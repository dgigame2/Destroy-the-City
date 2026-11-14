local Physics = require("../src/shared/Logic/Physics")
local MovementConfig = require("../src/shared/Config/MovementConfig")
local GrowthConfig = require("../src/shared/Config/GrowthConfig")
local LobbyConfig = require("../src/shared/Config/LobbyConfig")

return function(t)
	local g = MovementConfig.Gravity
	-- Altura do pulo (VALOR CALCULADO) a partir do JumpPower: h = v² / (2g)
	local h = MovementConfig.JumpPower ^ 2 / (2 * g)
	local speed = MovementConfig.WalkSpeed

	t.test("velocidade de decolagem atinge a altura configurada", function()
		local v = Physics.takeoffVelocity(h, g)
		t.near(v * v / (2 * g), h)
	end)

	t.test("queda de 0 studs dura 0s", function()
		t.equal(Physics.fallTime(0, g), 0)
	end)

	t.test("pulo no mesmo nível dura 2 * v / g", function()
		local v = Physics.takeoffVelocity(h, g)
		t.near(Physics.airTime(h, g, 0) :: number, 2 * v / g)
	end)

	t.test("plataforma no topo exato do pulo é alcançável", function()
		t.near(Physics.airTime(h, g, h) :: number, Physics.takeoffVelocity(h, g) / g)
	end)

	t.test("plataforma acima da altura do pulo é inalcançável", function()
		t.equal(Physics.maxGap(speed, h, g, h + 0.01), nil)
	end)

	t.test("vão alcançável cresce quando o destino é mais baixo", function()
		local flat = Physics.maxGap(speed, h, g, 0) :: number
		local down = Physics.maxGap(speed, h, g, -10) :: number
		t.truthy(down > flat)
	end)

	t.test("valores negativos são rejeitados", function()
		t.throws(function()
			Physics.fallTime(-1, g)
		end)
	end)

	t.test("lobby fora do alcance de qualquer jogador na cidade (pulo + altura do corpo)", function()
		-- VALOR CALCULADO: maior escala possível, pulo com JumpPower escalado, corpo ~5 studs por escala
		local s = GrowthConfig.MaxScale
		local jumpPower = MovementConfig.JumpPower * s ^ MovementConfig.JumpScaleExponent
		local jumpHeight = jumpPower ^ 2 / (2 * g)
		local reach = jumpHeight + 5 * s
		t.truthy(reach < LobbyConfig.FloorHeight)
	end)
end
