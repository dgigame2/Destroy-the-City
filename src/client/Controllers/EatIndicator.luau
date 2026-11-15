--!strict
-- Indicador de comer (só na run, só no cliente):
--   * um círculo no chão em volta do jogador mostra o alcance da boca (tudo que entrar nele e couber, é comido);
--     ele pisca quando você come algo;
--   * construções grandes demais dentro do alcance ficam com contorno vermelho e "🔒 BIGGER" em cima,
--     para ficar claro por que não estão sendo comidas.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EatConfig = require(Shared.Config.EatConfig)
local EatQuery = require(Shared.EatQuery)

local EatEffects = require(script.Parent.EatEffects)

local localPlayer = Players.LocalPlayer

local EatIndicator = {}

local RING_COLOR = Color3.fromRGB(255, 227, 107)
local LOCKED_COLOR = Color3.fromRGB(255, 80, 80)

local ring: Part
local ringTween: Tween? = nil
local locked: { [Model]: { Highlight: Highlight, Tag: BillboardGui } } = {}
local queryParams = OverlapParams.new()
queryParams.FilterType = Enum.RaycastFilterType.Include

local function buildingsFolder(): Folder?
	local city = Workspace:FindFirstChild("City")
	return city and city:FindFirstChild("Buildings") :: Folder?
end

local function makeRing(): Part
	local part = Instance.new("Part")
	part.Name = "EatRange"
	part.Shape = Enum.PartType.Cylinder
	part.Material = Enum.Material.Neon
	part.Color = RING_COLOR
	part.Transparency = 0.8
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	-- fica dentro da câmera: é só deste jogador e não vai para o servidor
	part.Parent = Workspace.CurrentCamera
	return part
end

local function rootAndRadius(): (BasePart?, Humanoid?, number)
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local radius = (localPlayer:GetAttribute("EatRadius") :: number?) or 0
	if humanoid == nil or humanoid.Health <= 0 or not localPlayer:GetAttribute("InMatch") then
		return nil, nil, radius
	end
	return root, humanoid, radius
end

local function updateRing()
	local root, humanoid, radius = rootAndRadius()
	if root == nil or humanoid == nil or radius <= 0 then
		ring.Transparency = 1
		return
	end
	if ringTween == nil then
		ring.Transparency = 0.8
	end
	local feet = root.Position.Y - root.Size.Y / 2 - humanoid.HipHeight
	ring.Size = Vector3.new(0.15, radius * 2, radius * 2)
	-- cilindro deitado: o eixo dele (X) aponta para cima
	ring.CFrame = CFrame.new(root.Position.X, feet + 0.12, root.Position.Z) * CFrame.Angles(0, 0, math.rad(90))
end

local function clearLocked(model: Model)
	local entry = locked[model]
	if entry then
		entry.Highlight:Destroy()
		entry.Tag:Destroy()
		locked[model] = nil
	end
end

local function markLocked(model: Model)
	if locked[model] then
		return
	end
	local highlight = Instance.new("Highlight")
	highlight.FillTransparency = 1
	highlight.OutlineColor = LOCKED_COLOR
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Adornee = model
	highlight.Parent = Workspace.CurrentCamera
	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.fromOffset(150, 40)
	tag.StudsOffsetWorldSpace = Vector3.new(0, model:GetExtentsSize().Y / 2 + 2, 0)
	tag.AlwaysOnTop = true
	tag.Adornee = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.Text = "🔒 BIGGER"
	text.TextColor3 = LOCKED_COLOR
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(11, 18, 48)
	stroke.Parent = text
	text.Parent = tag
	tag.Parent = Workspace.CurrentCamera
	locked[model] = { Highlight = highlight, Tag = tag }
end

-- Construções no alcance que ainda não dá para comer (mesma "boca" do servidor, EatService).
local function updateLocked()
	local root, _, radius = rootAndRadius()
	local buildings = buildingsFolder()
	local seen: { [Model]: boolean } = {}
	if root and buildings and radius > 0 then
		local edible = (localPlayer:GetAttribute("EdibleTier") :: number?) or 0
		queryParams.FilterDescendantsInstances = { buildings }
		local count = 0
		for _, hit in EatQuery.inReach(root.Position, radius, buildings, queryParams) do
			local model = hit.Model
			if not seen[model] then
				seen[model] = true
				local tier = (model:GetAttribute("Tier") :: number?) or 0
				local zone = (model:GetAttribute("Zone") :: number?) or 1
				local open = (ReplicatedStorage:GetAttribute("RunZone") :: number?) or 1
				-- construções de áreas ainda fechadas ficam atrás da barreira: sem aviso
				if zone <= open and tier > edible and count < EatConfig.MaxLockedHints then
					count += 1
					markLocked(model)
				end
			end
		end
	end
	for model in locked do
		if not seen[model] or model.Parent == nil then
			clearLocked(model)
		end
	end
end

-- Pisca o círculo quando você come algo.
local function flash()
	if ringTween then
		ringTween:Cancel()
	end
	ring.Transparency = 0.35
	local tween = TweenService:Create(ring, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { Transparency = 0.8 })
	ringTween = tween
	tween.Completed:Once(function()
		if ringTween == tween then
			ringTween = nil
		end
	end)
	tween:Play()
end

function EatIndicator.init()
	ring = makeRing()
	RunService.RenderStepped:Connect(updateRing)
	EatEffects.onLocalBite(flash)
	task.spawn(function()
		while true do
			task.wait(EatConfig.LockedHintSeconds)
			updateLocked()
		end
	end)
end

return EatIndicator
