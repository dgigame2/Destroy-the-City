--!strict
-- Monta a cidade da run (Logic/CityGen + Logic/CityTerrain) e controla as construções comidas
-- (na run elas não voltam: comer tudo = vitória) e as barreiras entre as áreas (zonas) da cidade.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CityGen = require(Shared.Logic.CityGen)
local CityTerrain = require(Shared.Logic.CityTerrain)
local CityProgress = require(Shared.Logic.CityProgress)
local Rng = require(Shared.Logic.Rng)
local Templates = require(Shared.Buildings.Templates)
local MapConfig = require(Shared.Config.MapConfig)
local CityConfig = require(Shared.Config.CityConfig)
local CityPlans = require(Shared.Config.CityPlans)
local DistrictConfig = require(Shared.Config.DistrictConfig)
local TierConfig = require(Shared.Config.TierConfig)
local GrowthConfig = require(Shared.Config.GrowthConfig)
local DifficultyConfig = require(Shared.Config.DifficultyConfig)

local Builder = require(script.Parent.Builder)
local LightingService = require(script.Parent.LightingService)

local BUILD_CHUNK = 25 -- construções por frame ao montar o mapa

export type MapInfo = MapConfig.MapInfo
type Difficulty = DifficultyConfig.Difficulty

local MapService = {}

local cityFolder: Folder? = nil
local currentMap: MapInfo? = nil
local currentLayout: CityGen.Layout? = nil
local stepGrowth: { number } = {}
local zoneTotals: { number } = {}
local eaten: { [Model]: boolean } = {}
local consumedCallback: ((number, number) -> ())? = nil

local BARRIER_COLOR = Color3.fromRGB(255, 90, 120)

function MapService.getMap(id: string): MapInfo?
	for _, map in MapConfig do
		if map.Id == id then
			return map
		end
	end
	return nil
end

function MapService.current(): MapInfo?
	return currentMap
end

function MapService.cityFolder(): Folder?
	return cityFolder
end

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function layoutFor(map: MapInfo, difficulty: Difficulty): CityGen.Layout
	return CityGen.generate(
		CityPlans[map.Id],
		DistrictConfig[map.Style],
		Templates,
		Rng.new(map.Seed),
		CityConfig,
		difficulty.MapScale
	)
end

-- Chão, faixas, terra, mar e paredes invisíveis da costa; cenário fora da cidade (não é comível).
local function buildTerrain(map: MapInfo, layout: CityGen.Layout, parent: Instance, shouldYield: boolean)
	local terrain = CityTerrain.generate(layout.Grid, map.Biome, Rng.new(map.Seed + 77), CityConfig, Templates)
	local ground = Instance.new("Folder")
	ground.Name = "Ground"
	ground.Parent = parent
	for index, data in terrain.Slabs do
		local part = Instance.new("Part")
		part.Name = data.Name
		part.Anchored = true
		part.Size = Vector3.new(data.Size[1], data.Size[2], data.Size[3])
		part.Position = Vector3.new(data.Pos[1], data.Pos[2], data.Pos[3])
		part.Color = rgb(data.Color)
		if data.Invisible then
			part.Transparency = 1
			part.CastShadow = false
			part.CanQuery = false
			Builder.studify(part, true)
		elseif data.Material == "Water" then
			Builder.studify(part, true)
			part.Material = Enum.Material.Glass
			part.Transparency = 0.15
			part.CastShadow = false
		elseif data.Material == "Ice" then
			Builder.studify(part, true)
			part.Material = Enum.Material.Ice
		elseif data.Name == "Foam" then
			Builder.studify(part, true)
			part.Transparency = 0.25
			part.CastShadow = false
			part.CanCollide = false
		elseif data.Name == "Mountain" or data.Name == "Islet" then
			Builder.studify(part)
			part.CanQuery = false
		else
			Builder.studify(part)
		end
		part.Parent = ground
		if shouldYield and index % CityConfig.BuildYieldEvery == 0 then
			task.wait()
		end
	end
	-- paredes invisíveis da costa (ninguém entra no mar)
	local walls = Instance.new("Folder")
	walls.Name = "CoastWalls"
	walls.Parent = ground
	for _, data in layout.Walls do
		local wall = Instance.new("Part")
		wall.Name = "Wall"
		wall.Anchored = true
		wall.Transparency = 1
		wall.CastShadow = false
		wall.CanQuery = false
		wall.Size = Vector3.new(data.Size[1], data.Size[2], data.Size[3])
		wall.Position = Vector3.new(data.Pos[1], data.Pos[2], data.Pos[3])
		wall.Parent = walls
	end
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = ground
	for _, item in terrain.Decor do
		local cframe = CFrame.new(item.X, item.Y, item.Z) * CFrame.Angles(0, math.rad(item.Rotation), 0)
		local model = Builder.build(Templates[item.Template], map.Palette, item.Variant, cframe)
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				part.CanQuery = false -- decoração não é comível nem bloqueia a mordida
			end
		end
		model.Parent = decor
	end
end

-- Barreiras entre as zonas: campo de força visível + parede invisível bem alta em cima.
-- Cada uma fica numa pasta "Zone<N>" e some quando a zona N abre.
local function buildBarriers(layout: CityGen.Layout, parent: Instance, openUpTo: number)
	local folder = Instance.new("Folder")
	folder.Name = "Barriers"
	folder.Parent = parent
	for _, data in layout.Barriers do
		if data.Zone <= openUpTo then
			continue
		end
		local zoneFolder = folder:FindFirstChild("Zone" .. data.Zone)
		if zoneFolder == nil then
			zoneFolder = Instance.new("Folder")
			zoneFolder.Name = "Zone" .. data.Zone
			zoneFolder.Parent = folder
		end
		local field = Instance.new("Part")
		field.Name = "Field"
		field.Anchored = true
		field.Size = Vector3.new(data.Size[1], data.Size[2], data.Size[3])
		field.Position = Vector3.new(data.Pos[1], data.Pos[2], data.Pos[3])
		field.Color = BARRIER_COLOR
		field.Material = Enum.Material.ForceField
		field.Transparency = 0.2
		field.CastShadow = false
		field.CanQuery = true -- o cliente acha a barreira para avisar "NEED TO CLEAN ... FIRST"
		field:SetAttribute("Zone", data.Zone)
		field.Parent = zoneFolder
		local wall = Instance.new("Part")
		wall.Name = "Wall"
		wall.Anchored = true
		wall.Transparency = 1
		wall.CastShadow = false
		wall.CanQuery = false
		local height = CityConfig.ColliderHeight
		wall.Size = Vector3.new(data.Size[1], height, data.Size[3])
		wall.Position = field.Position + Vector3.new(0, data.Size[2] / 2 + height / 2, 0)
		wall.Parent = zoneFolder
	end
	return folder
end

-- Monta a cidade inteira dentro de `parent`. `skip`: construções (BuildingId) já comidas nesta run.
-- `openUpTo`: zonas já abertas (sem barreira).
local function buildCity(
	map: MapInfo,
	parent: Instance,
	shouldYield: boolean,
	skip: { [number]: boolean }?,
	openUpTo: number,
	difficulty: Difficulty
): (Folder, CityGen.Layout)
	local layout = layoutFor(map, difficulty)
	local folder = Instance.new("Folder")
	folder.Name = "City"
	folder.Parent = parent
	buildTerrain(map, layout, folder, shouldYield)
	buildBarriers(layout, folder, openUpTo)
	-- placas das áreas: um ponto por zona (o cliente desenha o nome em cima; AreaSignsController)
	local labels = Instance.new("Folder")
	labels.Name = "ZoneLabels"
	labels.Parent = folder
	for zone, anchor in CityGen.zoneAnchors(layout, CityConfig.CellSize) do
		local point = Instance.new("Part")
		point.Name = "Zone" .. zone
		point.Anchored = true
		point.CanCollide = false
		point.CanQuery = false
		point.CanTouch = false
		point.Transparency = 1
		point.Size = Vector3.one
		point.Position = Vector3.new(anchor[1], anchor[2] + 0.5, anchor[3])
		point:SetAttribute("Zone", zone)
		point:SetAttribute("ZoneName", layout.ZoneNames[zone])
		point.Parent = labels
	end

	local buildings = Instance.new("Folder")
	buildings.Name = "Buildings"
	buildings.Parent = folder
	local chunk = Instance.new("Folder")
	for index, placement in layout.Placements do
		if skip and skip[index] then
			continue
		end
		local template = Templates[placement.Template]
		local cframe = CFrame.new(placement.X, placement.Y, placement.Z)
			* CFrame.Angles(0, math.rad(placement.Rotation), 0)
		local model = Builder.build(template, map.Palette, placement.Variant, cframe)
		model:SetAttribute("Tier", template.Tier)
		model:SetAttribute("BuildingId", index)
		model:SetAttribute("Zone", placement.Zone)
		model:SetAttribute("Step", placement.Step)
		model:SetAttribute("Template", placement.Template) -- desastres: condutores do raio etc.
		model.Parent = chunk
		if index % BUILD_CHUNK == 0 then
			for _, child in chunk:GetChildren() do
				child.Parent = buildings
			end
			if shouldYield then
				task.wait()
			end
		end
	end
	for _, child in chunk:GetChildren() do
		child.Parent = buildings
	end
	chunk:Destroy()
	return folder, layout
end

function MapService.clear()
	table.clear(eaten)
	if cityFolder then
		cityFolder:Destroy()
		cityFolder = nil
	end
	currentMap = nil
	currentLayout = nil
end

-- Quantas construções cada zona tem e quantas sobraram, dado o conjunto já comido.
function MapService.zoneCounts(alreadyEaten: { [number]: boolean }): ({ number }, { number })
	local layout = currentLayout :: CityGen.Layout
	local totals, remaining = {}, {}
	for k = 1, #layout.ZoneNames do
		totals[k], remaining[k] = 0, 0
	end
	for index, placement in layout.Placements do
		totals[placement.Zone] += 1
		if not alreadyEaten[index] then
			remaining[placement.Zone] += 1
		end
	end
	return totals, remaining
end

-- Monta a cidade da run com todas as barreiras (a run abre as zonas já limpas com openZone).
-- `alreadyEaten`: BuildingIds comidos antes (run salva). A dificuldade muda o tamanho da cidade.
function MapService.load(map: MapInfo, alreadyEaten: { [number]: boolean }?, difficulty: Difficulty)
	MapService.clear()
	LightingService.applyBiome(map.Biome.Lighting)
	ReplicatedStorage:SetAttribute("RunStyle", map.Style) -- clima do cliente (AmbienceController)
	local folder, layout = buildCity(map, Workspace, true, alreadyEaten, 1, difficulty)
	cityFolder = folder
	currentMap = map
	currentLayout = layout
	stepGrowth = CityProgress.balance(
		layout,
		Templates,
		TierConfig,
		CityPlans[map.Id].FinalScale,
		difficulty.Growth,
		CityConfig.Progression,
		GrowthConfig
	).Multipliers
	zoneTotals = MapService.zoneCounts({})
end

-- Prévia no editor do Studio (sem Play): monta a cidade dentro de `parent`, sem guardar estado de partida.
function MapService.buildPreview(map: MapInfo, parent: Instance): Folder
	LightingService.applyBiome(map.Biome.Lighting)
	local folder = buildCity(map, parent, false, nil, 0, DifficultyConfig[1])
	return folder
end

function MapService.buildingsFolder(): Folder?
	return if cityFolder then cityFolder:FindFirstChild("Buildings") :: Folder? else nil
end

function MapService.zoneNames(): { string }
	return if currentLayout then currentLayout.ZoneNames else {}
end

function MapService.zoneTotal(zone: number): number
	return zoneTotals[zone] or 0
end

-- Multiplicador de crescimento das construções de uma etapa (Logic/CityProgress).
function MapService.stepGrowth(step: number): number
	return stepGrowth[step] or 1
end

-- Um ponto de nascer (na rua) dentro da zona.
function MapService.randomSpawn(zone: number): Vector3
	local layout = currentLayout
	local list = if layout then layout.Spawns[zone] or layout.Spawns[1] else nil
	if list == nil or #list == 0 then
		return Vector3.new(0, 5, 0)
	end
	local spawn = list[math.random(1, #list)]
	return Vector3.new(spawn[1], spawn[2], spawn[3])
end

-- Centro das barreiras de uma zona (para o cliente apontar o caminho até ela).
function MapService.zoneGate(zone: number): Vector3?
	local layout = currentLayout
	if layout == nil then
		return nil
	end
	local sum, count = Vector3.zero, 0
	for _, b in layout.Barriers do
		if b.Zone == zone then
			sum += Vector3.new(b.Pos[1], b.Pos[2], b.Pos[3])
			count += 1
		end
	end
	return if count > 0 then sum / count else nil
end

-- Zona e altura do chão numa posição do mundo (zona 0 = mar / fora da terra; nil = fora da grade).
function MapService.groundAt(x: number, z: number): (number?, number)
	local layout = currentLayout
	if layout == nil then
		return nil, 0
	end
	local grid = layout.Grid
	local cx = math.floor(x / CityConfig.CellSize + grid.Width / 2)
	local cz = math.floor(z / CityConfig.CellSize + grid.Depth / 2)
	if cx < 0 or cz < 0 or cx >= grid.Width or cz >= grid.Depth then
		return nil, 0
	end
	local i = cz * grid.Width + cx + 1
	return grid.Zone[i], grid.Height[i] or 0
end

-- Abre a zona: as barreiras dela somem (o cliente faz o efeito de quebrar).
function MapService.openZone(zone: number)
	local barriers = cityFolder and cityFolder:FindFirstChild("Barriers")
	local folder = barriers and barriers:FindFirstChild("Zone" .. zone)
	if folder then
		folder:Destroy()
	end
end

-- Quantas construções a cidade tem ao todo (comidas ou não).
function MapService.total(): number
	return if currentLayout then #currentLayout.Placements else 0
end

-- Chamado com o BuildingId e a zona de cada construção comida.
function MapService.onConsumed(callback: (number, number) -> ())
	consumedCallback = callback
end

-- Remove a construção do mundo (não volta). Retorna false se já tinha sido comida.
function MapService.consume(model: Model): boolean
	if eaten[model] then
		return false
	end
	eaten[model] = true
	-- O evento de "comida" sai antes de remover, para o cliente ainda conseguir copiar os blocos.
	task.defer(function()
		model:Destroy()
	end)
	local id = model:GetAttribute("BuildingId")
	local zone = model:GetAttribute("Zone")
	if consumedCallback and type(id) == "number" and type(zone) == "number" then
		consumedCallback(id, zone)
	end
	return true
end

function MapService.isEaten(model: Model): boolean
	return eaten[model] == true
end

return MapService
