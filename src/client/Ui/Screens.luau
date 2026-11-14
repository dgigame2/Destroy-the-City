--!strict
-- Monta todas as telas (só aparência, sem lógica). Os controladores ligam tudo ao jogo.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UiConfig = require(Shared.Config.UiConfig)

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

export type VoteCard = {
	Holder: Frame,
	Hit: TextButton,
	Icon: TextLabel,
	Name: TextLabel,
	Votes: TextLabel,
	Stroke: UIStroke,
}
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
	Icons: Frame,
	ShopIcon: TextButton,
	SpinIcon: TextButton,
	RewardsIcon: TextButton,
	ClassesIcon: TextButton,
	RewardsBadge: TextLabel,
	SpinBadge: TextLabel,
	TimerHolder: Frame,
	Timer: TextLabel,
	MapName: TextLabel,
	-- Lobby
	LobbyBar: Frame,
	Play: TextButton,
	PlayText: TextLabel,
	Spectate: TextButton,
	SpectateText: TextLabel,
	AutoJoin: TextButton,
	AutoJoinText: TextLabel,
	AutoJoinFace: Frame,
	SpectatingLabel: TextLabel,
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
	-- Partida
	Vote: Frame,
	VoteTimer: TextLabel,
	VoteCards: { VoteCard },
	Winner: Frame,
	WinnerName: TextLabel,
	WinnerSub: TextLabel,
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
	sized(iconLabel, 110, 100, Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 52))
	iconLabel.Parent = face
	local subtitleLabel = Style.label("Subtitle", subtitle)
	subtitleLabel.TextColor3 = Color3.fromRGB(255, 247, 194)
	sized(subtitleLabel, C.Card.W - 20, 40, Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 156))
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

function Screens.build(parent: Instance): Refs
	local gui = Instance.new("ScreenGui")
	gui.Name = "EatCityUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false -- começa abaixo da barra do Roblox (menu/chat)
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
	-- a posição real (abaixo do dinheiro) é ajustada pelo controlador conforme a escala
	sized(gemsHolder, C.Currency.W, C.Currency.H, Vector2.zero, UDim2.fromOffset(C.Margin, C.Margin))
	add(gemsHolder)

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
	local _, shopIcon = iconAt(1, Style.Themes.Yellow, "🛒", "SHOP")
	local spinHolder, spinIcon = iconAt(2, Style.Themes.Pink, "🎡", "SPIN")
	local rewardsHolder, rewardsIcon = iconAt(3, Style.Themes.Green, "🎁", "REWARDS")
	local _, classesIcon = iconAt(4, Style.Themes.Purple, "⚔️", "CLASSES")
	local spinBadge = badge(spinHolder)
	local rewardsBadge = badge(rewardsHolder)
	add(icons)

	-- Relógio / status (topo centro) ------------------------------------------------
	local timerHolder, timerFace = Style.panel("Timer", Style.Themes.Blue)
	sized(timerHolder, C.Timer.W, C.Timer.H, Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, C.Margin))
	local timer = Style.label("Time", "LOBBY")
	sized(timer, C.Timer.W - 24, 42, Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 4))
	timer.Parent = timerFace
	local mapName = Style.label("Map", "")
	mapName.TextColor3 = Color3.fromRGB(255, 227, 107)
	sized(mapName, C.Timer.W - 24, 24, Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -6))
	mapName.Parent = timerFace
	add(timerHolder)

	-- Barra do lobby (embaixo) -------------------------------------------------------
	local barW = C.Play.W + C.Spectate.W + C.AutoJoin.W + 2 * gap
	local lobbyBar = Instance.new("Frame")
	lobbyBar.Name = "LobbyBar"
	lobbyBar.BackgroundTransparency = 1
	sized(lobbyBar, barW, C.Play.H, Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -C.Margin))
	local playHolder, play, playFace = Style.button("Play", Style.Themes.Green, "▶ PLAY")
	sized(playHolder, C.Play.W, C.Play.H, Vector2.zero, UDim2.fromOffset(0, 0))
	playHolder.Parent = lobbyBar
	local spectateHolder, spectate, spectateFace = Style.button("Spectate", Style.Themes.LightBlue, "👁 SPECTATE")
	sized(
		spectateHolder,
		C.Spectate.W,
		C.Spectate.H,
		Vector2.zero,
		UDim2.fromOffset(C.Play.W + gap, C.Play.H - C.Spectate.H)
	)
	spectateHolder.Parent = lobbyBar
	local autoHolder, autoJoin, autoFace = Style.button("AutoJoin", Style.Themes.Gray, "AUTO JOIN: ON")
	sized(
		autoHolder,
		C.AutoJoin.W,
		C.AutoJoin.H,
		Vector2.zero,
		UDim2.fromOffset(C.Play.W + C.Spectate.W + 2 * gap, C.Play.H - C.AutoJoin.H)
	)
	autoHolder.Parent = lobbyBar
	add(lobbyBar)
	local spectating = Style.label("Spectating", "")
	sized(spectating, 600, 44, Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -(C.Margin + C.Play.H + gap)))
	spectating.Visible = false
	add(spectating)

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
		{ "UPGRADES", Style.Themes.Yellow },
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

	-- Votação -----------------------------------------------------------------------------
	local voteW = 3 * C.VoteCard.W + 2 * gap * 2
	local vote = Instance.new("Frame")
	vote.Name = "Vote"
	vote.BackgroundTransparency = 1
	sized(vote, voteW, C.VoteTitleH + gap + C.VoteCard.H, Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5))
	vote.Visible = false
	local voteTitle = Style.label("Title", "VOTE FOR THE NEXT MAP")
	sized(voteTitle, voteW, 60, Vector2.new(0.5, 0), UDim2.fromScale(0.5, 0))
	voteTitle.Parent = vote
	local voteTimer = Style.label("Timer", "0:15")
	voteTimer.TextColor3 = Color3.fromRGB(255, 227, 107)
	sized(voteTimer, 200, 40, Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 64))
	voteTimer.Parent = vote
	local themes = { Style.Themes.Green, Style.Themes.LightBlue, Style.Themes.Purple }
	local voteCards: { VoteCard } = {}
	for i = 1, 3 do
		local holder, hit, face = Style.button("Option" .. i, themes[i], "")
		Style.stripes(face)
		sized(
			holder,
			C.VoteCard.W,
			C.VoteCard.H,
			Vector2.zero,
			UDim2.fromOffset((i - 1) * (C.VoteCard.W + gap * 2), C.VoteTitleH + gap)
		)
		local icon = Style.label("Icon", "🏙️")
		sized(icon, C.VoteCard.W - 60, 180, Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 24))
		icon.Parent = face
		local name = Style.label("MapName", "Map")
		sized(name, C.VoteCard.W - 30, 52, Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 226))
		name.Parent = face
		local votes = Style.label("Votes", "0 votes")
		votes.TextColor3 = Color3.fromRGB(255, 227, 107)
		sized(votes, C.VoteCard.W - 60, 38, Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 292))
		votes.Parent = face
		local selected = Instance.new("UIStroke")
		selected.Name = "Selected"
		selected.Thickness = 6
		selected.Color = Color3.new(1, 1, 1)
		selected.Enabled = false
		selected.Parent = holder:FindFirstChild("Shadow") :: Frame
		holder.Parent = vote
		voteCards[i] = { Holder = holder, Hit = hit, Icon = icon, Name = name, Votes = votes, Stroke = selected }
	end
	add(vote)

	-- Vencedor ----------------------------------------------------------------------------
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
		Icons = icons,
		ShopIcon = shopIcon,
		SpinIcon = spinIcon,
		RewardsIcon = rewardsIcon,
		ClassesIcon = classesIcon,
		RewardsBadge = rewardsBadge,
		SpinBadge = spinBadge,
		TimerHolder = timerHolder,
		Timer = timer,
		MapName = mapName,
		LobbyBar = lobbyBar,
		Play = play,
		PlayText = playFace:FindFirstChild("Text") :: TextLabel,
		Spectate = spectate,
		SpectateText = spectateFace:FindFirstChild("Text") :: TextLabel,
		AutoJoin = autoJoin,
		AutoJoinText = autoFace:FindFirstChild("Text") :: TextLabel,
		AutoJoinFace = autoFace,
		SpectatingLabel = spectating,
		Shop = shop,
		ShopClose = shopClose,
		ShopTabs = tabs,
		ShopContent = content,
		ShopGems = shopGems,
		Wheel = wheel,
		WheelClose = wheelClose,
		WheelViewport = viewport,
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
		Vote = vote,
		VoteTimer = voteTimer,
		VoteCards = voteCards,
		Winner = winner,
		WinnerName = winnerName,
		WinnerSub = winnerSub,
		Toast = toast,
		Combo = combo,
		Status = status,
		Popup = popup,
		PopupIcon = popupIcon,
		PopupText = popupText,
	}
end

return Screens
