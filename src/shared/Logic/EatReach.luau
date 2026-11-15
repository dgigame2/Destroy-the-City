--!strict
-- Alcance da "boca": uma peça está no alcance quando o ponto dela mais perto do jogador,
-- medido só na horizontal (X/Z), fica a no máximo `radius` studs. É exatamente o círculo
-- desenhado no chão (EatIndicator), então tudo que o círculo toca é comido.
-- Matemática pura (sem APIs do Roblox): recebe números e devolve números.

local EatReach = {}

export type Box = {
	-- centro da peça
	X: number,
	Y: number,
	Z: number,
	-- eixos da peça (vetores unitários: direita, cima, trás)
	RX: number,
	RY: number,
	RZ: number,
	UX: number,
	UY: number,
	UZ: number,
	BX: number,
	BY: number,
	BZ: number,
	-- metade do tamanho
	HX: number,
	HY: number,
	HZ: number,
}

local function clamp(value: number, half: number): number
	return math.clamp(value, -half, half)
end

-- Distância horizontal do jogador (px, pz) até o ponto mais perto da caixa.
-- O jogador é tratado como uma linha vertical: compara na altura do centro da peça.
function EatReach.horizontalDistance(px: number, pz: number, box: Box): number
	local dx, dy, dz = px - box.X, 0, pz - box.Z
	local u = clamp(dx * box.RX + dy * box.RY + dz * box.RZ, box.HX)
	local v = clamp(dx * box.UX + dy * box.UY + dz * box.UZ, box.HY)
	local w = clamp(dx * box.BX + dy * box.BY + dz * box.BZ, box.HZ)
	local cx = box.X + u * box.RX + v * box.UX + w * box.BX
	local cz = box.Z + u * box.RZ + v * box.UZ + w * box.BZ
	return math.sqrt((px - cx) ^ 2 + (pz - cz) ^ 2)
end

function EatReach.inReach(px: number, pz: number, box: Box, radius: number): boolean
	return EatReach.horizontalDistance(px, pz, box) <= radius
end

-- Caixa sem rotação (atalho para testes e peças alinhadas).
function EatReach.axisBox(x: number, y: number, z: number, sx: number, sy: number, sz: number): Box
	return {
		X = x,
		Y = y,
		Z = z,
		RX = 1,
		RY = 0,
		RZ = 0,
		UX = 0,
		UY = 1,
		UZ = 0,
		BX = 0,
		BY = 0,
		BZ = 1,
		HX = sx / 2,
		HY = sy / 2,
		HZ = sz / 2,
	}
end

return EatReach
