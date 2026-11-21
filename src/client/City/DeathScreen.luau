--!strict
-- Tela de morte que motiva (estudo GMTK/Cuphead: mostrar o quão perto você estava) e comemoração de quem matou.
--   Died (servidor -> vítima): "DESTROYED BY X (LV N)" + "você estava a 82% do LV 9" (ou "já dava para EVOLVE!").
--   Killed (servidor -> quem matou): som forte + tremida + "+N XP".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Pvp = require(Shared.Logic.Pvp)
local Tornado = require(Shared.Logic.Tornado)
local TornadoConfig = require(Shared.Config.TornadoConfig)
local Remotes = require(Shared.Remotes)

local Feedback = require(script.Parent.Parent.Feedback)
local Style = require(script.Parent.Parent.Ui.Style)

local DeathScreen = {}

local SECONDS = 4 -- tempo na tela (o renascimento leva mais ou menos isso)
local tcfg = TornadoConfig :: Tornado.Config
local localPlayer = Players.LocalPlayer

local holder: Frame
local title: TextLabel
local line: TextLabel
local token = 0

local function build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "DeathScreen"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 40
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.Parent = localPlayer:WaitForChild("PlayerGui")
	local face
	holder, face = Style.panel("Death", Style.Themes.Night, 18)
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.4)
	holder.Size = UDim2.fromOffset(340, 96)
	holder.Visible = false
	holder.Parent = gui
	title = Style.label("Title", "", 24)
	title.Position = UDim2.fromOffset(10, 8)
	title.Size = UDim2.new(1, -20, 0, 34)
	title.TextColor3 = Color3.fromRGB(255, 110, 110)
	title.TextScaled = true
	local titleSize = Instance.new("UITextSizeConstraint")
	titleSize.MaxTextSize = 24
	titleSize.Parent = title
	title.Parent = face
	line = Style.label("Line", "", 18)
	line.Position = UDim2.fromOffset(10, 48)
	line.Size = UDim2.new(1, -20, 0, 36)
	line.TextWrapped = true
	line.Parent = face
end

local function onDied(killer: any, level: any, lost: any, killerLevel: any)
	if type(killer) ~= "string" or type(level) ~= "number" or type(lost) ~= "number" then
		return
	end
	local pct, could = Pvp.deathProgress(tcfg, level, lost)
	title.Text = if type(killerLevel) == "number"
		then `DESTROYED BY {string.upper(killer)} (LV {killerLevel})`
		else `DESTROYED BY {string.upper(killer)}`
	line.Text = if could
		then "You already had enough XP to EVOLVE! Press R sooner."
		else `You were {pct}% of the way to LV {level + 1}!`
	token += 1
	local mine = token
	holder.Visible = true
	holder.Size = UDim2.fromOffset(300, 84)
	TweenService:Create(holder, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(340, 96) }):Play()
	Feedback.shake(0.8, 0.4)
	task.delay(SECONDS, function()
		if token == mine then
			holder.Visible = false
		end
	end)
end

local function onKilled(victim: any, gain: any)
	if type(victim) ~= "string" or type(gain) ~= "number" then
		return
	end
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	Feedback.play("Kill", { World = if root then root.Position else nil, Amount = gain })
end

function DeathScreen.init()
	build()
	Remotes.event(Remotes.Names.Events.Died).OnClientEvent:Connect(onDied)
	Remotes.event(Remotes.Names.Events.Killed).OnClientEvent:Connect(onKilled)
end

return DeathScreen
