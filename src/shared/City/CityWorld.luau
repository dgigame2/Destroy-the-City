--!strict
-- Monta a cidade no CLIENTE a partir do layout (Logic/CityGen), que é o mesmo em todo mundo pela semente.
-- Nada disso é replicado: o servidor só guarda dados (Logic/CityState). Chão, costa e decoração saem do
-- CityTerrain; cada construção vira um Model com o BuildingId = índice da Placement.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CityGen = require(Shared.Logic.CityGen)
local CityTerrain = require(Shared.Logic.CityTerrain)
local Rng = require(Shared.Logic.Rng)
local Templates = require(Shared.Buildings.Templates)
local CityConfig = require(Shared.Config.CityConfig)
local CityPlans = require(Shared.Config.CityPlans)
local DistrictConfig = require(Shared.Config.DistrictConfig)
local MapConfig = require(Shared.Config.MapConfig)

local Builder = require(script.Parent.Builder)

local CityWorld = {}

export type MapInfo = MapConfig.MapInfo

function CityWorld.map(id: string): MapInfo?
	for _, map in MapConfig do
		if map.Id == id then
			return map
		end
	end
	return nil
end

-- Mesmo layout em servidor e clientes (determinístico).
function CityWorld.layout(map: MapInfo, mapScale: number): CityGen.Layout
	return CityGen.generate(
		CityPlans[map.Id],
		DistrictConfig[map.Style],
		Templates,
		Rng.new(map.Seed),
		CityConfig,
		mapScale
	)
end

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- Chão, faixas, terra, mar e paredes invisíveis da costa; cenário fora da cidade (não é comível).
function CityWorld.terrain(map: MapInfo, layout: CityGen.Layout, parent: Instance, shouldYield: boolean)
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
		local checker = data.Checker
		if checker then
			-- 2º tom do xadrez: imagem 2x2 tingida no topo (CityConfig.CheckerTexture), em vez de 1 peça por quadrado
			local texture = Instance.new("Texture")
			texture.Face = Enum.NormalId.Top
			texture.Texture = CityConfig.CheckerTexture.Id
			texture.Color3 = rgb(checker.Color)
			texture.StudsPerTileU = checker.Tile
			texture.StudsPerTileV = checker.Tile
			texture.OffsetStudsU = checker.OffsetU
			texture.OffsetStudsV = checker.OffsetV
			texture.Parent = part
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

-- Uma construção (sem pai). Atributos: BuildingId, Tier, Template.
function CityWorld.building(map: MapInfo, placement: CityGen.Placement, id: number): Model
	local template = Templates[placement.Template]
	local cframe = CFrame.new(placement.X, placement.Y, placement.Z) * CFrame.Angles(0, math.rad(placement.Rotation), 0)
	local model = Builder.build(template, map.Palette, placement.Variant, cframe)
	model:SetAttribute("BuildingId", id)
	model:SetAttribute("Tier", template.Tier)
	model:SetAttribute("Template", placement.Template)
	return model
end

return CityWorld
