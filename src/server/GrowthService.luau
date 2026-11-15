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
local Place = require(Shared.Place)

local PlayerData = require(script.Parent.PlayerData)

-- Qual boost temporário afeta cada atributo.
local BOOST_FOR_STAT: { [string]: string } = { Coins = "Cash", Growth = "Growth" }

local GrowthService = {}

local appliedScale: { [Player]: number } = {}
-- dificuldade da run: alcance da boca e velocidade (modos difíceis são mais lentos de varrer)
local difficultyReach, difficultySpeed = 1, 1
local loadingAppearance: { [Player]: boolean } = {}

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

-- Multiplicador final de um atributo: Speed, Magnet, Growth, Coins ou Gems.
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

function GrowthService.startPoints(player: Player): number
	local class = GrowthService.equippedClass(player)
	return if class then class.Buffs.StartPoints or 0 else 0
end

function GrowthService.scale(player: Player): number
	local entry = PlayerData.get(player)
	return Growth.scaleFromPoints(if entry then entry.Points else 0, GrowthConfig)
end

local function scaledCFrame(cf: CFrame, factor: number): CFrame
	return cf.Rotation + cf.Position * factor
end

-- Aumenta/diminui o personagem SEM mexer na posição dele.
-- Model:ScaleTo no servidor reescreve o CFrame das peças com a posição que o servidor conhece, que chega
-- atrasada (o personagem é simulado no cliente): o jogador voltava alguns studs a cada mordida.
-- Aqui só mudam tamanhos, juntas, attachments e a altura do quadril; a peça raiz fica onde está.
local function rescale(character: Model, humanoid: Humanoid, factor: number)
	for _, item in character:GetDescendants() do
		if item:IsA("BasePart") then
			item.Size *= factor
		elseif item:IsA("JointInstance") then -- Motor6D das juntas e Welds dos acessórios
			item.C0 = scaledCFrame(item.C0, factor)
			item.C1 = scaledCFrame(item.C1, factor)
		elseif item:IsA("Attachment") then
			item.Position *= factor
		elseif item:IsA("SpecialMesh") and item.MeshType == Enum.MeshType.FileMesh then
			item.Scale *= factor -- malha de acessório antigo: o tamanho dela não segue o da peça
		end
	end
	humanoid.HipHeight *= factor
end

-- Aplica tamanho e movimento ao personagem atual. force = reescala mesmo com mudança pequena.
function GrowthService.apply(player: Player, force: boolean?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if character == nil or humanoid == nil then
		return
	end
	local scale = GrowthService.scale(player)
	local current = appliedScale[player] or 1 -- personagem novo nasce na escala 1
	-- enquanto roupas e acessórios chegam, espera: o onCharacter reescala tudo junto quando terminar
	local changed = (force and scale ~= current) or math.abs(scale - current) / current >= GrowthConfig.RescaleStep
	if changed and not loadingAppearance[player] then
		-- a escala automática do Roblox desfaria os tamanhos novos
		humanoid.AutomaticScalingEnabled = false
		rescale(character, humanoid, scale / current)
		appliedScale[player] = scale
	end
	humanoid.WalkSpeed = MovementConfig.WalkSpeed
		* difficultySpeed
		* GrowthService.multiplier(player, "Speed")
		* scale ^ MovementConfig.SpeedScaleExponent
	humanoid.UseJumpPower = true
	humanoid.JumpPower = if Place.isRun() then MovementConfig.RunJumpPower else MovementConfig.LobbyJumpPower

	player:SetAttribute("Scale", scale)
	player:SetAttribute("EdibleTier", Growth.highestEdibleTier(scale, TierConfig))
	-- alcance da boca (studs), para o círculo no chão do cliente
	player:SetAttribute("EatRadius", GrowthService.eatRadius(player))
end

-- Alcance da boca (studs): tamanho, upgrade de ímã e dificuldade.
function GrowthService.eatRadius(player: Player): number
	local scale = GrowthService.scale(player)
	return Growth.eatRadius(scale, GrowthService.multiplier(player, "Magnet") - 1, GrowthConfig) * difficultyReach
end

-- Dificuldade da run (DifficultyConfig): Reach multiplica o alcance da boca, Speed a velocidade.
function GrowthService.setDifficulty(reach: number, speed: number)
	difficultyReach, difficultySpeed = reach, speed
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

-- Novo personagem (spawn): nasce na escala 1. Espera a aparência (roupas e acessórios) carregar, para eles
-- crescerem junto.
function GrowthService.onCharacter(player: Player)
	appliedScale[player] = nil
	if not player:HasAppearanceLoaded() then
		loadingAppearance[player] = true
		local loaded = false
		local connection = player.CharacterAppearanceLoaded:Once(function()
			loaded = true
		end)
		local started = os.clock()
		while not loaded and os.clock() - started < 5 do
			task.wait(0.1)
		end
		connection:Disconnect()
		loadingAppearance[player] = nil
	end
	GrowthService.apply(player, true)
end

function GrowthService.forget(player: Player)
	appliedScale[player] = nil
	loadingAppearance[player] = nil
end

return GrowthService
