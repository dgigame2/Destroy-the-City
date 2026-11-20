--!strict
-- "Ingresso" da partida no DataStore (compartilhado entre o lobby e o lugar Run da mesma experiência).
-- O lobby grava: mapa, dificuldade e membros da party; o servidor da partida lê pelo RunId do teleporte
-- (o cliente não escolhe mapa nem membros). Não guarda progresso: toda partida é nova e o registro é
-- apagado no fim.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")

local STORE_NAME = "EatCity_Runs_v1"

export type Record = {
	Id: string,
	Map: string,
	Difficulty: string,
	Members: { number },
	Names: { string },
	CreatedAt: number,
	UpdatedAt: number,
	Temporary: boolean?, -- partida de teste do Studio: nunca é salva
}

local RunStore = {}

local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[RunStore] DataStore unavailable:", result)
	end
end

function RunStore.new(map: string, difficulty: string, members: { number }, names: { string }): Record
	local now = os.time()
	return {
		Id = HttpService:GenerateGUID(false),
		Map = map,
		Difficulty = difficulty,
		Members = members,
		Names = names,
		CreatedAt = now,
		UpdatedAt = now,
	}
end

-- Confere o que veio do DataStore (dados antigos ou corrompidos não quebram o servidor).
local function valid(saved: any): Record?
	if type(saved) ~= "table" or type(saved.Id) ~= "string" or type(saved.Map) ~= "string" then
		return nil
	end
	if type(saved.Difficulty) ~= "string" or type(saved.Members) ~= "table" then
		return nil
	end
	saved.Names = if type(saved.Names) == "table" then saved.Names else {}
	saved.CreatedAt = tonumber(saved.CreatedAt) or os.time()
	saved.UpdatedAt = tonumber(saved.UpdatedAt) or os.time()
	return saved :: Record
end

function RunStore.get(id: string): Record?
	if store == nil then
		return nil
	end
	local ok, saved = pcall(function()
		return (store :: DataStore):GetAsync(id)
	end)
	if not ok then
		warn("[RunStore] failed to load run", id, saved)
		return nil
	end
	return valid(saved)
end

function RunStore.save(record: Record): boolean
	if store == nil or record.Temporary then
		return false
	end
	record.UpdatedAt = os.time()
	local ok, err = pcall(function()
		(store :: DataStore):SetAsync(record.Id, record)
	end)
	if not ok then
		warn("[RunStore] failed to save run", record.Id, err)
	end
	return ok
end

function RunStore.remove(id: string)
	if store == nil then
		return
	end
	local ok, err = pcall(function()
		(store :: DataStore):RemoveAsync(id)
	end)
	if not ok then
		warn("[RunStore] failed to remove run", id, err)
	end
end

return RunStore
