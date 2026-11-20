--!strict
-- Estado da cidade da partida (puro). O servidor é a única fonte: vida, destruição e progresso.
-- Ids são densos (1..N, cabem em u16). Progresso = valor destruído / valor total (prédio grande vale mais).
-- Cada construção é destruída UMA vez por vida; 4 jogadores batendo juntos somam no máximo a vida dela.
-- A cidade se regenera: construção destruída volta inteira (revive) depois de MatchConfig.RegenSeconds.
-- Mudanças ficam marcadas (Dirty) até o servidor juntar tudo num lote (Logic/Protocol).
-- O cliente usa o mesmo estado como espelho (apply), sem decidir nada.

local CityState = {}

export type Building = { MaxHp: number, Value: number }

export type State = {
	Count: number,
	MaxHp: { number },
	Value: { number },
	Hp: { number },
	Dead: { boolean },
	TotalValue: number,
	DestroyedValue: number,
	DestroyedCount: number,
	Paid: { [number]: boolean }, -- índice do marco -> já comemorado
	Dirty: { [number]: boolean },
}

function CityState.new(buildings: { Building }): State
	local count = #buildings
	assert(count <= 65535, "CityState: mais de 65535 construções")
	local maxHp, value, hp, dead = table.create(count), table.create(count), table.create(count), table.create(count)
	local total = 0
	for i, b in buildings do
		assert(b.MaxHp > 0 and b.Value >= 0, "CityState: construção inválida")
		maxHp[i], value[i], hp[i], dead[i] = b.MaxHp, b.Value, b.MaxHp, false
		total += b.Value
	end
	return {
		Count = count,
		MaxHp = maxHp,
		Value = value,
		Hp = hp,
		Dead = dead,
		TotalValue = total,
		DestroyedValue = 0,
		DestroyedCount = 0,
		Paid = {},
		Dirty = {},
	}
end

local function valid(state: State, id: number): boolean
	return type(id) == "number" and id >= 1 and id <= state.Count and id == math.floor(id)
end

local function kill(state: State, id: number)
	state.Hp[id] = 0
	state.Dead[id] = true
	state.DestroyedValue += state.Value[id]
	state.DestroyedCount += 1
	state.Dirty[id] = true
end

-- A construção volta inteira (regeneração). Devolve false se não estava destruída.
function CityState.revive(state: State, id: number): boolean
	if not valid(state, id) or not state.Dead[id] then
		return false
	end
	state.Dead[id] = false
	state.Hp[id] = state.MaxHp[id]
	state.DestroyedValue -= state.Value[id]
	state.DestroyedCount -= 1
	state.Dirty[id] = true
	return true
end

-- Aplica dano. Devolve (dano que realmente entrou, destruiu agora?).
function CityState.hit(state: State, id: number, damage: number): (number, boolean)
	if not valid(state, id) or state.Dead[id] or not (damage > 0) or damage == math.huge then
		return 0, false
	end
	local before = state.Hp[id]
	if damage >= before - 1e-6 then
		kill(state, id)
		return before, true
	end
	state.Hp[id] = before - damage
	state.Dirty[id] = true
	return damage, false
end

function CityState.fraction(state: State, id: number): number
	if not valid(state, id) then
		return 0
	end
	return state.Hp[id] / state.MaxHp[id]
end

function CityState.progress(state: State): number
	if state.TotalValue <= 0 then
		return if state.DestroyedCount >= state.Count then 1 else 0
	end
	return math.clamp(state.DestroyedValue / state.TotalValue, 0, 1)
end

-- Marcos alcançados AGORA (cada um sai uma vez só). marks em ordem crescente.
function CityState.newMilestones(state: State, marks: { number }): { number }
	local reached = {}
	local p = CityState.progress(state)
	for index, mark in marks do
		if not state.Paid[index] and p >= mark - 1e-9 then
			state.Paid[index] = true
			table.insert(reached, index)
		end
	end
	return reached
end

-- Vida em 1 byte: 0 = destruída; viva fica em 1..levels (nunca 0, mesmo com 0,1% de vida).
function CityState.hpByte(state: State, id: number, levels: number): number
	if state.Dead[id] then
		return 0
	end
	return math.clamp(math.ceil(state.Hp[id] / state.MaxHp[id] * levels), 1, levels)
end

-- Ids mudados desde a última chamada (em ordem) e limpa a lista.
function CityState.takeDirty(state: State): { number }
	local ids = {}
	for id in state.Dirty do
		table.insert(ids, id)
	end
	table.sort(ids)
	table.clear(state.Dirty)
	return ids
end

-- Espelho do cliente: aplica o que o servidor mandou. Devolve (acabou de cair?, acabou de voltar?).
function CityState.apply(state: State, id: number, hpByte: number, levels: number): (boolean, boolean)
	if not valid(state, id) then
		return false, false
	end
	if state.Dead[id] then
		if hpByte > 0 then
			CityState.revive(state, id)
			state.Hp[id] = state.MaxHp[id] * math.clamp(hpByte, 1, levels) / levels
			return false, true
		end
		return false, false
	end
	if hpByte <= 0 then
		kill(state, id)
		return true, false
	end
	state.Hp[id] = state.MaxHp[id] * math.clamp(hpByte, 1, levels) / levels
	return false, false
end

return CityState
