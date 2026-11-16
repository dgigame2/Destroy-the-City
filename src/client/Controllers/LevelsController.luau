--!strict
-- Painel de níveis dos desastres (substitui o de contratos; mesmo visual e mesma posição).
-- Uma linha por desastre: "☄️ METEOR" + "LV 3" + barrinha de XP até o próximo nível. Só texto, não captura toque.
-- Estado vem do servidor no atributo JSON "Mastery" do jogador (server/MasteryService).
-- Posição: Logic/UiLayout (Levels). Subiu de nível: aviso + feedback triplo (som, balanço do painel, "LV n").
-- Também mostra o aviso da reação em cadeia (CHAIN x3...).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UiConfig = require(Shared.Config.UiConfig)
local UiLayout = require(Shared.Logic.UiLayout)
local DisasterConfig = require(Shared.Config.DisasterConfig)
local MasteryConfig = require(Shared.Config.MasteryConfig)
local Remotes = require(Shared.Remotes)

local Style = require(script.Parent.Parent.Ui.Style)
local Feedback = require(script.Parent.Parent.Feedback)
local InterfaceController = require(script.Parent.InterfaceController)

local localPlayer = Players.LocalPlayer

local LevelsController = {}

type Row = { Frame: Frame, Label: TextLabel, Count: TextLabel, Fill: Frame }
type Entry = { Id: string, Level: number, Progress: number }

-- cor da barra de cada desastre (a mesma família de cor do botão dele)
local FILL = {
	Meteor = Color3.fromRGB(255, 160, 60),
	Tornado = Color3.fromRGB(120, 220, 255),
	Lightning = Color3.fromRGB(255, 227, 107),
}

local gui: ScreenGui
local holder: Frame
local rows: { Row } = {}

local function titleOf(id: string): string
	local d = DisasterConfig.ById[id]
	return if d then `{d.Icon} {d.Name}` else id
end

local function makeRow(index: number, id: string, parent: Instance): Row
	local frame = Instance.new("Frame")
	frame.Name = "Row" .. index
	frame.BackgroundTransparency = 1
	frame.Parent = parent
	local label = Style.label("Label", titleOf(id))
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Position = UDim2.fromScale(0, 0)
	label.Size = UDim2.fromScale(0.6, 0.62)
	label.Parent = frame
	local count = Style.label("Count", "LV 1")
	count.TextXAlignment = Enum.TextXAlignment.Right
	count.Position = UDim2.fromScale(0.6, 0)
	count.Size = UDim2.fromScale(0.4, 0.62)
	count.Parent = frame
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.BackgroundColor3 = Color3.fromRGB(11, 18, 48)
	track.BackgroundTransparency = 0.4
	track.BorderSizePixel = 0
	track.Position = UDim2.fromScale(0, 0.7)
	track.Size = UDim2.fromScale(1, 0.18)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = track
	track.Parent = frame
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = FILL[id] or Color3.fromRGB(125, 255, 138)
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill
	fill.Parent = track
	return { Frame = frame, Label = label, Count = count, Fill = fill }
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
		local row = rows[i]
		local entry = byId[d.Id]
		local level = if entry then entry.Level else 1
		local progress = if entry then entry.Progress else 0
		row.Count.Text = if level >= MasteryConfig.MaxLevel then "MAX" else `LV {level}`
		row.Fill.Size = UDim2.fromScale(math.clamp(progress, 0, 1), 1)
	end
end

local function layout()
	local size = gui.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then
		return
	end
	local l = UiLayout.place(size.X, size.Y, UiConfig)
	local panel = l.Levels
	holder.Position = UDim2.fromOffset(panel.X0, panel.Y0)
	holder.Size = UDim2.fromOffset(panel.X1 - panel.X0, panel.Y1 - panel.Y0)
	for i, row in rows do
		local r = l.LevelRows[i]
		row.Frame.Position = UDim2.fromOffset(r.X0 - panel.X0, r.Y0 - panel.Y0)
		row.Frame.Size = UDim2.fromOffset(r.X1 - r.X0, r.Y1 - r.Y0)
	end
end

function LevelsController.init()
	gui = Instance.new("ScreenGui")
	gui.Name = "Levels"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.DisplayOrder = 4
	gui.Parent = localPlayer:WaitForChild("PlayerGui")
	-- painel em Depth Stack (sombra, gradiente, contorno), mais transparente para não esconder a cidade
	local panelHolder, face = Style.panel("LevelsPanel", Style.Themes.Blue, 12)
	panelHolder.AnchorPoint = Vector2.zero
	face.BackgroundTransparency = 0.25
	panelHolder.Parent = gui
	holder = panelHolder
	for i, d in DisasterConfig.List do
		rows[i] = makeRow(i, d.Id, panelHolder)
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
	layout()
	localPlayer:GetAttributeChangedSignal("Mastery"):Connect(refresh)
	refresh()
	Remotes.event(Remotes.Names.Events.DisasterLevelUp).OnClientEvent:Connect(function(id: string, level: number)
		InterfaceController.toast(`{titleOf(id)} LV {level}!`, FILL[id] or Color3.fromRGB(125, 255, 138))
		Feedback.play("Level", { Gui = holder, Amount = level })
	end)
	Remotes.event(Remotes.Names.Events.ChainReaction).OnClientEvent:Connect(function(text: string, count: number)
		InterfaceController.bigCombo(text)
		Feedback.play("Chain", { Gui = InterfaceController.refs().Combo, Amount = count })
	end)
end

return LevelsController
