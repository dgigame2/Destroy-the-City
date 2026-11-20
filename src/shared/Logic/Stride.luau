--!strict
-- Ritmo das animações padrão de andar/correr do Roblox para personagens de qualquer tamanho (puro, testável).
-- Mesma mistura do Animate R15 do Roblox: até metade do passo normal só "andar", a partir do passo normal só
-- "correr", e uma mistura no meio. A diferença é que aqui o passo é dividido pelo tamanho do personagem.

local Stride = {}

local WALK_AT = 0.5 -- ritmo em que o Animate R15 usa só a animação de andar
local RUN_AT = 1 -- ritmo em que usa só a de correr
local NEAR_ZERO = 0.0001 -- o Animate nunca zera o peso (evita a animação parar de tocar)

-- Ritmo normalizado: 1 = andando a WalkSpeed padrão no tamanho normal.
function Stride.normalized(speed: number, scale: number, baseWalkSpeed: number): number
	if scale <= 0 or baseWalkSpeed <= 0 then
		return 0
	end
	return math.max(speed, 0) / (baseWalkSpeed * scale)
end

export type Blend = { WalkWeight: number, RunWeight: number, WalkSpeed: number, RunSpeed: number }

function Stride.blend(rate: number): Blend
	local walkWeight, runWeight = NEAR_ZERO, NEAR_ZERO
	if rate <= WALK_AT then
		walkWeight = 1
	elseif rate < RUN_AT then
		local fade = (rate - WALK_AT) / (RUN_AT - WALK_AT)
		walkWeight = math.max(1 - fade, NEAR_ZERO)
		runWeight = math.max(fade, NEAR_ZERO)
	else
		runWeight = 1
	end
	return { WalkWeight = walkWeight, RunWeight = runWeight, WalkSpeed = rate / WALK_AT, RunSpeed = rate / RUN_AT }
end

return Stride
