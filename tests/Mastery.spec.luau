-- Nível de cada desastre (substitui os contratos), buff do raio e mira só no chão liberado.
local Mastery = require("../src/shared/Logic/Mastery")
local MasteryConfig = require("../src/shared/Config/MasteryConfig")
local Disasters = require("../src/shared/Logic/Disasters")
local DisasterConfig = require("../src/shared/Config/DisasterConfig")
local TierConfig = require("../src/shared/Config/TierConfig")

return function(t)
	local cfg = MasteryConfig

	t.test("nível: todo desastre começa no 1, igual ao DisasterConfig (sem bônus)", function()
		local entry = Mastery.new()
		t.equal(entry.Level, 1)
		t.equal(Mastery.damage(1, cfg), 1)
		t.equal(Mastery.size(1, cfg), 1)
		for _, d in DisasterConfig.List do
			t.equal(Mastery.extraHops(d.Id, 1, cfg), 0)
			t.equal(Mastery.extraDuration(d.Id, 1, cfg), 0)
		end
	end)

	t.test("nível: XP necessária cresce a cada nível e é 0 no máximo", function()
		for level = 2, cfg.MaxLevel - 1 do
			t.truthy(Mastery.need(level, cfg) > Mastery.need(level - 1, cfg))
		end
		t.equal(Mastery.need(cfg.MaxLevel, cfg), 0)
	end)

	t.test("nível: usar o desastre sobe o nível (pode subir vários de uma vez) e para no máximo", function()
		local entry = Mastery.new()
		t.equal(Mastery.add(entry, Mastery.need(1, cfg) - 1, cfg), 0)
		t.equal(Mastery.add(entry, 1, cfg), 1)
		t.equal(entry.Level, 2)
		t.equal(entry.Xp, 0)
		local big = Mastery.need(2, cfg) + Mastery.need(3, cfg) + 1
		t.equal(Mastery.add(entry, big, cfg), 2)
		t.equal(entry.Level, 4)
		Mastery.add(entry, 1e12, cfg)
		t.equal(entry.Level, cfg.MaxLevel)
		t.equal(Mastery.add(entry, 100, cfg), 0)
		t.equal(Mastery.progress(entry, cfg), 1)
	end)

	t.test("nível: XP maior para construções maiores; cadeia dá só uma parte", function()
		t.equal(#cfg.XpByTier, #TierConfig)
		for tier = 2, #TierConfig do
			t.truthy(Mastery.xp(tier, false, cfg) > Mastery.xp(tier - 1, false, cfg))
		end
		t.near(Mastery.xp(3, true, cfg), Mastery.xp(3, false, cfg) * cfg.ChainXp)
		t.equal(Mastery.add(Mastery.new(), 0, cfg), 0)
	end)

	t.test("nível: mais forte e maior a cada nível; raio ganha pulos e tornado dura mais", function()
		for level = 2, cfg.MaxLevel do
			t.truthy(Mastery.damage(level, cfg) > Mastery.damage(level - 1, cfg))
			t.truthy(Mastery.size(level, cfg) > Mastery.size(level - 1, cfg))
		end
		t.truthy(Mastery.extraHops("Lightning", cfg.MaxLevel, cfg) >= 2)
		t.equal(Mastery.extraHops("Meteor", cfg.MaxLevel, cfg), 0)
		t.truthy(Mastery.extraDuration("Tornado", cfg.MaxLevel, cfg) > 0)
		-- tamanho no máximo continua razoável (celular): até 2x
		t.truthy(Mastery.size(cfg.MaxLevel, cfg) <= 2)
	end)

	t.test("raio é zap: poucos pulos e recarga curta", function()
		local bolt = DisasterConfig.ById.Lightning
		t.truthy(bolt.Hops <= 3)
		t.truthy(bolt.Cooldown < DisasterConfig.ById.Meteor.Cooldown)
		t.truthy(bolt.Cooldown < DisasterConfig.ById.Tornado.Cooldown)
	end)

	-- chão liberado de exemplo: só x entre -10 e 10 (o resto é mar / área fechada)
	local function inside(x: number, _z: number): boolean
		return x >= -10 and x <= 10
	end

	t.test("mira: ponto no chão liberado não muda", function()
		local x, z, ok = Disasters.pullInside(0, 0, 5, 3, 3, inside)
		t.truthy(ok)
		t.equal(x, 5)
		t.equal(z, 3)
	end)

	t.test("mira: atrás da barreira volta para o último chão liberado na linha", function()
		local x, _, ok = Disasters.pullInside(0, 0, 40, 0, 3, inside)
		t.truthy(ok)
		t.truthy(x <= 10 and x >= 7)
	end)

	t.test("mira: jogador fora do chão liberado não lança nada", function()
		local _, _, ok = Disasters.pullInside(50, 0, 60, 0, 3, inside)
		t.falsy(ok)
	end)

	t.test("tornado: para na borda do chão liberado; dentro dele anda a duração toda", function()
		local cut = Disasters.travelTime(0, 0, 1, 0, 10, 5, 3, inside)
		t.truthy(cut > 0.5 and cut <= 1) -- anda ~10 studs a 10 studs/s
		t.equal(Disasters.travelTime(0, 0, 0, 1, 10, 5, 3, inside), 5) -- andando em Z, nunca sai
	end)
end
