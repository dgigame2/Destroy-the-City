-- Desastres da Fase 3 (Meteoro, Tornado, Raio): matemática pura e a regra de 4 jogadores ao mesmo tempo.
local Disasters = require("../src/shared/Logic/Disasters")
local StructureHealth = require("../src/shared/Logic/StructureHealth")
local Score = require("../src/shared/Logic/Score")
local DisasterConfig = require("../src/shared/Config/DisasterConfig")
local StructureConfig = require("../src/shared/Config/StructureConfig")
local ScoreConfig = require("../src/shared/Config/ScoreConfig")
local TierConfig = require("../src/shared/Config/TierConfig")
local FeedbackConfig = require("../src/shared/Config/FeedbackConfig")

return function(t)
	local cfg = DisasterConfig
	local meteor, tornado, lightning = cfg.ById.Meteor, cfg.ById.Tornado, cfg.ById.Lightning

	t.test("três desastres iniciais, todos no degrau 1 da curva de poder", function()
		t.equal(#cfg.List, 3)
		for _, d in cfg.List do
			t.equal(d.PowerTier, 1)
			t.truthy(d.Cooldown > 0 and d.Range > 0 and d.Damage > 0)
		end
	end)

	t.test("mecânicas diferentes: ponto (meteoro), linha (tornado), rede (raio)", function()
		t.truthy(meteor.Delay ~= nil and meteor.Radius ~= nil and meteor.Speed == nil)
		t.truthy(tornado.Speed ~= nil and tornado.Duration ~= nil and tornado.Hops == nil)
		t.truthy(lightning.Hops ~= nil and lightning.Radius == nil)
	end)

	t.test("construção forte: abaixo do poder leva dano, mas bem menos (nada fica travado)", function()
		local under = StructureConfig.UnderPower
		local weak = Disasters.hitDamage(tornado, 1.9, TierConfig[3], nil, under)
		local ok = Disasters.hitDamage(tornado, 2, TierConfig[3], nil, under)
		t.truthy(weak > 0)
		t.truthy(weak < ok * 0.5)
		t.equal(Disasters.underPower(5, TierConfig[5], under), 1)
	end)

	t.test("avião/hangar (tier 5) no começo: muitos meteoros; com o poder certo, 1 acerto", function()
		local under = StructureConfig.UnderPower
		local tier = TierConfig[5]
		local hp = Disasters.structureHp(tier, StructureConfig.HpPerScale)
		t.truthy(hp / Disasters.hitDamage(meteor, 1, tier, nil, under) >= 15)
		t.truthy(hp / Disasters.hitDamage(meteor, tier.RequiredScale, tier, nil, under) <= 1)
	end)

	t.test(
		"meteoro no centro derruba casa ou maior do seu tamanho em 1 acerto (pequeno é papel do tornado)",
		function()
			for i = 3, #TierConfig do
				local tier = TierConfig[i]
				local hp = Disasters.structureHp(tier, StructureConfig.HpPerScale)
				local damage = Disasters.hitDamage(meteor, tier.RequiredScale, tier)
				if damage < hp then
					error(`tier {i}: meteoro faz {damage} e o HP é {hp}`)
				end
			end
		end
	)

	t.test("tornado moe o que é pequeno e quase não arranha o do seu tamanho", function()
		local power = 5
		local small = Disasters.hitDamage(tornado, power, TierConfig[2]) / Disasters.structureHp(TierConfig[2], 120)
		local same = Disasters.hitDamage(tornado, power, TierConfig[5]) / Disasters.structureHp(TierConfig[5], 120)
		t.truthy(small >= 1) -- um tique derruba
		t.truthy(same < 0.2) -- precisa de vários tiques
	end)

	t.test("onda de choque do meteoro: cheia no miolo, cai até a borda, zero fora", function()
		t.near(Disasters.meteorFalloff(0, 10, 0.35, 0.25), 1)
		t.near(Disasters.meteorFalloff(3.5, 10, 0.35, 0.25), 1)
		t.near(Disasters.meteorFalloff(10, 10, 0.35, 0.25), 0.25)
		t.equal(Disasters.meteorFalloff(10.1, 10, 0.35, 0.25), 0)
		local a, b = Disasters.meteorFalloff(5, 10, 0.35, 0.25), Disasters.meteorFalloff(8, 10, 0.35, 0.25)
		t.truthy(a > b)
	end)

	t.test("mira longe demais é puxada para o alcance (servidor não confia no cliente)", function()
		local x, z = Disasters.clampTarget(0, 0, 300, 400, 50)
		t.near(math.sqrt(x * x + z * z), 50)
		local x2, z2 = Disasters.clampTarget(0, 0, 10, 0, 50)
		t.near(x2, 10)
		t.near(z2, 0)
	end)

	t.test("alcance, raio e velocidade crescem com o poder", function()
		t.truthy(Disasters.radius(meteor, 4, cfg) > Disasters.radius(meteor, 1, cfg))
		t.truthy(Disasters.range(meteor, 4, cfg) > Disasters.range(meteor, 1, cfg))
		t.truthy(Disasters.speed(tornado, 4, cfg) > Disasters.speed(tornado, 1, cfg))
	end)

	t.test("tornado arrasta objetos leves (postes, bancos) já no poder inicial; o resto continua no dano", function()
		t.truthy(Disasters.sweeps(tornado, 1, TierConfig[1]))
		t.falsy(Disasters.sweeps(tornado, 10, TierConfig[3])) -- casas não são arrastadas, levam dano
		t.falsy(Disasters.sweeps(meteor, 10, TierConfig[1])) -- só o tornado arrasta
		-- sem arrastar, uma passada não derrubaria um poste no poder inicial (era o bug)
		local ticks = Disasters.contactTicks(tornado.Radius, tornado.Speed, tornado.Tick)
		t.truthy(ticks * Disasters.hitDamage(tornado, 1, TierConfig[1]) < Disasters.structureHp(TierConfig[1], 120))
	end)

	t.test("tornado anda em linha reta na direção da mira", function()
		local dx, dz = Disasters.direction(0, 0, 0, 10, 1, 0)
		local x, z = Disasters.tornadoAt(0, 0, dx, dz, 20, 2)
		t.near(x, 0)
		t.near(z, 40)
		local fx, fz = Disasters.direction(5, 5, 5, 5, 3, 4)
		t.near(fx, 0.6)
		t.near(fz, 0.8)
	end)

	local function line(n, gap, conductorAt)
		local nodes = {}
		for i = 1, n do
			table.insert(nodes, { Id = i, X = (i - 1) * gap, Z = 0, Conductor = conductorAt == i })
		end
		return nodes
	end

	t.test("raio: começa no mais perto da mira e pula vizinho a vizinho perdendo força", function()
		local chain = Disasters.lightningChain(line(10, 5, nil), 0, 1, 8, 6, 9, 0.75, 1.6)
		t.equal(#chain, 7) -- primeiro alvo + 6 pulos
		t.equal(chain[1].Id, 1)
		t.equal(chain[2].Id, 2)
		t.near(chain[2].Strength, 0.75)
		t.near(chain[3].Strength, 0.75 * 0.75)
	end)

	t.test("raio: condutor não perde força e pula mais longe", function()
		-- vão de 12 entre 2 e 3: pulo normal (9) não alcança; condutor (9 x 1.6) alcança
		local nodes = {
			{ Id = 1, X = 0, Z = 0, Conductor = false },
			{ Id = 2, X = 5, Z = 0, Conductor = true },
			{ Id = 3, X = 17, Z = 0, Conductor = false },
		}
		local chain = Disasters.lightningChain(nodes, 0, 0, 8, 6, 9, 0.75, 1.6)
		t.equal(#chain, 3)
		t.near(chain[3].Strength, 0.75) -- perdeu só no pulo 1->2
		local plain = table.clone(nodes)
		plain[2] = { Id = 2, X = 5, Z = 0, Conductor = false }
		t.equal(#Disasters.lightningChain(plain, 0, 0, 8, 6, 9, 0.75, 1.6), 2)
	end)

	t.test("raio: nada perto da mira = nada atingido; nunca acerta o mesmo duas vezes", function()
		t.equal(#Disasters.lightningChain(line(3, 5, nil), 100, 100, 8, 6, 9, 0.75, 1.6), 0)
		local seen = {}
		for _, hop in Disasters.lightningChain(line(4, 1, 2), 0, 0, 8, 20, 9, 0.75, 1.6) do
			t.falsy(seen[hop.Id])
			seen[hop.Id] = true
		end
	end)

	t.test("cooldown", function()
		t.truthy(Disasters.ready(nil, 3, 0))
		t.falsy(Disasters.ready(10, 3, 12))
		t.truthy(Disasters.ready(10, 3, 13))
	end)

	t.test("4 jogadores acertando as mesmas construções ao mesmo tempo: cada uma cai e pontua UMA vez", function()
		local state = StructureHealth.new()
		local scores = { 0, 0, 0, 0 }
		local destroyed = 0
		local hp = Disasters.structureHp(TierConfig[3], StructureConfig.HpPerScale)
		-- 50 construções, 4 jogadores, 10 rodadas de golpes intercalados (meteoro + tornado + raio)
		for _ = 1, 10 do
			for id = 1, 50 do
				for player = 1, 4 do
					local d = cfg.List[(player + id) % 3 + 1]
					local damage = Disasters.hitDamage(d, 2.5, TierConfig[3]) * 0.3
					if StructureHealth.hit(state, id, damage, hp) then
						destroyed += 1
						scores[player] += Score.forDestroy(3, ScoreConfig.PointsByTier)
					end
				end
			end
		end
		t.equal(destroyed, 50)
		t.equal(scores[1] + scores[2] + scores[3] + scores[4], 50 * ScoreConfig.PointsByTier[3])
		t.falsy(StructureHealth.hit(state, 1, 9999, hp))
		t.falsy(StructureHealth.kill(state, 1))
	end)

	t.test("vida parcial: fração cai com o dano e zera ao destruir", function()
		local state = StructureHealth.new()
		t.falsy(StructureHealth.hit(state, 7, 25, 100))
		t.near(StructureHealth.fraction(state, 7, 100), 0.75)
		t.truthy(StructureHealth.hit(state, 7, 80, 100))
		t.equal(StructureHealth.fraction(state, 7, 100), 0)
	end)

	t.test("placar: ordem do maior para o menor", function()
		local r = Score.ranking({ { Name = "B", Score = 5 }, { Name = "A", Score = 9 }, { Name = "C", Score = 5 } })
		t.equal(r[1].Name, "A")
		t.equal(r[2].Name, "B")
	end)

	t.test("pontos sobem com o tier", function()
		for i = 2, #TierConfig do
			t.truthy(ScoreConfig.PointsByTier[i] > ScoreConfig.PointsByTier[i - 1])
		end
	end)

	t.test("lançar desastre tem feedback triplo", function()
		t.truthy(FeedbackConfig.Kinds.Cast ~= nil)
	end)
end
