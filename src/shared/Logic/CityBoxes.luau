--!strict
-- Caixas de um modelo já colocadas no mundo (posição + giro de 90 em 90 graus), como dados puros.
-- Usado pela prévia (lune run export) e pelos testes de "nada entra em nada" da cidade montada.

local CityBoxes = {}

export type WorldBox = { Min: { number }, Max: { number }, Role: string }

type Box = { Size: { number }, Pos: { number }, Role: string }

-- Giro em Y igual ao CFrame.Angles(0, rotação, 0) do Roblox.
function CityBoxes.place(boxes: { Box }, x: number, y: number, z: number, rotation: number): { WorldBox }
	local rad = math.rad(rotation)
	local c, s = math.floor(math.cos(rad) + 0.5), math.floor(math.sin(rad) + 0.5)
	local result = {}
	for _, b in boxes do
		local px, pz = b.Pos[1], b.Pos[3]
		local wx, wz = x + px * c + pz * s, z - px * s + pz * c
		local sx, sz = b.Size[1], b.Size[3]
		if rotation % 180 ~= 0 then
			sx, sz = sz, sx
		end
		local cy = y + b.Pos[2]
		table.insert(result, {
			Min = { wx - sx / 2, cy - b.Size[2] / 2, wz - sz / 2 },
			Max = { wx + sx / 2, cy + b.Size[2] / 2, wz + sz / 2 },
			Role = b.Role,
		})
	end
	return result
end

-- Duas caixas entram uma na outra (mais que `tolerance` em todos os eixos)?
function CityBoxes.overlaps(a: WorldBox, b: WorldBox, tolerance: number): boolean
	for axis = 1, 3 do
		if a.Max[axis] - tolerance <= b.Min[axis] or b.Max[axis] - tolerance <= a.Min[axis] then
			return false
		end
	end
	return true
end

return CityBoxes
