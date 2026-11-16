--!strict
-- Nível de cada desastre: mini barra embaixo do botão da skill, com "LV 3" escrito em cima e a barrinha de XP
-- enchendo até o próximo nível (pedido do usuário, 16/11/2026: sem painel separado). Só texto, não captura toque.
-- Estado vem do servidor no atributo JSON "Mastery" do jogador (server/MasteryService).
-- Posição: Logic/UiLayout (DisasterBars, Recommended). Subiu de nível: aviso + feedback triplo.
-- Também mostra a construção recomendada (canto superior direito) e o aviso da reação em cadeia (CHAIN x3...).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UiConfig = require(Shared.Config.UiConfig)
local UiLayout = require(Shared.Logic.UiLayout)
local DisasterConfig = require(Shared.Config.DisasterConfig)
local MasteryConfig = require(Shared.Config.MasteryConfig)
local PaletteConfig = require(Shared.Config.PaletteConfig)
local TierConfig = require(Shared.Config.TierConfig)
local Remotes = require(Shared.Remotes)

local Style = require(script.Parent.Parent.Ui.Style)
local Feedback = require(script.Parent.Parent.Feedback)
local InterfaceController = require(script.Parent.InterfaceController)

local localPlayer = Players.LocalPlayer

local LevelsController = {}

type Bar = { Frame: Frame, Count: TextLabel, Fill: Frame }
type Entry = { Id: string, Level: number, Progress: number }

-- cor da barra de cada desastre (a mesma família de cor do botão dele)
local FILL = {
	Meteor = Style.rgb(PaletteConfig.Disasters.Meteor),
	Tornado = Style.rgb(PaletteConfig.Disasters.Tornado),
	Lightning = Style.rgb(PaletteConfig.Disasters.Lightning),
}

local gui: ScreenGui
local bars: { Bar } = {}
local barIndex: { [string]: number } = {}
local recommended: Frame
local recommendedName: TextLabel

local function titleOf(id: string): string
	local d = DisasterConfig.ById[id]
	return if d then `{d.Icon} {d.Name}` else id
end

-- Mini barra: trilho escuro arredondado, preenchimento na cor do desastre e "LV n" por cima.
local function makeBar(index: number, id: string): Bar
	local track = Instance.new("Frame")
	track.Name = "Level" .. index
	track.AnchorPoint = Vector2.zero
	track.BackgroundColor3 = Style.TextStroke
	track.BackgroundTransparency = 0.25
	track.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = track
	local stroke = Instance.new("UIStroke")
	stroke.Color = Style.TextStroke
	stroke.Thickness = 2
	stroke.Parent = track
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = FILL[id] or Style.Colors.LevelFill
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	fill.ZIndex = 2
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill
	fill.Parent = track
	local count = Style.label("Count", "LV 1")
	count.AnchorPoint = Vector2.new(0.5, 0.5)
	count.Position = UDim2.fromScale(0.5, 0.5)
	count.Size = UDim2.fromScale(0.9, 0.9)
	count.ZIndex = 3
	count.Parent = track
	track.Parent = gui
	return { Frame = track, Count = count, Fill = fill }
end

local function decode(value: unknown): { Entry }
	if type(value) ~= "string" then
		return {}
	end
	local ok, result = pcall(HttpService.JSONDecode, HttpService, value)
	return if ok and type(result) == "table" then result else {}
end

local function refresh()
	local byId: { [string]: Entry } = {}
	for _, entry in decode(localPlayer:GetAttribute("Mastery")) do
		byId[entry.Id] = entry
	end
	for i, d in DisasterConfig.List do
		local bar = bars[i]
		local entry = byId[d.Id]
		local level = if entry then entry.Level else 1
		local progress = if entry then entry.Progress else 0
		local max = level >= MasteryConfig.MaxLevel
		bar.Count.Text = if max then "MAX" else `LV {level}`
		bar.Fill.Size = UDim2.fromScale(if max then 1 else math.clamp(progress, 0, 1), 1)
	end
end

local function layout()
	local size = gui.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then
		return
	end
	local desktop = UiLayout.isDesktop(UserInputService.TouchEnabled, UserInputService.KeyboardEnabled)
	local l = UiLayout.place(size.X, size.Y, UiConfig, desktop)
	for i, bar in bars do
		local r = l.DisasterBars[i]
		bar.Frame.Position = UDim2.fromOffset(r.X0, r.Y0)
		bar.Frame.Size = UDim2.fromOffset(r.X1 - r.X0, r.Y1 - r.Y0)
	end
	local rec = l.Recommended
	recommended.Position = UDim2.fromOffset(rec.X0, rec.Y0)
	recommended.Size = UDim2.fromOffset(rec.X1 - rec.X0, rec.Y1 - rec.Y0)
end

-- Construção recomendada: o maior tier que o seu poder já destrói bem (atributo EdibleTier do servidor).
-- Substitui o antigo aviso "YOU CAN NOW DESTROY ..." (agora tudo leva dano; o nível só vai subindo).
local function edibleTier(): number
	return (localPlayer:GetAttribute("EdibleTier") :: number?) or 1
end

local function refreshRecommended()
	local info = TierConfig[edibleTier()]
	recommendedName.Text = if info then info.DisplayName else ""
end

local function makeRecommended()
	local panel, face = Style.panel("Recommended", Style.Themes.Blue, 12)
	panel.AnchorPoint = Vector2.zero
	face.BackgroundTransparency = 0.25
	local title = Style.label("Title", "⭐ RECOMMENDED")
	title.TextColor3 = Style.Colors.Gold
	title.AnchorPoint = Vector2.new(0.5, 0)
	title.Position = UDim2.fromScale(0.5, 0.06)
	title.Size = UDim2.new(1, -16, 0.4, 0)
	title.Parent = face
	local name = Style.label("Building", "")
	name.AnchorPoint = Vector2.new(0.5, 1)
	name.Position = UDim2.fromScale(0.5, 0.96)
	name.Size = UDim2.new(1, -16, 0.5, 0)
	name.Parent = face
	panel.Parent = gui
	recommended, recommendedName = panel, name
end

function LevelsController.init()
	gui = Instance.new("ScreenGui")
	gui.Name = "Levels"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.DisplayOrder = 5 -- mesma camada dos botões dos desastres
	gui.Parent = localPlayer:WaitForChild("PlayerGui")
	for i, d in DisasterConfig.List do
		bars[i] = makeBar(i, d.Id)
		barIndex[d.Id] = i
	end
	makeRecommended()
	refreshRecommended()
	local lastTier = edibleTier()
	localPlayer:GetAttributeChangedSignal("EdibleTier"):Connect(function()
		local tier = edibleTier()
		refreshRecommended()
		if tier > lastTier then
			-- sem aviso no meio da tela: só som, tremor e o painel pulsando
			Feedback.play("TierUp", { Gui = recommended, Amount = tier })
		end
		lastTier = tier
	end)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
	layout()
	localPlayer:GetAttributeChangedSignal("Mastery"):Connect(refresh)
	refresh()
	Remotes.event(Remotes.Names.Events.DisasterLevelUp).OnClientEvent:Connect(function(id: string, level: number)
		InterfaceController.toast(`{titleOf(id)} LV {level}!`, FILL[id] or Style.Colors.LevelFill)
		local bar = bars[barIndex[id] or 1]
		Feedback.play("Level", { Gui = bar.Frame, Amount = level })
	end)
	Remotes.event(Remotes.Names.Events.ChainReaction).OnClientEvent:Connect(function(text: string, count: number)
		InterfaceController.bigCombo(text)
		Feedback.play("Chain", { Gui = InterfaceController.refs().Combo, Amount = count })
	end)
end

return LevelsController
