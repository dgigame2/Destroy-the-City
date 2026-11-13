--!strict
-- Loop do servidor que faz cada jogador na partida comer construções e jogadores menores ao redor.
-- Toda validação acontece aqui (o cliente só mostra os efeitos).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Growth = require(Shared.Logic.Growth)
local Buffs = require(Shared.Logic.Buffs)
local GrowthConfig = require(Shared.Config.GrowthConfig)
local TierConfig = require(Shared.Config.TierConfig)
local GemConfig = require(Shared.Config.GemConfig)
local RoundConfig = require(Shared.Config.RoundConfig)
local Remotes = require(Shared.Remotes)

local PlayerData = require(script.Parent.PlayerData)
local GrowthService = require(script.Parent.GrowthService)
local MapService = require(script.Parent.MapService)

local EatService = {}

local enabled = false
local random = Random.new()

function EatService.setEnabled(value: boolean)
	enabled = value
end

function EatService.inMatch(player: Player): boolean
	return player:GetAttribute("InMatch") == true
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	if character == nil then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Construção (Model direto dentro de Buildings) dona da peça.
local function buildingOf(part: BasePart, buildings: Folder): Model?
	local current: Instance? = part
	while current and current.Parent ~= buildings do
		current = current.Parent
	end
	return current :: Model?
end

local function eatBuildings(player: Player, root: BasePart, buildings: Folder, params: OverlapParams)
	local scale = GrowthService.scale(player)
	local radius = Growth.eatRadius(scale, GrowthService.multiplier(player, "Magnet") - 1, GrowthConfig)
	local growthMultiplier = GrowthService.multiplier(player, "Growth")
	local coinBonus = GrowthService.multiplier(player, "Coins") - 1

	local seen: { [Model]: boolean } = {}
	local eatenCount = 0
	-- A "boca" fica perto do chão, onde estão as construções.
	local center = Vector3.new(root.Position.X, math.max(radius * 0.5, 2), root.Position.Z)
	for _, part in Workspace:GetPartBoundsInRadius(center, radius, params) do
		local model = buildingOf(part, buildings)
		if model == nil or seen[model] or MapService.isEaten(model) then
			continue
		end
		seen[model] = true
		local tierIndex = model:GetAttribute("Tier") :: number
		local tier = TierConfig[tierIndex]
		if tier == nil or not Growth.canEatTier(scale, tier) then
			continue
		end
		local coins = Growth.coinsFromTier(tier, coinBonus)
		local gems = Buffs.gemDrop(GemConfig.DropByTier[tierIndex], random:NextNumber())
		Remotes.event(Remotes.Names.Events.BuildingEaten):FireAllClients(model, player, coins, gems)
		MapService.consume(model)
		PlayerData.addCoins(player, coins)
		if gems > 0 then
			PlayerData.addGems(player, gems)
		end
		GrowthService.addPoints(player, tier.Growth * growthMultiplier)
		eatenCount += 1
		if eatenCount >= RoundConfig.MaxEatsPerTick then
			break
		end
	end
end

local function eatPlayers(player: Player, root: BasePart)
	local scale = GrowthService.scale(player)
	local radius = Growth.eatRadius(scale, GrowthService.multiplier(player, "Magnet") - 1, GrowthConfig)
	for _, other in Players:GetPlayers() do
		if other == player or not EatService.inMatch(other) then
			continue
		end
		local otherRoot = rootOf(other)
		if otherRoot == nil then
			continue
		end
		local flat = Vector3.new(otherRoot.Position.X - root.Position.X, 0, otherRoot.Position.Z - root.Position.Z)
		if flat.Magnitude <= radius and Growth.canEatPlayer(scale, GrowthService.scale(other), GrowthConfig) then
			local victimData = PlayerData.get(other)
			if victimData == nil then
				continue
			end
			local gain = Growth.gainFromPlayer(victimData.Points, GrowthConfig)
			Remotes.event(Remotes.Names.Events.PlayerEaten):FireAllClients(player, other)
			GrowthService.setPoints(other, victimData.Points * GrowthService.respawnKeep(other))
			local humanoid = (other.Character :: Model):FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.Health = 0
			end
			GrowthService.addPoints(player, gain)
		end
	end
end

function EatService.start()
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	task.spawn(function()
		while true do
			task.wait(RoundConfig.EatTickSeconds)
			local buildings = MapService.buildingsFolder()
			if not enabled or buildings == nil then
				continue
			end
			params.FilterDescendantsInstances = { buildings }
			for _, player in Players:GetPlayers() do
				local root = if EatService.inMatch(player) then rootOf(player) else nil
				if root then
					eatBuildings(player, root, buildings, params)
					eatPlayers(player, root)
				end
			end
		end
	end)
end

return EatService
