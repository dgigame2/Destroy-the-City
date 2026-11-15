--!strict
-- Janela de upgrades da partida (etapa 3 do goat): compra com o dinheiro ganho comendo a cidade.
-- Abre pelo botão UPGRADES da barra da partida.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Upgrades = require(Shared.Logic.Upgrades)
local UpgradeConfig = require(Shared.Config.UpgradeConfig)
local Remotes = require(Shared.Remotes)

local Screens = require(script.Parent.Parent.Ui.Screens)
local Style = require(script.Parent.Parent.Ui.Style)
local InterfaceController = require(script.Parent.InterfaceController)
local Feedback = require(script.Parent.Parent.Feedback)

local localPlayer = Players.LocalPlayer

local ICONS: { [string]: string } = { Speed = "👟", Magnet = "🧲", Growth = "🍔", Coins = "💵" }

local UpgradesController = {}

local busy = false

local function setButton(card: Screens.Card, text: string, theme: Style.Theme)
	card.ButtonText.Text = text
	Style.recolor(card.ButtonFace, theme)
end

local function buy(id: string, gui: GuiObject, cost: number)
	if busy then
		return
	end
	busy = true
	local ok = Remotes.func(Remotes.Names.Functions.BuyUpgrade):InvokeServer(id)
	busy = false
	if ok then
		InterfaceController.bump(InterfaceController.refs().Upgrades)
		Feedback.play("Buy", { Gui = gui, Amount = cost })
	else
		InterfaceController.toast("NOT ENOUGH CASH", Color3.fromRGB(255, 120, 120))
		-- número = quanto falta
		local coins = (localPlayer:GetAttribute("Coins") :: number?) or 0
		Feedback.play("Fail", { Gui = gui, Amount = math.max(cost - coins, 0) })
	end
	UpgradesController.refresh()
end

function UpgradesController.refresh()
	local refs = InterfaceController.refs()
	if not refs.Upgrades.Visible then
		return
	end
	local coins = (localPlayer:GetAttribute("Coins") :: number?) or 0
	refs.UpgradesCash.Text = "💵 " .. InterfaceController.formatNumber(coins)
	local content = refs.UpgradesContent
	for _, child in content:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for index, upgrade in UpgradeConfig do
		local level = (localPlayer:GetAttribute("Upgrade_" .. upgrade.Id) :: number?) or 0
		local canBuy, cost = Upgrades.canBuy(upgrade, level, coins)
		local card = Screens.card(
			content,
			"Rare",
			upgrade.DisplayName,
			ICONS[upgrade.Id] or "⬆️",
			upgrade.Description .. "\nLv " .. level,
			""
		)
		card.Holder.LayoutOrder = index
		if level >= upgrade.MaxLevel then
			setButton(card, "MAX", Style.Themes.Gray)
		else
			setButton(
				card,
				"💵 " .. InterfaceController.formatNumber(cost),
				if canBuy then Style.Themes.Green else Style.Themes.Gray
			)
			card.Button.Activated:Connect(function()
				buy(upgrade.Id, card.Button, cost)
			end)
		end
	end
end

-- O dinheiro muda a cada mordida: junta as mudanças e redesenha no máximo 4x por segundo.
local pending = false
local function refreshSoon()
	if pending then
		return
	end
	pending = true
	task.delay(0.25, function()
		pending = false
		UpgradesController.refresh()
	end)
end

function UpgradesController.init()
	InterfaceController.onOpen("Upgrades", UpgradesController.refresh)
	localPlayer:GetAttributeChangedSignal("Coins"):Connect(refreshSoon)
	for _, upgrade in UpgradeConfig do
		localPlayer:GetAttributeChangedSignal("Upgrade_" .. upgrade.Id):Connect(refreshSoon)
	end
end

return UpgradesController
