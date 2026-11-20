--!strict
-- Cidade da partida no CLIENTE. Monta tudo localmente pela semente (CityWorld): nada de construção é
-- replicado. Recebe só dados do servidor:
--   * CitySnapshot (entrada / reconexão / lote perdido): quem já caiu e a vida das danificadas;
--   * CityDelta (lote a cada 0,1 s): id + 1 byte de vida. Seq fora de ordem -> pede o snapshot de novo.
-- O personagem fica ancorado (só aqui no cliente) até a cidade existir, para não cair no vazio.
-- Destruída: WreckPresenter anima e troca pelo destroço (o mesmo em todo cliente, semente = id).
-- Visibilidade por distância: LodManager (chunks, Tier do client/City/QualityTier).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CityState = require(Shared.Logic.CityState)
local Protocol = require(Shared.Logic.Protocol)
local MatchCity = require(Shared.Logic.MatchCity)
local MatchConfig = require(Shared.Config.MatchConfig)
local WreckConfig = require(Shared.Config.WreckConfig)
local ModelCatalog = require(Shared.Config.ModelCatalog)
local Templates = require(Shared.Buildings.Templates)
local CityWorld = require(Shared.City.CityWorld)
local Remotes = require(Shared.Remotes)

local LodManager = require(script.Parent.LodManager)
local QualityTier = require(script.Parent.QualityTier)
local WreckPresenter = require(script.Parent.WreckPresenter)

local CityClient = {}

local localPlayer = Players.LocalPlayer
local L = MatchConfig.HpLevels

local state: CityState.State? = nil
local models: { [number]: Model } = {}
local placements: { any } = {}
local infos: { MatchCity.Info } = {}
local lastSeq = -1
local ready = false
local pending: { Protocol.Delta } = {}
local resyncing = false
local buildingsFolder: Folder? = nil
local destroyedListeners: { (number, Vector3) -> () } = {}

function CityClient.onDestroyed(callback: (number, Vector3) -> ())
	table.insert(destroyedListeners, callback)
end

function CityClient.state(): CityState.State?
	return state
end

function CityClient.isReady(): boolean
	return ready
end

-- Onde fica a construção (para efeitos): centro no chão, altura e footprint (studs). nil = id inválido.
function CityClient.site(id: number): (Vector3?, number, number, number)
	local info, placement = infos[id], placements[id]
	if info == nil or placement == nil then
		return nil, 0, 0, 0
	end
	local b = info.Box
	return Vector3.new((b[1] + b[3]) / 2, placement.Y, (b[2] + b[4]) / 2), info.Height, b[3] - b[1], b[4] - b[2]
end

function CityClient.buildings(): Folder?
	return buildingsFolder
end

-- Caixa de longe (LOD Far): o footprint e a altura da construção, na cor da parede. Props baixos
-- (bancos, postes, placas) não ganham caixa: de longe só somem.
local IMPOSTOR_MIN_HEIGHT = 4
local function impostor(model: Model, info: MatchCity.Info, groundY: number): BasePart?
	if info.Height < IMPOSTOR_MIN_HEIGHT then
		return nil
	end
	local wall = model:FindFirstChild("Wall", true)
	local box = Instance.new("Part")
	box.Name = "Far"
	box.Anchored = true
	box.CanCollide = false
	box.CanTouch = false
	box.CastShadow = false
	box.Material = Enum.Material.SmoothPlastic
	box.Color = if wall and wall:IsA("BasePart") then wall.Color else Color3.fromRGB(200, 200, 205)
	local b = info.Box
	box.Size = Vector3.new(b[3] - b[1], info.Height, b[4] - b[2])
	box.Position = Vector3.new((b[1] + b[3]) / 2, groundY + info.Height / 2, (b[2] + b[4]) / 2)
	return box
end

local function destroyBuilding(id: number, animate: boolean)
	local model = models[id]
	if model == nil then
		return
	end
	models[id] = nil
	local position = model:GetPivot().Position
	local info = infos[id]
	WreckPresenter.destroy(id, model, placements[id], info.Height, animate, info.Value > 0)
	if animate then
		for _, callback in destroyedListeners do
			task.spawn(callback, id, position)
		end
	end
end

local function applyEntries(entries: { Protocol.Entry }, animate: boolean)
	local s = state :: CityState.State
	for _, e in entries do
		if CityState.apply(s, e.Id, e.Hp, L) then
			destroyBuilding(e.Id, animate)
		end
	end
end

local function resync()
	if resyncing then
		return
	end
	resyncing = true
	local remote = Remotes.func(Remotes.Names.Functions.CitySnapshot)
	local snap: Protocol.Snapshot? = nil
	for _ = 1, 20 do
		local ok, result = pcall(function()
			return remote:InvokeServer()
		end)
		snap = if ok then Protocol.decodeSnapshot(result) else nil
		if snap and snap.Count == (state :: CityState.State).Count then
			break
		end
		snap = nil
		task.wait(1)
	end
	if snap then
		local s = state :: CityState.State
		for id = 1, snap.Count do
			if snap.Dead[id] and not s.Dead[id] then
				CityState.apply(s, id, 0, L)
				destroyBuilding(id, false)
			end
		end
		applyEntries(snap.Damaged, false)
		lastSeq = snap.Seq
		-- lotes que chegaram enquanto o snapshot vinha, em ordem
		table.sort(pending, function(a, b)
			return a.Seq < b.Seq
		end)
		for _, delta in pending do
			if delta.Seq > lastSeq then
				applyEntries(delta.Entries, true)
				lastSeq = delta.Seq
			end
		end
		table.clear(pending)
	else
		warn("[CityClient] snapshot da cidade não chegou")
	end
	resyncing = false
end

local function onDelta(payload: unknown)
	local delta = Protocol.decodeDelta(payload)
	if delta == nil or state == nil then
		return
	end
	if resyncing or not ready then
		table.insert(pending, delta)
		return
	end
	if delta.Seq <= lastSeq then
		return -- velho ou repetido
	end
	if delta.Seq > lastSeq + 1 then
		table.insert(pending, delta) -- perdeu um lote: o snapshot conserta
		task.spawn(resync)
		return
	end
	lastSeq = delta.Seq
	applyEntries(delta.Entries, true)
end

local function holdCharacter(character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if root and not ready then
		root.Anchored = true
		while not ready and character.Parent do
			task.wait(0.1)
		end
		root.Anchored = false
	end
end

local function build()
	local mapId = ReplicatedStorage:GetAttribute("MatchMap") :: string
	local map = CityWorld.map(mapId) :: CityWorld.MapInfo
	local scale = (ReplicatedStorage:GetAttribute("MatchScale") :: number?) or 1
	local layout = CityWorld.layout(map, scale)
	placements = layout.Placements
	infos = MatchCity.infos(placements, Templates :: any, ModelCatalog :: any, MatchConfig)
	state = CityState.new(infos)

	local folder = Instance.new("Folder")
	folder.Name = "City"
	folder.Parent = Workspace
	CityWorld.terrain(map, layout, folder, true)
	local buildings = Instance.new("Folder")
	buildings.Name = "Buildings"
	buildings.Parent = folder
	buildingsFolder = buildings
	local wrecks = Instance.new("Folder")
	wrecks.Name = "Wrecks"
	wrecks.Parent = folder
	LodManager.init(buildings, wrecks, folder)
	-- cada construção entra já na faixa de LOD do chunk dela (as de longe nem entram no render)
	for id, placement in placements do
		local model = CityWorld.building(map, placement, id)
		models[id] = model
		local info = infos[id]
		LodManager.add(id, model, placement.X, placement.Z, function()
			return impostor(model, info, placement.Y)
		end)
		if id % WreckConfig.BuildPerFrame == 0 then
			task.wait()
		end
	end
	resync()
	ready = true
	-- lotes que chegaram depois do snapshot e antes de "ready"
	if #pending > 0 then
		task.spawn(resync)
	end
end

function CityClient.init()
	QualityTier.init()
	WreckPresenter.init()
	Remotes.event(Remotes.Names.Events.CityDelta).OnClientEvent:Connect(onDelta)
	localPlayer.CharacterAdded:Connect(holdCharacter)
	if localPlayer.Character then
		task.spawn(holdCharacter, localPlayer.Character)
	end
	task.spawn(function()
		while ReplicatedStorage:GetAttribute("MatchMap") == nil do
			ReplicatedStorage:GetAttributeChangedSignal("MatchMap"):Wait()
		end
		build()
	end)
end

return CityClient
