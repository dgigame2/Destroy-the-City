--!strict
-- Modelos novos das cidades (referências de mapa: bairros, centro de prédios, aeroporto, usina, porto, praia,
-- parque e neve). Mesmas regras do Templates: blocos alinhados aos eixos que só se encostam, tudo apoiado
-- no chão por uma cadeia de blocos, frente para -Z.
-- Cada função recebe o Voxel (peças básicas) e devolve {Name, Tier, Boxes}.

type Voxel = any

local CityBuildings: { [string]: (Voxel) -> any } = {}

-- Tier 1: objetos pequenos ------------------------------------------------------------------

function CityBuildings.Hedge(V)
	local box = V.box
	return {
		Name = "Hedge",
		Tier = 1,
		Boxes = { box(4, 1.6, 1.4, 0, 0, 0, "Leaves"), box(3.4, 0.6, 1, 0, 1.6, 0, "Leaves2") },
	}
end

function CityBuildings.Snowman(V)
	local box = V.box
	return {
		Name = "Snowman",
		Tier = 1,
		Boxes = {
			box(2.4, 2, 2.4, 0, 0, 0, "Snow"),
			box(1.8, 1.6, 1.8, 0, 2, 0, "Snow"),
			box(1.2, 1.2, 1.2, 0, 3.6, 0, "Snow"),
			box(0.3, 0.3, 0.6, 0, 4, -0.9, "Cone"),
			box(1.4, 0.3, 1.4, 0, 4.8, 0, "Tire"),
			box(0.9, 0.8, 0.9, 0, 5.1, 0, "Tire"),
		},
	}
end

function CityBuildings.Towel(V)
	local box = V.box
	return {
		Name = "Towel",
		Tier = 1,
		Boxes = { box(2.2, 0.1, 4, 0, 0, 0, "Towel"), box(1.4, 0.3, 0.8, 0, 0.1, 1.4, "Stripe") },
	}
end

function CityBuildings.PicnicTable(V)
	local box = V.box
	return {
		Name = "PicnicTable",
		Tier = 1,
		Boxes = {
			box(0.5, 1.6, 2.6, -1.8, 0, 0, "Beam"),
			box(0.5, 1.6, 2.6, 1.8, 0, 0, "Beam"),
			box(4.6, 0.4, 2.2, 0, 1.6, 0, "Plank"),
			box(4.6, 0.3, 0.8, 0, 0.8, -1.7, "Plank"),
			box(4.6, 0.3, 0.8, 0, 0.8, 1.7, "Plank"),
		},
	}
end

-- Iceberg: só decoração do mar congelado (fora da cidade).
function CityBuildings.Iceberg(V)
	local boxes = {}
	V.stack(boxes, 0, 0, 0, { { 14, 4, 12 }, { 10, 4, 9 }, { 6, 3, 5 }, { 3, 2, 3 } }, { "Ice", "Snow", "Ice", "Snow" })
	return { Name = "Iceberg", Tier = 1, Boxes = boxes }
end

-- Tier 2: objetos médios, barquinhos -----------------------------------------------------------

function CityBuildings.BusStop(V)
	local box = V.box
	return {
		Name = "BusStop",
		Tier = 2,
		Boxes = {
			box(0.6, 6, 0.6, -3, 0, 0.8, "Metal"),
			box(0.6, 6, 0.6, 3, 0, 0.8, "Metal"),
			box(7.6, 0.5, 2.6, 0, 6, 0.2, "Glass"),
			box(5.4, 4, 0.3, 0, 1, 1.2, "Glass"),
			box(5.4, 0.4, 1, 0, 1.4, 0.4, "Plank"),
			box(1.6, 1.2, 0.4, 0, 6.5, -0.9, "Sign"),
		},
	}
end

function CityBuildings.Lifeguard(V)
	local box = V.box
	local boxes = {}
	for _, x in { -1.5, 1.5 } do
		for _, z in { -1.5, 1.5 } do
			table.insert(boxes, box(0.5, 4, 0.5, x, 0, z, "Beam"))
		end
	end
	V.add(
		boxes,
		box(4.4, 0.5, 4.4, 0, 4, 0, "Plank"),
		box(3, 2.4, 3, 0, 4.5, 0, "Accent"),
		box(3.8, 0.5, 3.8, 0, 6.9, 0, "Stripe"),
		box(1.4, 1, 0.3, 0, 5.2, -1.65, "Window")
	)
	return { Name = "Lifeguard", Tier = 2, Boxes = boxes }
end

function CityBuildings.IceCreamStand(V)
	local box = V.box
	local boxes = {
		box(4, 2.4, 2.4, 0, 0, 0, "WallWhite"),
		box(4.4, 0.4, 2.8, 0, 2.4, 0, "Trim"),
		box(0.4, 3, 0.4, -1.8, 2.8, 0, "Metal"),
		box(0.4, 3, 0.4, 1.8, 2.8, 0, "Metal"),
		box(1, 1.4, 1, 0, 2.8, 0, "Cone"),
		box(3, 0.8, 0.3, 0, 0.8, -1.35, "Sign"),
	}
	V.stripes(boxes, -2.5, 5, 1, 5.8, 0, 3.2)
	return { Name = "IceCreamStand", Tier = 2, Boxes = boxes }
end

function CityBuildings.Igloo(V)
	local box = V.box
	local boxes = {}
	V.stack(boxes, 0, 0, 0, { { 6, 1.6 }, { 5, 1.4 }, { 3.6, 1.2 }, { 2, 0.8 } }, { "Snow", "Ice" })
	V.add(boxes, box(2, 2, 1.6, 0, 0, -3.8, "Snow"), box(1.2, 1.4, 0.2, 0, 0, -4.7, "Tire"))
	return { Name = "Igloo", Tier = 2, Boxes = boxes }
end

function CityBuildings.Boat(V)
	local box = V.box
	return {
		Name = "Boat",
		Tier = 2,
		Boxes = {
			box(3, 1, 7, 0, 0, 0, "Hull"),
			box(2, 1, 1, 0, 0, -4, "Hull"),
			box(2.4, 0.4, 6, 0, 1, 0, "Plank"),
			box(2, 1.4, 2, 0, 1.4, 0.8, "WallWhite"),
			box(1.6, 0.6, 0.3, 0, 2, -0.35, "Window"),
		},
	}
end

-- Tier 3: casas pequenas, parquinhos, caminhão -------------------------------------------------

function CityBuildings.Bungalow(V)
	local box = V.box
	local boxes = {
		box(12, 5, 10, 0, 0, 0, "Wall"),
		box(2.4, 3.6, 0.4, 0, 0, -5.2, "Door"),
	}
	V.frontWindows(boxes, 10, { -3.5, 3.5 }, 1.6, 2.4, 1.8)
	V.stepRoof(boxes, 12, 10, 5, 3, 1.2, "Roof")
	return { Name = "Bungalow", Tier = 3, Boxes = boxes }
end

function CityBuildings.BeachHouse(V)
	local box = V.box
	local boxes = {
		box(12, 5, 10, 0, 0, 0, "Wall"),
		box(13, 0.6, 11, 0, 5, 0, "Trim"),
		box(6, 3.4, 6, 2, 5.6, 1.5, "WallWhite"),
		box(7, 0.6, 7, 2, 9, 1.5, "Roof"),
		box(2.4, 3.6, 0.4, -3, 0, -5.2, "Door"),
		box(4, 2, 0.4, 2.5, 1.6, -5.2, "Window"),
	}
	V.stripes(boxes, -5, 4, 1.5, 3.8, -6, 2)
	return { Name = "BeachHouse", Tier = 3, Boxes = boxes }
end

function CityBuildings.SnowCabin(V)
	local box = V.box
	local boxes = {
		box(10, 4, 10, 0, 0, 0, "Plank"),
		box(2.2, 3.2, 0.4, 0, 0, -5.2, "Door"),
	}
	V.frontWindows(boxes, 10, { -3, 3 }, 1.4, 1.8, 1.6)
	V.stepRoof(boxes, 10, 10, 4, 4, 1.3, "Roof")
	return { Name = "SnowCabin", Tier = 3, Boxes = boxes }
end

function CityBuildings.Gazebo(V)
	local box = V.box
	local boxes = { box(8, 0.6, 8, 0, 0, 0, "Plank") }
	for _, x in { -3.4, 3.4 } do
		for _, z in { -3.4, 3.4 } do
			table.insert(boxes, box(0.6, 4, 0.6, x, 0.6, z, "Beam"))
		end
	end
	V.stack(boxes, 0, 0, 4.6, { { 9, 0.6 }, { 7, 0.8 }, { 5, 0.8 }, { 3, 0.8 } }, { "Trim", "Roof", "Roof", "RoofTop" })
	return { Name = "Gazebo", Tier = 3, Boxes = boxes }
end

function CityBuildings.Playground(V)
	local box = V.box
	local boxes = {
		box(10, 0.2, 7, 0, 0, 0, "Sandstone"),
		box(6.5, 0.5, 2.5, -1, 5.2, 0, "Metal"),
	}
	for _, x in { -4, 2 } do
		for _, z in { -1, 1 } do
			table.insert(boxes, box(0.5, 5, 0.5, x, 0.2, z, "Accent"))
		end
	end
	for _, x in { -2.4, 0.4 } do
		V.add(
			boxes,
			box(1.2, 0.3, 0.8, x, 1.6, 0, "Accent"),
			box(0.15, 3.3, 0.15, x - 0.4, 1.9, 0, "Metal"),
			box(0.15, 3.3, 0.15, x + 0.4, 1.9, 0, "Metal")
		)
	end
	-- caixa de areia e escorregador em degraus no canto
	V.add(
		boxes,
		box(2.4, 0.4, 2.4, 4, 0.2, -2, "Plank"),
		box(1.6, 1.4, 1.6, 4, 0.2, 2, "Accent"),
		box(1.6, 1, 1.6, 4, 1.6, 2, "Accent"),
		box(1.2, 0.4, 1.2, 4, 2.6, 2, "Trim")
	)
	return { Name = "Playground", Tier = 3, Boxes = boxes }
end

function CityBuildings.Truck(V)
	local box = V.box
	local boxes = {
		box(3.6, 0.8, 12, 0, 0.8, 0, "Metal"),
		box(3.6, 3.2, 3, 0, 1.6, -4.5, "Body"),
		box(3, 1.4, 0.3, 0, 3, -6.15, "Window"),
		box(3.8, 4, 8.4, 0, 1.6, 1.6, "Container"),
	}
	V.wheels(boxes, { -2.2, 2.2 }, { -4, 0, 4 }, 1.6)
	return { Name = "Truck", Tier = 3, Boxes = boxes }
end

function CityBuildings.SurfShop(V)
	local box = V.box
	return {
		Name = "SurfShop",
		Tier = 3,
		Boxes = {
			box(10, 5, 8, 0, 0, 0, "Wall"),
			box(11, 0.6, 9, 0, 5, 0, "Trim"),
			box(6, 1.6, 0.4, 0, 5.6, -4.2, "Sign"),
			box(2, 3.6, 0.4, 0, 0, -4.2, "Door"),
			box(0.8, 4, 0.3, -3, 0, -4.15, "Accent"),
			box(0.8, 4, 0.3, 3, 0, -4.15, "Towel"),
		},
	}
end

-- Píer de madeira sobre a água: postes, deque, bancos e postes de luz na ponta.
function CityBuildings.Pier(V)
	local box = V.box
	local boxes = {}
	for _, z in { -13, -4, 5, 13 } do
		for _, x in { -3.6, 3.6 } do
			table.insert(boxes, box(0.8, 1.4, 0.8, x, 0, z, "Beam"))
		end
	end
	table.insert(boxes, box(8, 0.6, 28, 0, 1.4, 0, "Plank"))
	for _, x in { -3.7, 3.7 } do
		table.insert(boxes, box(0.6, 1.2, 28, x, 2, 0, "Beam"))
	end
	V.add(
		boxes,
		box(3, 0.4, 1.2, 0, 2, 6, "Plank"),
		box(0.6, 5, 0.6, -2.5, 2, -12, "Metal"),
		box(1.2, 1, 1.2, -2.5, 7, -12, "Light"),
		box(0.6, 5, 0.6, 2.5, 2, -12, "Metal"),
		box(1.2, 1, 1.2, 2.5, 7, -12, "Light")
	)
	return { Name = "Pier", Tier = 3, Boxes = boxes }
end

-- Tier 4: lojas, sobrados, vilas, campo de futebol, contêineres, iate ------------------------------

function CityBuildings.Townhouse(V)
	local box = V.box
	local boxes = {}
	for i, role in { "Wall", "Brick", "WallWhite" } do
		local x = (i - 2) * 6
		V.add(
			boxes,
			box(6, 9, 10, x, 0, 0, role),
			box(6, 1, 11, x, 9, 0, "Roof"),
			box(1.8, 3.4, 0.4, x - 1.2, 0, -5.2, "Door"),
			box(1.6, 2, 0.4, x + 1.4, 1.2, -5.2, "Window"),
			box(3.6, 2, 0.4, x, 5, -5.2, "Window")
		)
	end
	table.insert(boxes, box(1.2, 2, 1.2, 8, 10, 2, "Chimney"))
	return { Name = "Townhouse", Tier = 4, Boxes = boxes }
end

function CityBuildings.Cafe(V)
	local box = V.box
	local boxes = {
		box(14, 6, 12, 0, 0, 0, "Wall"),
		box(15, 0.6, 13, 0, 6, 0, "Trim"),
		box(8, 1.4, 0.4, 0, 6.6, -6.2, "Sign"),
		box(2.4, 3.6, 0.4, -5, 0, -6.2, "Door"),
		box(9, 3.6, 0.4, 1.5, 0.4, -6.2, "Glass"),
	}
	V.stripes(boxes, -7, 7, 2, 4.4, -7.2, 2.4)
	for _, x in { -4, 4 } do
		V.add(boxes, box(0.3, 1.4, 0.3, x, 0, -10, "Metal"), box(1.6, 0.2, 1.6, x, 1.4, -10, "Plank"))
	end
	return { Name = "Cafe", Tier = 4, Boxes = boxes }
end

function CityBuildings.CornerStore(V)
	local box = V.box
	return {
		Name = "CornerStore",
		Tier = 4,
		Boxes = {
			box(12, 7, 12, 0, 0, 0, "Brick"),
			box(13, 0.6, 13, 0, 7, 0, "Trim"),
			box(3, 1.4, 2, 2, 7.6, 2, "Metal"),
			box(2.4, 3.6, 0.4, -3.5, 0, -6.2, "Door"),
			box(6, 3, 0.4, 2, 0.6, -6.2, "Glass"),
			box(10, 1.6, 0.4, 0, 4.4, -6.2, "Sign"),
			box(0.4, 3, 8, 6.2, 1, 0, "Glass"),
		},
	}
end

function CityBuildings.Villa(V)
	local box = V.box
	local boxes = {
		box(14, 5, 10, 0, 0, 3, "WallWhite"),
		box(15, 0.6, 11, 0, 5, 3, "Trim"),
		box(8, 4, 8, -3, 5.6, 4, "WallWhite"),
		box(9, 0.6, 9, -3, 9.6, 4, "Roof"),
		box(2.4, 3.6, 0.4, -4, 0, -2.2, "Door"),
		box(6, 2.6, 0.4, 3, 1, -2.2, "Glass"),
		box(4, 2, 0.4, -3, 6.6, -0.2, "Glass"),
		box(10, 0.4, 5, 0, 0, -5.5, "Stone"),
		box(8, 0.1, 3, 0, 0.4, -5.5, "Pool"),
	}
	return { Name = "Villa", Tier = 4, Boxes = boxes }
end

function CityBuildings.SoccerField(V)
	local box = V.box
	local boxes = {
		box(30, 0.2, 46, 0, 0, 0, "Grass"),
		box(0.6, 0.05, 44, -14.7, 0.2, 0, "Line"),
		box(0.6, 0.05, 44, 14.7, 0.2, 0, "Line"),
		box(28.8, 0.05, 0.6, 0, 0.2, -21.7, "Line"),
		box(28.8, 0.05, 0.6, 0, 0.2, 21.7, "Line"),
		box(28.8, 0.05, 0.6, 0, 0.2, 0, "Line"),
	}
	for _, z in { -22.4, 22.4 } do
		V.add(
			boxes,
			box(0.4, 2.4, 0.4, -3, 0.2, z, "Line"),
			box(0.4, 2.4, 0.4, 3, 0.2, z, "Line"),
			box(6.4, 0.4, 0.4, 0, 2.6, z, "Line")
		)
	end
	return { Name = "SoccerField", Tier = 4, Boxes = boxes }
end

function CityBuildings.ContainerStack(V)
	local box = V.box
	return {
		Name = "ContainerStack",
		Tier = 4,
		Boxes = {
			box(3, 3, 7.6, -1.5, 0, 0, "Container"),
			box(3, 3, 7.6, 1.5, 0, 0, "Accent"),
			box(3, 3, 7.6, -1.5, 3, 0, "Body"),
			box(3, 3, 7.6, 1.5, 3, 0, "Bus"),
		},
	}
end

function CityBuildings.Yacht(V)
	local box = V.box
	local boxes = {
		box(5, 1.6, 12, 0, 0, 1, "WallWhite"),
		box(3.6, 1.6, 2, 0, 0, -6, "WallWhite"),
		box(2, 1.6, 1.4, 0, 0, -7.7, "WallWhite"),
		box(5, 0.4, 12, 0, 1.6, 1, "Plank"),
		box(4, 2, 6, 0, 2, 2, "WallWhite"),
		box(3.2, 1.6, 4, 0, 4, 2.5, "WallWhite"),
		box(0.2, 1, 4, -2.1, 2.6, 2, "Window"),
		box(0.2, 1, 4, 2.1, 2.6, 2, "Window"),
	}
	return { Name = "Yacht", Tier = 4, Boxes = boxes }
end

-- Tier 5: comércio grande, escritórios, serviços, aeroporto, fábrica ------------------------------

function CityBuildings.Supermarket(V)
	local box = V.box
	local boxes = {
		box(32, 8, 22, 0, 0, 0, "WallWhite"),
		box(33, 0.8, 23, 0, 8, 0, "Accent"),
		box(20, 3, 0.4, 0, 0.6, -11.2, "Glass"),
		box(14, 2.4, 0.4, 0, 5, -11.2, "Sign"),
	}
	for _, x in { -8, 0, 8 } do
		table.insert(boxes, box(4, 1.6, 3, x, 8.8, 4, "Metal"))
	end
	return { Name = "Supermarket", Tier = 5, Boxes = boxes }
end

function CityBuildings.Office(V)
	local box = V.box
	local boxes = { box(18, 1, 16, 0, 0, 0, "Stone") }
	local top = V.banded(boxes, 16, 14, 0, 0, 1, 5, 4, "Glass", "Trim", 0.4)
	-- marquise da entrada encostada na fachada, com dois postes
	V.add(boxes, box(6, 2, 5, 3, top, 2, "Metal"), box(6, 0.4, 2, 0, 4.4, -8, "Trim"))
	table.insert(boxes, box(0.6, 4.4, 0.6, -2.7, 0, -8.6, "Metal"))
	table.insert(boxes, box(0.6, 4.4, 0.6, 2.7, 0, -8.6, "Metal"))
	return { Name = "Office", Tier = 5, Boxes = boxes }
end

function CityBuildings.School(V)
	local box = V.box
	local boxes = {
		box(26, 10, 12, 0, 0, 0, "Brick"),
		box(27, 0.6, 13, 0, 10, 0, "Trim"),
		box(6, 4, 4, 0, 10.6, 0, "Brick"),
		box(3, 3, 0.4, 0, 11, -2.2, "Clock"),
		box(7, 0.6, 5, 0, 14.6, 0, "Roof"),
		box(4, 4, 0.4, 0, 0, -6.2, "Door"),
	}
	V.frontWindows(boxes, 12, { -9, -5, 5, 9 }, 1.6, 2.4, 2)
	V.frontWindows(boxes, 12, { -9, -5, 0, 5, 9 }, 6, 2.4, 2)
	V.add(boxes, box(0.4, 14, 0.4, 14, 0, -4, "Metal"), box(2.4, 1.6, 0.2, 15.4, 12, -4, "Accent"))
	return { Name = "School", Tier = 5, Boxes = boxes }
end

function CityBuildings.FireStation(V)
	local box = V.box
	local boxes = {
		box(20, 9, 14, 0, 0, 0, "Red"),
		box(21, 0.6, 15, 0, 9, 0, "Trim"),
		box(5, 7, 5, 6, 9.6, 3, "Red"),
		box(6, 0.6, 6, 6, 16.6, 3, "Roof"),
		box(5.4, 5.4, 0.4, -5, 0, -7.2, "Garage"),
		box(5.4, 5.4, 0.4, 2, 0, -7.2, "Garage"),
		box(2, 3.4, 0.4, 7.8, 0, -7.2, "Door"),
		box(12, 1.6, 0.4, -1.5, 6.4, -7.2, "Sign"),
	}
	return { Name = "FireStation", Tier = 5, Boxes = boxes }
end

function CityBuildings.Church(V)
	local box = V.box
	local boxes = {
		box(10, 8, 18, 0, 0, 2, "WallWhite"),
		box(2.4, 4, 0.4, 0, 0, -11.2, "Door"),
	}
	-- telhado em degraus da nave
	for i, width in { 11, 8.4, 5.8, 3.2 } do
		table.insert(boxes, box(width, 1.4, 18, 0, 8 + (i - 1) * 1.4, 2, if i == 4 then "RoofTop" else "Roof"))
	end
	-- torre na frente, encostada na fachada
	V.stack(boxes, 0, -9, 0, { { 5, 14, 4 } }, { "WallWhite" })
	V.stack(boxes, 0, -9, 14, { { 5.6, 0.6, 4.6 }, { 4, 3, 3.4 }, { 2.6, 3, 2.4 }, { 1.2, 3, 1.2 } }, {
		"Trim",
		"Roof",
		"Roof",
		"RoofTop",
	})
	V.add(boxes, box(2, 2.4, 0.4, 0, 9, -11.2, "Window"), box(0.4, 3, 1.6, 5.2, 3, 2, "Window"))
	return { Name = "Church", Tier = 5, Boxes = boxes }
end

function CityBuildings.Bank(V)
	local box = V.box
	local boxes = {
		box(20, 1, 16, 0, 0, 0, "Stone"),
		box(18, 10, 12, 0, 1, 1, "Stone"),
		box(19, 0.8, 15, 0, 11, 0, "Trim"),
		box(3, 4, 0.4, 0, 1, -5.2, "Door"),
	}
	for _, x in { -7.5, -4.5, 4.5, 7.5 } do
		table.insert(boxes, box(1.4, 10, 1.4, x, 1, -6.8, "WallWhite"))
	end
	for i, width in { 18, 12, 6 } do
		table.insert(boxes, box(width, 1.2, 4, 0, 11.8 + (i - 1) * 1.2, -5, if i == 3 then "RoofTop" else "Roof"))
	end
	return { Name = "Bank", Tier = 5, Boxes = boxes }
end

function CityBuildings.Hangar(V)
	local box = V.box
	local boxes = { box(26, 8, 22, 0, 0, 0, "Metal") }
	for i, width in { 24, 20, 14, 6 } do
		table.insert(boxes, box(width, 1.6, 22, 0, 8 + (i - 1) * 1.6, 0, if i == 4 then "RoofTop" else "Roof"))
	end
	V.add(boxes, box(18, 7, 0.4, 0, 0, -11.2, "Garage"), box(10, 1.4, 0.4, 0, 8.6, -11.2, "Sign"))
	return { Name = "Hangar", Tier = 5, Boxes = boxes }
end

function CityBuildings.ControlTower(V)
	local box = V.box
	local boxes = {
		box(10, 3, 10, 0, 0, 0, "WallWhite"),
		box(4, 18, 4, 0, 3, 0, "WallWhite"),
		box(7, 0.6, 7, 0, 21, 0, "Trim"),
		box(7, 3, 7, 0, 21.6, 0, "Glass"),
		box(8, 0.6, 8, 0, 24.6, 0, "Accent"),
		box(0.4, 4, 0.4, 0, 25.2, 0, "Metal"),
		box(1, 1, 1, 0, 29.2, 0, "Light"),
	}
	return { Name = "ControlTower", Tier = 5, Boxes = boxes }
end

function CityBuildings.Plane(V)
	local box = V.box
	return {
		Name = "Plane",
		Tier = 5,
		Boxes = {
			box(0.6, 1.6, 0.6, 0, 0, -10, "Tire"),
			box(0.6, 3, 0.6, -4, 0, 1, "Tire"),
			box(0.6, 3, 0.6, 4, 0, 1, "Tire"),
			box(4, 4, 26, 0, 1.6, 0, "WallWhite"),
			box(3, 3, 2, 0, 2, -14, "WallWhite"),
			box(13, 0.6, 6, -8.5, 3, 1, "WallWhite"),
			box(13, 0.6, 6, 8.5, 3, 1, "WallWhite"),
			box(1.6, 1.6, 3, -6, 1.4, 0, "Metal"),
			box(1.6, 1.6, 3, 6, 1.4, 0, "Metal"),
			box(0.6, 5, 4, 0, 5.6, 11, "Accent"),
			box(4, 0.4, 3, -4, 4.4, 11.5, "WallWhite"),
			box(4, 0.4, 3, 4, 4.4, 11.5, "WallWhite"),
			box(0.2, 0.8, 20, -2.1, 4, -1, "Window"),
			box(0.2, 0.8, 20, 2.1, 4, -1, "Window"),
		},
	}
end

function CityBuildings.Terminal(V)
	local box = V.box
	local boxes = {
		box(40, 8, 16, 0, 0, 0, "WallWhite"),
		box(41, 1, 17, 0, 8, 0, "Accent"),
		box(30, 4, 0.4, 0, 1, -8.2, "Glass"),
		box(16, 2, 0.4, 0, 5.4, -8.2, "Sign"),
		box(14, 6, 10, -8, 9, 2, "Glass"),
		box(15, 0.8, 11, -8, 15, 2, "Trim"),
	}
	return { Name = "Terminal", Tier = 5, Boxes = boxes }
end

function CityBuildings.FactoryHall(V)
	local box = V.box
	local boxes = {
		box(24, 9, 18, 0, 0, 0, "Brick"),
		box(25, 0.6, 19, 0, 9, 0, "Trim"),
		box(10, 6, 0.4, -4, 0, -9.2, "Garage"),
	}
	-- telhado em serra
	for i = 0, 3 do
		local x = -9 + i * 6
		V.add(boxes, box(6, 1.6, 19, x, 9.6, 0, "Metal"), box(3, 1.4, 19, x - 1.5, 11.2, 0, "Glass"))
	end
	-- chaminé alta ao lado
	V.stack(boxes, 15, 4, 0, { { 4, 22 }, { 3.2, 4 } }, { "Brick", "Red" })
	return { Name = "FactoryHall", Tier = 5, Boxes = boxes }
end

function CityBuildings.SkiLodge(V)
	local box = V.box
	local boxes = {
		box(20, 10, 14, 0, 0, 0, "Plank"),
		box(3, 4, 0.4, 0, 0, -7.2, "Door"),
	}
	V.frontWindows(boxes, 14, { -6, 6 }, 1.6, 3, 2.2)
	V.frontWindows(boxes, 14, { -6, 0, 6 }, 6, 3, 2.2)
	V.stepRoof(boxes, 20, 14, 10, 5, 1.4, "Roof")
	return { Name = "SkiLodge", Tier = 5, Boxes = boxes }
end

-- Tier 6: torres, hotel, hospital, usina, guindaste, farol ------------------------------------------

function CityBuildings.OfficeTower(V)
	local box = V.box
	local boxes = { box(22, 4, 22, 0, 0, 0, "Stone") }
	local top = V.banded(boxes, 16, 16, 0, 0, 4, 12, 5, "Glass", "Trim", 0.4)
	V.add(boxes, box(10, 3, 10, 0, top, 0, "Metal"), box(0.8, 10, 0.8, 0, top + 3, 0, "Metal"))
	table.insert(boxes, box(6, 3, 0.4, 0, 0.5, -11.2, "Door"))
	return { Name = "OfficeTower", Tier = 6, Boxes = boxes }
end

function CityBuildings.GlassTower(V)
	local box = V.box
	local boxes = { box(22, 3, 22, 0, 0, 0, "Trim") }
	local top = V.banded(boxes, 18, 18, 0, 0, 3, 8, 5, "Glass", "Trim", 0.4)
	top = V.banded(boxes, 13, 13, 0, 0, top, 6, 5, "Glass", "Trim", 0.4)
	V.add(boxes, box(8, 4, 8, 0, top, 0, "RoofTop"))
	return { Name = "GlassTower", Tier = 6, Boxes = boxes }
end

function CityBuildings.RedTower(V)
	local box = V.box
	local boxes = { box(18, 2, 18, 0, 0, 0, "Stone") }
	local top = V.banded(boxes, 14, 14, 0, 0, 2, 10, 5, "Brick", "Trim", 0.3)
	V.add(boxes, box(10, 3, 10, 0, top, 0, "Roof"), box(4, 2, 4, 0, top + 3, 0, "RoofTop"))
	return { Name = "RedTower", Tier = 6, Boxes = boxes }
end

function CityBuildings.ApartmentTall(V)
	local box = V.box
	local boxes = { box(20, 1, 16, 0, 0, 0, "Stone") }
	local top = V.banded(boxes, 18, 14, 0, 0, 1, 9, 4.6, "Wall", "Trim", 0.4)
	V.add(boxes, box(19, 1, 15, 0, top, 0, "Roof"), box(4, 3, 4, 4, top + 1, 2, "Metal"))
	table.insert(boxes, box(3, 3.4, 0.4, 0, 1, -7.2, "Door"))
	return { Name = "ApartmentTall", Tier = 6, Boxes = boxes }
end

function CityBuildings.Hotel(V)
	local box = V.box
	local boxes = { box(28, 1, 14, 0, 0, 0, "Stone") }
	local top = V.banded(boxes, 26, 12, 0, 0, 1, 10, 4.4, "WallWhite", "Accent", 0.5)
	V.add(boxes, box(27, 1, 13, 0, top, 0, "Roof"), box(12, 3, 0.4, 0, top + 1, -6.2, "Sign"))
	V.add(boxes, box(4, 3.4, 0.4, 0, 1, -6.2, "Door"))
	return { Name = "Hotel", Tier = 6, Boxes = boxes }
end

function CityBuildings.Hospital(V)
	local box = V.box
	local boxes = { box(26, 1, 20, 0, 0, 0, "Stone") }
	local top = V.banded(boxes, 24, 18, 0, 0, 1, 6, 5, "WallWhite", "Trim", 0.4)
	V.add(
		boxes,
		box(25, 1, 19, 0, top, 0, "Trim"),
		box(8, 0.4, 8, 4, top + 1, 2, "Accent"),
		box(1.4, 5, 0.4, 0, top - 9, -9.6, "Red"),
		box(1.8, 1.4, 0.4, -1.6, top - 7.2, -9.6, "Red"),
		box(1.8, 1.4, 0.4, 1.6, top - 7.2, -9.6, "Red"),
		box(5, 3.4, 0.4, 0, 1, -9.2, "Door")
	)
	return { Name = "Hospital", Tier = 6, Boxes = boxes }
end

function CityBuildings.CoolingTower(V)
	local boxes = {}
	V.stack(
		boxes,
		0,
		0,
		0,
		{ { 20, 4 }, { 18, 4 }, { 16, 4 }, { 14.5, 4 }, { 14, 4 }, { 14.5, 3 }, { 15.4, 2 } },
		{ "Concrete", "Concrete", "Stone" }
	)
	return { Name = "CoolingTower", Tier = 6, Boxes = boxes }
end

function CityBuildings.Crane(V)
	local box = V.box
	local boxes = {}
	for _, x in { -6, 6 } do
		for _, z in { -4, 4 } do
			table.insert(boxes, box(1.6, 22, 1.6, x, 0, z, "Accent"))
		end
	end
	V.add(
		boxes,
		box(13.6, 2, 9.6, 0, 22, 0, "Accent"),
		box(3, 1.6, 30, 0, 24, -10, "Accent"),
		box(3, 2.4, 3, 3.5, 24, 3, "WallWhite"),
		-- gancho pendurado na ponta da lança
		box(0.4, 8, 0.4, 0, 16, -22, "Metal"),
		box(2, 1, 2, 0, 15, -22, "Metal")
	)
	return { Name = "Crane", Tier = 6, Boxes = boxes }
end

function CityBuildings.Lighthouse(V)
	local boxes = {}
	local y = V.stack(boxes, 0, 0, 0, { { 12, 2 }, { 9, 2 } }, { "Rock" })
	y = V.stack(
		boxes,
		0,
		0,
		y,
		{ { 6, 3 }, { 5.6, 3 }, { 5.2, 3 }, { 4.8, 3 }, { 4.4, 3 }, { 4, 3 } },
		{ "Red", "WallWhite" }
	)
	y = V.stack(boxes, 0, 0, y, { { 5.4, 0.6 }, { 3.6, 2.4 } }, { "Trim", "Light" })
	V.stack(boxes, 0, 0, y, { { 4.6, 0.6 }, { 3, 1 }, { 1.4, 1 } }, { "Red" })
	return { Name = "Lighthouse", Tier = 6, Boxes = boxes }
end

-- Tier 7: marcos ---------------------------------------------------------------------------------

function CityBuildings.SpireTower(V)
	local box = V.box
	local boxes = { box(28, 4, 28, 0, 0, 0, "Stone") }
	local top = V.banded(boxes, 22, 22, 0, 0, 4, 12, 6, "Glass", "Trim", 0.4)
	top = V.banded(boxes, 17, 17, 0, 0, top, 8, 6, "Glass", "Trim", 0.4)
	top = V.banded(boxes, 12, 12, 0, 0, top, 6, 6, "Glass", "Trim", 0.4)
	V.add(boxes, box(6, 4, 6, 0, top, 0, "Metal"), box(1.4, 30, 1.4, 0, top + 4, 0, "Metal"))
	table.insert(boxes, box(1, 1.4, 1, 0, top + 34, 0, "Light"))
	table.insert(boxes, box(8, 4, 0.4, 0, 0.5, -14.2, "Door"))
	return { Name = "SpireTower", Tier = 7, Boxes = boxes }
end

function CityBuildings.TwinTowers(V)
	local box = V.box
	local boxes = { box(34, 4, 16, 0, 0, 0, "Stone") }
	local tops = {}
	for _, x in { -9, 9 } do
		tops[x] = V.banded(boxes, 12, 12, x, 0, 4, 18, 5, "Glass", "Trim", 0.3)
	end
	-- ponte entre as torres (encostada nas duas)
	table.insert(boxes, box(5.4, 4, 5, 0, 48, 0, "Trim"))
	for _, x in { -9, 9 } do
		V.add(boxes, box(8, 6, 8, x, tops[x], 0, "RoofTop"), box(0.8, 8, 0.8, x, tops[x] + 6, 0, "Metal"))
	end
	return { Name = "TwinTowers", Tier = 7, Boxes = boxes }
end

function CityBuildings.TVTower(V)
	local box = V.box
	local boxes = {}
	local y = V.stack(boxes, 0, 0, 0, { { 14, 3 }, { 10, 3 }, { 6, 4 } }, { "Stone", "Red", "WallWhite" })
	for i = 1, 10 do
		table.insert(boxes, box(3, 6, 3, 0, y, 0, if i % 2 == 0 then "WallWhite" else "Red"))
		y += 6
	end
	y = V.stack(boxes, 0, 0, y, { { 8, 2 }, { 11, 4 }, { 8, 2 } }, { "Trim", "Glass", "Trim" })
	for i = 1, 4 do
		table.insert(boxes, box(1.2, 5, 1.2, 0, y, 0, if i % 2 == 0 then "WallWhite" else "Red"))
		y += 5
	end
	table.insert(boxes, box(1, 1, 1, 0, y, 0, "Light"))
	return { Name = "TVTower", Tier = 7, Boxes = boxes }
end

-- Roda-gigante: aro "pixelado" (quadrados de 2 que só se encostam), raios, eixo e cabines.
function CityBuildings.FerrisWheel(V)
	local box = V.box
	local radius, cell = 16, 2
	local hubY = radius + 5
	local boxes = { box(14, 1, 10, 0, 0, 0, "Stone") }
	for _, z in { -2, 2 } do
		table.insert(boxes, box(1.2, hubY - 2, 1.2, 0, 1, z, "Metal"))
	end
	table.insert(boxes, box(2, 2, 5.2, 0, hubY - 1, 0, "Metal"))
	for i = -radius - 1, radius do
		for j = -radius - 1, radius do
			local cx, cy = (i + 0.5) * cell, (j + 0.5) * cell
			local dist = math.sqrt(cx * cx + cy * cy)
			if dist >= radius - 1 and dist < radius + 1 then
				local role = if (i + j) % 6 == 0 then "Light" elseif (i + j) % 2 == 0 then "Accent" else "WallWhite"
				table.insert(boxes, box(cell, cell, 1, cx, hubY + cy - cell / 2, 0, role))
			end
		end
	end
	-- raios (horizontais e verticais) do eixo até o aro
	local inner = radius - 2
	for _, side in { -1, 1 } do
		table.insert(boxes, box(inner - 1, 0.8, 1, side * (1 + (inner - 1) / 2), hubY - 0.4, 0, "Metal"))
		table.insert(boxes, box(0.8, inner - 1, 1, 0, if side > 0 then hubY + 1 else hubY - inner, 0, "Metal"))
	end
	-- cabines encostadas por fora do aro, nas quatro pontas
	V.add(
		boxes,
		box(3, 2.4, 2.4, radius + 1.5, hubY - 1.2, 0, "Body"),
		box(3, 2.4, 2.4, -radius - 1.5, hubY - 1.2, 0, "Bus"),
		box(2.4, 2.4, 2.4, 0, hubY + radius, 0, "Body")
	)
	return { Name = "FerrisWheel", Tier = 7, Boxes = boxes }
end

function CityBuildings.CargoShip(V)
	local box = V.box
	local boxes = {
		box(12, 5, 52, 0, 0, 2, "Hull"),
		box(9, 5, 4, 0, 0, -26, "Hull"),
		box(5, 5, 3, 0, 0, -29.5, "Hull"),
		box(12.4, 0.6, 52, 0, 5, 2, "Trim"),
		box(10, 9, 7, 0, 5.6, 23, "WallWhite"),
		box(11, 0.6, 8, 0, 14.6, 23, "Accent"),
		box(8, 1.4, 0.3, 0, 12, 19.35, "Window"),
		box(2, 5, 2, 0, 15.2, 25, "Red"),
	}
	local roles = { "Container", "Accent", "Body", "Bus" }
	local k = 0
	for row = 0, 4 do
		for col = -1, 1 do
			k += 1
			local z = -18 + row * 7.8
			table.insert(boxes, box(3.6, 3, 7.6, col * 3.6, 5.6, z, roles[(k - 1) % 4 + 1]))
			if (row + col) % 2 == 0 then
				table.insert(boxes, box(3.6, 3, 7.6, col * 3.6, 8.6, z, roles[k % 4 + 1]))
			end
		end
	end
	return { Name = "CargoShip", Tier = 6, Boxes = boxes }
end

return CityBuildings
