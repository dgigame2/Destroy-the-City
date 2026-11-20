--!strict
-- Integração das telas com o jogo (etapa 3 do goat): HUD, janelas, avisos, progresso e vitória da run.
-- No lobby: gemas, vitórias e atalhos. Na run: dinheiro, gemas, progresso ("% EATEN") e a barra de baixo.
-- Os outros controladores (loja, roleta, recompensas, party) usam a API daqui para abrir janelas e avisar.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UiConfig = require(Shared.Config.UiConfig)
local PaletteConfig = require(Shared.Config.PaletteConfig)
local UiLayout = require(Shared.Logic.UiLayout)
local Place = require(Shared.Place)
local Remotes = require(Shared.Remotes)

local Screens = require(script.Parent.Parent.Ui.Screens)
local Style = require(script.Parent.Parent.Ui.Style)
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
	return (ReplicatedStorage:GetAttribute("MatchState") :: string?) or "Loading"
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
	return { refs.Shop, refs.Rewards, refs.Upgrades, refs.Party }
end

-- Abre uma janela (fecha a anterior). name: "Shop", "Rewards", "Upgrades" ou "Party".
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
	local layout = UiLayout.place(
		area.X,
		area.Y,
		C,
		UiLayout.isDesktop(UserInputService.TouchEnabled, UserInputService.KeyboardEnabled)
	)
	currentScale = layout.Scale
	for _, obj in refs.Scaled do
		setScale(obj, currentScale)
	end
	setScale(refs.MatchBar, layout.MatchScale)
	setScale(refs.TimerHolder, layout.TimerScale)
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
	-- só o cartão + som e balanço leve (sem brilho no personagem nem número extra: poluía a tela)
	Feedback.play("Reward", { Gui = refs.Popup, Text = "+1 " .. icon })
	task.delay(2.6, function()
		if popupToken == token then
			refs.Popup.Visible = false
		end
	end)
end

-- Aviso grande no lugar do combo (marcos da cidade: "50% DESTROYED!").
function InterfaceController.bigCombo(text: string, color: Color3?)
	comboToken += 1
	local token = comboToken
	refs.Combo.Text = text
	refs.Combo.TextColor3 = color or Style.Colors.Combo
	refs.Combo.Visible = true
	refs.Combo.Rotation = math.random(-6, 6)
	InterfaceController.bump(refs.Combo)
	task.delay(1.8, function()
		if comboToken == token then
			refs.Combo.Visible = false
			refs.Combo.TextColor3 = Color3.new(1, 1, 1)
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

-- Progresso da cidade (compartilhado): nome da cidade, "42% DESTROYED" e a barra (MatchProgress, pelo valor).
local function onProgress()
	local progress = math.clamp((ReplicatedStorage:GetAttribute("MatchProgress") :: number?) or 0, 0, 1)
	local percent = math.floor(progress * 100)
	refs.Timer.Text = (ReplicatedStorage:GetAttribute("MatchMapName") :: string?) or ""
	refs.MapName.Text = `{percent}% DESTROYED`
	refs.ProgressFill.Size = UDim2.fromScale(progress, 1)
end

-- Confete caindo pela tela inteira.
local CONFETTI_COLORS = {}
for _, c in PaletteConfig.Confetti do
	table.insert(CONFETTI_COLORS, Style.rgb(c))
end

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

-- Marco da cidade (25/50/75/100%): aviso grande + confete (o servidor já pagou as gemas extras).
local function onMilestone(_index: number, fraction: number)
	if type(fraction) ~= "number" or fraction >= 1 then
		return -- 100% é a vitória (onStateChanged)
	end
	InterfaceController.bigCombo(`{math.floor(fraction * 100 + 0.5)}% DESTROYED!`, Style.Colors.Gold)
	confetti()
	Feedback.play("ZoneClear", { Gui = refs.Combo })
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
		local gems = (ReplicatedStorage:GetAttribute("MatchWinGems") :: number?) or 0
		refs.WinnerName.Text = "CITY DESTROYED!"
		refs.WinnerSub.Text = `+{gems} 💎   •   Going back to the lobby...`
		InterfaceController.bump(refs.Winner)
		Feedback.play("ZoneClear", { Gui = refs.Winner, Amount = gems })
	end
	updateHud()
end

-- Barra da run: LOBBY pede confirmação (segundo toque), salva e volta ao lobby.
local function setupMatchBar()
	refs.UpgradesButton.Visible = false -- loja de slots e poderes chega na Etapa 7
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
	for _, close in { refs.ShopClose, refs.RewardsClose, refs.UpgradesClose } do
		close.Activated:Connect(InterfaceController.close)
	end

	setupCurrencies()
	setupMatchBar()

	Remotes.event(Remotes.Names.Events.Notice).OnClientEvent:Connect(function(text: string)
		InterfaceController.toast(text, Style.Colors.Gold)
	end)
	Remotes.event(Remotes.Names.Events.RewardGranted).OnClientEvent:Connect(InterfaceController.popup)

	for _, name in { "MatchProgress", "MatchMapName" } do
		ReplicatedStorage:GetAttributeChangedSignal(name):Connect(onProgress)
	end
	Remotes.event(Remotes.Names.Events.Milestone).OnClientEvent:Connect(onMilestone)
	ReplicatedStorage:GetAttributeChangedSignal("MatchState"):Connect(onStateChanged)
	onProgress()
	onStateChanged()
end

return InterfaceController
