-- Árvores de blocos do lobby: nenhum bloco dentro do outro e tudo apoiado (no chão ou em cima de outro bloco).
local BlockTrees = require("../src/shared/Logic/BlockTrees")

local TOL = 0.001

local function range(b, axis)
	return b.Pos[axis] - b.Size[axis] / 2, b.Pos[axis] + b.Size[axis] / 2
end

return function(t)
	for _, shape in BlockTrees.Shapes do
		t.test(`árvore {shape.Name}: nenhum bloco dentro do outro`, function()
			local boxes = shape.Boxes
			for i = 1, #boxes do
				for j = i + 1, #boxes do
					local inside = true
					for axis = 1, 3 do
						local a0, a1 = range(boxes[i], axis)
						local b0, b1 = range(boxes[j], axis)
						if not (a0 < b1 - TOL and b0 < a1 - TOL) then
							inside = false
						end
					end
					t.truthy(not inside, `{i} x {j}`)
				end
			end
		end)

		t.test(`árvore {shape.Name}: tudo apoiado`, function()
			for i, b in shape.Boxes do
				local bottom = range(b, 2)
				local ok = math.abs(bottom) < TOL
				for j, o in shape.Boxes do
					local _, top = range(o, 2)
					if j ~= i and math.abs(top - bottom) < TOL then
						ok = true
					end
					-- calombo do lado: encosta na lateral de uma camada na mesma altura
					local o0 = range(o, 2)
					if j ~= i and o.Role == "Leaves" and math.abs(o0 - bottom) < TOL then
						ok = true
					end
				end
				t.truthy(ok, i)
			end
		end)
	end
end
