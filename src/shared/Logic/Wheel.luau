--!strict
-- Roleta: sorteio ponderado, probabilidades e ângulo final da animação. Funções puras.

export type Segment = { Weight: number }
type Rng = { next: (any) -> number }

local Wheel = {}

function Wheel.totalWeight(segments: { Segment }): number
	local total = 0
	for _, segment in segments do
		assert(segment.Weight > 0, "peso deve ser > 0")
		total += segment.Weight
	end
	return total
end

-- Probabilidade de cada fatia (soma 1).
function Wheel.probabilities(segments: { Segment }): { number }
	local total = Wheel.totalWeight(segments)
	local result = {}
	for index, segment in segments do
		result[index] = segment.Weight / total
	end
	return result
end

function Wheel.pick(segments: { Segment }, rng: Rng): number
	local roll = rng:next() * Wheel.totalWeight(segments)
	for index, segment in segments do
		roll -= segment.Weight
		if roll < 0 then
			return index
		end
	end
	return #segments
end

-- Ângulo (graus) para a roda parar com o centro da fatia `index` embaixo do ponteiro (topo).
-- As fatias são desenhadas em sentido horário a partir do topo; a roda gira no sentido horário.
-- `turns` voltas completas antes de parar; `jitter` (0..1) desloca dentro da fatia sem sair dela.
function Wheel.targetAngle(index: number, count: number, turns: number, jitter: number): number
	local slice = 360 / count
	local center = (index - 0.5) * slice
	local offset = (math.clamp(jitter, 0, 1) - 0.5) * slice * 0.7
	return turns * 360 + (360 - center) + offset
end

-- Fatia que fica sob o ponteiro depois de girar `angle` graus (inverso de targetAngle).
function Wheel.indexAtAngle(angle: number, count: number): number
	local slice = 360 / count
	local pointer = (360 - (angle % 360)) % 360
	return math.floor(pointer / slice) + 1
end

function Wheel.freeSpinIn(lastFree: number, now: number, cooldown: number): number
	return math.max(0, lastFree + cooldown - now)
end

return Wheel
