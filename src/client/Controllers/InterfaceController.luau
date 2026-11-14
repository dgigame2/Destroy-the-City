--!strict
-- Integração das telas com o jogo (etapa 3 do goat): HUD, janelas, avisos, votação, vencedor e barra do lobby.
-- Os outros controladores (loja, roleta, recompensas, espectar) usam a API daqui para abrir janelas e avisar.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UiConfig = require(Shared.Config.UiConfig)
local UiLayout = require(Shared.Logic.UiLayout)
local Remotes = require(Shared.Remotes)

local Screens = require(script.Parent.Parent.Ui.Screens)
local EatEffects = require(script.Parent.EatEffects)

local localPlayer = Players.LocalPlayer

local InterfaceController = {}

local refs: Screens.Refs
local currentScale = 1
local toastToken, comboToken, popupToken = 0, 0, 0
local voteOptionIds: { string } = {}
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

local function formatTime(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	if seconds >= 3600 then
		return string.format("%dh %02dm", seconds // 3600, (seconds % 3600) // 60)
	end
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end
InterfaceController.formatTime = formatTime

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

local function inMatch(): boolean
	return localPlayer:GetAttribute("InMatch") == true
end

local function roundState(): string
	return (ReplicatedStorage:GetAttribute("RoundState") :: string?) or "Loading"
end

-- HUD visível só sem janela aberta. Barra do lobby só fora da partida.
local function updateHud()
	local hud = openWindow == nil
	local state = roundState()
	refs.CashHolder.Visible = hud
	refs.GemsHolder.Visible = hud
	refs.Icons.Visible = hud and state ~= "Voting"
	refs.TimerHolder.Visible = hud and state ~= "Voting"
	refs.LobbyBar.Visible = hud and not inMatch() and state ~= "Voting"
end
InterfaceController.updateHud = updateHud

function InterfaceController.onOpen(name: string, callback: () -> ())
	onWindowOpened[name] = callback
end

-- Abre uma janela (fecha a anterior). name: "Shop", "Wheel" ou "Rewards".
function InterfaceController.open(name: string)
	for _, window in { refs.Shop, refs.Wheel, refs.Rewards } do
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
	refs.Shop.Visible = false
	refs.Wheel.Visible = false
	refs.Rewards.Visible = false
	openWindow = nil
	updateHud()
end

function InterfaceController.isOpen(name: string): boolean
	return openWindow == name
end

local function updateScale()
	local area = refs.Gui.AbsoluteSize
	if area.X <= 0 or area.Y <= 0 then
		return
	end
	currentScale = UiLayout.scale(area.X, area.Y, UiConfig)
	for _, obj in refs.Scaled do
		local s = obj:FindFirstChildOfClass("UIScale")
		if s then
			s.Scale = currentScale
		end
	end
	-- gemas abaixo do dinheiro; atalhos abaixo das gemas (posições reais dependem da escala)
	local m, gap = UiConfig.Margin, UiConfig.Gap * currentScale
	local gemsY = m + UiConfig.Currency.H * currentScale + gap
	refs.GemsHolder.Position = UDim2.fromOffset(m, gemsY)
	refs.Icons.Position = UDim2.fromOffset(m, gemsY + UiConfig.Currency.H * currentScale + 2 * gap)
	refs.Toast.Position = UDim2.new(0.5, 0, 0, UiConfig.Toast.Y * currentScale)
	refs.Popup.Position = UDim2.new(0.5, 0, 0, (UiConfig.Toast.Y + UiConfig.Toast.H + 20) * currentScale)
	refs.SpectatingLabel.Position = UDim2.new(0.5, 0, 1, -(m + (UiConfig.Play.H + UiConfig.Gap) * currentScale))
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
	local shownCash, shownGems = 0, 0
	local function onCash()
		local cash = (localPlayer:GetAttribute("Coins") :: number?) or 0
		if cash > shownCash then
			InterfaceController.bump(refs.CashHolder)
		end
		shownCash = cash
		refs.Cash.Text = InterfaceController.formatNumber(cash)
	end
	local function onGems()
		local gems = (localPlayer:GetAttribute("Gems") :: number?) or 0
		if gems > shownGems then
			InterfaceController.bump(refs.GemsHolder)
		end
		shownGems = gems
		refs.Gems.Text = InterfaceController.formatNumber(gems)
		refs.ShopGems.Text = "💎 " .. InterfaceController.formatNumber(gems)
	end
	localPlayer:GetAttributeChangedSignal("Coins"):Connect(onCash)
	localPlayer:GetAttributeChangedSignal("Gems"):Connect(onGems)
	onCash()
	onGems()
end

local function setupVote()
	local castVote = Remotes.event(Remotes.Names.Events.CastVote)
	for index, card in refs.VoteCards do
		card.Hit.Activated:Connect(function()
			local id = voteOptionIds[index]
			if id == nil then
				return
			end
			castVote:FireServer(id)
			for i, other in refs.VoteCards do
				other.Stroke.Enabled = i == index
			end
		end)
	end
	Remotes.event(Remotes.Names.Events.VoteStarted).OnClientEvent:Connect(function(options: { any })
		table.clear(voteOptionIds)
		for index, card in refs.VoteCards do
			local option = options[index]
			card.Holder.Visible = option ~= nil
			card.Stroke.Enabled = false
			if option then
				voteOptionIds[index] = option.Id
				card.Name.Text = option.Name
				card.Icon.Text = option.Icon
				card.Votes.Text = "0 votes"
			end
		end
		InterfaceController.close()
		refs.Vote.Visible = true
		InterfaceController.bump(refs.Vote)
	end)
	Remotes.event(Remotes.Names.Events.VoteUpdated).OnClientEvent:Connect(function(counts: { [string]: number })
		for index, card in refs.VoteCards do
			local id = voteOptionIds[index]
			local count = if id then counts[id] or 0 else 0
			card.Votes.Text = count .. (if count == 1 then " vote" else " votes")
		end
	end)
end

local function onStateChanged()
	local state = roundState()
	refs.Winner.Visible = state == "Winner"
	refs.Vote.Visible = state == "Voting"
	refs.Status.Visible = state == "Loading" and inMatch()
	refs.Status.Text = "Building the city..."
	refs.MapName.Text = (ReplicatedStorage:GetAttribute("MapName") :: string?) or ""
	if state ~= "Playing" then
		refs.Toast.Visible = false
		refs.Combo.Visible = false
	end
	if state == "Winner" then
		local name = (ReplicatedStorage:GetAttribute("Winner") :: string?) or ""
		refs.WinnerName.Text = if name ~= "" then name .. " WINS!" else "ROUND OVER!"
		refs.WinnerSub.Text = "The biggest city eater!"
		InterfaceController.bump(refs.Winner)
	end
	updateHud()
end

local function setupTierToasts()
	local lastTier = (localPlayer:GetAttribute("EdibleTier") :: number?) or 1
	localPlayer:GetAttributeChangedSignal("EdibleTier"):Connect(function()
		local tier = (localPlayer:GetAttribute("EdibleTier") :: number?) or 1
		if tier > lastTier and inMatch() then
			InterfaceController.toast(
				"YOU CAN NOW EAT " .. EatEffects.tierName(tier) .. "!",
				Color3.fromRGB(255, 227, 107)
			)
			EatEffects.playTierUp()
		end
		lastTier = tier
	end)
end

local function setupLobbyBar()
	local join = Remotes.event(Remotes.Names.Events.JoinMatch)
	local autoJoin = Remotes.event(Remotes.Names.Events.SetAutoJoin)
	refs.Play.Activated:Connect(function()
		join:FireServer()
	end)
	local auto = true
	refs.AutoJoin.Activated:Connect(function()
		auto = not auto
		autoJoin:FireServer(auto)
		refs.AutoJoinText.Text = if auto then "AUTO JOIN: ON" else "AUTO JOIN: OFF"
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

	for _, close in { refs.ShopClose, refs.WheelClose, refs.RewardsClose } do
		close.Activated:Connect(InterfaceController.close)
	end

	setupCurrencies()
	setupVote()
	setupTierToasts()
	setupLobbyBar()

	EatEffects.onLocalBite(function(info)
		showCombo(EatEffects.currentCombo())
		if info.Gems > 0 then
			InterfaceController.toast("+" .. info.Gems .. " 💎 GEMS!", Color3.fromRGB(140, 210, 255))
		end
	end)
	Remotes.event(Remotes.Names.Events.PlayerEaten).OnClientEvent:Connect(function(eater: Player, victim: Player)
		if victim == localPlayer then
			InterfaceController.toast("YOU GOT EATEN!", Color3.fromRGB(255, 120, 120))
		elseif eater == localPlayer then
			InterfaceController.toast("YOU ATE " .. victim.DisplayName:upper() .. "!", Color3.fromRGB(125, 255, 138))
		end
	end)
	Remotes.event(Remotes.Names.Events.RewardGranted).OnClientEvent:Connect(InterfaceController.popup)

	ReplicatedStorage:GetAttributeChangedSignal("RoundState"):Connect(onStateChanged)
	ReplicatedStorage:GetAttributeChangedSignal("MapName"):Connect(onStateChanged)
	localPlayer:GetAttributeChangedSignal("InMatch"):Connect(onStateChanged)
	onStateChanged()

	RunService.Heartbeat:Connect(function()
		local endsAt = (ReplicatedStorage:GetAttribute("RoundEndsAt") :: number?) or 0
		local remaining = endsAt - Workspace:GetServerTimeNow()
		local state = roundState()
		if state == "Playing" then
			refs.Timer.Text = if inMatch() then formatTime(remaining) else "LIVE " .. formatTime(remaining)
		elseif state == "Voting" then
			refs.VoteTimer.Text = formatTime(remaining)
			refs.Timer.Text = "VOTING"
		elseif state == "Intermission" then
			refs.Timer.Text = "STARTS IN " .. formatTime(remaining)
		elseif state == "Winner" then
			refs.Timer.Text = "ROUND OVER"
		else
			refs.Timer.Text = "LOBBY"
		end
		refs.PlayText.Text = if state == "Playing"
			then "▶ PLAY"
			elseif state == "Intermission" then "READY " .. formatTime(remaining)
			else "WAITING..."
	end)
end

return InterfaceController
