--!strict
-- Janela CREATE PARTY (etapa 3 do goat). Abre quando você pisa num quadrado vazio da área START A RUN.
-- Esquerda: capítulo (mapa), dificuldade e tamanho da party -> CREATE. Direita: runs salvas -> LOAD GAME.
-- BACK ou X cancelam e o servidor tira você do quadrado.

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Runs = require(Shared.Logic.Runs)
local MapConfig = require(Shared.Config.MapConfig)
local DifficultyConfig = require(Shared.Config.DifficultyConfig)
local PartyConfig = require(Shared.Config.PartyConfig)
local RunConfig = require(Shared.Config.RunConfig)
local Remotes = require(Shared.Remotes)

local Screens = require(script.Parent.Parent.Ui.Screens)
local Style = require(script.Parent.Parent.Ui.Style)
local InterfaceController = require(script.Parent.InterfaceController)

local localPlayer = Players.LocalPlayer

local PartyController = {}

local padIndex: number? = nil
local mapIndex = 1
local difficultyIndex = 1
local size = PartyConfig.MaxSize
local busy = false
local cards: { Screens.SavedRunCard } = {}

local GOOD = Color3.fromRGB(125, 255, 138)
local BAD = Color3.fromRGB(255, 120, 120)

local function wins(): number
	return (localPlayer:GetAttribute("Wins") :: number?) or 0
end

local function savedRuns(): { Runs.Summary }
	local raw = localPlayer:GetAttribute("SavedRuns")
	if type(raw) ~= "string" then
		return {}
	end
	local ok, list = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	return if ok and type(list) == "table" then list else {}
end

local function mapById(id: string): typeof(MapConfig[1])?
	for _, map in MapConfig do
		if map.Id == id then
			return map
		end
	end
	return nil
end

local function difficultyById(id: string): DifficultyConfig.Difficulty?
	for _, d in DifficultyConfig do
		if d.Id == id then
			return d
		end
	end
	return nil
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

local function loadRun(summary: Runs.Summary)
	if busy or padIndex == nil then
		return
	end
	busy = true
	local ok, reason = Remotes.func(Remotes.Names.Functions.LoadRun):InvokeServer(padIndex, summary.Id)
	busy = false
	if ok then
		InterfaceController.close()
		local text = if #summary.Members > 1
			then "Everyone in this run must step on your pad!"
			else "Loading your run..."
		InterfaceController.toast(text, GOOD)
	else
		InterfaceController.toast(reason or "Could not load the run", BAD)
	end
end

local function refreshSaved()
	local refs = InterfaceController.refs()
	for _, card in cards do
		card.Holder:Destroy()
	end
	table.clear(cards)
	local now = os.time()
	local list = Runs.clean(savedRuns(), now, RunConfig.SavedRunDays)
	refs.SavedEmpty.Visible = #list == 0
	for order, summary in list do
		local card = Screens.savedRunCard(refs.SavedList, order)
		local map = mapById(summary.Map)
		local difficulty = difficultyById(summary.Difficulty)
		card.Title.Text = if map then `{map.Icon} {map.DisplayName}` else summary.Map
		local others = {}
		for index, id in summary.Members do
			if id ~= localPlayer.UserId then
				table.insert(others, summary.Names[index] or "?")
			end
		end
		card.With.Text = if #others > 0 then "WITH " .. table.concat(others, ", "):upper() else "SOLO"
		card.Difficulty.Text = if difficulty then difficulty.Name else summary.Difficulty
		card.Progress.Text = `🍔 {math.floor((summary.Progress or 0) * 100)}%`
		local left = Runs.expiresIn(summary.UpdatedAt, now, RunConfig.SavedRunDays)
		card.Expires.Text = `⏳ {Runs.formatDuration(left)} left`
		card.Load.Activated:Connect(function()
			loadRun(summary)
		end)
		table.insert(cards, card)
	end
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
		refreshSaved()
	end)
	localPlayer:GetAttributeChangedSignal("SavedRuns"):Connect(function()
		if InterfaceController.isOpen("Party") then
			refreshSaved()
		end
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
