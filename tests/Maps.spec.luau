-- Verificações de level design nos 5 mapas gerados:
-- OVERLAPS, limites do mapa (SHOULDN'T REACH), spawns livres (NO WAY OUT),
-- progressão sem beco sem saída (UNREACHABLE) e vitória alcançável.
local MapGen = require("../src/shared/Logic/MapGen")
local Rng = require("../src/shared/Logic/Rng")
local Growth = require("../src/shared/Logic/Growth")
local Templates = require("../src/shared/Buildings/Templates")
local MapConfig = require("../src/shared/Config/MapConfig")
local TierConfig = require("../src/shared/Config/TierConfig")
local GrowthConfig = require("../src/shared/Config/GrowthConfig")

local function rect(p)
	return p.X - p.Width / 2, p.Z - p.Depth / 2, p.X + p.Width / 2, p.Z + p.Depth / 2
end

local function overlaps(a, b)
	local ax0, az0, ax1, az1 = rect(a)
	local bx0, bz0, bx1, bz1 = rect(b)
	return ax0 < bx1 and bx0 < ax1 and az0 < bz1 and bz0 < az1
end

-- Come tudo que der, do menor para o maior, até não conseguir mais nada. Retorna escala final e tiers alcançados.
local function simulateFullClear(layout)
	local items = {}
	for _, p in layout.Placements do
		table.insert(items, Templates[p.Template].Tier)
	end
	table.sort(items)
	local eaten = {}
	local points = 0
	local progress = true
	while progress do
		progress = false
		local scale = Growth.scaleFromPoints(points, GrowthConfig)
		for i, tierIndex in items do
			if not eaten[i] and Growth.canEatTier(scale, TierConfig[tierIndex]) then
				eaten[i] = true
				points += TierConfig[tierIndex].Growth
				scale = Growth.scaleFromPoints(points, GrowthConfig)
				progress = true
			end
		end
	end
	local eatenAll = true
	for i in items do
		eatenAll = eatenAll and eaten[i] == true
	end
	return Growth.scaleFromPoints(points, GrowthConfig), eatenAll, points
end

local function generate(map)
	return MapGen.generate(map, Templates, Rng.new(map.Seed))
end

return function(t)
	for _, map in MapConfig do
		local layout = generate(map)

		t.test(`{map.Id}: geração determinística`, function()
			local again = generate(map)
			t.equal(#again.Placements, #layout.Placements)
			for i, p in layout.Placements do
				t.equal(again.Placements[i].Template, p.Template)
				t.equal(again.Placements[i].X, p.X)
				t.equal(again.Placements[i].Z, p.Z)
			end
		end)

		t.test(`{map.Id}: construções suficientes ({#layout.Placements})`, function()
			t.truthy(#layout.Placements >= 300)
		end)

		t.test(`{map.Id}: nenhuma construção sobreposta (OVERLAPS)`, function()
			local list = layout.Placements
			for i = 1, #list do
				for j = i + 1, #list do
					if overlaps(list[i], list[j]) then
						error(
							`{list[i].Template} em ({list[i].X},{list[i].Z}) sobrepõe {list[j].Template} em ({list[j].X},{list[j].Z})`
						)
					end
				end
			end
		end)

		t.test(`{map.Id}: tudo dentro dos limites do mapa`, function()
			local hx, hz = layout.Size[1] / 2, layout.Size[2] / 2
			for _, p in layout.Placements do
				local x0, z0, x1, z1 = rect(p)
				t.truthy(x0 >= -hx and x1 <= hx and z0 >= -hz and z1 <= hz)
			end
		end)

		t.test(`{map.Id}: spawns em lugar livre (NO WAY OUT)`, function()
			t.truthy(#layout.Spawns > 0)
			local radius = 4 -- espaço livre mínimo ao redor do spawn
			for _, s in layout.Spawns do
				local probe = { X = s[1], Z = s[2], Width = radius * 2, Depth = radius * 2 }
				for _, p in layout.Placements do
					if overlaps(probe, p) then
						error(`spawn ({s[1]},{s[2]}) bloqueado por {p.Template}`)
					end
				end
			end
		end)

		t.test(`{map.Id}: todos os tiers existem no mapa`, function()
			local seen = {}
			for _, p in layout.Placements do
				seen[Templates[p.Template].Tier] = true
			end
			for tier in TierConfig do
				if not seen[tier] then
					error(`falta tier {tier} ({TierConfig[tier].Name})`)
				end
			end
		end)

		t.test(`{map.Id}: progressão sem beco sem saída e vitória alcançável (UNREACHABLE)`, function()
			local finalScale, eatenAll = simulateFullClear(layout)
			if not eatenAll then
				error(`jogador fica travado: escala final {finalScale}`)
			end
			if finalScale < map.WinScale then
				error(`comendo o mapa inteiro chega só à escala {finalScale}, vitória exige {map.WinScale}`)
			end
		end)

		t.test(`{map.Id}: tamanho de vitória abaixo do teto de escala`, function()
			t.truthy(map.WinScale < GrowthConfig.MaxScale)
		end)

		t.test(`{map.Id}: vitória não é fácil demais (exige >= 40% do crescimento do mapa)`, function()
			local _, _, totalPoints = simulateFullClear(layout)
			local winPoints = Growth.pointsForScale(map.WinScale, GrowthConfig)
			t.truthy(winPoints >= totalPoints * 0.4)
		end)
	end
end
