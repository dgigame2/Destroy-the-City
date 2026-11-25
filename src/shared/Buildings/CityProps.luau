--!strict
-- Objetos dos microambientes (quintais, parquinhos, carga e descarga, obras, posto). O visual vem do Blender
-- (assets/blender/build_city_props.py -> MeshModelsConfig); estes blocos são a reserva e definem tamanho,
-- tier e colisão. Mesmas regras do Templates: blocos alinhados que só se encostam, apoiados no chão,
-- frente para -Z.

type Voxel = any

local CityProps: { [string]: (Voxel) -> any } = {}

-- Portão: mesmo tamanho de um pedaço de cerca (entra na linha da cerca).
function CityProps.Gate(V)
	-- reserva da mesh: mesmos postes da cerca
	local box = V.box
	local boxes = {}
	for _, s in { -1, 1 } do
		V.add(
			boxes,
			box(1.4, 0.6, 1.4, s * 3.8, 0, 0, "FenceBase"),
			box(1, 2.2, 1, s * 3.8, 0.6, 0, "FenceWood"),
			box(1.4, 0.8, 1.4, s * 3.8, 2.8, 0, "FenceWood"),
			box(0.7, 2.8, 0.6, s * 0.4, 0.4, 0, "FenceWood"),
			box(2.55, 0.6, 0.4, s * 2.025, 0.6, 0, "FenceWood"),
			box(2.55, 0.6, 0.4, s * 2.025, 2.2, 0, "FenceWood"),
			box(0.5, 1, 0.3, s * 1.9, 1.2, 0, "FenceWood")
		)
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
	-- reserva da mesh: casinha branca de telhado vermelho, tigela e grama
	local box = V.box
	return {
		Name = "Doghouse",
		Tier = 1,
		Boxes = {
			box(4.4, 0.6, 3.6, 0, 0, 0, "ToyRed"),
			box(3.8, 2.1, 3.2, 0, 0.6, 0, "PlaneBody"),
			box(5, 0.7, 4.2, 0, 2.7, 0, "ToyRed"),
			box(3.4, 0.7, 4.2, 0, 3.4, 0, "ToyRed"),
			box(1.6, 0.8, 4.4, 0, 4.1, 0, "ToyRed"),
			box(1.5, 1.4, 0.1, 0, 0.6, -1.65, "FenceWood"),
			box(1.2, 0.6, 1.1, 1.1, 0, -2.45, "ToyRed"),
			box(0.6, 1, 0.6, 2.6, 0, -1, "Canopy"),
			box(0.6, 1, 0.6, -2.6, 0, 0, "Canopy"),
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
	local boxes = {
		box(1.9, 0.3, 1.5, 0, 1.6, 0, "Tire"),
		box(2.3, 0.5, 1.9, 0, 1.9, 0, "Tire"),
		box(1.8, 0.5, 1.4, 0, 2.4, 0, "Tire"),
		box(1.5, 0.3, 1.1, 0, 2.9, 0, "Tire"),
		box(0.5, 0.25, 0.5, 0, 3.2, 0, "Steel"),
	}
	-- pernas abertas em dois degraus
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			V.add(
				boxes,
				box(0.35, 0.8, 0.35, x * 0.75, 0.8, z * 0.55, "Steel"),
				box(0.35, 0.8, 0.35, x * 0.95, 0, z * 0.65, "Steel")
			)
		end
	end
	return { Name = "Grill", Tier = 1, Boxes = boxes }
end

-- Mesa de quintal com ombrelone e duas cadeiras.
function CityProps.PatioSet(V)
	local box = V.box
	local boxes = {
		box(0.5, 1.8, 0.5, 0, 0, 0, "ToyDark"),
		box(2.6, 0.5, 2.2, 0, 1.8, 0, "Trim"),
		box(0.5, 2, 0.5, 0, 2.3, 0, "ToyDark"),
		box(4, 0.6, 4, 0, 4.3, 0, "ToyYellow"),
		box(2.7, 0.35, 2.7, 0, 4.9, 0, "Trim"),
	}
	for _, s in { -1, 1 } do
		table.insert(boxes, box(1.1, 1, 1.1, s * 2.3, 0, 0, "Trunk"))
		table.insert(boxes, box(1.2, 0.4, 1.4, s * 2.3, 1, 0, "ToyYellow"))
		table.insert(boxes, box(0.3, 1.5, 1.4, s * 2.75, 1.4, 0, "ToyYellow"))
	end
	return { Name = "PatioSet", Tier = 1, Boxes = boxes }
end

-- Pilha de três caixas de papelão com fita (cabe em 1 célula).
function CityProps.Crate(V)
	local box = V.box
	return {
		Name = "Crate",
		Tier = 1,
		Boxes = {
			box(1.5, 1.6, 1.8, 0.73, 0, 0.2, "Cardboard"),
			box(0.35, 0.06, 0.3, 0.73, 1.6, -0.55, "Tape"),
			box(0.35, 0.4, 0.06, 0.73, 1.2, -0.73, "Tape"),
			box(1.35, 1.25, 1.7, -0.75, 0, -0.1, "Cardboard"),
			box(0.35, 0.06, 1.7, -0.9, 1.25, -0.1, "Tape"),
			box(0.35, 0.35, 0.06, -0.9, 0.9, -0.98, "Tape"),
			box(1.5, 1.2, 1.6, 0, 1.6, 0.4, "Cardboard"),
			box(0.35, 0.06, 1.6, 0, 2.8, 0.4, "Tape"),
			box(0.35, 0.4, 0.06, 0, 2.4, -0.43, "Tape"),
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

-- Caçamba com tampa inclinada (a tampa é cunha: alta atrás, baixa na frente).
function CityProps.Dumpster(V)
	local box = V.box
	local boxes = {
		box(4.8, 2, 2.8, 0, 0.4, 0, "ToyBlue"),
		box(5.2, 0.4, 3.2, 0, 2.4, 0, "Steel"),
		box(4.8, 0.2, 2.8, 0, 2.8, 0, "Steel"),
	}
	for _, sx in { -1, 1 } do
		table.insert(boxes, box(0.4, 0.6, 1.3, sx * 2.6, 1.3, -0.4, "ToyDark"))
		for _, sz in { -1, 1 } do
			table.insert(boxes, box(1, 0.4, 0.8, sx * 1.7, 0, sz * 0.9, "ToyDark"))
		end
		table.insert(boxes, V.shaped(box(0.45, 0.7, 2.8, sx * 2.175, 3, 0, "Steel"), "Wedge", 0))
		table.insert(boxes, V.shaped(box(1.2, 0.7, 2.8, sx * 0.85, 3, 0, "Steel"), "Wedge", 0))
		for _, x in { 0.6, 1.75 } do
			table.insert(boxes, box(0.4, 1.4, 0.1, sx * x, 0.7, -1.45, "ToyBlueDark"))
		end
	end
	for _, x in { -1.7, 0, 1.7 } do
		V.add(boxes, box(0.5, 0.2, 2.8, x, 3, 0, "Steel"), V.shaped(box(0.5, 0.7, 2.8, x, 3.2, 0, "Steel"), "Wedge", 0))
	end
	return { Name = "Dumpster", Tier = 1, Boxes = boxes }
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

-- Placas de trânsito (reserva das meshes de assets/blender/build_signs.py): poste com a placa na frente.
local function trafficSign(name: string, role: string, mark: string): (Voxel) -> any
	return function(V)
		local box = V.box
		return {
			Name = name,
			Tier = 1,
			Boxes = {
				box(1.2, 0.4, 1.2, 0, 0, 0.1, "Metal"),
				box(0.4, 3.25, 0.4, 0, 0.4, 0.3, "Metal"),
				box(2.2, 2.2, 0.3, 0, 2.55, -0.05, role),
				box(1.4, 0.4, 0.1, 0, 3.45, -0.25, mark),
			},
		}
	end
end

CityProps.StopSign = trafficSign("StopSign", "ToyRed", "Trim")
CityProps.SpeedSign = trafficSign("SpeedSign", "Trim", "ToyRed")
CityProps.WarningSign = trafficSign("WarningSign", "ToyYellow", "Tire")

function CityProps.FuelPump(V)
	local boxes = {}
	V.fuelPump(boxes, 0, 0, 0)
	return { Name = "FuelPump", Tier = 1, Boxes = boxes }
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
	local box, shaped = V.box, V.shaped
	local oz = -2.9 -- centraliza o comprimento no footprint
	local boxes = {
		box(3, 0.5, 2.8, 0, 5.6, oz, "ToyWood"),
		box(1.8, 0.4, 2.6, 0, 3.6, oz, "ToyWood"),
	}
	for _, x in { -1.15, 1.15 } do
		for _, z in { -1.05, 1.05 } do
			table.insert(boxes, box(0.5, 5.6, 0.5, x, 0, z + oz, "ToyMetal"))
		end
	end
	for _, y in { 0.8, 1.75, 2.7 } do
		table.insert(boxes, box(1.8, 0.35, 0.35, 0, y, -1.1 + oz, "ToyMetal"))
	end
	-- degraus e, dos lados, corrimão com rampa contínua (uma cunha por degrau)
	for k = 1, 5 do
		local top = 4.2 - 0.7 * k
		local low = math.max(top - 1, 0)
		local z = -1.6 + 1.15 * (k - 0.5)
		table.insert(boxes, box(1.8, top - low, 1.15, 0, low, z, "ToyPurple"))
		for _, x in { -1.1, 1.1 } do
			V.add(
				boxes,
				box(0.4, top + 0.1 - low, 1.15, x, low, z, "ToyPurple"),
				shaped(box(0.4, 0.7, 1.15, x, top + 0.1, z, "ToyPurple"), "Wedge", 180)
			)
		end
	end
	for _, x in { -1.1, 1.1 } do
		table.insert(boxes, box(0.4, 0.9, 0.3, x, 0, 4.3, "ToyPurple"))
	end
	return { Name = "Slide", Tier = 1, Boxes = boxes }
end

function CityProps.Seesaw(V)
	local box = V.box
	local boxes = {
		box(1, 0.5, 1, 0, 0, 0, "ToyMetal"),
		box(1.4, 0.5, 1.2, 0, 0.5, 0, "ToyMetal"),
		box(7, 0.4, 1.4, 0, 1, 0, "ToyYellow"),
	}
	for _, s in { -1, 1 } do
		table.insert(boxes, box(0.3, 0.8, 0.8, s * 2.1, 1.4, 0, "ToyMetal"))
		table.insert(boxes, box(1.1, 0.3, 1.1, s * 2.9, 1.4, 0, "ToyWood"))
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
