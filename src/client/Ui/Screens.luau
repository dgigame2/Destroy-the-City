--!strict
-- Monta todas as telas (só aparência, sem lógica). Os controladores ligam tudo ao jogo.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UiConfig = require(Shared.Config.UiConfig)
local UiLayout = require(Shared.Logic.UiLayout)
local WheelConfig = require(Shared.Config.WheelConfig)

local Style = require(script.Parent.Style)

local C = UiConfig

export type Card = {
	Holder: Frame,
	Face: Frame,
	Title: TextLabel,
	Icon: TextLabel,
	Subtitle: TextLabel,
	Button: TextButton,
	ButtonFace: Frame,
	ButtonText: TextLabel,
}

export type DifficultyButton = { Holder: Frame, Hit: TextButton, Face: Frame, Title: TextLabel, Sub: TextLabel }
export type DayTile = { Holder: Frame, Face: Frame, Day: TextLabel, Icon: TextLabel, Label: TextLabel }
export type WheelButton = { Holder: Frame, Hit: TextButton, Face: Frame, Title: TextLabel, Sub: TextLabel }

export type Refs = {
	Gui: ScreenGui,
	Scaled: { GuiObject },
	-- HUD
	Cash: TextLabel,
	CashHolder: Frame,
	Gems: TextLabel,
	GemsHolder: Frame,
	Wins: TextLabel,
	WinsHolder: Frame,
	Icons: Frame,
	ShopIcon: TextButton,
	SpinIcon: TextButton,
	RewardsIcon: TextButton,
	ClassesIcon: TextButton,
	IconHolders: { Frame },
	RewardsBadge: TextLabel,
	SpinBadge: TextLabel,
	TimerHolder: Frame,
	Timer: TextLabel,
	MapName: TextLabel,
	ProgressFill: Frame,
	-- Run (embaixo)
	MatchBar: Frame,
	UpgradesButton: TextButton,
	LobbyButton: TextButton,
	LobbyButtonText: TextLabel,
	LobbyButtonFace: Frame,
	-- Upgrades (janela da partida)
	Upgrades: Frame,
	UpgradesClose: TextButton,
	UpgradesContent: ScrollingFrame,
	UpgradesCash: TextLabel,
	-- Loja
	Shop: Frame,
	ShopClose: TextButton,
	ShopTabs: { [string]: { Hit: TextButton, Face: Frame } },
	ShopContent: ScrollingFrame,
	ShopGems: TextLabel,
	-- Roleta
	Wheel: Frame,
	WheelClose: TextButton,
	WheelViewport: ViewportFrame,
	WheelLabels: Frame,
	WheelButtons: { [string]: WheelButton },
	-- Recompensas
	Rewards: Frame,
	RewardsClose: TextButton,
	DayTiles: { DayTile },
	ClaimDaily: TextButton,
	ClaimDailyText: TextLabel,
	ClaimDailyFace: Frame,
	Weekly: TextLabel,
	ClaimWeekly: TextButton,
	ClaimWeeklyText: TextLabel,
	ClaimWeeklyFace: Frame,
	-- CREATE PARTY (lobby)
	Party: Frame,
	PartyClose: TextButton,
	PartyPrev: TextButton,
	PartyNext: TextButton,
	PartyMapFace: Frame,
	PartyChapter: TextLabel,
	PartyMapName: TextLabel,
	PartyDifficulties: { DifficultyButton },
	PartyMinus: TextButton,
	PartyPlus: TextButton,
	PartySize: TextLabel,
	PartyBack: TextButton,
	PartyCreate: TextButton,
	PartyCreateFace: Frame,
	PartyCreateText: TextLabel,
	SavedList: ScrollingFrame,
	SavedEmpty: TextLabel,
	-- Run
	Winner: Frame,
	WinnerName: TextLabel,
	WinnerSub: TextLabel,
	-- Áreas da cidade
	Frenzy: Frame,
	FrenzyText: TextLabel,
	Celebration: Frame,
	CelebrationTitle: TextLabel,
	CelebrationSub: TextLabel,
	Chips: { TextLabel },
	Rays: Frame,
	Continue: TextButton,
	ContinueHolder: Frame,
	Confetti: Frame,
	Toast: TextLabel,
	Combo: TextLabel,
	Status: TextLabel,
	Popup: Frame,
	PopupIcon: TextLabel,
	PopupText: TextLabel,
}

local function sized(obj: GuiObject, w: number, h: number, anchor: Vector2, position: UDim2)
	obj.Size = UDim2.fromOffset(w, h)
	obj.AnchorPoint = anchor
	obj.Position = position
end

local function badge(parent: Instance): TextLabel
	local b = Style.label("Badge", "!")
	b.BackgroundColor3 = Color3.fromRGB(255, 60, 70)
	b.BackgroundTransparency = 0
	b.Size = UDim2.fromOffset(34, 34)
	b.AnchorPoint = Vector2.new(0.5, 0.5)
	b.Position = UDim2.new(1, -4, 0, 4)
	b.ZIndex = 9
	b.Visible = false
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = b
	b.Parent = parent
	return b
end

local Screens = {}

-- Card de item/classe/produto: título, ícone grande, legenda e botão de preço.
function Screens.card(
	parent: Instance,
	themeName: string,
	title: string,
	icon: string,
	subtitle: string,
	buttonText: string
): Card
	local holder, face = Style.panel("Card", (Style.Themes :: any)[themeName] or Style.Themes.Blue, 20)
	holder.Size = UDim2.fromOffset(C.Card.W, C.Card.H)
	Style.stripes(face)
	local titleLabel = Style.label("Title", title)
	sized(titleLabel, C.Card.W - 20, 34, Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 12))
	titleLabel.Parent = face
	local iconLabel = Style.label("Icon", icon)
	sized(iconLabel, 100, 86, Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 48))
	iconLabel.Parent = face
	local subtitleLabel = Style.label("Subtitle", subtitle)
	subtitleLabel.TextColor3 = Color3.fromRGB(255, 247, 194)
	sized(subtitleLabel, C.Card.W - 20, 40, Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 138))
	subtitleLabel.Parent = face
	local buttonHolder, button, buttonFace = Style.button("Buy", Style.Themes.Green, buttonText)
	sized(buttonHolder, C.Card.W - 24, C.CardButton.H, Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -10))
	buttonHolder.Parent = face
	holder.Parent = parent
	return {
		Holder = holder,
		Face = face,
		Title = titleLabel,
		Icon = iconLabel,
		Subtitle = subtitleLabel,
		Button = button,
		ButtonFace = buttonFace,
		ButtonText = buttonFace:FindFirstChild("Text") :: TextLabel,
	}
end

local function currency(name: string, t: Style.Theme, icon: string): (Frame, TextLabel)
	local holder, face = Style.panel(name, t, 16)
	local iconLabel = Style.label("Icon", icon)
	sized(iconLabel, 44, 44, Vector2.new(0, 0.5), UDim2.new(0, 8, 0.5, 0))
	iconLabel.Parent = face
	local amount = Style.label("Amount", "0")
	amount.TextXAlignment = Enum.TextXAlignment.Left
	sized(amount, C.Currency.W - 70, C.Currency.H - 16, Vector2.new(0, 0.5), UDim2.new(0, 58, 0.5, 0))
	amount.Parent = face
	return holder, amount
end

local function placeRect(obj: GuiObject, r: UiLayout.Rect)
	obj.AnchorPoint = Vector2.zero
	obj.Position = UDim2.fromOffset(r.X0, r.Y0)
	obj.Size = UDim2.fromOffset(r.X1 - r.X0, r.Y1 - r.Y0)
end

-- Etiqueta colorida pequena (dificuldade e progresso no card da run salva).
local function tag(name: string, t: Style.Theme, r: UiLayout.Rect, parent: Instance): TextLabel
	local holder, face = Style.panel(name, t, 10)
	placeRect(holder, r)
	local text = Style.label("Text", "")
	text.AnchorPoint = Vector2.new(0.5, 0.5)
	text.Position = UDim2.fromScale(0.5, 0.5)
	text.Size = UDim2.fromScale(0.9, 1)
	text.Parent = face
	holder.Parent = parent
	return text
end

export type SavedRunCard = {
	Holder: Frame,
	Title: TextLabel,
	With: TextLabel,
	Difficulty: TextLabel,
	Progress: TextLabel,
	Expires: TextLabel,
	Load: TextButton,
}

-- Card de uma run salva (lista da direita da CREATE PARTY).
function Screens.savedRunCard(parent: Instance, order: number): SavedRunCard
	local layout = UiLayout.partyWindow(C).SavedCard
	local holder, face = Style.panel("SavedRun", Style.Themes.Paper, 18)
	holder.Size = UDim2.fromOffset(C.SavedCard.W, C.SavedCard.H)
	holder.LayoutOrder = order
	local title = Style.label("Title", "")
	title.TextXAlignment = Enum.TextXAlignment.Left
	placeRect(title, layout.Title)
	title.Parent = face
	local with = Style.label("With", "")
	with.TextXAlignment = Enum.TextXAlignment.Left
	with.TextTruncate = Enum.TextTruncate.AtEnd
	with.TextColor3 = Color3.fromRGB(255, 227, 107)
	placeRect(with, layout.With)
	with.Parent = face
	local difficulty = tag("Difficulty", Style.Themes.Green, layout.DifficultyTag, face)
	local progress = tag("Progress", Style.Themes.LightBlue, layout.ProgressTag, face)
	local expires = Style.label("Expires", "")
	expires.TextXAlignment = Enum.TextXAlignment.Left
	expires.TextColor3 = Color3.fromRGB(255, 150, 150)
	placeRect(expires, layout.Expires)
	expires.Parent = face
	local loadHolder, load = Style.button("Load", Style.Themes.Green, "LOAD GAME")
	placeRect(loadHolder, layout.Load)
	loadHolder.Parent = face
	holder.Parent = parent
	return {
		Holder = holder,
		Title = title,
		With = with,
		Difficulty = difficulty,
		Progress = progress,
		Expires = expires,
		Load = load,
	}
end

-- Janela CREATE PARTY: mapa (capítulos), dificuldade, tamanho da party e runs salvas.
function Screens.partyWindow()
	local L = UiLayout.partyWindow(C)
	local W, H = C.PartyWindow.W, C.PartyWindow.H
	local window, body, close =
		Style.window("Party", Style.Themes.Green, "CREATE PARTY", W, H, C.HeaderH, C.CloseButton.W)
	sized(window, W, H, Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5))
	window.Visible = false

	local function button(name: string, t: Style.Theme, text: string, r: UiLayout.Rect): (TextButton, Frame)
		local holder, hit, face = Style.button(name, t, text)
		placeRect(holder, r)
		holder.Parent = body
		return hit, face
	end

	local prev = button("Prev", Style.Themes.LightBlue, "<", L.Prev)
	local nextButton = button("Next", Style.Themes.LightBlue, ">", L.Next)
	local mapHolder, mapFace = Style.panel("MapCard", Style.Themes.Yellow, 18)
	placeRect(mapHolder, L.MapCard)
	local cardW = L.MapCard.X1 - L.MapCard.X0 - 24
	local chapter = Style.label("Chapter", "")
	sized(chapter, cardW, 32, Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 10))
	chapter.Parent = mapFace
	local mapName = Style.label("Name", "")
	sized(mapName, cardW, 40, Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 48))
	mapName.Parent = mapFace
	mapHolder.Parent = body

	local difficulties: { DifficultyButton } = {}
	for index, r in L.Difficulty do
		local holder, hit, face = Style.button("Difficulty" .. index, Style.Themes.Gray, "")
		placeRect(holder, r)
		local w = C.DifficultyButton.W - 12
		local title = Style.label("Title", "")
		sized(title, w, 40, Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 8))
		title.Parent = face
		local sub = Style.label("Sub", "")
		sub.TextColor3 = Color3.fromRGB(255, 247, 194)
		sized(sub, w, C.TextRow, Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -8))
		sub.Parent = face
		holder.Parent = body
		difficulties[index] = { Holder = holder, Hit = hit, Face = face, Title = title, Sub = sub }
	end

	local sizeLabel = Style.label("PartyLabel", "PARTY")
	placeRect(sizeLabel, {
		X0 = L.SizeLabel.X0,
		Y0 = L.SizeLabel.Y0 + (L.SizeLabel.Y1 - L.SizeLabel.Y0) / 4,
		X1 = L.SizeLabel.X1,
		Y1 = L.SizeLabel.Y1 - (L.SizeLabel.Y1 - L.SizeLabel.Y0) / 4,
	})
	sizeLabel.Parent = body
	local minus = button("Minus", Style.Themes.Yellow, "-", L.Minus)
	local sizeHolder, sizeFace = Style.panel("Size", Style.Themes.Blue, 14)
	placeRect(sizeHolder, L.Size)
	local size = Style.label("Value", "4")
	size.AnchorPoint = Vector2.new(0.5, 0.5)
	size.Position = UDim2.fromScale(0.5, 0.5)
	size.Size = UDim2.fromScale(0.86, 0.6)
	size.Parent = sizeFace
	sizeHolder.Parent = body
	local plus = button("Plus", Style.Themes.Yellow, "+", L.Plus)

	local back = button("Back", Style.Themes.Red, "BACK", L.Back)
	local create, createFace = button("Create", Style.Themes.Green, "CREATE", L.Create)

	local savedTitle = Style.label("SavedTitle", "SAVED RUNS")
	placeRect(savedTitle, L.SavedTitle)
	savedTitle.Parent = body
	local list = Instance.new("ScrollingFrame")
	list.Name = "SavedList"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.ScrollingDirection = Enum.ScrollingDirection.Y
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ZIndex = 4
	placeRect(list, L.SavedList)
	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, C.Gap)
	listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = list
	local listPadding = Instance.new("UIPadding")
	listPadding.PaddingTop = UDim.new(0, 4)
	listPadding.PaddingBottom = UDim.new(0, 8)
	listPadding.Parent = list
	list.Parent = body
	local empty = Style.label("Empty", "No saved runs yet")
	sized(empty, L.SavedList.X1 - L.SavedList.X0, C.TextRow, Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 24))
	empty.Parent = list

	return {
		Window = window,
		Close = close,
		Prev = prev,
		Next = nextButton,
		MapFace = mapFace,
		Chapter = chapter,
		MapName = mapName,
		Difficulties = difficulties,
		Minus = minus,
		Plus = plus,
		Size = size,
		Back = back,
		Create = create,
		CreateFace = createFace,
		CreateText = createFace:FindFirstChild("Text") :: TextLabel,
		SavedList = list,
		SavedEmpty = empty,
	}
end

function Screens.build(parent: Instance): Refs
	local gui = Instance.new("ScreenGui")
	gui.Name = "EatCityUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false -- começa abaixo da barra do Roblox (menu/chat)
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets -- e longe de entalhes/cantos arredondados do celular
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local scaled: { GuiObject } = {}
	local function add(obj: GuiObject)
		table.insert(scaled, obj)
		obj.Parent = gui
	end
	local gap = C.Gap

	-- Moedas e gemas (topo esquerdo) ------------------------------------------------
	local cashHolder, cash = currency("Cash", Style.Themes.Green, "💵")
	sized(cashHolder, C.Currency.W, C.Currency.H, Vector2.zero, UDim2.fromOffset(C.Margin, C.Margin))
	add(cashHolder)
	local gemsHolder, gems = currency("Gems", Style.Themes.LightBlue, "💎")
	-- a posição real (ao lado do dinheiro) é ajustada pelo controlador conforme a escala
	sized(gemsHolder, C.Currency.W, C.Currency.H, Vector2.zero, UDim2.fromOffset(C.Margin, C.Margin))
	add(gemsHolder)
	-- no lobby não existe dinheiro (é da run): no lugar dele aparecem as vitórias
	local winsHolder, wins = currency("Wins", Style.Themes.Yellow, "🏆")
	sized(winsHolder, C.Currency.W, C.Currency.H, Vector2.zero, UDim2.fromOffset(C.Margin, C.Margin))
	winsHolder.Visible = false
	add(winsHolder)

	-- Coluna de atalhos -------------------------------------------------------------
	local icons = Instance.new("Frame")
	icons.Name = "Icons"
	icons.BackgroundTransparency = 1
	sized(
		icons,
		C.IconButton.W,
		C.IconCount * C.IconButton.H + (C.IconCount - 1) * gap,
		Vector2.zero,
		UDim2.fromOffset(C.Margin, C.Margin)
	)
	local function iconAt(index: number, t: Style.Theme, icon: string, text: string): (Frame, TextButton)
		local holder, hit = Style.iconButton(text, t, icon, text)
		sized(
			holder,
			C.IconButton.W,
			C.IconButton.H,
			Vector2.zero,
			UDim2.fromOffset(0, (index - 1) * (C.IconButton.H + gap))
		)
		holder.Parent = icons
		return holder, hit
	end
	local shopHolder, shopIcon = iconAt(1, Style.Themes.Yellow, "🛒", "SHOP")
	local spinHolder, spinIcon = iconAt(2, Style.Themes.Pink, "🎡", "SPIN")
	local rewardsHolder, rewardsIcon = iconAt(3, Style.Themes.Green, "🎁", "GIFT")
	local classesHolder, classesIcon = iconAt(4, Style.Themes.Purple, "⚔️", "CLASS")
	local spinBadge = badge(spinHolder)
	local rewardsBadge = badge(rewardsHolder)
	add(icons)

	-- Progresso da run (topo centro): "42% EATEN", nome do mapa e barra --------------
	local timerHolder, timerFace = Style.panel("Timer", Style.Themes.Blue)
	sized(timerHolder, C.Timer.W, C.Timer.H, Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, C.Margin))
	local timer = Style.label("Time", "0% EATEN")
	sized(timer, C.Timer.W - 24, 38, Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 4))
	timer.Parent = timerFace
	local mapName = Style.label("Map", "")
	mapName.TextColor3 = Color3.fromRGB(255, 227, 107)
	sized(mapName, C.Timer.W - 24, C.TextRow, Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 42))
	mapName.Parent = timerFace
	local track = Instance.new("Frame")
	track.Name = "Progress"
	track.BackgroundColor3 = Color3.fromRGB(16, 26, 70)
	track.BorderSizePixel = 0
	track.ZIndex = 5
	sized(track, C.Timer.W - 40, 8, Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -6))
	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(1, 0)
	trackCorner.Parent = track
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = Color3.fromRGB(255, 211, 61)
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	fill.ZIndex = 6
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill
	fill.Parent = track
	track.Parent = timerFace
	timerHolder.Visible = false
	add(timerHolder)

	-- Barra da run (embaixo): upgrades e voltar ao lobby -------------------------------
	local matchW = C.UpgradesButton.W + C.LobbyButton.W + gap
	local matchBar = Instance.new("Frame")
	matchBar.Name = "MatchBar"
	matchBar.BackgroundTransparency = 1
	sized(matchBar, matchW, C.UpgradesButton.H, Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -C.Margin))
	local upgradesHolder, upgradesButton = Style.button("Upgrades", Style.Themes.Yellow, "⬆️ UPGRADES")
	sized(upgradesHolder, C.UpgradesButton.W, C.UpgradesButton.H, Vector2.zero, UDim2.fromOffset(0, 0))
	upgradesHolder.Parent = matchBar
	local lobbyHolder, lobbyButton, lobbyFace = Style.button("Lobby", Style.Themes.Red, "🏠 LOBBY")
	sized(
		lobbyHolder,
		C.LobbyButton.W,
		C.LobbyButton.H,
		Vector2.zero,
		UDim2.fromOffset(C.UpgradesButton.W + gap, C.UpgradesButton.H - C.LobbyButton.H)
	)
	lobbyHolder.Parent = matchBar
	matchBar.Visible = false
	add(matchBar)

	-- Janela da loja -----------------------------------------------------------------
	local shop, shopBody, shopClose, shopTitle =
		Style.window("Shop", Style.Themes.Red, "SHOP", C.Window.W, C.Window.H, C.HeaderH, C.CloseButton.W)
	sized(shop, C.Window.W, C.Window.H, Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5))
	shop.Visible = false
	local shopGems = Style.label("GemsLabel", "💎 0")
	shopGems.TextColor3 = Color3.fromRGB(200, 240, 255)
	shopGems.TextXAlignment = Enum.TextXAlignment.Right
	sized(shopGems, 220, 46, Vector2.new(1, 0.5), UDim2.new(1, -(C.CloseButton.W + 20), 0.5, 0))
	shopGems.Parent = shopTitle.Parent :: Frame
	local tabs: { [string]: { Hit: TextButton, Face: Frame } } = {}
	local tabThemes = {
		{ "ITEMS", Style.Themes.LightBlue },
		{ "CLASSES", Style.Themes.Purple },
		{ "ROBUX", Style.Themes.Green },
	}
	for index, spec in tabThemes do
		local holder, hit, face = Style.button(spec[1], spec[2] :: Style.Theme, spec[1] :: string)
		sized(
			holder,
			C.Tab.W,
			C.Tab.H,
			Vector2.zero,
			UDim2.fromOffset(gap * 2 + (index - 1) * (C.Tab.W + gap), C.HeaderH + gap)
		)
		holder.Parent = shopBody
		tabs[spec[1] :: string] = { Hit = hit, Face = face }
	end
	local content = Instance.new("ScrollingFrame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.ScrollBarThickness = 8
	content.ScrollingDirection = Enum.ScrollingDirection.Y
	content.AutomaticCanvasSize = Enum.AutomaticSize.Y
	content.CanvasSize = UDim2.new()
	local contentTop = C.HeaderH + C.Tab.H + gap * 2
	content.Position = UDim2.fromOffset(gap, contentTop)
	content.Size = UDim2.new(1, -gap * 2, 1, -contentTop - gap)
	content.ZIndex = 4
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(C.Card.W, C.Card.H)
	grid.CellPadding = UDim2.fromOffset(gap, gap + 6)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = content
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 12)
	padding.Parent = content
	content.Parent = shopBody
	add(shop)

	-- Janela de upgrades (compra com dinheiro no meio da partida) ----------------------
	local upgrades, upgradesBody, upgradesClose, upgradesTitle = Style.window(
		"Upgrades",
		Style.Themes.Yellow,
		"UPGRADES",
		C.UpgradeWindow.W,
		C.UpgradeWindow.H,
		C.HeaderH,
		C.CloseButton.W
	)
	sized(upgrades, C.UpgradeWindow.W, C.UpgradeWindow.H, Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5))
	upgrades.Visible = false
	local upgradesCash = Style.label("CashLabel", "💵 0")
	upgradesCash.TextColor3 = Color3.fromRGB(205, 255, 205)
	upgradesCash.TextXAlignment = Enum.TextXAlignment.Right
	sized(upgradesCash, 260, 46, Vector2.new(1, 0.5), UDim2.new(1, -(C.CloseButton.W + 20), 0.5, 0))
	upgradesCash.Parent = upgradesTitle.Parent :: Frame
	local upgradesContent = Instance.new("ScrollingFrame")
	upgradesContent.Name = "Content"
	upgradesContent.BackgroundTransparency = 1
	upgradesContent.BorderSizePixel = 0
	upgradesContent.ScrollBarThickness = 8
	upgradesContent.ScrollingDirection = Enum.ScrollingDirection.Y
	upgradesContent.AutomaticCanvasSize = Enum.AutomaticSize.Y
	upgradesContent.CanvasSize = UDim2.new()
	upgradesContent.Position = UDim2.fromOffset(gap, C.HeaderH + gap)
	upgradesContent.Size = UDim2.new(1, -gap * 2, 1, -C.HeaderH - gap * 2)
	upgradesContent.ZIndex = 4
	local upgradesGrid = Instance.new("UIGridLayout")
	upgradesGrid.CellSize = UDim2.fromOffset(C.Card.W, C.Card.H)
	upgradesGrid.CellPadding = UDim2.fromOffset(gap, gap)
	upgradesGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	upgradesGrid.SortOrder = Enum.SortOrder.LayoutOrder
	upgradesGrid.Parent = upgradesContent
	upgradesContent.Parent = upgradesBody
	add(upgrades)

	-- Janela da roleta ----------------------------------------------------------------
	local wheel, wheelBody, wheelClose =
		Style.window("Wheel", Style.Themes.Pink, "LUCKY WHEEL", C.Window.W, C.Window.H, C.HeaderH, C.CloseButton.W)
	sized(wheel, C.Window.W, C.Window.H, Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5))
	wheel.Visible = false
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "WheelView"
	viewport.BackgroundTransparency = 1
	viewport.Ambient = Color3.fromRGB(200, 200, 210)
	viewport.LightColor = Color3.new(1, 1, 1)
	sized(viewport, C.WheelView, C.WheelView, Vector2.new(0, 0.5), UDim2.new(0, gap * 2, 0.5, C.HeaderH / 2))
	viewport.ZIndex = 4
	viewport.Parent = wheelBody
	-- Nomes dos prêmios por cima da roda (o ViewportFrame não mostra textos 3D).
	-- O controlador posiciona e gira este quadro junto com a roda.
	local wheelLabels = Instance.new("Frame")
	wheelLabels.Name = "WheelLabels"
	wheelLabels.BackgroundTransparency = 1
	wheelLabels.AnchorPoint = Vector2.new(0.5, 0.5)
	wheelLabels.Size = UDim2.fromOffset(C.WheelView, C.WheelView)
	wheelLabels.Position = UDim2.fromScale(0.5, 0.5)
	wheelLabels.ZIndex = 6
	local segments = WheelConfig.Segments
	local prize = C.WheelPrize
	for index, segment in segments do
		local angle = (index - 0.5) * (2 * math.pi / #segments) -- sentido horário a partir do topo
		local dx, dy = math.sin(angle), -math.cos(angle)
		-- ícone grande perto da borda, "em pé" na fatia
		local icon = Style.label("PrizeIcon" .. index, segment.Icon)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Size = UDim2.fromScale(prize.IconSize, prize.IconSize)
		icon.Position = UDim2.fromScale(0.5 + dx * prize.IconRadius / 2, 0.5 + dy * prize.IconRadius / 2)
		icon.Rotation = math.deg(angle)
		icon.ZIndex = 7
		icon.Parent = wheelLabels
		-- texto curto ao longo do raio; na metade esquerda vira para não ficar de cabeça para baixo
		local mid = (prize.TextFrom + prize.TextTo) / 2
		local text = Style.label("PrizeText" .. index, segment.Short)
		text.AnchorPoint = Vector2.new(0.5, 0.5)
		text.Size = UDim2.fromScale((prize.TextTo - prize.TextFrom) / 2, prize.TextThickness)
		text.Position = UDim2.fromScale(0.5 + dx * mid / 2, 0.5 + dy * mid / 2)
		text.Rotation = math.deg(angle) + (if angle <= math.pi then -90 else 90)
		text.ZIndex = 7
		text.Parent = wheelLabels
	end
	wheelLabels.Parent = viewport
	local wheelButtons: { [string]: WheelButton } = {}
	local wheelSpecs = {
		{ "Free", Style.Themes.Green, "FREE SPIN", "Ready!" },
		{ "Extra", Style.Themes.Yellow, "USE SPIN", "x0 saved" },
		{ "Gems", Style.Themes.LightBlue, "💎 75", "1 Spin" },
		{ "Robux", Style.Themes.Green, Style.Robux .. " 25", "1 Spin" },
	}
	local buttonsTop = C.HeaderH + (C.Window.H - C.HeaderH - (4 * C.WheelButton.H + 3 * gap)) / 2
	for index, spec in wheelSpecs do
		local holder, hit, face = Style.button(spec[1] :: string, spec[2] :: Style.Theme, "")
		sized(
			holder,
			C.WheelButton.W,
			C.WheelButton.H,
			Vector2.new(1, 0),
			UDim2.new(1, -gap * 2, 0, buttonsTop + (index - 1) * (C.WheelButton.H + gap))
		)
		local title = Style.label("Title", spec[3] :: string)
		sized(title, C.WheelButton.W - 30, 44, Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 8))
		title.Parent = face
		local sub = Style.label("Sub", spec[4] :: string)
		sub.TextColor3 = Color3.fromRGB(255, 247, 194)
		sized(sub, C.WheelButton.W - 30, 26, Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -8))
		sub.Parent = face
		holder.Parent = wheelBody
		wheelButtons[spec[1] :: string] = { Holder = holder, Hit = hit, Face = face, Title = title, Sub = sub }
	end
	add(wheel)

	-- Janela de recompensas ---------------------------------------------------------------
	local rewards, rewardsBody, rewardsClose =
		Style.window("Rewards", Style.Themes.Green, "DAILY REWARDS", C.Window.W, C.Window.H, C.HeaderH, C.CloseButton.W)
	sized(rewards, C.Window.W, C.Window.H, Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5))
	rewards.Visible = false
	local dayTiles: { DayTile } = {}
	local tilesW = 7 * C.DayTile.W + 6 * gap
	for day = 1, 7 do
		local holder, face = Style.panel("Day" .. day, Style.Themes.LightBlue, 18)
		sized(
			holder,
			C.DayTile.W,
			C.DayTile.H,
			Vector2.zero,
			UDim2.fromOffset((C.Window.W - tilesW) / 2 + (day - 1) * (C.DayTile.W + gap), C.HeaderH + gap * 2)
		)
		local dayLabel = Style.label("Day", "DAY " .. day)
		sized(dayLabel, C.DayTile.W - 10, 28, Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 8))
		dayLabel.Parent = face
		local icon = Style.label("Icon", "🎁")
		sized(icon, 62, 62, Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 40))
		icon.Parent = face
		local text = Style.label("Label", "")
		sized(text, C.DayTile.W - 10, 30, Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -8))
		text.Parent = face
		holder.Parent = rewardsBody
		dayTiles[day] = { Holder = holder, Face = face, Day = dayLabel, Icon = icon, Label = text }
	end
	local lowerTop = C.HeaderH + gap * 4 + C.DayTile.H
	local claimHolder, claimDaily, claimFace = Style.button("ClaimDaily", Style.Themes.Green, "CLAIM")
	sized(
		claimHolder,
		C.ClaimButton.W,
		C.ClaimButton.H,
		Vector2.zero,
		UDim2.fromOffset(gap * 3, lowerTop + (C.WeeklyPanel.H - C.ClaimButton.H) / 2)
	)
	claimHolder.Parent = rewardsBody
	local weeklyHolder, weeklyFace = Style.panel("Weekly", Style.Themes.Purple, 20)
	Style.stripes(weeklyFace)
	sized(weeklyHolder, C.WeeklyPanel.W, C.WeeklyPanel.H, Vector2.new(1, 0), UDim2.new(1, -gap * 3, 0, lowerTop))
	local weeklyTitle = Style.label("Title", "WEEKLY CHEST")
	sized(weeklyTitle, C.WeeklyPanel.W - 30, 34, Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 8))
	weeklyTitle.Parent = weeklyFace
	local weekly = Style.label("Rewards", "")
	sized(weekly, C.WeeklyPanel.W - 30, 40, Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 48))
	weekly.Parent = weeklyFace
	local weeklyClaimHolder, claimWeekly, weeklyClaimFace = Style.button("ClaimWeekly", Style.Themes.Green, "CLAIM")
	sized(weeklyClaimHolder, C.WeeklyPanel.W - 40, C.ClaimButton.H, Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -10))
	weeklyClaimHolder.Parent = weeklyFace
	weeklyHolder.Parent = rewardsBody
	add(rewards)

	-- Janela CREATE PARTY (lobby) ----------------------------------------------------------
	local party = Screens.partyWindow()
	add(party.Window)

	-- Vitória da run ---------------------------------------------------------------------
	local winner, winnerFace = Style.panel("Winner", Style.Themes.Yellow, 24)
	Style.stripes(winnerFace)
	sized(winner, C.WinnerBanner.W, C.WinnerBanner.H, Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.35))
	winner.Visible = false
	local winnerName = Style.label("Name", "")
	sized(winnerName, C.WinnerBanner.W - 60, 90, Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 12))
	winnerName.Parent = winnerFace
	local winnerSub = Style.label("Sub", "")
	sized(winnerSub, C.WinnerBanner.W - 100, 40, Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -14))
	winnerSub.Parent = winnerFace
	add(winner)

	-- FRENZY: embaixo do progresso da área (posição real vem do UiLayout) ------------------------
	local frenzyHolder, frenzyFace = Style.panel("Frenzy", Style.Themes.Orange, 14)
	sized(frenzyHolder, C.Frenzy.W, C.Frenzy.H, Vector2.zero, UDim2.fromOffset(0, 0))
	local frenzyText = Style.label("Text", "⚡ FRENZY 20s")
	frenzyText.AnchorPoint = Vector2.new(0.5, 0.5)
	frenzyText.Position = UDim2.fromScale(0.5, 0.5)
	frenzyText.Size = UDim2.fromScale(0.86, 0.6)
	frenzyText.Parent = frenzyFace
	frenzyHolder.Visible = false
	add(frenzyHolder)

	-- Comemoração de área limpa: raios girando atrás, painel com título, próxima área e três prêmios ------
	local CW, CH = C.Celebration.W, C.Celebration.H
	local celebration = Instance.new("Frame")
	celebration.Name = "Celebration"
	celebration.BackgroundTransparency = 1
	sized(celebration, CW, CH, Vector2.zero, UDim2.fromOffset(0, 0))
	celebration.Visible = false
	local rays = Instance.new("Frame")
	rays.Name = "Rays"
	rays.BackgroundTransparency = 1
	rays.AnchorPoint = Vector2.new(0.5, 0.5)
	rays.Position = UDim2.fromScale(0.5, 0.5)
	rays.Size = UDim2.fromOffset(0, 0)
	for k = 0, 7 do
		local ray = Instance.new("Frame")
		ray.Name = "Ray"
		ray.AnchorPoint = Vector2.new(0.5, 0.5)
		ray.Size = UDim2.fromOffset(CW * 2.4, 70)
		ray.Rotation = k * 22.5
		ray.BackgroundColor3 = Color3.fromRGB(255, 240, 160)
		ray.BackgroundTransparency = 0.72
		ray.BorderSizePixel = 0
		ray.ZIndex = 0
		local fade = Instance.new("UIGradient")
		fade.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(1, 1),
		})
		fade.Parent = ray
		ray.Parent = rays
	end
	rays.Parent = celebration
	local celebPanel, celebFace = Style.panel("Panel", Style.Themes.Yellow, 26)
	Style.stripes(celebFace)
	celebPanel.Size = UDim2.fromScale(1, 1)
	celebPanel.Parent = celebration
	local celebTitle = Style.label("Title", "AREA CLEARED!")
	sized(celebTitle, CW - 60, 90, Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 22))
	celebTitle.Parent = celebFace
	local celebSub = Style.label("Sub", "")
	sized(celebSub, CW - 40, 40, Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 120))
	celebSub.Parent = celebFace
	local chips: { TextLabel } = {}
	local chipW, chipH, chipGap = C.RewardChip.W, C.RewardChip.H, 24
	local chipsX = (CW - (3 * chipW + 2 * chipGap)) / 2
	for i, theme in { Style.Themes.LightBlue, Style.Themes.Green, Style.Themes.Pink } do
		local chip, chipFace = Style.panel("Chip" .. i, theme, 14)
		sized(chip, chipW, chipH, Vector2.zero, UDim2.fromOffset(chipsX + (i - 1) * (chipW + chipGap), CH - 24 - chipH))
		local text = Style.label("Text", "")
		text.AnchorPoint = Vector2.new(0.5, 0.5)
		text.Position = UDim2.fromScale(0.5, 0.5)
		text.Size = UDim2.fromScale(0.9, 0.6)
		text.Parent = chipFace
		chip.Parent = celebFace
		chips[i] = text
	end
	add(celebration)
	-- CONTINUE: embaixo do painel (fecha antes do tempo). Tamanho em pixels vem do UiLayout (nunca menor que
	-- o polegar), por isso fica fora da escala geral.
	local continueHolder, continueButton = Style.button("Continue", Style.Themes.Green, "CONTINUE ▶")
	continueHolder.Size = UDim2.fromOffset(C.ContinueButton.W, C.ContinueButton.H)
	continueHolder.Visible = false
	continueHolder.Parent = gui
	-- confete cobre a tela inteira (não escala com a interface)
	local confetti = Instance.new("Frame")
	confetti.Name = "Confetti"
	confetti.BackgroundTransparency = 1
	confetti.Size = UDim2.fromScale(1, 1)
	confetti.ZIndex = 20
	confetti.Parent = gui

	-- Avisos, combo, status, prêmio -------------------------------------------------------
	local toast = Style.label("Toast", "")
	sized(toast, C.Toast.W, C.Toast.H, Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, C.Toast.Y))
	toast.Visible = false
	add(toast)
	local combo = Style.label("Combo", "")
	combo.TextColor3 = Color3.fromRGB(255, 227, 107)
	sized(combo, C.Combo.W, C.Combo.H, Vector2.new(0.5, 0.5), UDim2.fromScale(0.72, 0.6))
	combo.Visible = false
	add(combo)
	local status = Style.label("Status", "")
	sized(status, 800, 60, Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5))
	status.Visible = false
	add(status)
	local popup, popupFace = Style.panel("Popup", Style.Themes.Yellow, 22)
	Style.stripes(popupFace)
	sized(popup, C.Popup.W, C.Popup.H, Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, C.Toast.Y + C.Toast.H + 20))
	popup.Visible = false
	local popupIcon = Style.label("Icon", "🎁")
	sized(popupIcon, 96, 96, Vector2.new(0, 0.5), UDim2.new(0, 18, 0.5, 0))
	popupIcon.Parent = popupFace
	local popupText = Style.label("Text", "")
	popupText.TextXAlignment = Enum.TextXAlignment.Left
	sized(popupText, C.Popup.W - 140, 70, Vector2.new(0, 0.5), UDim2.new(0, 124, 0.5, 0))
	popupText.Parent = popupFace
	add(popup)

	gui.Parent = parent

	return {
		Gui = gui,
		Scaled = scaled,
		Cash = cash,
		CashHolder = cashHolder,
		Gems = gems,
		GemsHolder = gemsHolder,
		Wins = wins,
		WinsHolder = winsHolder,
		Icons = icons,
		ShopIcon = shopIcon,
		SpinIcon = spinIcon,
		RewardsIcon = rewardsIcon,
		ClassesIcon = classesIcon,
		IconHolders = { shopHolder, spinHolder, rewardsHolder, classesHolder },
		RewardsBadge = rewardsBadge,
		SpinBadge = spinBadge,
		TimerHolder = timerHolder,
		Timer = timer,
		MapName = mapName,
		ProgressFill = fill,
		Shop = shop,
		ShopClose = shopClose,
		ShopTabs = tabs,
		ShopContent = content,
		ShopGems = shopGems,
		Wheel = wheel,
		WheelClose = wheelClose,
		MatchBar = matchBar,
		UpgradesButton = upgradesButton,
		LobbyButton = lobbyButton,
		LobbyButtonFace = lobbyFace,
		LobbyButtonText = lobbyFace:FindFirstChild("Text") :: TextLabel,
		Upgrades = upgrades,
		UpgradesClose = upgradesClose,
		UpgradesContent = upgradesContent,
		UpgradesCash = upgradesCash,
		WheelViewport = viewport,
		WheelLabels = wheelLabels,
		WheelButtons = wheelButtons,
		Rewards = rewards,
		RewardsClose = rewardsClose,
		DayTiles = dayTiles,
		ClaimDaily = claimDaily,
		ClaimDailyText = claimFace:FindFirstChild("Text") :: TextLabel,
		ClaimDailyFace = claimFace,
		Weekly = weekly,
		ClaimWeekly = claimWeekly,
		ClaimWeeklyText = weeklyClaimFace:FindFirstChild("Text") :: TextLabel,
		ClaimWeeklyFace = weeklyClaimFace,
		Party = party.Window,
		PartyClose = party.Close,
		PartyPrev = party.Prev,
		PartyNext = party.Next,
		PartyMapFace = party.MapFace,
		PartyChapter = party.Chapter,
		PartyMapName = party.MapName,
		PartyDifficulties = party.Difficulties,
		PartyMinus = party.Minus,
		PartyPlus = party.Plus,
		PartySize = party.Size,
		PartyBack = party.Back,
		PartyCreate = party.Create,
		PartyCreateFace = party.CreateFace,
		PartyCreateText = party.CreateText,
		SavedList = party.SavedList,
		SavedEmpty = party.SavedEmpty,
		Winner = winner,
		WinnerName = winnerName,
		WinnerSub = winnerSub,
		Toast = toast,
		Combo = combo,
		Status = status,
		Frenzy = frenzyHolder,
		FrenzyText = frenzyText,
		Celebration = celebration,
		CelebrationTitle = celebTitle,
		CelebrationSub = celebSub,
		Chips = chips,
		Rays = rays,
		Continue = continueButton,
		ContinueHolder = continueHolder,
		Confetti = confetti,
		Popup = popup,
		PopupIcon = popupIcon,
		PopupText = popupText,
	}
end

return Screens
