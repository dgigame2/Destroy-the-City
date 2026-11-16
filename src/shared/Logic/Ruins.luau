--!strict
-- Escombros que ficam no lugar de uma construção derrubada (puro, testável no Lune).
-- A pilha é uma grade de blocos baixos DENTRO do terreno da construção (no máximo Margin do footprint), com
-- alturas sorteadas pela semente e alguns pedaços menores apoiados em cima. Os blocos só se encostam
-- (nunca um dentro do outro) e todos tocam o chão ou o bloco de baixo: nada flutua.
-- Papéis de cor: "Rubble" (concreto), "RubbleDark" (concreto escuro), "RubbleWall" (cor da parede da construção).

local Ruins = {}

export type Box = { Size: { number }, Pos: { number }, Role: string }

type Config = {
	Cell: number,
	MaxCells: number,
	Margin: number,
	HeightByTier: { number },
	MinHeight: number,
	Chunks: number,
	MaxParts: number,
}

local function noise(seed: number, i: number): number
	local h = bit32.bxor(bit32.band(seed * 2654435761, 0xFFFFFFFF), bit32.band(i * 40503, 0xFFFFFFFF))
	h = bit32.band(h * 1103515245 + 12345, 0xFFFFFFFF)
	return (h % 10007) / 10007
end

-- Altura máxima da pilha para o tier (0 = não deixa escombros).
function Ruins.height(tier: number, cfg: Config): number
	local list = cfg.HeightByTier
	return list[math.clamp(tier, 1, #list)] or 0
end

-- Blocos da pilha para um terreno w x d (studs) do tier. Base no chão (Y = 0), centro em (0, 0).
function Ruins.pile(w: number, d: number, tier: number, seed: number, cfg: Config): { Box }
	local boxes: { Box } = {}
	local hmax = Ruins.height(tier, cfg)
	if hmax <= 0 or w <= 0 or d <= 0 then
		return boxes
	end
	local width, depth = w * cfg.Margin, d * cfg.Margin
	local nx = math.clamp(math.floor(width / cfg.Cell + 0.5), 1, cfg.MaxCells)
	local nz = math.clamp(math.floor(depth / cfg.Cell + 0.5), 1, cfg.MaxCells)
	local cw, cd = width / nx, depth / nz
	local roll = 0
	local function nextNoise(): number
		roll += 1
		return noise(seed, roll)
	end
	local cells = {}
	for i = 1, nx do
		for j = 1, nz do
			local h = hmax * (cfg.MinHeight + (1 - cfg.MinHeight) * nextNoise())
			local x = -width / 2 + cw * (i - 0.5)
			local z = -depth / 2 + cd * (j - 0.5)
			local pick = nextNoise()
			local role = if pick < 0.45 then "Rubble" elseif pick < 0.75 then "RubbleWall" else "RubbleDark"
			table.insert(boxes, { Size = { cw, h, cd }, Pos = { x, h / 2, z }, Role = role })
			table.insert(cells, { X = x, Z = z, H = h })
			if #boxes >= cfg.MaxParts then
				return boxes
			end
		end
	end
	-- pedaços menores em cima de alguns blocos (dentro do bloco de baixo, apoiados no topo dele)
	for _, cell in cells do
		if #boxes >= cfg.MaxParts then
			break
		end
		if nextNoise() < cfg.Chunks then
			local sw, sd = cw * 0.5, cd * 0.5
			local ox = (nextNoise() - 0.5) * (cw - sw)
			local oz = (nextNoise() - 0.5) * (cd - sd)
			local h = math.max(hmax * 0.25, 0.3)
			local role = if nextNoise() < 0.5 then "RubbleWall" else "Rubble"
			table.insert(
				boxes,
				{ Size = { sw, h, sd }, Pos = { cell.X + ox, cell.H + h / 2, cell.Z + oz }, Role = role }
			)
		end
	end
	return boxes
end

return Ruins
