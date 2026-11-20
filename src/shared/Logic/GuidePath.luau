--!strict
-- Caminho das setas que levam até a área nova (puro, testável no Lune). Tudo no plano X/Z.

local GuidePath = {}

export type Point = { number } -- {x, z}
export type Box = { X: number, Z: number, HalfX: number, HalfZ: number } -- barreira alinhada aos eixos

-- Ponto da caixa mais perto de (x, z).
function GuidePath.closestOnBox(x: number, z: number, box: Box): Point
	return {
		math.clamp(x, box.X - box.HalfX, box.X + box.HalfX),
		math.clamp(z, box.Z - box.HalfZ, box.Z + box.HalfZ),
	}
end

-- A passagem mais perto do jogador entre todas as barreiras da área.
function GuidePath.nearestGate(x: number, z: number, boxes: { Box }): Point?
	local best, bestDistance = nil, math.huge
	for _, box in boxes do
		local p = GuidePath.closestOnBox(x, z, box)
		local d = (p[1] - x) ^ 2 + (p[2] - z) ^ 2
		if d < bestDistance then
			best, bestDistance = p, d
		end
	end
	return best
end

-- O segmento (ax, az) -> (bx, bz) atravessa a caixa? (método das faixas; a caixa ganha `pad` de folga)
local function segmentHitsBox(ax: number, az: number, bx: number, bz: number, box: Box, pad: number): boolean
	local t0, t1 = 0, 1
	for _, axis in { { ax, bx - ax, box.X, box.HalfX + pad }, { az, bz - az, box.Z, box.HalfZ + pad } } do
		local origin, delta, center, half = axis[1], axis[2], axis[3], axis[4]
		local lo, hi = center - half, center + half
		if math.abs(delta) < 1e-9 then
			if origin < lo or origin > hi then
				return false
			end
		else
			local ta, tb = (lo - origin) / delta, (hi - origin) / delta
			if ta > tb then
				ta, tb = tb, ta
			end
			t0, t1 = math.max(t0, ta), math.min(t1, tb)
			if t0 > t1 then
				return false
			end
		end
	end
	return true
end

-- Já entrou na área nova? Do jogador até o meio da área (`finish`) não cruza mais nenhuma barreira dela.
function GuidePath.inside(x: number, z: number, finish: Point, boxes: { Box }): boolean
	for _, box in boxes do
		if segmentHitsBox(x, z, finish[1], finish[2], box, 0.5) then
			return false
		end
	end
	return true
end

function GuidePath.length(points: { Point }): number
	local total = 0
	for i = 1, #points - 1 do
		total += math.sqrt((points[i + 1][1] - points[i][1]) ^ 2 + (points[i + 1][2] - points[i][2]) ^ 2)
	end
	return total
end

export type Arrow = { X: number, Z: number, DirX: number, DirZ: number }

-- Setas a cada `spacing` ao longo do caminho, deslocadas por `phase` (0..spacing): com a fase subindo
-- no tempo, as setas "andam" para frente. No máximo `max` setas.
function GuidePath.arrows(points: { Point }, spacing: number, phase: number, max: number): { Arrow }
	local result: { Arrow } = {}
	local distance = phase % spacing
	local walked = 0
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local dx, dz = b[1] - a[1], b[2] - a[2]
		local len = math.sqrt(dx * dx + dz * dz)
		if len > 0 then
			while distance <= walked + len and #result < max do
				local t = (distance - walked) / len
				table.insert(result, { X = a[1] + dx * t, Z = a[2] + dz * t, DirX = dx / len, DirZ = dz / len })
				distance += spacing
			end
		end
		walked += len
	end
	return result
end

return GuidePath
