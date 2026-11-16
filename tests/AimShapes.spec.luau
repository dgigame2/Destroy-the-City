local AimShapes = require("../src/shared/Logic/AimShapes")
local AimConfig = require("../src/shared/Config/AimConfig")

return function(t)
	t.test("mira: traços ficam em cima do círculo, iguais e sem encostar", function()
		local r = 10
		local list = AimShapes.dashes(5, -3, r, AimConfig.Dashes, AimConfig.DashFill, 0.3)
		t.equal(#list, AimConfig.Dashes)
		for _, dash in list do
			t.near(math.sqrt((dash.X - 5) ^ 2 + (dash.Z + 3) ^ 2), r)
			t.near(dash.Length, list[1].Length)
		end
		-- traço menor que a corda do trecho inteiro: sobra vão entre eles
		local chord = 2 * r * math.sin(math.pi / AimConfig.Dashes)
		t.truthy(list[1].Length < chord)
	end)

	t.test("mira: setas seguem a direção, começam fora do círculo e não passam do fim", function()
		local list = AimShapes.arrows(0, 0, 1, 0, 4, 40, 6, 0.5, 20)
		t.truthy(#list > 0)
		local last = -math.huge
		for _, a in list do
			t.near(a.Z, 0)
			t.truthy(a.X >= 4 and a.X <= 40)
			t.truthy(a.X > last)
			t.truthy(a.Fade >= 0 and a.Fade <= 1)
			last = a.X
		end
	end)

	t.test("mira: setas andam com a fase e respeitam o máximo", function()
		local a = AimShapes.arrows(0, 0, 0, 1, 0, 100, 10, 0, 50)
		local b = AimShapes.arrows(0, 0, 0, 1, 0, 100, 10, 0.5, 50)
		t.near(b[1].Z - a[1].Z, 5)
		t.equal(#AimShapes.arrows(0, 0, 0, 1, 0, 1000, 1, 0, 7), 7)
		t.equal(#AimShapes.arrows(0, 0, 1, 0, 10, 5, 2, 0, 9), 0) -- caminho menor que o círculo
	end)
end
