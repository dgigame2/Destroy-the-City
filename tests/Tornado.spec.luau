-- O jogador-tornado: níveis, XP, tamanho, dano, forma e rebirth.
local Tornado = require("../src/shared/Logic/Tornado")
local cfg = require("../src/shared/Config/TornadoConfig")

return function(t)
	t.test("XP junta além da barra; o nível só sobe com EVOLVE (um por vez)", function()
		local need = Tornado.xpToNext(cfg, 1)
		local xp = Tornado.addXp(cfg, 1, 0, need * 3, 0)
		t.near(xp, need * 3) -- nada sobe sozinho
		t.truthy(Tornado.canEvolve(cfg, 1, xp, 0))
		local level, rest = Tornado.evolve(cfg, 1, xp, 0)
		t.equal(level, 2)
		t.near(rest :: number, need * 2)
		t.equal(Tornado.evolve(cfg, 1, need - 1, 0), nil) -- barra não cheia
	end)

	t.test("nível máximo = 15 + rebirths, até 30", function()
		t.equal(Tornado.maxLevel(cfg, 0), cfg.BaseMaxLevel)
		t.equal(Tornado.maxLevel(cfg, 1), cfg.BaseMaxLevel + 1)
		t.equal(Tornado.maxLevel(cfg, 999), cfg.MaxLevel)
		t.equal(Tornado.maxRebirths(cfg), cfg.MaxLevel - cfg.BaseMaxLevel)
		local full = Tornado.xpToNext(cfg, cfg.BaseMaxLevel) * 2
		t.equal(Tornado.canEvolve(cfg, cfg.BaseMaxLevel, full, 0), false) -- no máximo não evolui
		t.truthy(Tornado.canEvolve(cfg, cfg.BaseMaxLevel, full, 1)) -- com 1 rebirth vai ao 16
	end)

	t.test("rebirth: só no máximo, com a barra cheia e com rebirth sobrando", function()
		local m = cfg.BaseMaxLevel
		local need = Tornado.xpToNext(cfg, m)
		t.truthy(Tornado.canRebirth(cfg, m, need, 0))
		t.equal(Tornado.canRebirth(cfg, m, need - 1, 0), false) -- barra não cheia
		t.equal(Tornado.canRebirth(cfg, m - 1, 1e12, 0), false) -- abaixo do máximo
		local last = Tornado.maxRebirths(cfg)
		t.equal(Tornado.canRebirth(cfg, cfg.MaxLevel, 1e12, last), false) -- acabaram os rebirths
	end)

	t.test("fim de tudo (nível 30 sem rebirth sobrando): a barra para cheia", function()
		local last = Tornado.maxRebirths(cfg)
		local xp = Tornado.addXp(cfg, cfg.MaxLevel, 0, 1e15, last)
		t.near(xp, Tornado.xpToNext(cfg, cfg.MaxLevel))
		t.truthy(Tornado.addXp(cfg, cfg.BaseMaxLevel, 0, 1e15, 0) > Tornado.xpToNext(cfg, cfg.BaseMaxLevel))
	end)

	t.test("o rebirth acelera o XP (+50% cada)", function()
		t.near(Tornado.xpFor(cfg, 10, 1), (10 + cfg.PropXp) * 1.5)
		t.near(Tornado.xpFor(cfg, 0, 0), cfg.PropXp) -- prop dá só o mínimo
	end)

	t.test("tamanho, dano e velocidade só crescem com o nível", function()
		for level = 2, cfg.MaxLevel do
			t.truthy(Tornado.radius(cfg, level) > Tornado.radius(cfg, level - 1))
			t.truthy(Tornado.dps(cfg, level, 0) > Tornado.dps(cfg, level - 1, 0))
			t.truthy(Tornado.walkSpeed(cfg, level) > Tornado.walkSpeed(cfg, level - 1))
		end
	end)

	t.test("calibragem: nível 1 derruba prop em < 1 s; nível 15 derruba o maior prédio em 1 a 4 s", function()
		t.truthy(20 / Tornado.dps(cfg, 1, 0) < 1)
		local t15 = 2456 / Tornado.dps(cfg, cfg.BaseMaxLevel, 0)
		t.truthy(t15 > 1 and t15 < 4)
	end)

	t.test("formas: 1ª no nível 1, última no máximo, em ordem", function()
		t.equal(Tornado.form(cfg, 1), 1)
		t.equal(Tornado.form(cfg, cfg.MaxLevel), #cfg.Forms)
		for i = 2, #cfg.Forms do
			t.truthy(cfg.Forms[i].From > cfg.Forms[i - 1].From)
			t.equal(Tornado.form(cfg, cfg.Forms[i].From), i)
			t.equal(Tornado.form(cfg, cfg.Forms[i].From - 1), i - 1)
		end
	end)

	t.test("save limpo: lixo, NaN e fora do limite viram valores válidos", function()
		local l, x, r = Tornado.sanitize(cfg, nil, nil, nil)
		t.equal(l, 1)
		t.equal(x, 0)
		t.equal(r, 0)
		l, x, r = Tornado.sanitize(cfg, 0 / 0, math.huge, -3)
		t.equal(l, 1)
		t.equal(x, 0)
		t.equal(r, 0)
		l, x, r = Tornado.sanitize(cfg, 999.7, 1e12, 2.9)
		t.equal(l, cfg.BaseMaxLevel + 2) -- o nível respeita o máximo dos rebirths
		t.near(x, 1e12) -- XP guardado além da barra continua
		t.equal(r, 2)
		l, _, r = Tornado.sanitize(cfg, 99, 0, 999)
		t.equal(r, Tornado.maxRebirths(cfg))
		t.equal(l, cfg.MaxLevel)
		l, x, r = Tornado.sanitize(cfg, "5", 3, 1)
		t.equal(l, 5)
		t.near(x, 3)
		t.equal(r, 1)
	end)

	t.test("cor do rebirth: nenhuma sem rebirth, muda nos degraus e cobre todos os rebirths", function()
		t.equal(Tornado.aura(cfg, 0), nil)
		t.truthy(Tornado.aura(cfg, 1) ~= nil)
		t.truthy(Tornado.aura(cfg, 2) == Tornado.aura(cfg, 1))
		t.truthy(Tornado.aura(cfg, 3) ~= Tornado.aura(cfg, 2))
		t.truthy(Tornado.aura(cfg, Tornado.maxRebirths(cfg)) ~= nil)
	end)

	t.test("coroa: maior nível, desempate por rebirth, ninguém se empatar ou estiver sozinho", function()
		t.equal(Tornado.biggest({ { Id = 1, Level = 9, Rebirths = 0 } }), nil)
		t.equal(Tornado.biggest({ { Id = 1, Level = 1, Rebirths = 0 }, { Id = 2, Level = 1, Rebirths = 0 } }), nil)
		t.equal(Tornado.biggest({ { Id = 1, Level = 3, Rebirths = 0 }, { Id = 2, Level = 5, Rebirths = 0 } }), 2)
		t.equal(Tornado.biggest({ { Id = 1, Level = 5, Rebirths = 2 }, { Id = 2, Level = 5, Rebirths = 1 } }), 1)
		-- empate no topo depois de um maior aparecer antes
		t.equal(
			Tornado.biggest({
				{ Id = 1, Level = 2, Rebirths = 0 },
				{ Id = 2, Level = 6, Rebirths = 0 },
				{ Id = 3, Level = 6, Rebirths = 0 },
			}),
			nil
		)
	end)
end
