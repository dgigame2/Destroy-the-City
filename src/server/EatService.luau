--!strict
-- Loop do servidor da run: cada jogador come as construções ao redor.
-- A party é cooperativa: não existe comer jogador, e o crescimento de cada mordida vai para TODOS da party
-- (multiplicado pela dificuldade). O dinheiro fica com quem comeu.
-- Toda validação acontece aqui (o cliente só mostra os efeitos).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Growth = require(Shared.Logic.Growth)
local Buffs = require(Shared.Logic.Buffs)
local TierConfig = require(Shared.Config.TierConfig)
local GemConfig = require(Shared.Config.GemConfig)
local EatConfig = require(Shared.Config.EatConfig)
local RunConfig = require(Shared.Config.RunConfig)
local Zones = require(Shared.Logic.Zones)
local Remotes = require(Shared.Remotes)
local EatQuery = require(Shared.EatQuery)

local PlayerData = require(script.Parent.PlayerData)
local GrowthService = require(script.Parent.GrowthService)
local MapService = require(script.Parent.MapService)

local EatService = {}

local enabled = false
local random = Random.new()
local difficultyGrowth = 1
local openZone = 1 -- só come construções desta zona ou das anteriores
local frenzyUntil = 0 -- Workspace:GetServerTimeNow() até quando o frenesi dobra crescimento e dinheiro

function EatService.setEnabled(value: boolean)
	enabled = value
end

-- Multiplicador de crescimento da dificuldade da run.
function EatService.setDifficultyGrowth(value: number)
	difficultyGrowth = value
end

-- Zona mais alta aberta (as construções das zonas depois dela não podem ser comidas).
function EatService.setOpenZone(zone: number)
	openZone = zone
end

-- Frenesi: até `untilTime` tudo rende `RunConfig.FrenzyMultiplier` vezes.
function EatService.setFrenzy(untilTime: number)
	frenzyUntil = untilTime
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

-- Come uma construção: efeito para todos, dinheiro/gemas para quem comeu e crescimento para a party inteira.
local function eatModel(player: Player, model: Model, tierIndex: number)
	local tier = TierConfig[tierIndex]
	local step = (model:GetAttribute("Step") :: number?) or 1
	local coinBonus = GrowthService.multiplier(player, "Coins") - 1
	local frenzy = if Zones.frenzyActive(frenzyUntil, Workspace:GetServerTimeNow())
		then RunConfig.FrenzyMultiplier
		else 1
	local coins = Growth.coinsFromTier(tier, coinBonus) * frenzy
	local gems =
		Buffs.gemDrop(GemConfig.DropByTier[tierIndex], random:NextNumber(), GrowthService.multiplier(player, "Gems"))
	Remotes.event(Remotes.Names.Events.BuildingEaten):FireAllClients(model, player, coins, gems)
	MapService.consume(model)
	PlayerData.addCoins(player, coins)
	if gems > 0 then
		PlayerData.addGems(player, gems)
	end
	-- a party inteira cresce junto (cada um com os próprios bônus de crescimento)
	for _, member in Players:GetPlayers() do
		if EatService.inMatch(member) then
			GrowthService.addPoints(
				member,
				tier.Growth
					* MapService.stepGrowth(step)
					* frenzy
					* difficultyGrowth
					* GrowthService.multiplier(member, "Growth")
			)
		end
	end
end

local function eatBuildings(player: Player, root: BasePart, buildings: Folder, params: OverlapParams)
	local scale = GrowthService.scale(player)
	local radius = GrowthService.eatRadius(player)

	local eatenCount = 0
	-- tudo que o círculo do chão toca, do mais perto para o mais longe
	for _, hit in EatQuery.inReach(root.Position, radius, buildings, params) do
		local model = hit.Model
		if MapService.isEaten(model) then
			continue
		end
		local tierIndex = model:GetAttribute("Tier") :: number
		local zone = (model:GetAttribute("Zone") :: number?) or 1
		local tier = TierConfig[tierIndex]
		if tier == nil or zone > openZone or not Growth.canEatTier(scale, tier) then
			continue
		end
		eatModel(player, model, tierIndex)
		eatenCount += 1
		if eatenCount >= EatConfig.MaxEatsPerTick then
			break
		end
	end
end

-- Coleta automática do fim da área: tudo que sobrou na zona é sugado pela party
-- (cada construção vai para um jogador, em rodízio), com os mesmos prêmios de comer.
-- Devolve false se ninguém da party está em jogo (nada foi coletado).
function EatService.collectAll(models: { Model }): boolean
	local members = {}
	for _, player in Players:GetPlayers() do
		if EatService.inMatch(player) and rootOf(player) then
			table.insert(members, player)
		end
	end
	if #members == 0 then
		return false
	end
	local gap = EatConfig.AutoCollectSeconds / math.max(#models, 1)
	for index, model in models do
		if model.Parent and not MapService.isEaten(model) then
			local tierIndex = model:GetAttribute("Tier") :: number
			if TierConfig[tierIndex] then
				eatModel(members[(index - 1) % #members + 1], model, tierIndex)
			end
		end
		task.wait(gap)
	end
	return true
end

function EatService.start()
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	task.spawn(function()
		while true do
			task.wait(EatConfig.EatTickSeconds)
			local buildings = MapService.buildingsFolder()
			if not enabled or buildings == nil then
				continue
			end
			params.FilterDescendantsInstances = { buildings }
			for _, player in Players:GetPlayers() do
				local root = if EatService.inMatch(player) then rootOf(player) else nil
				if root then
					eatBuildings(player, root, buildings, params)
				end
			end
		end
	end)
end

return EatService
