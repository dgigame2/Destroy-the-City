-- Animação padrão de andar com personagens grandes: o pé acompanha o chão em qualquer tamanho.
local Stride = require("../src/shared/Logic/Stride")
local MovementConfig = require("../src/shared/Config/MovementConfig")
local GrowthConfig = require("../src/shared/Config/GrowthConfig")

return function(t)
	local base = MovementConfig.WalkSpeed

	t.test("tamanho normal na velocidade padrão: ritmo 1 (só correr, velocidade 1)", function()
		local blend = Stride.blend(Stride.normalized(base, 1, base))
		t.near(blend.RunWeight, 1)
		t.near(blend.RunSpeed, 1)
	end)

	t.test("gigante: o ritmo cai na mesma proporção do tamanho (passo maior, perna mais lenta)", function()
		for _, scale in { 2, 5, 10, GrowthConfig.MaxScale } do
			-- velocidade real do jogo nesse tamanho (VALOR CALCULADO pela fórmula do GrowthService)
			local speed = base * scale ^ MovementConfig.SpeedScaleExponent
			local rate = Stride.normalized(speed, scale, base)
			t.near(rate * scale * base, speed)
			t.truthy(rate < 1)
		end
	end)

	t.test("mistura andar/correr sem pesos zerados e contínua", function()
		local last = Stride.blend(0)
		for i = 1, 30 do
			local blend = Stride.blend(i * 0.05)
			t.truthy(blend.WalkWeight > 0 and blend.RunWeight > 0)
			t.truthy(math.abs(blend.WalkWeight - last.WalkWeight) <= 0.11)
			last = blend
		end
	end)

	t.test("parado ou escala inválida: ritmo 0", function()
		t.equal(Stride.normalized(0, 3, base), 0)
		t.equal(Stride.normalized(10, 0, base), 0)
	end)
end
