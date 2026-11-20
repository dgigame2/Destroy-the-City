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
local FROST_NATURE =
	{ SnowPine = 5, IceCrystal = 1.2, Snowman = 0.4, SnowPile = 1.2, IceBlock = 0.6, Bush = 1, Rock = 1 }

-- Gerador planejado (Logic/CityGen + Logic/Placement + Config/ModelCatalog). Uma cidade por vez: hoje só a
-- Garden Village usa; Beach e Frost continuam no gerador antigo até a Garden ser aprovada.
local function group(chance: number, min: number, max: number, radius: number)
	return table.freeze({ Chance = chance, Min = min, Max = max, Radius = radius })
end

-- Microambientes (CityGen.fillKits / dressBack). Posições em células (3 studs), frente do kit em Z = 0.
local function p(model: string, x: number, z: number, rot: number?, chance: number?)
	return table.freeze({ Model = model, X = x, Z = z, Rot = rot, Chance = chance })
end
local function kit(
	name: string,
	ground: string,
	districts: Mix,
	size: { number },
	spacing: number,
	front: number?,
	pieces
)
	return table.freeze({
		Name = name,
		Ground = ground,
		Districts = table.freeze(districts),
		Size = size,
		Spacing = spacing,
		Front = front,
		Pieces = table.freeze(pieces),
	})
end

-- Fundo e lados das construções (iguais nas três cidades; cada uma troca o quintal das casas).
local function backs(houseYard: Mix): { [string]: any }
	local house = table.freeze({ Gate = 0.5, SideFence = 0.7, Items = houseYard, Count = { 1, 3 } })
	local shop = table.freeze({
		Items = { Crate = 2, Barrel = 1.5, Pallet = 1, Dumpster = 1.2 },
		Count = { 1, 3 },
		Depth = 2,
		Side = { BikeRack = 1, PowerBox = 0.5 },
		SideCount = 1,
	})
	local office = table.freeze({ Items = { Dumpster = 1, PowerBox = 1, BikeRack = 0.6 }, Count = { 1, 2 }, Depth = 3 })
	local result: { [string]: any } = {
		Shop = shop,
		CornerStore = shop,
		SurfShop = shop,
		Cafe = table.freeze({
			Items = { Crate = 1, Barrel = 1, Dumpster = 1 },
			Count = { 1, 2 },
			Depth = 2,
			Side = { PatioSet = 1 },
			SideCount = 1,
		}),
		Supermarket = table.freeze({
			Items = { Pallet = 2, Crate = 2, Dumpster = 1, Barrel = 1 },
			Count = { 2, 4 },
			Depth = 3,
			Side = { ShoppingCart = 3, BikeRack = 1 },
			SideCount = 3,
		}),
		GasStation = table.freeze({
			Items = { Barrel = 2, Crate = 1, Dumpster = 1, PowerBox = 1 },
			Count = { 2, 3 },
			Depth = 3,
			Side = { FuelPump = 2, PowerBox = 0.5, WarningSign = 0.5 },
			SideCount = 2,
		}),
		Warehouse = table.freeze({ Items = { Pallet = 2, Crate = 2, Barrel = 2 }, Count = { 2, 4 }, Depth = 3 }),
		FactoryHall = table.freeze({ Items = { Pallet = 1, Barrel = 2, Crate = 1 }, Count = { 2, 3 }, Depth = 3 }),
		Bank = office,
		Office = office,
		Hotel = office,
		Apartment = office,
		ApartmentTall = office,
	}
	for _, name in { "Bungalow", "House", "Cottage", "BigHouse", "Townhouse", "Villa", "BeachHouse", "SnowCabin" } do
		result[name] = house
	end
	return table.freeze(result)
end

local GARDEN_BACKS = backs({ Doghouse = 1, Clothesline = 1.2, Grill = 1, PatioSet = 1, Bicycle = 1.2, FlowerPot = 0.6 })

-- Kits iguais nas três cidades (as peças de cada tema entram por `extra`).
local function cityKits(extra: { any }): { any }
	local list = {
		-- obra pequena: cavaletes e cones na frente, material atrás
		kit(
			"Roadworks",
			"Lot",
			{ Downtown = 0.002, Apartments = 0.0015, Commercial = 0.0015, Suburb = 0.001 },
			{
				6,
				4,
			},
			120,
			nil,
			{
				p("Barrier", 0, 0),
				p("Cone", 2, 0),
				p("Barrier", 3, 0),
				p("Cone", 5, 0),
				p("Pallet", 0, 2),
				p("Pallet", 0, 3, 0, 0.7),
				p("Crate", 2, 2),
				p("Crate", 2, 3, 0, 0.7),
				p("Barrel", 3, 3),
				p("Barrel", 4, 3, 0, 0.7),
				p("WarningSign", 5, 2),
			}
		),
		-- pátio de carga: caminhão encostado, paletes, caixas, barris e caçamba
		kit("LoadingYard", "Asphalt", { Industrial = 0.003, Harbor = 0.003, Airport = 0.0015 }, { 8, 5 }, 45, nil, {
			p("Truck", 0, 0),
			p("Pallet", 4, 0),
			p("Pallet", 4, 1, 0, 0.7),
			p("Crate", 6, 0),
			p("Crate", 7, 0, 0, 0.7),
			p("Crate", 6, 1, 0, 0.6),
			p("Barrel", 4, 3),
			p("Barrel", 5, 3, 0, 0.7),
			p("Dumpster", 6, 3),
			p("Barrel", 4, 4, 0, 0.5),
		}),
		-- fileira de vagas nos pátios grandes: postes nas pontas, carros lado a lado
		kit(
			"CarRow",
			"Asphalt",
			{ Industrial = 0.002, Airport = 0.002, Harbor = 0.0015, Parking = 0.02 },
			{
				14,
				6,
			},
			40,
			nil,
			{
				p("Lamp", 0, 0),
				p("Car", 1, 0),
				p("Car", 4, 0, 0, 0.8),
				p("Car", 7, 0, 0, 0.8),
				p("Car", 10, 0, 0, 0.8),
				p("Lamp", 13, 0),
				p("Bin", 0, 5),
				p("ShoppingCart", 13, 5, 0, 0.5),
			}
		),
	}
	for _, k in extra do
		table.insert(list, k)
	end
	return table.freeze(list)
end

-- parquinho completo: escorregador, balanço, gangorra, brinquedão, bancos com lixeira, mesa e postes
local function playground(districts: Mix, decor: string)
	return kit("Playground", "Lot", districts, { 10, 9 }, 80, 3, {
		p(decor, 0, 0),
		p("Lamp", 9, 0),
		p("Slide", 1, 2),
		p("Swing", 4, 2),
		p("Seesaw", 4, 5),
		p("Bench", 8, 1, 90),
		p("Bin", 8, 3),
		p("Bench", 8, 5, 90, 0.8),
		p("Playground", 1, 6),
		p("PicnicTable", 7, 7, 0, 0.8),
		p("Lamp", 0, 8),
	})
end

-- cantinho de praça: árvore com canteiro, banco, lixeira e poste
local function plazaRest(tree: string, bed: string)
	return kit("PlazaRest", "Plaza", { Park = 0.08, Downtown = 0.08, Garden = 0.1, Market = 0.08 }, { 7, 6 }, 24, nil, {
		p(tree, 0, 2),
		p("Bench", 1, 0),
		p("Bin", 3, 0),
		p("Lamp", 6, 0),
		p(bed, 6, 2, 90),
		p("FlowerPot", 6, 5),
	})
end

-- pracinha no miolo dos quarteirões (fundo dos lotes que ficava vazio)
local function courtyard(tree: string, plant: string, bed: string)
	return kit(
		"Courtyard",
		"Lot",
		{ Downtown = 0.003, Apartments = 0.002, Commercial = 0.0015, Suburb = 0.0015, Park = 0.002 },
		{ 9, 7 },
		40,
		nil,
		{
			p(tree, 0, 0),
			p("PicnicTable", 6, 0),
			p("Grill", 8, 0, 0, 0.7),
			p(plant, 6, 3),
			p(bed, 0, 4),
			p("Bench", 2, 5),
			p("Bin", 4, 5),
			p("FlowerPot", 5, 6, 0, 0.8),
			p("Lamp", 8, 6),
		}
	)
end

local GARDEN_KITS = cityKits({
	playground({ Park = 0.05, Garden = 0.05, Suburb = 0.01, Apartments = 0.006, Downtown = 0.006 }, "Flowers"),
	plazaRest("Tree", "Flowers"),
	courtyard("Tree", "Bush", "Flowers"),
})

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
	Backs = GARDEN_BACKS,
	Kits = GARDEN_KITS,
	Boost = table.freeze({ Commercial = table.freeze({ GasStation = 1.6 }) }), -- mais postos na vila
})

-- Outra cidade = o planejador da Garden com o que muda nela (quintal, kits, praia, grupos).
local function plannerFrom(overrides: { [string]: any })
	local result = table.clone(GARDEN_PLANNER)
	result.Boost = nil
	for key, value in overrides do
		result[key] = value
	end
	return table.freeze(result)
end

-- chance igual em todos os bairros que têm o chão do kit
local function everywhere(chance: number): Mix
	local result = {}
	for _, name in
		{ "Park", "Commercial", "Apartments", "Downtown", "Resort", "Suburb", "Garden", "Market", "Harbor", "Lodge" }
	do
		result[name] = chance
	end
	return result
end

-- ICE CITY: vila de inverno habitada. Neve encostada nas construções, pista de patinação, esculturas de gelo,
-- cerca com neve e poucos bonecos de neve (cada um num lugar que faz sentido).
local FROST_BACKS = backs({ Snowman = 1, SnowPile = 1.6, IceBlock = 0.6, Doghouse = 0.8, Bicycle = 0.5, Barrel = 0.6 })
local FROST_KITS = cityKits({
	playground(
		{ Park = 0.05, Garden = 0.05, Suburb = 0.01, Apartments = 0.006, Downtown = 0.006, Lodge = 0.02 },
		"SnowPile"
	),
	courtyard("SnowPine", "SnowPile", "IceBlock"),
	-- pista de patinação com bancos, postes, lixeira, boneco de neve e neve varrida para o canto
	kit(
		"SkatingRink",
		"Lot",
		{ Park = 0.02, Garden = 0.03, Lodge = 0.02, Downtown = 0.002, Suburb = 0.002 },
		{
			9,
			7,
		},
		70,
		3,
		{
			p("Lamp", 0, 0),
			p("SkateRink", 1, 1),
			p("Bench", 7, 1, 90),
			p("Bin", 8, 3),
			p("Bench", 7, 4, 90, 0.8),
			p("Lamp", 8, 0),
			p("Lamp", 0, 6),
			p("Snowman", 2, 6),
			p("SnowPile", 4, 6),
		}
	),
	-- praça de inverno: escultura de gelo no meio, bancos, poste e neve
	kit(
		"WinterPlaza",
		"Plaza",
		{ Park = 0.06, Downtown = 0.05, Garden = 0.08, Market = 0.05, Lodge = 0.05 },
		{
			6,
			6,
		},
		30,
		nil,
		{
			p("Bench", 0, 0),
			p("Bin", 2, 0),
			p("Lamp", 5, 0),
			p("IceSculpture", 2, 2),
			p("SnowPile", 0, 3),
			p("IceBlock", 5, 3),
			p("Bench", 2, 5, 180, 0.8),
		}
	),
	plazaRest("SnowPine", "IceBlock"),
})

local FROST_PLANNER = plannerFrom({
	DistrictGroups = table.freeze({
		Garden = group(0.16, 3, 6, 3),
		Market = group(0.06, 2, 4, 3),
		Park = group(0.09, 3, 6, 4),
		Lodge = group(0.06, 2, 5, 3),
		Downtown = group(0.015, 1, 3, 2),
		Industrial = group(0.006, 1, 2, 3),
		Harbor = group(0.006, 1, 2, 3),
		Airport = group(0.003, 1, 2, 3),
	}),
	Beach = table.freeze({
		Anchor = table.freeze({ SnowPine = 1 }),
		Companions = table.freeze({ SnowPile = 2, IceCrystal = 1, IceBlock = 1, Snowman = 0.3 }),
		NearWater = 8,
		Group = group(0.03, 1, 3, 3),
	}),
	Yard = table.freeze({
		Mailbox = 0.7,
		Fence = 0.75,
		BackGap = 3,
		Plant = 0.85,
		Plants = table.freeze({ SnowPile = 3, Bush = 1, IceBlock = 1 }),
	}),
	FenceModel = "SnowFence",
	Backs = FROST_BACKS,
	Kits = FROST_KITS,
})

-- BEACH CITY: região turística. A areia vira vários ambientes: guarda-sóis com cadeiras e caixa térmica,
-- espreguiçadeiras, quadra de vôlei, posto de salva-vidas e quiosques com mesas cercadinhos.
local BEACH_BACKS = (function()
	local result =
		table.clone(backs({ BeachChair = 1, Cooler = 1, SurfRack = 1, Grill = 1, PatioSet = 1, Bicycle = 1 }))
	result.SurfShop = table.freeze({
		Items = { Crate = 1, Cooler = 1, Barrel = 0.5 },
		Count = { 1, 2 },
		Depth = 2,
		Side = { SurfRack = 2, BikeRack = 0.6 },
		SideCount = 2,
	})
	return table.freeze(result)
end)()

local BEACH_KITS = cityKits({
	playground(
		{ Park = 0.05, Garden = 0.05, Suburb = 0.01, Apartments = 0.006, Downtown = 0.006, Resort = 0.01 },
		"Flowers"
	),
	plazaRest("Tree", "Flowers"),
	courtyard("Tree", "Bush", "Flowers"),
	-- guarda-sol com duas cadeiras, caixa térmica e toalha
	kit("BeachRest", "Sand", everywhere(0.01), { 5, 5 }, 18, nil, {
		p("Umbrella", 1, 1),
		p("BeachChair", 1, 4),
		p("BeachChair", 3, 4, 0, 0.8),
		p("Cooler", 4, 1, 0, 0.7),
		p("Towel", 0, 0, 0, 0.6),
	}),
	-- fileira de espreguiçadeiras do hotel com um guarda-sol no meio
	kit("LoungerRow", "Sand", everywhere(0.006), { 7, 4 }, 30, nil, {
		p("Lounger", 0, 1),
		p("Lounger", 1, 1),
		p("Umbrella", 2, 0),
		p("Lounger", 5, 1),
		p("Lounger", 6, 1, 0, 0.7),
		p("Cooler", 3, 3, 0, 0.7),
	}),
	-- quadra de vôlei de praia
	kit("VolleyCourt", "Sand", everywhere(0.012), { 6, 6 }, 90, nil, {
		p("VolleyNet", 1, 2),
		p("BeachChair", 0, 0),
		p("Cooler", 5, 0),
		p("Towel", 0, 4, 0, 0.7),
		p("BeachChair", 5, 5, 180, 0.7),
	}),
	-- posto de salva-vidas: torre, boia, pranchas e caixa térmica
	kit("LifeguardPost", "Sand", everywhere(0.003), { 6, 4 }, 90, nil, {
		p("Lifeguard", 0, 0),
		p("Buoy", 3, 0),
		p("SurfRack", 4, 1),
		p("Cooler", 0, 3, 0, 0.7),
	}),
	-- quiosque com mesas e cercadinho atrás
	kit("KioskBar", "Sand", everywhere(0.004), { 8, 6 }, 60, nil, {
		p("Kiosk", 2, 0),
		p("Cooler", 5, 0, 0, 0.8),
		p("Bin", 6, 0),
		p("PatioSet", 0, 3),
		p("PatioSet", 3, 3),
		p("PatioSet", 6, 3, 0, 0.7),
		p("Fence", 0, 5),
		p("Fence", 5, 5),
	}),
})

local BEACH_PLANNER = plannerFrom({
	DistrictGroups = table.freeze({
		Garden = group(0.16, 3, 6, 3),
		Market = group(0.06, 2, 4, 3),
		Park = group(0.09, 3, 6, 4),
		Resort = group(0.05, 2, 4, 3),
		Downtown = group(0.015, 1, 3, 2),
		Industrial = group(0.006, 1, 2, 3),
		Harbor = group(0.006, 1, 2, 3),
		Airport = group(0.003, 1, 2, 3),
	}),
	Beach = table.freeze({
		Anchor = table.freeze({ Umbrella = 1 }),
		Companions = table.freeze({ BeachChair = 1.5, Towel = 0.7, Cooler = 0.8, Palm = 0.3 }),
		NearWater = 8,
		Group = group(0.03, 1, 3, 3),
	}),
	Yard = table.freeze({
		Mailbox = 0.7,
		Fence = 0.7,
		BackGap = 3,
		Plant = 0.85,
		Plants = table.freeze({ Bush = 2, Hedge = 1, Flowers = 2 }),
	}),
	Backs = BEACH_BACKS,
	Kits = BEACH_KITS,
	Boost = table.freeze({ Commercial = table.freeze({ GasStation = 1.4 }) }),
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
	-- pesos extras de construção por bairro só nesta cidade (ex.: mais postos na vila)
	if planner and planner.Boost then
		for name, weights in planner.Boost do
			local base = districts[name]
			if base then
				local buildings = table.clone(base.Buildings)
				for model, weight in weights do
					buildings[model] = weight
				end
				local boosted = table.clone(base)
				boosted.Buildings = buildings
				districts[name] = table.freeze(boosted)
			end
		end
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
		{ Tree = 4, Bush = 3, Flowers = 1, Hedge = 3 },
		{ Flowers = 1, Hedge = 3, Bush = 3, PicnicTable = 2, Bench = 2, FlowerPot = 2, Mushroom = 1.5 },
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
		{ Towel = 0.6, Cooler = 1, FlowerPot = 2, Bench = 2, Bush = 2, Flowers = 2, PicnicTable = 1.5, Hedge = 1 },
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
		{ Umbrella = 4, Towel = 1.2, BeachChair = 2, Cooler = 1, Palm = 2, Lifeguard = 0.6, IceCreamStand = 0.4 },
		BEACH_PLANNER
	),
	Frost = fill(
		FROST_NATURE,
		{ SnowPine = 4, Snowman = 0.5, SnowPile = 1.5, Bush = 1, Hedge = 1 },
		{ Snowman = 0.6, SnowPile = 1.5, IceBlock = 1, Bush = 2, Bench = 2, FlowerPot = 1, Hedge = 2, PicnicTable = 1 },
		{ Igloo = 2, FoodCart = 2, IceCrystal = 2, SnowPine = 3, Car = 1.5, BusStop = 1 },
		{
			Suburb = spec(
				"Lot",
				{ SnowCabin = 4, Bungalow = 3, House = 2, Cottage = 2, Igloo = 1.5, Townhouse = 1, Car = 0.6 },
				{ SnowPine = 4, Snowman = 0.5, SnowPile = 1.5, Bush = 1, Hedge = 1 },
				0.3
			),
			Lodge = spec("Lot", { SkiLodge = 2, SnowCabin = 3, Cafe = 1, Shop = 1 }, FROST_NATURE, 0.3),
		},
		{ SnowPile = 2, IceCrystal = 2, IceBlock = 1, Snowman = 0.6 },
		FROST_PLANNER
	),
})
