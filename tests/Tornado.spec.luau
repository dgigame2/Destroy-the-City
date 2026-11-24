-- O jogador-tornado: níveis, XP, tamanho, dano, forma e rebirth.
local Tornado = require("../src/shared/Logic/Tornado")
local cfg = require("../src/shared/Config/TornadoConfig")
local BASE, TOP = cfg.MaxLevels[1], cfg.MaxLevels[#cfg.MaxLevels]

return function(t)
	t.test("XP junta além da barra; o nível só sobe com EVOLVE (todos os pagos de uma vez)", function()
		local need = Tornado.xpToNext(cfg, 1)
		local xp = Tornado.addXp(cfg, 1, 0, need + Tornado.xpToNext(cfg, 2) + Tornado.xpToNext(cfg, 3) - 1, 0)
		t.truthy(Tornado.canEvolve(cfg, 1, xp, 0))
		local level, rest = Tornado.evolve(cfg, 1, xp, 0)
		t.equal(level, 3) -- pagou o 1 e o 2; faltou 1 de XP para o 4
		t.near(rest :: number, Tornado.xpToNext(cfg, 3) - 1)
		local top, left = Tornado.evolve(cfg, 1, 1e9, 0)
		t.equal(top, BASE) -- para no máximo e guarda o resto
		t.truthy((left :: number) > 0)
		t.equal(Tornado.evolveSeconds(cfg, 1, 2), cfg.Evolve.Seconds)
		t.equal(Tornado.evolveSeconds(cfg, 2, 4), cfg.Evolve.FormSeconds)
		t.equal(Tornado.evolve(cfg, 1, need - 1, 0), nil) -- barra não cheia
	end)

	t.test("nível máximo: 15, 17, 20, 24 e 29; toda barra tem XP e só cresce", function()
		t.equal(Tornado.maxLevel(cfg, 0), BASE)
		t.equal(Tornado.maxLevel(cfg, 1), 17)
		t.equal(Tornado.maxLevel(cfg, 999), TOP)
		t.equal(Tornado.maxRebirths(cfg), 4)
		t.equal(#cfg.Xp, TOP)
		for level = 2, TOP do
			t.truthy(Tornado.xpToNext(cfg, level) > Tornado.xpToNext(cfg, level - 1))
		end
		local full = Tornado.xpToNext(cfg, BASE) * 2
		t.equal(Tornado.canEvolve(cfg, BASE, full, 0), false) -- no máximo não evolui
		t.truthy(Tornado.canEvolve(cfg, BASE, full, 1)) -- com 1 rebirth vai ao 16
	end)

	t.test("rebirth: só no máximo, com a barra cheia e com rebirth sobrando", function()
		local m = BASE
		local need = Tornado.xpToNext(cfg, m)
		t.truthy(Tornado.canRebirth(cfg, m, need, 0))
		t.equal(Tornado.canRebirth(cfg, m, need - 1, 0), false) -- barra não cheia
		t.equal(Tornado.canRebirth(cfg, m - 1, 1e12, 0), false) -- abaixo do máximo
		local last = Tornado.maxRebirths(cfg)
		t.equal(Tornado.canRebirth(cfg, TOP, 1e12, last), false) -- acabaram os rebirths
	end)

	t.test("fim de tudo (nível 29 sem rebirth sobrando): a barra para cheia", function()
		local last = Tornado.maxRebirths(cfg)
		local xp = Tornado.addXp(cfg, TOP, 0, 1e15, last)
		t.near(xp, Tornado.xpToNext(cfg, TOP))
		t.truthy(Tornado.addXp(cfg, BASE, 0, 1e15, 0) > Tornado.xpToNext(cfg, BASE))
	end)

	t.test("o rebirth acelera o XP (dobra cada)", function()
		t.near(Tornado.xpFor(cfg, 10, 1), (10 + cfg.PropXp) * 2)
		t.near(Tornado.xpBonus(cfg, 4), 16)
		t.near(Tornado.xpFor(cfg, 0, 0), cfg.PropXp) -- prop dá só o mínimo
	end)

	t.test("tamanho, dano e velocidade só crescem com o nível", function()
		for level = 2, TOP do
			t.truthy(Tornado.radius(cfg, level) > Tornado.radius(cfg, level - 1))
			t.truthy(Tornado.dps(cfg, level, 0) > Tornado.dps(cfg, level - 1, 0))
			t.truthy(Tornado.walkSpeed(cfg, level) > Tornado.walkSpeed(cfg, level - 1))
		end
	end)

	t.test("câmera: enquadra a altura e largura do funil em qualquer ângulo", function()
		local distance = Tornado.cameraDistance(18, 24, 60, 16 / 9)
		t.near(distance, 60) -- raio da esfera = 30; seno de 30 graus = 0,5
		t.near(Tornado.cameraDistance(36, 48, 60, 16 / 9), distance * 2)
	end)

	t.test("câmera: tela estreita ou FOV menor precisam de mais distância", function()
		local landscape = Tornado.cameraDistance(18, 24, 70, 16 / 9)
		t.truthy(Tornado.cameraDistance(18, 24, 70, 9 / 16) > landscape)
		t.truthy(Tornado.cameraDistance(18, 24, 55, 16 / 9) > landscape)
	end)

	t.test("calibragem: nível 1 derruba prop em < 1 s; nível 15 derruba o maior prédio em 1 a 4 s", function()
		t.truthy(20 / Tornado.dps(cfg, 1, 0) < 1)
		local t15 = 2456 / Tornado.dps(cfg, BASE, 0)
		t.truthy(t15 > 1 and t15 < 4)
	end)

	t.test("formas: 1ª no nível 1, última no máximo, em ordem", function()
		t.equal(Tornado.form(cfg, 1), 1)
		t.equal(Tornado.form(cfg, TOP), #cfg.Forms)
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
		t.equal(l, Tornado.maxLevel(cfg, 2)) -- o nível respeita o máximo dos rebirths
		t.near(x, 1e12) -- XP guardado além da barra continua
		t.equal(r, 2)
		l, _, r = Tornado.sanitize(cfg, 99, 0, 999)
		t.equal(r, Tornado.maxRebirths(cfg))
		t.equal(l, TOP)
		l, x, r = Tornado.sanitize(cfg, "5", 3, 1)
		t.equal(l, 5)
		t.near(x, 3)
		t.equal(r, 1)
	end)

	t.test("forma: Breeze volta leve e estreito ao descer do Void Storm para o nível 1", function()
		local void = cfg.Forms[Tornado.form(cfg, TOP)]
		local breeze = cfg.Forms[Tornado.form(cfg, 1)]
		t.truthy(breeze.Height < void.Height and breeze.Bands < void.Bands)
		t.truthy(breeze.Crown == 0 and void.Crown > 0 and breeze.Density < void.Density)
		t.truthy(Tornado.visualRadius(breeze, 0.5) < Tornado.visualRadius(void, 0.5))
	end)

	t.test("forma: largura interpola entre a base e o topo em cada perfil", function()
		for _, form in cfg.Forms do
			t.near(Tornado.visualRadius(form, 0), form.Base)
			t.near(Tornado.visualRadius(form, 1), form.Top)
		end
	end)

	t.test("rebirth: dois rebirths selecionam o azul sem alterar a forma do nível 13", function()
		local palette = cfg.RebirthFx.Colors
		t.equal(Tornado.rebirthColor(palette, 0), nil)
		t.equal(Tornado.rebirthColor(palette, 1), palette[1].Color)
		t.equal(Tornado.rebirthColor(palette, 2), palette[2].Color)
		t.equal(Tornado.rebirthColor(palette, 3), palette[3].Color)
		t.equal(Tornado.rebirthColor(palette, Tornado.maxRebirths(cfg)), palette[#palette].Color)
		t.equal(Tornado.maxLevel(cfg, 3), 24)
		t.equal(cfg.Forms[Tornado.form(cfg, 13)].Name, "Supertornado")
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
