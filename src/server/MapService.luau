--!strict
-- Monta e desmonta as cidades, controla construções comidas e a regeneração.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MapGen = require(Shared.Logic.MapGen)
local Rng = require(Shared.Logic.Rng)
local Templates = require(Shared.Buildings.Templates)
local MapConfig = require(Shared.Config.MapConfig)
local RoundConfig = require(Shared.Config.RoundConfig)
local Remotes = require(Shared.Remotes)

local Builder = require(script.Parent.Builder)

local BUILD_CHUNK = 20 -- construções por frame ao montar o mapa
local ROAD_TOP = 0.1
local WALK_TOP = 0.15
local WALL_HEIGHT = 2000

export type MapInfo = typeof(MapConfig[1])

local MapService = {}

local cityFolder: Folder? = nil
local currentMap: MapInfo? = nil
local currentLayout: MapGen.Layout? = nil
local generation = 0 -- muda a cada mapa novo; regenerações de um mapa antigo são ignoradas
local eaten: { [Model]: boolean } = {}

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

local function rgb(palette, role: string): Color3
	return Builder.color(palette, role, 0)
end

local function slab(
	parent: Instance,
	name: string,
	size: Vector3,
	position: Vector3,
	color: Color3,
	material: Enum.Material
)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Chão, ruas, calçadas, faixas, paredões de pedra decorativos e paredes invisíveis nas bordas.
local function buildGround(map: MapInfo, layout: MapGen.Layout, parent: Folder)
	local palette = map.Palette
	local sx, sz = layout.Size[1], layout.Size[2]
	local ground = Instance.new("Folder")
	ground.Name = "Ground"

	slab(
		ground,
		"Grass",
		Vector3.new(sx + 400, 4, sz + 400),
		Vector3.new(0, -2, 0),
		rgb(palette, "Ground"),
		Enum.Material.SmoothPlastic
	)

	local road, block = map.RoadWidth, map.BlockSize
	-- Faixa (de 10 studs) que cairia dentro de um cruzamento?
	local function inIntersection(coord: number, total: number): boolean
		local offset = (coord + total / 2) % (block + road)
		return offset < road + 5 or offset > block + road - 5
	end
	local roadColor, lineColor, walkColor = rgb(palette, "Road"), rgb(palette, "RoadLine"), rgb(palette, "Sidewalk")
	for i = 0, map.BlocksX do
		local x = -sx / 2 + road / 2 + i * (block + road)
		slab(
			ground,
			"Road",
			Vector3.new(road, 1, sz),
			Vector3.new(x, ROAD_TOP - 0.5, 0),
			roadColor,
			Enum.Material.SmoothPlastic
		)
		for z = -sz / 2 + 10, sz / 2 - 10, 24 do
			if inIntersection(z, sz) then
				continue
			end
			slab(
				ground,
				"Line",
				Vector3.new(0.8, 1, 10),
				Vector3.new(x, WALK_TOP - 0.5, z),
				lineColor,
				Enum.Material.SmoothPlastic
			)
		end
	end
	for j = 0, map.BlocksZ do
		local z = -sz / 2 + road / 2 + j * (block + road)
		slab(
			ground,
			"Road",
			Vector3.new(sx, 1, road),
			Vector3.new(0, ROAD_TOP - 0.5, z),
			roadColor,
			Enum.Material.SmoothPlastic
		)
		for x = -sx / 2 + 10, sx / 2 - 10, 24 do
			if inIntersection(x, sx) then
				continue
			end
			slab(
				ground,
				"Line",
				Vector3.new(10, 1, 0.8),
				Vector3.new(x, WALK_TOP - 0.5, z),
				lineColor,
				Enum.Material.SmoothPlastic
			)
		end
	end
	-- Calçadas: moldura em volta de cada quarteirão.
	local walk = map.SidewalkWidth
	for _, b in layout.Blocks do
		local x0, z0, x1, z1 = b[1], b[2], b[3], b[4]
		local cx, cz, w, d = (x0 + x1) / 2, (z0 + z1) / 2, x1 - x0, z1 - z0
		slab(
			ground,
			"Walk",
			Vector3.new(w, 1, walk),
			Vector3.new(cx, WALK_TOP - 0.5, z0 + walk / 2),
			walkColor,
			Enum.Material.SmoothPlastic
		)
		slab(
			ground,
			"Walk",
			Vector3.new(w, 1, walk),
			Vector3.new(cx, WALK_TOP - 0.5, z1 - walk / 2),
			walkColor,
			Enum.Material.SmoothPlastic
		)
		slab(
			ground,
			"Walk",
			Vector3.new(walk, 1, d - walk * 2),
			Vector3.new(x0 + walk / 2, WALK_TOP - 0.5, cz),
			walkColor,
			Enum.Material.SmoothPlastic
		)
		slab(
			ground,
			"Walk",
			Vector3.new(walk, 1, d - walk * 2),
			Vector3.new(x1 - walk / 2, WALK_TOP - 0.5, cz),
			walkColor,
			Enum.Material.SmoothPlastic
		)
	end

	-- Paredões em degraus (rocha rosada com topo verde), como o cânion da referência 1.
	local rock, rockDark, top = Color3.fromRGB(200, 120, 120), Color3.fromRGB(170, 95, 105), Color3.fromRGB(70, 200, 90)
	local margin = 60
	for side = 1, 4 do
		local horizontal = side <= 2
		local sign = if side % 2 == 1 then -1 else 1
		local length = (if horizontal then sx else sz) + margin * 2 + 160
		for step = 0, 2 do
			local height = 40 + step * 35
			local depth = 30
			local offset = (if horizontal then sz else sx) / 2 + margin + step * depth + depth / 2
			local size = if horizontal then Vector3.new(length, height, depth) else Vector3.new(depth, height, length)
			local pos = if horizontal
				then Vector3.new(0, height / 2, sign * offset)
				else Vector3.new(sign * offset, height / 2, 0)
			slab(ground, "Cliff", size, pos, if step % 2 == 0 then rock else rockDark, Enum.Material.SmoothPlastic)
			local capSize = size + Vector3.new(0, 4 - height, 0)
			slab(ground, "CliffTop", capSize, pos + Vector3.new(0, height / 2 + 2, 0), top, Enum.Material.SmoothPlastic)
		end
	end

	-- Paredes invisíveis: ninguém sai do mapa (SHOULDN'T REACH).
	local half = Vector3.new(sx / 2 + margin, 0, sz / 2 + margin)
	for _, spec in
		{
			{ Vector3.new(sx + margin * 2, WALL_HEIGHT, 4), Vector3.new(0, WALL_HEIGHT / 2, -half.Z) },
			{ Vector3.new(sx + margin * 2, WALL_HEIGHT, 4), Vector3.new(0, WALL_HEIGHT / 2, half.Z) },
			{ Vector3.new(4, WALL_HEIGHT, sz + margin * 2), Vector3.new(-half.X, WALL_HEIGHT / 2, 0) },
			{ Vector3.new(4, WALL_HEIGHT, sz + margin * 2), Vector3.new(half.X, WALL_HEIGHT / 2, 0) },
		}
	do
		local wall = slab(ground, "Boundary", spec[1], spec[2], Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
		wall.Transparency = 1
		wall.CastShadow = false
	end

	ground.Parent = parent
end

function MapService.clear()
	generation += 1
	table.clear(eaten)
	if cityFolder then
		cityFolder:Destroy()
		cityFolder = nil
	end
	currentMap = nil
	currentLayout = nil
end

-- Monta o mapa em partes (não trava o servidor). Retorna quando terminar.
function MapService.load(map: MapInfo)
	MapService.clear()
	local layout = MapGen.generate(map, Templates, Rng.new(map.Seed))
	local folder = Instance.new("Folder")
	folder.Name = "City"
	buildGround(map, layout, folder)

	local buildings = Instance.new("Folder")
	buildings.Name = "Buildings"
	buildings.Parent = folder
	folder.Parent = Workspace

	local chunk = Instance.new("Folder")
	for index, placement in layout.Placements do
		local template = Templates[placement.Template]
		local cframe = CFrame.new(placement.X, 0, placement.Z) * CFrame.Angles(0, math.rad(placement.Rotation), 0)
		local model = Builder.build(template, map.Palette, placement.Variant, cframe)
		model:SetAttribute("Tier", template.Tier)
		model:SetAttribute("BuildingId", index)
		model.Parent = chunk
		if index % BUILD_CHUNK == 0 then
			for _, child in chunk:GetChildren() do
				child.Parent = buildings
			end
			task.wait()
		end
	end
	for _, child in chunk:GetChildren() do
		child.Parent = buildings
	end
	chunk:Destroy()

	cityFolder = folder
	currentMap = map
	currentLayout = layout
end

function MapService.buildingsFolder(): Folder?
	return if cityFolder then cityFolder:FindFirstChild("Buildings") :: Folder? else nil
end

function MapService.randomSpawn(): Vector3
	local layout = currentLayout
	if layout == nil or #layout.Spawns == 0 then
		return Vector3.new(0, 5, 0)
	end
	local spawn = layout.Spawns[math.random(1, #layout.Spawns)]
	return Vector3.new(spawn[1], 5, spawn[2])
end

-- Algum personagem está dentro da área da construção? (evita renascer prédio em cima de alguém)
local function occupied(model: Model): boolean
	local cframe, size = model:GetBoundingBox()
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local characters = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(characters, player.Character)
		end
	end
	if #characters == 0 then
		return false
	end
	params.FilterDescendantsInstances = characters
	return #Workspace:GetPartBoundsInBox(cframe, size + Vector3.new(2, 2, 2), params) > 0
end

local function scheduleRegen(model: Model, myGeneration: number)
	task.delay(RoundConfig.RegenSeconds, function()
		while generation == myGeneration and occupied(model) do
			task.wait(2)
		end
		local buildings = MapService.buildingsFolder()
		if generation ~= myGeneration or buildings == nil then
			model:Destroy()
			return
		end
		eaten[model] = nil
		model.Parent = buildings
		Remotes.event(Remotes.Names.Events.BuildingRegenerated):FireAllClients(model)
	end)
end

-- Remove a construção do mundo e agenda a volta dela. Retorna false se já tinha sido comida.
function MapService.consume(model: Model): boolean
	if eaten[model] then
		return false
	end
	eaten[model] = true
	-- O evento de "comida" sai antes de remover, para o cliente ainda conseguir copiar os blocos.
	task.defer(function()
		model.Parent = nil
	end)
	scheduleRegen(model, generation)
	return true
end

function MapService.isEaten(model: Model): boolean
	return eaten[model] == true
end

return MapService
