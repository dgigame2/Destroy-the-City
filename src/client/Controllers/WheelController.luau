--!strict
-- Roleta: a roda só existe dentro da janela SPIN (cópia do modelo que o servidor deixa no
-- ReplicatedStorage). O servidor sorteia; aqui só animamos até parar na fatia sorteada.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Wheel = require(Shared.Logic.Wheel)
local WheelConfig = require(Shared.Config.WheelConfig)
local LobbyConfig = require(Shared.Config.LobbyConfig)
local UiConfig = require(Shared.Config.UiConfig)
local ProductConfig = require(Shared.Config.ProductConfig)
local Remotes = require(Shared.Remotes)

local Style = require(script.Parent.Parent.Ui.Style)
local InterfaceController = require(script.Parent.InterfaceController)
local Feedback = require(script.Parent.Parent.Feedback)

local MarketplaceService = game:GetService("MarketplaceService")
local localPlayer = Players.LocalPlayer

local WheelController = {}

type Spinner = { Rotor: Model, Rest: CFrame, Angle: number, Token: number, Overlay: GuiObject? }

-- câmera da roda dentro da janela
local PREVIEW_FOV = UiConfig.WheelCamera.Fov
local PREVIEW_DISTANCE = UiConfig.WheelCamera.Distance
local PREVIEW_LIFT = UiConfig.WheelCamera.Lift

local preview: Spinner? = nil
local spinning = false

local function rotate(spinner: Spinner, angle: number)
	spinner.Angle = angle
	-- eixo da roda = X local do cubo central; ângulo negativo = horário para quem olha de frente
	spinner.Rotor:PivotTo(spinner.Rest * CFrame.Angles(-math.rad(angle), 0, 0))
	-- os nomes dos prêmios (2D) giram junto: ângulo positivo = horário na tela também
	if spinner.Overlay then
		spinner.Overlay.Rotation = angle
	end
end

local function spin(spinner: Spinner, index: number, duration: number)
	spinner.Token += 1
	local token = spinner.Token
	local count = #WheelConfig.Segments
	local start = spinner.Angle % 360
	local target = Wheel.targetAngle(index, count, 6, math.random())
	local value = Instance.new("NumberValue")
	value.Value = start
	local connection = value.Changed:Connect(function(angle)
		if spinner.Token == token then
			rotate(spinner, angle)
		end
	end)
	local tween = TweenService:Create(
		value,
		TweenInfo.new(duration, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		{ Value = target }
	)
	tween:Play()
	tween.Completed:Once(function()
		connection:Disconnect()
		value:Destroy()
	end)
end

-- Modelo da roda que o LobbyService monta no ReplicatedStorage (com o cubo central já chegado).
local function findWheelModel(): Model?
	local wheelModel = ReplicatedStorage:WaitForChild("LuckyWheel", 30) :: Model?
	local rotor = wheelModel and wheelModel:WaitForChild("Rotor", 30) :: Model?
	if rotor == nil then
		return nil
	end
	-- o giro é em volta do cubo central: espera ele chegar (sem ele o pivô fica no lugar errado)
	local deadline = os.clock() + 30
	while rotor.PrimaryPart == nil and os.clock() < deadline do
		task.wait(0.1)
	end
	return if rotor.PrimaryPart then wheelModel else nil
end

-- Copia a roda inteira para dentro da janela, com uma câmera de frente.
local function buildPreview(viewport: ViewportFrame, source: Model): Spinner?
	local copy = source:Clone()
	local rotor = copy:FindFirstChild("Rotor") :: Model?
	if rotor == nil then
		return nil
	end
	copy.Parent = viewport
	local hub = rotor.PrimaryPart :: BasePart
	local camera = Instance.new("Camera")
	camera.FieldOfView = PREVIEW_FOV
	local front = hub.CFrame.XVector -- aponta para quem olha a roda
	local lift = Vector3.new(0, PREVIEW_LIFT, 0)
	camera.CFrame = CFrame.lookAt(hub.Position + front * PREVIEW_DISTANCE + lift, hub.Position + lift)
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	-- Encaixa os nomes dos prêmios em cima da roda: projeção da câmera (FOV vertical, janela quadrada).
	local halfHeight = PREVIEW_DISTANCE * math.tan(math.rad(PREVIEW_FOV / 2))
	local overlay = InterfaceController.refs().WheelLabels
	local diameter = LobbyConfig.WheelRadius / halfHeight -- fração da altura da janela
	overlay.Size = UDim2.fromScale(diameter, diameter)
	overlay.Position = UDim2.fromScale(0.5, 0.5 + (PREVIEW_LIFT / halfHeight) / 2)
	return { Rotor = rotor, Rest = rotor:GetPivot(), Angle = 0, Token = 0, Overlay = overlay }
end

local function setButton(button: any, title: string, sub: string, enabled: boolean, enabledTheme: Style.Theme)
	button.Title.Text = title
	button.Sub.Text = sub
	Style.recolor(button.Face, if enabled then enabledTheme else Style.Themes.Gray)
end

local function freeIn(): number
	local lastFree = (localPlayer:GetAttribute("WheelLastFree") :: number?) or 0
	return Wheel.freeSpinIn(lastFree, os.time(), WheelConfig.FreeCooldownSeconds)
end

local function refresh()
	local refs = InterfaceController.refs()
	local buttons = refs.WheelButtons
	local wait = freeIn()
	setButton(
		buttons.Free,
		"FREE SPIN",
		if wait > 0 then InterfaceController.formatTime(wait) else "Ready!",
		wait == 0 and not spinning,
		Style.Themes.Green
	)
	local extra = (localPlayer:GetAttribute("WheelExtra") :: number?) or 0
	setButton(buttons.Extra, "USE SPIN", "x" .. extra .. " saved", extra > 0 and not spinning, Style.Themes.Yellow)
	local gems = (localPlayer:GetAttribute("Gems") :: number?) or 0
	setButton(
		buttons.Gems,
		"💎 " .. WheelConfig.GemCost,
		"1 Spin",
		gems >= WheelConfig.GemCost and not spinning,
		Style.Themes.LightBlue
	)
	local product = ProductConfig[4]
	local robuxReady = product and product.ProductId ~= 0
	setButton(
		buttons.Robux,
		if robuxReady then Style.Robux .. " " .. product.PriceLabel else "SOON",
		"1 Spin",
		robuxReady and not spinning,
		Style.Themes.Green
	)
	refs.SpinBadge.Visible = wait == 0 or extra > 0
end

local function request(payment: string, gui: GuiObject)
	if spinning then
		return
	end
	spinning = true
	refresh()
	local index = Remotes.func(Remotes.Names.Functions.SpinWheel):InvokeServer(payment)
	if index == nil then
		spinning = false
		InterfaceController.toast("CAN'T SPIN NOW", Style.Colors.Danger)
		Feedback.play("Fail", { Gui = gui, Text = "✖" })
		refresh()
		return
	end
	if payment == "Gems" then
		Feedback.play("Spin", { Gui = gui, Amount = WheelConfig.GemCost, Text = `-{WheelConfig.GemCost} 💎` })
	else
		-- giro grátis: sem o "FREE!" flutuando (só som e tremor)
		Feedback.play("Spin", { Gui = gui, Text = "-1 🎟️", NoNumber = payment == "Free" })
	end
	if preview then
		spin(preview, index, WheelConfig.SpinSeconds - 0.3)
	end
	task.delay(WheelConfig.SpinSeconds, function()
		spinning = false
		refresh()
	end)
end

function WheelController.init()
	local refs = InterfaceController.refs()
	InterfaceController.onOpen("Wheel", refresh)
	refs.SpinIcon.Activated:Connect(function()
		InterfaceController.open("Wheel")
	end)
	local buttons = refs.WheelButtons
	buttons.Free.Hit.Activated:Connect(function()
		request("Free", buttons.Free.Holder)
	end)
	buttons.Extra.Hit.Activated:Connect(function()
		request("Extra", buttons.Extra.Holder)
	end)
	buttons.Gems.Hit.Activated:Connect(function()
		request("Gems", buttons.Gems.Holder)
	end)
	buttons.Robux.Hit.Activated:Connect(function()
		local product = ProductConfig[4]
		if product and product.ProductId ~= 0 and not spinning then
			MarketplaceService:PromptProductPurchase(localPlayer, product.ProductId)
		end
	end)
	for _, attribute in { "WheelLastFree", "WheelExtra", "Gems" } do
		localPlayer:GetAttributeChangedSignal(attribute):Connect(refresh)
	end

	task.spawn(function()
		local wheelModel = findWheelModel()
		if wheelModel then
			preview = buildPreview(refs.WheelViewport, wheelModel)
		end
		refresh()
	end)
	-- contagem regressiva do giro grátis
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= 1 then
			elapsed = 0
			refresh()
		end
	end)
end

return WheelController
