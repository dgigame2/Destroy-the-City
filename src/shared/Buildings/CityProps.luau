--!strict
-- Objetos dos microambientes (quintais, parquinhos, carga e descarga, obras, posto). O visual vem do Blender
-- (assets/blender/build_city_props.py -> MeshModelsConfig); estes blocos são a reserva e definem tamanho,
-- tier e colisão. Mesmas regras do Templates: blocos alinhados que só se encostam, apoiados no chão,
-- frente para -Z.

type Voxel = any

local CityProps: { [string]: (Voxel) -> any } = {}

-- Portão: mesmo tamanho de um pedaço de cerca (entra na linha da cerca).
function CityProps.Gate(V)
	local box = V.box
	local boxes = {
		box(0.8, 3.4, 0.8, -4, 0, 0, "Beam"),
		box(0.8, 3.4, 0.8, 4, 0, 0, "Beam"),
	}
	for _, s in { -1, 1 } do
		table.insert(boxes, box(3.2, 0.6, 0.4, s * 2, 0.6, 0, "Plank"))
		table.insert(boxes, box(3.2, 0.6, 0.4, s * 2, 2.4, 0, "Plank"))
		for _, x in { 1.2, 2.8 } do
			table.insert(boxes, box(0.4, 1.2, 0.4, s * x, 1.2, 0, "Plank"))
		end
	end
	return { Name = "Gate", Tier = 1, Boxes = boxes }
end

-- Bicicleta encostada (comprida em X).
function CityProps.Bicycle(V)
	local box = V.box
	return {
		Name = "Bicycle",
		Tier = 1,
		Boxes = {
			box(1.8, 1.8, 0.3, -1.3, 0, 0, "Tire"),
			box(1.8, 1.8, 0.3, 1.3, 0, 0, "Tire"),
			box(0.8, 0.3, 0.2, 0, 1.2, 0, "Accent"),
			box(0.2, 0.6, 0.2, -0.3, 1.5, 0, "Accent"),
			box(0.6, 0.2, 0.3, -0.3, 2.1, 0, "Tire"),
			box(0.2, 0.8, 0.2, 0.3, 1.5, 0, "Metal"),
			box(0.2, 0.2, 1, 0.3, 2.3, 0, "Metal"),
		},
	}
end

function CityProps.Doghouse(V)
	local box = V.box
	return {
		Name = "Doghouse",
		Tier = 1,
		Boxes = {
			box(3.2, 2.4, 3.2, 0, 0, 0, "Wall"),
			box(3.8, 0.5, 3.8, 0, 2.4, 0, "Roof"),
			box(2.6, 0.5, 3.8, 0, 2.9, 0, "Roof"),
			box(1.4, 0.5, 3.8, 0, 3.4, 0, "Roof"),
			box(1.2, 1.6, 0.1, 0, 0, -1.65, "Tire"),
			box(0.8, 0.3, 0.8, 1.2, 0, -2.3, "Accent"),
		},
	}
end

function CityProps.Clothesline(V)
	local box = V.box
	return {
		Name = "Clothesline",
		Tier = 1,
		Boxes = {
			box(0.4, 4, 0.4, -3.2, 0, 0, "Beam"),
			box(0.4, 4, 0.4, 3.2, 0, 0, "Beam"),
			box(6, 0.1, 0.1, 0, 3.6, 0, "Trim"),
			box(1.2, 1.4, 0.1, -1.6, 2.2, 0, "Accent"),
			box(1, 1.2, 0.1, 0, 2.4, 0, "Stripe"),
			box(1.2, 1.6, 0.1, 1.6, 2, 0, "Awning"),
		},
	}
end

function CityProps.Grill(V)
	local box = V.box
	local boxes = {}
	for _, x in { -0.6, 0.6 } do
		for _, z in { -0.6, 0.6 } do
			table.insert(boxes, box(0.2, 1.6, 0.2, x, 0, z, "Metal"))
		end
	end
	table.insert(boxes, box(1.6, 0.6, 1.6, 0, 1.6, 0, "Tire"))
	table.insert(boxes, box(1.2, 0.5, 1.2, 0, 2.2, 0, "Tire"))
	table.insert(boxes, box(0.3, 0.2, 0.3, 0, 2.7, 0, "Metal"))
	return { Name = "Grill", Tier = 1, Boxes = boxes }
end

-- Mesa de quintal com ombrelone e duas cadeiras.
function CityProps.PatioSet(V)
	local box = V.box
	local boxes = {
		box(0.4, 2, 0.4, 0, 0, 0, "Metal"),
		box(2.6, 0.2, 2.6, 0, 2, 0, "Trim"),
		box(0.2, 2.4, 0.2, 0, 2.2, 0, "Metal"),
		box(4, 0.3, 4, 0, 4.6, 0, "Awning"),
		box(2.6, 0.3, 2.6, 0, 4.9, 0, "Stripe"),
	}
	for _, s in { -1, 1 } do
		table.insert(boxes, box(1, 1.2, 1, s * 2.3, 0, 0, "Beam"))
		table.insert(boxes, box(1.2, 0.2, 1.2, s * 2.3, 1.2, 0, "Plank"))
		table.insert(boxes, box(0.2, 1.4, 1.2, s * 2.8, 1.4, 0, "Plank"))
	end
	return { Name = "PatioSet", Tier = 1, Boxes = boxes }
end

function CityProps.Crate(V)
	local box = V.box
	return {
		Name = "Crate",
		Tier = 1,
		Boxes = {
			box(2.4, 2.4, 2.4, 0, 0, 0, "Plank"),
			box(2.4, 0.3, 0.1, 0, 1.05, -1.25, "Beam"),
			box(2.4, 0.3, 0.1, 0, 1.05, 1.25, "Beam"),
		},
	}
end

function CityProps.Barrel(V)
	local box = V.box
	return {
		Name = "Barrel",
		Tier = 1,
		Boxes = { box(2, 2.8, 2, 0, 0, 0, "Accent"), box(1.6, 0.2, 1.6, 0, 2.8, 0, "Metal") },
	}
end

-- Palete com tijolos (obra e depósito).
function CityProps.Pallet(V)
	local box = V.box
	return {
		Name = "Pallet",
		Tier = 1,
		Boxes = { box(4, 0.6, 3, 0, 0, 0, "Plank"), box(3.4, 1.2, 2.4, 0, 0.6, 0, "Brick") },
	}
end

function CityProps.Dumpster(V)
	local box = V.box
	return {
		Name = "Dumpster",
		Tier = 1,
		Boxes = { box(5, 3, 3, 0, 0, 0, "Body"), box(5.2, 0.3, 3.2, 0, 3, 0, "Metal") },
	}
end

-- Cavalete de obra listrado.
function CityProps.Barrier(V)
	local box = V.box
	local boxes = {
		box(0.4, 2, 1.4, -1.6, 0, 0, "Metal"),
		box(0.4, 2, 1.4, 1.6, 0, 0, "Metal"),
		box(4, 0.6, 0.3, 0, 2, 0, "Accent"),
	}
	for _, x in { -1.2, 0, 1.2 } do
		table.insert(boxes, box(0.6, 0.6, 0.1, x, 2, -0.2, "Stripe"))
	end
	return { Name = "Barrier", Tier = 1, Boxes = boxes }
end

function CityProps.WarningSign(V)
	local box = V.box
	return {
		Name = "WarningSign",
		Tier = 1,
		Boxes = {
			box(1.2, 0.3, 1.2, 0, 0, 0, "Metal"),
			box(0.3, 3, 0.3, 0, 0.3, 0, "Metal"),
			box(1.8, 1.8, 0.2, 0, 3.3, 0, "Sign"),
			box(0.3, 0.9, 0.1, 0, 3.7, -0.15, "Tire"),
		},
	}
end

function CityProps.FuelPump(V)
	local box = V.box
	return {
		Name = "FuelPump",
		Tier = 1,
		Boxes = {
			box(2.4, 0.4, 1.8, 0, 0, 0, "Stone"),
			box(1.6, 3.6, 1.2, 0, 0.4, 0, "Accent"),
			box(1, 0.8, 0.1, 0, 2.6, -0.65, "Window"),
			box(1.8, 0.4, 1.4, 0, 4, 0, "Trim"),
			box(0.3, 1.2, 0.3, 0.95, 1.6, 0, "Tire"),
		},
	}
end

function CityProps.ShoppingCart(V)
	local box = V.box
	return {
		Name = "ShoppingCart",
		Tier = 1,
		Boxes = {
			box(1.8, 1, 0.2, 0, 0, -1.2, "Metal"),
			box(1.8, 1, 0.2, 0, 0, 1.2, "Metal"),
			box(2.2, 1.4, 3, 0, 1, 0, "Metal"),
			box(2.2, 0.2, 0.2, 0, 2.4, 1.4, "Accent"),
		},
	}
end

function CityProps.PowerBox(V)
	local box = V.box
	return {
		Name = "PowerBox",
		Tier = 1,
		Boxes = {
			box(2, 0.3, 1.2, 0, 0, 0, "Stone"),
			box(1.8, 2.6, 1, 0, 0.3, 0, "Metal"),
			box(1.8, 0.3, 0.1, 0, 2.2, -0.55, "Accent"),
			box(0.6, 0.6, 0.1, 0, 1.3, -0.55, "Sign"),
		},
	}
end

-- Bicicletário com uma bicicleta presa.
function CityProps.BikeRack(V)
	local box = V.box
	local boxes = { box(4.2, 0.2, 0.2, 0, 1.6, 0, "Metal") }
	for _, x in { -2, 0, 2 } do
		table.insert(boxes, box(0.2, 1.6, 0.2, x, 0, 0, "Metal"))
	end
	table.insert(boxes, box(1.8, 1.8, 0.3, -1.3, 0, -0.9, "Tire"))
	table.insert(boxes, box(1.8, 1.8, 0.3, 1.3, 0, -0.9, "Tire"))
	table.insert(boxes, box(0.8, 0.3, 0.2, 0, 1.2, -0.9, "Accent"))
	return { Name = "BikeRack", Tier = 1, Boxes = boxes }
end

-- Escorregador: torre com escada atrás (-Z) e rampa descendo para +Z (em degraus nos blocos de reserva).
function CityProps.Slide(V)
	local box = V.box
	local oz = -2.7 -- centraliza o comprimento no footprint
	local boxes = {}
	for _, x in { -0.9, 0.9 } do
		for _, z in { -0.9, 0.9 } do
			table.insert(boxes, box(0.4, 4, 0.4, x, 0, z + oz, "Metal"))
		end
	end
	table.insert(boxes, box(2.2, 0.3, 2.2, 0, 4, oz, "Plank"))
	for _, x in { -0.6, 0.6 } do
		table.insert(boxes, box(0.2, 4, 0.2, x, 0, -1.6 + oz, "Metal"))
	end
	for _, y in { 1, 2, 3 } do
		table.insert(boxes, box(1, 0.2, 0.2, 0, y, -1.6 + oz, "Metal"))
	end
	for k = 1, 5 do
		table.insert(boxes, box(1.6, 4.3 - 0.8 * k, 1.2, 0, 0, 1.1 + 1.2 * (k - 1) + 0.6 + oz, "Accent"))
	end
	return { Name = "Slide", Tier = 1, Boxes = boxes }
end

function CityProps.Swing(V)
	local box = V.box
	local boxes = {
		box(0.4, 5.6, 2.4, -3.2, 0, 0, "Metal"),
		box(0.4, 5.6, 2.4, 3.2, 0, 0, "Metal"),
		box(6.8, 0.4, 0.6, 0, 5.6, 0, "Metal"),
	}
	for _, x in { -1.4, 1.4 } do
		table.insert(boxes, box(0.1, 3.4, 0.1, x - 0.5, 2.2, 0, "Metal"))
		table.insert(boxes, box(0.1, 3.4, 0.1, x + 0.5, 2.2, 0, "Metal"))
		table.insert(boxes, box(1.2, 0.2, 0.6, x, 2, 0, "Accent"))
	end
	return { Name = "Swing", Tier = 1, Boxes = boxes }
end

function CityProps.Seesaw(V)
	local box = V.box
	local boxes = {
		box(0.8, 1, 0.8, 0, 0, 0, "Metal"),
		box(7, 0.3, 0.8, 0, 1, 0, "Accent"),
	}
	for _, s in { -1, 1 } do
		table.insert(boxes, box(0.2, 0.8, 0.2, s * 2.4, 1.3, 0, "Metal"))
		table.insert(boxes, box(0.8, 0.2, 0.8, s * 3.1, 1.3, 0, "Plank"))
	end
	return { Name = "Seesaw", Tier = 1, Boxes = boxes }
end

-- Neve (Ice City) ---------------------------------------------------------------------------------

function CityProps.SnowPile(V)
	local box = V.box
	return {
		Name = "SnowPile",
		Tier = 1,
		Boxes = {
			box(3.4, 1.2, 2.6, 0, 0, 0, "Snow"),
			box(2.2, 0.8, 1.8, 0, 1.2, 0, "Snow"),
			box(1, 0.5, 1, 0, 2, 0, "Snow"),
		},
	}
end

function CityProps.IceBlock(V)
	local box = V.box
	return {
		Name = "IceBlock",
		Tier = 1,
		Boxes = { box(2.4, 2.4, 2.4, 0, 0, 0, "Ice"), box(1.6, 1.6, 1.6, 0, 2.4, 0, "Ice") },
	}
end

-- Escultura de gelo (cisne): base de neve, corpo, cabeça e asas de gelo.
function CityProps.IceSculpture(V)
	local box = V.box
	return {
		Name = "IceSculpture",
		Tier = 2,
		Boxes = {
			box(3, 0.8, 3, 0, 0, 0, "Snow"),
			box(2, 3, 1.2, 0, 0.8, 0, "Ice"),
			box(1.4, 1.4, 1.4, 0, 3.8, 0, "Ice"),
			box(1, 1.6, 0.4, -1.5, 2, 0, "Ice"),
			box(1, 1.6, 0.4, 1.5, 2, 0, "Ice"),
		},
	}
end

-- Pista de patinação: gelo liso cercado por mureta.
function CityProps.SkateRink(V)
	local box = V.box
	return {
		Name = "SkateRink",
		Tier = 2,
		Boxes = {
			box(12, 0.3, 8, 0, 0, 0, "Ice"),
			box(12.8, 1, 0.4, 0, 0, -4.2, "Trim"),
			box(12.8, 1, 0.4, 0, 0, 4.2, "Trim"),
			box(0.4, 1, 8, -6.2, 0, 0, "Trim"),
			box(0.4, 1, 8, 6.2, 0, 0, "Trim"),
		},
	}
end

-- Cerca com neve em cima (quintais da Ice City).
function CityProps.SnowFence(V)
	local box, add = V.box, V.add
	local boxes = {}
	for _, x in { -4, 0, 4 } do
		add(boxes, box(0.8, 3.2, 0.8, x, 0, 0, "Beam"), box(1, 0.3, 1, x, 3.2, 0, "Snow"))
	end
	for _, x in { -2, 2 } do
		add(
			boxes,
			box(3.2, 0.6, 0.4, x, 1, 0, "Plank"),
			box(3.2, 0.6, 0.4, x, 2.2, 0, "Plank"),
			box(3.2, 0.2, 0.4, x, 2.8, 0, "Snow")
		)
	end
	return { Name = "SnowFence", Tier = 1, Boxes = boxes }
end

-- Praia (Beach City) ------------------------------------------------------------------------------

function CityProps.BeachChair(V)
	local box = V.box
	return {
		Name = "BeachChair",
		Tier = 1,
		Boxes = {
			box(1.6, 0.6, 0.2, 0, 0, -0.9, "Metal"),
			box(1.6, 0.6, 0.2, 0, 0, 0.9, "Metal"),
			box(1.6, 0.3, 2, 0, 0.6, 0, "Towel"),
			box(1.6, 1.4, 0.3, 0, 0.9, 0.85, "Towel"),
		},
	}
end

function CityProps.Lounger(V)
	local box = V.box
	return {
		Name = "Lounger",
		Tier = 1,
		Boxes = {
			box(2, 0.6, 5, 0, 0, 0, "Beam"),
			box(1.8, 0.2, 3.6, 0, 0.6, 0.6, "Towel"),
			box(1.8, 0.6, 1.2, 0, 0.6, -1.8, "Towel"),
			box(1.8, 0.6, 0.6, 0, 1.2, -2.1, "Towel"),
		},
	}
end

-- Pranchas de surf encostadas num cavalete.
function CityProps.SurfRack(V)
	local box = V.box
	return {
		Name = "SurfRack",
		Tier = 1,
		Boxes = {
			box(0.3, 3, 0.3, -2, 0, 0, "Beam"),
			box(0.3, 3, 0.3, 2, 0, 0, "Beam"),
			box(4.3, 0.3, 0.3, 0, 3, 0, "Beam"),
			box(0.9, 3.4, 0.2, -1.2, 0, -0.35, "Accent"),
			box(0.9, 3.6, 0.2, 0, 0, -0.35, "Sign"),
			box(0.9, 3.2, 0.2, 1.2, 0, -0.35, "Body"),
		},
	}
end

function CityProps.VolleyNet(V)
	local box = V.box
	return {
		Name = "VolleyNet",
		Tier = 1,
		Boxes = {
			box(0.3, 4, 0.3, -4, 0, 0, "Metal"),
			box(0.3, 4, 0.3, 4, 0, 0, "Metal"),
			box(7.7, 1.2, 0.1, 0, 2.6, 0, "Trim"),
			box(7.7, 0.2, 0.1, 0, 3.8, 0, "Stripe"),
			box(0.8, 0.8, 0.8, 2, 0, -2, "Stripe"),
		},
	}
end

-- Quiosque de praia: balcão, colunas e telhado em duas camadas.
function CityProps.Kiosk(V)
	local box = V.box
	local boxes = {
		box(5, 2.2, 3, 0, 0, 0, "Plank"),
		box(3, 0.8, 0.1, 0, 1, -1.55, "Sign"),
		box(6, 0.5, 4, 0, 4.6, 0, "Awning"),
		box(4.4, 0.5, 3, 0, 5.1, 0, "Awning"),
	}
	for _, x in { -2.3, 2.3 } do
		for _, z in { -1.3, 1.3 } do
			table.insert(boxes, box(0.3, 2.4, 0.3, x, 2.2, z, "Beam"))
		end
	end
	return { Name = "Kiosk", Tier = 2, Boxes = boxes }
end

function CityProps.Cooler(V)
	local box = V.box
	return {
		Name = "Cooler",
		Tier = 1,
		Boxes = { box(1.6, 1, 1, 0, 0, 0, "Body"), box(1.7, 0.3, 1.1, 0, 1, 0, "Trim") },
	}
end

-- Boia salva-vidas pendurada num poste.
function CityProps.Buoy(V)
	local box = V.box
	return {
		Name = "Buoy",
		Tier = 1,
		Boxes = { box(0.3, 3, 0.3, 0, 0, 0, "Beam"), box(1.4, 1.4, 0.3, 0, 1.6, -0.3, "Accent") },
	}
end

return CityProps
