--!strict
local TornadoSway = require("../src/shared/Logic/TornadoSway")

return function(t: any)
	local cfg = { Wave = 0.16, WaveSpeed = 2.4, MoveWave = 0.6, Lean = 0.9, Stiffness = 60, Damping = 7 }

	t.test("balanço do tornado: o pé fica parado e a onda se compensa do pé ao topo", function()
		local s = TornadoSway.new()
		for _ = 1, 200 do
			TornadoSway.step(cfg, s, 1 / 60, 0, 0)
			local fx, fz = TornadoSway.offset(cfg, s, 0)
			t.near(fx, 0)
			t.near(fz, 0)
			local sx, sz = 0, 0
			for i = 1, 40 do
				local x, z = TornadoSway.offset(cfg, s, i / 40)
				sx += x / 40
				sz += z / 40
			end
			t.truthy(math.sqrt(sx * sx + sz * sz) < cfg.Wave * 0.25, "o meio do corpo saiu do eixo")
		end
	end)

	t.test(
		"balanço do tornado: andando o topo fica para trás; parado volta ao centro; travada não explode",
		function()
			local s = TornadoSway.new()
			for _ = 1, 180 do
				TornadoSway.step(cfg, s, 1 / 60, 5, 0)
			end
			t.truthy(math.abs(s.X + cfg.Lean) < 0.02)
			TornadoSway.step(cfg, s, 10, 5, 0)
			t.truthy(math.abs(s.X) < cfg.Lean * 2, "a mola explodiu")
			for _ = 1, 240 do
				TornadoSway.step(cfg, s, 1 / 60, 0, 0)
			end
			t.truthy(math.abs(s.X) < 0.02)
		end
	)
end
