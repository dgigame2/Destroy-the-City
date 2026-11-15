--!strict
-- Parties do lobby (área START A RUN).
-- Pisar num quadrado vazio: você vira o dono e escolhe (tela CREATE PARTY) mapa, dificuldade e tamanho,
-- ou carrega uma run salva. Depois outros pisam no quadrado para entrar. A party sai para o lugar Run
-- quando o tempo acaba ou logo depois de lotar.
-- Situações do quadrado: Empty -> Creating -> Open | Loading -> Departing -> Empty.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Party = require(Shared.Logic.Party)
local Runs = require(Shared.Logic.Runs)
local RunArea = require(Shared.Logic.RunArea)
local PartyConfig = require(Shared.Config.PartyConfig)
local LobbyConfig = require(Shared.Config.LobbyConfig)
local MapConfig = require(Shared.Config.MapConfig)
local DifficultyConfig = require(Shared.Config.DifficultyConfig)
local RunConfig = require(Shared.Config.RunConfig)
local Remotes = require(Shared.Remotes)

local PlayerData = require(script.Parent.PlayerData)
local LobbyService = require(script.Parent.LobbyService)
local RunStore = require(script.Parent.RunStore)
local Teleporter = require(script.Parent.Teleporter)

type PadState = {
	Info: LobbyService.PadInfo,
	Status: string,
	Owner: Player?,
	Settings: Party.Settings?,
	RunId: string?, -- run salva sendo carregada
	RunMembers: { number }?,
	Since: number, -- quando entrou na situação atual
	FullSince: number?,
	OnPad: { Player }, -- na ordem de chegada
}

local PartyService = {}

local pads: { PadState } = {}
local teleporting: { [Player]: boolean } = {}

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function notice(player: Player, text: string)
	Remotes.event(Remotes.Names.Events.Notice):FireClient(player, text)
end

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function reset(pad: PadState)
	pad.Status = "Empty"
	pad.Owner = nil
	pad.Settings = nil
	pad.RunId = nil
	pad.RunMembers = nil
	pad.FullSince = nil
	pad.Since = now()
end

-- Tira o jogador de cima do quadrado (cancelou ou o tempo de escolher acabou).
local function pushOff(pad: PadState, player: Player)
	local character = player.Character
	if character then
		character:PivotTo(pad.Info.Exit)
	end
end

local function closeCreating(pad: PadState, push: boolean)
	local owner = pad.Owner
	if owner then
		Remotes.event(Remotes.Names.Events.PartyClosed):FireClient(owner)
		if push then
			pushOff(pad, owner)
		end
	end
	reset(pad)
end

local function ownsAnyPad(player: Player): boolean
	for _, pad in pads do
		if pad.Owner == player then
			return true
		end
	end
	return false
end

-- Quem está em cima de cada quadrado agora (mantém a ordem de chegada).
local function refreshOnPad()
	local cfg = LobbyConfig.RunArea
	for _, pad in pads do
		local still: { Player } = {}
		local present: { [Player]: boolean } = {}
		for _, player in Players:GetPlayers() do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and not teleporting[player] then
				local p = LobbyService.toLocal(root.Position)
				if RunArea.isOnPad(pad.Info.Area, p.X, p.Y, p.Z, cfg.DetectHeight) then
					present[player] = true
				end
			end
		end
		for _, player in pad.OnPad do
			if present[player] then
				table.insert(still, player)
				present[player] = nil
			end
		end
		for _, player in Players:GetPlayers() do
			if present[player] then
				table.insert(still, player)
			end
		end
		pad.OnPad = still
	end
end

local function ids(list: { Player }): { number }
	local result = {}
	for _, player in list do
		table.insert(result, player.UserId)
	end
	return result
end

local function playersFrom(userIds: { number }): { Player }
	local result = {}
	for _, id in userIds do
		local player = Players:GetPlayerByUserId(id)
		if player then
			table.insert(result, player)
		end
	end
	return result
end

local function partyMembers(pad: PadState): { Player }
	local owner = pad.Owner
	local settings = pad.Settings
	if owner == nil or settings == nil then
		return {}
	end
	return playersFrom(Party.members(owner.UserId, ids(pad.OnPad), settings.Size))
end

local function failDeparture(pad: PadState, members: { Player }, reason: string)
	for _, player in members do
		teleporting[player] = nil
		notice(player, reason)
		pushOff(pad, player) -- senão o quadrado abriria a tela de novo na hora
	end
	reset(pad)
end

-- Cria (ou confere) a run e leva a party para o lugar Run.
local function depart(pad: PadState, members: { Player })
	pad.Status = "Departing"
	pad.Since = now()
	for _, player in members do
		teleporting[player] = true
	end
	local canTeleport, why = Teleporter.available()
	if not canTeleport then
		failDeparture(pad, members, why or "Teleport is not available")
		return
	end
	local settings = pad.Settings :: Party.Settings
	local runId = pad.RunId
	if runId then
		if RunStore.get(runId) == nil then
			for _, player in members do
				PlayerData.removeRun(player, runId)
			end
			failDeparture(pad, members, "This run no longer exists")
			return
		end
	else
		local names = {}
		for _, player in members do
			table.insert(names, player.DisplayName)
		end
		local record = RunStore.new(settings.Map, settings.Difficulty, ids(members), names)
		if not RunStore.save(record) then
			failDeparture(pad, members, "Could not create the run, try again")
			return
		end
		runId = record.Id
		local summary: Runs.Summary = {
			Id = record.Id,
			Map = record.Map,
			Difficulty = record.Difficulty,
			Members = record.Members,
			Names = record.Names,
			Progress = 0,
			UpdatedAt = os.time(),
		}
		for _, player in members do
			PlayerData.upsertRun(player, summary)
		end
	end
	-- a conta salva antes de trocar de servidor (gemas, runs salvas…)
	for _, player in members do
		PlayerData.save(player)
	end
	local ok, reason = Teleporter.toRun(members, runId :: string)
	if not ok then
		failDeparture(pad, members, reason or "Teleport failed")
		return
	end
	-- os jogadores somem do lobby quando o teleporte termina; o quadrado já pode ser usado de novo
	task.delay(3, function()
		if pad.Status == "Departing" then
			reset(pad)
		end
	end)
end

local function updateBoard(pad: PadState)
	local owner = pad.Owner
	local ownerName = if owner then owner.DisplayName else nil
	local size = if pad.Settings then pad.Settings.Size else PartyConfig.MaxSize
	local count, secondsLeft = #pad.OnPad, nil
	if pad.Status == "Open" then
		count = #partyMembers(pad)
		secondsLeft = Party.departAt(pad.Since, pad.FullSince, PartyConfig.OpenSeconds, PartyConfig.FullSeconds) - now()
	elseif pad.Status == "Loading" then
		local members = pad.RunMembers or {}
		local here = 0
		for _, id in ids(pad.OnPad) do
			if table.find(members, id) then
				here += 1
			end
		end
		count, size = here, #members
		secondsLeft = if pad.FullSince
			then pad.FullSince + PartyConfig.FullSeconds - now()
			else pad.Since + PartyConfig.LoadWaitSeconds - now()
	end
	local title, line = Party.statusText(pad.Status, ownerName, count, size, secondsLeft)
	pad.Info.Title.Text = title
	pad.Info.Line.Text = line
	local color = rgb(PartyConfig.Colors[pad.Status] or PartyConfig.Colors.Empty)
	for _, border in pad.Info.Border do
		border.Color = color
	end
end

local function step(pad: PadState)
	local owner = pad.Owner
	local t = now()
	if pad.Status == "Empty" then
		for _, player in pad.OnPad do
			if not ownsAnyPad(player) then
				pad.Status = "Creating"
				pad.Owner = player
				pad.Since = t
				Remotes.event(Remotes.Names.Events.PartyPrompt):FireClient(player, pad.Info.Index)
				break
			end
		end
	elseif pad.Status == "Creating" then
		if owner == nil or owner.Parent == nil or table.find(pad.OnPad, owner) == nil then
			closeCreating(pad, false)
		elseif t - pad.Since > PartyConfig.CreateTimeoutSeconds then
			closeCreating(pad, true)
		end
	elseif pad.Status == "Open" then
		if owner == nil or owner.Parent == nil or table.find(pad.OnPad, owner) == nil then
			for _, player in pad.OnPad do
				notice(player, "The party leader left the pad")
			end
			reset(pad)
			return
		end
		local members = partyMembers(pad)
		local settings = pad.Settings :: Party.Settings
		if #members >= settings.Size then
			pad.FullSince = pad.FullSince or t
		else
			pad.FullSince = nil
		end
		if t >= Party.departAt(pad.Since, pad.FullSince, PartyConfig.OpenSeconds, PartyConfig.FullSeconds) then
			task.spawn(depart, pad, members)
		end
	elseif pad.Status == "Loading" then
		if owner == nil or owner.Parent == nil or table.find(pad.OnPad, owner) == nil then
			reset(pad)
			return
		end
		local members = pad.RunMembers or {}
		local ready, missing = Runs.canLoad(members, ids(pad.OnPad))
		pad.FullSince = if ready then pad.FullSince or t else nil
		if pad.FullSince and t >= pad.FullSince + PartyConfig.FullSeconds then
			task.spawn(depart, pad, playersFrom(members))
		elseif not ready and t - pad.Since > PartyConfig.LoadWaitSeconds then
			notice(owner, `Everyone in this run must be on the pad ({#missing} missing)`)
			reset(pad)
		end
	end
end

local function padFor(player: Player, index: unknown, status: string): PadState?
	if type(index) ~= "number" then
		return nil
	end
	local pad = pads[index]
	if pad == nil or pad.Owner ~= player or pad.Status ~= status then
		return nil
	end
	return pad
end

function PartyService.init()
	for _, info in LobbyService.pads() do
		local pad: PadState = {
			Info = info,
			Status = "Empty",
			Since = now(),
			OnPad = {},
		}
		table.insert(pads, pad)
	end

	Remotes.func(Remotes.Names.Functions.CreateParty).OnServerInvoke = function(player, index, settings)
		local pad = padFor(player, index, "Creating")
		local entry = PlayerData.get(player)
		if pad == nil or entry == nil then
			return false, "Step on a pad first"
		end
		local clean, why = Party.validate(settings, entry.Wins, MapConfig, DifficultyConfig, PartyConfig.MaxSize)
		if clean == nil then
			return false, why
		end
		pad.Settings = clean
		pad.Status = "Open"
		pad.Since = now()
		pad.FullSince = nil
		return true, nil
	end

	Remotes.func(Remotes.Names.Functions.LoadRun).OnServerInvoke = function(player, index, runId)
		local pad = padFor(player, index, "Creating")
		local entry = PlayerData.get(player)
		if pad == nil or entry == nil or type(runId) ~= "string" then
			return false, "Step on a pad first"
		end
		local found: Runs.Summary? = nil
		for _, summary in entry.SavedRuns do
			if summary.Id == runId then
				found = summary
			end
		end
		if found == nil or Runs.isExpired(found.UpdatedAt, os.time(), RunConfig.SavedRunDays) then
			return false, "This run no longer exists"
		end
		pad.Settings = { Map = found.Map, Difficulty = found.Difficulty, Size = #found.Members }
		pad.RunId = found.Id
		pad.RunMembers = found.Members
		pad.Status = "Loading"
		pad.Since = now()
		pad.FullSince = nil
		return true, nil
	end

	Remotes.func(Remotes.Names.Functions.CancelParty).OnServerInvoke = function(player, index)
		local pad = padFor(player, index, "Creating")
		if pad then
			closeCreating(pad, true)
		end
		return true
	end

	TeleportService.TeleportInitFailed:Connect(function(player, _result, message)
		if teleporting[player] then
			teleporting[player] = nil
			notice(player, `Teleport failed: {message}`)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		teleporting[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(PartyConfig.TickSeconds)
			refreshOnPad()
			for _, pad in pads do
				if pad.Status ~= "Departing" then
					local ok, err = pcall(step, pad)
					if not ok then
						warn("[PartyService] pad", pad.Info.Index, err)
						reset(pad)
					end
				end
				updateBoard(pad)
			end
		end
	end)
end

return PartyService
