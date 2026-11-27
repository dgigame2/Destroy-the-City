--!strict
-- Os 3 mapas do jogo (capítulos, na ordem). Cada um é uma cidade inteira num estilo (referências do usuário):
--   1. Garden Village: cidade verde numa ilha (subúrbios, parque do lago, aeroporto, centro com usina e rio);
--   2. Palm Beach: cidade de praia com orla, porto, rio e parque de diversões, cercada de praia;
--   3. Frost City: cidade de neve cortada por rios, com porto, aeroporto e usina, num mar congelado.
-- A planta de cada cidade fica em CityPlans; o que cada bairro tem, em DistrictConfig (pelo Style).
-- Cores em RGB 0-255. Listas de cores são sorteadas por construção (Variant).
-- Vitória da run: comer todas as construções do mapa (RunConfig / Logic/Runs).

type RGB = { number }

export type Palette = { [string]: { RGB } }

export type Biome = {
	Border: string, -- "Island" | "Beach" | "IceSea" (Logic/CityTerrain)
	Ground: { RGB }, -- xadrez da grama dos terrenos
	Wild: { RGB }, -- margem natural entre a cidade e o mar (CityGen Coast.Wild)
	Road: { RGB },
	RoadLine: RGB,
	Walk: RGB, -- calçada
	Water: RGB,
	Sand: { RGB },
	Plaza: { RGB },
	Asphalt: { RGB },
	Runway: { RGB },
	Base: { RGB }, -- terra embaixo do chão (beirada na costa)
	SeaLevel: number, -- altura da superfície do mar (abaixo do chão)
	Sea: { RGB }, -- água rasa e funda (ou gelo)
	Foam: RGB, -- espuma colada na costa
	Mountain: { RGB }, -- montanhas do horizonte (de baixo para cima)
	MountainTop: RGB,
	MarginDecor: { [string]: number }, -- árvores das ilhotas (não é comível)
	SeaDecor: { [string]: number }, -- barcos, pedras, icebergs no mar
	-- clima do mapa (server/LightingService.applyBiome)
	Lighting: {
		Ambient: RGB,
		OutdoorAmbient: RGB,
		AtmosphereColor: RGB,
		AtmosphereDecay: RGB,
		AtmosphereDensity: number,
		Haze: number,
		Glare: number,
		Saturation: number,
		Contrast: number,
		TintColor: RGB,
		ClockTime: number,
		Brightness: number,
		ShadowSoftness: number,
		Bloom: { Intensity: number, Size: number, Threshold: number },
		SunRays: { Intensity: number, Spread: number },
		Clouds: { Cover: number, Density: number, Color: RGB },
	},
}

export type MapInfo = {
	Id: string,
	DisplayName: string,
	Icon: string, -- emoji do capítulo na tela CREATE PARTY
	Seed: number,
	Style: string, -- conjunto de bairros (DistrictConfig): "Garden" | "Beach" | "Frost"
	RequiredWins: number, -- vitórias da conta para liberar este capítulo
	Palette: Palette,
	Biome: Biome,
}

-- Paleta base no estilo das referências de mapa: blocos com stud, cores saturadas de desenho animado.
local BASE: Palette = {
	Wall = { { 255, 222, 160 }, { 160, 206, 255 }, { 255, 170, 170 }, { 180, 236, 150 }, { 255, 234, 120 } },
	WallWhite = { { 250, 248, 240 } },
	Roof = { { 214, 54, 66 }, { 48, 110, 220 }, { 32, 160, 140 }, { 130, 70, 200 } },
	RoofTop = { { 214, 54, 66 }, { 48, 110, 220 }, { 32, 160, 140 }, { 130, 70, 200 } },
	Trim = { { 250, 250, 252 } },
	Window = { { 110, 200, 255 } },
	Glass = { { 150, 220, 255 } },
	Door = { { 160, 100, 56 }, { 220, 60, 80 }, { 50, 110, 220 } },
	Garage = { { 214, 218, 228 } },
	Chimney = { { 170, 70, 60 } },
	Awning = { { 236, 52, 64 }, { 30, 150, 245 }, { 250, 180, 30 } },
	Stripe = { { 255, 255, 255 }, { 255, 255, 255 }, { 255, 255, 255 } },
	Sign = { { 255, 214, 50 }, { 70, 210, 255 }, { 255, 100, 170 } },
	Accent = { { 236, 60, 70 }, { 50, 120, 236 }, { 250, 160, 40 }, { 150, 70, 210 } },
	Metal = { { 120, 126, 142 } },
	Trunk = { { 150, 96, 52 } },
	Beam = { { 170, 110, 60 } },
	Plank = { { 230, 186, 104 } },
	Leaves = { { 84, 200, 40 }, { 60, 184, 50 }, { 110, 214, 44 } },
	Leaves2 = { { 120, 226, 60 }, { 92, 210, 70 }, { 146, 232, 70 } },
	Pine = { { 34, 150, 70 }, { 40, 164, 84 } },
	-- árvores de blocos: papéis próprios para a copa ficar quadrada (Leaves/Pine viram copa low-poly no MeshKit)
	Bark = { { 128, 102, 92 } },
	Canopy = { { 84, 160, 66 } },
	CanopyTop = { { 140, 196, 80 } },
	CanopyDark = { { 62, 130, 58 } },
	-- parquinho e bancos
	ToyWood = { { 232, 178, 92 } },
	ToyLeg = { { 196, 112, 50 } },
	ToyMetal = { { 124, 132, 170 } },
	ToyRed = { { 224, 52, 62 } },
	ToyPurple = { { 160, 56, 210 } },
	ToyYellow = { { 250, 180, 30 } },
	ToyDark = { { 84, 90, 104 } },
	LampDark = { { 88, 68, 64 } },
	Steel = { { 148, 152, 178 } },
	ToyBlue = { { 0, 104, 250 } },
	ToyBlueDark = { { 0, 78, 200 } },
	ContainerYellow = { { 255, 210, 20 } },
	Cardboard = { { 240, 184, 98 } },
	Tape = { { 208, 124, 48 } },
	TruckGreen = { { 40, 164, 48 } },
	TruckMid = { { 30, 130, 42 } },
	TruckDark = { { 24, 98, 52 } },
	TruckLime = { { 140, 216, 70 } },
	TruckCab = { { 0, 140, 246 } },
	-- branco do avião mais escuro que o WallWhite: com a luz do jogo, o claro estoura e apaga as faces
	PlaneBody = { { 212, 213, 224 } },
	PlaneFlap = { { 188, 192, 208 } },
	PlaneBand = { { 112, 176, 230 } },
	PlaneWindow = { { 34, 122, 200 } },
	TowerBlue = { { 78, 114, 204 } },
	TowerNavy = { { 36, 62, 140 } },
	TowerRoof = { { 94, 146, 222 } },
	TowerGlass = { { 64, 180, 250 } },
	FenceWood = { { 166, 102, 66 } },
	FenceBase = { { 122, 80, 70 } },
	-- casas do Blender (build_houses.py): cores fixas, iguais às imagens
	HouseWall = { { 246, 236, 226 } },
	HouseTrim = { { 238, 206, 170 } },
	RoofOrange = { { 238, 128, 28 } },
	RoofTeal = { { 24, 166, 156 } },
	-- casas grandes do Blender (Townhouse, Villa = GableHouse, BigHouse = Mansion)
	RoofBrown = { { 150, 74, 46 } },
	RoofNavy = { { 70, 82, 148 } },
	RoofClay = { { 198, 84, 56 } },
	-- floricultura (CornerFlowers)
	FlowerPink = { { 236, 84, 150 } },
	PinkLight = { { 250, 196, 218 } },
	Body = { { 40, 200, 110 }, { 236, 64, 64 }, { 50, 130, 245 }, { 252, 200, 50 }, { 245, 245, 245 } },
	Tire = { { 40, 40, 46 } },
	Light = { { 255, 236, 160 } },
	Dome = { { 40, 150, 160 } },
	Stone = { { 196, 192, 206 }, { 180, 176, 194 } },
	Brick = { { 206, 96, 80 }, { 184, 80, 90 } },
	Rock = { { 150, 150, 168 }, { 132, 130, 150 } },
	Sandstone = { { 226, 172, 104 }, { 206, 150, 88 } },
	Stem = { { 245, 236, 220 } },
	Cap = { { 206, 46, 50 }, { 138, 98, 60 }, { 140, 66, 172 } },
	CapSpot = { { 246, 240, 236 }, { 124, 86, 52 }, { 214, 170, 236 } }, -- mesma ordem do Cap
	Petal = { { 246, 246, 250 }, { 238, 122, 184 }, { 246, 204, 56 } },
	PetalCore = { { 246, 180, 40 } },
	Parasol = { { 214, 56, 60 }, { 58, 118, 214 } },
	RockDark = { { 112, 114, 136 } },
	Flower = { { 255, 110, 170 }, { 255, 214, 60 } },
	Flower2 = { { 170, 120, 255 }, { 255, 255, 255 } },
	Pot = { { 210, 112, 66 } },
	Cone = { { 255, 130, 30 } },
	Water = { { 80, 190, 255 } },
	Bus = { { 255, 200, 30 }, { 60, 160, 245 } },
	Tank = { { 120, 206, 236 }, { 240, 240, 246 } },
	Clock = { { 255, 250, 235 } },
	Cactus = { { 54, 180, 110 }, { 40, 160, 96 } },
	DeadWood = { { 64, 62, 76 } },
	Snow = { { 248, 252, 255 } },
	Ice = { { 150, 226, 255 }, { 120, 206, 250 } },
	Towel = { { 255, 220, 60 }, { 255, 120, 160 }, { 90, 200, 255 } },
	Sidewalk = { { 206, 206, 222 } },
	-- cidades novas (CityBuildings)
	Grass = { { 92, 200, 70 } }, -- gramado do campo de futebol
	Line = { { 250, 250, 255 } }, -- linhas brancas, traves
	Container = { { 220, 70, 60 }, { 50, 120, 220 }, { 60, 170, 90 }, { 245, 150, 40 } },
	Hull = { { 40, 60, 110 }, { 190, 50, 60 } },
	Pool = { { 70, 210, 245 } },
	Concrete = { { 226, 226, 232 } },
	Red = { { 220, 56, 64 } },
}

-- Copia a paleta base trocando só o que o mapa quer diferente.
-- O topo do telhado acompanha o telhado, a não ser que o mapa mude (neve).
local function palette(overrides: Palette): Palette
	local result = table.clone(BASE)
	for role, colors in overrides do
		result[role] = colors
	end
	if overrides.Roof and not overrides.RoofTop then
		result.RoofTop = overrides.Roof
	end
	return table.freeze(result)
end

local function biome(def: Biome): Biome
	return table.freeze(def)
end

local maps: { MapInfo } = {
	{
		Id = "GardenVillage",
		RequiredWins = 0,
		Icon = "🌼",
		DisplayName = "Garden Village",
		Seed = 1101,
		Style = "Garden",
		-- referência: casas claras com telhado marrom/vermelho, torres azul-claro, árvores redondas
		Palette = palette({
			Wall = { { 250, 247, 240 }, { 244, 236, 220 }, { 236, 242, 250 }, { 250, 230, 214 }, { 246, 240, 228 } },
			WallWhite = { { 252, 251, 248 } },
			Roof = { { 168, 74, 56 }, { 124, 78, 56 }, { 196, 96, 64 }, { 72, 112, 150 } },
			Glass = { { 176, 216, 248 }, { 196, 226, 250 } },
			Window = { { 150, 200, 240 } },
			Leaves = { { 74, 176, 62 }, { 92, 192, 70 }, { 62, 160, 60 } },
			Leaves2 = { { 104, 204, 80 }, { 86, 190, 72 }, { 120, 214, 86 } },
			Pine = { { 52, 150, 70 }, { 60, 164, 80 } },
		}),
		Biome = biome({
			Border = "Island",
			Ground = { { 122, 204, 82 }, { 110, 194, 74 } },
			Wild = { { 108, 192, 70 }, { 98, 182, 64 } },
			Road = { { 196, 174, 142 }, { 188, 166, 134 } },
			RoadLine = { 250, 248, 240 },
			Walk = { 236, 232, 222 },
			Water = { 52, 112, 196 }, -- rio azul fundo (referência de rio de cidade)
			Sand = { { 122, 204, 82 }, { 110, 194, 74 } }, -- sem praia: a grama vai até o mar
			Plaza = { { 214, 206, 214 }, { 200, 192, 204 } },
			Asphalt = { { 120, 122, 134 }, { 110, 112, 124 } },
			Runway = { { 84, 86, 96 }, { 78, 80, 90 } },
			Base = { { 150, 98, 60 }, { 128, 82, 50 } },
			SeaLevel = -1.2,
			Sea = { { 96, 206, 240 }, { 46, 136, 222 } },
			Foam = { 236, 248, 255 },
			Mountain = { { 92, 182, 70 }, { 74, 160, 60 }, { 120, 124, 138 } },
			MountainTop = { 246, 249, 252 },
			MarginDecor = { Tree = 1.5, Oak = 1.25, BentTree = 1.25, Pine = 2, Bush = 1, WideBush = 1 },
			SeaDecor = { Boat = 3, Rock = 1, FlatRock = 0.5, TallRock = 0.5, Yacht = 1 },
			-- manhã ensolarada de primavera: sol quente, sombras macias, céu com nuvens fofas
			Lighting = {
				Ambient = { 124, 118, 128 },
				OutdoorAmbient = { 158, 152, 160 },
				AtmosphereColor = { 196, 220, 255 },
				AtmosphereDecay = { 120, 156, 232 },
				AtmosphereDensity = 0.12,
				Haze = 0.4,
				Glare = 0.35,
				Saturation = 0.32, -- cores vivas mas macias (referências)
				Contrast = 0.06,
				TintColor = { 255, 248, 236 },
				ClockTime = 10.6,
				Brightness = 2.6,
				ShadowSoftness = 0.55,
				Bloom = { Intensity = 0.5, Size = 28, Threshold = 1.4 },
				SunRays = { Intensity = 0.1, Spread = 0.7 },
				Clouds = { Cover = 0.62, Density = 0.6, Color = { 255, 255, 255 } },
			},
		}),
	},
	{
		Id = "Harbor",
		RequiredWins = 1,
		Icon = "🏝️",
		DisplayName = "Palm Beach",
		Seed = 3303,
		Style = "Beach",
		Palette = palette({
			Wall = { { 255, 226, 170 }, { 160, 226, 255 }, { 255, 186, 170 }, { 180, 246, 210 }, { 250, 250, 250 } },
			Roof = { { 255, 120, 60 }, { 40, 120, 220 }, { 30, 180, 160 } },
		}),
		Biome = biome({
			Border = "Beach",
			Ground = { { 128, 214, 80 }, { 114, 202, 70 } },
			Wild = { { 248, 226, 160 }, { 240, 214, 144 } }, -- ilha de areia
			Road = { { 150, 154, 168 }, { 140, 144, 158 } },
			RoadLine = { 255, 255, 255 },
			Walk = { 244, 230, 196 },
			Water = { 46, 140, 210 },
			Sand = { { 248, 224, 150 }, { 240, 212, 134 } },
			Plaza = { { 250, 236, 200 }, { 236, 220, 184 } },
			Asphalt = { { 126, 128, 140 }, { 116, 118, 130 } },
			Runway = { { 90, 92, 102 }, { 84, 86, 96 } },
			Base = { { 236, 200, 130 }, { 220, 184, 114 } },
			SeaLevel = -0.5,
			Sea = { { 96, 204, 232 }, { 40, 150, 214 } },
			Foam = { 246, 252, 255 },
			Mountain = { { 116, 196, 92 }, { 92, 174, 80 }, { 206, 176, 124 } },
			MountainTop = { 134, 210, 110 },
			MarginDecor = { Palm = 4, Bush = 2, Umbrella = 1 },
			SeaDecor = { Boat = 3, Yacht = 2, Rock = 0.4, FlatRock = 0.3, TallRock = 0.3 },
			-- tarde tropical: sol forte, mar turquesa brilhante, poucas nuvens
			Lighting = {
				Ambient = { 134, 128, 130 },
				OutdoorAmbient = { 168, 162, 160 },
				AtmosphereColor = { 200, 232, 255 },
				AtmosphereDecay = { 96, 176, 240 },
				AtmosphereDensity = 0.1,
				Haze = 0.3,
				Glare = 0.5,
				Saturation = 0.34,
				Contrast = 0.06,
				TintColor = { 255, 246, 230 },
				ClockTime = 15.2,
				Brightness = 3,
				ShadowSoftness = 0.5,
				Bloom = { Intensity = 0.55, Size = 26, Threshold = 1.35 },
				SunRays = { Intensity = 0.12, Spread = 0.8 },
				Clouds = { Cover = 0.5, Density = 0.45, Color = { 255, 255, 255 } },
			},
		}),
	},
	{
		Id = "Metropolis",
		RequiredWins = 3,
		Icon = "❄️",
		DisplayName = "Frost City",
		Seed = 5505,
		Style = "Frost",
		Palette = palette({
			Wall = { { 170, 200, 245 }, { 214, 224, 245 }, { 150, 180, 230 }, { 240, 244, 252 } },
			Roof = { { 40, 70, 140 }, { 70, 80, 110 }, { 30, 130, 160 } },
			RoofTop = { { 248, 252, 255 } },
			Glass = { { 150, 200, 250 }, { 170, 214, 255 } },
			Brick = { { 190, 60, 80 }, { 160, 50, 70 } },
			Leaves = { { 50, 140, 130 }, { 40, 120, 116 }, { 60, 150, 140 } },
			Leaves2 = { { 220, 240, 250 }, { 230, 245, 255 }, { 210, 235, 248 } },
			Pine = { { 30, 120, 110 }, { 36, 134, 120 } },
			Canopy = { { 50, 140, 130 } },
			CanopyTop = { { 220, 240, 250 } },
			CanopyDark = { { 40, 120, 116 } },
			Rock = { { 140, 150, 176 }, { 120, 132, 160 } },
			Grass = { { 200, 230, 240 } },
		}),
		Biome = biome({
			Border = "IceSea",
			Ground = { { 226, 242, 252 }, { 208, 230, 246 } },
			Wild = { { 244, 250, 255 }, { 230, 240, 250 } },
			Road = { { 150, 164, 190 }, { 140, 154, 180 } },
			RoadLine = { 255, 255, 255 },
			Walk = { 236, 244, 252 },
			Water = { 70, 142, 222 }, -- rios azul forte (referência)
			Sand = { { 236, 240, 248 }, { 220, 228, 242 } },
			Plaza = { { 220, 230, 246 }, { 206, 218, 240 } },
			Asphalt = { { 130, 140, 164 }, { 120, 130, 154 } },
			Runway = { { 96, 104, 126 }, { 90, 98, 120 } },
			Base = { { 136, 148, 172 }, { 120, 132, 158 } },
			SeaLevel = -0.35,
			Sea = { { 200, 232, 250 }, { 150, 200, 236 } },
			Foam = { 250, 252, 255 },
			Mountain = { { 176, 192, 220 }, { 150, 166, 198 }, { 210, 222, 240 } },
			MountainTop = { 252, 253, 255 },
			MarginDecor = { SnowPine = 5, Snowman = 1, IceCrystal = 1 },
			SeaDecor = { Iceberg = 4, IceCrystal = 1, Rock = 0.4, FlatRock = 0.3, TallRock = 0.3 },
			-- inverno: sol baixo (sombras longas), névoa fria, céu bem nublado e neve brilhando
			Lighting = {
				Ambient = { 132, 142, 164 },
				OutdoorAmbient = { 170, 184, 210 },
				AtmosphereColor = { 220, 236, 255 },
				AtmosphereDecay = { 160, 190, 236 },
				AtmosphereDensity = 0.14,
				Haze = 0.6,
				Glare = 0.25,
				Saturation = 0.3,
				Contrast = 0.1,
				TintColor = { 236, 244, 255 },
				ClockTime = 9.2,
				Brightness = 1.9,
				ShadowSoftness = 0.4,
				Bloom = { Intensity = 0.35, Size = 30, Threshold = 1.4 },
				SunRays = { Intensity = 0.08, Spread = 0.6 },
				Clouds = { Cover = 0.78, Density = 0.85, Color = { 240, 246, 255 } },
			},
		}),
	},
}

for _, map in maps do
	table.freeze(map)
end

return table.freeze(maps)
