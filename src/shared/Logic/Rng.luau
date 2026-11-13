--!strict
-- Gerador pseudoaleatório determinístico (LCG) para gerar mapas iguais em qualquer lugar,
-- inclusive nos testes fora do Roblox.

export type Rng = {
	next: (self: Rng) -> number,
	int: (self: Rng, min: number, max: number) -> number,
	pick: <T>(self: Rng, list: { T }) -> T,
	weighted: (self: Rng, weights: { [string]: number }) -> string,
	_state: number,
}

local MODULUS = 2 ^ 31
local MULTIPLIER = 1103515245
local INCREMENT = 12345

local Rng = {}
Rng.__index = Rng

function Rng.new(seed: number): Rng
	local self = setmetatable({ _state = math.floor(seed) % MODULUS }, Rng)
	return (self :: any) :: Rng
end

-- Número em [0, 1).
function Rng.next(self: Rng): number
	self._state = (MULTIPLIER * self._state + INCREMENT) % MODULUS
	return self._state / MODULUS
end

function Rng.int(self: Rng, min: number, max: number): number
	assert(max >= min, "max deve ser >= min")
	return min + math.floor(self:next() * (max - min + 1))
end

function Rng.pick<T>(self: Rng, list: { T }): T
	assert(#list > 0, "lista vazia")
	return list[self:int(1, #list)]
end

-- Escolhe uma chave com probabilidade proporcional ao peso. Ordem das chaves é estável (ordenada).
function Rng.weighted(self: Rng, weights: { [string]: number }): string
	local keys = {}
	local total = 0
	for key, weight in weights do
		if weight > 0 then
			table.insert(keys, key)
			total += weight
		end
	end
	assert(total > 0, "pesos vazios")
	table.sort(keys)
	local roll = self:next() * total
	for _, key in keys do
		roll -= weights[key]
		if roll < 0 then
			return key
		end
	end
	return keys[#keys]
end

return Rng
