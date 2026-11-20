--!strict
-- Skills (Q) de cada forma do tornado: uma por forma (Forms[i] usa Skills[i]). Lógica em Logic/Skills.
-- Toda skill é uma ou mais "zonas" que se movem; tudo em RAIOS do tornado de quem usa (cresce com o nível)
-- e o dano é proporcional a quem usa (iguais = equilibrado):
--   Move: "Line" anda na direção do Q (Speed raios/s, até Travel raios; Wobble = zigue-zague)
--         "Self" segue o tornado · "Fixed" fica parada (Ahead raios à frente) · "Orbit" gira em volta
--         (Count zonas a Orbit raios, Spin rad/s; volta ao centro nos últimos Return segundos)
--   Size = raio da zona (raios); Grow = cresce até +Grow no fim (buraco negro)
--   CityRate = x o dano passivo por segundo na cidade; HpRate = fração da vida máxima de quem usa por segundo
--   Once = acerta cada tornado uma vez com ImpactHp (em vez de HpRate)
--   Pull = studs/s puxando tornados para o centro da zona (negativo = empurra para fora);
--   Drag = studs/s arrastando na direção do Q
--   Burst (no fim): Size raios, City x dano passivo, Hp fração da vida; cresce com o que a skill destruiu:
--   x(1 + min(destruídos, Cap) * PerItem)
--   Trail = deixa rastro (fogo) que dura TrailSeconds e dá TrailRate x dano passivo por segundo

local function skill(t: { [string]: any }): any
	return table.freeze(t)
end

return table.freeze({
	-- 1. Breeze — Wind Burst: rajada que empurra
	skill({
		Name = "Wind Burst",
		Color = { 220, 240, 255 },
		Cooldown = 4,
		Move = "Line",
		Speed = 8,
		Travel = 4,
		Size = 0.9,
		CityRate = 4,
		Once = true,
		ImpactHp = 0.15,
		Pull = -40,
	}),
	-- 2. Dust Devil — Dust Dash: redemoinho que corre em linha e estoura no fim
	skill({
		Name = "Dust Dash",
		Color = { 222, 196, 150 },
		Cooldown = 8,
		Move = "Line",
		Speed = 5,
		Travel = 6,
		Size = 0.7,
		CityRate = 2.5,
		HpRate = 0.15,
		Pull = 15,
		Burst = { Size = 1.5, City = 1.5, Hp = 0.1, Cap = 20, PerItem = 0.05 },
	}),
	-- 3. Tornado — Vortex Slam: suga em volta e explode com o que juntou
	skill({
		Name = "Vortex Slam",
		Color = { 200, 210, 230 },
		Cooldown = 10,
		Move = "Self",
		Duration = 2.5,
		Size = 2.2,
		CityRate = 1.2,
		HpRate = 0.06,
		Pull = 35,
		Burst = { Size = 2.5, City = 2.5, Hp = 0.15, Cap = 30, PerItem = 0.04 },
	}),
	-- 4. Supertornado — Twin Cyclones: dois tornados menores giram em volta e voltam
	skill({
		Name = "Twin Cyclones",
		Color = { 120, 130, 170 },
		Cooldown = 12,
		Move = "Orbit",
		Duration = 4,
		Count = 2,
		Orbit = 2.5,
		Spin = 2.2,
		Return = 0.8,
		Size = 0.8,
		CityRate = 2,
		HpRate = 0.06,
		Burst = { Size = 2, City = 2, Hp = 0.12, Cap = 40, PerItem = 0.03 },
	}),
	-- 5. Hurricane — Eye of the Storm: área enorme parada, puxa para o centro e estoura em volta
	skill({
		Name = "Eye of the Storm",
		Color = { 70, 90, 150 },
		Cooldown = 15,
		Move = "Fixed",
		Ahead = 0,
		Duration = 5,
		Size = 3.5,
		CityRate = 0.8,
		HpRate = 0.04,
		Pull = 25,
		Burst = { Size = 3.5, City = 2, Hp = 0.15, Cap = 50, PerItem = 0.02 },
	}),
	-- 6. Typhoon — Tidal Surge: onda que avança arrastando e joga tudo para o alto no fim
	skill({
		Name = "Tidal Surge",
		Color = { 60, 170, 190 },
		Cooldown = 14,
		Move = "Line",
		Speed = 4,
		Travel = 7,
		Size = 1.2,
		CityRate = 3,
		HpRate = 0.12,
		Drag = 40,
		Burst = { Size = 1.5, City = 2, Hp = 0.12, Cap = 40, PerItem = 0.03 },
	}),
	-- 7. Firenado — Inferno Spiral: tornado de fogo que zigue-zagueia, deixa fogo no chão e explode
	skill({
		Name = "Inferno Spiral",
		Color = { 255, 120, 40 },
		Cooldown = 15,
		Move = "Line",
		Speed = 1.6,
		Travel = 4,
		Wobble = 3,
		Size = 0.9,
		CityRate = 2.5,
		HpRate = 0.1,
		Trail = true,
		TrailSeconds = 3,
		TrailRate = 0.8,
		Burst = { Size = 1.8, City = 2.5, Hp = 0.15, Cap = 30, PerItem = 0.03 },
	}),
	-- 8. Void Storm — Black Hole: singularidade à frente que cresce, puxa tudo e implode
	skill({
		Name = "Black Hole",
		Color = { 120, 60, 170 },
		Cooldown = 18,
		Move = "Fixed",
		Ahead = 3,
		Duration = 5,
		Size = 1,
		Grow = 2,
		CityRate = 1.5,
		HpRate = 0.05,
		Pull = 50,
		Burst = { Size = 3.5, City = 3, Hp = 0.2, Cap = 60, PerItem = 0.03 },
	}),
})
