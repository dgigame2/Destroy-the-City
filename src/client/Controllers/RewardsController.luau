--!strict
-- Janela de recompensas: sequência de 7 dias e baú semanal.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rewards = require(Shared.Logic.Rewards)
local RewardConfig = require(Shared.Config.RewardConfig)
local Remotes = require(Shared.Remotes)

local Style = require(script.Parent.Parent.Ui.Style)
local InterfaceController = require(script.Parent.InterfaceController)

local localPlayer = Players.LocalPlayer

local RewardsController = {}

local busy = false

local function dailyState(): (boolean, number, number)
	local lastDay = (localPlayer:GetAttribute("DailyLastDay") :: number?) or -1
	local streak = (localPlayer:GetAttribute("DailyStreak") :: number?) or 0
	local today = Rewards.dayIndex(os.time())
	local canClaim, nextDay = Rewards.daily(lastDay, streak, today, #RewardConfig.Daily)
	-- dias já resgatados nesta sequência
	local claimedThrough = if canClaim then nextDay - 1 else streak
	return canClaim, nextDay, claimedThrough
end

local function weeklyReady(): boolean
	local lastWeek = (localPlayer:GetAttribute("WeeklyLastWeek") :: number?) or -1
	return Rewards.weekly(lastWeek, Rewards.weekIndex(os.time()))
end

local function refresh()
	local refs = InterfaceController.refs()
	local canClaim, nextDay, claimedThrough = dailyState()
	for day, tile in refs.DayTiles do
		local reward = RewardConfig.Daily[day]
		tile.Icon.Text = reward.Icon
		local claimed = day <= claimedThrough
		local today = canClaim and day == nextDay
		tile.Label.Text = if claimed then "✔" else reward.Label
		Style.recolor(
			tile.Face,
			if claimed then Style.Themes.Gray elseif today then Style.Themes.Yellow else Style.Themes.LightBlue
		)
	end
	local wait = Rewards.secondsToNextDay(os.time())
	refs.ClaimDailyText.Text = if canClaim
		then "CLAIM DAY " .. nextDay
		else "NEXT IN " .. InterfaceController.formatTime(wait)
	Style.recolor(refs.ClaimDailyFace, if canClaim then Style.Themes.Green else Style.Themes.Gray)

	local parts = {}
	for _, reward in RewardConfig.Weekly do
		table.insert(parts, reward.Icon .. " " .. reward.Label)
	end
	refs.Weekly.Text = table.concat(parts, "   ")
	local weekly = weeklyReady()
	refs.ClaimWeeklyText.Text = if weekly then "CLAIM" else "CLAIMED"
	Style.recolor(refs.ClaimWeeklyFace, if weekly then Style.Themes.Green else Style.Themes.Gray)
	refs.RewardsBadge.Visible = canClaim or weekly
end

local function claim(remote: string)
	if busy then
		return
	end
	busy = true
	Remotes.func(remote):InvokeServer()
	busy = false
	refresh()
end

function RewardsController.init()
	local refs = InterfaceController.refs()
	InterfaceController.onOpen("Rewards", refresh)
	refs.RewardsIcon.Activated:Connect(function()
		InterfaceController.open("Rewards")
	end)
	refs.ClaimDaily.Activated:Connect(function()
		claim(Remotes.Names.Functions.ClaimDaily)
	end)
	refs.ClaimWeekly.Activated:Connect(function()
		claim(Remotes.Names.Functions.ClaimWeekly)
	end)
	for _, attribute in { "DailyLastDay", "DailyStreak", "WeeklyLastWeek" } do
		localPlayer:GetAttributeChangedSignal(attribute):Connect(refresh)
	end
	refresh()
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= 1 then
			elapsed = 0
			refresh()
		end
	end)
end

return RewardsController
