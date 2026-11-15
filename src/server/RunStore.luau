--!strict
-- Runs salvas no DataStore (compartilhado entre o lobby e o lugar Run da mesma experiência).
-- Uma run guarda: mapa, dificuldade, membros, estado de cada jogador (pontos, dinheiro, upgrades)
-- e quais construções já foram comidas.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CityConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.CityConfig)

local STORE_NAME = "EatCity_Runs_v1"

export type PlayerState = { Points: number, Coins: number, Upgrades: { [string]: number } }

export type Record = {
	Id: string,
	Map: string,
	Difficulty: string,
	Members: { number },
	Names: { string },
	Players: { [string]: PlayerState }, -- chave = tostring(UserId)
	Eaten: { number },
	CreatedAt: number,
	UpdatedAt: number,
	Temporary: boolean?, -- run de teste do Studio: nunca é salva
	Layout: number?, -- versão das cidades (CityConfig.LayoutVersion) quando a run foi salva
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
		Players = {},
		Eaten = {},
		Layout = CityConfig.LayoutVersion,
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
	saved.Players = if type(saved.Players) == "table" then saved.Players else {}
	saved.Eaten = if type(saved.Eaten) == "table" then saved.Eaten else {}
	-- cidade mudou desde que a run foi salva: os ids das construções não batem mais, a run recomeça
	if saved.Layout ~= CityConfig.LayoutVersion then
		saved.Eaten = {}
		saved.Players = {}
		saved.Layout = CityConfig.LayoutVersion
	end
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
