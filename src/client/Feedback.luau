--!strict
-- Feedback triplo de toda ação (Config/FeedbackConfig): SOM + SHAKE + NÚMERO pequeno, sempre juntos.
--   Feedback.play("Buy", { Gui = botão, Amount = 120 })     -- na UI: balança o botão e o número sai dele
--   Feedback.play("Eat", { World = posição, Amount = 5 })  -- no mundo: treme a câmera e o número sai do lugar
-- Todo botão do jogo ganha o feedback de "Click" sozinho (Feedback.init escuta o PlayerGui).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FeedbackConfig = require(Shared.Config.FeedbackConfig)
local Shake = require(Shared.Logic.Shake)
local Style = require(script.Parent.Ui.Style)

local localPlayer = Players.LocalPlayer

local Feedback = {}

-- NoNumber: só som e tremor, sem o texto flutuando (ex.: giro grátis da roleta, pedido do usuário)
export type Target = { Gui: GuiObject?, World: Vector3?, Amount: number?, Text: string?, NoNumber: boolean? }

local lastSound: { [string]: number } = {}
local cameraShake = 0
local cameraStart = 0
local cameraSeconds = 0.1
local wobbling: { [GuiObject]: { Base: number, Token: number } } = {}
local merged: { [string]: { Label: TextLabel, Amount: number, At: number } } = {}

local soundFolder = Instance.new("Folder")
soundFolder.Name = "FeedbackSounds"
soundFolder.Parent = SoundService

local numberGui = Instance.new("ScreenGui")
numberGui.Name = "FeedbackNumbers"
numberGui.ResetOnSpawn = false
numberGui.DisplayOrder = 50
numberGui.IgnoreGuiInset = true

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function playSound(kind: string, spec: FeedbackConfig.Sound)
	local now = os.clock()
	if now - (lastSound[kind] or 0) < spec.MinGap then
		return
	end
	lastSound[kind] = now
	local sound = Instance.new("Sound")
	sound.SoundId = spec.Id
	sound.Volume = spec.Volume
	sound.PlaybackSpeed = spec.Pitch + (math.random() * 2 - 1) * spec.Jitter
	sound.Parent = soundFolder
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

-- Balança o elemento (rotação), sem mexer na posição nem no layout.
local function wobble(gui: GuiObject, degrees: number, seconds: number)
	local entry = wobbling[gui]
	local base = if entry then entry.Base else gui.Rotation
	local token = (if entry then entry.Token else 0) + 1
	wobbling[gui] = { Base = base, Token = token }
	local start = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local current = wobbling[gui]
		if current == nil or current.Token ~= token or gui.Parent == nil then
			connection:Disconnect()
			return
		end
		local t = (os.clock() - start) / seconds
		gui.Rotation = base + Shake.uiAngle(degrees, t)
		if t >= 1 then
			gui.Rotation = base
			wobbling[gui] = nil
			connection:Disconnect()
		end
	end)
end

local function shakeCamera(amount: number, seconds: number)
	local scale = (localPlayer:GetAttribute("Scale") :: number?) or 1
	cameraShake = Shake.add(cameraShake, amount * scale, FeedbackConfig.MaxCameraShake * scale)
	cameraStart = cameraShake
	cameraSeconds = math.max(seconds, 0.05)
end

local function format(spec: FeedbackConfig.Number, amount: number): string
	return string.format(spec.Format, math.floor(amount + 0.5))
end

-- Ponto da tela de onde o número sai.
local function screenPoint(target: Target): Vector2?
	if target.Gui then
		local gui = target.Gui
		return gui.AbsolutePosition + Vector2.new(gui.AbsoluteSize.X / 2, 0)
	end
	local camera = Workspace.CurrentCamera
	if target.World and camera then
		local point, visible = camera:WorldToViewportPoint(target.World)
		if visible then
			return Vector2.new(point.X, point.Y)
		end
	end
	return nil
end

-- O elemento está aparecendo de verdade? (ele e todos os pais visíveis; HUD escondido atrás de janela não conta)
local function onScreen(gui: GuiObject): boolean
	local node: Instance? = gui
	while node and node:IsA("GuiObject") do
		if not node.Visible then
			return false
		end
		node = node.Parent
	end
	return true
end

local function showNumber(kind: string, spec: FeedbackConfig.Number, target: Target)
	if spec.Hidden or (target.Gui and not onScreen(target.Gui)) then
		return
	end
	local key = kind .. (if target.Gui then target.Gui:GetFullName() else "")
	local amount = target.Amount or 1
	local now = os.clock()
	local previous = merged[key]
	-- números seguidos do mesmo tipo no mesmo lugar viram um só ("+12")
	if previous and previous.Label.Parent and target.Text == nil then
		local total = Shake.merge(previous.Amount, previous.At, amount, now, spec.Merge)
		if total ~= amount then
			previous.Amount, previous.At = total, now
			previous.Label.Text = format(spec, total)
			return
		end
	end
	local point = screenPoint(target)
	if point == nil then
		return
	end
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Size = UDim2.fromOffset(220, FeedbackConfig.NumberSize)
	label.Position = UDim2.fromOffset(point.X + math.random(-12, 12), point.Y)
	label.Font = Style.Font
	label.TextScaled = true
	label.Text = target.Text or format(spec, amount)
	label.TextColor3 = rgb(spec.Color)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Style.TextStroke
	stroke.Parent = label
	label.Parent = numberGui
	merged[key] = { Label = label, Amount = amount, At = now }
	local seconds = FeedbackConfig.NumberSeconds
	TweenService:Create(label, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = label.Position - UDim2.fromOffset(0, FeedbackConfig.NumberRise),
	}):Play()
	TweenService:Create(label, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
	}):Play()
	TweenService:Create(stroke, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Transparency = 1,
	}):Play()
	task.delay(seconds, function()
		label:Destroy()
	end)
end

-- Tremor de câmera avulso (impacto de desastre perto de você), com o mesmo teto dos outros tremores.
function Feedback.shake(amount: number, seconds: number)
	shakeCamera(amount, seconds)
end

-- Toca os três feedbacks de uma ação.
function Feedback.play(kind: string, target: Target)
	local spec = FeedbackConfig.Kinds[kind]
	if spec == nil then
		warn("[Feedback] tipo desconhecido:", kind)
		return
	end
	playSound(kind, spec.Sound)
	if spec.Shake.Camera then
		shakeCamera(spec.Shake.Camera, spec.Shake.Seconds)
	end
	if spec.Shake.Ui and target.Gui then
		if onScreen(target.Gui) then
			wobble(target.Gui, spec.Shake.Ui, spec.Shake.Seconds)
		end
	elseif spec.Shake.Ui then
		-- ação sem elemento na tela: treme a câmera de leve no lugar
		shakeCamera(spec.Shake.Ui * 0.02, spec.Shake.Seconds)
	end
	if not target.NoNumber then
		showNumber(kind, spec.Number, target)
	end
end

-- O que balança quando um botão é tocado: o próprio botão, ou o painel dele se o botão for invisível.
local function visualOf(button: GuiButton): GuiObject
	local parent = button.Parent
	if button.BackgroundTransparency >= 1 and parent and parent:IsA("GuiObject") then
		return parent
	end
	return button
end

local function hookButton(item: Instance)
	if item:IsA("GuiButton") and not item:GetAttribute("FeedbackHooked") then
		item:SetAttribute("FeedbackHooked", true)
		item.Activated:Connect(function()
			Feedback.play("Click", { Gui = visualOf(item) })
		end)
	end
end

function Feedback.init()
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	numberGui.Parent = playerGui
	for _, item in playerGui:GetDescendants() do
		hookButton(item)
	end
	playerGui.DescendantAdded:Connect(hookButton)
	-- tremor da câmera: depois da câmera do Roblox se posicionar, a cada frame
	RunService:BindToRenderStep("FeedbackShake", Enum.RenderPriority.Camera.Value + 1, function(dt)
		if cameraShake <= 0 then
			return
		end
		local camera = Workspace.CurrentCamera
		if camera then
			local s = cameraShake
			camera.CFrame *= CFrame.new((math.random() * 2 - 1) * s, (math.random() * 2 - 1) * s, 0)
		end
		cameraShake = Shake.decay(cameraShake, cameraStart, cameraSeconds, dt)
	end)
end

return Feedback
