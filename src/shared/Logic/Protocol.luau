--!strict
-- Mensagens compactas da cidade em `buffer` (puro). Nada de Instance pela rede: só ids e 1 byte de vida.
--   Delta    (lote a cada MatchConfig.DeltaInterval): u8 tipo=1 | u32 seq | u16 n | n × (u16 id, u8 hp)
--   Snapshot (entrada/reconexão/seq perdido):         u8 tipo=2 | u32 seq | u16 count | bitset das destruídas
--            | u16 m | m × (u16 id, u8 hp) das danificadas vivas
-- hp: 0 = destruída, 1..levels = vida em degraus (CityState.hpByte).
-- decode devolve nil para mensagem mal formada (tamanho errado, tipo errado).

local CityState = if script then require(script.Parent.CityState) else require("./CityState")

local Protocol = {}

Protocol.Delta = 1
Protocol.Snapshot = 2

export type Entry = { Id: number, Hp: number }
export type Delta = { Seq: number, Entries: { Entry } }
export type Snapshot = { Seq: number, Count: number, Dead: { boolean }, Damaged: { Entry } }

function Protocol.encodeDelta(seq: number, state: CityState.State, ids: { number }, levels: number): buffer
	local n = #ids
	assert(n <= 65535, "Protocol: lote grande demais")
	local b = buffer.create(7 + n * 3)
	buffer.writeu8(b, 0, Protocol.Delta)
	buffer.writeu32(b, 1, seq)
	buffer.writeu16(b, 5, n)
	for i, id in ids do
		local o = 7 + (i - 1) * 3
		buffer.writeu16(b, o, id)
		buffer.writeu8(b, o + 2, CityState.hpByte(state, id, levels))
	end
	return b
end

function Protocol.decodeDelta(b: any): Delta?
	if typeof(b) ~= "buffer" or buffer.len(b) < 7 or buffer.readu8(b, 0) ~= Protocol.Delta then
		return nil
	end
	local n = buffer.readu16(b, 5)
	if buffer.len(b) ~= 7 + n * 3 then
		return nil
	end
	local entries = table.create(n)
	for i = 1, n do
		local o = 7 + (i - 1) * 3
		entries[i] = { Id = buffer.readu16(b, o), Hp = buffer.readu8(b, o + 2) }
	end
	return { Seq = buffer.readu32(b, 1), Entries = entries }
end

function Protocol.encodeSnapshot(seq: number, state: CityState.State, levels: number): buffer
	local count = state.Count
	local bits = math.ceil(count / 8)
	local damaged = {}
	for id = 1, count do
		if not state.Dead[id] and state.Hp[id] < state.MaxHp[id] then
			table.insert(damaged, id)
		end
	end
	local m = #damaged
	local b = buffer.create(7 + bits + 2 + m * 3)
	buffer.writeu8(b, 0, Protocol.Snapshot)
	buffer.writeu32(b, 1, seq)
	buffer.writeu16(b, 5, count)
	for id = 1, count do
		if state.Dead[id] then
			local byte = 7 + (id - 1) // 8
			buffer.writeu8(b, byte, bit32.bor(buffer.readu8(b, byte), bit32.lshift(1, (id - 1) % 8)))
		end
	end
	local o = 7 + bits
	buffer.writeu16(b, o, m)
	for i, id in damaged do
		local p = o + 2 + (i - 1) * 3
		buffer.writeu16(b, p, id)
		buffer.writeu8(b, p + 2, CityState.hpByte(state, id, levels))
	end
	return b
end

function Protocol.decodeSnapshot(b: any): Snapshot?
	if typeof(b) ~= "buffer" or buffer.len(b) < 9 or buffer.readu8(b, 0) ~= Protocol.Snapshot then
		return nil
	end
	local count = buffer.readu16(b, 5)
	local bits = math.ceil(count / 8)
	local o = 7 + bits
	if buffer.len(b) < o + 2 then
		return nil
	end
	local m = buffer.readu16(b, o)
	if buffer.len(b) ~= o + 2 + m * 3 then
		return nil
	end
	local dead = table.create(count, false)
	for id = 1, count do
		dead[id] = bit32.btest(buffer.readu8(b, 7 + (id - 1) // 8), bit32.lshift(1, (id - 1) % 8))
	end
	local damaged = table.create(m)
	for i = 1, m do
		local p = o + 2 + (i - 1) * 3
		damaged[i] = { Id = buffer.readu16(b, p), Hp = buffer.readu8(b, p + 2) }
	end
	return { Seq = buffer.readu32(b, 1), Count = count, Dead = dead, Damaged = damaged }
end

return Protocol
