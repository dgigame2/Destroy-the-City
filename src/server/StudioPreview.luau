--!strict
-- Prévia de um mapa NO EDITOR do Studio (sem dar Play), para olhar, voar pela câmera e medir peças.
-- Uso, na barra de comandos do Studio (Exibir > Barra de comandos):
--   require(game.ServerScriptService.Server.StudioPreview).show("GardenVillage")
--   require(game.ServerScriptService.Server.StudioPreview).show(3)      -- pelo número do mapa (1 a 3)
--   require(game.ServerScriptService.Server.StudioPreview).clear()      -- apaga a prévia
-- A prévia fica na pasta Workspace.StudioPreview com Archivable = false: ela NÃO é salva no arquivo
-- do jogo e NÃO entra no Play (o jogo monta tudo sozinho quando começa).

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.MapConfig)

local CityWorld = require(ReplicatedStorage.Shared.City.CityWorld)
local DifficultyConfig = require(ReplicatedStorage.Shared.Config.DifficultyConfig)
local LightingService = require(script.Parent.LightingService)

local StudioPreview = {}

local FOLDER_NAME = "StudioPreview"

local function findMap(which: string | number?): MapConfig.MapInfo?
	if which == nil then
		return MapConfig[1]
	end
	if type(which) == "number" then
		return MapConfig[which]
	end
	for _, map in MapConfig do
		if map.Id == which or string.lower(map.DisplayName) == string.lower(which :: string) then
			return map
		end
	end
	return nil
end

function StudioPreview.clear()
	local existing = Workspace:FindFirstChild(FOLDER_NAME)
	if existing then
		existing:Destroy()
	end
end

function StudioPreview.show(which: string | number?)
	local map = findMap(which)
	if map == nil then
		local names = {}
		for index, m in MapConfig do
			table.insert(names, `{index} = "{m.Id}" ({m.DisplayName})`)
		end
		warn("[StudioPreview] mapa não encontrado. Opções: " .. table.concat(names, ", "))
		return
	end
	StudioPreview.clear()
	local started = os.clock()
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Archivable = false
	folder.Parent = Workspace

	LightingService.apply()
	LightingService.applyBiome(map.Biome.Lighting)
	-- a mesma montagem do cliente na partida (CityWorld), na escala da 1ª dificuldade
	local layout = CityWorld.layout(map, DifficultyConfig[1].MapScale)
	CityWorld.terrain(map, layout, folder, false)
	local buildings = Instance.new("Folder")
	buildings.Name = "Buildings"
	buildings.Parent = folder
	for id, placement in layout.Placements do
		CityWorld.building(map, placement, id).Parent = buildings
	end
	local parts = 0
	for _, d in folder:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	print(
		`[StudioPreview] {map.DisplayName}: {#layout.Placements} construções, {parts} peças, montado em `
			.. `{string.format("%.1f", os.clock() - started)}s. `
			.. "Para apagar: require(game.ServerScriptService.Server.StudioPreview).clear()"
	)
end

return StudioPreview
