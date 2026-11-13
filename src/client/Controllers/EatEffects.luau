--!strict
-- Efeito de comer: a construção se desmonta bloco por bloco, cada bloco dá um "pulinho"
-- e é sugado para a boca do jogador, encolhendo, com um pop sonoro que fica mais agudo no combo.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AudioConfig = require(Shared.Config.AudioConfig)
local TierConfig = require(Shared.Config.TierConfig)
local Remotes = require(Shared.Remotes)

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
local popsThisSecond = 0
local popWindowStart = 0

local function playSound(spec: { Id: string, Volume: number }, parent: Instance, pitch: number?)
	local sound = Instance.new("Sound")
	sound.SoundId = spec.Id
	sound.Volume = spec.Volume
	sound.PlaybackSpeed = pitch or 1
	sound.RollOffMaxDistance = 600
	sound.Parent = parent
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	task.delay(4, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

local function comboPitch(): number
	return math.min(1 + combo * AudioConfig.ComboPitchStep, AudioConfig.ComboPitchMax)
end

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

local function onPartArrived(part: BasePart, root: BasePart, isLocal: boolean)
	local emitter = sparkles(root)
	emitter.Color = ColorSequence.new(part.Color)
	emitter:Emit(2)
	if isLocal then
		local now = os.clock()
		if now - popWindowStart >= 1 then
			popWindowStart = now
			popsThisSecond = 0
		end
		if popsThisSecond < AudioConfig.MaxPopsPerSecond then
			popsThisSecond += 1
			playSound(AudioConfig.Pop, root, comboPitch() + math.random() * 0.08)
		end
	end
	part:Destroy()
end

local function animatePart(part: BasePart, delayTime: number, root: BasePart, scale: number, isLocal: boolean)
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
		onPartArrived(part, root, isLocal)
	end)
end

local function floatingCoins(position: Vector3, amount: number)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = position
	anchor.Parent = effectsFolder
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(160, 60)
	billboard.AlwaysOnTop = true
	billboard.Parent = anchor
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = "+" .. amount .. " 💵"
	label.TextColor3 = Color3.fromRGB(125, 255, 138)
	label.Parent = billboard
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(11, 18, 48)
	stroke.Parent = label
	TweenService:Create(anchor, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = position + Vector3.new(0, 8, 0),
	}):Play()
	TweenService:Create(label, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
	}):Play()
	TweenService:Create(stroke, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Transparency = 1,
	}):Play()
	task.delay(1, function()
		anchor:Destroy()
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
			animatePart(part, (index - 1) / math.max(#parts, 1) * SPREAD_SECONDS, root, scale, isLocal)
		end
	end
	task.delay(SPREAD_SECONDS + POP_TIME + FLY_TIME + 0.5, function()
		copy:Destroy()
	end)

	if isLocal then
		local now = os.clock()
		combo = if now - lastBite <= AudioConfig.ComboWindowSeconds then combo + 1 else 1
		lastBite = now
		playSound(AudioConfig.Bite, root, 0.9 + math.min(combo, 10) * 0.03)
		playSound(AudioConfig.Coin, root, comboPitch())
		floatingCoins(pivot.Position + Vector3.new(0, 4, 0), coins)
		if tier >= 3 then
			punchCamera(math.min(2 + tier, 9))
		end
		for _, listener in biteListeners do
			listener({ Coins = coins, Gems = gems or 0, Tier = tier, Position = pivot.Position })
		end
	end
end

-- Construção voltando: aparece em sequência, de baixo para cima.
local function onBuildingRegenerated(model: Model?)
	if model == nil then
		return
	end
	local parts = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		end
	end
	table.sort(parts, function(a, b)
		return a.Position.Y < b.Position.Y
	end)
	for index, part in parts do
		local final = part.Transparency
		part.Transparency = 1
		task.delay(index * 0.015, function()
			TweenService:Create(part, TweenInfo.new(0.25), { Transparency = final }):Play()
		end)
	end
end

local function onPlayerEaten(eater: Player, victim: Player)
	local victimRoot = victim.Character and mouthOf(victim.Character :: Model)
	local eaterRoot = eater.Character and mouthOf(eater.Character :: Model)
	if eaterRoot then
		playSound(AudioConfig.Gulp, eaterRoot)
		sparkles(eaterRoot):Emit(30)
	end
	if victimRoot and victim.Character then
		for _, d in (victim.Character :: Model):GetDescendants() do
			if d:IsA("BasePart") then
				TweenService:Create(d, TweenInfo.new(0.3), { Transparency = 1 }):Play()
			end
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

function EatEffects.playTierUp()
	local character = localPlayer.Character
	local root = character and mouthOf(character)
	if root then
		playSound(AudioConfig.TierUp, root)
		sparkles(root):Emit(40)
	end
end

function EatEffects.init()
	Remotes.event(Remotes.Names.Events.BuildingEaten).OnClientEvent:Connect(onBuildingEaten)
	Remotes.event(Remotes.Names.Events.BuildingRegenerated).OnClientEvent:Connect(onBuildingRegenerated)
	Remotes.event(Remotes.Names.Events.PlayerEaten).OnClientEvent:Connect(onPlayerEaten)
end

return EatEffects
