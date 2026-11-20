-- Efeitos dos elementos: matemática pura (ElementFxMath) e limites do ElementFxConfig (goat: explosão < 1 s).
local ElementFxMath = require("../src/shared/Logic/ElementFxMath")
local ElementFxConfig = require("../src/shared/Config/ElementFxConfig")
local ElementConfig = require("../src/shared/Config/ElementConfig")

local function seeded(seed: number): () -> number
	local state = seed
	return function()
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
end

return function(t)
	t.test("efeitos: todo elemento tem config de efeito", function()
		for _, e in ElementConfig.List do
			t.truthy(ElementFxConfig[e.Id] ~= nil, e.Id)
		end
	end)

	t.test("efeitos: toda explosão dura menos de 1 s", function()
		local f = ElementFxConfig
		t.truthy(f.Fire.ImpactSeconds < 1)
		t.truthy(f.Lightning.Seconds < 1)
		t.truthy(f.Wind.Seconds < 1)
		t.truthy(f.Lightning.FlickerOff < f.Lightning.FlickerOn)
		t.truthy(f.Lightning.FlickerOn < f.Lightning.Seconds)
	end)

	t.test("qualidade: automática = meio; 1 = mínimo; 10 = tudo; sempre 0..1", function()
		t.equal(ElementFxMath.quality(0, 0.35, 0.6), 0.6)
		t.near(ElementFxMath.quality(1, 0.35, 0.6), 0.35)
		t.near(ElementFxMath.quality(10, 0.35, 0.6), 1)
		for level = 0, 12 do
			local q = ElementFxMath.quality(level, 0.35, 0.6)
			t.truthy(q > 0 and q <= 1)
		end
	end)

	t.test("partículas: menos para os outros, nunca 0, 0 se a base é 0", function()
		t.equal(ElementFxMath.count(18, 1, true, 0.6), 18)
		t.truthy(ElementFxMath.count(18, 1, false, 0.6) < 18)
		t.equal(ElementFxMath.count(1, 0.1, false, 0.1), 1)
		t.equal(ElementFxMath.count(0, 1, true, 1), 0)
	end)

	t.test("raio: começa no alto, termina no impacto, desce sempre e respeita o desvio", function()
		local rand = seeded(7)
		local points = ElementFxMath.bolt(95, 10, 6, rand)
		t.equal(#points, 11)
		t.equal(points[1].Y, 95)
		t.equal(points[#points].Y, 0)
		t.equal(points[1].X, 0)
		t.equal(points[#points].X, 0)
		t.equal(points[#points].Z, 0)
		for i = 2, #points do
			t.truthy(points[i].Y < points[i - 1].Y)
			t.truthy(math.abs(points[i].X) <= 6 and math.abs(points[i].Z) <= 6)
		end
	end)

	t.test("arco do raio (cadeia): começa e termina nos pontos certos", function()
		local a, b = { X = 0, Y = 4, Z = 0 }, { X = 30, Y = 0, Z = 10 }
		local points = ElementFxMath.between(a, b, 8, 3, seeded(5))
		t.equal(#points, 9)
		t.equal(points[1].X, 0)
		t.equal(points[1].Y, 4)
		t.near(points[9].X, 30)
		t.near(points[9].Z, 10)
	end)

	t.test("galho do raio: sai do ponto de origem e desce", function()
		local from = { X = 1, Y = 50, Z = -2 }
		local points = ElementFxMath.branch(from, 30, 4, 2, seeded(3))
		t.equal(#points, 5)
		t.equal(points[1].X, 1)
		t.equal(points[1].Y, 50)
		t.near(points[#points].Y, 20)
	end)

	t.test("bola de fogo: sai do alto e chega exatamente no impacto", function()
		local start = ElementFxMath.fallStart(3, 4, 30, 70)
		t.near(start.X, 18)
		t.near(start.Z, 24)
		t.equal(start.Y, 70)
		local mid = ElementFxMath.fall(start, 0.5)
		t.truthy(mid.Y < 70 and mid.Y > 0)
		local hit = ElementFxMath.fall(start, 1)
		t.near(hit.X, 0)
		t.near(hit.Y, 0)
		t.near(hit.Z, 0)
		-- quem lança no próprio pé: cai reto
		local straight = ElementFxMath.fallStart(0, 0, 30, 70)
		t.equal(straight.X, 0)
	end)

	t.test("redemoinho: abre e sobe com o tempo; fios espalhados em volta", function()
		local a0 = ElementFxMath.swirl(1, 3, 0, 1.25, 3, 11, 9, 1.7)
		local a1 = ElementFxMath.swirl(1, 3, 1, 1.25, 3, 11, 9, 1.7)
		t.near(math.sqrt(a0.X ^ 2 + a0.Z ^ 2), 3)
		t.near(math.sqrt(a1.X ^ 2 + a1.Z ^ 2), 11)
		t.truthy(a1.Y > a0.Y)
		local b0 = ElementFxMath.swirl(2, 3, 0, 1.25, 3, 11, 9, 1.7)
		t.truthy(math.abs(a0.X - b0.X) + math.abs(a0.Z - b0.Z) > 1)
	end)

	t.test("fade: 0 nas pontas, 1 no pico", function()
		t.equal(ElementFxMath.fade(0, 0.2), 0)
		t.equal(ElementFxMath.fade(1, 0.2), 0)
		t.near(ElementFxMath.fade(0.2, 0.2), 1)
		t.truthy(ElementFxMath.fade(0.6, 0.2) < 1)
	end)
end
