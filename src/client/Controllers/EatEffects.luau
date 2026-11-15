--!strict
-- Efeito de comer: a construção se desmonta bloco por bloco, cada bloco dá um "pulinho"
-- e é sugado para a boca do jogador, encolhendo. Som, tremor e número: Feedback ("Eat").

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AudioConfig = require(Shared.Config.AudioConfig)
local TierConfig = require(Shared.Config.TierConfig)
local Remotes = require(Shared.Remotes)

local Feedback = require(script.Parent.Parent.Feedback)

local localPlayer = Players.LocalPlayer

local MAX_PARTS = 120 -- blocos animados por construção (o resto some direto)
local SPREAD_SECONDS = 0.45 -- tempo entre o primeiro e o último bloco sair
local POP_TIME = 0.12
local FLY_TIME = 0.34

local EatEffects = {}

export type BiteInfo = { Coins: number, Gems: number, Tier: number, Position: Vector3 }
local biteListeners: { (BiteInfo) -> () } = {}
local anyBiteListeners: { (Player) -> () } = {}

-- Mordidas do jogador local (combo, avisos).
function EatEffects.onLocalBite(callback: (BiteInfo) -> ())
	table.insert(biteListeners, callback)
end

-- Mordidas de qualquer jogador (animação de "nhac").
function EatEffects.onAnyBite(callback: (Player) -> ())
	table.insert(anyBiteListeners, callback)
end

local effectsFolder = Instance.new("Folder")
effectsFolder.Name = "EatEffects"
effectsFolder.Parent = Workspace

local combo = 0
local lastBite = 0

-- Emissor de faíscas preso no jogador que está comendo (criado uma vez por personagem).
local function sparkles(root: BasePart): ParticleEmitter
	local existing = root:FindFirstChild("EatSparkles")
	if existing then
		return (existing :: Attachment):FindFirstChildOfClass("ParticleEmitter") :: ParticleEmitter
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "EatSparkles"
	attachment.Parent = root
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(0.25, 0.45)
	emitter.Speed = NumberRange.new(10, 22)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) })
	emitter.LightEmission = 0.8
	emitter.Parent = attachment
	return emitter
end

local function mouthOf(character: Model): BasePart?
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function onPartArrived(part: BasePart, root: BasePart)
	local emitter = sparkles(root)
	emitter.Color = ColorSequence.new(part.Color)
	emitter:Emit(2)
	part:Destroy()
end

local function animatePart(part: BasePart, delayTime: number, root: BasePart, scale: number)
	task.delay(delayTime, function()
		if part.Parent == nil or root.Parent == nil then
			part:Destroy()
			return
		end
		-- 1. pulinho: cresce um pouco e sobe
		local up = part.CFrame + Vector3.new(0, 1.5 + part.Size.Y * 0.2, 0)
		local pop =
			TweenService:Create(part, TweenInfo.new(POP_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				CFrame = up,
				Size = part.Size * 1.15,
			})
		pop:Play()
		pop.Completed:Wait()
		if root.Parent == nil then
			part:Destroy()
			return
		end
		-- 2. sugado para a boca, girando e encolhendo
		local mouth = root.Position + Vector3.new(0, scale * 1.5, 0)
		local spin = CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
		local fly = TweenService:Create(part, TweenInfo.new(FLY_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			CFrame = CFrame.new(mouth) * spin,
			Size = part.Size * 0.08,
			Transparency = 0.2,
		})
		fly:Play()
		fly.Completed:Wait()
		onPartArrived(part, root)
	end)
end

local function punchCamera(strength: number)
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	local base = 70
	camera.FieldOfView = base + strength
	TweenService
		:Create(camera, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FieldOfView = base })
		:Play()
end

local function onBuildingEaten(model: Model?, eater: Player, coins: number, gems: number?)
	if model == nil or eater.Character == nil then
		return
	end
	local root = mouthOf(eater.Character :: Model)
	if root == nil then
		return
	end
	local isLocal = eater == localPlayer
	for _, listener in anyBiteListeners do
		listener(eater)
	end
	local scale = (eater:GetAttribute("Scale") :: number?) or 1
	local tier = (model:GetAttribute("Tier") :: number?) or 1
	local pivot = model:GetPivot()

	local copy = model:Clone()
	-- some na hora do original (o servidor remove logo em seguida)
	model.Parent = nil

	local parts = {}
	for _, d in copy:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
			table.insert(parts, d)
		end
	end
	-- os blocos mais próximos da boca saem primeiro (onda de "sucção")
	table.sort(parts, function(a, b)
		return (a.Position - root.Position).Magnitude < (b.Position - root.Position).Magnitude
	end)
	copy.Parent = effectsFolder
	for index, part in parts do
		if index > MAX_PARTS then
			part:Destroy()
		else
			animatePart(part, (index - 1) / math.max(#parts, 1) * SPREAD_SECONDS, root, scale)
		end
	end
	task.delay(SPREAD_SECONDS + POP_TIME + FLY_TIME + 0.5, function()
		copy:Destroy()
	end)

	if isLocal then
		local now = os.clock()
		combo = if now - lastBite <= AudioConfig.ComboWindowSeconds then combo + 1 else 1
		lastBite = now
		-- som + tremor + número (Config/FeedbackConfig "Eat")
		Feedback.play("Eat", { World = pivot.Position + Vector3.new(0, 4, 0), Amount = coins })
		if tier >= 3 then
			punchCamera(math.min(2 + tier, 9))
		end
		for _, listener in biteListeners do
			listener({ Coins = coins, Gems = gems or 0, Tier = tier, Position = pivot.Position })
		end
	end
end

function EatEffects.currentCombo(): number
	if os.clock() - lastBite > AudioConfig.ComboWindowSeconds then
		return 0
	end
	return combo
end

function EatEffects.tierName(tier: number): string
	local info = TierConfig[tier]
	return if info then info.DisplayName else ""
end

-- Brilho em volta do jogador nos momentos grandes (o som vem do Feedback de cada ação).
function EatEffects.playTierUp()
	local character = localPlayer.Character
	local root = character and mouthOf(character)
	if root then
		sparkles(root):Emit(40)
	end
end

function EatEffects.init()
	Remotes.event(Remotes.Names.Events.BuildingEaten).OnClientEvent:Connect(onBuildingEaten)
end

return EatEffects
