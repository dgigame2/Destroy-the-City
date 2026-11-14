--!strict
-- Os 5 mapas do jogo. Cada um gera uma cidade diferente (mistura de construções, cores e marco central).
-- Cores em RGB 0-255. Listas de cores são sorteadas por construção (Variant).
-- WinScale: tamanho que um jogador precisa atingir para "comer o mapa todo" e vencer a partida.

type RGB = { number }

export type Palette = { [string]: { RGB } }

export type MapInfo = {
	Id: string,
	DisplayName: string,
	Icon: string, -- emoji mostrado no card de votação
	Seed: number,
	BlocksX: number,
	BlocksZ: number,
	BlockSize: number,
	RoadWidth: number,
	SidewalkWidth: number,
	BuildingMix: { [string]: number },
	Landmark: string,
	ParkedCarChance: number,
	ParkChance: number,
	NatureMix: { [string]: number },
	WinScale: number,
	Palette: Palette,
}

-- Paleta base no estilo da referência 2 (blocos em tons pastel, telhados escuros saturados).
local BASE: Palette = {
	Wall = { { 236, 222, 205 }, { 214, 226, 240 }, { 245, 214, 214 }, { 220, 236, 214 }, { 240, 232, 196 } },
	Roof = { { 150, 40, 70 }, { 40, 60, 140 }, { 30, 110, 110 }, { 70, 50, 120 } },
	Trim = { { 245, 245, 250 } },
	Window = { { 120, 190, 255 } },
	Glass = { { 150, 210, 255 } },
	Door = { { 40, 90, 200 }, { 200, 50, 80 }, { 60, 60, 70 } },
	Garage = { { 210, 215, 225 } },
	Chimney = { { 140, 50, 60 } },
	Awning = { { 230, 70, 90 }, { 60, 170, 230 }, { 250, 180, 50 } },
	Sign = { { 255, 210, 60 }, { 60, 200, 255 }, { 255, 90, 160 } },
	Accent = { { 230, 60, 70 }, { 60, 120, 230 }, { 240, 160, 60 }, { 150, 70, 200 } },
	Metal = { { 120, 125, 140 } },
	Trunk = { { 120, 80, 50 } },
	Leaves = { { 70, 190, 90 }, { 90, 210, 110 }, { 60, 170, 120 } },
	Body = { { 40, 200, 110 }, { 230, 70, 70 }, { 60, 130, 240 }, { 250, 200, 60 }, { 245, 245, 245 } },
	Tire = { { 35, 35, 40 } },
	Light = { { 255, 235, 170 } },
	Dome = { { 40, 130, 140 } },
	WallWhite = { { 248, 246, 240 } },
	Beam = { { 120, 78, 52 } },
	Stone = { { 190, 186, 200 }, { 176, 172, 188 } },
	Brick = { { 200, 96, 84 }, { 176, 82, 92 } },
	Rock = { { 150, 150, 170 }, { 130, 128, 150 } },
	Pine = { { 40, 150, 80 }, { 52, 170, 92 } },
	Stem = { { 245, 236, 220 } },
	Cap = { { 235, 70, 80 }, { 180, 90, 220 }, { 70, 140, 240 } },
	Flower = { { 255, 120, 170 }, { 255, 210, 70 } },
	Flower2 = { { 160, 120, 255 }, { 255, 255, 255 } },
	Pot = { { 200, 110, 70 } },
	Cone = { { 255, 130, 40 } },
	Water = { { 90, 190, 255 } },
	Bus = { { 255, 200, 40 }, { 70, 160, 240 } },
	Tank = { { 120, 200, 230 }, { 240, 240, 245 } },
	Clock = { { 255, 250, 235 } },
	Ground = { { 90, 205, 90 } },
	Road = { { 60, 64, 80 } },
	Sidewalk = { { 200, 200, 215 } },
	RoadLine = { { 245, 245, 245 } },
}

-- Copia a paleta base trocando só o que o mapa quer diferente.
local function palette(overrides: Palette): Palette
	local result = table.clone(BASE)
	for role, colors in overrides do
		result[role] = colors
	end
	return table.freeze(result)
end

-- Natureza padrão do miolo dos quarteirões (referências de mapa: pinheiros, árvores redondas, cogumelos).
local NATURE = { Tree = 4, Pine = 3, Bush = 3, Rock = 1.5, Mushroom = 2, FlowerPot = 1.5 }

local maps: { MapInfo } = {
	{
		Id = "GardenVillage",
		Icon = "🏡",
		DisplayName = "Garden Village",
		Seed = 1101,
		BlocksX = 5,
		BlocksZ = 5,
		BlockSize = 110,
		RoadWidth = 26,
		SidewalkWidth = 6,
		BuildingMix = {
			House = 8,
			Cottage = 5,
			BigHouse = 5,
			Shop = 2,
			GasStation = 0.8,
			Apartment = 1.5,
			WaterTower = 0.6,
			Museum = 0.4,
			ClockTower = 0.3,
			Tower = 0.3,
		},
		Landmark = "Stadium",
		ParkedCarChance = 0.35,
		ParkChance = 0.18,
		NatureMix = NATURE,
		WinScale = 20,
		Palette = palette({}),
	},
	{
		Id = "Downtown",
		Icon = "🏙️",
		DisplayName = "Downtown",
		Seed = 2202,
		BlocksX = 5,
		BlocksZ = 5,
		BlockSize = 110,
		RoadWidth = 28,
		SidewalkWidth = 6,
		BuildingMix = {
			Shop = 5,
			Apartment = 5,
			Tower = 1.5,
			ClockTower = 0.6,
			BigHouse = 2,
			House = 2,
			GasStation = 0.8,
			Museum = 0.5,
		},
		Landmark = "Skyscraper",
		ParkedCarChance = 0.5,
		ParkChance = 0.12,
		NatureMix = NATURE,
		WinScale = 22,
		Palette = palette({
			Wall = { { 210, 220, 235 }, { 190, 200, 220 }, { 235, 225, 210 }, { 200, 215, 230 } },
			Roof = { { 50, 60, 110 }, { 70, 80, 100 }, { 40, 100, 130 } },
		}),
	},
	{
		Id = "Harbor",
		Icon = "⚓",
		DisplayName = "Harbor",
		Seed = 3303,
		BlocksX = 5,
		BlocksZ = 5,
		BlockSize = 110,
		RoadWidth = 26,
		SidewalkWidth = 6,
		BuildingMix = {
			Warehouse = 5,
			WaterTower = 1.5,
			Shop = 2,
			House = 3,
			Cottage = 2,
			BigHouse = 2,
			GasStation = 1,
			Apartment = 2,
			Tower = 0.5,
		},
		Landmark = "Skyscraper",
		ParkedCarChance = 0.45,
		ParkChance = 0.1,
		NatureMix = NATURE,
		WinScale = 21,
		Palette = palette({
			Wall = { { 240, 200, 160 }, { 200, 220, 240 }, { 230, 180, 170 }, { 210, 210, 190 } },
			Roof = { { 170, 70, 40 }, { 40, 90, 150 }, { 90, 90, 100 } },
			Ground = { { 110, 200, 120 } },
		}),
	},
	{
		Id = "MuseumDistrict",
		Icon = "🏛️",
		DisplayName = "Museum District",
		Seed = 4404,
		BlocksX = 5,
		BlocksZ = 5,
		BlockSize = 110,
		RoadWidth = 26,
		SidewalkWidth = 6,
		BuildingMix = {
			House = 4,
			Cottage = 3,
			BigHouse = 4,
			Shop = 3,
			Apartment = 2,
			Museum = 1.5,
			ClockTower = 0.8,
			Tower = 0.5,
		},
		Landmark = "Stadium",
		ParkedCarChance = 0.3,
		ParkChance = 0.22,
		NatureMix = NATURE,
		WinScale = 21,
		Palette = palette({
			Wall = { { 245, 235, 220 }, { 225, 215, 245 }, { 215, 240, 235 }, { 250, 220, 200 } },
			Roof = { { 120, 40, 120 }, { 40, 120, 120 }, { 160, 50, 60 } },
			Leaves = { { 240, 160, 200 }, { 90, 210, 110 }, { 70, 190, 90 } },
		}),
	},
	{
		Id = "Metropolis",
		Icon = "🌆",
		DisplayName = "Metropolis",
		Seed = 5505,
		BlocksX = 6,
		BlocksZ = 6,
		BlockSize = 110,
		RoadWidth = 30,
		SidewalkWidth = 6,
		BuildingMix = {
			Apartment = 5,
			Tower = 2.5,
			ClockTower = 0.8,
			Shop = 4,
			Warehouse = 1.5,
			WaterTower = 0.8,
			BigHouse = 1,
			House = 1,
		},
		Landmark = "Skyscraper",
		ParkedCarChance = 0.55,
		ParkChance = 0.1,
		NatureMix = NATURE,
		WinScale = 24,
		Palette = palette({
			Wall = { { 190, 205, 230 }, { 220, 225, 235 }, { 170, 190, 220 }, { 235, 215, 200 } },
			Roof = { { 30, 50, 100 }, { 60, 60, 80 }, { 30, 120, 150 } },
		}),
	},
}

for _, map in maps do
	table.freeze(map.BuildingMix)
	table.freeze(map)
end

return table.freeze(maps)
