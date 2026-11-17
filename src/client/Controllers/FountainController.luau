--!strict
-- Anima a água da fonte do lobby: troca o quadro visível de cada grupo (cortinas e ondinhas feitas no
-- Blender, assets/blender/build_fountain_water.py) FrameRate vezes por segundo. Só no cliente: é visual.
-- O LobbyService monta os quadros em Lobby.Fountain.WaterFrames (atributos Group e Frame).

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LobbyConfig = require(Shared.Config.LobbyConfig)
local FountainWaterMeshConfig = require(Shared.Config.FountainWaterMeshConfig)

local FountainController = {}

local function play(folder: Instance)
	local cfg = LobbyConfig.FountainWater
	local count = FountainWaterMeshConfig.Frames
	-- quadros de cada grupo, em ordem
	local groups: { [string]: { BasePart } } = {}
	for _, p in folder:GetChildren() do
		local group, frame = p:GetAttribute("Group"), p:GetAttribute("Frame")
		if p:IsA("BasePart") and type(group) == "string" and type(frame) == "number" then
			groups[group] = groups[group] or {}
			groups[group][frame] = p
		end
	end
	local shown = 1
	local clock = 0
	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		if not folder.Parent then
			connection:Disconnect() -- o lobby foi remontado
			return
		end
		clock += dt
		local step = 1 / cfg.FrameRate
		if clock < step then
			return
		end
		clock %= step
		local nextFrame = shown % count + 1
		for _, frames in groups do
			local old, new = frames[shown], frames[nextFrame]
			if old and new then
				new.Transparency = cfg.FrameTransparency
				old.Transparency = 1
			end
		end
		shown = nextFrame
	end)
end

function FountainController.init()
	task.spawn(function()
		local lobby = Workspace:WaitForChild("Lobby", 30)
		local fountain = lobby and lobby:WaitForChild("Fountain", 30)
		local frames = fountain and fountain:WaitForChild("WaterFrames", 10)
		if frames then
			play(frames)
		end
	end)
end

return FountainController
