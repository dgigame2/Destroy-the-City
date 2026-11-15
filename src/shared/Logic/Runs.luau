--!strict
-- Regras das runs (puras, testáveis no Lune): progresso, vitória, recompensa, runs salvas e capítulos.

local Runs = {}

export type Summary = {
	Id: string,
	Map: string,
	Difficulty: string,
	Members: { number }, -- UserIds da party
	Names: { string }, -- nomes para mostrar na lista
	Progress: number, -- 0 a 1 (quanto da cidade já foi comido)
	UpdatedAt: number, -- os.time()
}

-- Quanto da cidade já foi comido (0 a 1).
function Runs.progress(eaten: number, total: number): number
	if total <= 0 then
		return 1
	end
	return math.clamp(eaten / total, 0, 1)
end

function Runs.isVictory(eaten: number, total: number): boolean
	return total > 0 and eaten >= total
end

function Runs.winGems(base: number, rewardMultiplier: number): number
	return math.floor(base * rewardMultiplier + 0.5)
end

function Runs.unlocked(requiredWins: number, wins: number): boolean
	return wins >= requiredWins
end

-- Segundos até a run salva expirar (negativo = já expirou).
function Runs.expiresIn(updatedAt: number, now: number, days: number): number
	return updatedAt + days * 86400 - now
end

function Runs.isExpired(updatedAt: number, now: number, days: number): boolean
	return Runs.expiresIn(updatedAt, now, days) <= 0
end

-- Para carregar uma run salva, todos os membros dela precisam estar presentes.
-- Devolve se pode e quem está faltando.
function Runs.canLoad(members: { number }, present: { number }): (boolean, { number })
	local here: { [number]: boolean } = {}
	for _, id in present do
		here[id] = true
	end
	local missing = {}
	for _, id in members do
		if not here[id] then
			table.insert(missing, id)
		end
	end
	return #missing == 0, missing
end

-- Coloca/atualiza o resumo na lista da conta (mais recente primeiro), tira expirados e limita o tamanho.
function Runs.upsert(list: { Summary }, summary: Summary, now: number, days: number, max: number): { Summary }
	local result: { Summary } = { summary }
	for _, entry in list do
		if entry.Id ~= summary.Id and not Runs.isExpired(entry.UpdatedAt, now, days) then
			table.insert(result, entry)
		end
	end
	table.sort(result, function(a, b)
		return a.UpdatedAt > b.UpdatedAt
	end)
	while #result > max do
		table.remove(result)
	end
	return result
end

function Runs.remove(list: { Summary }, id: string): { Summary }
	local result: { Summary } = {}
	for _, entry in list do
		if entry.Id ~= id then
			table.insert(result, entry)
		end
	end
	return result
end

function Runs.clean(list: { Summary }, now: number, days: number): { Summary }
	local result: { Summary } = {}
	for _, entry in list do
		if not Runs.isExpired(entry.UpdatedAt, now, days) then
			table.insert(result, entry)
		end
	end
	return result
end

-- Construções comidas viram uma lista ordenada de ids (para salvar) e voltam a ser um conjunto.
function Runs.encodeEaten(set: { [number]: boolean }): { number }
	local list = {}
	for id, value in set do
		if value then
			table.insert(list, id)
		end
	end
	table.sort(list)
	return list
end

function Runs.decodeEaten(list: any, total: number): { [number]: boolean }
	local set: { [number]: boolean } = {}
	if type(list) ~= "table" then
		return set
	end
	for _, id in list do
		if type(id) == "number" and id == math.floor(id) and id >= 1 and id <= total then
			set[id] = true
		end
	end
	return set
end

-- "1d 4h", "3h 12m", "45m": tempo até a run salva sumir.
function Runs.formatDuration(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	local days, hours, minutes = s // 86400, (s % 86400) // 3600, (s % 3600) // 60
	if days > 0 then
		return `{days}d {hours}h`
	elseif hours > 0 then
		return `{hours}h {minutes}m`
	end
	return `{minutes}m`
end

return Runs
