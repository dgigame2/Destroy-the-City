--!strict
-- Ciclo das partidas com lobby:
-- carregar mapa -> jogar (5 min ou até alguém ficar do tamanho do mapa) -> vencedor -> votação -> próximo.
-- Quem está no lobby com "Auto Join" entra sozinho quando a partida começa; quem chega no meio
-- fica no lobby e pode entrar pelo portal/botão PLAY ou espectar.
-- O estado vai para os clientes como atributos do ReplicatedStorage; cada jogador tem o atributo InMatch.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Voting = require(Shared.Logic.Voting)
local Rng = require(Shared.Logic.Rng)
local MapConfig = require(Shared.Config.MapConfig)
local RoundConfig = require(Shared.Config.RoundConfig)
local GemConfig = require(Shared.Config.GemConfig)
local Remotes = require(Shared.Remotes)

local PlayerData = require(script.Parent.PlayerData)
local GrowthService = require(script.Parent.GrowthService)
local MapService = require(script.Parent.MapService)
local EatService = require(script.Parent.EatService)
local LobbyService = require(script.Parent.LobbyService)
local CosmeticService = require(script.Parent.CosmeticService)

local RoundService = {}

local rng = Rng.new(os.time())
local votes: { [Player]: string } = {}
local voteOptions: { string } = {}
local voting = false

local function state(): string?
	return ReplicatedStorage:GetAttribute("RoundState") :: string?
end

local function setState(newState: string, endsAt: number?)
	ReplicatedStorage:SetAttribute("RoundState", newState)
	ReplicatedStorage:SetAttribute("RoundEndsAt", endsAt or 0)
end

local function setAnchored(player: Player, anchored: boolean)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		root.Anchored = anchored
	end
end

local function teleportToCity(player: Player)
	local character = player.Character
	if character == nil then
		return
	end
	local spawn = MapService.randomSpawn()
	local position = spawn + Vector3.new(0, GrowthService.scale(player) * 3, 0)
	local center = Vector3.new(0, position.Y, 0)
	local look = if (center - position).Magnitude > 1 then CFrame.lookAt(position, center) else CFrame.new(position)
	character:PivotTo(look)
end

-- Coloca o jogador na partida em andamento (começa do tamanho inicial da classe).
local function joinMatch(player: Player)
	if state() ~= "Playing" or player:GetAttribute("InMatch") then
		return
	end
	player:SetAttribute("InMatch", true)
	GrowthService.setPoints(player, GrowthService.startPoints(player))
	GrowthService.onCharacter(player)
	teleportToCity(player)
end

-- Tira da partida e leva para o lobby com tamanho normal.
local function sendToLobby(player: Player)
	player:SetAttribute("InMatch", false)
	GrowthService.setPoints(player, 0)
	if player.Character then
		GrowthService.onCharacter(player)
		LobbyService.teleport(player)
		setAnchored(player, false)
	end
end

-- Novo personagem: na partida renasce na cidade (com o tamanho guardado); senão, no lobby.
function RoundService.onCharacter(player: Player, character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	if root == nil then
		return
	end
	-- o Roblox posiciona o personagem logo depois do CharacterAdded; esperar evita que ele desfaça o teleporte
	task.wait(0.15)
	if character.Parent == nil then
		return
	end
	GrowthService.onCharacter(player)
	CosmeticService.refresh(player)
	if player:GetAttribute("InMatch") and state() == "Playing" then
		teleportToCity(player)
	else
		player:SetAttribute("InMatch", false)
		LobbyService.teleport(player)
	end
end

local function matchPlayers(): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("InMatch") then
			table.insert(list, player)
		end
	end
	return list
end

local function biggestPlayer(): Player?
	local best, bestScale = nil, -1
	for _, player in matchPlayers() do
		local scale = GrowthService.scale(player)
		if scale > bestScale then
			best, bestScale = player, scale
		end
	end
	return best
end

local function playRound(map: MapService.MapInfo): Player?
	local endsAt = Workspace:GetServerTimeNow() + RoundConfig.RoundSeconds
	setState("Playing", endsAt)
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("AutoJoin") ~= false then
			joinMatch(player)
		end
	end
	EatService.setEnabled(true)
	local winner: Player? = nil
	while Workspace:GetServerTimeNow() < endsAt do
		task.wait(0.25)
		for _, player in matchPlayers() do
			if GrowthService.scale(player) >= map.WinScale then
				winner = player
				break
			end
		end
		if winner then
			break
		end
	end
	EatService.setEnabled(false)
	return winner or biggestPlayer()
end

local function rewardRound(winner: Player?, map: MapService.MapInfo)
	for _, player in matchPlayers() do
		PlayerData.addGems(player, GemConfig.PlayedRoundGems)
	end
	if winner then
		PlayerData.addCoins(winner, math.floor(map.WinScale * 10))
		PlayerData.addGems(winner, GemConfig.WinGems)
	end
end

local function runVote(currentId: string): string
	local ids = {}
	for _, map in MapConfig do
		table.insert(ids, map.Id)
	end
	voteOptions = Voting.pickOptions(ids, RoundConfig.VoteOptions, currentId, rng)
	table.clear(votes)
	voting = true
	local payload = {}
	for _, id in voteOptions do
		local map = MapService.getMap(id) :: MapService.MapInfo
		table.insert(payload, { Id = id, Name = map.DisplayName, Icon = map.Icon })
	end
	local endsAt = Workspace:GetServerTimeNow() + RoundConfig.VoteSeconds
	setState("Voting", endsAt)
	Remotes.event(Remotes.Names.Events.VoteStarted):FireAllClients(payload, endsAt)
	task.wait(RoundConfig.VoteSeconds)
	voting = false
	return Voting.winner(voteOptions, votes, rng)
end

function RoundService.init()
	Remotes.event(Remotes.Names.Events.CastVote).OnServerEvent:Connect(function(player: Player, mapId: unknown)
		if not voting or type(mapId) ~= "string" or table.find(voteOptions, mapId) == nil then
			return
		end
		votes[player] = mapId
		Remotes.event(Remotes.Names.Events.VoteUpdated):FireAllClients(Voting.counts(voteOptions, votes))
	end)
	Remotes.event(Remotes.Names.Events.JoinMatch).OnServerEvent:Connect(joinMatch)
	Remotes.event(Remotes.Names.Events.SetAutoJoin).OnServerEvent:Connect(function(player: Player, value: unknown)
		if type(value) == "boolean" then
			player:SetAttribute("AutoJoin", value)
		end
	end)
	LobbyService.onPortalTouched(joinMatch)
	Players.PlayerAdded:Connect(function(player)
		player:SetAttribute("AutoJoin", true)
		player:SetAttribute("InMatch", false)
	end)
	for _, player in Players:GetPlayers() do
		player:SetAttribute("AutoJoin", true)
		player:SetAttribute("InMatch", false)
	end
	Players.PlayerRemoving:Connect(function(player)
		votes[player] = nil
		GrowthService.forget(player)
	end)
	-- quem cair do lobby volta para ele
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root and not player:GetAttribute("InMatch") and LobbyService.isBelowLobby(root.Position) then
					LobbyService.teleport(player)
				end
			end
		end
	end)
end

function RoundService.run()
	local nextMap = MapConfig[rng:int(1, #MapConfig)]
	while true do
		setState("Loading")
		ReplicatedStorage:SetAttribute("MapName", nextMap.DisplayName)
		MapService.load(nextMap)
		while #Players:GetPlayers() < RoundConfig.MinPlayersToStart do
			task.wait(1)
		end
		-- intervalo no lobby: dá tempo de usar loja, roleta e recompensas antes da partida
		local intermissionEnds = Workspace:GetServerTimeNow() + RoundConfig.IntermissionSeconds
		setState("Intermission", intermissionEnds)
		task.wait(RoundConfig.IntermissionSeconds)

		local winner = playRound(nextMap)
		ReplicatedStorage:SetAttribute("Winner", if winner then winner.DisplayName else "")
		rewardRound(winner, nextMap)
		setState("Winner", Workspace:GetServerTimeNow() + RoundConfig.WinnerScreenSeconds)
		task.wait(RoundConfig.WinnerScreenSeconds)

		-- todo mundo volta para o lobby para votar enquanto o próximo mapa carrega
		for _, player in Players:GetPlayers() do
			sendToLobby(player)
		end
		local chosen = runVote(nextMap.Id)
		nextMap = MapService.getMap(chosen) :: MapService.MapInfo
	end
end

return RoundService
