--!strict
-- Janela CREATE PARTY (etapa 3 do goat). Abre quando você pisa num quadrado vazio da área START A RUN.
-- Capítulo (mapa), dificuldade e tamanho da party -> CREATE. (A coluna de runs salvas saiu: toda partida é
-- nova. A janela de verdade, com os 3 elementos, vem na Etapa 9.)
-- BACK ou X cancelam e o servidor tira você do quadrado.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Runs = require(Shared.Logic.Runs)
local MapConfig = require(Shared.Config.MapConfig)
local DifficultyConfig = require(Shared.Config.DifficultyConfig)
local PartyConfig = require(Shared.Config.PartyConfig)
local Remotes = require(Shared.Remotes)

local Style = require(script.Parent.Parent.Ui.Style)
local InterfaceController = require(script.Parent.InterfaceController)

local localPlayer = Players.LocalPlayer

local PartyController = {}

local padIndex: number? = nil
local mapIndex = 1
local difficultyIndex = 1
local size = PartyConfig.MaxSize
local busy = false

local GOOD = Style.Colors.LevelFill
local BAD = Style.Colors.Danger

local function wins(): number
	return (localPlayer:GetAttribute("Wins") :: number?) or 0
end

local function mapUnlocked(): boolean
	return Runs.unlocked(MapConfig[mapIndex].RequiredWins, wins())
end

local function refreshLeft()
	local refs = InterfaceController.refs()
	local map = MapConfig[mapIndex]
	local unlocked = mapUnlocked()
	refs.PartyChapter.Text = if unlocked then `{map.Icon} CHAPTER {mapIndex}` else `🔒 {map.RequiredWins} WINS NEEDED`
	refs.PartyMapName.Text = map.DisplayName
	Style.recolor(refs.PartyMapFace, if unlocked then Style.Themes.Yellow else Style.Themes.Gray)

	for index, button in refs.PartyDifficulties do
		local d = DifficultyConfig[index]
		button.Holder.Visible = d ~= nil
		if d then
			local open = Runs.unlocked(d.RequiredWins, wins())
			button.Title.Text = d.Name
			button.Sub.Text = if open then string.rep("💀", d.Skulls) else `🔒 {d.RequiredWins} WINS`
			local theme = if not open
				then Style.Themes.Gray
				elseif index == difficultyIndex then Style.Themes.Green
				else Style.Themes.LightBlue
			Style.recolor(button.Face, theme)
		end
	end

	refs.PartySize.Text = tostring(size)
	local ready = unlocked and Runs.unlocked(DifficultyConfig[difficultyIndex].RequiredWins, wins())
	Style.recolor(refs.PartyCreateFace, if ready then Style.Themes.Green else Style.Themes.Gray)
	refs.PartyCreateText.Text = "CREATE"
end

local function create()
	if busy or padIndex == nil then
		return
	end
	if not mapUnlocked() then
		InterfaceController.toast(`Win {MapConfig[mapIndex].RequiredWins} runs to unlock this chapter`, BAD)
		return
	end
	local difficulty = DifficultyConfig[difficultyIndex]
	if not Runs.unlocked(difficulty.RequiredWins, wins()) then
		InterfaceController.toast(`Win {difficulty.RequiredWins} runs to unlock {difficulty.Name}`, BAD)
		return
	end
	busy = true
	local settings = { Map = MapConfig[mapIndex].Id, Difficulty = difficulty.Id, Size = size }
	local ok, reason = Remotes.func(Remotes.Names.Functions.CreateParty):InvokeServer(padIndex, settings)
	busy = false
	if ok then
		InterfaceController.close()
		local text = if size > 1 then "Party created! Friends can step on your pad" else "Starting your run..."
		InterfaceController.toast(text, GOOD)
	else
		InterfaceController.toast(reason or "Could not create the party", BAD)
	end
end

local function cancel()
	local index = padIndex
	padIndex = nil
	InterfaceController.close()
	if index then
		task.spawn(function()
			Remotes.func(Remotes.Names.Functions.CancelParty):InvokeServer(index)
		end)
	end
end

function PartyController.init()
	local refs = InterfaceController.refs()

	refs.PartyPrev.Activated:Connect(function()
		mapIndex = (mapIndex - 2) % #MapConfig + 1
		refreshLeft()
	end)
	refs.PartyNext.Activated:Connect(function()
		mapIndex = mapIndex % #MapConfig + 1
		refreshLeft()
	end)
	for index, button in refs.PartyDifficulties do
		button.Hit.Activated:Connect(function()
			local d = DifficultyConfig[index]
			if d and Runs.unlocked(d.RequiredWins, wins()) then
				difficultyIndex = index
				refreshLeft()
			elseif d then
				InterfaceController.toast(`Win {d.RequiredWins} runs to unlock {d.Name}`, BAD)
			end
		end)
	end
	refs.PartyMinus.Activated:Connect(function()
		size = math.max(1, size - 1)
		refreshLeft()
	end)
	refs.PartyPlus.Activated:Connect(function()
		size = math.min(PartyConfig.MaxSize, size + 1)
		refreshLeft()
	end)
	refs.PartyCreate.Activated:Connect(create)
	refs.PartyBack.Activated:Connect(cancel)
	refs.PartyClose.Activated:Connect(cancel)

	InterfaceController.onOpen("Party", function()
		refreshLeft()
	end)
	localPlayer:GetAttributeChangedSignal("Wins"):Connect(function()
		if InterfaceController.isOpen("Party") then
			refreshLeft()
		end
	end)

	Remotes.event(Remotes.Names.Events.PartyPrompt).OnClientEvent:Connect(function(index: number)
		padIndex = index
		InterfaceController.open("Party")
	end)
	Remotes.event(Remotes.Names.Events.PartyClosed).OnClientEvent:Connect(function()
		padIndex = nil
		if InterfaceController.isOpen("Party") then
			InterfaceController.close()
		end
	end)
end

return PartyController
