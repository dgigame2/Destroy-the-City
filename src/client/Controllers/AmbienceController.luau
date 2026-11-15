--!strict
-- Clima em volta da câmera na run (Config/AmbienceConfig): pétalas no Garden, neve no Frost.
-- Uma peça invisível acompanha a câmera e solta as partículas por cima dela.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AmbienceConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.AmbienceConfig)

local localPlayer = Players.LocalPlayer

local AmbienceController = {}

local emitterPart: Part? = nil
local emitter: ParticleEmitter? = nil

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function build(style: string)
	if emitterPart then
		emitterPart:Destroy()
		emitterPart, emitter = nil, nil
	end
	local weather = (AmbienceConfig.Weather :: any)[style] :: AmbienceConfig.Weather?
	if weather == nil then
		return
	end
	local part = Instance.new("Part")
	part.Name = "Ambience"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.CastShadow = false
	part.Size = Vector3.new(AmbienceConfig.AreaSize, 1, AmbienceConfig.AreaSize)
	local e = Instance.new("ParticleEmitter")
	e.Texture = weather.Texture
	local keys = {}
	for i, c in weather.Colors do
		table.insert(
			keys,
			ColorSequenceKeypoint.new(if #weather.Colors == 1 then 0 else (i - 1) / (#weather.Colors - 1), rgb(c))
		)
	end
	if #keys == 1 then
		table.insert(keys, ColorSequenceKeypoint.new(1, keys[1].Value))
	end
	e.Color = ColorSequence.new(keys)
	e.Rate = weather.Rate
	e.Lifetime = NumberRange.new(weather.Lifetime[1], weather.Lifetime[2])
	e.Speed = NumberRange.new(weather.Speed[1], weather.Speed[2])
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(weather.Drift[1], -weather.Fall, weather.Drift[2])
	e.RotSpeed = NumberRange.new(-weather.Spin, weather.Spin)
	e.Rotation = NumberRange.new(0, 360)
	e.LightEmission = weather.LightEmission
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.1, weather.Size[2]),
		NumberSequenceKeypoint.new(0.85, weather.Size[1]),
		NumberSequenceKeypoint.new(1, 0),
	})
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Parent = part
	part.Parent = Workspace.CurrentCamera
	emitterPart, emitter = part, e
end

local function follow()
	local part, e = emitterPart, emitter
	local camera = Workspace.CurrentCamera
	if part == nil or e == nil or camera == nil then
		return
	end
	local scale = math.clamp((localPlayer:GetAttribute("Scale") :: number?) or 1, 1, AmbienceConfig.MaxAreaScale)
	local side = AmbienceConfig.AreaSize * scale
	if math.abs(part.Size.X - side) > 1 then
		part.Size = Vector3.new(side, 1, side)
		-- um pouco mais de partículas na área maior (com teto, para não pesar)
		local weather = (AmbienceConfig.Weather :: any)[ReplicatedStorage:GetAttribute("RunStyle")]
		if weather then
			e.Rate = weather.Rate * math.min(scale, 2)
		end
	end
	local p = camera.CFrame.Position
	part.CFrame = CFrame.new(p.X, p.Y + AmbienceConfig.AreaHeight * scale * 0.5, p.Z)
end

function AmbienceController.init()
	local function refresh()
		build((ReplicatedStorage:GetAttribute("RunStyle") :: string?) or "")
	end
	ReplicatedStorage:GetAttributeChangedSignal("RunStyle"):Connect(refresh)
	refresh()
	RunService.RenderStepped:Connect(follow)
end

return AmbienceController
