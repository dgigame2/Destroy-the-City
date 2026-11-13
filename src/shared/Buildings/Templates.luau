--!strict
-- Modelos de construções e props, descritos como blocos (dados puros, sem APIs do Roblox).
-- Estilo: cidade low-poly fofa (referências 2, 8-11): telhados inclinados, árvores redondas e pinheiros
-- em camadas, cogumelos, fontes, carros arredondados.
-- Convenções: unidades em studs; a frente aponta para -Z; Pos é o centro relativo à base no chão (Y = 0).
-- Size é sempre a caixa alinhada aos eixos do mundo (é o que os testes usam).
-- Shape: "Block" (padrão), "Wedge" (cunha, parte alta em +Z antes da rotação), "Cylinder" (em pé),
-- "DiscZ" (disco virado para a frente), "DiscX" (roda, eixo em X), "Ball".
-- Rot: rotação em Y (0, 90, 180, 270) — usada nas cunhas.

export type Box = {
	Size: { number },
	Pos: { number },
	Role: string,
	Shape: string?,
	Rot: number?,
}

export type Template = {
	Name: string,
	Tier: number,
	Footprint: { number },
	Boxes: { Box },
}

local function box(sx: number, sy: number, sz: number, x: number, y: number, z: number, role: string): Box
	return { Size = { sx, sy, sz }, Pos = { x, y + sy / 2, z }, Role = role }
end

local function cyl(d: number, h: number, x: number, y: number, z: number, role: string): Box
	return { Size = { d, h, d }, Pos = { x, y + h / 2, z }, Role = role, Shape = "Cylinder" }
end

-- Disco virado para a frente (eixo em Z): relógios, placas redondas.
local function disc(d: number, thickness: number, x: number, y: number, z: number, role: string): Box
	return { Size = { d, d, thickness }, Pos = { x, y + d / 2, z }, Role = role, Shape = "DiscZ" }
end

-- Roda (eixo em X).
local function wheel(d: number, thickness: number, x: number, y: number, z: number): Box
	return { Size = { thickness, d, d }, Pos = { x, y + d / 2, z }, Role = "Tire", Shape = "DiscX" }
end

local function ball(d: number, x: number, y: number, z: number, role: string): Box
	return { Size = { d, d, d }, Pos = { x, y + d / 2, z }, Role = role, Shape = "Ball" }
end

-- Cunha: (sx, sy, sz) já no espaço do mundo; rot gira a parte alta (0 = alta em +Z, 180 = alta em -Z,
-- 90 = alta em -X, 270 = alta em +X).
local function wedge(
	sx: number,
	sy: number,
	sz: number,
	x: number,
	y: number,
	z: number,
	role: string,
	rot: number
): Box
	return { Size = { sx, sy, sz }, Pos = { x, y + sy / 2, z }, Role = role, Shape = "Wedge", Rot = rot }
end

-- Telhado de duas águas ao longo de X (cumeeira no meio, caindo para frente e para trás) + beiral.
local function gableRoof(boxes: { Box }, w: number, d: number, baseY: number, height: number, role: string)
	table.insert(boxes, box(w + 1, 0.6, d + 1.4, 0, baseY, 0, "Trim"))
	local half = (d + 1.4) / 2
	table.insert(boxes, wedge(w + 1, height, half, 0, baseY + 0.6, -half / 2, role, 0))
	table.insert(boxes, wedge(w + 1, height, half, 0, baseY + 0.6, half / 2, role, 180))
end

-- Janela com moldura (vidro + peitoril) na fachada da frente.
local function frontWindows(boxes: { Box }, d: number, xs: { number }, y: number, ww: number, wh: number)
	for _, x in xs do
		table.insert(boxes, box(ww, wh, 0.4, x, y, -d / 2 - 0.2, "Window"))
		table.insert(boxes, box(ww + 0.6, 0.3, 0.8, x, y - 0.3, -d / 2 - 0.4, "Trim"))
	end
end

local function sideWindows(boxes: { Box }, w: number, zs: { number }, y: number, ww: number, wh: number)
	for _, z in zs do
		table.insert(boxes, box(0.4, wh, ww, w / 2 + 0.2, y, z, "Window"))
	end
end

local function wheels(boxes: { Box }, xs: { number }, zs: { number }, size: number)
	for _, x in xs do
		for _, z in zs do
			table.insert(boxes, wheel(size, 0.8, x, 0, z))
		end
	end
end

local builders: { [string]: () -> any } = {}

-- Tier 1: props ------------------------------------------------------------

function builders.Lamp()
	return {
		Name = "Lamp",
		Tier = 1,
		Boxes = {
			cyl(1.4, 0.6, 0, 0, 0, "Metal"),
			cyl(0.6, 9, 0, 0.6, 0, "Metal"),
			box(1.6, 0.4, 1.6, 0, 9.6, 0, "Metal"),
			ball(1.6, 0, 10, 0, "Light"),
		},
	}
end

function builders.Bench()
	return {
		Name = "Bench",
		Tier = 1,
		Boxes = {
			box(0.6, 1.2, 1.6, -2, 0, 0, "Metal"),
			box(0.6, 1.2, 1.6, 2, 0, 0, "Metal"),
			box(5, 0.5, 1.8, 0, 1.2, 0, "Trunk"),
			box(5, 1.4, 0.4, 0, 1.7, 0.7, "Trunk"),
		},
	}
end

function builders.Bin()
	return {
		Name = "Bin",
		Tier = 1,
		Boxes = {
			cyl(1.6, 2.4, 0, 0, 0, "Accent"),
			cyl(1.9, 0.4, 0, 2.4, 0, "Trim"),
		},
	}
end

function builders.Bush()
	return {
		Name = "Bush",
		Tier = 1,
		Boxes = {
			ball(3, -0.8, 0, 0, "Leaves"),
			ball(2.6, 0.9, 0, 0.3, "Leaves"),
			ball(2.2, 0, 1.4, -0.2, "Leaves"),
		},
	}
end

function builders.Hydrant()
	return {
		Name = "Hydrant",
		Tier = 1,
		Boxes = {
			cyl(1, 2, 0, 0, 0, "Accent"),
			box(1.8, 0.4, 0.5, 0, 1.2, 0, "Accent"),
			ball(1, 0, 1.7, 0, "Accent"),
		},
	}
end

function builders.Cone()
	return {
		Name = "Cone",
		Tier = 1,
		Boxes = {
			box(1.6, 0.3, 1.6, 0, 0, 0, "Cone"),
			cyl(1.2, 0.8, 0, 0.3, 0, "Cone"),
			cyl(0.9, 0.5, 0, 1.1, 0, "Trim"),
			cyl(0.6, 0.6, 0, 1.6, 0, "Cone"),
		},
	}
end

function builders.FlowerPot()
	return {
		Name = "FlowerPot",
		Tier = 1,
		Boxes = {
			cyl(1.8, 1.4, 0, 0, 0, "Pot"),
			ball(1.6, 0, 1.2, 0, "Leaves"),
			ball(0.7, -0.4, 2.3, 0, "Flower"),
			ball(0.7, 0.4, 2.1, 0.3, "Flower2"),
		},
	}
end

function builders.Mushroom()
	return {
		Name = "Mushroom",
		Tier = 1,
		Boxes = {
			cyl(1, 1.6, 0, 0, 0, "Stem"),
			cyl(3, 0.8, 0, 1.6, 0, "Cap"),
			cyl(2, 0.6, 0, 2.4, 0, "Cap"),
			ball(0.5, 0.8, 2.6, -0.5, "Trim"),
			ball(0.5, -0.6, 2.8, 0.4, "Trim"),
		},
	}
end

function builders.Mailbox()
	return {
		Name = "Mailbox",
		Tier = 1,
		Boxes = {
			box(0.4, 2, 0.4, 0, 0, 0, "Trunk"),
			box(1.2, 1, 1.8, 0, 2, 0, "Accent"),
			cyl(1.2, 0.3, 0, 3, 0, "Accent"),
		},
	}
end

-- Tier 2: árvores, pedras e carros -----------------------------------------------

function builders.Tree()
	return {
		Name = "Tree",
		Tier = 2,
		Boxes = {
			cyl(1.4, 5, 0, 0, 0, "Trunk"),
			ball(6, 0, 4.5, 0, "Leaves"),
			ball(4.2, -1.6, 7.5, 0.6, "Leaves"),
			ball(3.6, 1.4, 8, -0.4, "Leaves"),
		},
	}
end

function builders.Pine()
	return {
		Name = "Pine",
		Tier = 2,
		Boxes = {
			cyl(1.2, 3, 0, 0, 0, "Trunk"),
			cyl(6, 2.4, 0, 3, 0, "Pine"),
			cyl(4.6, 2.4, 0, 5.4, 0, "Pine"),
			cyl(3.2, 2.2, 0, 7.8, 0, "Pine"),
			cyl(1.8, 2, 0, 10, 0, "Pine"),
		},
	}
end

function builders.Rock()
	return {
		Name = "Rock",
		Tier = 2,
		Boxes = {
			ball(4, -0.6, 0, 0, "Rock"),
			ball(2.8, 1.4, 0, 0.6, "Rock"),
			ball(2.2, 0.2, 2.4, -0.2, "Rock"),
		},
	}
end

function builders.Car()
	local boxes = {
		box(5, 1.6, 10, 0, 0.8, 0, "Body"),
		box(4.6, 0.4, 9.4, 0, 2.4, 0, "Body"),
		box(4.2, 1.6, 5, 0, 2.8, 0.6, "Glass"),
		box(4.4, 0.4, 5.2, 0, 4.4, 0.6, "Body"),
		box(1.2, 0.6, 0.3, -1.6, 1.4, -5.1, "Light"),
		box(1.2, 0.6, 0.3, 1.6, 1.4, -5.1, "Light"),
		box(4.6, 0.5, 0.4, 0, 0.8, -5.1, "Metal"),
	}
	wheels(boxes, { -2.3, 2.3 }, { -3.2, 3.2 }, 1.8)
	return { Name = "Car", Tier = 2, Boxes = boxes }
end

function builders.FoodCart()
	return {
		Name = "FoodCart",
		Tier = 2,
		Boxes = {
			box(5, 3, 3, 0, 0.8, 0, "Awning"),
			box(5.4, 0.4, 3.4, 0, 3.8, 0, "Trim"),
			wheel(1.6, 0.8, -2, 0, 0),
			wheel(1.6, 0.8, 2, 0, 0),
			cyl(0.3, 3, 0, 4.2, 0, "Metal"),
			cyl(6, 0.6, 0, 7.2, 0, "Awning"),
			cyl(3.4, 0.6, 0, 7.8, 0, "Trim"),
		},
	}
end

-- Tier 3: casas e fonte -----------------------------------------------------------

function builders.House()
	local w, d, h = 12, 10, 8
	local boxes = {
		box(w + 1, 0.6, d + 1, 0, 0, 0, "Trim"),
		box(w, h, d, 0, 0.6, 0, "Wall"),
		box(2.4, 4.4, 0.4, 0, 0.6, -d / 2 - 0.2, "Door"),
		box(4, 0.5, 1.6, 0, 0, -d / 2 - 1.3, "Trim"),
		box(0.6, 0.6, 0.6, 1.8, 3.4, -d / 2 - 0.3, "Light"),
	}
	frontWindows(boxes, d, { -3.8, 3.8 }, 3.2, 2.6, 2.4)
	sideWindows(boxes, w, { -2, 2 }, 3.2, 2.4, 2.4)
	gableRoof(boxes, w, d, h + 0.6, 5, "Roof")
	table.insert(boxes, box(1.6, 4, 1.6, 3, h + 1.2, 2.5, "Chimney"))
	return { Name = "House", Tier = 3, Boxes = boxes }
end

function builders.Cottage()
	local w, d, h = 11, 9, 7
	local boxes = {
		box(w, 1.2, d, 0, 0, 0, "Stone"),
		box(w, h, d, 0, 1.2, 0, "WallWhite"),
		box(2.2, 4.2, 0.4, -2.5, 1.2, -d / 2 - 0.2, "Door"),
	}
	-- vigas aparentes (enxaimel)
	for _, x in { -w / 2 + 0.3, -1, 1.5, w / 2 - 0.3 } do
		table.insert(boxes, box(0.6, h, 0.4, x, 1.2, -d / 2 - 0.2, "Beam"))
	end
	table.insert(boxes, box(w, 0.5, 0.5, 0, 1.2 + h / 2, -d / 2 - 0.25, "Beam"))
	frontWindows(boxes, d, { 3.6 }, 3, 2.2, 2.2)
	gableRoof(boxes, w, d, h + 1.2, 4.5, "Roof")
	return { Name = "Cottage", Tier = 3, Boxes = boxes }
end

function builders.Fountain()
	return {
		Name = "Fountain",
		Tier = 3,
		Boxes = {
			cyl(14, 1.4, 0, 0, 0, "Stone"),
			cyl(12, 0.4, 0, 1.4, 0, "Water"),
			cyl(2.4, 4, 0, 1.4, 0, "Stone"),
			cyl(6, 0.8, 0, 5.4, 0, "Stone"),
			cyl(5, 0.3, 0, 6.2, 0, "Water"),
			cyl(1.2, 2, 0, 6.2, 0, "Stone"),
			ball(1.6, 0, 8.2, 0, "Water"),
		},
	}
end

-- Tier 4: sobrado, loja, ônibus, posto ----------------------------------------------

function builders.BigHouse()
	local w, d = 16, 12
	local boxes = {
		box(w + 1, 0.6, d + 1, 0, 0, 0, "Trim"),
		box(w, 7, d, 0, 0.6, 0, "Wall"),
		box(w + 0.6, 0.8, d + 0.6, 0, 7.6, 0, "Trim"),
		box(w, 6, d, 0, 8.4, 0, "Wall"),
		box(2.6, 4.6, 0.4, -4, 0.6, -d / 2 - 0.2, "Door"),
		box(6, 4.6, 0.4, 3.5, 0.6, -d / 2 - 0.2, "Garage"),
		box(5, 0.4, 2.4, -4, 5.4, -d / 2 - 1.2, "Awning"),
	}
	frontWindows(boxes, d, { -5, 0, 5 }, 10, 2.6, 2.6)
	sideWindows(boxes, w, { -3, 3 }, 3, 2.4, 2.4)
	sideWindows(boxes, w, { -3, 3 }, 10, 2.4, 2.6)
	gableRoof(boxes, w, d, 14.4, 6, "Roof")
	table.insert(boxes, box(1.8, 4.4, 1.8, -5, 15, 3, "Chimney"))
	return { Name = "BigHouse", Tier = 4, Boxes = boxes }
end

function builders.Shop()
	local w, d, h = 18, 12, 10
	local boxes = {
		box(w, h, d, 0, 0, 0, "Wall"),
		box(13, 5, 0.4, -1.5, 0.8, -d / 2 - 0.2, "Glass"),
		box(2.6, 5, 0.4, 7, 0, -d / 2 - 0.2, "Door"),
		box(10, 2, 0.6, 0, 7.4, -d / 2 - 0.3, "Sign"),
		box(w + 0.8, 1, d + 0.8, 0, h, 0, "Trim"),
		box(4, 1.6, 3, 4, h + 1, 2, "Metal"),
	}
	-- toldo listrado inclinado
	for i = 0, 5 do
		local role = if i % 2 == 0 then "Awning" else "Trim"
		table.insert(boxes, wedge(3, 1.6, 3.2, -7.5 + i * 3, 5.8, -d / 2 - 1.6, role, 0))
	end
	return { Name = "Shop", Tier = 4, Boxes = boxes }
end

function builders.Bus()
	local boxes = {
		box(6, 4.4, 20, 0, 1, 0, "Bus"),
		box(5.6, 1.8, 18, 0, 3, 0, "Glass"),
		box(6.2, 0.6, 20.2, 0, 5.4, 0, "Trim"),
		box(4.6, 1.2, 0.4, 0, 2.4, -10.2, "Glass"),
		box(1.2, 0.6, 0.3, -2, 1.4, -10.15, "Light"),
		box(1.2, 0.6, 0.3, 2, 1.4, -10.15, "Light"),
	}
	wheels(boxes, { -2.8, 2.8 }, { -6.5, 6.5 }, 2.2)
	return { Name = "Bus", Tier = 4, Boxes = boxes }
end

function builders.GasStation()
	local boxes = {
		box(22, 0.4, 16, 0, 0, 0, "Sidewalk"),
		box(10, 7, 7, 4, 0.4, 4, "Wall"),
		box(6, 3.6, 0.4, 4, 0.8, 0.3, "Glass"),
		box(10.6, 0.8, 7.6, 4, 7.4, 4, "Awning"),
		box(20, 1.2, 8, 0, 9.2, -3, "Awning"),
		box(20.4, 0.4, 8.4, 0, 10.4, -3, "Trim"),
	}
	for _, x in { -8, 8 } do
		table.insert(boxes, cyl(0.8, 8.8, x, 0.4, -3, "Metal"))
	end
	for _, x in { -4, 0 } do
		table.insert(boxes, box(1.4, 2.6, 1, x, 0.4, -3, "Accent"))
	end
	return { Name = "GasStation", Tier = 4, Boxes = boxes }
end

-- Tier 5: prédio, galpão, caixa d'água ------------------------------------------------

function builders.Apartment()
	local w, d, floors, floorH = 18, 16, 6, 6
	local h = floors * floorH
	local boxes = {
		box(w + 1, 1, d + 1, 0, 0, 0, "Trim"),
		box(w, h, d, 0, 1, 0, "Wall"),
		box(3, 4.6, 0.4, 0, 1, -d / 2 - 0.2, "Door"),
		box(6, 0.4, 2, 0, 5.8, -d / 2 - 1, "Awning"),
		box(w + 1, 1, d + 1, 0, h + 1, 0, "Trim"),
		cyl(4, 3, -4, h + 2, 3, "Metal"),
		box(3, 3, 3, 5, h + 2, -3, "Roof"),
	}
	for floor = 1, floors - 1 do
		local y = 1 + floor * floorH + 1.6
		frontWindows(boxes, d, { -5.5, 0, 5.5 }, y, 3, 2.8)
		sideWindows(boxes, w, { -4.5, 0, 4.5 }, y, 3, 2.8)
	end
	return { Name = "Apartment", Tier = 5, Boxes = boxes }
end

function builders.Warehouse()
	local w, d, h = 30, 22, 14
	local boxes = {
		box(w, h, d, 0, 0, 0, "Wall"),
		box(10, 9, 0.4, -6, 0, -d / 2 - 0.2, "Garage"),
		box(2.6, 4.6, 0.4, 8, 0, -d / 2 - 0.2, "Door"),
		box(16, 1.2, 0.4, 0, 11, -d / 2 - 0.2, "Sign"),
	}
	gableRoof(boxes, w, d, h, 6, "Roof")
	return { Name = "Warehouse", Tier = 5, Boxes = boxes }
end

function builders.WaterTower()
	local boxes = {
		cyl(16, 12, 0, 22, 0, "Tank"),
		cyl(17, 1, 0, 21.4, 0, "Trim"),
		cyl(12, 2.4, 0, 34, 0, "Roof"),
		cyl(6, 2, 0, 36.4, 0, "Roof"),
		box(10, 2.4, 0.4, 0, 27, -8.1, "Sign"),
	}
	for _, x in { -5, 5 } do
		for _, z in { -5, 5 } do
			table.insert(boxes, box(1.2, 22, 1.2, x, 0, z, "Metal"))
		end
	end
	table.insert(boxes, box(11, 0.8, 0.8, 0, 10, -5, "Metal"))
	table.insert(boxes, box(11, 0.8, 0.8, 0, 10, 5, "Metal"))
	return { Name = "WaterTower", Tier = 5, Boxes = boxes }
end

-- Tier 6: torre, museu, torre do relógio ------------------------------------------------

function builders.Tower()
	local boxes = {
		box(26, 2, 26, 0, 0, 0, "Trim"),
		box(24, 44, 24, 0, 2, 0, "Wall"),
		box(25, 1.2, 25, 0, 46, 0, "Trim"),
		box(19, 26, 19, 0, 47.2, 0, "Wall"),
		box(20, 1.2, 20, 0, 73.2, 0, "Trim"),
		cyl(12, 8, 0, 74.4, 0, "Roof"),
		cyl(1, 14, 0, 82.4, 0, "Metal"),
		ball(1.6, 0, 96.4, 0, "Light"),
		box(4, 6, 0.4, 0, 2, -12.2, "Door"),
	}
	for y = 8, 40, 8 do
		table.insert(boxes, box(22, 3, 0.4, 0, y, -12.2, "Window"))
		table.insert(boxes, box(0.4, 3, 22, 12.2, y, 0, "Window"))
	end
	for y = 52, 68, 8 do
		table.insert(boxes, box(17, 3, 0.4, 0, y, -9.7, "Window"))
		table.insert(boxes, box(0.4, 3, 17, 9.7, y, 0, "Window"))
	end
	return { Name = "Tower", Tier = 6, Boxes = boxes }
end

function builders.Museum()
	local boxes = {
		box(46, 3, 38, 0, 0, 2, "Stone"),
		box(30, 1, 3, 0, 0, -18.5, "Stone"),
		box(26, 1, 2, 0, 1, -18, "Stone"),
		box(22, 1, 1, 0, 2, -17.5, "Stone"),
		box(40, 20, 26, 0, 3, 5, "WallWhite"),
		box(42, 1.2, 34, 0, 23, 1, "Trim"),
		wedge(21, 5, 6, -10.5, 24.2, -13, "WallWhite", 270),
		wedge(21, 5, 6, 10.5, 24.2, -13, "WallWhite", 90),
		box(10, 3, 0.6, 0, 19, -8.3, "Sign"),
	}
	for _, x in { -15, -9, -3, 3, 9, 15 } do
		table.insert(boxes, cyl(2.4, 20, x, 3, -12, "Trim"))
	end
	-- cúpula redonda em camadas (referência 3)
	table.insert(boxes, cyl(20, 2, 0, 24.2, 5, "Dome"))
	table.insert(boxes, cyl(17, 2, 0, 26.2, 5, "Dome"))
	table.insert(boxes, cyl(13, 2, 0, 28.2, 5, "Dome"))
	table.insert(boxes, cyl(8, 2, 0, 30.2, 5, "Dome"))
	table.insert(boxes, ball(3, 0, 32.2, 5, "Light"))
	for _, z in { -2, 5, 12 } do
		table.insert(boxes, box(0.4, 10, 3, 20.2, 7, z, "Accent"))
	end
	return { Name = "Museum", Tier = 6, Boxes = boxes }
end

function builders.ClockTower()
	local boxes = {
		box(20, 3, 20, 0, 0, 0, "Stone"),
		box(16, 40, 16, 0, 3, 0, "Brick"),
		box(17, 1.2, 17, 0, 43, 0, "Trim"),
		box(12, 12, 12, 0, 44.2, 0, "WallWhite"),
		disc(8, 0.6, 0, 46.2, -6.3, "Clock"),
		disc(8, 0.6, 0, 46.2, 6.3, "Clock"),
		box(13, 1, 13, 0, 56.2, 0, "Trim"),
		wedge(13, 10, 6.5, 0, 57.2, -3.25, "Roof", 0),
		wedge(13, 10, 6.5, 0, 57.2, 3.25, "Roof", 180),
		box(4, 7, 0.4, 0, 3, -8.2, "Door"),
	}
	for y = 10, 34, 8 do
		table.insert(boxes, box(3, 4, 0.4, 0, y, -8.2, "Window"))
		table.insert(boxes, box(0.4, 4, 3, 8.2, y, 0, "Window"))
	end
	return { Name = "ClockTower", Tier = 6, Boxes = boxes }
end

-- Tier 7: marcos do mapa ---------------------------------------------------------

function builders.Skyscraper()
	local boxes = {
		box(42, 3, 42, 0, 0, 0, "Trim"),
		box(38, 60, 38, 0, 3, 0, "Wall"),
		box(40, 2, 40, 0, 63, 0, "Trim"),
		box(30, 50, 30, 0, 65, 0, "Wall"),
		box(32, 2, 32, 0, 115, 0, "Trim"),
		box(20, 30, 20, 0, 117, 0, "Wall"),
		box(22, 2, 22, 0, 147, 0, "Roof"),
		cyl(10, 8, 0, 149, 0, "Roof"),
		cyl(1.4, 26, 0, 157, 0, "Light"),
		box(8, 8, 0.4, 0, 3, -19.2, "Door"),
	}
	for y = 12, 56, 9 do
		table.insert(boxes, box(36, 4, 0.4, 0, y, -19.2, "Window"))
		table.insert(boxes, box(0.4, 4, 36, 19.2, y, 0, "Window"))
	end
	for y = 72, 108, 9 do
		table.insert(boxes, box(28, 4, 0.4, 0, y, -15.2, "Window"))
		table.insert(boxes, box(0.4, 4, 28, 15.2, y, 0, "Window"))
	end
	for y = 122, 140, 9 do
		table.insert(boxes, box(18, 4, 0.4, 0, y, -10.2, "Window"))
		table.insert(boxes, box(0.4, 4, 18, 10.2, y, 0, "Window"))
	end
	return { Name = "Skyscraper", Tier = 7, Boxes = boxes }
end

function builders.Stadium()
	local boxes = {
		box(70, 1, 54, 0, 0, 0, "Trim"),
		box(50, 0.4, 34, 0, 1, 0, "Leaves"),
	}
	for i = 0, 4 do
		local y = 1 + i * 3
		local inset = i * 2
		table.insert(boxes, box(70, 3, 4, 0, y, -25 + inset, "Wall"))
		table.insert(boxes, box(70, 3, 4, 0, y, 25 - inset, "Wall"))
		table.insert(boxes, box(4, 3, 46 - inset * 2, -33 + inset, y, 0, "Wall"))
		table.insert(boxes, box(4, 3, 46 - inset * 2, 33 - inset, y, 0, "Wall"))
	end
	for _, x in { -33, 33 } do
		for _, z in { -25, 25 } do
			table.insert(boxes, cyl(2, 30, x, 1, z, "Metal"))
			table.insert(boxes, box(6, 3, 2, x, 31, z, "Light"))
		end
	end
	return { Name = "Stadium", Tier = 7, Boxes = boxes }
end

-- Footprint calculado a partir dos blocos (simétrico em torno do centro, arredondado para cima).
local function computeFootprint(boxes: { Box }): { number }
	local halfX, halfZ = 0, 0
	for _, b in boxes do
		halfX = math.max(halfX, math.abs(b.Pos[1]) + b.Size[1] / 2)
		halfZ = math.max(halfZ, math.abs(b.Pos[3]) + b.Size[3] / 2)
	end
	return { math.ceil(halfX * 2), math.ceil(halfZ * 2) }
end

local Templates: { [string]: Template } = {}
for name, build in builders do
	local template = build()
	template.Footprint = computeFootprint(template.Boxes)
	assert(template.Name == name, `nome inconsistente: {name}`)
	Templates[name] = template
end

return Templates
