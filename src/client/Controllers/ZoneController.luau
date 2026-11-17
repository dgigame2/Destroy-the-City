--!strict
-- Efeitos no mundo quando uma área da cidade abre (só na run):
--   * a barreira de campo de força quebra em pedaços que voam e somem (menos de 1 segundo);
--   * setas douradas no chão "andam" do jogador até a passagem da área nova e até o meio dela.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RunConfig = require(Shared.Config.RunConfig)
local Remotes = require(Shared.Remotes)
local GuidePath = require(Shared.Logic.GuidePath)

local Style = require(script.Parent.Parent.Ui.Style)

local localPlayer = Players.LocalPlayer

local ZoneController = {}

local BREAK_SECONDS = 0.8 -- regra do goat: explosões duram menos de 1 segundo
local PIECE_LENGTH = 6
local GUIDE_SECONDS = 25 -- setas somem depois disso (ou assim que você entra na área nova)
local GUIDE_SPACING = 9 -- distância entre setas (x escala)
local GUIDE_SPEED = 14 -- quanto as setas andam por segundo (x escala)
local GUIDE_SIZE = 5 -- tamanho de cada seta (x escala)
local GUIDE_MAX = 60
local GUIDE_COLOR = Style.Colors.Fill

local effects = Instance.new("Folder")
effects.Name = "ZoneEffects"
effects.Parent = Workspace

-- Cópias locais dos campos de força da zona (o servidor apaga os originais quando a zona abre).
local function copyBarrier(zone: number): { BasePart }
	local city = Workspace:FindFirstChild("City")
	local barriers = city and city:FindFirstChild("Barriers")
	local folder = barriers and barriers:FindFirstChild("Zone" .. zone)
	local copies = {}
	if folder == nil then
		return copies
	end
	for _, part in folder:GetChildren() do
		if part:IsA("BasePart") and part.Name == "Field" then
			local copy = part:Clone()
			copy.CanCollide = false
			copy.CanQuery = false
			copy.CanTouch = false
			copy.Transparency = 1 -- só aparece na hora de quebrar
			copy.Parent = effects
			table.insert(copies, copy)
		end
	end
	return copies
end

-- Quebra uma parede em pedaços ao longo do comprimento: cada um sobe, gira, encolhe e some.
local function shatter(wall: BasePart)
	local size = wall.Size
	local alongX = size.X >= size.Z
	local length = if alongX then size.X else size.Z
	local count = math.clamp(math.floor(length / PIECE_LENGTH), 1, 40)
	local step = length / count
	for i = 0, count - 1 do
		local offset = -length / 2 + (i + 0.5) * step
		local piece = wall:Clone()
		piece.Transparency = 0.2
		piece.Size = if alongX then Vector3.new(step, size.Y, size.Z) else Vector3.new(size.X, size.Y, step)
		piece.CFrame = wall.CFrame * CFrame.new(if alongX then offset else 0, 0, if alongX then 0 else offset)
		piece.Parent = effects
		local fly = Vector3.new(math.random(-6, 6), math.random(8, 16), math.random(-6, 6))
		local spin = CFrame.Angles(math.rad(math.random(-90, 90)), math.rad(math.random(-90, 90)), 0)
		TweenService:Create(piece, TweenInfo.new(BREAK_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = piece.CFrame * spin + fly,
			Size = piece.Size * 0.3,
			Transparency = 1,
		}):Play()
		task.delay(BREAK_SECONDS, function()
			piece:Destroy()
		end)
	end
	wall:Destroy()
end

-- Setas no chão que "andam" do jogador até a passagem da área nova e depois até o meio dela (onde
-- fica a placa). Somem sozinhas depois de GuideSeconds ou quando o jogador chega.
local function makeChevron(): Model
	local model = Instance.new("Model")
	model.Name = "Arrow"
	for _, side in { -1, 1 } do
		local bar = Instance.new("Part")
		bar.Anchored = true
		bar.CanCollide = false
		bar.CanQuery = false
		bar.CanTouch = false
		bar.CastShadow = false
		bar.Material = Enum.Material.Neon
		bar.Color = GUIDE_COLOR
		bar:SetAttribute("Side", side)
		bar.Parent = model
	end
	return model
end

local function placeChevron(
	model: Model,
	x: number,
	y: number,
	z: number,
	dirX: number,
	dirZ: number,
	size: number,
	fade: number
)
	local yaw = math.atan2(-dirX, -dirZ) -- frente do CFrame (-Z) na direção do caminho
	local base = CFrame.new(x, y, z) * CFrame.Angles(0, yaw, 0)
	for _, bar in model:GetChildren() do
		local part = bar :: BasePart
		local side = part:GetAttribute("Side") :: number
		part.Size = Vector3.new(size * 0.22, size * 0.08, size * 0.7)
		-- as duas barras formam um ">" apontando para a frente
		part.CFrame = base * CFrame.new(side * size * 0.22, 0, 0) * CFrame.Angles(0, side * math.rad(40), 0)
		part.Transparency = fade
	end
end

local guideConnection: RBXScriptConnection? = nil

local function guide(zone: number, boxes: { GuidePath.Box })
	if guideConnection then
		guideConnection:Disconnect()
		guideConnection = nil
	end
	local city = Workspace:FindFirstChild("City")
	local labels = city and city:FindFirstChild("ZoneLabels")
	local point = labels and labels:FindFirstChild("Zone" .. zone) :: BasePart?
	local folder = Instance.new("Folder")
	folder.Name = "GuideArrows"
	folder.Parent = effects
	local pool: { Model } = {}
	local start = os.clock()
	guideConnection = RunService.RenderStepped:Connect(function()
		local character = localPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local elapsed = os.clock() - start
		local scale = (localPlayer:GetAttribute("Scale") :: number?) or 1
		local finish = point and Vector2.new(point.Position.X, point.Position.Z)
		-- passou da barreira para dentro da área nova: as setas somem
		local arrived = root
			and finish
			and GuidePath.inside(root.Position.X, root.Position.Z, { finish.X, finish.Y }, boxes)
		if root == nil or elapsed > GUIDE_SECONDS or arrived then
			folder:Destroy()
			if guideConnection then
				guideConnection:Disconnect()
				guideConnection = nil
			end
			return
		end
		local here = root :: BasePart
		local path: { GuidePath.Point } = { { here.Position.X, here.Position.Z } }
		local gate = GuidePath.nearestGate(here.Position.X, here.Position.Z, boxes)
		if gate then
			table.insert(path, gate)
		end
		if finish then
			table.insert(path, { finish.X, finish.Y })
		end
		local spacing = GUIDE_SPACING * scale
		local arrows = GuidePath.arrows(path, spacing, elapsed * GUIDE_SPEED * scale + spacing * 0.6, GUIDE_MAX)
		-- some no último segundo
		local fade = math.clamp(1 - (GUIDE_SECONDS - elapsed), 0, 1) * 0.8 + 0.1
		local y = here.Position.Y - (character :: Model):GetExtentsSize().Y * 0.5 + 0.3
		for index, arrow in arrows do
			local model = pool[index]
			if model == nil then
				model = makeChevron()
				model.Parent = folder
				pool[index] = model
			end
			placeChevron(model, arrow.X, y, arrow.Z, arrow.DirX, arrow.DirZ, GUIDE_SIZE * scale, fade)
		end
		for index = #arrows + 1, #pool do
			for _, bar in pool[index]:GetChildren() do
				(bar :: BasePart).Transparency = 1
			end
		end
	end)
end

-- Barreiras da zona viram caixas no plano (antes de quebrarem).
local function boxesOf(walls: { BasePart }): { GuidePath.Box }
	local boxes = {}
	for _, wall in walls do
		table.insert(
			boxes,
			{ X = wall.Position.X, Z = wall.Position.Z, HalfX = wall.Size.X / 2, HalfZ = wall.Size.Z / 2 }
		)
	end
	return boxes
end

function ZoneController.init()
	Remotes.event(Remotes.Names.Events.ZoneCleared).OnClientEvent:Connect(function(info: any)
		local copies = copyBarrier(info.NextIndex)
		local boxes = boxesOf(copies)
		task.delay(RunConfig.ZoneCelebrationSeconds, function()
			for _, wall in copies do
				shatter(wall)
			end
			guide(info.NextIndex, boxes)
		end)
	end)
end

return ZoneController
