--!strict
-- Compra de upgrades. O cliente só pede; o servidor confere moedas, nível e aplica.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Upgrades = require(Shared.Logic.Upgrades)
local UpgradeConfig = require(Shared.Config.UpgradeConfig)
local Remotes = require(Shared.Remotes)

local PlayerData = require(script.Parent.PlayerData)
local GrowthService = require(script.Parent.GrowthService)

local UpgradeService = {}

function UpgradeService.init()
	Remotes.func(Remotes.Names.Functions.BuyUpgrade).OnServerInvoke = function(player: Player, id: unknown)
		if type(id) ~= "string" then
			return false
		end
		local upgrade = Upgrades.find(UpgradeConfig, id)
		local entry = PlayerData.get(player)
		if upgrade == nil or entry == nil then
			return false
		end
		local level = entry.Upgrades[id] or 0
		local ok, cost = Upgrades.canBuy(upgrade, level, entry.Coins)
		if not ok or not PlayerData.spend(player, cost) then
			return false
		end
		PlayerData.setUpgrade(player, id, level + 1)
		GrowthService.apply(player)
		return true
	end
end

return UpgradeService
