--!strict
-- Servidor da run (lugar "Run"): carrega a run da party, deixa todo mundo comer a cidade e salva o progresso.
-- Fluxo: primeiro jogador chega com o RunId (TeleportData) -> carrega o registro -> monta a cidade sem as
-- construções já comidas -> come até acabar -> vitória (gemas + 1 win) -> todos voltam para o lobby.
-- A cidade é dividida em áreas (zonas): só a primeira começa aberta; comer tudo de uma zona abre a próxima,
-- com comemoração (prêmios + FRENZY) e a barreira caindo.
-- Estado para o cliente (atributos do ReplicatedStorage): RunState ("Loading" | "Playing" | "Victory"),
-- RunMap, RunMapIcon, RunDifficulty, RunEaten, RunTotal, RunWinGems, RunZone, RunZones, RunZoneName,
-- RunZoneLeft, RunZoneTotal, FrenzyUntil.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Runs = require(Shared.Logic.Runs)
local Zones = require(Shared.Logic.Zones)
local RunConfig = require(Shared.Config.RunConfig)
local MapConfig = require(Shared.Config.MapConfig)
local DifficultyConfig = require(Shared.Config.DifficultyConfig)
local EconomyConfig = require(Shared.Config.EconomyConfig)
local Remotes = require(Shared.Remotes)

local PlayerData = require(script.Parent.PlayerData)
local GrowthService = require(script.Parent.GrowthService)
local MapService = require(script.Parent.MapService)
local EatService = require(script.Parent.EatService)
local CosmeticService = require(script.Parent.CosmeticService)
local RunStore = require(script.Parent.RunStore)
local Teleporter = require(script.Parent.Teleporter)

local RunSession = {}

local record: RunStore.Record? = nil
local difficulty: DifficultyConfig.Difficulty = DifficultyConfig[1]
local eatenSet: { [number]: boolean } = {}
local eatenCount = 0
local finished = false
local revealedZone = 0
local currentZone = 1
local zoneLeft: { number } = {}
local autoCollected: { [number]: boolean } = {}

local function notice(player: Player, text: string)
	Remotes.event(Remotes.Names.Events.Notice):FireClient(player, text)
end

local function setState(state: string)
	ReplicatedStorage:SetAttribute("RunState", state)
end

local function isMember(player: Player): boolean
	local current = record
	if current == nil then
		return false
	end
	return current.Temporary == true or table.find(current.Members, player.UserId) ~= nil
end

local function teleportToCity(player: Player)
	local character = player.Character
	if character == nil then
		return
	end
	local spawn = MapService.randomSpawn(currentZone)
	local position = spawn + Vector3.new(0, GrowthService.scale(player) * 3, 0)
	local center = Vector3.new(0, position.Y, 0)
	local look = if (center - position).Magnitude > 1 then CFrame.lookAt(position, center) else CFrame.new(position)
	character:PivotTo(look)
end

-- Guarda no registro o tamanho, o dinheiro e os upgrades do jogador.
local function snapshot(player: Player)
	local current = record
	local entry = PlayerData.get(player)
	if current == nil or entry == nil or not player:GetAttribute("InMatch") then
		return
	end
	current.Players[tostring(player.UserId)] = {
		Points = entry.Points,
		Coins = entry.Coins,
		Upgrades = table.clone(entry.Upgrades),
	}
end

local function summary(current: RunStore.Record): Runs.Summary
	return {
		Id = current.Id,
		Map = current.Map,
		Difficulty = current.Difficulty,
		Members = current.Members,
		Names = current.Names,
		Progress = Runs.progress(eatenCount, MapService.total()),
		UpdatedAt = os.time(),
	}
end

-- Salva a run e atualiza o resumo na lista de runs salvas de quem está aqui (ou de `players`).
local function saveRun(players: { Player }?)
	local current = record
	if current == nil or finished or current.Temporary then
		return
	end
	for _, player in Players:GetPlayers() do
		snapshot(player)
	end
	current.Eaten = Runs.encodeEaten(eatenSet)
	RunStore.save(current)
	local entry = summary(current)
	for _, player in players or Players:GetPlayers() do
		if isMember(player) then
			PlayerData.upsertRun(player, entry)
		end
	end
end

local function publishProgress()
	ReplicatedStorage:SetAttribute("RunEaten", eatenCount)
	ReplicatedStorage:SetAttribute("RunTotal", MapService.total())
	ReplicatedStorage:SetAttribute("RunZone", currentZone)
	ReplicatedStorage:SetAttribute("RunZones", #zoneLeft)
	ReplicatedStorage:SetAttribute("RunZoneName", MapService.zoneNames()[currentZone] or "")
	ReplicatedStorage:SetAttribute("RunZoneLeft", zoneLeft[currentZone] or 0)
	ReplicatedStorage:SetAttribute("RunZoneTotal", MapService.zoneTotal(currentZone))
end

-- Faltando poucas construções na zona atual, elas brilham através das paredes para a party achar.
local function revealRemaining()
	local buildings = MapService.buildingsFolder()
	if revealedZone == currentZone or buildings == nil or (zoneLeft[currentZone] or 0) > RunConfig.RevealRemaining then
		return
	end
	local remaining = {}
	for _, model in buildings:GetChildren() do
		if model:IsA("Model") and model:GetAttribute("Zone") == currentZone and not MapService.isEaten(model) then
			table.insert(remaining, model)
		end
	end
	revealedZone = currentZone
	for _, model in remaining do
		local highlight = Instance.new("Highlight")
		highlight.Name = "Reveal"
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		highlight.FillColor = Color3.fromRGB(255, 220, 60)
		highlight.FillTransparency = 0.55
		highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
		highlight.Parent = model
	end
end

local function victory()
	local current = record
	if current == nil or finished then
		return
	end
	finished = true
	EatService.setEnabled(false)
	local gems = Runs.winGems(RunConfig.WinGems, difficulty.Reward)
	ReplicatedStorage:SetAttribute("RunWinGems", gems)
	setState("Victory")
	for _, player in Players:GetPlayers() do
		if isMember(player) and player:GetAttribute("InMatch") then
			PlayerData.addGems(player, gems)
			PlayerData.addWin(player)
			PlayerData.removeRun(player, current.Id)
			task.spawn(PlayerData.save, player)
		end
	end
	if not current.Temporary then
		task.spawn(RunStore.remove, current.Id)
	end
	task.wait(RunConfig.VictorySeconds)
	local ok, why = Teleporter.toLobby(Players:GetPlayers())
	if not ok then
		for _, player in Players:GetPlayers() do
			notice(player, `Victory! ({why})`)
		end
	end
end

-- Zona limpa: prêmios para a party, comemoração na tela e, depois dela, a barreira cai e começa o FRENZY.
local function clearZone(zone: number)
	local names = MapService.zoneNames()
	local reward = Zones.reward(zone, RunConfig.ZoneRewards, difficulty.Reward)
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("InMatch") then
			PlayerData.addGems(player, reward.Gems)
			PlayerData.addCoins(player, reward.Cash)
		end
	end
	local nextZone = zone + 1
	Remotes.event(Remotes.Names.Events.ZoneCleared):FireAllClients({
		Zone = zone,
		Name = names[zone],
		Next = names[nextZone],
		NextIndex = nextZone,
		Gems = reward.Gems,
		Cash = reward.Cash,
		Frenzy = reward.FrenzySeconds,
		Gate = MapService.zoneGate(nextZone),
	})
	task.wait(RunConfig.ZoneCelebrationSeconds)
	if finished then
		return
	end
	currentZone = nextZone
	MapService.openZone(nextZone)
	EatService.setOpenZone(nextZone)
	local frenzyUntil = Workspace:GetServerTimeNow() + reward.FrenzySeconds
	EatService.setFrenzy(frenzyUntil)
	ReplicatedStorage:SetAttribute("FrenzyUntil", frenzyUntil)
	publishProgress()
	revealRemaining()
	saveRun()
end

-- Comeu 98% da área atual: o resto da área é sugado sozinho (uma vez por zona).
local function autoCollect(zone: number)
	local buildings = MapService.buildingsFolder()
	if autoCollected[zone] or buildings == nil then
		return
	end
	autoCollected[zone] = true
	local remaining = {}
	for _, model in buildings:GetChildren() do
		if model:IsA("Model") and model:GetAttribute("Zone") == zone and not MapService.isEaten(model) then
			table.insert(remaining, model)
		end
	end
	if not EatService.collectAll(remaining) then
		autoCollected[zone] = nil -- ninguém em jogo ainda: tenta de novo depois
	end
end

local function needsAutoCollect(): boolean
	local zone = currentZone
	return not autoCollected[zone]
		and Zones.shouldAutoCollect(zoneLeft[zone] or 0, MapService.zoneTotal(zone), RunConfig.AutoCollect)
end

local function onConsumed(id: number, zone: number)
	if eatenSet[id] then
		return
	end
	eatenSet[id] = true
	eatenCount += 1
	zoneLeft[zone] = math.max((zoneLeft[zone] or 1) - 1, 0)
	publishProgress()
	revealRemaining()
	if zone == currentZone and needsAutoCollect() then
		task.spawn(autoCollect, zone)
	end
	if Runs.isVictory(eatenCount, MapService.total()) then
		task.spawn(victory)
	elseif zone == currentZone and zoneLeft[zone] == 0 and currentZone < #zoneLeft then
		task.spawn(clearZone, zone)
	end
end

-- Jogador entrou no servidor (dados da conta já carregados).
function RunSession.onPlayerReady(player: Player)
	while record == nil and player.Parent do
		task.wait(0.2)
	end
	local current = record
	if current == nil or player.Parent == nil then
		return
	end
	if not isMember(player) then
		local ok = Teleporter.toLobby({ player })
		if not ok then
			player:Kick("This run belongs to another party.")
		end
		return
	end
	if current.Temporary and table.find(current.Members, player.UserId) == nil then
		table.insert(current.Members, player.UserId)
		table.insert(current.Names, player.DisplayName)
	end
	local saved = current.Players[tostring(player.UserId)]
	if saved then
		PlayerData.setRunState(player, tonumber(saved.Coins) or 0, saved.Upgrades or {})
		GrowthService.setPoints(player, tonumber(saved.Points) or 0)
	else
		PlayerData.setRunState(player, EconomyConfig.StartingCoins, {})
		GrowthService.setPoints(player, GrowthService.startPoints(player))
	end
	player:SetAttribute("InMatch", true)
	-- o personagem só nasce agora, com a cidade pronta (CharacterAutoLoads fica desligado na run)
	player:LoadCharacter()
end

-- Novo personagem (entrada ou renascimento): vai para a cidade com o tamanho guardado.
function RunSession.onCharacter(player: Player, character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	if root == nil then
		return
	end
	-- o Roblox posiciona o personagem logo depois do CharacterAdded; esperar evita que ele desfaça o teleporte
	task.wait(0.15)
	if character.Parent == nil or not player:GetAttribute("InMatch") then
		return
	end
	GrowthService.onCharacter(player)
	CosmeticService.refresh(player)
	teleportToCity(player)
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

local function findDifficulty(id: string): DifficultyConfig.Difficulty
	for _, d in DifficultyConfig do
		if d.Id == id then
			return d
		end
	end
	return DifficultyConfig[1]
end

-- Descobre qual run este servidor deve carregar (vem com o primeiro jogador).
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
		-- teste no Studio: run temporária com as opções do RunConfig (não é salva)
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
	saveRun({ player })
	PlayerData.save(player)
	local ok, why = Teleporter.toLobby({ player })
	if not ok then
		notice(player, why or "Could not go back to the lobby")
	end
end

function RunSession.init()
	setState("Loading")
	Players.CharacterAutoLoads = false
	PlayerData.beforeSave(function(players)
		saveRun(players)
	end)
	Remotes.event(Remotes.Names.Events.LeaveMatch).OnServerEvent:Connect(leave)
	Players.PlayerRemoving:Connect(function(player)
		GrowthService.forget(player)
	end)
end

function RunSession.run()
	local loaded = loadRecord()
	if loaded == nil then
		-- sem run válida: devolve todo mundo ao lobby
		for _, player in Players:GetPlayers() do
			notice(player, "This run could not be loaded")
		end
		Teleporter.toLobby(Players:GetPlayers())
		return
	end
	local map = MapService.getMap(loaded.Map) or MapConfig[1]
	difficulty = findDifficulty(loaded.Difficulty)
	GrowthService.setDifficulty(difficulty.Reach, difficulty.Speed)
	-- ids acima do total do mapa são descartados depois de montar a cidade
	eatenSet = Runs.decodeEaten(loaded.Eaten, math.huge)
	MapService.onConsumed(onConsumed)
	MapService.load(map, eatenSet, difficulty)
	eatenSet = Runs.decodeEaten(Runs.encodeEaten(eatenSet), MapService.total())
	eatenCount = #Runs.encodeEaten(eatenSet)
	-- zonas já limpas (run salva) começam abertas
	local _, remaining = MapService.zoneCounts(eatenSet)
	zoneLeft = remaining
	currentZone = Zones.current(remaining)
	for zone = 2, currentZone do
		MapService.openZone(zone)
	end
	EatService.setOpenZone(currentZone)

	ReplicatedStorage:SetAttribute("RunMap", map.DisplayName)
	ReplicatedStorage:SetAttribute("RunMapIcon", map.Icon)
	ReplicatedStorage:SetAttribute("RunDifficulty", difficulty.Name)
	publishProgress()
	EatService.setDifficultyGrowth(difficulty.Growth)
	EatService.setEnabled(true)
	-- run salva que já parou em 98%+ (ou ninguém estava em jogo na hora): coleta assim que der
	task.spawn(function()
		while not finished do
			if needsAutoCollect() then
				autoCollect(currentZone)
			end
			task.wait(1)
		end
	end)
	record = loaded
	setState("Playing")
	revealRemaining()

	while not finished do
		task.wait(RunConfig.SaveEverySeconds)
		saveRun()
	end
end

return RunSession
