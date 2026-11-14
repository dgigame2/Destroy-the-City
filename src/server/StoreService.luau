--!strict
-- Loja de gemas (itens e classes), equipar, recompensas diária/semanal, roleta e compras com Robux.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rewards = require(Shared.Logic.Rewards)
local Wheel = require(Shared.Logic.Wheel)
local WheelConfig = require(Shared.Config.WheelConfig)
local RewardConfig = require(Shared.Config.RewardConfig)
local ProductConfig = require(Shared.Config.ProductConfig)
local Remotes = require(Shared.Remotes)

local PlayerData = require(script.Parent.PlayerData)
local Grants = require(script.Parent.Grants)
local GrowthService = require(script.Parent.GrowthService)
local CosmeticService = require(script.Parent.CosmeticService)

local StoreService = {}

local random = Random.new()
local rng = {
	next = function()
		return random:NextNumber()
	end,
}
local spinning: { [Player]: boolean } = {}

-- Comprar item ou classe com gemas.
local function buy(player: Player, id: unknown): (boolean, string)
	if type(id) ~= "string" then
		return false, "Invalid"
	end
	local entry = PlayerData.get(player)
	if entry == nil then
		return false, "Loading"
	end
	local item = Grants.findItem(id)
	local class = Grants.findClass(id)
	local price = if item then item.Price elseif class then class.Price else nil
	if price == nil then
		return false, "Invalid"
	end
	if (class or (item and item.Kind ~= "Boost")) and entry.Owned[id] then
		return false, "Owned"
	end
	if not PlayerData.spendGems(player, price) then
		return false, "Not enough Gems"
	end
	if item then
		Grants.giveItem(player, item)
	elseif class then
		entry.Owned[id] = true
		entry.Equipped.Class = id
		PlayerData.publish(player)
		GrowthService.apply(player)
	end
	CosmeticService.refresh(player)
	return true, "OK"
end

-- Equipar (ou tirar, se já estiver equipado) item ou classe que o jogador tem.
local function equip(player: Player, id: unknown): boolean
	local entry = PlayerData.get(player)
	if entry == nil or type(id) ~= "string" or not entry.Owned[id] then
		return false
	end
	local item = Grants.findItem(id)
	local slot = if item and item.Kind ~= "Boost" then item.Kind elseif Grants.findClass(id) then "Class" else nil
	if slot == nil then
		return false
	end
	entry.Equipped[slot] = if entry.Equipped[slot] == id then nil else id
	PlayerData.publish(player)
	GrowthService.apply(player)
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

-- Gira a roleta. payment: "Free" (24h), "Extra" (giros guardados) ou "Gems".
-- Retorna o índice sorteado; o prêmio é entregue quando a animação termina.
local function spin(player: Player, payment: unknown): number?
	local entry = PlayerData.get(player)
	if entry == nil or spinning[player] then
		return nil
	end
	local now = os.time()
	if payment == "Free" then
		if Wheel.freeSpinIn(entry.Wheel.LastFree, now, WheelConfig.FreeCooldownSeconds) > 0 then
			return nil
		end
		entry.Wheel.LastFree = now
	elseif payment == "Extra" then
		if entry.Wheel.Extra <= 0 then
			return nil
		end
		entry.Wheel.Extra -= 1
	elseif payment == "Gems" then
		if not PlayerData.spendGems(player, WheelConfig.GemCost) then
			return nil
		end
	else
		return nil
	end
	PlayerData.publish(player)
	local index = Wheel.pick(WheelConfig.Segments, rng)
	spinning[player] = true
	Remotes.event(Remotes.Names.Events.WheelSpun):FireAllClients(player, index)
	task.delay(WheelConfig.SpinSeconds, function()
		spinning[player] = nil
		if player.Parent then
			local segment = WheelConfig.Segments[index]
			Grants.give(player, segment.Reward, segment.Icon)
			CosmeticService.refresh(player)
		end
	end)
	return index
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
	Remotes.func(functions.SpinWheel).OnServerInvoke = spin
	MarketplaceService.ProcessReceipt = processReceipt
	Players.PlayerRemoving:Connect(function(player)
		spinning[player] = nil
	end)
end

return StoreService
