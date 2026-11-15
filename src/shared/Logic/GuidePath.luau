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
