--!strict
-- Entrega prêmios (recompensas, roleta, Robux) e itens. Um lugar só para todas as fontes de prêmio.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Buffs = require(Shared.Logic.Buffs)
local ShopConfig = require(Shared.Config.ShopConfig)
local ClassConfig = require(Shared.Config.ClassConfig)
local WheelConfig = require(Shared.Config.WheelConfig)
local Remotes = require(Shared.Remotes)

local PlayerData = require(script.Parent.PlayerData)

export type Reward = { Kind: string, Amount: number?, Id: string? }

local Grants = {}

function Grants.findItem(id: string): ShopConfig.Item?
	for _, item in ShopConfig do
		if item.Id == id then
			return item
		end
	end
	return nil
end

function Grants.findClass(id: string): ClassConfig.ClassInfo?
	for _, class in ClassConfig do
		if class.Id == id then
			return class
		end
	end
	return nil
end

local function notify(player: Player, text: string, icon: string)
	Remotes.event(Remotes.Names.Events.RewardGranted):FireClient(player, text, icon)
end

-- Ativa um boost (soma tempo se já estiver ativo).
function Grants.applyBoost(player: Player, item: ShopConfig.Item)
	local entry = PlayerData.get(player)
	if entry == nil or item.Boost == nil then
		return
	end
	entry.Boosts[item.Boost] = Buffs.extendBoost(entry.Boosts[item.Boost], os.time(), (item.Minutes or 10) * 60)
	PlayerData.publish(player)
end

-- Dá um item. Repetido (cosmético) vira gemas conforme a raridade.
function Grants.giveItem(player: Player, item: ShopConfig.Item): string
	local entry = PlayerData.get(player)
	if entry == nil then
		return ""
	end
	if item.Kind == "Boost" then
		Grants.applyBoost(player, item)
		return item.Name .. " (" .. (item.Minutes or 10) .. " min)"
	end
	if entry.Owned[item.Id] then
		local gems = WheelConfig.DuplicateGems[item.Rarity] or 25
		PlayerData.addGems(player, gems)
		return item.Name .. " (owned) → " .. gems .. " Gems"
	end
	entry.Owned[item.Id] = true
	-- equipa automaticamente se o espaço estiver vazio
	if entry.Equipped[item.Kind] == nil then
		entry.Equipped[item.Kind] = item.Id
	end
	PlayerData.publish(player)
	return item.Name
end

-- Entrega um prêmio genérico e avisa o jogador. Retorna o texto mostrado.
function Grants.give(player: Player, reward: Reward, icon: string?): string
	local text = ""
	if reward.Kind == "Coins" then
		PlayerData.addCoins(player, reward.Amount or 0)
		text = (reward.Amount or 0) .. " Cash"
	elseif reward.Kind == "Gems" then
		PlayerData.addGems(player, reward.Amount or 0)
		text = (reward.Amount or 0) .. " Gems"
	elseif reward.Kind == "Spin" then
		local entry = PlayerData.get(player)
		if entry then
			entry.Wheel.Extra += reward.Amount or 1
			PlayerData.publish(player)
		end
		text = (reward.Amount or 1) .. " Spin" .. (if (reward.Amount or 1) > 1 then "s" else "")
	elseif reward.Kind == "Item" then
		local item = Grants.findItem(reward.Id or "")
		if item then
			text = Grants.giveItem(player, item)
		end
	end
	if text ~= "" then
		notify(player, "+ " .. text, icon or "🎁")
	end
	return text
end

return Grants
