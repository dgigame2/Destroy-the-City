--!strict
-- Gera o layout de uma cidade a partir da definição do mapa. Função pura e determinística:
-- a mesma definição sempre gera o mesmo layout (testável fora do Roblox).

export type MapDef = {
	Id: string,
	Seed: number,
	BlocksX: number,
	BlocksZ: number,
	BlockSize: number,
	RoadWidth: number,
	SidewalkWidth: number,
	BuildingMix: { [string]: number },
	Landmark: string,
	ParkedCarChance: number,
	ParkChance: number, -- chance de um quarteirão virar praça
	NatureMix: { [string]: number }, -- árvores/pedras/cogumelos no miolo dos quarteirões e praças
}

export type Placement = {
	Template: string,
	X: number,
	Z: number,
	Rotation: number, -- 0 ou 180 (frente para -Z ou +Z)
	Width: number,
	Depth: number,
	Variant: number, -- semente de cor da construção
}

export type Layout = {
	Size: { number }, -- tamanho total X, Z
	Placements: { Placement },
	Spawns: { { number } }, -- {x, z} nos cruzamentos
	Blocks: { { number } }, -- {x0, z0, x1, z1} de cada quarteirão
}

type Template = { Footprint: { number } }
type Rng = {
	next: (any) -> number,
	int: (any, number, number) -> number,
	weighted: (any, { [string]: number }) -> string,
}

local GAP = 3 -- espaço entre construções vizinhas
local ROW_DEPTH_RATIO = 0.5 -- cada fileira usa até metade da profundidade útil do quarteirão

local MapGen = {}

local function place(layout: Layout, rng: Rng, name: string, template: Template, x: number, z: number, rotation: number)
	table.insert(layout.Placements, {
		Template = name,
		X = x,
		Z = z,
		Rotation = rotation,
		Width = template.Footprint[1],
		Depth = template.Footprint[2],
		Variant = rng:int(1, 1000000),
	})
end

-- Escolhe um modelo que caiba em (maxW, maxD); tenta algumas vezes e depois desiste.
local function pickFitting(
	rng: Rng,
	templates: { [string]: Template },
	mix: { [string]: number },
	maxW: number,
	maxD: number
): string?
	for _ = 1, 8 do
		local name = rng:weighted(mix)
		local footprint = templates[name].Footprint
		if footprint[1] <= maxW and footprint[2] <= maxD then
			return name
		end
	end
	return nil
end

-- Preenche uma fileira de construções ao longo de X.
local function fillRow(
	layout: Layout,
	rng: Rng,
	templates: { [string]: Template },
	mix: { [string]: number },
	x0: number,
	x1: number,
	edgeZ: number,
	maxDepth: number,
	rotation: number
)
	local cursor = x0
	while x1 - cursor >= 6 do
		local name = pickFitting(rng, templates, mix, x1 - cursor, maxDepth)
		if name == nil then
			name = "Bush"
		end
		local template = templates[name :: string]
		local w, d = template.Footprint[1], template.Footprint[2]
		if w > x1 - cursor then
			break
		end
		local z = if rotation == 0 then edgeZ + d / 2 else edgeZ - d / 2
		place(layout, rng, name :: string, template, cursor + w / 2, z, rotation)
		cursor += w + GAP
	end
end

-- Faixa central entre as duas fileiras: natureza (árvores, pinheiros, pedras, cogumelos, flores).
local function fillMiddle(
	layout: Layout,
	rng: Rng,
	templates: { [string]: Template },
	mix: { [string]: number },
	x0: number,
	x1: number,
	z0: number,
	z1: number
)
	local cursor = x0
	while x1 - cursor >= 4 do
		local name = rng:weighted(mix)
		local template = templates[name]
		local w, d = template.Footprint[1], template.Footprint[2]
		if w > x1 - cursor then
			break
		end
		if d <= z1 - z0 then
			local z = z0 + d / 2 + rng:next() * (z1 - z0 - d)
			place(layout, rng, name, template, cursor + w / 2, z, 0)
		end
		cursor += w + 2
	end
end

-- Praça: fonte no centro, bancos e canteiros em volta, carrinhos de comida e natureza nas bordas.
local function fillPark(
	layout: Layout,
	def: MapDef,
	rng: Rng,
	templates: { [string]: Template },
	ux0: number,
	uz0: number,
	ux1: number,
	uz1: number
)
	local cx, cz = (ux0 + ux1) / 2, (uz0 + uz1) / 2
	local fountain = templates.Fountain
	place(layout, rng, "Fountain", fountain, cx, cz, 0)
	local ring = fountain.Footprint[1] / 2 + 6
	for _, offset in { { 0, -ring }, { 0, ring }, { -ring, 0 }, { ring, 0 } } do
		place(layout, rng, "Bench", templates.Bench, cx + offset[1], cz + offset[2], 0)
	end
	for _, offset in { { -ring, -ring }, { ring, -ring }, { -ring, ring }, { ring, ring } } do
		place(layout, rng, "FlowerPot", templates.FlowerPot, cx + offset[1], cz + offset[2], 0)
	end
	place(layout, rng, "FoodCart", templates.FoodCart, cx - ring - 12, cz - ring + 2, 0)
	place(layout, rng, "FoodCart", templates.FoodCart, cx + ring + 12, cz + ring - 2, 0)
	local inner = ring + 18
	fillMiddle(layout, rng, templates, def.NatureMix, ux0, ux1, uz0, cz - inner)
	fillMiddle(layout, rng, templates, def.NatureMix, ux0, ux1, cz + inner, uz1)
	fillMiddle(layout, rng, templates, def.NatureMix, ux0, cx - inner, cz - inner + 2, cz + inner - 2)
	fillMiddle(layout, rng, templates, def.NatureMix, cx + inner, ux1, cz - inner + 2, cz + inner - 2)
end

local function fillBlock(
	layout: Layout,
	def: MapDef,
	rng: Rng,
	templates: { [string]: Template },
	ux0: number,
	uz0: number,
	ux1: number,
	uz1: number
)
	local usableD = uz1 - uz0
	if rng:next() < def.ParkChance then
		fillPark(layout, def, rng, templates, ux0, uz0, ux1, uz1)
		return
	end

	-- Duas fileiras: frente para a rua de baixo (-Z) e de cima (+Z).
	local rowDepth = usableD * ROW_DEPTH_RATIO - GAP
	local smallMix = {}
	for name, weight in def.BuildingMix do
		if templates[name].Footprint[2] <= rowDepth then
			smallMix[name] = weight
		end
	end
	if next(smallMix) == nil then
		return
	end
	fillRow(layout, rng, templates, smallMix, ux0, ux1, uz0, rowDepth, 0)
	fillRow(layout, rng, templates, smallMix, ux0, ux1, uz1, rowDepth, 180)

	-- Maior profundidade realmente usada em cada fileira define a faixa livre do meio.
	local frontDepth, backDepth = 0, 0
	for i = #layout.Placements, 1, -1 do
		local p = layout.Placements[i]
		if p.X < ux0 or p.X > ux1 or p.Z < uz0 or p.Z > uz1 then
			break
		end
		if p.Rotation == 0 then
			frontDepth = math.max(frontDepth, p.Depth)
		else
			backDepth = math.max(backDepth, p.Depth)
		end
	end
	fillMiddle(layout, rng, templates, def.NatureMix, ux0, ux1, uz0 + frontDepth + GAP, uz1 - backDepth - GAP)
end

-- Props na calçada: postes a cada ~28 studs, com lixeiras, bancos e hidrantes alternados.
local function fillSidewalk(
	layout: Layout,
	rng: Rng,
	templates: { [string]: Template },
	x0: number,
	x1: number,
	z: number
)
	local spacing = 10
	local cursor = x0 + 4
	local index = 0
	local props = { "Lamp", "Bin", "FlowerPot", "Lamp", "Bench", "Mailbox", "Lamp", "Hydrant", "Cone" }
	while cursor <= x1 - 4 do
		index += 1
		local name = props[(index - 1) % #props + 1]
		if name == "Lamp" or rng:next() < 0.7 then
			place(layout, rng, name, templates[name], cursor, z, 0)
		end
		cursor += spacing
	end
end

-- Carros estacionados na beira das ruas horizontais, fora dos cruzamentos.
local function fillParkedCars(
	layout: Layout,
	def: MapDef,
	rng: Rng,
	templates: { [string]: Template },
	x0: number,
	x1: number,
	laneZ: number
)
	local car = templates.Car
	local length = car.Footprint[2]
	local cursor = x0 + 6
	while cursor + length <= x1 - 6 do
		if rng:next() < def.ParkedCarChance then
			-- estacionado de frente para a calçada (alinhado em Z); de vez em quando um ônibus
			local name = if rng:next() < 0.12 then "Bus" else "Car"
			local vehicle = templates[name]
			if cursor + vehicle.Footprint[1] <= x1 - 6 then
				local z = laneZ - (vehicle.Footprint[2] - length) / 2
				place(
					layout,
					rng,
					name,
					vehicle,
					cursor + vehicle.Footprint[1] / 2,
					z,
					if rng:next() < 0.5 then 0 else 180
				)
				cursor += vehicle.Footprint[1] - car.Footprint[1]
			end
		end
		cursor += car.Footprint[1] + 6
	end
end

function MapGen.generate(def: MapDef, templates: { [string]: Template }, rng: Rng): Layout
	local block, road, walk = def.BlockSize, def.RoadWidth, def.SidewalkWidth
	local sizeX = def.BlocksX * block + (def.BlocksX + 1) * road
	local sizeZ = def.BlocksZ * block + (def.BlocksZ + 1) * road
	local layout: Layout = { Size = { sizeX, sizeZ }, Placements = {}, Spawns = {}, Blocks = {} }

	local landmarkI, landmarkJ = math.floor(def.BlocksX / 2), math.floor(def.BlocksZ / 2)

	for i = 0, def.BlocksX - 1 do
		for j = 0, def.BlocksZ - 1 do
			local x0 = -sizeX / 2 + road + i * (block + road)
			local z0 = -sizeZ / 2 + road + j * (block + road)
			local x1, z1 = x0 + block, z0 + block
			table.insert(layout.Blocks, { x0, z0, x1, z1 })

			-- Calçadas: props na faixa externa do quarteirão (lados de baixo e de cima).
			fillSidewalk(layout, rng, templates, x0, x1, z0 + walk / 2)
			fillSidewalk(layout, rng, templates, x0, x1, z1 - walk / 2)

			local ux0, uz0, ux1, uz1 = x0 + walk, z0 + walk, x1 - walk, z1 - walk
			if i == landmarkI and j == landmarkJ then
				local landmark = templates[def.Landmark]
				place(layout, rng, def.Landmark, landmark, (ux0 + ux1) / 2, (uz0 + uz1) / 2, 0)
				-- arbustos nos cantos da praça do marco
				for _, corner in
					{ { ux0 + 3, uz0 + 3 }, { ux1 - 3, uz0 + 3 }, { ux0 + 3, uz1 - 3 }, { ux1 - 3, uz1 - 3 } }
				do
					place(layout, rng, "Bush", templates.Bush, corner[1], corner[2], 0)
				end
			else
				fillBlock(layout, def, rng, templates, ux0, uz0, ux1, uz1)
			end
		end
	end

	-- Carros nas ruas horizontais (faixa perto da calçada de cima de cada rua).
	for j = 0, def.BlocksZ do
		local roadZ0 = -sizeZ / 2 + j * (block + road)
		for i = 0, def.BlocksX - 1 do
			local x0 = -sizeX / 2 + road + i * (block + road)
			fillParkedCars(
				layout,
				def,
				rng,
				templates,
				x0,
				x0 + block,
				roadZ0 + road - templates.Car.Footprint[2] / 2 - 1
			)
		end
	end

	-- Spawns nos cruzamentos internos (os da borda deixam o jogador olhando para o paredão).
	for i = 1, def.BlocksX - 1 do
		for j = 1, def.BlocksZ - 1 do
			local x = -sizeX / 2 + road / 2 + i * (block + road)
			local z = -sizeZ / 2 + road / 2 + j * (block + road)
			table.insert(layout.Spawns, { x, z })
		end
	end

	return layout
end

return MapGen
