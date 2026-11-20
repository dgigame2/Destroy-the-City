--!strict
-- Partida (lugar "Run"): carrega a party, monta a cidade em DADOS (CityService), deixa todo mundo destruir
-- e paga as recompensas. Fluxo: primeiro jogador chega com o RunId -> carrega o registro (RunStore) ->
-- "Playing" -> marcos 25/50/75% (gemas extras, uma vez por jogador) -> CompleteAt derruba o resto ->
-- 100% = vitória (gemas + 1 vitória) -> todos voltam para o lobby.
-- Estado para o cliente (atributos do ReplicatedStorage): MatchState ("Loading" | "Playing" | "Victory"),
-- MatchMap (id), MatchMapName, MatchScale (tamanho da cidade da dificuldade), MatchDifficulty, MatchProgress
-- (0..1), MatchWinGems. O cliente monta a cidade com MatchMap + MatchScale (mesmo layout do servidor).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CityState = require(Shared.Logic.CityState)
local Runs = require(Shared.Logic.Runs)
local MatchConfig = require(Shared.Config.MatchConfig)
local RunConfig = require(Shared.Config.RunConfig)
local DifficultyConfig = require(Shared.Config.DifficultyConfig)
local MapConfig = require(Shared.Config.MapConfig)
local CityWorld = require(Shared.City.CityWorld)
local Remotes = require(Shared.Remotes)

local PlayerData = require(script.Parent.Parent.PlayerData)
local RunStore = require(script.Parent.Parent.RunStore)
local Teleporter = require(script.Parent.Parent.Teleporter)
local LightingService = require(script.Parent.Parent.LightingService)
local CosmeticService = require(script.Parent.Parent.CosmeticService)
local CityService = require(script.Parent.CityService)
local ElementService = require(script.Parent.ElementService)

local MatchService = {}

local record: RunStore.Record? = nil
local finished = false
local winGems = 0
local paidMilestones: { [Player]: { [number]: boolean } } = {}
local pocket: { [Player]: number } = {} -- dinheiro fracionário ainda não pago

local function setState(state: string)
	ReplicatedStorage:SetAttribute("MatchState", state)
end

local function notice(player: Player, text: string)
	Remotes.event(Remotes.Names.Events.Notice):FireClient(player, text)
end

local function isMember(player: Player): boolean
	local current = record
	return current ~= nil and (current.Temporary == true or table.find(current.Members, player.UserId) ~= nil)
end

local function playing(): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("InMatch") then
			table.insert(list, player)
		end
	end
	return list
end

local function pay(player: Player, amount: number)
	local total = (pocket[player] or 0) + amount
	local whole = math.floor(total)
	pocket[player] = total - whole
	if whole > 0 then
		PlayerData.addCoins(player, whole)
	end
end

local function findDifficulty(id: string)
	for _, d in DifficultyConfig do
		if d.Id == id then
			return d
		end
	end
	return DifficultyConfig[1]
end

local function victory()
	if finished then
		return
	end
	finished = true
	setState("Victory")
	local current = record :: RunStore.Record
	for _, player in playing() do
		if isMember(player) then
			PlayerData.addGems(player, winGems)
			PlayerData.addWin(player)
			task.spawn(PlayerData.save, player)
		end
	end
	if not current.Temporary then
		task.spawn(RunStore.remove, current.Id)
	end
	task.wait(MatchConfig.VictorySeconds)
	local ok, why = Teleporter.toLobby(Players:GetPlayers())
	if not ok then
		for _, player in Players:GetPlayers() do
			notice(player, `Victory! ({why})`)
		end
	end
end

-- Marcos: cada um sai uma vez na partida; cada jogador recebe uma vez (quem entrou depois não recebe os antigos).
local function checkMilestones()
	local state = CityService.state() :: CityState.State
	ReplicatedStorage:SetAttribute("MatchProgress", CityState.progress(state))
	for _, index in CityState.newMilestones(state, MatchConfig.Milestones) do
		local bonus = math.floor(winGems * (MatchConfig.MilestoneGems[index] or 0) + 0.5)
		for _, player in playing() do
			local paid = paidMilestones[player]
			if paid == nil then
				paid = {}
				paidMilestones[player] = paid
			end
			if not paid[index] then
				paid[index] = true
				if bonus > 0 then
					PlayerData.addGems(player, bonus)
				end
			end
		end
		Remotes.event(Remotes.Names.Events.Milestone):FireAllClients(index, MatchConfig.Milestones[index])
	end
	if CityState.progress(state) >= 1 - 1e-9 and not finished then
		CityService.flushNow()
		task.spawn(victory)
	end
end

local function onDestroyed(player: Player?, id: number)
	local state = CityService.state() :: CityState.State
	local money = state.Value[id] * MatchConfig.Money.PerValue
	if money > 0 then
		local party = playing()
		if player and player:GetAttribute("InMatch") then
			pay(player, money * MatchConfig.Money.DestroyerShare)
			money *= 1 - MatchConfig.Money.DestroyerShare
		end
		for _, member in party do
			pay(member, money / math.max(#party, 1))
		end
	end
	-- perto do fim o servidor derruba o que sobrou (ninguém caça a última casinha)
	if CityState.progress(state) >= MatchConfig.CompleteAt and state.DestroyedValue < state.TotalValue then
		for other = 1, state.Count do
			if not state.Dead[other] and state.Value[other] > 0 then
				CityService.hit(other, state.MaxHp[other])
			end
		end
	end
	checkMilestones()
end

local function spawnPoint(): Vector3
	local layout = CityService.layout()
	local spawns = layout and layout.Spawns[1]
	if spawns and #spawns > 0 then
		local s = spawns[math.random(1, #spawns)]
		return Vector3.new(s[1], s[2] + 4, s[3])
	end
	return Vector3.new(0, 20, 0)
end

local function onCharacter(player: Player, character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	if root == nil then
		return
	end
	task.wait(0.15) -- o Roblox reposiciona logo depois do CharacterAdded
	if character.Parent == nil or not player:GetAttribute("InMatch") then
		return
	end
	CosmeticService.refresh(player)
	character:PivotTo(CFrame.new(spawnPoint()))
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Died:Once(function()
			task.wait(Players.RespawnTime)
			if player.Parent and player:GetAttribute("InMatch") then
				player:LoadCharacter()
			end
		end)
	end
end

local function onPlayerReady(player: Player)
	while record == nil and player.Parent do
		task.wait(0.2)
	end
	local current = record
	if current == nil or player.Parent == nil then
		return
	end
	if not isMember(player) then
		if not Teleporter.toLobby({ player }) then
			player:Kick("This match belongs to another party.")
		end
		return
	end
	if current.Temporary and table.find(current.Members, player.UserId) == nil then
		table.insert(current.Members, player.UserId)
		table.insert(current.Names, player.DisplayName)
	end
	PlayerData.setRunState(player, 0) -- dinheiro da partida começa do zero em toda partida
	player:SetAttribute("InMatch", true)
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	player:LoadCharacter()
end

local function loadRecord(): RunStore.Record?
	local first = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
	local runId = Teleporter.runIdOf(first)
	if runId then
		for _ = 1, 3 do
			local found = RunStore.get(runId)
			if found then
				return found
			end
			task.wait(2)
		end
		return nil
	end
	if RunService:IsStudio() then
		local temporary = RunStore.new(RunConfig.Studio.Map, RunConfig.Studio.Difficulty, {}, {})
		temporary.Temporary = true
		return temporary
	end
	return nil
end

local function leave(player: Player)
	if finished then
		return
	end
	PlayerData.save(player)
	local ok, why = Teleporter.toLobby({ player })
	if not ok then
		notice(player, why or "Could not go back to the lobby")
	end
end

function MatchService.init()
	setState("Loading")
	Players.CharacterAutoLoads = false
	CityService.start()
	ElementService.start()
	ElementService.setGate(function(player)
		return not finished
			and player:GetAttribute("InMatch") == true
			and ReplicatedStorage:GetAttribute("MatchState") == "Playing"
	end)
	ElementService.onDestroyed(onDestroyed)
	Remotes.event(Remotes.Names.Events.LeaveMatch).OnServerEvent:Connect(leave)
	Players.PlayerRemoving:Connect(function(player)
		paidMilestones[player] = nil
		pocket[player] = nil
	end)
	PlayerData.init(onPlayerReady)
end

function MatchService.run()
	local loaded = loadRecord()
	if loaded == nil then
		for _, player in Players:GetPlayers() do
			notice(player, "This match could not be loaded")
		end
		Teleporter.toLobby(Players:GetPlayers())
		return
	end
	local map = CityWorld.map(loaded.Map) or MapConfig[1]
	local difficulty = findDifficulty(loaded.Difficulty)
	winGems = Runs.winGems(RunConfig.WinGems, difficulty.Reward)
	LightingService.applyBiome(map.Biome.Lighting)
	CityService.load(map, difficulty.MapScale)
	ReplicatedStorage:SetAttribute("RunStyle", map.Style) -- clima do cliente (AmbienceController)
	ReplicatedStorage:SetAttribute("MatchMap", map.Id)
	ReplicatedStorage:SetAttribute("MatchMapName", map.DisplayName)
	ReplicatedStorage:SetAttribute("MatchScale", difficulty.MapScale)
	ReplicatedStorage:SetAttribute("MatchDifficulty", difficulty.Name)
	ReplicatedStorage:SetAttribute("MatchWinGems", winGems)
	ReplicatedStorage:SetAttribute("MatchProgress", 0)
	record = loaded
	setState("Playing")
end

return MatchService
