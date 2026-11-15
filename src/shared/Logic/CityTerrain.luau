--!strict
-- Chão da cidade como dados puros (testável fora do Roblox): cada tipo de célula vira blocos (juntando
-- células vizinhas iguais num bloco só), faixas brancas nas ruas e na pista, a terra embaixo e o mar:
--   * a terra (formato da costa da Logic/CityGen) fica em cima de uma base, que aparece como uma beirada
--     entre a grama/areia e a água;
--   * o mar começa claro (raso, com espuma colada na costa) e escurece longe da terra;
--   * fora da cidade: ilhotas com árvores, pedras, barcos (ou icebergs) e uma cadeia de montanhas no horizonte.
-- Estilos do bioma (Border): Island (ilha verde), Beach (praia larga, mar turquesa), IceSea (mar de gelo).
-- O jogador fica na terra (paredes invisíveis da costa, CityGen.Walls). Todos os blocos são alinhados aos
-- eixos e só se encostam.

export type RGB = { number }

export type Slab = {
	Name: string,
	Size: { number },
	Pos: { number }, -- centro
	Color: RGB,
	Invisible: boolean?,
	Material: string?, -- "Water"/"Ice": o Builder deixa liso e um pouco transparente
}

export type Decor = { Template: string, X: number, Y: number, Z: number, Rotation: number, Variant: number }

export type Result = {
	Slabs: { Slab },
	Decor: { Decor },
	Half: { number }, -- meia-largura da grade da cidade, X e Z
}

type Grid = { Width: number, Depth: number, Kind: { string }, Height: { number }, Zone: { number } }
type Template = { Footprint: { number } }
type Biome = { [string]: any }
type Rng = {
	next: (any) -> number,
	int: (any, number, number) -> number,
	weighted: (any, { [string]: number }) -> string,
}

local CityTerrain = {}

local function slab(
	name: string,
	x0: number,
	y0: number,
	z0: number,
	x1: number,
	y1: number,
	z1: number,
	color: RGB
): Slab
	return {
		Name = name,
		Size = { x1 - x0, y1 - y0, z1 - z0 },
		Pos = { (x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2 },
		Color = color,
	}
end

-- tipo de célula -> campo de cor do bioma
local BIOME_KEY = { Lot = "Ground" }

local function colorFor(biome: Biome, kind: string, parity: number): RGB
	local list = biome[BIOME_KEY[kind] or kind]
	if type(list[1]) == "table" then
		return list[parity % #list + 1]
	end
	return list
end

-- Junta células iguais (mesmo tipo, altura e cor do xadrez) em retângulos.
local function cityGround(out: { Slab }, grid: Grid, biome: Biome, cfg: any)
	local w, d, size = grid.Width, grid.Depth, cfg.CellSize
	local keys: { string } = {}
	local parity: { number } = {}
	for z = 0, d - 1 do
		for x = 0, w - 1 do
			local i = z * w + x + 1
			local kind = grid.Kind[i]
			local n = cfg.Checker[kind]
			-- zonas do fim (jogador gigante): quadrados maiores (menos peças, mesmo visual na escala dele)
			if n and grid.Zone[i] >= cfg.BigCheckerZone then
				n *= 2
			end
			local p = if n then (x // n + z // n) % 2 else 0
			parity[i] = p
			keys[i] = if kind == "Sea" then "" else `{kind}|{grid.Height[i]}|{p}`
		end
	end
	local done: { boolean } = {}
	for z = 0, d - 1 do
		for x = 0, w - 1 do
			local i = z * w + x + 1
			if not done[i] and keys[i] ~= "" then
				local key = keys[i]
				local x1 = x
				while x1 + 1 < w and not done[z * w + x1 + 2] and keys[z * w + x1 + 2] == key do
					x1 += 1
				end
				local z1 = z
				local grow = true
				while grow and z1 + 1 < d do
					for xx = x, x1 do
						local j = (z1 + 1) * w + xx + 1
						if done[j] or keys[j] ~= key then
							grow = false
							break
						end
					end
					if grow then
						z1 += 1
					end
				end
				for zz = z, z1 do
					for xx = x, x1 do
						done[zz * w + xx + 1] = true
					end
				end
				local kind = grid.Kind[i]
				local s = slab(
					kind,
					(x - w / 2) * size,
					0,
					(z - d / 2) * size,
					(x1 + 1 - w / 2) * size,
					grid.Height[i],
					(z1 + 1 - d / 2) * size,
					colorFor(biome, kind, parity[i])
				)
				if kind == "Water" then
					s.Material = "Water"
				end
				table.insert(out, s)
			end
		end
	end
end

-- Faixas brancas tracejadas no meio das ruas retas (fora dos cruzamentos) e as marcas da pista.
local function lines(out: { Slab }, grid: Grid, biome: Biome, cfg: any)
	local w, d, size = grid.Width, grid.Depth, cfg.CellSize
	local function kindAt(x: number, z: number): string?
		if x < 0 or z < 0 or x >= w or z >= d then
			return nil
		end
		return grid.Kind[z * w + x + 1]
	end
	local function isRoad(x: number, z: number): boolean
		return kindAt(x, z) == "Road"
	end
	local color = biome.RoadLine
	local top, roadTop = cfg.LineTop, cfg.Heights.Road
	local every = math.max(1, cfg.LineEvery // size)
	-- rua que corre em X: a faixa fica na borda entre duas linhas de rua, com rua dos dois lados e
	-- não-rua acima e abaixo da largura da rua (assim não entra em cruzamento)
	for z = 1, d - 1 do
		for x = 0, w - 1, every do
			local up, down = 0, 0
			while isRoad(x, z - 1 - up) do
				up += 1
			end
			while isRoad(x, z + down) do
				down += 1
			end
			local straight = up >= 2 and up == down and up <= 5
			-- no meio da rua entre duas áreas fica a barreira: sem faixa ali (piscava embaixo dela)
			local sameZone = grid.Zone[(z - 1) * w + x + 1] == grid.Zone[z * w + x + 1]
			if
				straight
				and sameZone
				and isRoad(x + 1, z)
				and isRoad(x + 1, z - 1)
				and isRoad(x - 1, z)
				and isRoad(x - 1, z - 1)
			then
				local cx, cz = (x + 0.5 - w / 2) * size, (z - d / 2) * size
				local half = math.min(cfg.LineDash, size) / 2
				table.insert(out, slab("Line", cx - half, roadTop, cz - 0.4, cx + half, top, cz + 0.4, color))
			end
		end
	end
	for x = 1, w - 1 do
		for z = 0, d - 1, every do
			local left, right = 0, 0
			while isRoad(x - 1 - left, z) do
				left += 1
			end
			while isRoad(x + right, z) do
				right += 1
			end
			local straight = left >= 2 and left == right and left <= 5
			local sameZone = grid.Zone[z * w + x] == grid.Zone[z * w + x + 1]
			if
				straight
				and sameZone
				and isRoad(x, z + 1)
				and isRoad(x - 1, z + 1)
				and isRoad(x, z - 1)
				and isRoad(x - 1, z - 1)
			then
				local cx, cz = (x - w / 2) * size, (z + 0.5 - d / 2) * size
				local half = math.min(cfg.LineDash, size) / 2
				table.insert(out, slab("Line", cx - 0.4, roadTop, cz - half, cx + 0.4, top, cz + half, color))
			end
		end
	end
	-- pista: faixa central tracejada no comprimento (as pistas da planta correm em Z)
	local runwayTop = cfg.Heights.Runway
	for x = 0, w - 1 do
		for z = 0, d - 1, 2 do
			if kindAt(x, z) == "Runway" and kindAt(x - 1, z) == "Runway" and kindAt(x + 1, z) == "Runway" then
				local runLeft = 0
				while kindAt(x - 1 - runLeft, z) == "Runway" do
					runLeft += 1
				end
				local runRight = 0
				while kindAt(x + 1 + runRight, z) == "Runway" do
					runRight += 1
				end
				if runLeft == runRight and kindAt(x, z + 1) == "Runway" then
					local cx, cz = (x + 0.5 - w / 2) * size, (z + 1 - d / 2) * size
					table.insert(out, slab("Line", cx - 0.6, runwayTop, cz - 3, cx + 0.6, top, cz + 3, color))
				end
			end
		end
	end
end

-- Retângulos (em células) que cobrem as células com a mesma chave (chave nil = fora).
local function greedy(w: number, d: number, keyOf: (number, number) -> string?): { { any } }
	local keys: { string | false } = {}
	for z = 0, d - 1 do
		for x = 0, w - 1 do
			keys[z * w + x + 1] = keyOf(x, z) or false
		end
	end
	local done: { boolean } = {}
	local rects = {}
	for z = 0, d - 1 do
		for x = 0, w - 1 do
			local i = z * w + x + 1
			local key = keys[i]
			if key and not done[i] then
				local x1 = x
				while x1 + 1 < w and not done[z * w + x1 + 2] and keys[z * w + x1 + 2] == key do
					x1 += 1
				end
				local z1 = z
				local grow = true
				while grow and z1 + 1 < d do
					for xx = x, x1 do
						local j = (z1 + 1) * w + xx + 1
						if done[j] or keys[j] ~= key then
							grow = false
							break
						end
					end
					if grow then
						z1 += 1
					end
				end
				for zz = z, z1 do
					for xx = x, x1 do
						done[zz * w + xx + 1] = true
					end
				end
				table.insert(rects, { x, z, x1 + 1, z1 + 1, key })
			end
		end
	end
	return rects
end

-- Distância (em células, contando diagonais) de cada célula de mar até a terra, até `limit`.
local function seaDistance(grid: Grid, limit: number): { number }
	local w, d = grid.Width, grid.Depth
	local dist: { number } = {}
	local queue = {}
	for i = 1, w * d do
		if grid.Kind[i] ~= "Sea" then
			dist[i] = 0
			table.insert(queue, i)
		else
			dist[i] = math.huge
		end
	end
	local head = 1
	while head <= #queue do
		local i = queue[head]
		head += 1
		if dist[i] >= limit then
			continue
		end
		local x, z = (i - 1) % w, (i - 1) // w
		for dx = -1, 1 do
			for dz = -1, 1 do
				local nx, nz = x + dx, z + dz
				if nx >= 0 and nz >= 0 and nx < w and nz < d then
					local j = nz * w + nx + 1
					if dist[j] > dist[i] + 1 then
						dist[j] = dist[i] + 1
						table.insert(queue, j)
					end
				end
			end
		end
	end
	return dist
end

-- Terra embaixo de toda célula de terra (aparece como beirada entre o chão e a água).
local function base(out: { Slab }, grid: Grid, biome: Biome, cfg: any)
	local w, d, size = grid.Width, grid.Depth, cfg.CellSize
	local check = cfg.BaseCheckCells
	-- xadrez só na beirada da costa (o resto fica escondido embaixo do chão: um bloco só)
	local rects = greedy(w, d, function(x, z)
		local i = z * w + x + 1
		if grid.Kind[i] == "Sea" then
			return nil
		end
		local coastal = false
		for dx = -1, 1 do
			for dz = -1, 1 do
				local nx, nz = x + dx, z + dz
				if nx >= 0 and nz >= 0 and nx < w and nz < d and grid.Kind[nz * w + nx + 1] == "Sea" then
					coastal = true
				end
			end
		end
		return if coastal then tostring((x // check + z // check) % 2) else "0"
	end)
	for _, r in rects do
		local color = biome.Base[if r[5] == "1" then 2 else 1]
		table.insert(
			out,
			slab(
				"Base",
				(r[1] - w / 2) * size,
				-cfg.BaseDepth,
				(r[2] - d / 2) * size,
				(r[3] - w / 2) * size,
				0,
				(r[4] - d / 2) * size,
				color
			)
		)
	end
end

-- Mar dentro da grade: raso (claro) perto da terra, fundo (escuro) longe; espuma colada na costa.
local function innerSea(out: { Slab }, grid: Grid, biome: Biome, cfg: any)
	local w, d, size = grid.Width, grid.Depth, cfg.CellSize
	local top = biome.SeaLevel
	local dist = seaDistance(grid, cfg.ShallowCells + 1)
	local material = if biome.Border == "IceSea" then "Ice" else "Water"
	local rects = greedy(w, d, function(x, z)
		local i = z * w + x + 1
		if grid.Kind[i] ~= "Sea" then
			return nil
		end
		return if dist[i] <= cfg.ShallowCells then "Shallow" else "Deep"
	end)
	for _, r in rects do
		local color = if r[5] == "Shallow" then biome.Sea[1] else biome.Sea[2]
		local x0, z0 = (r[1] - w / 2) * size, (r[2] - d / 2) * size
		local x1, z1 = (r[3] - w / 2) * size, (r[4] - d / 2) * size
		local water = slab("Sea", x0, -cfg.BaseDepth, z0, x1, top, z1, color)
		water.Material = material
		table.insert(out, water)
	end
	-- espuma (ou borda de gelo quebrado): faixa fina por cima da água, colada na costa
	local foam = greedy(w, d, function(x, z)
		local i = z * w + x + 1
		return if grid.Kind[i] == "Sea" and dist[i] == 1 then "Foam" else nil
	end)
	for _, r in foam do
		local x0, z0 = (r[1] - w / 2) * size, (r[2] - d / 2) * size
		local x1, z1 = (r[3] - w / 2) * size, (r[4] - d / 2) * size
		table.insert(out, slab("Foam", x0, top, z0, x1, top + cfg.FoamHeight, z1, biome.Foam))
	end
end

-- Mar fora da grade até o horizonte: peças de no máximo MaxPart studs (limite do Roblox: 2048 por lado),
-- em faixas em volta da grade, até SeaSize de distância. Só se encostam.
local function outerSea(out: { Slab }, hx: number, hz: number, biome: Biome, cfg: any)
	local top, reach, tile = biome.SeaLevel, cfg.SeaSize, cfg.SeaTile
	local y0 = top - cfg.OuterSeaDepth
	local material = if biome.Border == "IceSea" then "Ice" else "Water"
	local color = biome.Sea[2]
	-- cortes em X e Z: bordas da grade e passos de `tile` para fora
	local function cuts(half: number): { number }
		local list = { -half, half }
		local d = half
		while d < half + reach do
			d = math.min(d + tile, half + reach)
			table.insert(list, d)
			table.insert(list, 1, -d)
		end
		-- a grade em si também em pedaços (se for maior que uma peça)
		local inner = {}
		local n = math.ceil(2 * half / tile)
		for k = 1, n - 1 do
			table.insert(inner, -half + k * 2 * half / n)
		end
		for _, v in inner do
			table.insert(list, v)
		end
		table.sort(list)
		return list
	end
	local xs, zs = cuts(hx), cuts(hz)
	for i = 1, #xs - 1 do
		for j = 1, #zs - 1 do
			local x0, x1, z0, z1 = xs[i], xs[i + 1], zs[j], zs[j + 1]
			local inside = x0 >= -hx - 0.01 and x1 <= hx + 0.01 and z0 >= -hz - 0.01 and z1 <= hz + 0.01
			if not inside then
				local p = slab("Sea", x0, y0, z0, x1, top, z1, color)
				p.Material = material
				table.insert(out, p)
			end
		end
	end
end

type Circle = { X: number, Z: number, R: number }

-- Lugar livre (círculos não se encostam) fora da área [-hx, hx] x [-hz, hz] (+ folga), até `far` dela.
local function freeSpot(
	rng: Rng,
	used: { Circle },
	hx: number,
	hz: number,
	near: number,
	far: number,
	radius: number
): (number?, number?)
	for _ = 1, 40 do
		local x = (rng:next() * 2 - 1) * (hx + far)
		local z = (rng:next() * 2 - 1) * (hz + far)
		local outside = math.abs(x) - radius > hx + near or math.abs(z) - radius > hz + near
		if outside then
			local ok = true
			for _, c in used do
				if (c.X - x) ^ 2 + (c.Z - z) ^ 2 < (c.R + radius) ^ 2 then
					ok = false
					break
				end
			end
			if ok then
				table.insert(used, { X = x, Z = z, R = radius })
				return x, z
			end
		end
	end
	return nil, nil
end

local function footprintRadius(templates: { [string]: Template }, name: string): number
	local f = templates[name].Footprint
	return math.sqrt(f[1] ^ 2 + f[2] ^ 2) / 2 + 1
end

local function addDecor(decor: { Decor }, rng: Rng, name: string, x: number, y: number, z: number)
	table.insert(decor, {
		Template = name,
		X = x,
		Y = y,
		Z = z,
		Rotation = rng:int(0, 3) * 90,
		Variant = rng:int(1, 1000000),
	})
end

-- Ilhotas: um bloco de areia (ou neve) saindo da água e um gramado em cima, com árvores.
local function islets(
	result: Result,
	rng: Rng,
	biome: Biome,
	templates: { [string]: Template },
	used: { Circle },
	cfg: any
)
	local hx, hz = result.Half[1], result.Half[2]
	local top = biome.SeaLevel
	for _ = 1, cfg.Islets do
		local size = cfg.IsletSize[1] + rng:next() * (cfg.IsletSize[2] - cfg.IsletSize[1])
		local x, z = freeSpot(rng, used, hx, hz, cfg.IsletNear, cfg.IsletFar, size * 0.86)
		if x == nil or z == nil then
			continue
		end
		local sx, sz = size * (0.8 + rng:next() * 0.4), size * (0.8 + rng:next() * 0.4)
		local beach = slab("Islet", x - sx / 2, top, z - sz / 2, x + sx / 2, top + 1, z + sz / 2, biome.Sand[1])
		table.insert(result.Slabs, beach)
		local gx, gz = sx * 0.62, sz * 0.62
		table.insert(
			result.Slabs,
			slab("Islet", x - gx / 2, top + 1, z - gz / 2, x + gx / 2, top + 2, z + gz / 2, biome.Ground[1])
		)
		-- árvores numa grade dentro do gramado
		local step = 14
		local nx, nz = math.max(1, math.floor(gx / step)), math.max(1, math.floor(gz / step))
		for i = 0, nx - 1 do
			for j = 0, nz - 1 do
				if rng:next() < 0.7 then
					local name = rng:weighted(biome.MarginDecor)
					local f = templates[name].Footprint
					if math.max(f[1], f[2]) <= step - 1 then
						local px = x - gx / 2 + (i + 0.5) * gx / nx
						local pz = z - gz / 2 + (j + 0.5) * gz / nz
						addDecor(result.Decor, rng, name, px, top + 2, pz)
					end
				end
			end
		end
	end
end

-- Barcos, pedras ou icebergs boiando no mar em volta.
local function seaDecor(
	result: Result,
	rng: Rng,
	biome: Biome,
	templates: { [string]: Template },
	used: { Circle },
	cfg: any
)
	local hx, hz = result.Half[1], result.Half[2]
	for _ = 1, cfg.SeaDecorCount do
		local name = rng:weighted(biome.SeaDecor)
		local radius = footprintRadius(templates, name)
		local x, z = freeSpot(rng, used, hx, hz, cfg.SeaDecorNear, cfg.IsletFar, radius)
		if x and z then
			addDecor(result.Decor, rng, name, x, biome.SeaLevel, z)
		end
	end
end

-- Pedras e barcos no mar de dentro da grade, longe da costa (fora do alcance do jogador).
local function innerSeaDecor(
	result: Result,
	grid: Grid,
	rng: Rng,
	biome: Biome,
	templates: { [string]: Template },
	used: { Circle },
	cfg: any
)
	local w, d, size = grid.Width, grid.Depth, cfg.CellSize
	local dist = seaDistance(grid, 100)
	local spacing = cfg.InnerDecorSpacing
	for z = spacing // 2, d - 1, spacing do
		for x = spacing // 2, w - 1, spacing do
			local i = z * w + x + 1
			if grid.Kind[i] == "Sea" and dist[i] >= cfg.InnerDecorMinCells and rng:next() < cfg.InnerDecorChance then
				local name = rng:weighted(biome.SeaDecor)
				local radius = footprintRadius(templates, name)
				-- todo o modelo em cima de mar a mais de 2 células da terra
				local reach = math.ceil(radius / size)
				local jitter = spacing * 0.3
				if dist[i] - reach - math.ceil(jitter) >= 2 then
					-- fora da grade certinha (não fica enfileirado)
					local jx, jz = (rng:next() * 2 - 1) * jitter, (rng:next() * 2 - 1) * jitter
					local wx, wz = (x + 0.5 + jx - w / 2) * size, (z + 0.5 + jz - d / 2) * size
					local free = true
					for _, c in used do
						if (c.X - wx) ^ 2 + (c.Z - wz) ^ 2 < (c.R + radius) ^ 2 then
							free = false
							break
						end
					end
					if free then
						table.insert(used, { X = wx, Z = wz, R = radius })
						addDecor(result.Decor, rng, name, wx, biome.SeaLevel, wz)
					end
				end
			end
		end
	end
end

-- Cadeia de montanhas no horizonte: blocos empilhados, cada um menor, com o topo de neve (ou mais claro).
local function mountains(result: Result, rng: Rng, biome: Biome, used: { Circle }, cfg: any)
	local hx, hz = result.Half[1], result.Half[2]
	local top = biome.SeaLevel
	for _ = 1, cfg.Mountains do
		local width = cfg.MountainSize[1] + rng:next() * (cfg.MountainSize[2] - cfg.MountainSize[1])
		local x, z = freeSpot(rng, used, hx, hz, cfg.MountainNear, cfg.MountainFar, width * 0.72)
		if x == nil or z == nil then
			continue
		end
		local levels = rng:int(3, 5)
		local height = width * (0.35 + rng:next() * 0.25)
		local y = top
		local colors = biome.Mountain
		for level = 1, levels do
			local f = 1 - (level - 1) / levels * 0.8
			local sx, sz = width * f, width * f * (0.75 + rng:next() * 0.2)
			local h = height / levels
			local color = if level == levels then biome.MountainTop else colors[(level - 1) % #colors + 1]
			table.insert(
				result.Slabs,
				slab("Mountain", x - sx / 2, y, z - sz / 2, x + sx / 2, y + h, z + sz / 2, color)
			)
			y += h
		end
	end
end

function CityTerrain.generate(grid: Grid, biome: Biome, rng: Rng, cfg: any, templates: { [string]: Template }): Result
	local size = cfg.CellSize
	local hx, hz = grid.Width * size / 2, grid.Depth * size / 2
	local result: Result = { Slabs = {}, Decor = {}, Half = { hx, hz } }
	local out = result.Slabs
	cityGround(out, grid, biome, cfg)
	lines(out, grid, biome, cfg)
	base(out, grid, biome, cfg)
	innerSea(out, grid, biome, cfg)
	outerSea(out, hx, hz, biome, cfg)
	local used: { Circle } = {}
	innerSeaDecor(result, grid, rng, biome, templates, used, cfg)
	mountains(result, rng, biome, used, cfg)
	islets(result, rng, biome, templates, used, cfg)
	seaDecor(result, rng, biome, templates, used, cfg)
	return result
end

return CityTerrain
