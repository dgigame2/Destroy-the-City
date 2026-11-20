-- Dados da partida a partir da cidade real: caixas no mundo, valor, vida e simulação de tempo.
local Templates = require("../src/shared/Buildings/Templates")
local MapConfig = require("../src/shared/Config/MapConfig")
local CityPlans = require("../src/shared/Config/CityPlans")
local CityConfig = require("../src/shared/Config/CityConfig")
local DistrictConfig = require("../src/shared/Config/DistrictConfig")
local ModelCatalog = require("../src/shared/Config/ModelCatalog")
local MatchConfig = require("../src/shared/Config/MatchConfig")
local ElementConfig = require("../src/shared/Config/ElementConfig")
local CityGen = require("../src/shared/Logic/CityGen")
local MatchCity = require("../src/shared/Logic/MatchCity")
local MatchSim = require("../src/shared/Logic/MatchSim")
local Elements = require("../src/shared/Logic/Elements")
local Rng = require("../src/shared/Logic/Rng")

local map = MapConfig[1]
local layout =
	CityGen.generate(CityPlans[map.Id], DistrictConfig[map.Style], Templates, Rng.new(map.Seed), CityConfig, 1)

return function(t)
	t.test("caixa no mundo: girar 90° troca largura e fundo, 180° mantém", function()
		local min, max = { -2, 0, -6 }, { 2, 5, 6 }
		local b0 = MatchCity.worldBox(min, max, 0, 100, 50)
		t.near(b0[1], 98)
		t.near(b0[4], 56)
		local b90 = MatchCity.worldBox(min, max, 90, 100, 50)
		t.near(b90[3] - b90[1], 12)
		t.near(b90[4] - b90[2], 4)
		local b180 = MatchCity.worldBox(min, max, 180, 0, 0)
		t.near(b180[3] - b180[1], 4)
	end)

	t.test("cidade real: todo objeto tem vida > 0; só construções contam no progresso", function()
		local infos = MatchCity.infos(layout.Placements, Templates, ModelCatalog, MatchConfig)
		t.equal(#infos, #layout.Placements)
		local counted = 0
		for i, info in infos do
			t.truthy(info.MaxHp > 0, layout.Placements[i].Template)
			t.truthy(info.Box[3] >= info.Box[1] and info.Box[4] >= info.Box[2])
			if info.Value > 0 then
				counted += 1
				t.truthy((MatchConfig.Value.Weight[info.Category] or 0) > 0)
			end
		end
		t.truthy(counted > 100)
	end)

	t.test("valor: prédio maior vale mais que casa pequena, mas não a cidade inteira", function()
		local cfg = MatchConfig
		local house = MatchCity.value(12, 12, 10, 1, cfg)
		local office = MatchCity.value(24, 24, 60, 1, cfg)
		t.truthy(office > house * 3)
		local infos = MatchCity.infos(layout.Placements, Templates, ModelCatalog, cfg)
		local total, biggest = 0, 0
		for _, info in infos do
			total += info.Value
			biggest = math.max(biggest, info.Value)
		end
		t.truthy(biggest < total * 0.05) -- nenhuma construção sozinha vale 5% da cidade
	end)

	t.test("servidor e cliente geram os mesmos dados (mesma semente)", function()
		local again =
			CityGen.generate(CityPlans[map.Id], DistrictConfig[map.Style], Templates, Rng.new(map.Seed), CityConfig, 1)
		local a = MatchCity.infos(layout.Placements, Templates, ModelCatalog, MatchConfig)
		local b = MatchCity.infos(again.Placements, Templates, ModelCatalog, MatchConfig)
		t.equal(#a, #b)
		for i = 1, #a do
			t.equal(a[i].MaxHp, b[i].MaxHp)
			t.equal(a[i].Box[1], b[i].Box[1])
		end
	end)

	t.test("chão: dentro da cidade tem altura, fora não", function()
		local s = layout.Spawns[1][1]
		t.truthy(MatchCity.groundAt(layout.Grid, CityConfig.CellSize, s[1], s[3]) ~= nil)
		t.equal(MatchCity.groundAt(layout.Grid, CityConfig.CellSize, 1e6, 1e6), nil)
	end)

	t.test("elementos: dano cresce por nível, nível fora da faixa é cortado, cooldown e alcance valem", function()
		local fire = ElementConfig.ById.Fire
		t.equal(Elements.damage(fire, 5, 5), fire.Damage * fire.Power[5])
		t.equal(Elements.damage(fire, 99, 5), Elements.damage(fire, 5, 5))
		t.equal(Elements.damage(fire, -3, 5), Elements.damage(fire, 1, 5))
		t.falsy((Elements.canCast(fire, 10, 10.1, 5)))
		t.falsy((Elements.canCast(fire, 10, 11, 5, 3))) -- cooldown do nível (3 s)
		t.truthy((Elements.canCast(fire, 10, 13.1, 5, 3)))
		t.falsy((Elements.canCast(fire, nil, 10, fire.Range + 1)))
		t.falsy((Elements.canCast(fire, nil, 10, 0 / 0)))
		t.truthy((Elements.canCast(fire, 1, 10, 5)))
		t.truthy(Elements.against(ElementConfig.ById.Wind, "Vehicle", 2, 1.5) > 1)
		t.truthy(Elements.against(ElementConfig.ById.Lightning, "Building", 50, 1.5) > 1)
	end)

	t.test("simulação: mais jogadores = mais rápido, mas 4 não é 4× (alvos disputados)", function()
		local infos = MatchCity.infos(layout.Placements, Templates, ModelCatalog, MatchConfig)
		local function secs(n)
			return MatchSim.run(infos, 1e6, ElementConfig.ById.Fire, 1, n, 0.5, MatchConfig.Milestones, 0.985, 1.5).Seconds
		end
		t.truthy(secs(2) < secs(1))
		t.truthy(secs(4) < secs(2))
		t.truthy(secs(4) > secs(1) / 4)
	end)
end
