--!strict
-- Vida das construções numa run (pura). Uma construção só é destruída UMA vez, por quem deu o golpe final,
-- mesmo com 4 jogadores acertando ao mesmo tempo: o segundo golpe numa construção já destruída não conta.

local StructureHealth = {}

export type State = { Hp: { [number]: number }, Dead: { [number]: boolean } }

function StructureHealth.new(): State
	return { Hp = {}, Dead = {} }
end

-- Aplica dano. Devolve true só no golpe que destrói (uma vez por construção).
function StructureHealth.hit(state: State, id: number, damage: number, maxHp: number): boolean
	if state.Dead[id] or damage <= 0 then
		return false
	end
	local hp = (state.Hp[id] or maxHp) - damage
	if hp <= 1e-6 then
		state.Dead[id] = true
		state.Hp[id] = 0
		return true
	end
	state.Hp[id] = hp
	return false
end

-- Marca como destruída por fora (comer antigo, coleta automática, run salva).
function StructureHealth.kill(state: State, id: number): boolean
	if state.Dead[id] then
		return false
	end
	state.Dead[id] = true
	state.Hp[id] = 0
	return true
end

-- Fração de vida (1 = inteira).
function StructureHealth.fraction(state: State, id: number, maxHp: number): number
	if state.Dead[id] then
		return 0
	end
	return math.clamp((state.Hp[id] or maxHp) / maxHp, 0, 1)
end

return StructureHealth
