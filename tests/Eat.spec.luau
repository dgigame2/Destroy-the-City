local EatReach = require("../src/shared/Logic/EatReach")
local Zones = require("../src/shared/Logic/Zones")
local RunConfig = require("../src/shared/Config/RunConfig")
local EatConfig = require("../src/shared/Config/EatConfig")

return function(t)
	local auto = RunConfig.AutoCollect

	t.test("alcance: peça encostando na borda do círculo (no chão) é comida", function()
		-- antes a busca era uma esfera com centro em r/2 de altura: no chão ela só chegava a ~0,87 r
		local r = 20
		local box = EatReach.axisBox(r + 1, 0.5, 0, 2, 1, 2) -- borda mais perto a exatamente r
		t.truthy(EatReach.inReach(0, 0, box, r))
		t.near(EatReach.horizontalDistance(0, 0, box), r)
	end)

	t.test("alcance: peça logo fora do círculo não é comida", function()
		local box = EatReach.axisBox(23, 0.5, 0, 2, 1, 2)
		t.falsy(EatReach.inReach(0, 0, box, 20))
	end)

	t.test("alcance: altura da peça não importa (topo de torre conta pela posição no chão)", function()
		local low = EatReach.axisBox(10, 1, 10, 4, 2, 4)
		local high = EatReach.axisBox(10, 300, 10, 4, 2, 4)
		t.near(EatReach.horizontalDistance(0, 0, low), EatReach.horizontalDistance(0, 0, high))
	end)

	t.test("alcance: jogador em cima/dentro da peça tem distância 0", function()
		t.near(EatReach.horizontalDistance(1, 1, EatReach.axisBox(0, 5, 0, 10, 10, 10)), 0)
	end)

	t.test("alcance: peça girada 45° usa o canto mais perto", function()
		local c, s = math.cos(math.rad(45)), math.sin(math.rad(45))
		-- quadrado 2x2 girado em Y, centro em (10, 0): o canto aponta para o jogador (distância 10 - √2)
		local box = EatReach.axisBox(10, 0, 0, 2, 2, 2)
		box.RX, box.RZ = c, -s
		box.BX, box.BZ = s, c
		t.truthy(math.abs(EatReach.horizontalDistance(0, 0, box) - (10 - math.sqrt(2))) < 1e-6)
	end)

	t.test("comer: teto por tick alto o bastante para não deixar nada para trás", function()
		t.truthy(EatConfig.MaxEatsPerTick / EatConfig.EatTickSeconds >= 200)
	end)

	t.test("coleta automática: começa em 98% e não antes", function()
		t.falsy(Zones.shouldAutoCollect(3, 100, auto)) -- 97%
		t.truthy(Zones.shouldAutoCollect(2, 100, auto)) -- 98%
		t.truthy(Zones.shouldAutoCollect(1, 100, auto))
		t.falsy(Zones.shouldAutoCollect(0, 100, auto)) -- já acabou
		t.falsy(Zones.shouldAutoCollect(0, 0, auto))
	end)

	t.test("coleta automática: zona pequena (menos de 50) só coleta a última peça", function()
		t.falsy(Zones.shouldAutoCollect(2, 40, auto)) -- 95%
		t.truthy(Zones.shouldAutoCollect(1, 60, auto)) -- 98,3%
	end)

	t.test("tela: 98% real aparece como 95%", function()
		t.equal(Zones.displayPercent(2, 100, auto), 95)
		t.equal(Zones.displayPercent(20, 1000, auto), 95)
	end)

	t.test("tela: porcentagem nunca desce e termina em 100", function()
		local total = 777
		local last = -1
		for left = total, 0, -1 do
			local shown = Zones.displayPercent(left, total, auto)
			t.truthy(shown >= last and shown >= 0 and shown <= 100)
			last = shown
		end
		t.equal(last, 100)
		t.equal(Zones.displayPercent(total, total, auto), 0)
	end)

	t.test(
		"destaque das últimas peças: 25 + avisos de 'BIGGER' cabem no limite de 31 Highlights do Roblox",
		function()
			t.equal(RunConfig.RevealRemaining, 25)
			t.truthy(RunConfig.RevealRemaining + EatConfig.MaxLockedHints <= 31)
		end
	)
end
