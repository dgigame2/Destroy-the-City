--!strict
-- Formas da mira dos desastres (pura, testada no Lune em tests/AimShapes.spec.luau). Tudo no plano X/Z.
-- O cliente (AimVisual) só posiciona peças nos pontos que estas funções devolvem.

local AimShapes = {}

export type Dash = { X: number, Z: number, Yaw: number, Length: number }
export type Arrow = { X: number, Z: number, Fade: number }

-- Traços do círculo tracejado: `count` traços iguais, girados por `phase` (radianos). Cada traço fica no meio
-- do seu trecho, alinhado com a tangente (Yaw = direção do traço no plano, em radianos, a partir de +X).
function AimShapes.dashes(cx: number, cz: number, radius: number, count: number, fill: number, phase: number): { Dash }
	local list = {}
	local step = 2 * math.pi / count
	local length = 2 * radius * math.sin(step * fill / 2) -- corda do arco do traço
	for i = 0, count - 1 do
		local a = phase + i * step
		table.insert(list, {
			X = cx + math.cos(a) * radius,
			Z = cz + math.sin(a) * radius,
			Yaw = a + math.pi / 2,
			Length = length,
		})
	end
	return list
end

-- Setas ao longo do caminho (sx, sz) -> direção (dx, dz) unitária, até `length`. As setas andam para a frente
-- com `phase` (0 a 1 = um espaçamento). Começam fora do círculo de largada (`start`) e somem no fim (Fade 0..1).
function AimShapes.arrows(
	sx: number,
	sz: number,
	dx: number,
	dz: number,
	start: number,
	length: number,
	spacing: number,
	phase: number,
	max: number
): { Arrow }
	local list = {}
	if length <= start or spacing <= 0 then
		return list
	end
	local offset = (phase % 1) * spacing
	local d = start + offset
	while d <= length and #list < max do
		local fadeIn = math.clamp((d - start) / spacing, 0, 1)
		local fadeOut = math.clamp((length - d) / spacing, 0, 1)
		table.insert(list, { X = sx + dx * d, Z = sz + dz * d, Fade = math.min(fadeIn, fadeOut) })
		d += spacing
	end
	return list
end

return AimShapes
