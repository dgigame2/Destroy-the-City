--!strict
-- Votação de mapas. Funções puras.

-- Qualquer objeto com :int e :pick (ver Logic/Rng).
type Rng = {
	int: (any, number, number) -> number,
	pick: (any, { string }) -> string,
}

local Voting = {}

-- Sorteia `count` mapas diferentes, evitando repetir o mapa atual quando houver opções suficientes.
function Voting.pickOptions(mapIds: { string }, count: number, currentId: string?, rng: Rng): { string }
	local pool = {}
	for _, id in mapIds do
		if id ~= currentId or #mapIds <= count then
			table.insert(pool, id)
		end
	end
	local options = {}
	while #options < count and #pool > 0 do
		local index = rng:int(1, #pool)
		table.insert(options, table.remove(pool, index) :: string)
	end
	return options
end

-- Conta votos (voto inválido é ignorado). Empate ou nenhum voto: sorteia entre os mais votados.
function Voting.winner(options: { string }, votes: { [any]: string }, rng: Rng): string
	assert(#options > 0, "sem opções")
	local counts = {}
	for _, id in options do
		counts[id] = 0
	end
	for _, choice in votes do
		if counts[choice] ~= nil then
			counts[choice] += 1
		end
	end
	local best = -1
	local tied = {}
	for _, id in options do
		if counts[id] > best then
			best = counts[id]
			tied = { id }
		elseif counts[id] == best then
			table.insert(tied, id)
		end
	end
	return rng:pick(tied)
end

function Voting.counts(options: { string }, votes: { [any]: string }): { [string]: number }
	local counts = {}
	for _, id in options do
		counts[id] = 0
	end
	for _, choice in votes do
		if counts[choice] ~= nil then
			counts[choice] += 1
		end
	end
	return counts
end

return Voting
