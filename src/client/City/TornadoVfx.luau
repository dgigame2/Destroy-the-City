--!strict
-- Corpo e vento dos tornados feitos em peças (Config/SpinModelConfig).
--   Corpo: cada peça gira no próprio eixo e o corpo ondula e atrasa ao andar (Logic/TornadoSway).
--   Vento: fitas finas que sobem em espiral pelo corpo, com fiapos saindo delas, em trios (nenhum lado pesa mais).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ElementFxConfig = require(Shared.Config.ElementFxConfig)
local SpinModelConfig = require(Shared.Config.SpinModelConfig)
local TornadoSway = require(Shared.Logic.TornadoSway)

local TornadoVfx = {}

local ribbonCfg = SpinModelConfig.Ribbon
local wispCfg = SpinModelConfig.Wisp
local sway = SpinModelConfig.Sway

type Strand = { A: Attachment, B: Attachment, Trail: Trail, Wisp: ParticleEmitter, T: number }
type Jet = { At: Attachment, Emitter: ParticleEmitter, Def: SpinModelConfig.Jet, Phase: number }
export type Vfx = {
	Root: BasePart,
	Def: SpinModelConfig.Model,
	Strands: { Strand },
	Jets: { Jet },
	Quality: number,
	Time: number,
	Sway: TornadoSway.State,
	Unit: number,
	Enabled: boolean,
	Own: boolean,
}

local function keys(points: { { number } }, scale: number?): NumberSequence
	local list = {}
	for _, p in points do
		table.insert(list, NumberSequenceKeypoint.new(p[1], p[2] * (scale or 1)))
	end
	return NumberSequence.new(list)
end

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- root: peça âncora do tornado, sem giro (as fitas ficam presas nela).
function TornadoVfx.new(root: BasePart, def: SpinModelConfig.Model, own: boolean): Vfx
	local strands: { Strand } = {}
	local count = if own then ribbonCfg.Own else ribbonCfg.Others
	for i = 1, count do
		local a, b = Instance.new("Attachment"), Instance.new("Attachment")
		a.Name, b.Name = "WindA", "WindB"
		a.Parent, b.Parent = root, root
		local trail = Instance.new("Trail")
		trail.Attachment0, trail.Attachment1 = a, b
		trail.Lifetime = ribbonCfg.Seconds
		trail.MinLength = 0.1
		trail.FaceCamera = false -- de frente para a câmera a fita vira um borrão largo
		trail.Color = ColorSequence.new(rgb(def.Light), rgb(def.Tint))
		trail.Transparency = keys(ribbonCfg.Alpha)
		trail.WidthScale = keys(ribbonCfg.Width)
		trail.LightEmission = 0
		trail.LightInfluence = 1
		trail.Parent = root
		local wisp = Instance.new("ParticleEmitter")
		wisp.Texture = ElementFxConfig.Textures.Smoke
		wisp.Color = ColorSequence.new(rgb(def.Light), rgb(def.Tint))
		wisp.Orientation = Enum.ParticleOrientation.VelocityParallel
		wisp.Squash = NumberSequence.new(wispCfg.Squash)
		wisp.Lifetime = NumberRange.new(wispCfg.Seconds * 0.7, wispCfg.Seconds)
		wisp.Transparency = keys(wispCfg.Alpha)
		wisp.EmissionDirection = Enum.NormalId.Front
		wisp.SpreadAngle = Vector2.new(10, 10)
		wisp.Drag = 2
		wisp.LightEmission = 0
		wisp.LightInfluence = 1
		wisp.Parent = a
		-- trios: três fitas na mesma altura, o segundo trio meia subida depois
		strands[i] = { A = a, B = b, Trail = trail, Wisp = wisp, T = math.floor((i - 1) / 3) * 3 / count }
	end
	local jets: { Jet } = {}
	for _, j in SpinModelConfig.Jets do
		for k = 0, 2 do
			local at = Instance.new("Attachment")
			at.Name = "WindJet"
			at.Parent = root
			local e = Instance.new("ParticleEmitter")
			e.Texture = ElementFxConfig.Textures.Smoke
			e.Color = ColorSequence.new(rgb(if j.Dust then def.DustColor else def.Light), rgb(def.Tint))
			if j.Squash > 0 then
				e.Orientation = Enum.ParticleOrientation.VelocityParallel
				e.Squash = NumberSequence.new(j.Squash)
			else
				e.Rotation = NumberRange.new(0, 360)
				e.RotSpeed = NumberRange.new(60, 150)
			end
			e.Lifetime = NumberRange.new(j.Seconds * 0.7, j.Seconds)
			e.Transparency = keys(j.Alpha)
			e.EmissionDirection = Enum.NormalId.Front
			e.SpreadAngle = Vector2.new(14, 14)
			e.Drag = 2.5
			e.LightEmission = 0
			e.LightInfluence = 1
			e.Parent = at
			table.insert(jets, { At = at, Emitter = e, Def = j, Phase = k * 2 * math.pi / 3 + j.T * 4 })
		end
	end
	return {
		Root = root,
		Def = def,
		Strands = strands,
		Jets = jets,
		Quality = 1,
		Time = 0,
		Sway = TornadoSway.new(),
		Unit = 1,
		Enabled = true,
		Own = own,
	}
end

-- unit: studs por unidade do modelo. quality: multiplicador de partículas (aparelho e dono).
function TornadoVfx.resize(vfx: Vfx, unit: number, quality: number)
	vfx.Unit = unit
	vfx.Quality = quality
	for _, j in vfx.Jets do
		j.Emitter.Rate = j.Def.Rate * quality
		j.Emitter.Size = keys(j.Def.Size, unit)
		j.Emitter.Speed = NumberRange.new(j.Def.Speed * 0.7 * unit, j.Def.Speed * unit)
	end
	for _, s in vfx.Strands do
		s.Wisp.Rate = wispCfg.Rate * quality
		s.Wisp.Size = keys(wispCfg.Size, unit)
		s.Wisp.Speed = NumberRange.new(wispCfg.Speed * 0.7 * unit, wispCfg.Speed * unit)
	end
end

local function setEnabled(vfx: Vfx, enabled: boolean)
	if vfx.Enabled == enabled then
		return
	end
	vfx.Enabled = enabled
	for _, j in vfx.Jets do
		j.Emitter.Enabled = enabled
		if not enabled then
			j.Emitter:Clear()
		end
	end
	for _, s in vfx.Strands do
		s.Trail.Enabled = enabled
		s.Wisp.Enabled = enabled
		if not enabled then
			s.Trail:Clear()
			s.Wisp:Clear()
		end
	end
end

local function profile(points: { { number } }, t: number): number
	for i = 2, #points do
		local p, q = points[i - 1], points[i]
		if t <= q[1] then
			return p[2] + (q[2] - p[2]) * (t - p[1]) / (q[1] - p[1])
		end
	end
	return points[#points][2]
end

-- Ponto da espinha na altura t e a inclinação dela ali (unidades do modelo).
local function bend(vfx: Vfx, t: number): (number, number, CFrame)
	local x, z = TornadoSway.offset(sway, vfx.Sway, t)
	local h = vfx.Def.Height
	local e = 0.04
	local x1, z1 = TornadoSway.offset(sway, vfx.Sway, math.max(t - e, 0))
	local x2, z2 = TornadoSway.offset(sway, vfx.Sway, t + e)
	local span = (t + e - math.max(t - e, 0)) * h
	local sx, sz = (x2 - x1) / span, (z2 - z1) / span
	local slope = math.sqrt(sx * sx + sz * sz)
	local tilt = if slope > 1e-4
		then CFrame.fromAxisAngle(Vector3.new(sz, 0, -sx) / slope, math.atan(slope) * SpinModelConfig.PieceTilt)
		else CFrame.identity
	return x, z, tilt
end

-- base: chão do tornado, sem giro. angle: giro acumulado do corpo. mx, mz: velocidade / velocidade de andar.
function TornadoVfx.update(
	vfx: Vfx,
	model: Model,
	base: CFrame,
	angle: number,
	dt: number,
	mx: number,
	mz: number,
	hidden: boolean
)
	TornadoSway.step(sway, vfx.Sway, dt, mx, mz)
	local unit, height = vfx.Unit, vfx.Def.Height
	for _, part in model:GetChildren() do
		local piece = vfx.Def.Pieces[part.Name]
		if piece and part:IsA("BasePart") then
			local o, c = piece.Origin, piece.Center
			local x, z, tilt = bend(vfx, o[2] / height)
			part.CFrame = base
				* CFrame.new((o[1] + x) * unit, o[2] * unit, (o[3] + z) * unit)
				* tilt
				* CFrame.Angles(0, angle * piece.Speed, 0)
				* CFrame.new(c[1] * unit, c[2] * unit, c[3] * unit)
		end
	end
	local camera = Workspace.CurrentCamera
	local far = camera ~= nil
		and (camera.CFrame.Position - base.Position).Magnitude > SpinModelConfig.MaxDistance + unit * 10
	setEnabled(vfx, not hidden and not far)
	if not vfx.Enabled then
		return
	end
	vfx.Time += dt
	local moving = math.min(math.sqrt(mx * mx + mz * mz), 1)
	for _, j in vfx.Jets do
		local d = j.Def
		local x, z, tilt = bend(vfx, d.T)
		local a = j.Phase + vfx.Time * d.Turns * 2 * math.pi
		local out = Vector3.new(math.cos(a), 0, -math.sin(a))
		local at = (Vector3.new(x, d.T * height, z) + out * d.Radius) * unit
		-- vento reto em volta do corpo, deitado junto com a onda
		local along = tilt * (Vector3.new(-math.sin(a), d.Up, -math.cos(a)) + out * d.Out)
		j.At.CFrame = CFrame.lookAt(at, at + along)
		j.Emitter.Rate = d.Rate * vfx.Quality * (1 + d.Move * moving)
	end
	for i, s in vfx.Strands do
		s.T += dt / ribbonCfg.Climb
		if s.T >= 1 then
			s.T %= 1
			s.Trail:Clear() -- sem risco do topo até o pé
		end
		local t = s.T
		local x, z, tilt = bend(vfx, t)
		local r = profile(vfx.Def.Profile, t) * ribbonCfg.Reach + ribbonCfg.Gap
		-- mesmo sentido do giro do corpo (sentido anti-horário visto de cima, -Z = frente da partícula)
		local a = i * 2 * math.pi / 3 + math.floor((i - 1) / 3) * 2 * math.pi / 9 + t * ribbonCfg.Turns * 2 * math.pi
		local at = Vector3.new(x + math.cos(a) * r, t * height, z - math.sin(a) * r) * unit
		local out = Vector3.new(math.cos(a), 0, -math.sin(a))
		local along = tilt * Vector3.new(-math.sin(a), 0, -math.cos(a))
		local half = tilt.YVector * (ribbonCfg.Size * (0.4 + 0.6 * t) * unit / 2)
		s.A.CFrame = CFrame.lookAt(at + half, at + half + along, out)
		s.B.Position = at - half
	end
end

function TornadoVfx.destroy(vfx: Vfx)
	for _, j in vfx.Jets do
		j.At:Destroy()
	end
	for _, s in vfx.Strands do
		s.Trail:Destroy()
		s.A:Destroy()
		s.B:Destroy()
	end
end

return TornadoVfx
