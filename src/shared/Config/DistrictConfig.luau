--!strict
-- O que cada tipo de bairro tem (Logic/CityGen). Pesos = chance relativa de cada modelo.
-- Cada etapa da cidade ainda limita o tamanho máximo (Cap da planta): numa etapa do começo,
-- prédios grandes nunca aparecem, mesmo que o bairro tenha.
-- Um conjunto por estilo de mapa (campo, praia, neve).
-- Garden e Market são os bairros das primeiras etapas: cheios de coisas pequenas (tier 1) e médias (tier 2),
-- para o começo ser varrer uma região inteira, não caçar coisinhas entre casas.

local ModelCatalog = if script then require(script.Parent.ModelCatalog) else require("./ModelCatalog")

type Mix = { [string]: number }
type Spec = { Ground: string, Buildings: Mix, Nature: Mix, NatureChance: number, BlockFill: number }
export type Fill = {
	Districts: { [string]: Spec },
	Sidewalk: Mix,
	Parking: Mix,
	Beach: Mix,
	Plaza: Mix,
	Boats: Mix,
	BoatChance: number,
	Planner: any?,
}

-- chance = natureza no que sobrar; blockFill = quanto o miolo dos quarteirões é preenchido com construções
local function spec(ground: string, buildings: Mix, nature: Mix, chance: number, blockFill: number?): Spec
	return table.freeze({
		Ground = ground,
		Buildings = buildings,
		Nature = nature,
		NatureChance = chance,
		BlockFill = blockFill or 1,
	})
end

-- Bairros iguais nos três estilos (só a natureza muda)
local function common(nature: Mix, yard: Mix, small: Mix, market: Mix): { [string]: Spec }
	local parkNature = table.clone(nature)
	parkNature.Gazebo = 0.5
	parkNature.Playground = 0.6
	parkNature.PicnicTable = 1
	parkNature.Bench = 1
	return {
		-- casinhas: começo da cidade
		Suburb = spec(
			"Lot",
			{ Bungalow = 4, House = 4, Cottage = 3, BigHouse = 2, Townhouse = 1.5, Shop = 0.6, Car = 0.6 },
			yard,
			0.25
		),
		-- ruas comerciais
		Commercial = spec("Lot", {
			Shop = 3,
			Cafe = 2.5,
			CornerStore = 2.5,
			Townhouse = 1.5,
			Supermarket = 0.8,
			Bank = 0.8,
			Office = 1.2,
			FireStation = 0.4,
			Church = 0.3,
			School = 0.4,
			GasStation = 0.6,
		}, nature, 0.15),
		-- prédios residenciais
		Apartments = spec("Lot", {
			Apartment = 3,
			ApartmentTall = 2,
			Townhouse = 2,
			Office = 1,
			Hospital = 0.3,
			Shop = 1,
			Cafe = 1,
		}, nature, 0.18),
		-- centro: torres
		Downtown = spec("Lot", {
			OfficeTower = 3,
			GlassTower = 3,
			RedTower = 2,
			ApartmentTall = 1.5,
			Office = 1.5,
			Bank = 0.6,
			Hotel = 0.6,
			Tower = 1,
			ClockTower = 0.3,
			Skyscraper = 1.2,
			SpireTower = 0.4,
			TwinTowers = 0.3,
		}, { Bush = 2, FlowerPot = 2, Bench = 1, Tree = 1, Fountain = 0.6, Gazebo = 0.4, Playground = 0.3 }, 0.12),
		-- indústria e porto (no asfalto)
		Industrial = spec("Asphalt", {
			Warehouse = 3,
			FactoryHall = 2,
			WaterTower = 1,
			ContainerStack = 2,
			Truck = 1,
			OilTank = 2,
			SmokeStack = 1,
			PowerPylon = 1,
		}, { ContainerStack = 2, Truck = 1, Cone = 2 }, 0.04, 0.3),
		Harbor = spec(
			"Asphalt",
			{ Warehouse = 2, ContainerStack = 4, Truck = 1, OilTank = 1.5 },
			{ ContainerStack = 2, Truck = 1, Cone = 1 },
			0.05,
			0.4
		),
		Airport = spec("Asphalt", { Hangar = 2, Plane = 1.5 }, { Cone = 2, Truck = 0.3 }, 0.02, 0.08),
		-- parque: só natureza e coisas de parque
		Park = spec("Lot", {}, parkNature, 0.45),
		-- jardim (1ª etapa): canteiros, mesinhas e bancos, bem cheio
		Garden = spec("Lot", small, small, 0.55, 0.75),
		-- feirinha (2ª etapa): barraquinhas, carros e árvores, com coisinhas entre eles
		Market = spec("Lot", market, small, 0.4, 0.6),
	}
end

local GARDEN_NATURE = { Tree = 5, Bush = 3, Flowers = 1, Hedge = 2, Rock = 0.5, Mushroom = 1 }
local BEACH_NATURE = { Palm = 5, Bush = 2, Flowers = 2, Hedge = 1, Rock = 1 }
local FROST_NATURE = { SnowPine = 5, IceCrystal = 1.5, Snowman = 1.5, Bush = 1, Rock = 1 }

-- Gerador planejado (Logic/CityGen + Logic/Placement + Config/ModelCatalog). Uma cidade por vez: hoje só a
-- Garden Village usa; Beach e Frost continuam no gerador antigo até a Garden ser aprovada.
local function group(chance: number, min: number, max: number, radius: number)
	return table.freeze({ Chance = chance, Min = min, Max = max, Radius = radius })
end

local GARDEN_PLANNER = table.freeze({
	Catalog = ModelCatalog,
	BlockReach = 8, -- prédio no miolo só até 24 studs da calçada; mais fundo vira quintal
	FrontClear = 1, -- sem árvore na faixa da fachada
	Groups = group(0.035, 2, 4, 3), -- quintais e bairros
	DistrictGroups = table.freeze({
		Garden = group(0.18, 3, 6, 3), -- 1ª etapa: jardim (canteiros, mesas, bancos) em ilhas
		Market = group(0.06, 2, 4, 3),
		Park = group(0.09, 3, 6, 4),
		Downtown = group(0.015, 1, 3, 2),
		-- pátios (asfalto): poucos cones e contêineres soltos
		Industrial = group(0.006, 1, 2, 3),
		Harbor = group(0.006, 1, 2, 3),
		Airport = group(0.003, 1, 2, 3),
	}),
	DrivewayCar = 0.45,
	Houses = table.freeze({
		Bungalow = true,
		House = true,
		Cottage = true,
		BigHouse = true,
		Townhouse = true,
		Villa = true,
		BeachHouse = true,
		SnowCabin = true,
	}),
	EntrancePots = 0.3,
	Storefronts = table.freeze({
		Shop = true,
		Cafe = true,
		CornerStore = true,
		Supermarket = true,
		Bank = true,
		SurfShop = true,
		Hotel = true,
	}),
	Sidewalk = table.freeze({ Bin = 2, Hydrant = 1.5, Mailbox = 1, BusStop = 0.6 }),
	SidewalkChance = 0.07,
	Beach = table.freeze({
		Anchor = table.freeze({ Umbrella = 1 }),
		Companions = table.freeze({ Towel = 2, Umbrella = 1, Palm = 0.4 }),
		NearWater = 8, -- células (24 studs) da água
		Group = group(0.03, 1, 3, 3),
	}),
	Runway = table.freeze({ Plane = 1 }),
	RunwayChance = 0.05,
	Apron = table.freeze({ Plane = 1 }),
	ApronChance = 0.0015,
	Wild = group(0.04, 2, 5, 3), -- bosque na margem antes do mar (mata fechada é natural)
	-- densidade com função (mais coisa para destruir sem perder a cara de cidade)
	Yard = table.freeze({
		Mailbox = 0.7,
		Fence = 0.75,
		BackGap = 3, -- cerca a 9 studs do fundo da casa
		Plant = 0.85,
		Plants = table.freeze({ Bush = 3, Hedge = 2, Flowers = 1 }),
	}),
	CurbCars = table.freeze({ Chance = 0.6, Spacing = 19, MinRoad = 6 }),
	ParkingChance = 0.9, -- estacionamento lotado
	PlazaChance = 0.2, -- praça com bancos, vasos e carrinhos (cada um longe do outro igual)
})

local function fill(
	nature: Mix,
	yard: Mix,
	small: Mix,
	market: Mix,
	extra: { [string]: Spec },
	beach: Mix,
	planner: any?
): Fill
	local districts = common(nature, yard, small, market)
	for name, s in extra do
		districts[name] = s
	end
	return table.freeze({
		Planner = planner,
		Districts = table.freeze(districts),
		Sidewalk = { Bin = 2, Hydrant = 1.5, FlowerPot = 2, Bench = 1.5, Mailbox = 1, BusStop = 0.5, Cone = 0.4 },
		Parking = { Car = 6, Bus = 0.6, Truck = 1 },
		Beach = beach,
		Plaza = { Bench = 3, FlowerPot = 3, FoodCart = 1.5, Lamp = 1, IceCreamStand = 0.6 },
		Boats = { Boat = 4, Yacht = 1.5 },
		BoatChance = 0.004,
		Wild = nature, -- árvores e moitas da margem antes do mar (destrutíveis)
	})
end

return table.freeze({
	Garden = fill(
		GARDEN_NATURE,
		{ Tree = 4, Bush = 3, Flowers = 1, Hedge = 3, Fence = 1 },
		{ Flowers = 1, Hedge = 3, Bush = 3, PicnicTable = 2, Bench = 2, FlowerPot = 2, Mushroom = 1.5, Fence = 1 },
		{ FoodCart = 3, IceCreamStand = 2, BusStop = 1, Car = 2, Tree = 3, Pine = 1 },
		{},
		{
			Umbrella = 2,
			Towel = 3,
			Palm = 1,
		},
		GARDEN_PLANNER
	),
	Beach = fill(
		BEACH_NATURE,
		{ Palm = 4, Bush = 2, Flowers = 2, Hedge = 2 },
		{ Towel = 3, FlowerPot = 2, Bench = 2, Bush = 2, Flowers = 2, PicnicTable = 1.5, Hedge = 1 },
		{ Umbrella = 3, IceCreamStand = 2, FoodCart = 2, Lifeguard = 1, Palm = 2, Car = 1, Rock = 0.5 },
		{
			-- frente de praia: casas de praia, vilas e hotéis
			Resort = spec("Lot", {
				BeachHouse = 4,
				Villa = 3,
				SurfShop = 1.5,
				Hotel = 1.5,
				Cafe = 1,
				IceCreamStand = 1,
			}, BEACH_NATURE, 0.25),
			Suburb = spec(
				"Lot",
				{ BeachHouse = 3, Bungalow = 3, House = 3, Villa = 1.5, Cottage = 1, Townhouse = 1, Car = 0.6 },
				{ Palm = 4, Bush = 2, Flowers = 2, Hedge = 2 },
				0.3
			),
		},
		{ Umbrella = 4, Towel = 5, Palm = 2, Lifeguard = 0.6, IceCreamStand = 0.4 }
	),
	Frost = fill(
		FROST_NATURE,
		{ SnowPine = 4, Snowman = 2, Bush = 1, Hedge = 1 },
		{ Snowman = 3, Bush = 2, Bench = 2, FlowerPot = 1, Hedge = 2, Fence = 1, Mushroom = 0.5 },
		{ Igloo = 2, FoodCart = 2, IceCrystal = 2, SnowPine = 3, Car = 1.5, BusStop = 1 },
		{
			Suburb = spec(
				"Lot",
				{ SnowCabin = 4, Bungalow = 3, House = 2, Cottage = 2, Igloo = 1.5, Townhouse = 1, Car = 0.6 },
				{ SnowPine = 4, Snowman = 2, Bush = 1, Hedge = 1 },
				0.3
			),
			Lodge = spec("Lot", { SkiLodge = 2, SnowCabin = 3, Cafe = 1, Shop = 1 }, FROST_NATURE, 0.3),
		},
		{ Snowman = 3, IceCrystal = 2 }
	),
})
