--!strict
-- Animações procedurais: aplica as poses do AnimationConfig nas juntas (Motor6D.Transform) de todos
-- os personagens visíveis. O Animate padrão do Roblox foi substituído (StarterCharacterScripts), então
-- nada sobrescreve estas poses.
-- Estados: parado/andando (mistura pela velocidade), pulando, caindo, pousando e mordendo (camada extra).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AnimSampler = require(Shared.Logic.AnimSampler)
local AnimationConfig = require(Shared.Config.AnimationConfig)
local MovementConfig = require(Shared.Config.MovementConfig)

local EatEffects = require(script.Parent.EatEffects)

local AnimationController = {}

-- Junta canônica -> (parte filha, nome do Motor6D) para R15.
local R15: { [string]: { string } } = {
	Root = { "LowerTorso", "Root" },
	Waist = { "UpperTorso", "Waist" },
	Neck = { "Head", "Neck" },
	LeftArm = { "LeftUpperArm", "LeftShoulder" },
	RightArm = { "RightUpperArm", "RightShoulder" },
	LeftForearm = { "LeftLowerArm", "LeftElbow" },
	RightForearm = { "RightLowerArm", "RightElbow" },
	LeftLeg = { "LeftUpperLeg", "LeftHip" },
	RightLeg = { "RightUpperLeg", "RightHip" },
	LeftShin = { "LeftLowerLeg", "LeftKnee" },
	RightShin = { "RightLowerLeg", "RightKnee" },
}

-- R6: só balanço dos membros (eixo Z do Motor6D, lado esquerdo espelhado) e o quique do corpo.
local R6: { [string]: { string } } = {
	Root = { "HumanoidRootPart", "RootJoint" },
	LeftArm = { "Torso", "Left Shoulder" },
	RightArm = { "Torso", "Right Shoulder" },
	LeftLeg = { "Torso", "Left Hip" },
	RightLeg = { "Torso", "Right Hip" },
}

type Rig = {
	Character: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	IsR6: boolean,
	Joints: { [string]: Motor6D },
	Phase: number,
	WalkWeight: number,
	AirTime: number,
	LandAt: number,
	ChompAt: number,
	WasAirborne: boolean,
}

local rigs: { [Model]: Rig } = {}
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function findJoints(character: Model, isR6: boolean): { [string]: Motor6D }
	local joints = {}
	for name, path in (if isR6 then R6 else R15) do
		local part = character:FindFirstChild(path[1])
		local motor = part and part:FindFirstChild(path[2])
		if motor and motor:IsA("Motor6D") then
			joints[name] = motor
		end
	end
	return joints
end

local function track(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if humanoid == nil or root == nil then
		return
	end
	local isR6 = humanoid.RigType == Enum.HumanoidRigType.R6
	if not isR6 then
		character:WaitForChild("RightLowerLeg", 10)
	end
	rigs[character] = {
		Character = character,
		Humanoid = humanoid,
		Root = root,
		IsR6 = isR6,
		Joints = findJoints(character, isR6),
		Phase = math.random(),
		WalkWeight = 0,
		AirTime = 0,
		LandAt = -10,
		ChompAt = -10,
		WasAirborne = false,
	}
	character.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			rigs[character] = nil
		end
	end)
end

local function onPlayer(player: Player)
	player.CharacterAdded:Connect(track)
	if player.Character then
		task.spawn(track, player.Character)
	end
end

-- No chão? Raio para baixo a partir do quadril (funciona também para personagens de outros jogadores).
local function grounded(rig: Rig, scale: number): boolean
	rayParams.FilterDescendantsInstances = { rig.Character }
	-- folga pequena: com folga grande o raio ainda acha o chão durante quase todo o pulo
	local length = (rig.Humanoid.HipHeight + rig.Root.Size.Y / 2) + 0.35 * scale
	return Workspace:Raycast(rig.Root.Position, Vector3.new(0, -length, 0), rayParams) ~= nil
end

local function apply(rig: Rig, pose: AnimSampler.Sample, scale: number)
	for name, motor in rig.Joints do
		local p = pose[name]
		if p == nil then
			motor.Transform = CFrame.identity
			continue
		end
		local pitch, yaw, roll = math.rad(p.Pitch), math.rad(p.Yaw), math.rad(p.Roll)
		if rig.IsR6 then
			if name == "Root" then
				-- RootJoint do R6 é girado: "para cima" é o Z local
				motor.Transform = CFrame.new(0, 0, p.Up * scale)
			else
				local side = if string.sub(name, 1, 4) == "Left" then -1 else 1
				motor.Transform = CFrame.Angles(0, 0, pitch * side)
			end
		elseif name == "Waist" or name == "Neck" then
			-- partes acima da junta: inclinar para a frente é rotação negativa em X
			motor.Transform = CFrame.Angles(-pitch, yaw, roll)
		else
			motor.Transform = CFrame.new(0, p.Up * scale, 0) * CFrame.Angles(pitch, yaw, roll)
		end
	end
end

local function step(dt: number)
	local now = os.clock()
	for character, rig in rigs do
		if rig.Humanoid.Health <= 0 or character.Parent == nil then
			continue
		end
		local scale = character:GetScale()
		local velocity = rig.Root.AssemblyLinearVelocity
		local horizontal = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		local walkSpeed = MovementConfig.WalkSpeed * scale ^ MovementConfig.SpeedScaleExponent
		local airborne = not grounded(rig, scale) and math.abs(velocity.Y) > 1

		-- pouso: estava no ar por um tempinho e encostou no chão
		if rig.WasAirborne and not airborne and rig.AirTime > 0.25 then
			rig.LandAt = now
		end
		rig.AirTime = if airborne then rig.AirTime + dt else 0
		rig.WasAirborne = airborne

		-- base: parado <-> andando, cadência acompanha a velocidade
		local targetWeight = math.clamp(horizontal / (walkSpeed * 0.3), 0, 1)
		rig.WalkWeight += (targetWeight - rig.WalkWeight) * math.min(dt * 10, 1)
		rig.Phase += dt * math.clamp(horizontal / walkSpeed, 0.6, 2.2)
		local idle = AnimSampler.sample(AnimationConfig.Idle, now)
		local walk = AnimSampler.sample(AnimationConfig.Walk, rig.Phase * AnimationConfig.Walk.Duration)
		local pose = AnimSampler.blend(idle, walk, rig.WalkWeight)

		if airborne then
			local rising = velocity.Y > 0
			local air = if rising
				then AnimSampler.sample(AnimationConfig.Jump, rig.AirTime)
				else AnimSampler.sample(AnimationConfig.Fall, rig.AirTime)
			pose = AnimSampler.blend(pose, air, math.clamp(rig.AirTime / 0.12, 0, 1))
		elseif now - rig.LandAt < AnimationConfig.Land.Duration then
			pose = AnimSampler.blend(pose, AnimSampler.sample(AnimationConfig.Land, now - rig.LandAt), 0.85)
		end

		-- mordida por cima de tudo
		local chompTime = now - rig.ChompAt
		if chompTime < AnimationConfig.Chomp.Duration then
			pose = AnimSampler.add(pose, AnimSampler.sample(AnimationConfig.Chomp, chompTime), 1)
		end

		apply(rig, pose, scale)
	end
end

function AnimationController.init()
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	EatEffects.onAnyBite(function(eater: Player)
		local rig = eater.Character and rigs[eater.Character]
		-- mordidas seguidas não reiniciam no meio do movimento
		if rig and os.clock() - rig.ChompAt > AnimationConfig.Chomp.Duration * 0.8 then
			rig.ChompAt = os.clock()
		end
	end)
	-- depois do passo de animação do Roblox e antes da física: nossas poses valem para o quadro
	RunService.PreSimulation:Connect(step)
end

return AnimationController
