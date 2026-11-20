--!strict
-- Loja de gemas (cosméticos), equipar, recompensas diária/semanal e compras com Robux.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rewards = require(Shared.Logic.Rewards)
local RewardConfig = require(Shared.Config.RewardConfig)
local ProductConfig = require(Shared.Config.ProductConfig)
local Remotes = require(Shared.Remotes)

local PlayerData = require(script.Parent.PlayerData)
local Grants = require(script.Parent.Grants)
local CosmeticService = require(script.Parent.CosmeticService)

local StoreService = {}

-- Comprar cosmético com gemas.
local function buy(player: Player, id: unknown): (boolean, string)
	if type(id) ~= "string" then
		return false, "Invalid"
	end
	local entry = PlayerData.get(player)
	if entry == nil then
		return false, "Loading"
	end
	local item = Grants.findItem(id)
	if item == nil then
		return false, "Invalid"
	end
	if entry.Owned[id] then
		return false, "Owned"
	end
	if not PlayerData.spendGems(player, item.Price) then
		return false, "Not enough Gems"
	end
	Grants.giveItem(player, item)
	CosmeticService.refresh(player)
	return true, "OK"
end

-- Equipar (ou tirar, se já estiver equipado) um cosmético que o jogador tem.
local function equip(player: Player, id: unknown): boolean
	local entry = PlayerData.get(player)
	if entry == nil or type(id) ~= "string" or not entry.Owned[id] then
		return false
	end
	local item = Grants.findItem(id)
	if item == nil then
		return false
	end
	local slot = item.Kind
	entry.Equipped[slot] = if entry.Equipped[slot] == id then nil else id
	PlayerData.publish(player)
	CosmeticService.refresh(player)
	return true
end

local function claimDaily(player: Player): boolean
	local entry = PlayerData.get(player)
	if entry == nil then
		return false
	end
	local today = Rewards.dayIndex(os.time())
	local ok, day = Rewards.daily(entry.Daily.LastDay, entry.Daily.Streak, today, #RewardConfig.Daily)
	if not ok then
		return false
	end
	entry.Daily.LastDay = today
	entry.Daily.Streak = day
	PlayerData.publish(player)
	local reward = RewardConfig.Daily[day]
	Grants.give(player, reward, reward.Icon)
	return true
end

local function claimWeekly(player: Player): boolean
	local entry = PlayerData.get(player)
	if entry == nil then
		return false
	end
	local week = Rewards.weekIndex(os.time())
	if not Rewards.weekly(entry.Weekly.LastWeek, week) then
		return false
	end
	entry.Weekly.LastWeek = week
	PlayerData.publish(player)
	for _, reward in RewardConfig.Weekly do
		Grants.give(player, reward, reward.Icon)
	end
	return true
end

-- Compras com Robux (Developer Products).
local function processReceipt(receipt): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if player == nil or PlayerData.get(player) == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local product = nil
	for _, candidate in ProductConfig do
		if candidate.ProductId ~= 0 and candidate.ProductId == receipt.ProductId then
			product = candidate
		end
	end
	if product == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if PlayerData.markReceipt(player, receipt.PurchaseId) then
		Grants.give(player, product.Grant, product.Icon)
		if not PlayerData.save(player) then
			-- sem salvar, o Roblox tenta de novo mais tarde; o recibo marcado evita entregar duas vezes
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function StoreService.init()
	local functions = Remotes.Names.Functions
	Remotes.func(functions.BuyItem).OnServerInvoke = buy
	Remotes.func(functions.EquipItem).OnServerInvoke = equip
	Remotes.func(functions.ClaimDaily).OnServerInvoke = claimDaily
	Remotes.func(functions.ClaimWeekly).OnServerInvoke = claimWeekly
	MarketplaceService.ProcessReceipt = processReceipt
end

return StoreService
