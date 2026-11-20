--!strict
-- Entrega prêmios (recompensas diárias/semanais, Robux) e itens. Um lugar só para todas as fontes de prêmio.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ShopConfig = require(Shared.Config.ShopConfig)
local EconomyConfig = require(Shared.Config.EconomyConfig)
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

local function notify(player: Player, text: string, icon: string)
	Remotes.event(Remotes.Names.Events.RewardGranted):FireClient(player, text, icon)
end

-- Dá um item. Repetido (cosmético) vira gemas conforme a raridade.
function Grants.giveItem(player: Player, item: ShopConfig.Item): string
	local entry = PlayerData.get(player)
	if entry == nil then
		return ""
	end
	if entry.Owned[item.Id] then
		local gems = EconomyConfig.DuplicateGems[item.Rarity] or 25
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
	if reward.Kind == "Gems" then
		PlayerData.addGems(player, reward.Amount or 0)
		text = (reward.Amount or 0) .. " Gems"
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
