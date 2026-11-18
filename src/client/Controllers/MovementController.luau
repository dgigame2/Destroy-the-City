--!strict
-- Movimento do jogador local: pulo só no lobby (na run fica desligado) e a animação padrão do Roblox de
-- andar/correr.
-- O Animate padrão acha que o personagem continua do tamanho normal (o crescimento do jogo não é o do Roblox),
-- então as pernas ficariam rápidas demais num gigante. Antes de cada passo de animação, a velocidade das
-- animações de andar/correr é recalculada pela velocidade real dividida pelo tamanho: o pé acompanha o chão.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Stride = require(Shared.Logic.Stride)
local MovementConfig = require(Shared.Config.MovementConfig)
local Place = require(Shared.Place)

local localPlayer = Players.LocalPlayer

local MovementController = {}

local function onCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if humanoid then
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, not Place.isRun())
	end
end

local function adjustStride()
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if animator == nil or root == nil then
		return
	end
	local walk: AnimationTrack?, run: AnimationTrack? = nil, nil
	for _, track in animator:GetPlayingAnimationTracks() do
		local name = track.Animation and track.Animation.Name
		if name == "WalkAnim" then
			walk = track
		elseif name == "RunAnim" then
			run = track
		end
	end
	if walk == nil and run == nil then
		return
	end
	local velocity = root.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local scale = (localPlayer:GetAttribute("Scale") :: number?) or 1
	local blend = Stride.blend(Stride.normalized(speed, scale, MovementConfig.AnimationWalkSpeed))
	if walk then
		walk:AdjustWeight(blend.WalkWeight, 0.1)
		walk:AdjustSpeed(blend.WalkSpeed)
	end
	if run then
		run:AdjustWeight(blend.RunWeight, 0.1)
		run:AdjustSpeed(blend.RunSpeed)
	end
end

function MovementController.init()
	localPlayer.CharacterAdded:Connect(onCharacter)
	if localPlayer.Character then
		task.spawn(onCharacter, localPlayer.Character)
	end
	RunService.PreAnimation:Connect(adjustStride)
end

return MovementController
