--!strict
-- Estado de cada jogador. Pontos de crescimento ficam só aqui (o jogador não vê o número).
-- Salvos na conta (DataStore): gemas, vitórias, runs salvas, itens, equipados, recompensas, roleta e boosts.
-- Dinheiro (Coins), upgrades e pontos são DA RUN: ficam aqui só enquanto a run está aberta e são salvos
-- junto com a run (RunStore), não na conta.
-- O cliente recebe tudo o que precisa mostrar por atributos do Player.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UpgradeConfig = require(Shared.Config.UpgradeConfig)
local EconomyConfig = require(Shared.Config.EconomyConfig)
local RunConfig = require(Shared.Config.RunConfig)
local Runs = require(Shared.Logic.Runs)

local STORE_NAME = "EatCity_PlayerData_v1"
local MAX_RECEIPTS = 50

export type Data = {
	Coins: number,
	Gems: number,
	Upgrades: { [string]: number },
	Owned: { [string]: boolean }, -- itens e classes comprados/ganhos
	Equipped: { [string]: string }, -- Trail, Aura, Class -> id
	Daily: { LastDay: number, Streak: number },
	Weekly: { LastWeek: number },
	Wheel: { LastFree: number, Extra: number },
	Boosts: { [string]: number }, -- "Cash"/"Growth" -> os.time() em que termina
	Receipts: { string }, -- compras com Robux já entregues (evita entregar duas vezes)
	Wins: number, -- cidades comidas inteiras (liberam capítulos e dificuldades)
	SavedRuns: { Runs.Summary }, -- runs salvas desta conta (resumo para a lista do lobby)
	Points: number, -- da run, não vai para a conta
}

local PlayerData = {}

local data: { [Player]: Data } = {}
local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[PlayerData] DataStore unavailable (publish the place and enable Studio API access to save):", result)
	end
end

local function fresh(): Data
	return {
		Coins = EconomyConfig.StartingCoins,
		Gems = 0,
		Upgrades = {},
		Owned = {},
		Equipped = {},
		Daily = { LastDay = -1, Streak = 0 },
		Weekly = { LastWeek = -1 },
		Wheel = { LastFree = 0, Extra = 0 },
		Boosts = {},
		Receipts = {},
		Wins = 0,
		SavedRuns = {},
		Points = 0,
	}
end

-- Copia só campos conhecidos do que veio salvo (dados antigos ou corrompidos não quebram o jogo).
local function merge(entry: Data, saved: any)
	if type(saved) ~= "table" then
		return
	end
	entry.Gems = tonumber(saved.Gems) or entry.Gems
	entry.Wins = math.max(0, math.floor(tonumber(saved.Wins) or 0))
	if type(saved.SavedRuns) == "table" then
		local list: { Runs.Summary } = {}
		for _, run in saved.SavedRuns do
			if
				type(run) == "table"
				and type(run.Id) == "string"
				and type(run.Map) == "string"
				and type(run.Difficulty) == "string"
				and type(run.Members) == "table"
			then
				table.insert(list, {
					Id = run.Id,
					Map = run.Map,
					Difficulty = run.Difficulty,
					Members = run.Members,
					Names = if type(run.Names) == "table" then run.Names else {},
					Progress = tonumber(run.Progress) or 0,
					UpdatedAt = tonumber(run.UpdatedAt) or 0,
				})
			end
		end
		entry.SavedRuns = Runs.clean(list, os.time(), RunConfig.SavedRunDays)
	end
	if type(saved.Owned) == "table" then
		for id, owned in saved.Owned do
			if type(id) == "string" and owned == true then
				entry.Owned[id] = true
			end
		end
	end
	if type(saved.Equipped) == "table" then
		for slot, id in saved.Equipped do
			if type(slot) == "string" and type(id) == "string" then
				entry.Equipped[slot] = id
			end
		end
	end
	if type(saved.Daily) == "table" then
		entry.Daily.LastDay = tonumber(saved.Daily.LastDay) or -1
		entry.Daily.Streak = tonumber(saved.Daily.Streak) or 0
	end
	if type(saved.Weekly) == "table" then
		entry.Weekly.LastWeek = tonumber(saved.Weekly.LastWeek) or -1
	end
	if type(saved.Wheel) == "table" then
		entry.Wheel.LastFree = tonumber(saved.Wheel.LastFree) or 0
		entry.Wheel.Extra = tonumber(saved.Wheel.Extra) or 0
	end
	if type(saved.Boosts) == "table" then
		for kind, untilTime in saved.Boosts do
			if type(kind) == "string" and tonumber(untilTime) then
				entry.Boosts[kind] = tonumber(untilTime) :: number
			end
		end
	end
	if type(saved.Receipts) == "table" then
		for _, receipt in saved.Receipts do
			if type(receipt) == "string" then
				table.insert(entry.Receipts, receipt)
			end
		end
	end
end

-- Publica para o cliente (atributos). Tabelas viram JSON.
function PlayerData.publish(player: Player)
	local entry = data[player]
	if entry == nil then
		return
	end
	player:SetAttribute("Coins", entry.Coins)
	player:SetAttribute("Gems", entry.Gems)
	for _, upgrade in UpgradeConfig do
		player:SetAttribute("Upgrade_" .. upgrade.Id, entry.Upgrades[upgrade.Id] or 0)
	end
	player:SetAttribute("Owned", HttpService:JSONEncode(entry.Owned))
	player:SetAttribute("EquippedTrail", entry.Equipped.Trail or "")
	player:SetAttribute("EquippedAura", entry.Equipped.Aura or "")
	player:SetAttribute("EquippedClass", entry.Equipped.Class or "")
	player:SetAttribute("DailyLastDay", entry.Daily.LastDay)
	player:SetAttribute("DailyStreak", entry.Daily.Streak)
	player:SetAttribute("WeeklyLastWeek", entry.Weekly.LastWeek)
	player:SetAttribute("WheelLastFree", entry.Wheel.LastFree)
	player:SetAttribute("WheelExtra", entry.Wheel.Extra)
	player:SetAttribute("BoostCash", entry.Boosts.Cash or 0)
	player:SetAttribute("BoostGrowth", entry.Boosts.Growth or 0)
	player:SetAttribute("Wins", entry.Wins)
	player:SetAttribute("SavedRuns", HttpService:JSONEncode(entry.SavedRuns))
end

local function load(player: Player): Data
	local entry = fresh()
	if store then
		local ok, saved = pcall(function()
			return (store :: DataStore):GetAsync(tostring(player.UserId))
		end)
		if ok then
			merge(entry, saved)
		else
			warn("[PlayerData] failed to load", player.Name, saved)
		end
	end
	return entry
end

function PlayerData.save(player: Player): boolean
	local entry = data[player]
	if entry == nil or store == nil then
		return false
	end
	local snapshot = table.clone(entry) :: any
	-- dinheiro, upgrades e pontos são da run (salvos no RunStore)
	snapshot.Points = nil
	snapshot.Coins = nil
	snapshot.Upgrades = nil
	local ok, err = pcall(function()
		(store :: DataStore):SetAsync(tostring(player.UserId), snapshot)
	end)
	if not ok then
		warn("[PlayerData] failed to save", player.Name, err)
	end
	return ok
end

function PlayerData.get(player: Player): Data?
	return data[player]
end

function PlayerData.addCoins(player: Player, amount: number)
	local entry = data[player]
	if entry then
		entry.Coins += amount
		player:SetAttribute("Coins", entry.Coins)
	end
end

function PlayerData.spend(player: Player, amount: number): boolean
	local entry = data[player]
	if entry == nil or entry.Coins < amount then
		return false
	end
	entry.Coins -= amount
	player:SetAttribute("Coins", entry.Coins)
	return true
end

function PlayerData.addGems(player: Player, amount: number)
	local entry = data[player]
	if entry then
		entry.Gems += amount
		player:SetAttribute("Gems", entry.Gems)
	end
end

function PlayerData.spendGems(player: Player, amount: number): boolean
	local entry = data[player]
	if entry == nil or entry.Gems < amount then
		return false
	end
	entry.Gems -= amount
	player:SetAttribute("Gems", entry.Gems)
	return true
end

-- Estado da run para este jogador (dinheiro e upgrades vêm da run salva; zera em run nova).
function PlayerData.setRunState(player: Player, coins: number, upgrades: { [string]: number })
	local entry = data[player]
	if entry == nil then
		return
	end
	entry.Coins = coins
	entry.Upgrades = {}
	for _, upgrade in UpgradeConfig do
		local level = tonumber(upgrades[upgrade.Id])
		if level then
			entry.Upgrades[upgrade.Id] = math.clamp(math.floor(level), 0, upgrade.MaxLevel)
		end
	end
	PlayerData.publish(player)
end

function PlayerData.addWin(player: Player)
	local entry = data[player]
	if entry then
		entry.Wins += 1
		player:SetAttribute("Wins", entry.Wins)
	end
end

function PlayerData.upsertRun(player: Player, summary: Runs.Summary)
	local entry = data[player]
	if entry then
		entry.SavedRuns =
			Runs.upsert(entry.SavedRuns, summary, os.time(), RunConfig.SavedRunDays, RunConfig.MaxSavedRuns)
		player:SetAttribute("SavedRuns", HttpService:JSONEncode(entry.SavedRuns))
	end
end

function PlayerData.removeRun(player: Player, id: string)
	local entry = data[player]
	if entry then
		entry.SavedRuns = Runs.remove(entry.SavedRuns, id)
		player:SetAttribute("SavedRuns", HttpService:JSONEncode(entry.SavedRuns))
	end
end

function PlayerData.setUpgrade(player: Player, id: string, level: number)
	local entry = data[player]
	if entry then
		entry.Upgrades[id] = level
		player:SetAttribute("Upgrade_" .. id, level)
	end
end

-- Marca uma compra com Robux como entregue. Retorna false se já tinha sido entregue.
function PlayerData.markReceipt(player: Player, receiptId: string): boolean
	local entry = data[player]
	if entry == nil or table.find(entry.Receipts, receiptId) then
		return false
	end
	table.insert(entry.Receipts, receiptId)
	while #entry.Receipts > MAX_RECEIPTS do
		table.remove(entry.Receipts, 1)
	end
	return true
end

-- Chamado antes de salvar quem está saindo (ou todo mundo, quando o servidor fecha).
-- A run usa para guardar o próprio estado e atualizar a lista de runs salvas antes da conta ser salva.
local beforeSave: (({ Player }) -> ())? = nil

function PlayerData.beforeSave(callback: ({ Player }) -> ())
	beforeSave = callback
end

local function runBeforeSave(players: { Player })
	if beforeSave then
		local ok, err = pcall(beforeSave, players)
		if not ok then
			warn("[PlayerData] beforeSave failed:", err)
		end
	end
end

function PlayerData.init(onReady: (Player) -> ())
	local function added(player: Player)
		local entry = load(player)
		if player.Parent == nil then
			return
		end
		data[player] = entry
		PlayerData.publish(player)
		onReady(player)
	end
	Players.PlayerAdded:Connect(added)
	for _, player in Players:GetPlayers() do
		task.spawn(added, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		runBeforeSave({ player })
		PlayerData.save(player)
		data[player] = nil
	end)
	game:BindToClose(function()
		runBeforeSave(Players:GetPlayers())
		for _, player in Players:GetPlayers() do
			PlayerData.save(player)
		end
	end)
	-- salvamento automático a cada 3 minutos
	task.spawn(function()
		while true do
			task.wait(180)
			for _, player in Players:GetPlayers() do
				PlayerData.save(player)
			end
		end
	end)
end

return PlayerData
