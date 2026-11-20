--!strict
-- Loja do lobby: abas ITEMS (cosméticos com gemas: rastros e auras) e ROBUX (pacotes de gemas).
-- Nada aqui muda o poder do jogador. A loja da partida (slots e poderes) chega na Etapa 7.

local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ShopConfig = require(Shared.Config.ShopConfig)
local ProductConfig = require(Shared.Config.ProductConfig)
local Remotes = require(Shared.Remotes)

local Screens = require(script.Parent.Parent.Ui.Screens)
local Style = require(script.Parent.Parent.Ui.Style)
local InterfaceController = require(script.Parent.InterfaceController)
local Feedback = require(script.Parent.Parent.Feedback)

local localPlayer = Players.LocalPlayer

local ShopController = {}

local currentTab = "ITEMS"
local busy = false

local function owned(): { [string]: boolean }
	local raw = localPlayer:GetAttribute("Owned") :: string?
	if raw == nil or raw == "" then
		return {}
	end
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
	return if ok and type(decoded) == "table" then decoded else {}
end

local function equipped(slot: string): string
	return (localPlayer:GetAttribute("Equipped" .. slot) :: string?) or ""
end

local function setButton(card: Screens.Card, text: string, theme: Style.Theme)
	card.ButtonText.Text = text
	Style.recolor(card.ButtonFace, theme)
end

-- Executa uma compra/ação no servidor e atualiza a aba.
local function request(remote: string, id: string, gui: GuiObject?, price: number?)
	if busy then
		return
	end
	busy = true
	local ok, reason = Remotes.func(remote):InvokeServer(id)
	busy = false
	if remote == Remotes.Names.Functions.BuyItem then
		if ok then
			InterfaceController.bump(InterfaceController.refs().Shop)
			Feedback.play("Buy", { Gui = gui, Amount = price })
		elseif reason then
			InterfaceController.toast(string.upper(reason), Style.Colors.Danger)
			Feedback.play("Fail", { Gui = gui, Amount = price })
		end
	end
	ShopController.refresh()
end

local function clear(content: ScrollingFrame)
	for _, child in content:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
end

local function buildItems(content: ScrollingFrame)
	local mine = owned()
	local gems = (localPlayer:GetAttribute("Gems") :: number?) or 0
	for index, item in ShopConfig do
		local card = Screens.card(content, item.Rarity, item.Name, item.Icon, string.upper(item.Rarity), "")
		card.Holder.LayoutOrder = index
		if mine[item.Id] == true then
			local on = equipped(item.Kind) == item.Id
			setButton(
				card,
				if on then "EQUIPPED" else "EQUIP",
				if on then Style.Themes.Gray else Style.Themes.LightBlue
			)
			card.Button.Activated:Connect(function()
				request(Remotes.Names.Functions.EquipItem, item.Id)
			end)
		else
			setButton(card, "💎 " .. item.Price, if gems >= item.Price then Style.Themes.Green else Style.Themes.Gray)
			card.Button.Activated:Connect(function()
				request(Remotes.Names.Functions.BuyItem, item.Id, card.Button, item.Price)
			end)
		end
	end
end

local function buildRobux(content: ScrollingFrame)
	for index, product in ProductConfig do
		local card = Screens.card(content, "Legendary", product.Name, product.Icon, "Robux", "")
		card.Holder.LayoutOrder = index
		if product.ProductId == 0 then
			setButton(card, "SOON", Style.Themes.Gray)
		else
			setButton(card, Style.Robux .. " " .. product.PriceLabel, Style.Themes.Green)
			card.Button.Activated:Connect(function()
				MarketplaceService:PromptProductPurchase(localPlayer, product.ProductId)
			end)
		end
	end
end

function ShopController.refresh()
	local refs = InterfaceController.refs()
	if not refs.Shop.Visible then
		return
	end
	local content = refs.ShopContent
	clear(content)
	if currentTab == "ITEMS" then
		buildItems(content)
	else
		buildRobux(content)
	end
	-- aba atual destacada (as outras ficam mais apagadas)
	for name, tab in refs.ShopTabs do
		tab.Face.BackgroundTransparency = if name == currentTab then 0 else 0.35
	end
end

function ShopController.openTab(tab: string)
	currentTab = tab
	InterfaceController.open("Shop")
end

function ShopController.init()
	local refs = InterfaceController.refs()
	InterfaceController.onOpen("Shop", ShopController.refresh)
	for name, tab in refs.ShopTabs do
		tab.Hit.Activated:Connect(function()
			currentTab = name
			ShopController.refresh()
		end)
	end
	refs.ShopIcon.Activated:Connect(function()
		ShopController.openTab("ITEMS")
	end)
	for _, attribute in { "Gems", "Owned", "EquippedTrail", "EquippedAura" } do
		localPlayer:GetAttributeChangedSignal(attribute):Connect(ShopController.refresh)
	end
end

return ShopController
