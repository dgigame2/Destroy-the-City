--!strict
-- Destruição em cadeia (Logic/Chain + server/DisasterService).
-- Quando uma construção cai, ela pode atingir as vizinhas:
--   Explosive: veículos, posto de gasolina, fábricas, navio... explodem (raio em studs). Dano = HP da própria
--              construção x DamageFactor, cai até EdgeDamage na borda.
--   Collapse: prédios grandes (tier >= CollapseFromTier) desabam e os destroços atingem em volta.
-- O dano em cadeia respeita o PODER de quem começou (não derruba o que você ainda não pode) e cada construção
-- só cai uma vez. Limites (celular/servidor): profundidade MaxDepth e no máximo MaxPerChain reações por cadeia.
-- Bônus: cada nível de profundidade rende DepthBonus a mais de dinheiro e pontos (teto MaxBonus).

return table.freeze({
	MaxDepth = 4,
	MaxPerChain = 40,
	StepDelay = 0.18, -- segundos entre um elo e o próximo (dá para ver a cadeia acontecendo)
	DepthBonus = 0.25,
	MaxBonus = 1,
	EdgeDamage = 0.35,
	-- avisos de combo (a partir de quantas construções na mesma cadeia)
	Labels = table.freeze({
		table.freeze({ At = 3, Text = "CHAIN x%d" }),
		table.freeze({ At = 8, Text = "BIG CHAIN x%d!" }),
		table.freeze({ At = 15, Text = "MEGA CHAIN x%d!" }),
	}),
	Explosive = table.freeze({
		Car = table.freeze({ Radius = 11, DamageFactor = 1.6 }),
		FoodCart = table.freeze({ Radius = 8, DamageFactor = 1.4 }),
		Boat = table.freeze({ Radius = 9, DamageFactor = 1.4 }),
		Truck = table.freeze({ Radius = 13, DamageFactor = 1.5 }),
		Bus = table.freeze({ Radius = 13, DamageFactor = 1.5 }),
		Yacht = table.freeze({ Radius = 13, DamageFactor = 1.4 }),
		GasStation = table.freeze({ Radius = 28, DamageFactor = 1.8 }),
		ContainerStack = table.freeze({ Radius = 14, DamageFactor = 1.3 }),
		WaterTower = table.freeze({ Radius = 18, DamageFactor = 1.2 }),
		Plane = table.freeze({ Radius = 30, DamageFactor = 1.6 }),
		FactoryHall = table.freeze({ Radius = 32, DamageFactor = 1.4 }),
		CoolingTower = table.freeze({ Radius = 36, DamageFactor = 1.5 }),
		CargoShip = table.freeze({ Radius = 40, DamageFactor = 1.4 }),
		OilTank = table.freeze({ Radius = 34, DamageFactor = 1.9 }), -- tanque de combustível: a maior explosão
	}),
	CollapseFromTier = 5,
	Collapse = table.freeze({ RadiusPadding = 6, DamageFactor = 0.7 }),
})
