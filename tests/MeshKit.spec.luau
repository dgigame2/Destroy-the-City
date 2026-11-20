local MeshKit = require("../src/shared/Logic/MeshKit")
local MeshKitConfig = require("../src/shared/Config/MeshKitConfig")
local Templates = require("../src/shared/Buildings/Templates")

local C = MeshKitConfig

local function box(size, role, shape, tilt)
	return { Size = size, Role = role, Shape = shape, Tilt = tilt }
end

return function(t)
	t.test("kit: parede comum vira bloco chanfrado", function()
		t.equal(MeshKit.choose(box({ 10, 8, 10 }, "Wall"), C), C.Block)
	end)

	t.test("kit: folhagem grande vira copa low-poly; pequena fica bloco", function()
		t.equal(MeshKit.choose(box({ 4, 3, 4 }, "Leaves"), C), C.Leaf)
		t.equal(MeshKit.choose(box({ 4, 3, 4 }, "Pine"), C), C.Leaf)
		t.equal(MeshKit.choose(box({ 0.8, 0.8, 0.8 }, "Leaves2"), C), C.Block)
	end)

	t.test("kit: cilindro e bola usam as meshes deles; cunha e inclinado ficam peça normal", function()
		t.equal(MeshKit.choose(box({ 2, 6, 2 }, "Metal", "Cylinder"), C), C.Cylinder)
		t.equal(MeshKit.choose(box({ 3, 3, 3 }, "Dome", "Ball"), C), C.Ball)
		t.equal(MeshKit.choose(box({ 2, 1, 2 }, "Roof", "Wedge"), C), nil)
		t.equal(MeshKit.choose(box({ 2, 2, 2 }, "Wall", nil, { 10, 0, 0 }), C), nil)
	end)

	t.test("kit: luz e água continuam peça normal (neon e vidro)", function()
		t.equal(MeshKit.choose(box({ 2, 2, 2 }, "Light"), C), nil)
		t.equal(MeshKit.choose(box({ 6, 1, 6 }, "Water"), C), nil)
	end)

	t.test("kit: blocos finos ou compridos demais ficam peça normal (chanfro não estica)", function()
		t.equal(MeshKit.choose(box({ 4, 4, C.MinSide * 0.5 }, "Window"), C), nil)
		t.equal(MeshKit.choose(box({ C.MaxAspect * 2 + 1, 2, 2 }, "Trim"), C), nil)
		t.equal(MeshKit.choose(box({ C.MaxAspect * 1, 1, 1 }, "Trim"), C), C.Block)
	end)

	t.test("kit: desligado = tudo peça normal", function()
		local off = table.clone(C)
		off.Enabled = false
		t.equal(MeshKit.choose(box({ 10, 8, 10 }, "Wall"), off), nil)
	end)

	t.test("kit: todos os modelos do jogo têm a maioria dos blocos com mesh do Blender", function()
		local total, withMesh = 0, 0
		for _, template in Templates do
			for _, b in template.Boxes do
				total += 1
				if MeshKit.choose(b, C) then
					withMesh += 1
				end
			end
		end
		t.truthy(total > 0 and withMesh / total >= 0.6)
	end)
end
