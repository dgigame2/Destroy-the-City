--!strict
-- Converte os pontos escondidos em tamanho real do personagem, velocidade e pulo,
-- e junta os bônus de upgrades, classe equipada e boosts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Growth = require(Shared.Logic.Growth)
local Upgrades = require(Shared.Logic.Upgrades)
local Buffs = require(Shared.Logic.Buffs)
local GrowthConfig = require(Shared.Config.GrowthConfig)
local TierConfig = require(Shared.Config.TierConfig)
local UpgradeConfig = require(Shared.Config.UpgradeConfig)
local ClassConfig = require(Shared.Config.ClassConfig)
local MovementConfig = require(Shared.Config.MovementConfig)

local PlayerData = require(script.Parent.PlayerData)

-- Qual boost temporário afeta cada atributo.
local BOOST_FOR_STAT: { [string]: string } = { Coins = "Cash", Growth = "Growth" }

local GrowthService = {}

local appliedScale: { [Player]: number } = {}

function GrowthService.equippedClass(player: Player): ClassConfig.ClassInfo?
	local entry = PlayerData.get(player)
	local id = entry and entry.Equipped.Class
	if entry == nil or id == nil or not entry.Owned[id] then
		return nil
	end
	for _, class in ClassConfig do
		if class.Id == id then
			return class
		end
	end
	return nil
end

-- Multiplicador final de um atributo: Speed, Magnet, Growth ou Coins.
function GrowthService.multiplier(player: Player, stat: string): number
	local entry = PlayerData.get(player)
	if entry == nil then
		return 1
	end
	local upgrade = Upgrades.find(UpgradeConfig, stat)
	local upgradeBonus = if upgrade then Upgrades.bonus(upgrade, entry.Upgrades[stat] or 0) else 0
	local class = GrowthService.equippedClass(player)
	local classBonus = if class then class.Buffs[stat] or 0 else 0
	local boost = BOOST_FOR_STAT[stat]
	local boostActive = boost ~= nil and Buffs.boostActive(entry.Boosts[boost], os.time())
	return Buffs.multiplier({ Upgrade = upgradeBonus, Class = classBonus, BoostActive = boostActive })
end

function GrowthService.respawnKeep(player: Player): number
	local class = GrowthService.equippedClass(player)
	return Buffs.respawnKeep(GrowthConfig.RespawnKeepFraction, class and class.Buffs.RespawnKeep)
end

function GrowthService.startPoints(player: Player): number
	local class = GrowthService.equippedClass(player)
	return if class then class.Buffs.StartPoints or 0 else 0
end

function GrowthService.scale(player: Player): number
	local entry = PlayerData.get(player)
	return Growth.scaleFromPoints(if entry then entry.Points else 0, GrowthConfig)
end

-- Aplica tamanho e movimento ao personagem atual. force = reescala mesmo com mudança pequena.
function GrowthService.apply(player: Player, force: boolean?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if character == nil or humanoid == nil then
		return
	end
	local scale = GrowthService.scale(player)
	local last = appliedScale[player]
	if force or last == nil or math.abs(scale - last) / last >= GrowthConfig.RescaleStep then
		character:ScaleTo(scale)
		appliedScale[player] = scale
	end
	humanoid.WalkSpeed = MovementConfig.WalkSpeed
		* GrowthService.multiplier(player, "Speed")
		* scale ^ MovementConfig.SpeedScaleExponent
	humanoid.UseJumpPower = true
	humanoid.JumpPower = MovementConfig.JumpPower * scale ^ MovementConfig.JumpScaleExponent

	player:SetAttribute("Scale", scale)
	player:SetAttribute("EdibleTier", Growth.highestEdibleTier(scale, TierConfig))
end

function GrowthService.addPoints(player: Player, amount: number)
	local entry = PlayerData.get(player)
	if entry then
		entry.Points += amount
		GrowthService.apply(player)
	end
end

function GrowthService.setPoints(player: Player, points: number)
	local entry = PlayerData.get(player)
	if entry then
		entry.Points = points
	end
end

-- Novo personagem (spawn): escala sai do zero, então força o ScaleTo.
function GrowthService.onCharacter(player: Player)
	appliedScale[player] = nil
	GrowthService.apply(player, true)
end

function GrowthService.forget(player: Player)
	appliedScale[player] = nil
end

return GrowthService
