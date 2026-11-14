local Rng = require("../src/shared/Logic/Rng")

return function(t)
	t.test("mesma semente gera a mesma sequência", function()
		local a, b = Rng.new(42), Rng.new(42)
		for _ = 1, 100 do
			t.equal(a:next(), b:next())
		end
	end)

	t.test("next fica em [0, 1)", function()
		local rng = Rng.new(3)
		for _ = 1, 10000 do
			local value = rng:next()
			t.truthy(value >= 0 and value < 1)
		end
	end)

	t.test("int fica dentro do intervalo e cobre os extremos", function()
		local rng = Rng.new(9)
		local seenMin, seenMax = false, false
		for _ = 1, 5000 do
			local value = rng:int(2, 6)
			t.truthy(value >= 2 and value <= 6 and value == math.floor(value))
			seenMin = seenMin or value == 2
			seenMax = seenMax or value == 6
		end
		t.truthy(seenMin and seenMax)
	end)

	t.test("weighted respeita pesos (peso 0 nunca sai)", function()
		local rng = Rng.new(5)
		local counts = { a = 0, b = 0, c = 0 }
		for _ = 1, 10000 do
			local key = rng:weighted({ a = 3, b = 1, c = 0 })
			counts[key] += 1
		end
		t.equal(counts.c, 0)
		t.truthy(counts.a > counts.b * 2)
	end)
end
