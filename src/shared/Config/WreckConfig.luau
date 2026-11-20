--!strict
-- Destroços (AUDITORIA §8.3). Escolha pela semente = BuildingId (Logic/Wreck): todo cliente vê o MESMO.
-- A base do destroço ainda é a pilha PROVISÓRIA de blocos (Logic/Ruins); na Etapa 3 vira mesh do Blender
-- (36 = 4 tamanhos x 3 famílias x 3 variantes), escolhida pelo mesmo Wreck.pick. Objetos que não contam no
-- progresso (Value 0: carros, árvores, postes...) só somem.

return table.freeze({
	-- tamanho pela área do footprint (studs²)
	Sizes = table.freeze({
		table.freeze({ Name = "P", MaxArea = 150 }),
		table.freeze({ Name = "M", MaxArea = 500 }),
		table.freeze({ Name = "G", MaxArea = 1500 }),
		table.freeze({ Name = "GG", MaxArea = math.huge }),
	}),
	-- família pelo nome do template (trecho do nome); sem trecho = DefaultFamily
	Families = table.freeze({
		Commercial = table.freeze({
			"Office",
			"Skyscraper",
			"GlassTower",
			"SpireTower",
			"RedTower",
			"TwinTowers",
			"TVTower",
			"ClockTower",
			"Bank",
			"Hotel",
			"Shop",
			"Store",
			"Supermarket",
			"Cafe",
			"Museum",
			"Hospital",
			"School",
			"Stadium",
			"Church",
			"Kiosk",
			"Terminal",
		}),
		Industrial = table.freeze({
			"Factory",
			"Warehouse",
			"Container",
			"Crane",
			"CoolingTower",
			"OilTank",
			"SmokeStack",
			"Hangar",
			"PowerPylon",
			"WaterTower",
			"ControlTower",
			"GasStation",
			"FireStation",
		}),
		Residential = table.freeze({}),
	}),
	DefaultFamily = "Residential",
	Variants = 3,

	-- desabamento (client/City/WreckPresenter): afunda Sink x altura e inclina até MaxTilt, sem física
	Collapse = table.freeze({
		Seconds = 0.45,
		Sink = 0.7,
		MaxTilt = 14,
	}),
	-- pedaços voando (pool, CFrame por frame, sem física); quantidade pelo tamanho, cortada pelo teto do Tier
	Pieces = table.freeze({
		PerSize = table.freeze({ P = 2, M = 4, G = 6, GG = 8 }),
		Speed = 26,
		MaxSize = 2.6,
		Gravity = 120,
		Seconds = 1.1, -- some (encolhe) no fim
	}),

	-- pilha provisória (Logic/Ruins)
	Ruins = table.freeze({
		FromTier = 1,
		Cell = 4,
		MaxCells = 3,
		Margin = 0.9,
		HeightByTier = table.freeze({ 1, 1.4, 2, 2.6, 3.2, 4, 5 }),
		MinHeight = 0.35,
		Chunks = 0.25,
		MaxParts = 8,
		Concrete = table.freeze({ 150, 150, 155 }),
		DarkConcrete = table.freeze({ 105, 105, 112 }),
	}),
	-- quantas construções o cliente monta por frame (entrada sem travar o celular)
	BuildPerFrame = 40,
})
