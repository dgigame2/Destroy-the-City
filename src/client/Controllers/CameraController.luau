--!strict
-- Afasta a câmera conforme o tornado cresce, mantendo os controles nativos.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Place = require(Shared.Place)
local Tornado = require(Shared.Logic.Tornado)
local TornadoConfig = require(Shared.Config.TornadoConfig)

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

local function followTornado()
	local view = TornadoConfig.Camera
	local visual = TornadoConfig.Visual
	local targetDistance: number? = nil
	local humanoid: Humanoid? = nil
	local cameraSignals: { RBXScriptConnection } = {}
	local transition: RBXScriptConnection? = nil

	local function frameTornado()
		local camera = Workspace.CurrentCamera
		if not camera or camera.ViewportSize.X <= 0 or camera.ViewportSize.Y <= 0 then
			return
		end
		local level = (localPlayer:GetAttribute("TornadoLevel") :: number?) or 1
		local radius = Tornado.radius(TornadoConfig, level)
		local form = TornadoConfig.Forms[Tornado.form(TornadoConfig, level)]
		local halfHeight = radius * (form.Height + form.Crown / 2) / 2
		local outerRadius = radius
			* (
				form.Bend
				+ math.max(
					form.Base + visual.BandWidthAtBase / 2,
					form.Top
						* math.max(
							1 + visual.BandWidthAtTop / 2,
							visual.OrbitRadiusScale + visual.SmokeWidthScale * 1.4 / 2
						),
					form.Crown / 2
				)
			)
		local offset = Vector3.new(0, halfHeight - TornadoConfig.RootToGround, 0)
		local aspect = camera.ViewportSize.X / camera.ViewportSize.Y
		local distance = Tornado.cameraDistance(halfHeight, outerRadius, camera.FieldOfView, aspect) * view.Padding
		local maxDistance = math.max(view.MinMaxDistance, distance * view.MaxDistanceScale)
		local previousTarget = targetDistance
		targetDistance = distance
		if transition then
			transition:Disconnect()
			transition = nil
		end
		local subject = humanoid
		if previousTarget == nil then
			localPlayer.CameraMaxZoomDistance = maxDistance
			localPlayer.CameraMinZoomDistance = distance
			if subject then
				subject.CameraOffset = offset
			end
			return
		end
		local from = localPlayer.CameraMinZoomDistance
		local fromOffset = if subject then subject.CameraOffset else offset
		local actualDistance = (camera.CFrame.Position - camera.Focus.Position).Magnitude
		local zoomIn = distance < from
		local fromMax = math.max(actualDistance, from)
		local elapsed = 0
		localPlayer.CameraMaxZoomDistance = maxDistance
		transition = RunService.PreRender:Connect(function(dt)
			elapsed += dt
			local alpha = math.min(elapsed / view.TransitionSeconds, 1)
			local eased = TweenService:GetValue(alpha, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			localPlayer.CameraMinZoomDistance = from + (distance - from) * eased
			if zoomIn then
				localPlayer.CameraMaxZoomDistance = fromMax + (distance - fromMax) * eased
			end
			if subject then
				subject.CameraOffset = fromOffset:Lerp(offset, eased)
			end
			if alpha >= 1 then
				localPlayer.CameraMaxZoomDistance = maxDistance
				if transition then
					transition:Disconnect()
					transition = nil
				end
			end
		end)
	end

	local function watchCamera()
		for _, signal in cameraSignals do
			signal:Disconnect()
		end
		table.clear(cameraSignals)
		local camera = Workspace.CurrentCamera
		if camera then
			table.insert(cameraSignals, camera:GetPropertyChangedSignal("ViewportSize"):Connect(frameTornado))
			table.insert(cameraSignals, camera:GetPropertyChangedSignal("FieldOfView"):Connect(frameTornado))
		end
		frameTornado()
	end

	local function onCharacter(character: Model)
		local subject = character:WaitForChild("Humanoid") :: Humanoid
		if localPlayer.Character == character then
			humanoid = subject
			frameTornado()
		end
	end

	localPlayer:GetAttributeChangedSignal("TornadoLevel"):Connect(frameTornado)
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
	localPlayer.CharacterAdded:Connect(onCharacter)
	watchCamera()
	if localPlayer.Character then
		task.spawn(onCharacter, localPlayer.Character)
	end
end

function CameraController.init()
	if Place.isRun() then
		followTornado()
		return
	end
	localPlayer:GetAttributeChangedSignal("Scale"):Connect(apply)
	apply()
end

return CameraController
