local GuidePath = require("../src/shared/Logic/GuidePath")

return function(t)
	t.test("passagem: ponto mais perto da barreira mais perto", function()
		local boxes = {
			{ X = 100, Z = 0, HalfX = 0.3, HalfZ = 50 },
			{ X = 0, Z = 300, HalfX = 50, HalfZ = 0.3 },
		}
		local gate = GuidePath.nearestGate(0, 20, boxes) :: { number }
		t.near(gate[1], 99.7)
		t.near(gate[2], 20)
	end)

	t.test("setas: espaçadas igual, na direção do caminho", function()
		local arrows = GuidePath.arrows({ { 0, 0 }, { 100, 0 } }, 10, 0, 100)
		t.equal(#arrows, 11)
		t.near(arrows[2].X - arrows[1].X, 10)
		t.near(arrows[1].DirX, 1)
		t.near(arrows[1].DirZ, 0)
	end)

	t.test("setas andam para frente com a fase e viram na curva", function()
		local path = { { 0, 0 }, { 10, 0 }, { 10, 10 } }
		local a = GuidePath.arrows(path, 4, 3, 100)
		t.near(a[1].X, 3)
		local last = a[#a]
		t.near(last.DirZ, 1)
		t.truthy(#GuidePath.arrows(path, 1, 0, 5) == 5)
		t.near(GuidePath.length(path), 20)
	end)

	t.test("setas somem ao atravessar a barreira para dentro da área nova", function()
		-- barreira em x = 0 (de z -50 a 50); meio da área nova em x = 40
		local boxes = { { X = 0, Z = 0, HalfX = 0.3, HalfZ = 50 } }
		local finish = { 40, 0 }
		t.falsy(GuidePath.inside(-10, 5, finish, boxes)) -- ainda do lado de fora
		t.truthy(GuidePath.inside(3, 5, finish, boxes)) -- passou da barreira
		t.truthy(GuidePath.inside(40, 0, finish, boxes))
	end)
end
