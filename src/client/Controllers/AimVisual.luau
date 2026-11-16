--!strict
-- Desenho da mira dos desastres no chão: círculo tracejado girando (com disco clarinho dentro) e, no tornado,
-- setas em "V" andando na direção em que ele vai. As posições vêm de Logic/AimShapes (testada no Lune);
-- aqui só se movem peças de um estoque fixo (nada é criado a cada frame).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AimConfig = require(Shared.Config.AimConfig)
local AimShapes = require(Shared.Logic.AimShapes)

local AimVisual = {}

local C = AimConfig
local folder: Folder
local fill: Part
local glow: PointLight
local dashes: { Part } = {}
local arrows: { { Part } } = {} -- cada seta = 2 pernas

local function piece(name: string): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = (Enum.Material :: any)[C.Glow.Material] -- neon: traços e setas brilham
	p.Transparency = 1
	p.Parent = folder
	return p
end

function AimVisual.init()
	folder = Instance.new("Folder")
	folder.Name = "DisasterAim"
	folder.Parent = Workspace.CurrentCamera
	fill = piece("Fill")
	fill.Shape = Enum.PartType.Cylinder
	fill.Material = Enum.Material.SmoothPlastic
	glow = Instance.new("PointLight")
	glow.Shadows = false
	glow.Enabled = false
	glow.Parent = fill
	for i = 1, C.Dashes do
		dashes[i] = piece("Dash")
	end
	for i = 1, C.MaxArrows do
		arrows[i] = { piece("ArrowL"), piece("ArrowR") }
	end
end

-- Pasta com todas as peças da mira (o raio do mouse ignora ela).
function AimVisual.folder(): Folder
	return folder
end

function AimVisual.hideArrows()
	for _, pair in arrows do
		pair[1].Transparency = 1
		pair[2].Transparency = 1
	end
end

function AimVisual.hide()
	fill.Transparency = 1
	glow.Enabled = false
	for _, d in dashes do
		d.Transparency = 1
	end
	AimVisual.hideArrows()
end

-- Círculo tracejado em `center` (no chão) com raio `r`. `clock` = tempo, para o giro.
function AimVisual.ring(center: Vector3, r: number, color: Color3, clock: number)
	local y = center.Y + C.Lift
	fill.Size = Vector3.new(0.1, r * 2, r * 2)
	fill.CFrame = CFrame.new(center.X, y - 0.05, center.Z) * CFrame.Angles(0, 0, math.rad(90))
	fill.Color = color
	fill.Transparency = C.FillTransparency
	glow.Color = color
	glow.Range = math.min(r * C.Glow.LightRange, 60) -- PointLight vai até 60
	glow.Brightness = C.Glow.LightBrightness
	glow.Enabled = true
	local width = math.max(r * C.DashWidth, C.MinWidth)
	for i, shape in AimShapes.dashes(center.X, center.Z, r, C.Dashes, C.DashFill, clock * C.Spin) do
		local d = dashes[i]
		d.Size = Vector3.new(width, C.Thickness, shape.Length)
		-- o eixo Z da peça aponta para a direção do traço (Yaw a partir de +X no plano X/Z)
		local dir = Vector3.new(math.cos(shape.Yaw), 0, math.sin(shape.Yaw))
		local at = Vector3.new(shape.X, y, shape.Z)
		d.CFrame = CFrame.lookAt(at, at + dir)
		d.Color = color
		d.Transparency = C.LineTransparency
	end
end

-- Setas do caminho do tornado: de `from` na direção `dir` (unitária, no plano) até `length`, começando na borda
-- do círculo de raio `r`.
function AimVisual.path(from: Vector3, dir: Vector3, length: number, r: number, color: Color3, clock: number)
	local list =
		AimShapes.arrows(from.X, from.Z, dir.X, dir.Z, r, length, r * C.ArrowSpacing, clock * C.ArrowFlow, C.MaxArrows)
	local leg = r * C.ArrowSize
	local width = math.max(r * C.DashWidth * 1.4, C.MinWidth * 1.4)
	local spread = math.rad(C.ArrowAngle)
	local back = -dir
	for i, pair in arrows do
		local a = list[i]
		if a == nil then
			pair[1].Transparency = 1
			pair[2].Transparency = 1
			continue
		end
		local tip = Vector3.new(a.X, from.Y + C.ArrowLift, a.Z)
		for side, p in pair do
			local angle = if side == 1 then spread else -spread
			-- perna: sai da ponta da seta para trás, aberta para um lado
			local legDir = CFrame.fromAxisAngle(Vector3.yAxis, angle):VectorToWorldSpace(back)
			local mid = tip + legDir * (leg / 2)
			p.Size = Vector3.new(width, C.Thickness, leg)
			p.CFrame = CFrame.lookAt(mid, mid + legDir)
			p.Color = color
			p.Transparency = 1 - a.Fade * (1 - C.LineTransparency)
		end
	end
end

return AimVisual
