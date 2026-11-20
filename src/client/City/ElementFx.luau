--!strict
-- Efeitos dos golpes dos elementos (só visual; o dano é do servidor e chega pelo CityDelta).
--   FOGO: bola de fogo cai do lado de quem lançou, com rastro; no impacto, chamas, brasas, fumaça,
--         anel de choque e clarão laranja.
--   RAIO: raio em zigue-zague do céu com galhos, pisca duas vezes (outro desenho), faíscas, anel e clarão azul.
--   VENTO: redemoinho de 3 fios que gira, abre e sobe, poeira, folhinhas e anel no chão.
-- Otimização (prioridade do projeto): cada efeito é um "kit" montado UMA vez e reaproveitado (pool por
-- elemento); partículas só por Emit() (nenhum emissor ligado); um único Heartbeat anima tudo; teto de efeitos
-- ao mesmo tempo; partículas caem com a qualidade gráfica e para os golpes dos outros jogadores.
-- Números em Config/ElementFxConfig; matemática em Logic/ElementFxMath (testada no Lune).
-- Chega por UnreliableRemoteEvent: se um se perder, só some o efeito.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ElementConfig = require(Shared.Config.ElementConfig)
local ElementFxConfig = require(Shared.Config.ElementFxConfig)
local ElementFxMath = require(Shared.Logic.ElementFxMath)

local QualityTier = require(script.Parent.QualityTier)

local ElementFx = {}

type Point = ElementFxMath.Point

type Kit = {
	Element: string,
	Root: Part, -- invisível, no ponto do impacto (as partículas saem do Center)
	Center: Attachment,
	Emitters: { [string]: ParticleEmitter },
	Light: PointLight,
	Ball: Part?, -- fogo: bola que cai / raio: brilho no impacto
	BallEmitter: ParticleEmitter?,
	Trail: Trail?,
	Segments: { Part }?, -- raio
	Beams: { { Beam: Beam, A0: Attachment, A1: Attachment } }?, -- vento
}

type Active = {
	Kit: Kit,
	Own: boolean,
	At: Vector3,
	R: number, -- raio do efeito (studs)
	Age: number,
	Start: Point?, -- fogo: de onde a bola vem
	Impacted: boolean,
	Redrawn: boolean,
	ArcFrom: Vector3?, -- raio: arco entre dois pontos (cadeia) em vez de cair do céu
}

local F = ElementFxConfig
local localPlayer = Players.LocalPlayer
local folder: Folder? = nil
local pools: { [string]: { Kit } } = {}
local active: { Active } = {}
local counts = { Own = 0, Others = 0 }
local rng = Random.new()
local function rand(): number
	return rng:NextNumber()
end

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function v3(p: Point): Vector3
	return Vector3.new(p.X, p.Y, p.Z)
end

local function container(): Folder
	if folder == nil or folder.Parent == nil then
		local f = Instance.new("Folder")
		f.Name = "ElementFx"
		f.Parent = Workspace
		folder = f
	end
	return folder :: Folder
end

local function quality(): number
	local ok, level = pcall(function()
		return (UserSettings():GetService("UserGameSettings") :: any).SavedQualityLevel.Value
	end)
	local q = ElementFxMath.quality(if ok and type(level) == "number" then level else 0, F.QualityMin, F.QualityAuto)
	return q * QualityTier.current().Particles
end

-- ===== montagem dos kits (uma vez por kit; depois só reaproveita) =====

local function part(name: string, shape: Enum.PartType, color: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = Vector3.one
	return p
end

local function emitter(name: string, texture: string, color: ColorSequence, parent: Instance): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Texture = texture
	e.Color = color
	e.Enabled = false
	e.LightEmission = 1
	e.LightInfluence = 0
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-90, 90)
	e.Parent = parent
	return e
end

local function seq3(a: Color3, b: Color3, c: Color3): ColorSequence
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, a),
		ColorSequenceKeypoint.new(0.4, b),
		ColorSequenceKeypoint.new(1, c),
	})
end

local function fadeOut(from: number): NumberSequence
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, from), NumberSequenceKeypoint.new(1, 1) })
end

local function newKit(elementId: string): Kit
	local root = part("Fx" .. elementId, Enum.PartType.Block, Color3.new(1, 1, 1))
	local center = Instance.new("Attachment")
	center.Name = "Center"
	center.Position = Vector3.new(0, 0.4, 0) -- logo acima do chão (o anel não some dentro dele)
	center.Parent = root
	local light = Instance.new("PointLight")
	light.Enabled = false
	light.Shadows = false
	light.Parent = root
	local kit: Kit = {
		Element = elementId,
		Root = root,
		Center = center,
		Emitters = {},
		Light = light,
	}

	-- anel de choque: 1 partícula deitada no chão (textura de onda de choque do Roblox) que abre e some
	local ringColor = if elementId == "Fire"
		then F.Fire.Hot
		elseif elementId == "Lightning" then F.Lightning.Glow
		else F.Wind.Strand
	local shock = emitter("Shock", F.Textures.Shock, ColorSequence.new(rgb(ringColor)), center)
	shock.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
	shock.EmissionDirection = Enum.NormalId.Top
	shock.SpreadAngle = Vector2.zero
	shock.Speed = NumberRange.new(0.01)
	shock.RotSpeed = NumberRange.new(0)
	shock.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(0.6, 0.5),
		NumberSequenceKeypoint.new(1, 1),
	})
	kit.Emitters.Shock = shock

	if elementId == "Fire" then
		local c = F.Fire
		light.Color = rgb(c.Hot)
		local flames = emitter("Flames", F.Textures.Fire, seq3(rgb(c.Core), rgb(c.Hot), rgb(c.Deep)), center)
		flames.Transparency = fadeOut(0.05)
		flames.Lifetime = NumberRange.new(0.35, 0.6)
		flames.Drag = 4
		kit.Emitters.Flames = flames
		local embers = emitter("Embers", F.Textures.Sparks, ColorSequence.new(rgb(c.Core), rgb(c.Hot)), center)
		embers.Transparency = fadeOut(0)
		embers.Lifetime = NumberRange.new(0.4, 0.75)
		embers.Drag = 1.5
		kit.Emitters.Embers = embers
		local smoke = emitter("Smoke", F.Textures.Smoke, ColorSequence.new(rgb(c.SmokeColor)), center)
		smoke.LightEmission = 0
		smoke.LightInfluence = 1
		smoke.Transparency = fadeOut(0.45)
		smoke.Lifetime = NumberRange.new(0.6, 0.9)
		smoke.Drag = 2
		kit.Emitters.Smoke = smoke
		-- bola de fogo com rastro e chama própria
		local ball = part("Ball", Enum.PartType.Ball, rgb(c.Hot))
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Parent, a1.Parent = ball, ball
		local trail = Instance.new("Trail")
		trail.Attachment0, trail.Attachment1 = a0, a1
		trail.Color = ColorSequence.new(rgb(c.Core), rgb(c.Deep))
		trail.Transparency = NumberSequence.new(0.1, 1)
		trail.Lifetime = c.TrailSeconds
		trail.LightEmission = 1
		trail.FaceCamera = true
		trail.Enabled = false
		trail.Parent = ball
		local ballCenter = Instance.new("Attachment")
		ballCenter.Parent = ball
		local ballFlames =
			emitter("BallFlames", F.Textures.Fire, seq3(rgb(c.Core), rgb(c.Hot), rgb(c.Deep)), ballCenter)
		ballFlames.Transparency = fadeOut(0.1)
		ballFlames.Lifetime = NumberRange.new(0.15, 0.25)
		ballFlames.Speed = NumberRange.new(0)
		ballFlames.Rate = 70
		ball.Parent = root
		kit.Ball, kit.Trail, kit.BallEmitter = ball, trail, ballFlames
	elseif elementId == "Lightning" then
		local c = F.Lightning
		light.Color = rgb(c.Glow)
		local sparks = emitter("Sparks", F.Textures.Sparkle, ColorSequence.new(rgb(c.Core), rgb(c.Glow)), center)
		sparks.Transparency = fadeOut(0)
		sparks.Lifetime = NumberRange.new(0.2, 0.4)
		sparks.Drag = 3
		kit.Emitters.Sparks = sparks
		local segments = {}
		for i = 1, c.Segments + c.Branches * c.BranchSegments do
			local seg = part("Seg" .. i, Enum.PartType.Block, if i <= c.Segments then rgb(c.Core) else rgb(c.Glow))
			seg.Parent = root
			segments[i] = seg
		end
		kit.Segments = segments
		local glow = part("Glow", Enum.PartType.Ball, rgb(c.Core))
		glow.Parent = root
		kit.Ball = glow
	else
		local c = F.Wind
		local dust = emitter("Dust", F.Textures.Smoke, ColorSequence.new(rgb(c.DustColor)), center)
		dust.LightEmission = 0
		dust.LightInfluence = 1
		dust.Transparency = fadeOut(0.35)
		dust.Lifetime = NumberRange.new(0.45, 0.75)
		dust.SpreadAngle = Vector2.new(180, 15)
		dust.Drag = 2.5
		kit.Emitters.Dust = dust
		local bits = emitter("Bits", F.Textures.Sparkle, ColorSequence.new(rgb(c.BitsColor), rgb(c.Strand)), center)
		bits.LightEmission = 0.4
		bits.Transparency = fadeOut(0)
		bits.Lifetime = NumberRange.new(0.4, 0.7)
		bits.Drag = 2
		kit.Emitters.Bits = bits
		local beams = {}
		for k = 1, c.Strands do
			local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
			a0.Parent, a1.Parent = root, root
			local beam = Instance.new("Beam")
			beam.Attachment0, beam.Attachment1 = a0, a1
			beam.Color = ColorSequence.new(rgb(c.Strand))
			beam.LightEmission = 0.7
			beam.FaceCamera = true
			beam.Segments = 12
			beam.Enabled = false
			beam.Parent = root
			beams[k] = { Beam = beam, A0 = a0, A1 = a1 }
		end
		kit.Beams = beams
	end
	root.Parent = container()
	return kit
end

local function take(elementId: string): Kit
	local pool = pools[elementId]
	if pool == nil then
		pool = {}
		pools[elementId] = pool
	end
	return table.remove(pool) or newKit(elementId)
end

local function hide(kit: Kit)
	kit.Light.Enabled = false
	if kit.Ball then
		kit.Ball.Transparency = 1
	end
	if kit.Trail then
		kit.Trail.Enabled = false
	end
	if kit.BallEmitter then
		kit.BallEmitter.Enabled = false
	end
	if kit.Segments then
		for _, seg in kit.Segments do
			seg.Transparency = 1
		end
	end
	if kit.Beams then
		for _, b in kit.Beams do
			b.Beam.Enabled = false
		end
	end
end

-- ===== peças comuns =====

local function burst(fx: Active, name: string, base: number, size: NumberSequence, speed: NumberRange, accel: Vector3)
	local e = fx.Kit.Emitters[name]
	if e == nil then
		return
	end
	e.Size = size
	e.Speed = speed
	e.Acceleration = accel
	e:Emit(ElementFxMath.count(base, quality(), fx.Own, QualityTier.current().OthersScale))
end

local function grow(r: number, from: number, to: number): NumberSequence
	return NumberSequence.new({
		NumberSequenceKeypoint.new(0, r * from),
		NumberSequenceKeypoint.new(0.3, r * to),
		NumberSequenceKeypoint.new(1, 0),
	})
end

-- anel de choque: abre de from x R até to x R em `seconds` (uma partícula só)
local function shockwave(fx: Active, from: number, to: number, seconds: number)
	local e = fx.Kit.Emitters.Shock
	e.Lifetime = NumberRange.new(seconds)
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, fx.R * from),
		NumberSequenceKeypoint.new(0.4, fx.R * to * 0.8),
		NumberSequenceKeypoint.new(1, fx.R * to),
	})
	e:Emit(1)
end

local function flash(fx: Active, t: number, range: number, brightness: number)
	local light = fx.Kit.Light
	local k = ElementFxMath.fade(t, 0.12)
	light.Enabled = k > 0.01
	light.Range = math.min(fx.R * range + 6, 60) -- PointLight do Roblox vai até 60
	light.Brightness = brightness * k
end

-- ===== FOGO =====

local function fireImpact(fx: Active)
	local c, r = F.Fire, fx.R
	burst(fx, "Flames", c.Flames, grow(r, 0.25, 0.55), NumberRange.new(r * 0.6, r * 1.3), Vector3.new(0, r * 2, 0))
	burst(fx, "Embers", c.Embers, NumberSequence.new(0.5, 0), NumberRange.new(r * 1.5, r * 3), Vector3.new(0, -40, 0))
	burst(fx, "Smoke", c.Smoke, grow(r, 0.3, 0.8), NumberRange.new(r * 0.3, r * 0.6), Vector3.new(0, r * 0.8, 0))
end

local function stepFire(fx: Active): boolean
	local c, kit = F.Fire, fx.Kit
	local ball = kit.Ball :: Part
	if fx.Age < c.FallSeconds then
		local p = ElementFxMath.fall(fx.Start :: Point, fx.Age / c.FallSeconds)
		ball.CFrame = CFrame.new(fx.At + v3(p))
		return false
	end
	if not fx.Impacted then
		fx.Impacted = true
		ball.Transparency = 1
		(kit.Trail :: Trail).Enabled = false
		(kit.BallEmitter :: ParticleEmitter).Enabled = false
		kit.Root.CFrame = CFrame.new(fx.At)
		fireImpact(fx)
		shockwave(fx, c.RingFrom, c.RingTo, c.ImpactSeconds * 0.5)
	end
	local t = (fx.Age - c.FallSeconds) / c.ImpactSeconds
	flash(fx, t, c.LightRange, c.LightBrightness)
	return t >= 1
end

-- ===== RAIO =====

local function drawBolt(fx: Active)
	local c, r = F.Lightning, fx.R
	local segments = fx.Kit.Segments :: { Part }
	local scale = if fx.Own then 1 else F.OthersSize
	local main = if fx.ArcFrom
		then ElementFxMath.between(
			{ X = fx.ArcFrom.X - fx.At.X, Y = fx.ArcFrom.Y - fx.At.Y, Z = fx.ArcFrom.Z - fx.At.Z },
			{ X = 0, Y = 0, Z = 0 },
			c.Segments,
			r * c.Jitter * 0.5,
			rand
		)
		else ElementFxMath.bolt(c.Height, c.Segments, r * c.Jitter, rand)
	local function lay(index: number, a: Point, b: Point, width: number)
		local seg = segments[index]
		local pa, pb = fx.At + v3(a), fx.At + v3(b)
		local len = (pb - pa).Magnitude
		seg.Size = Vector3.new(width * scale, width * scale, len + width * 0.5)
		seg.CFrame = CFrame.lookAt((pa + pb) / 2, pb)
		seg.Transparency = 0
	end
	for i = 1, c.Segments do
		lay(i, main[i], main[i + 1], c.Width)
	end
	local index = c.Segments
	for i = index + 1, #segments do
		segments[i].Transparency = 1
	end
	for _ = 1, if fx.ArcFrom then 0 else c.Branches do
		local from = main[rng:NextInteger(3, c.Segments - 2)]
		local branch = ElementFxMath.branch(from, c.Height * c.BranchLength, c.BranchSegments, r * c.Jitter * 0.6, rand)
		for i = 1, c.BranchSegments do
			index += 1
			lay(index, branch[i], branch[i + 1], c.BranchWidth)
		end
	end
end

local function stepLightning(fx: Active): boolean
	local c, kit = F.Lightning, fx.Kit
	local segments = kit.Segments :: { Part }
	local glow = kit.Ball :: Part
	local t = fx.Age / c.Seconds
	if not fx.Impacted then
		fx.Impacted = true
		kit.Root.CFrame = CFrame.new(fx.At)
		drawBolt(fx)
		shockwave(fx, c.RingFrom, c.RingTo, c.Seconds * 0.6)
		burst(
			fx,
			"Sparks",
			c.Sparks,
			NumberSequence.new(0.6, 0),
			NumberRange.new(fx.R * 2, fx.R * 4),
			Vector3.new(0, -30, 0)
		)
	end
	if fx.Age >= c.FlickerOff and fx.Age < c.FlickerOn then
		for _, seg in segments do
			seg.Transparency = 1
		end
	elseif fx.Age >= c.FlickerOn and not fx.Redrawn then
		fx.Redrawn = true
		drawBolt(fx) -- reacende com outro desenho
	elseif fx.Redrawn then
		local fade = (fx.Age - c.FlickerOn) / (c.Seconds - c.FlickerOn)
		for _, seg in segments do
			seg.Transparency = math.min(1, fade * 1.2)
		end
	end
	-- brilho no ponto do impacto
	local g = ElementFxMath.fade(t, 0.1)
	glow.Transparency = 1 - g * 0.85
	glow.Size = Vector3.one * fx.R * (0.4 + 0.8 * t)
	glow.CFrame = CFrame.new(fx.At)
	flash(fx, t, c.LightRange, c.LightBrightness)
	return t >= 1
end

-- ===== VENTO =====

local function stepWind(fx: Active): boolean
	local c, kit = F.Wind, fx.Kit
	local t = fx.Age / c.Seconds
	if not fx.Impacted then
		fx.Impacted = true
		kit.Root.CFrame = CFrame.new(fx.At)
		local r = fx.R
		shockwave(fx, c.RingFrom, c.RingTo, c.Seconds * 0.5)
		burst(fx, "Dust", c.Dust, grow(r, 0.3, 0.7), NumberRange.new(r * 1, r * 2), Vector3.new(0, r * 0.6, 0))
		burst(
			fx,
			"Bits",
			c.Bits,
			NumberSequence.new(0.45, 0.1),
			NumberRange.new(r * 1.5, r * 3),
			Vector3.new(0, r * 2, 0)
		)
	end
	local alpha = 1 - ElementFxMath.fade(t, 0.15)
	local transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.25 + 0.75 * alpha),
		NumberSequenceKeypoint.new(1, 1),
	})
	local scale = if fx.Own then 1 else F.OthersSize
	for k, b in kit.Beams :: { { Beam: Beam, A0: Attachment, A1: Attachment } } do
		local a, z =
			ElementFxMath.swirl(k, c.Strands, t, c.Turns, fx.R * c.Radius0, fx.R * c.Radius1, fx.R * c.Rise, c.Arc)
		b.A0.Position = v3(a)
		b.A1.Position = v3(z)
		b.Beam.CurveSize0 = fx.R * 0.5
		b.Beam.CurveSize1 = -fx.R * 0.5
		b.Beam.Width0 = fx.R * c.StrandWidth * scale
		b.Beam.Width1 = fx.R * c.StrandWidth * 0.3 * scale
		b.Beam.Transparency = transparency
		b.Beam.Enabled = t < 1
	end
	return t >= 1
end

local STEPS: { [string]: (Active) -> boolean } = {
	Fire = stepFire,
	Lightning = stepLightning,
	Wind = stepWind,
}

-- ===== entrada =====

function ElementFx.casterPosition(casterId: unknown): Vector3?
	if type(casterId) ~= "number" then
		return nil
	end
	local player = Players:GetPlayerByUserId(casterId)
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root.Position else nil
end

export type Options = {
	Fall: boolean?, -- fogo: bola cai do céu (só o 1º pulso do golpe)
	ArcFrom: Vector3?, -- raio: arco a partir deste ponto (cadeia)
}

-- Um efeito de golpe no ponto `at` com raio `radius` (studs). Devolve false se o teto do Tier encheu.
-- Chamado pelo client/City/ElementCasts para cada pulso do plano.
function ElementFx.spawn(elementId: string, casterId: number, at: Vector3, radius: number, options: Options?): boolean
	local element = ElementConfig.ById[elementId]
	if element == nil or STEPS[element.Id] == nil then
		return false
	end
	local own = casterId == localPlayer.UserId
	local kind = if own then "Own" else "Others"
	local tier = QualityTier.current()
	if counts[kind] >= (if own then tier.MaxOwn else tier.MaxOthers) then
		return false
	end
	counts[kind] += 1
	local r = math.clamp(radius, 2, 40) * (if own then 1 else F.OthersSize)
	local fx: Active = {
		Kit = take(element.Id),
		Own = own,
		At = at,
		R = r,
		Age = 0,
		Impacted = false,
		Redrawn = false,
		ArcFrom = options and options.ArcFrom,
	}
	local fall = options == nil or options.Fall ~= false
	if element.Id == "Fire" and not fall then
		fx.Age = F.Fire.FallSeconds -- começa já no impacto (pulsos seguintes do golpe)
	elseif element.Id == "Fire" then
		local c = F.Fire
		local from = ElementFx.casterPosition(casterId)
		local d = if from then from - fx.At else Vector3.zero
		fx.Start = ElementFxMath.fallStart(d.X, d.Z, c.FallBack, c.FallHeight)
		local ball = fx.Kit.Ball :: Part
		ball.Size = Vector3.one * r * c.BallSize
		ball.Transparency = 0
		ball.CFrame = CFrame.new(fx.At + v3(fx.Start :: Point))
		-- rastro da largura da bola
		local trail = fx.Kit.Trail :: Trail
		local half = r * c.BallSize * 0.4
		(trail.Attachment0 :: Attachment).Position = Vector3.new(0, half, 0);
		(trail.Attachment1 :: Attachment).Position = Vector3.new(0, -half, 0)
		local ballFlames = fx.Kit.BallEmitter :: ParticleEmitter
		ballFlames.Size = NumberSequence.new(r * c.BallSize * 0.9, 0)
		ballFlames.Enabled = true
		(fx.Kit.Trail :: Trail).Enabled = true
	end
	table.insert(active, fx)
	return true
end

local function step(dt: number)
	for i = #active, 1, -1 do
		local fx = active[i]
		fx.Age += dt
		if STEPS[fx.Kit.Element](fx) then
			hide(fx.Kit)
			table.insert(pools[fx.Kit.Element], fx.Kit)
			local kind = if fx.Own then "Own" else "Others"
			counts[kind] -= 1
			active[i] = active[#active]
			active[#active] = nil
		end
	end
end

function ElementFx.init()
	RunService.Heartbeat:Connect(function(dt)
		if #active > 0 then
			step(dt)
		end
	end)
end

return ElementFx
