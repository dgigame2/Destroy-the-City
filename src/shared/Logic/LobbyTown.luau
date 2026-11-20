--!strict
-- Cidadezinha em volta do parque do lobby (LobbyConfig.Town). Lógica pura: testada no Lune (LobbyTown.spec).
-- O parque (gramado W x D, centro 0,0) é cercado, de dentro para fora, por: calçada, rua (com faixa
-- amarela no meio), calçada de fora, lotes com casas viradas para a rua (árvores entre elas) e um gramado
-- até o horizonte. Cada faixa é um anel de 4 retângulos que só encostam (nenhum passa por cima do outro).

local BlockTrees = if script then require(script.Parent.BlockTrees) else require("./BlockTrees")

local LobbyTown = {}

export type Rect = { X0: number, Z0: number, X1: number, Z1: number }
export type Item = { Template: string, X: number, Z: number, Yaw: number, Scale: number, Variant: number? }
export type Config = {
	Sidewalk: number,
	Road: number,
	Lot: number,
	Horizon: number,
	HousePitch: number,
	HouseScale: number,
	Houses: { string },
	TreeScale: number,
	Dash: { number }, -- { comprimento, largura, passo }
	Cars: number, -- carros parados por lado comprido
	BuildingGap: number,
	BuildingLot: number,
	BuildingPitch: number,
	BuildingScale: number,
	Buildings: { string },
	ForestGap: number, -- vão entre os prédios do fundo e a floresta
	ForestDepth: number,
	ForestPitch: number,
	ForestDensity: number, -- 0..1: quantas casas da grade têm árvore
	ForestScale: { number }, -- escala mínima e máxima das árvores da floresta
	HillGap: number,
	HillPitch: number,
	Hills: { { number } }, -- tamanho (X, Z) de cada morro (Lobby_Hill1..3)
}
export type Town = {
	Sidewalks: { Rect },
	Roads: { Rect },
	Dashes: { Rect },
	Ground: { Rect },
	Houses: { Item },
	Trees: { Item },
	Cars: { Item },
	Buildings: { Item },
	Forest: { Item },
	Hills: { Item }, -- Template = "Hill" .. n
	Outer: { number }, -- meia-largura e meia-profundidade de onde acabam os lotes
	Outer2: { number }, -- até onde vão os prédios do fundo
}

-- anel entre a caixa de dentro (hx, hz = meias medidas) e a de fora (hx + t, hz + t), em 4 retângulos:
-- frente e fundo com a largura toda, laterais só entre eles
local function ring(hx: number, hz: number, t: number): { Rect }
	local ox, oz = hx + t, hz + t
	return {
		{ X0 = -ox, Z0 = -oz, X1 = ox, Z1 = -hz },
		{ X0 = -ox, Z0 = hz, X1 = ox, Z1 = oz },
		{ X0 = -ox, Z0 = -hz, X1 = -hx, Z1 = hz },
		{ X0 = hx, Z0 = -hz, X1 = ox, Z1 = hz },
	}
end

-- Posições ao longo de um lado de comprimento `length`, de `pitch` em `pitch`, centradas.
local function along(length: number, pitch: number): { number }
	local n = math.floor(length / pitch)
	local list = {}
	for i = 0, n - 1 do
		table.insert(list, (i - (n - 1) / 2) * pitch)
	end
	return list
end

function LobbyTown.build(width: number, depth: number, cfg: Config): Town
	local hx, hz = width / 2, depth / 2
	local town: Town = {
		Sidewalks = {},
		Roads = {},
		Dashes = {},
		Ground = {},
		Houses = {},
		Trees = {},
		Cars = {},
		Buildings = {},
		Forest = {},
		Hills = {},
		Outer = {},
		Outer2 = {},
	}
	for _, r in ring(hx, hz, cfg.Sidewalk) do
		table.insert(town.Sidewalks, r)
	end
	local rx, rz = hx + cfg.Sidewalk, hz + cfg.Sidewalk
	for _, r in ring(rx, rz, cfg.Road) do
		table.insert(town.Roads, r)
	end
	local sx, sz = rx + cfg.Road, rz + cfg.Road
	for _, r in ring(sx, sz, cfg.Sidewalk) do
		table.insert(town.Sidewalks, r)
	end
	local lx, lz = sx + cfg.Sidewalk, sz + cfg.Sidewalk -- começo dos lotes
	for _, r in ring(lx, lz, cfg.Lot + cfg.Horizon) do
		table.insert(town.Ground, r)
	end
	town.Outer = { lx + cfg.Lot, lz + cfg.Lot }

	-- faixa amarela tracejada no meio da rua (só nos trechos retos, longe das esquinas)
	local mid = cfg.Road / 2
	local len, wid, step = cfg.Dash[1], cfg.Dash[2], cfg.Dash[3]
	for _, x in along(2 * rx - cfg.Road, step) do
		for _, z in { -(rz + mid), rz + mid } do
			table.insert(town.Dashes, { X0 = x - len / 2, Z0 = z - wid / 2, X1 = x + len / 2, Z1 = z + wid / 2 })
		end
	end
	for _, z in along(2 * rz - cfg.Road, step) do
		for _, x in { -(rx + mid), rx + mid } do
			table.insert(town.Dashes, { X0 = x - wid / 2, Z0 = z - len / 2, X1 = x + wid / 2, Z1 = z + len / 2 })
		end
	end

	-- casas: no meio da faixa dos lotes, de frente para a rua (a frente dos modelos é -Z)
	local houseZ, houseX = lz + cfg.Lot / 2, lx + cfg.Lot / 2
	local count = 0
	local function house(x: number, z: number, yaw: number)
		count += 1
		local template = cfg.Houses[(count - 1) % #cfg.Houses + 1]
		table.insert(town.Houses, { Template = template, X = x, Z = z, Yaw = yaw, Scale = cfg.HouseScale })
	end
	local function tree(x: number, z: number)
		local n = #town.Trees + 1
		table.insert(town.Trees, { Template = "BlockTree", X = x, Z = z, Yaw = 0, Scale = cfg.TreeScale, Variant = n })
	end
	local rowX = along(2 * lx, cfg.HousePitch)
	local rowZ = along(2 * lz, cfg.HousePitch)
	for i, x in rowX do
		house(x, -houseZ, 180) -- fundo: olha para +Z
		house(x, houseZ, 0) -- frente: olha para -Z
		if i < #rowX then
			local tx = x + cfg.HousePitch / 2
			tree(tx, -houseZ)
			tree(tx, houseZ)
		end
	end
	for i, z in rowZ do
		house(-houseX, z, -90) -- esquerda: olha para +X
		house(houseX, z, 90) -- direita: olha para -X
		if i < #rowZ then
			local tz = z + cfg.HousePitch / 2
			tree(-houseX, tz)
			tree(houseX, tz)
		end
	end
	-- esquinas: uma árvore em cada
	for _, sxSign in { -1, 1 } do
		for _, szSign in { -1, 1 } do
			tree(sxSign * houseX, szSign * houseZ)
		end
	end

	-- prédios maiores no fundo: outra fileira atrás das casas (vira o horizonte da cidade), de frente para o parque
	local bx0, bz0 = town.Outer[1] + cfg.BuildingGap, town.Outer[2] + cfg.BuildingGap
	local bx, bz = bx0 + cfg.BuildingLot / 2, bz0 + cfg.BuildingLot / 2
	local built = 0
	local function building(x: number, z: number, yaw: number)
		built += 1
		local template = cfg.Buildings[(built - 1) % #cfg.Buildings + 1]
		table.insert(town.Buildings, { Template = template, X = x, Z = z, Yaw = yaw, Scale = cfg.BuildingScale })
	end
	for _, x in along(2 * (bx0 + cfg.BuildingLot), cfg.BuildingPitch) do
		building(x, -bz, 180)
		building(x, bz, 0)
	end
	for _, z in along(2 * bz0, cfg.BuildingPitch) do
		building(-bx, z, -90)
		building(bx, z, 90)
	end
	town.Outer2 = { bx0 + cfg.BuildingLot, bz0 + cfg.BuildingLot }

	-- floresta de árvores de blocos atrás dos prédios: grade com um "sorteio" fixo pela posição (sempre igual)
	local f0x, f0z = town.Outer2[1] + cfg.ForestGap, town.Outer2[2] + cfg.ForestGap
	local f1x, f1z = f0x + cfg.ForestDepth, f0z + cfg.ForestDepth
	local pitch = cfg.ForestPitch
	local function hash(a: number, b: number): number
		local v = math.sin(a * 12.9898 + b * 78.233) * 43758.5453
		return v - math.floor(v)
	end
	local gx = math.floor(f1x / pitch)
	local gz = math.floor(f1z / pitch)
	for i = -gx, gx do
		for j = -gz, gz do
			local x, z = i * pitch, j * pitch
			-- só no anel da floresta (fora da caixa dos prédios + vão, dentro da caixa de fora)
			local outside = math.abs(x) > f0x + pitch / 2 or math.abs(z) > f0z + pitch / 2
			local inBand = math.abs(x) <= f1x - pitch / 2 and math.abs(z) <= f1z - pitch / 2
			if outside and inBand and hash(i, j) < cfg.ForestDensity then
				local jx = (hash(j, i) - 0.5) * pitch * 0.2
				local jz = (hash(i + 7, j - 3) - 0.5) * pitch * 0.2
				local s = cfg.ForestScale[1] + (cfg.ForestScale[2] - cfg.ForestScale[1]) * hash(i - 5, j + 9)
				local v = math.floor(hash(i + 3, j + 1) * 3) + 1
				table.insert(
					town.Forest,
					{ Template = "BlockTree", X = x + jx, Z = z + jz, Yaw = 0, Scale = s, Variant = v }
				)
			end
		end
	end

	-- morros em volta de tudo (horizonte), um do lado do outro sem se cruzar
	local biggest = 0
	for _, h in cfg.Hills do
		biggest = math.max(biggest, h[1], h[2])
	end
	local hx2, hz2 = f1x + cfg.HillGap + biggest / 2, f1z + cfg.HillGap + biggest / 2
	local hillCount = 0
	local function hillAt(x: number, z: number)
		hillCount += 1
		local n = (hillCount - 1) % #cfg.Hills + 1
		table.insert(town.Hills, { Template = "Hill" .. n, X = x, Z = z, Yaw = 0, Scale = 1, Variant = n })
	end
	for _, x in along(2 * hx2 + cfg.HillPitch, cfg.HillPitch) do
		hillAt(x, -hz2)
		hillAt(x, hz2)
	end
	for _, z in along(2 * hz2 - cfg.HillPitch, cfg.HillPitch) do
		hillAt(-hx2, z)
		hillAt(hx2, z)
	end

	-- carros parados na rua, encostados na calçada de fora, nos lados compridos
	local laneZ = rz + cfg.Road * 0.75
	for i, x in along(2 * rx - cfg.Road * 2, (2 * rx - cfg.Road * 2) / cfg.Cars) do
		local side = if i % 2 == 0 then 1 else -1
		table.insert(town.Cars, { Template = "Car", X = x, Z = side * laneZ, Yaw = 90, Scale = 1 })
	end
	return town
end

-- Caixa no chão de qualquer item da cidade: árvore de blocos, morro (tamanho em cfg.Hills) ou modelo dos
-- Templates (footprint = Templates[nome].Footprint).
function LobbyTown.box(item: Item, cfg: Config, templates: { [string]: any }): Rect
	if item.Template == "BlockTree" then
		local hx, hz = BlockTrees.half(BlockTrees.pick(item.Variant or 1), item.Scale)
		return { X0 = item.X - hx, Z0 = item.Z - hz, X1 = item.X + hx, Z1 = item.Z + hz }
	elseif string.sub(item.Template, 1, 4) == "Hill" then
		local size = cfg.Hills[item.Variant or 1]
		return LobbyTown.footprint(item, size)
	end
	return LobbyTown.footprint(item, templates[item.Template].Footprint)
end

-- Caixa (x0, z0, x1, z1) que um modelo ocupa no chão, girada em passos de 90° (Footprint = {X, Z}).
function LobbyTown.footprint(item: Item, footprint: { number }): Rect
	local fx, fz = footprint[1] * item.Scale / 2, footprint[2] * item.Scale / 2
	if math.abs(item.Yaw) % 180 == 90 then
		fx, fz = fz, fx
	end
	return { X0 = item.X - fx, Z0 = item.Z - fz, X1 = item.X + fx, Z1 = item.Z + fz }
end

return LobbyTown
