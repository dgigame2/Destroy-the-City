--!strict
-- Afasta a câmera conforme o jogador cresce (sem prender o zoom do jogador).

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Place = require(ReplicatedStorage:WaitForChild("Shared").Place)

local localPlayer = Players.LocalPlayer

local MIN_DISTANCE_PER_SCALE = 14 -- câmera nunca fica mais perto que isso * escala
local MAX_DISTANCE_PER_SCALE = 60

local CameraController = {}

local lastScale = 1

local function apply()
	local scale = (localPlayer:GetAttribute("Scale") :: number?) or 1
	local shrunk = scale < lastScale * 0.7
	lastScale = scale
	local wanted = MIN_DISTANCE_PER_SCALE * scale
	localPlayer.CameraMaxZoomDistance = math.max(MAX_DISTANCE_PER_SCALE * scale, 128)
	local camera = Workspace.CurrentCamera
	local focus = camera and camera.Focus.Position
	localPlayer.CameraMinZoomDistance = 0.5 * scale
	if shrunk then
		-- encolheu muito (renasceu ou novo mapa): traz a câmera de volta para perto
		localPlayer.CameraMaxZoomDistance = wanted * 1.5
		task.delay(0.2, function()
			localPlayer.CameraMaxZoomDistance = math.max(MAX_DISTANCE_PER_SCALE * scale, 128)
		end)
		return
	end
	if camera and focus and (camera.CFrame.Position - focus).Magnitude < wanted then
		-- empurra a câmera para trás uma vez e depois libera o zoom de novo
		localPlayer.CameraMinZoomDistance = wanted
		task.delay(0.1, function()
			localPlayer.CameraMinZoomDistance = 0.5 * scale
			if shrunk then
				-- encolheu muito (renasceu ou novo mapa): traz a câmera de volta para perto
				localPlayer.CameraMaxZoomDistance = wanted * 1.5
				task.delay(0.2, function()
					localPlayer.CameraMaxZoomDistance = math.max(MAX_DISTANCE_PER_SCALE * scale, 128)
				end)
				return
			end
		end)
	end
end

-- Modo desastres: o personagem não cresce, mas os desastres sim. A câmera começa afastada (dá para ver o
-- impacto) e o zoom máximo acompanha o poder (alcance dos desastres).
local DISASTER_START = 38 -- distância inicial da câmera
local DISASTER_MAX = 160 -- zoom máximo na partida (ver a área do golpe de longe)

function CameraController.init()
	if Place.isRun() then
		localPlayer.CameraMaxZoomDistance = DISASTER_MAX
		-- empurra a câmera para longe a cada nascimento e depois libera o zoom
		local function pushBack()
			task.wait(0.5)
			localPlayer.CameraMinZoomDistance = DISASTER_START
			task.wait(0.2)
			localPlayer.CameraMinZoomDistance = 8
		end
		localPlayer.CharacterAdded:Connect(pushBack)
		if localPlayer.Character then
			task.spawn(pushBack)
		end
		return
	end
	localPlayer:GetAttributeChangedSignal("Scale"):Connect(apply)
	apply()
end

return CameraController
