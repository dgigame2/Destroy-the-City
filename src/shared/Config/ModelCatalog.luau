--!strict
-- Catálogo dos modelos para o gerador planejado (Logic/Placement + Logic/CityGen): o que cada modelo É e as
-- regras de onde ele pode ficar. Modelo novo = uma linha aqui (o que não está listado é "Building").
--
-- Category:
--   Building  casas, lojas, prédios, marcos (frente para a rua, entrada livre)
--   Stall     barraquinhas (carrinho de comida, sorveteria): frente para a rua, sem entrada reservada
--   Vehicle   carros e afins: só na entrada da casa, estacionamento ou pátio
--   Aircraft  aviões: só no aeroporto (pátio ou pista)
--   Tree      árvores: centro dos grupos de natureza
--   Plant     arbustos, flores, cogumelos, pedras: completam os grupos
--   Leisure   bancos, mesas, vasos, cercas: pontos de convivência e entradas
--   Street    postes, lixeiras, hidrantes, caixas de correio, pontos de ônibus, cones: calçada
--   Beach     guarda-sol, toalha, salva-vidas: só na areia
--   Boat      barcos: só na água
--   Yard      pilhas de contêiner: pátio de indústria e porto
--
-- Spacing = distância mínima (studs, centro a centro) até outro modelo da MESMA categoria de espaçamento
-- (SpacingGroup, padrão = o próprio nome): impede fileiras de bancos, vasos colados, bonecos amontoados.
-- Only = tipos de chão permitidos (nil = o que o gerador escolher). Districts = bairros permitidos.
-- FaceRoad = na calçada, só encostado na rua e com a frente virada para ela.
-- BackToRoad = construção de costas para a rua (a frente olha para o meio do terreno).

export type Entry = {
	Category: string,
	Spacing: number?,
	SpacingGroup: string?,
	Only: { [string]: boolean }?,
	Districts: { [string]: boolean }?,
	FaceRoad: boolean?,
	BackToRoad: boolean?,
}

local SAND = table.freeze({ Sand = true })
local AIRPORT = table.freeze({ Airport = true })

local entries: { [string]: Entry } = {
	-- barraquinhas
	FoodCart = { Category = "Stall", Spacing = 14 },
	IceCreamStand = { Category = "Stall", Spacing = 14 },
	-- veículos
	Car = { Category = "Vehicle" },
	Truck = { Category = "Vehicle" },
	Bus = { Category = "Vehicle" },
	Plane = { Category = "Aircraft", Spacing = 45, Only = table.freeze({ Asphalt = true, Runway = true }) },
	-- natureza
	Tree = { Category = "Tree", Spacing = 12, SpacingGroup = "Tree" },
	Oak = { Category = "Tree", Spacing = 12, SpacingGroup = "Tree" },
	BentTree = { Category = "Tree", Spacing = 12, SpacingGroup = "Tree" },
	Pine = { Category = "Tree", Spacing = 10, SpacingGroup = "Tree" },
	SnowPine = { Category = "Tree", Spacing = 10, SpacingGroup = "Tree" },
	Palm = { Category = "Tree", Spacing = 14, SpacingGroup = "Tree" },
	Acacia = { Category = "Tree", Spacing = 14, SpacingGroup = "Tree" },
	DeadTree = { Category = "Tree", Spacing = 10, SpacingGroup = "Tree" },
	Cactus = { Category = "Plant", Spacing = 10 },
	Bush = { Category = "Plant", Spacing = 7 },
	WideBush = { Category = "Plant", Spacing = 10, SpacingGroup = "Bush" },
	Hedge = { Category = "Plant", Spacing = 6 },
	Flowers = { Category = "Plant", Spacing = 12 },
	Mushroom = { Category = "Plant", Spacing = 14 },
	Rock = { Category = "Plant", Spacing = 14 },
	FlatRock = { Category = "Plant", Spacing = 14, SpacingGroup = "Rock" },
	TallRock = { Category = "Plant", Spacing = 14, SpacingGroup = "Rock" },
	RockPillar = { Category = "Plant", Spacing = 14 },
	IceCrystal = { Category = "Plant", Spacing = 14 },
	Snowman = { Category = "Plant", Spacing = 30 },
	-- convivência
	Bench = { Category = "Leisure", Spacing = 24 },
	PicnicTable = { Category = "Leisure", Spacing = 18 },
	FlowerPot = { Category = "Leisure", Spacing = 14 },
	Fence = { Category = "Leisure", Spacing = 8 }, -- pedaços de cerca seguidos no fundo do lote
	-- pontos de parque grandes: um de cada por pedaço de parque
	Gazebo = { Category = "Leisure", Spacing = 60, SpacingGroup = "ParkFeature" },
	Playground = { Category = "Leisure", Spacing = 60, SpacingGroup = "ParkFeature" },
	Fountain = { Category = "Leisure", Spacing = 60, SpacingGroup = "ParkFeature" },
	-- calçada
	Lamp = { Category = "Street", Spacing = 27 },
	Bin = { Category = "Street", Spacing = 30 },
	Hydrant = { Category = "Street", Spacing = 40 },
	Mailbox = { Category = "Street", Spacing = 12 }, -- uma por casa
	BusStop = { Category = "Street", Spacing = 80 },
	Cone = { Category = "Street", Spacing = 18 },
	-- praia
	Umbrella = { Category = "Beach", Spacing = 8, Only = SAND },
	Towel = { Category = "Beach", Spacing = 6, Only = SAND },
	Lifeguard = { Category = "Beach", Spacing = 70, Only = SAND },
	-- água
	Boat = { Category = "Boat", Only = table.freeze({ Water = true }) },
	Yacht = { Category = "Boat", Only = table.freeze({ Water = true }) },
	Iceberg = { Category = "Boat", Only = table.freeze({ Water = true }) },
	-- pátio (indústria, porto): pilhas soltas, longe uma da outra
	ContainerStack = { Category = "Yard", Spacing = 14 },
	-- microambientes (kits e quintais): ficam no lugar que o kit desenha
	Gate = { Category = "Leisure", Spacing = 8, SpacingGroup = "Fence" }, -- entra na linha da cerca
	Bicycle = { Category = "Leisure", Spacing = 10 },
	Doghouse = { Category = "Leisure", Spacing = 20 },
	Clothesline = { Category = "Leisure", Spacing = 20 },
	Grill = { Category = "Leisure", Spacing = 16 },
	PatioSet = { Category = "Leisure", Spacing = 16 },
	Slide = { Category = "Leisure" },
	Seesaw = { Category = "Leisure" },
	Crate = { Category = "Yard" },
	Barrel = { Category = "Yard" },
	Pallet = { Category = "Yard" },
	Dumpster = { Category = "Yard", Spacing = 20 },
	Barrier = { Category = "Street" },
	-- placas de trânsito: espaço entre elas contado junto, frente virada para a rua
	WarningSign = { Category = "Street", Spacing = 50, SpacingGroup = "RoadSign", FaceRoad = true },
	StopSign = { Category = "Street", Spacing = 50, SpacingGroup = "RoadSign", FaceRoad = true },
	SpeedSign = { Category = "Street", Spacing = 50, SpacingGroup = "RoadSign", FaceRoad = true },
	FuelPump = { Category = "Street" },
	ShoppingCart = { Category = "Street" },
	PowerBox = { Category = "Street", Spacing = 40 },
	BikeRack = { Category = "Street", Spacing = 40 },
	-- neve
	SnowFence = { Category = "Leisure", Spacing = 8, SpacingGroup = "Fence" },
	SnowPile = { Category = "Plant", Spacing = 10 },
	IceBlock = { Category = "Plant", Spacing = 12 },
	IceSculpture = { Category = "Leisure", Spacing = 30 },
	SkateRink = { Category = "Leisure", Spacing = 60 },
	-- praia
	BeachChair = { Category = "Beach", Spacing = 5, Only = SAND },
	Lounger = { Category = "Beach", Spacing = 6, Only = SAND },
	VolleyNet = { Category = "Beach", Spacing = 60, Only = SAND },
	Cooler = { Category = "Beach", Spacing = 8 },
	Buoy = { Category = "Beach", Spacing = 30 },
	SurfRack = { Category = "Leisure", Spacing = 20 },
	Kiosk = { Category = "Stall", Spacing = 30 },
	-- construções com regra própria
	Hangar = { Category = "Building", Spacing = 60, Districts = AIRPORT, BackToRoad = true },
}

for _, entry in entries do
	table.freeze(entry)
end

return table.freeze(entries)
