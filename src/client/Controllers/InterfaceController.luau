--!strict
-- Integração das telas com o jogo (etapa 3 do goat): HUD, janelas, avisos, progresso e vitória da run.
-- No lobby: gemas, vitórias e atalhos. Na run: dinheiro, gemas, progresso ("% EATEN") e a barra de baixo.
-- Os outros controladores (loja, roleta, recompensas, party) usam a API daqui para abrir janelas e avisar.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UiConfig = require(Shared.Config.UiConfig)
local UiLayout = require(Shared.Logic.UiLayout)
local Zones = require(Shared.Logic.Zones)
local RunConfig = require(Shared.Config.RunConfig)
local Place = require(Shared.Place)
local Remotes = require(Shared.Remotes)

local Screens = require(script.Parent.Parent.Ui.Screens)
local EatEffects = require(script.Parent.EatEffects)
local Feedback = require(script.Parent.Parent.Feedback)

local localPlayer = Players.LocalPlayer

local InterfaceController = {}

local refs: Screens.Refs
local currentScale = 1
local toastToken, comboToken, popupToken = 0, 0, 0
local isRun = Place.isRun()
local openWindow: string? = nil
local onWindowOpened: { [string]: () -> () } = {}

function InterfaceController.refs(): Screens.Refs
	return refs
end

function InterfaceController.scale(): number
	return currentScale
end

function InterfaceController.formatNumber(n: number): string
	local s = tostring(math.floor(n))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1."):reverse()
	return (formatted:gsub("^%.", ""))
end

-- "1:05" / "2h 03m": tempo até a próxima roleta grátis, recompensa etc.
function InterfaceController.formatTime(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	if seconds >= 3600 then
		return string.format("%dh %02dm", seconds // 3600, (seconds % 3600) // 60)
	end
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- Pulinho num elemento escalado (feedback de ganho/compra).
function InterfaceController.bump(target: GuiObject)
	local s = target:FindFirstChildOfClass("UIScale")
	if s == nil then
		return
	end
	s.Scale = currentScale * 1.1
	TweenService
		:Create(s, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = currentScale })
		:Play()
end

local function runState(): string
	return (ReplicatedStorage:GetAttribute("RunState") :: string?) or "Loading"
end

-- HUD visível só sem janela aberta. Lobby: gemas, vitórias e atalhos. Run: dinheiro, gemas, progresso e barra.
local function updateHud()
	local hud = openWindow == nil
	local state = runState()
	refs.CashHolder.Visible = hud and isRun
	refs.GemsHolder.Visible = hud
	refs.WinsHolder.Visible = hud and not isRun
	refs.Icons.Visible = hud and not isRun
	refs.TimerHolder.Visible = hud and isRun and state ~= "Loading"
	refs.MatchBar.Visible = hud and isRun and state == "Playing"
end
InterfaceController.updateHud = updateHud

function InterfaceController.onOpen(name: string, callback: () -> ())
	onWindowOpened[name] = callback
end

local function windows(): { Frame }
	return { refs.Shop, refs.Wheel, refs.Rewards, refs.Upgrades, refs.Party }
end

-- Abre uma janela (fecha a anterior). name: "Shop", "Wheel", "Rewards", "Upgrades" ou "Party".
function InterfaceController.open(name: string)
	for _, window in windows() do
		window.Visible = window.Name == name
	end
	openWindow = name
	local callback = onWindowOpened[name]
	if callback then
		callback()
	end
	InterfaceController.bump((refs :: any)[name])
	updateHud()
end

function InterfaceController.close()
	for _, window in windows() do
		window.Visible = false
	end
	openWindow = nil
	updateHud()
end

function InterfaceController.isOpen(name: string): boolean
	return openWindow == name
end

local function place(obj: GuiObject, r: UiLayout.Rect)
	obj.AnchorPoint = Vector2.zero
	obj.Position = UDim2.fromOffset(r.X0, r.Y0)
end

local function setScale(obj: GuiObject, value: number)
	local s = obj:FindFirstChildOfClass("UIScale")
	if s then
		s.Scale = value
	end
end

-- Posiciona tudo pelo Logic/UiLayout (o mesmo cálculo que os testes verificam em vários aparelhos).
local function updateScale()
	local area = refs.Gui.AbsoluteSize
	if area.X <= 0 or area.Y <= 0 then
		return
	end
	local C = UiConfig
	local layout = UiLayout.place(area.X, area.Y, C)
	currentScale = layout.Scale
	for _, obj in refs.Scaled do
		setScale(obj, currentScale)
	end
	-- janelas: nunca maiores que a tela (celulares bem curtos)
	for _, window in windows() do
		local size = { W = window.Size.X.Offset, H = window.Size.Y.Offset }
		setScale(window, UiLayout.windowScale(area.X, area.Y, size, C))
	end

	-- lobby: gemas no primeiro lugar e vitórias ao lado (o dinheiro só existe na run)
	if isRun then
		place(refs.CashHolder, layout.Cash)
		place(refs.GemsHolder, layout.Gems)
	else
		place(refs.GemsHolder, layout.Cash)
		place(refs.WinsHolder, layout.Gems)
	end
	place(refs.TimerHolder, layout.Timer)
	place(refs.MatchBar, layout.MatchBar)
	place(refs.Toast, layout.Toast)
	refs.Toast.Size = UDim2.fromOffset((layout.Toast.X1 - layout.Toast.X0) / currentScale, C.Toast.H)
	place(refs.Popup, layout.Popup)
	place(refs.Winner, layout.Victory)
	refs.Winner.Size = UDim2.fromOffset((layout.Victory.X1 - layout.Victory.X0) / currentScale, C.WinnerBanner.H)
	place(refs.Frenzy, layout.Frenzy)
	place(refs.Celebration, layout.Celebration)
	place(refs.ContinueHolder, layout.Continue)
	refs.ContinueHolder.Size =
		UDim2.fromOffset(layout.Continue.X1 - layout.Continue.X0, layout.Continue.Y1 - layout.Continue.Y0)
	setScale(refs.Celebration, (layout.Celebration.X1 - layout.Celebration.X0) / C.Celebration.W)

	-- atalhos: 1 coluna ou 2 (telas baixas), preenchidas coluna por coluna
	local columns = layout.IconColumns
	local rows = math.ceil(C.IconCount / columns)
	local cell, gap = C.IconButton.W, C.Gap
	refs.Icons.Size = UDim2.fromOffset(columns * cell + (columns - 1) * gap, rows * cell + (rows - 1) * gap)
	place(refs.Icons, layout.Icons)
	for index, holder in refs.IconHolders do
		local col, r = (index - 1) // rows, (index - 1) % rows
		holder.Position = UDim2.fromOffset(col * (cell + gap), r * (cell + gap))
	end
end

function InterfaceController.toast(text: string, color: Color3?)
	toastToken += 1
	local token = toastToken
	refs.Toast.Text = text
	refs.Toast.TextColor3 = color or Color3.new(1, 1, 1)
	refs.Toast.Visible = true
	InterfaceController.bump(refs.Toast)
	task.delay(2.2, function()
		if toastToken == token then
			refs.Toast.Visible = false
		end
	end)
end

-- Cartão de prêmio (recompensas, roleta, compras).
function InterfaceController.popup(text: string, icon: string)
	popupToken += 1
	local token = popupToken
	refs.PopupText.Text = text
	refs.PopupIcon.Text = icon
	refs.Popup.Visible = true
	InterfaceController.bump(refs.Popup)
	EatEffects.playTierUp()
	Feedback.play("Reward", { Gui = refs.Popup, Text = "+1 " .. icon })
	task.delay(2.6, function()
		if popupToken == token then
			refs.Popup.Visible = false
		end
	end)
end

local function showCombo(count: number)
	if count < 3 then
		return
	end
	comboToken += 1
	local token = comboToken
	refs.Combo.Text = "x" .. count .. " COMBO!"
	refs.Combo.Visible = true
	refs.Combo.Rotation = math.random(-8, 8)
	InterfaceController.bump(refs.Combo)
	task.delay(1.2, function()
		if comboToken == token then
			refs.Combo.Visible = false
		end
	end)
end

local function setupCurrencies()
	-- nil = ainda não leu (não mostra "+tudo" ao entrar)
	local shownCash: number?, shownGems: number? = nil, nil
	local function onCash()
		local cash = (localPlayer:GetAttribute("Coins") :: number?) or 0
		if shownCash and cash > shownCash then
			InterfaceController.bump(refs.CashHolder)
			Feedback.play("Coins", { Gui = refs.CashHolder, Amount = cash - shownCash })
		end
		shownCash = cash
		refs.Cash.Text = InterfaceController.formatNumber(cash)
	end
	local function onWins()
		refs.Wins.Text = InterfaceController.formatNumber((localPlayer:GetAttribute("Wins") :: number?) or 0)
	end
	local function onGems()
		local gems = (localPlayer:GetAttribute("Gems") :: number?) or 0
		if shownGems and gems > shownGems then
			InterfaceController.bump(refs.GemsHolder)
			Feedback.play("Gems", { Gui = refs.GemsHolder, Amount = gems - shownGems })
		end
		shownGems = gems
		refs.Gems.Text = InterfaceController.formatNumber(gems)
		refs.ShopGems.Text = "💎 " .. InterfaceController.formatNumber(gems)
	end
	localPlayer:GetAttributeChangedSignal("Coins"):Connect(onCash)
	localPlayer:GetAttributeChangedSignal("Gems"):Connect(onGems)
	localPlayer:GetAttributeChangedSignal("Wins"):Connect(onWins)
	onCash()
	onGems()
	onWins()
end

-- Progresso da run: "42% EATEN" e a barra.
-- Progresso da área atual: nome da área, "AREA 2 OF 4" e a barra do quanto já foi comido nela.
local function onProgress()
	local zone = (ReplicatedStorage:GetAttribute("RunZone") :: number?) or 1
	local zones = (ReplicatedStorage:GetAttribute("RunZones") :: number?) or 1
	local left = (ReplicatedStorage:GetAttribute("RunZoneLeft") :: number?) or 0
	local total = (ReplicatedStorage:GetAttribute("RunZoneTotal") :: number?) or 0
	-- 98% real aparece como 95% (aos 98% o resto da área é coletado sozinho)
	local percent = Zones.displayPercent(left, total, RunConfig.AutoCollect)
	refs.Timer.Text = (ReplicatedStorage:GetAttribute("RunZoneName") :: string?) or ""
	refs.MapName.Text = `AREA {zone}/{zones} • {percent}%`
	refs.ProgressFill.Size = UDim2.fromScale(percent / 100, 1)
end

-- FRENZY (depois de abrir uma área): contagem regressiva embaixo do progresso.
local function updateFrenzy()
	local untilTime = ReplicatedStorage:GetAttribute("FrenzyUntil") :: number?
	local now = Workspace:GetServerTimeNow()
	local active = isRun and Zones.frenzyActive(untilTime, now)
	refs.Frenzy.Visible = active and openWindow == nil and runState() == "Playing"
	if active then
		refs.FrenzyText.Text = `⚡ FRENZY {math.ceil((untilTime :: number) - now)}s`
	end
end

-- Confete caindo pela tela inteira.
local CONFETTI_COLORS = {
	Color3.fromRGB(255, 90, 90),
	Color3.fromRGB(90, 200, 255),
	Color3.fromRGB(255, 220, 60),
	Color3.fromRGB(120, 230, 120),
	Color3.fromRGB(220, 120, 255),
}

local function confetti()
	local area = refs.Gui.AbsoluteSize
	for _ = 1, UiConfig.ConfettiPieces do
		local piece = Instance.new("Frame")
		piece.BorderSizePixel = 0
		piece.BackgroundColor3 = CONFETTI_COLORS[math.random(1, #CONFETTI_COLORS)]
		local size = math.random(6, 12) * currentScale * 1.4
		piece.Size = UDim2.fromOffset(size, size * 1.6)
		piece.Position = UDim2.fromOffset(math.random() * area.X, -40 - math.random() * area.Y * 0.4)
		piece.Rotation = math.random(0, 360)
		piece.ZIndex = 20
		piece.Parent = refs.Confetti
		local fall = math.random(18, 32) / 10
		TweenService:Create(piece, TweenInfo.new(fall, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
			Position = UDim2.fromOffset(piece.Position.X.Offset + math.random(-120, 120), area.Y + 40),
			Rotation = piece.Rotation + math.random(180, 720),
		}):Play()
		task.delay(fall, function()
			piece:Destroy()
		end)
	end
end

-- Números do prêmio subindo de 0 até o valor (efeito de contagem).
local function countUp(label: TextLabel, prefix: string, value: number, suffix: string, seconds: number)
	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local t = math.min((os.clock() - started) / seconds, 1)
		label.Text = prefix .. InterfaceController.formatNumber(value * t) .. suffix
		if t >= 1 then
			connection:Disconnect()
		end
	end)
end

local celebrationToken = 0
local celebrationFinish: (() -> ())? = nil

export type ZoneInfo = { Zone: number, Name: string?, Next: string?, Gems: number, Cash: number, Frenzy: number }

-- Área limpa: painel grande com raios girando, confete e prêmios contando. Some antes da barreira cair.
function InterfaceController.celebrate(info: ZoneInfo)
	InterfaceController.close()
	refs.Toast.Visible = false
	refs.CelebrationTitle.Text = "AREA CLEARED!"
	refs.CelebrationSub.Text = if info.Next then `NEXT: {info.Next}  →` else ""
	refs.Chips[3].Text = `⚡ FRENZY {info.Frenzy}s`
	refs.Celebration.Visible = true
	refs.ContinueHolder.Visible = true
	InterfaceController.bump(refs.Celebration)
	countUp(refs.Chips[1], "+", info.Gems, " 💎", 1.2)
	countUp(refs.Chips[2], "+$", info.Cash, "", 1.2)
	confetti()
	EatEffects.playTierUp()
	Feedback.play("ZoneClear", { Gui = refs.Celebration, Amount = info.Gems })
	local spin = RunService.RenderStepped:Connect(function(dt)
		refs.Rays.Rotation = (refs.Rays.Rotation + dt * 25) % 360
	end)
	celebrationToken += 1
	local token = celebrationToken
	local function finish()
		if token ~= celebrationToken then
			return
		end
		celebrationToken += 1
		spin:Disconnect()
		refs.Celebration.Visible = false
		refs.ContinueHolder.Visible = false
		if info.Next then
			InterfaceController.toast(`GO! {info.Next} IS OPEN!`, Color3.fromRGB(255, 227, 107))
		end
	end
	celebrationFinish = finish
	task.delay(RunConfig.ZoneCelebrationSeconds, finish)
end

local function onStateChanged()
	local state = runState()
	refs.Status.Visible = isRun and state == "Loading"
	refs.Status.Text = "Building the city..."
	refs.Winner.Visible = isRun and state == "Victory"
	if state == "Victory" then
		InterfaceController.close()
		refs.Toast.Visible = false
		refs.Combo.Visible = false
		local gems = (ReplicatedStorage:GetAttribute("RunWinGems") :: number?) or 0
		refs.WinnerName.Text = "CITY EATEN!"
		refs.WinnerSub.Text = `+{gems} 💎   •   Going back to the lobby...`
		InterfaceController.bump(refs.Winner)
		EatEffects.playTierUp()
		Feedback.play("ZoneClear", { Gui = refs.Winner, Amount = gems })
	end
	updateHud()
end

local function setupTierToasts()
	local lastTier = (localPlayer:GetAttribute("EdibleTier") :: number?) or 1
	localPlayer:GetAttributeChangedSignal("EdibleTier"):Connect(function()
		local tier = (localPlayer:GetAttribute("EdibleTier") :: number?) or 1
		if tier > lastTier and isRun then
			InterfaceController.toast(
				"YOU CAN NOW EAT " .. EatEffects.tierName(tier) .. "!",
				Color3.fromRGB(255, 227, 107)
			)
			EatEffects.playTierUp()
			Feedback.play("TierUp", { Gui = refs.Toast, Amount = tier })
		end
		lastTier = tier
	end)
end

-- Barra da run: UPGRADES abre a janela; LOBBY pede confirmação (segundo toque), salva e volta ao lobby.
local function setupMatchBar()
	refs.UpgradesButton.Activated:Connect(function()
		InterfaceController.open("Upgrades")
	end)
	local leave = Remotes.event(Remotes.Names.Events.LeaveMatch)
	local armedToken = 0
	local function reset()
		armedToken += 1
		refs.LobbyButtonText.Text = "🏠 LOBBY"
	end
	refs.LobbyButton.Activated:Connect(function()
		if refs.LobbyButtonText.Text ~= "SURE?" then
			armedToken += 1
			local token = armedToken
			refs.LobbyButtonText.Text = "SURE?"
			task.delay(UiConfig.LeaveConfirmSeconds, function()
				if armedToken == token then
					reset()
				end
			end)
			return
		end
		reset()
		leave:FireServer()
	end)
end

function InterfaceController.init()
	refs = Screens.build(localPlayer:WaitForChild("PlayerGui"))
	for _, obj in refs.Scaled do
		local s = Instance.new("UIScale")
		s.Parent = obj
	end
	updateScale()
	refs.Gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateScale)

	-- o X da CREATE PARTY também cancela a party: quem liga é o PartyController
	for _, close in { refs.ShopClose, refs.WheelClose, refs.RewardsClose, refs.UpgradesClose } do
		close.Activated:Connect(InterfaceController.close)
	end

	setupCurrencies()
	setupTierToasts()
	setupMatchBar()

	EatEffects.onLocalBite(function(info)
		showCombo(EatEffects.currentCombo())
		if info.Gems > 0 then
			InterfaceController.toast("+" .. info.Gems .. " 💎 GEMS!", Color3.fromRGB(140, 210, 255))
		end
	end)
	Remotes.event(Remotes.Names.Events.Notice).OnClientEvent:Connect(function(text: string)
		InterfaceController.toast(text, Color3.fromRGB(255, 227, 107))
	end)
	Remotes.event(Remotes.Names.Events.RewardGranted).OnClientEvent:Connect(InterfaceController.popup)

	for _, name in { "RunZone", "RunZones", "RunZoneName", "RunZoneLeft", "RunZoneTotal" } do
		ReplicatedStorage:GetAttributeChangedSignal(name):Connect(onProgress)
	end
	RunService.Heartbeat:Connect(updateFrenzy)
	Remotes.event(Remotes.Names.Events.ZoneCleared).OnClientEvent:Connect(InterfaceController.celebrate)
	-- CONTINUE fecha a comemoração antes do tempo
	refs.Continue.Activated:Connect(function()
		if celebrationFinish then
			celebrationFinish()
		end
	end)
	ReplicatedStorage:GetAttributeChangedSignal("RunState"):Connect(onStateChanged)
	onProgress()
	onStateChanged()
end

return InterfaceController
