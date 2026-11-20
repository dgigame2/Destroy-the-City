-- Cidadezinha em volta do parque do lobby: faixas só encostam, casas/árvores/carros não se cruzam, casas
-- ficam nos lotes e carros na rua sem pisar na faixa amarela.
local LobbyTown = require("../src/shared/Logic/LobbyTown")
local LobbyConfig = require("../src/shared/Config/LobbyConfig")
local Templates = require("../src/shared/Buildings/Templates")

local cfg = LobbyConfig.Town
local town = LobbyTown.build(LobbyConfig.Width, LobbyConfig.Depth, cfg)
local TOL = 0.001

local function overlap(a, b): boolean
	return a.X0 < b.X1 - TOL and b.X0 < a.X1 - TOL and a.Z0 < b.Z1 - TOL and b.Z0 < a.Z1 - TOL
end

local function inside(a, b): boolean
	return a.X0 >= b.X0 - TOL and a.X1 <= b.X1 + TOL and a.Z0 >= b.Z0 - TOL and a.Z1 <= b.Z1 + TOL
end

local function boxOf(item)
	return LobbyTown.box(item, cfg, Templates)
end

local PARK =
	{ X0 = -LobbyConfig.Width / 2, Z0 = -LobbyConfig.Depth / 2, X1 = LobbyConfig.Width / 2, Z1 = LobbyConfig.Depth / 2 }

return function(t)
	t.test("cidade: calçadas, ruas e gramado só encostam (e nenhum entra no parque)", function()
		local all = {}
		for _, group in { town.Sidewalks, town.Roads, town.Ground } do
			for _, r in group do
				table.insert(all, r)
			end
		end
		for i = 1, #all do
			t.truthy(not overlap(all[i], PARK), i)
			for j = i + 1, #all do
				t.truthy(not overlap(all[i], all[j]), `{i} x {j}`)
			end
		end
	end)

	t.test("cidade: faixa amarela fica em cima da rua", function()
		t.truthy(#town.Dashes > 0)
		for i, d in town.Dashes do
			local ok = false
			for _, r in town.Roads do
				ok = ok or inside(d, r)
			end
			t.truthy(ok, i)
		end
	end)

	t.test("cidade: casas e árvores nos lotes, sem encostar uma na outra", function()
		local things = {}
		for _, group in { town.Houses, town.Trees } do
			for _, item in group do
				table.insert(things, { item.Template, boxOf(item) })
			end
		end
		t.truthy(#town.Houses >= 20)
		for i, a in things do
			local onLot = false
			for _, g in town.Ground do
				onLot = onLot or inside(a[2], g)
			end
			t.truthy(onLot, `{a[1]} {i} fora do gramado dos lotes`)
			-- não passa da faixa dos lotes (fica perto da rua)
			t.truthy(math.max(math.abs(a[2].X0), math.abs(a[2].X1)) <= town.Outer[1] + TOL, i)
			t.truthy(math.max(math.abs(a[2].Z0), math.abs(a[2].Z1)) <= town.Outer[2] + TOL, i)
			for j = i + 1, #things do
				t.truthy(not overlap(a[2], things[j][2]), `{a[1]} {i} x {things[j][1]} {j}`)
			end
		end
	end)

	t.test("cidade: prédios do fundo atrás das casas, sem encostar em nada", function()
		t.truthy(#town.Buildings >= 16)
		local others = {}
		for _, group in { town.Houses, town.Trees } do
			for _, item in group do
				table.insert(others, boxOf(item))
			end
		end
		for i, b in town.Buildings do
			local box = boxOf(b)
			-- atrás da faixa das casas (fora dela) e dentro do gramado
			local behind = math.max(math.abs(box.X0), math.abs(box.X1)) > town.Outer[1] + TOL
				or math.max(math.abs(box.Z0), math.abs(box.Z1)) > town.Outer[2] + TOL
			t.truthy(behind, i)
			local onGround = false
			for _, g in town.Ground do
				onGround = onGround or inside(box, g)
			end
			t.truthy(onGround, i)
			for _, o in others do
				t.truthy(not overlap(box, o), `prédio {i} encosta numa casa/árvore`)
			end
			for j = i + 1, #town.Buildings do
				t.truthy(not overlap(box, boxOf(town.Buildings[j])), `{b.Template} {i} x {j}`)
			end
		end
	end)

	t.test(
		"cidade: floresta atrás dos prédios e morros no horizonte, sem nada se cruzar e tudo no gramado",
		function()
			t.truthy(#town.Forest >= 60)
			t.truthy(#town.Hills >= 10)
			local placed = {}
			for _, group in { town.Houses, town.Trees, town.Buildings } do
				for _, item in group do
					table.insert(placed, boxOf(item))
				end
			end
			local list = {}
			for _, group in { town.Forest, town.Hills } do
				for _, item in group do
					table.insert(list, { item.Template, boxOf(item) })
				end
			end
			for i, a in list do
				-- pode ficar em cima da emenda de dois pedaços do gramado (mesma altura): confere a caixa toda
				local g = town.Ground
				local all = { X0 = g[1].X0, Z0 = g[1].Z0, X1 = g[2].X1, Z1 = g[2].Z1 }
				t.truthy(inside(a[2], all), `{a[1]} {i} fora do gramado`)
				for _, p in placed do
					t.truthy(not overlap(a[2], p), `{a[1]} {i} encosta na cidade`)
				end
				for j = i + 1, #list do
					t.truthy(not overlap(a[2], list[j][2]), `{a[1]} {i} x {list[j][1]} {j}`)
				end
			end
		end
	)

	t.test("cidade: carros parados na rua, sem pisar na faixa nem um no outro", function()
		t.equal(#town.Cars, cfg.Cars)
		for i, car in town.Cars do
			local b = boxOf(car)
			local onRoad = false
			for _, r in town.Roads do
				onRoad = onRoad or inside(b, r)
			end
			t.truthy(onRoad, i)
			for _, d in town.Dashes do
				t.truthy(not overlap(b, d), i)
			end
			for j = i + 1, #town.Cars do
				t.truthy(not overlap(b, boxOf(town.Cars[j])), `{i} x {j}`)
			end
		end
	end)
end
