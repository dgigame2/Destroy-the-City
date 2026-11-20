-- Etapa 4: os 5 níveis de cada elemento (Logic/ElementPlan + Config/ElementConfig.Levels).
local ElementPlan = require("../src/shared/Logic/ElementPlan")
local MatchSim = require("../src/shared/Logic/MatchSim")
local MatchCity = require("../src/shared/Logic/MatchCity")
local CityGen = require("../src/shared/Logic/CityGen")
local Rng = require("../src/shared/Logic/Rng")
local ElementConfig = require("../src/shared/Config/ElementConfig")
local MatchConfig = require("../src/shared/Config/MatchConfig")
local Templates = require("../src/shared/Buildings/Templates")
local MapConfig = require("../src/shared/Config/MapConfig")
local CityPlans = require("../src/shared/Config/CityPlans")
local CityConfig = require("../src/shared/Config/CityConfig")
local DistrictConfig = require("../src/shared/Config/DistrictConfig")
local ModelCatalog = require("../src/shared/Config/ModelCatalog")

local MAX = ElementConfig.MaxLevel
-- curva da velocidade de destruir por nível (AUDITORIA §11: ~5x no nível 5)
local CURVE = { 1, 1.5, 2.3, 3.4, 5 }

local function same(a, b)
	if #a.Pulses ~= #b.Pulses then
		return false
	end
	for i, p in a.Pulses do
		local q = b.Pulses[i]
		if p.At ~= q.At or p.X ~= q.X or p.Z ~= q.Z or p.Radius ~= q.Radius or p.Mult ~= q.Mult then
			return false
		end
	end
	return true
end

return function(t)
	t.test("níveis: todo elemento tem 5 níveis válidos e Power para cada um", function()
		for _, e in ElementConfig.List do
			t.equal(#e.Levels, MAX)
			t.equal(#e.Power, MAX)
			for level = 1, MAX do
				local plan = ElementPlan.build(e, level, MAX, 0, 0, 30, 40, 7)
				t.truthy(#plan.Pulses >= 1, `{e.Id} {level}`)
				t.truthy(plan.Cooldown > 0)
				t.truthy(plan.Duration <= 6) -- nenhum golpe dura mais que 6 s
				for _, p in plan.Pulses do
					t.truthy(p.Radius > 0 and p.Mult > 0 and p.MaxTargets >= 1 and p.At >= 0)
				end
			end
		end
	end)

	t.test("plano: mesma semente = mesmo golpe em servidor e clientes; outra semente muda o sorteio", function()
		local bolt = ElementConfig.ById.Lightning
		local a = ElementPlan.build(bolt, 4, MAX, 0, 0, 50, 0, 123)
		local b = ElementPlan.build(bolt, 4, MAX, 0, 0, 50, 0, 123)
		local c = ElementPlan.build(bolt, 4, MAX, 0, 0, 50, 0, 124)
		t.truthy(same(a, b))
		t.falsy(same(a, c))
	end)

	t.test("formas: impacto no alvo, cone e tornado seguem a direção do golpe, tempestade fica na área", function()
		local fire = ElementConfig.ById.Fire
		local p1 = ElementPlan.build(fire, 1, MAX, 0, 0, 100, 0, 1).Pulses
		t.equal(#p1, 1)
		t.equal(p1[1].X, 100)
		local wind = ElementConfig.ById.Wind
		local cone = ElementPlan.build(wind, 2, MAX, 0, 0, 100, 0, 1).Pulses
		for i = 2, #cone do
			t.truthy(cone[i].X > cone[i - 1].X) -- para frente (+X)
			t.truthy(cone[i].At > cone[i - 1].At)
		end
		local tornado = ElementPlan.build(wind, 4, MAX, 0, 0, 0, 100, 1).Pulses
		t.truthy(tornado[#tornado].Z > tornado[1].Z + 30) -- andou na direção +Z
		local vortex = ElementPlan.build(wind, 3, MAX, 0, 0, 0, 100, 1).Pulses
		t.near(vortex[#vortex].Z, vortex[1].Z) -- vórtice parado
		local bolt = ElementConfig.ById.Lightning
		local storm = ElementPlan.build(bolt, 4, MAX, 0, 0, 200, 200, 9)
		local area = bolt.Levels[4].Parts[1].Area * bolt.Radius
		for _, p in storm.Pulses do
			t.truthy(math.sqrt((p.X - 200) ^ 2 + (p.Z - 200) ^ 2) <= area + 1e-6)
		end
	end)

	t.test("níveis 3 e 5 mudam a mecânica: cadeia do raio, fogo que espalha", function()
		local bolt = ElementConfig.ById.Lightning
		t.truthy(ElementPlan.build(bolt, 3, MAX, 0, 0, 1, 1, 1).Pulses[1].Chain ~= nil)
		t.truthy(ElementPlan.build(bolt, 5, MAX, 0, 0, 1, 1, 1).Pulses[1].Chain.Hops > 3)
		local fire = ElementConfig.ById.Fire
		t.equal(ElementPlan.build(fire, 2, MAX, 0, 0, 1, 1, 1).Burn.Foci, 0)
		t.truthy(ElementPlan.build(fire, 3, MAX, 0, 0, 1, 1, 1).Burn.Foci > 0)
	end)

	t.test("cadeia: salta para o mais perto ainda não usado, respeita o alcance e os saltos", function()
		local list = {
			{ Id = 1, X = 10, Z = 0 },
			{ Id = 2, X = 20, Z = 0 },
			{ Id = 3, X = 30, Z = 0 },
			{ Id = 4, X = 200, Z = 0 },
		}
		local hops = ElementPlan.chain(0, 0, list, 5, 15, {})
		t.equal(#hops, 3)
		t.equal(hops[1].Id, 1)
		t.equal(hops[3].Id, 3)
		local used = { [1] = true }
		t.equal(#ElementPlan.chain(0, 0, list, 5, 15, used), 0) -- o 2 está a 20 (fora do alcance)
		t.equal(#ElementPlan.chain(0, 0, list, 1, 15, {}), 1)
	end)

	t.test("nível fora da faixa é cortado; cooldown do nível vale", function()
		local wind = ElementConfig.ById.Wind
		t.equal(ElementPlan.cooldown(wind, 99, MAX), wind.Levels[MAX].Cooldown)
		t.equal(ElementPlan.cooldown(wind, -1, MAX), wind.Cooldown)
	end)

	-- balanceamento na cidade real (Garden Village, normal)
	local map = MapConfig[1]
	local layout =
		CityGen.generate(CityPlans[map.Id], DistrictConfig[map.Style], Templates, Rng.new(map.Seed), CityConfig, 1)
	local infos = MatchCity.infos(layout.Placements, Templates, ModelCatalog, MatchConfig)
	local land = 0
	for _, info in infos do
		land += (info.Box[3] - info.Box[1]) * (info.Box[4] - info.Box[2])
	end
	land *= 2.5
	local density = MatchSim.density(infos, land)

	t.test("balanço: cada nível destrói ~1 / 1,5 / 2,3 / 3,4 / 5x mais rápido que o nível 1 (±15%)", function()
		for _, e in ElementConfig.List do
			local d1 = ElementPlan.expectedDps(e, 1, MAX, density)
			for level = 2, MAX do
				local ratio = ElementPlan.expectedDps(e, level, MAX, density) / d1
				if math.abs(ratio / CURVE[level] - 1) > 0.15 then
					error(`{e.Id} nível {level}: {string.format("%.2f", ratio)}x (meta {CURVE[level]}x)`)
				end
			end
		end
	end)

	t.test("balanço: no nível 1 os três elementos limpam a cidade em tempos parecidos (±20%)", function()
		local times = {}
		for _, e in ElementConfig.List do
			local r = MatchSim.run(
				infos,
				land,
				e,
				1,
				1,
				0.5,
				MatchConfig.Milestones,
				MatchConfig.CompleteAt,
				ElementConfig.TallBonus
			)
			table.insert(times, r.Seconds)
		end
		local avg = (times[1] + times[2] + times[3]) / 3
		for i, s in times do
			if math.abs(s / avg - 1) > 0.2 then
				error(
					`{ElementConfig.List[i].Id}: {string.format("%.1f", s / 60)} min (média {string.format(
						"%.1f",
						avg / 60
					)})`
				)
			end
		end
	end)
end
