--!strict
-- Hotbar dos elementos: coluna no canto direito da tela (pedido do usuário, 18/11/2026), um botão por elemento
-- (ícone + nome), número da tecla no canto (só no PC), recarga escurecendo o botão e a mini barra do nível
-- embaixo. O selecionado ganha contorno dourado.
-- Posições: Logic/UiLayout.place (Elements/ElementBars), o mesmo cálculo que o UiLayout.spec confere em
-- aparelhos reais. Só UI: quem decide o que fazer com o toque é o client/City/ElementInput.
-- Nível: atributos do jogador "Level<Id>" (1..MaxLevel) e "LevelProgress<Id>" (0..1); sem eles, LV 1 vazio
-- (os níveis de verdade chegam na Etapa 4).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ElementConfig = require(Shared.Config.ElementConfig)
local UiConfig = require(Shared.Config.UiConfig)
local UiLayout = require(Shared.Logic.UiLayout)

local Style = require(script.Parent.Parent.Ui.Style)

local ElementBar = {}

type Slot = {
	Holder: Frame,
	Hit: TextButton,
	Face: Frame,
	Stroke: UIStroke,
	Outline: Color3,
	Key: Frame,
	Cooldown: Frame,
	Bar: Frame,
	Fill: Frame,
	Level: TextLabel,
}

local localPlayer = Players.LocalPlayer
local slots: { Slot } = {}
local gui: ScreenGui? = nil
local selected = 1
local onPick: ((index: number) -> ())? = nil

local GOLD = Style.Colors.Gold or Color3.fromRGB(255, 229, 120)
local DARK = Style.rgb({ 20, 26, 52 })

local function corner(parent: Instance, radius: UDim)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	c.Parent = parent
end

local function newSlot(index: number, element: ElementConfig.Element, parent: Instance): Slot
	local theme = Style.Themes[element.Theme] or Style.Themes.Blue
	local holder, hit, face = Style.button("Element" .. element.Id, theme, "")
	holder.Parent = parent
	-- ícone em cima (50%) e nome embaixo (34%), como os atalhos (o UiLayout.spec confere que o nome cabe)
	local icon = Style.glyph("Icon", element.Icon)
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.Position = UDim2.fromScale(0.5, 0.06)
	icon.Size = UDim2.fromScale(0.62, 0.5)
	icon.Parent = face
	local caption = Style.label("Caption", element.Short)
	caption.AnchorPoint = Vector2.new(0.5, 1)
	caption.Position = UDim2.new(0.5, 0, 1, -3)
	caption.Size = UDim2.new(1, -6, 0.34, 0)
	caption.Parent = face

	-- recarga: sombra escura que esvazia de cima para baixo
	local cooldown = Instance.new("Frame")
	cooldown.Name = "Cooldown"
	cooldown.AnchorPoint = Vector2.new(0, 1)
	cooldown.Position = UDim2.fromScale(0, 1)
	cooldown.Size = UDim2.fromScale(1, 0)
	cooldown.BackgroundColor3 = DARK
	cooldown.BackgroundTransparency = 0.45
	cooldown.BorderSizePixel = 0
	cooldown.ZIndex = 6
	corner(cooldown, UDim.new(0, 14))
	cooldown.Parent = face

	-- número da tecla (PC), no canto de cima à esquerda, metade para fora
	local key = Instance.new("Frame")
	key.Name = "Key"
	key.AnchorPoint = Vector2.new(0.5, 0.5)
	key.Position = UDim2.fromScale(0.06, 0.06)
	key.Size = UDim2.fromScale(0.34, 0.34)
	key.BackgroundColor3 = Style.TextStroke
	key.ZIndex = 7
	corner(key, UDim.new(0.5, 0))
	local keyText = Style.label("Text", tostring(index))
	keyText.Size = UDim2.fromScale(0.8, 0.8)
	keyText.AnchorPoint = Vector2.new(0.5, 0.5)
	keyText.Position = UDim2.fromScale(0.5, 0.5)
	keyText.ZIndex = 8
	keyText.Parent = key
	key.Parent = holder

	-- mini barra do nível (embaixo do botão; posição vem do layout)
	local bar = Instance.new("Frame")
	bar.Name = "Level" .. element.Id
	bar.BackgroundColor3 = DARK
	bar.BackgroundTransparency = 0.2
	bar.BorderSizePixel = 0
	corner(bar, UDim.new(0.5, 0))
	local barStroke = Instance.new("UIStroke")
	barStroke.Thickness = 2
	barStroke.Color = Style.TextStroke
	barStroke.Parent = bar
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = theme.Top
	fill.BorderSizePixel = 0
	corner(fill, UDim.new(0.5, 0))
	fill.Parent = bar
	local level = Style.label("Text", "LV 1")
	level.Size = UDim2.fromScale(0.9, 0.9)
	level.AnchorPoint = Vector2.new(0.5, 0.5)
	level.Position = UDim2.fromScale(0.5, 0.5)
	level.Parent = bar
	bar.Parent = parent

	hit.Activated:Connect(function()
		if onPick then
			onPick(index)
		end
	end)

	local stroke = face:FindFirstChildOfClass("UIStroke") :: UIStroke
	return {
		Holder = holder,
		Hit = hit,
		Face = face,
		Stroke = stroke,
		Outline = stroke.Color,
		Key = key,
		Cooldown = cooldown,
		Bar = bar,
		Fill = fill,
		Level = level,
	}
end

local function refreshLevel(index: number)
	local slot, element = slots[index], ElementConfig.List[index]
	local level = localPlayer:GetAttribute("Level" .. element.Id)
	local progress = localPlayer:GetAttribute("LevelProgress" .. element.Id)
	local lv = math.clamp(if type(level) == "number" then math.floor(level) else 1, 1, ElementConfig.MaxLevel)
	local max = lv >= ElementConfig.MaxLevel
	slot.Level.Text = if max then "MAX" else `LV {lv}`
	local frac = if max then 1 elseif type(progress) == "number" then math.clamp(progress, 0, 1) else 0
	slot.Fill.Size = UDim2.fromScale(frac, 1)
	slot.Fill.Visible = frac > 0
end

local function layout()
	local screen = gui
	if screen == nil then
		return
	end
	local area = screen.AbsoluteSize
	if area.X <= 0 or area.Y <= 0 then
		return
	end
	local desktop = UiLayout.isDesktop(UserInputService.TouchEnabled, UserInputService.KeyboardEnabled)
	local placed = UiLayout.place(area.X, area.Y, UiConfig, desktop)
	for i, slot in slots do
		local r, b = placed.Elements[i], placed.ElementBars[i]
		if r == nil or b == nil then
			continue
		end
		slot.Holder.Position = UDim2.fromOffset(r.X0, r.Y0)
		slot.Holder.Size = UDim2.fromOffset(r.X1 - r.X0, r.Y1 - r.Y0)
		slot.Bar.Position = UDim2.fromOffset(b.X0, b.Y0)
		slot.Bar.Size = UDim2.fromOffset(b.X1 - b.X0, b.Y1 - b.Y0)
		slot.Key.Visible = desktop
	end
end

-- Marca o elemento escolhido (contorno dourado).
function ElementBar.select(index: number)
	selected = index
	for i, slot in slots do
		local on = i == selected
		slot.Stroke.Color = if on then GOLD else slot.Outline
		slot.Stroke.Thickness = if on then 6 else 4
	end
	layout()
end

-- Recarga do elemento `index`: a sombra cobre o botão e esvazia em `seconds`.
function ElementBar.cooldown(index: number, seconds: number)
	local slot = slots[index]
	if slot == nil or seconds <= 0 then
		return
	end
	slot.Cooldown.Size = UDim2.fromScale(1, 1)
	TweenService
		:Create(slot.Cooldown, TweenInfo.new(seconds, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(1, 0) })
		:Play()
end

-- O botão (para o balanço do Feedback quando a escolha vem do teclado).
function ElementBar.button(index: number): GuiObject?
	local slot = slots[index]
	return if slot then slot.Holder else nil
end

function ElementBar.init(pick: (index: number) -> ())
	onPick = pick
	local screen = Instance.new("ScreenGui")
	screen.Name = "ElementBar"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = false -- igual ao HUD: abaixo da barra do Roblox
	screen.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui = screen
	for i, element in ElementConfig.List do
		slots[i] = newSlot(i, element, screen)
		refreshLevel(i)
		localPlayer:GetAttributeChangedSignal("Level" .. element.Id):Connect(function()
			refreshLevel(i)
		end)
		localPlayer:GetAttributeChangedSignal("LevelProgress" .. element.Id):Connect(function()
			refreshLevel(i)
		end)
	end
	screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
	UserInputService.LastInputTypeChanged:Connect(layout)
	screen.Parent = localPlayer:WaitForChild("PlayerGui")
	ElementBar.select(selected)
end

return ElementBar
