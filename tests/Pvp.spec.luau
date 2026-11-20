-- PvP entre tornados: vida, engolir, rajada, equilíbrio, entrada do cliente.
local Pvp = require("../src/shared/Logic/Pvp")
local Tornado = require("../src/shared/Logic/Tornado")
local cfg = require("../src/shared/Config/PvpConfig")
local tcfg = require("../src/shared/Config/TornadoConfig")

return function(t)
	t.test("vida cresce com o nível", function()
		t.near(Pvp.maxHp(cfg, 1), cfg.Hp.Base)
		for level = 2, tcfg.MaxLevel do
			t.truthy(Pvp.maxHp(cfg, level) > Pvp.maxHp(cfg, level - 1))
		end
	end)

	t.test("só engole quem é LevelGap+ níveis maior", function()
		t.truthy(Pvp.canEat(cfg, 1 + cfg.LevelGap, 1))
		t.equal(Pvp.canEat(cfg, cfg.LevelGap, 1), false)
		t.equal(Pvp.canEat(cfg, 1, 1 + cfg.LevelGap), false)
	end)

	t.test("matar dá parte da barra da vítima", function()
		t.near(Pvp.killXp(cfg, tcfg, 5), cfg.KillXpShare * Tornado.xpToNext(tcfg, 5))
	end)

	t.test("regenera só depois do atraso, sem passar do máximo, e morto não regenera", function()
		t.equal(Pvp.regen(cfg, 50, 100, cfg.Regen.Delay - 0.1, 1), 50)
		t.near(Pvp.regen(cfg, 50, 100, cfg.Regen.Delay, 1), 50 + 100 * cfg.Regen.Share)
		t.equal(Pvp.regen(cfg, 99.9, 100, 99, 10), 100)
		t.equal(Pvp.regen(cfg, 0, 100, 99, 1), 0)
	end)

	t.test("vida mantém a porcentagem ao mudar o máximo", function()
		t.near(Pvp.rescale(50, 100, 200), 100)
		t.near(Pvp.rescale(10, 0, 200), 200)
	end)

	t.test("direção do cliente: lixo é recusado, válida é normalizada", function()
		t.equal(Pvp.direction(nil, 1), nil)
		t.equal(Pvp.direction("1", 1), nil)
		t.equal(Pvp.direction(0, 0), nil)
		t.equal(Pvp.direction(0 / 0, 1), nil)
		t.equal(Pvp.direction(math.huge, 1), nil)
		local x, z = Pvp.direction(3, 4)
		t.near(x :: number, 0.6)
		t.near(z :: number, 0.8)
	end)

	t.test("cone da rajada: na frente e perto acerta; atrás ou longe não", function()
		t.truthy(Pvp.inFront(0, 0, 1, 0, 5, 1, 10, cfg.Burst.MinDot))
		t.equal(Pvp.inFront(0, 0, 1, 0, -5, 0, 10, cfg.Burst.MinDot), false)
		t.equal(Pvp.inFront(0, 0, 1, 0, 11, 0, 10, cfg.Burst.MinDot), false)
		t.truthy(Pvp.inFront(0, 0, 1, 0, 0, 0, 10, cfg.Burst.MinDot)) -- em cima
	end)

	t.test(
		"PvP equilibrado: mesmo nível = mesma vida e mesmo dano; 1 nível de diferença não decide sozinho",
		function()
			for level = 1, tcfg.MaxLevel do
				local hp = Pvp.maxHp(cfg, level)
				local hit = cfg.Burst.HpShare * Pvp.maxHp(cfg, level)
				t.equal(math.ceil(hp / hit), math.ceil(1 / cfg.Burst.HpShare)) -- igual contra igual: mesmas rajadas
			end
			for level = 1, tcfg.MaxLevel - 1 do
				local small = math.ceil(Pvp.maxHp(cfg, level + 1) / (cfg.Burst.HpShare * Pvp.maxHp(cfg, level)))
				local big = math.ceil(Pvp.maxHp(cfg, level) / (cfg.Burst.HpShare * Pvp.maxHp(cfg, level + 1)))
				t.truthy(small - big <= 4) -- o menor precisa de no máximo 4 rajadas a mais
			end
		end
	)
end
