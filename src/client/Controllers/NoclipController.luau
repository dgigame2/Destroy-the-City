--!strict
-- Noclip de desenvolvedor (DevConfig): /noclip no chat liga/desliga voar atravessando tudo.
-- WASD/analógico seguem a câmera, Espaço sobe, Ctrl ou Q desce, Shift acelera. Só no cliente (o personagem
-- é do próprio jogador); só para quem está em DevConfig.Admins ou no Studio.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local DevConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.DevConfig)

local NoclipController = {}

local player = Players.LocalPlayer
local flying = false
local connection: RBXScriptConnection? = nil

local function allowed(): boolean
	return RunService:IsStudio() or table.find(DevConfig.Admins, player.UserId) ~= nil
end

local function stop()
	flying = false
	if connection then
		connection:Disconnect()
		connection = nil
	end
	local character = player.Character
	if not character then
		return
	end
	for _, p in character:GetDescendants() do
		if p:IsA("BasePart") and p:GetAttribute("NoclipCollide") ~= nil then
			p.CanCollide = p:GetAttribute("NoclipCollide") :: boolean
			p:SetAttribute("NoclipCollide", nil)
		end
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.PlatformStand = false
	end
end

local function start()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (character and humanoid and root) then
		return
	end
	flying = true
	humanoid.PlatformStand = true
	connection = RunService.Stepped:Connect(function()
		if not (character.Parent and root.Parent) then
			stop()
			return
		end
		-- atravessa tudo: desliga a colisão das peças do personagem (guarda o valor para voltar depois)
		for _, p in character:GetDescendants() do
			if p:IsA("BasePart") and p.CanCollide then
				if p:GetAttribute("NoclipCollide") == nil then
					p:SetAttribute("NoclipCollide", true)
				end
				p.CanCollide = false
			end
		end
		local camera = Workspace.CurrentCamera
		local look = camera.CFrame.LookVector
		local move = humanoid.MoveDirection -- já vem relativo à câmera (teclado e analógico)
		-- anda para onde a câmera olha (inclusive para cima/baixo quando olha inclinado)
		local flatLook = Vector3.new(look.X, 0, look.Z)
		local forward = if flatLook.Magnitude > 0.01 then flatLook.Unit else Vector3.zAxis
		local amount = move:Dot(forward)
		local velocity = move + look * amount - forward * amount
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
			velocity += Vector3.yAxis
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.Q) then
			velocity -= Vector3.yAxis
		end
		local fast = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
		local speed = if fast then DevConfig.FastSpeed else DevConfig.FlySpeed
		root.AssemblyLinearVelocity = if velocity.Magnitude > 0.01 then velocity.Unit * speed else Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		root.CFrame = CFrame.lookAlong(root.Position, forward)
	end)
end

local function toggle()
	if not allowed() then
		return
	end
	if flying then
		stop()
	else
		start()
	end
end

function NoclipController.init()
	if not allowed() then
		return
	end
	-- comando do chat novo (TextChatService) e, se o jogo usar o chat antigo, a mensagem digitada
	local command = Instance.new("TextChatCommand")
	command.Name = "NoclipCommand"
	command.PrimaryAlias = DevConfig.NoclipCommand
	command.Triggered:Connect(toggle)
	command.Parent = TextChatService
	player.Chatted:Connect(function(message)
		if string.lower(message) == DevConfig.NoclipCommand then
			toggle()
		end
	end)
	player.CharacterAdded:Connect(function()
		if flying then
			stop()
		end
	end)
end

return NoclipController
