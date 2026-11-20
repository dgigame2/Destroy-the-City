--!strict
-- Golpes dos elementos no CLIENTE (Etapa 4). Recebe do servidor só (elemento, nível, semente, alvo, origem) e
-- monta o MESMO plano que o servidor (Logic/ElementPlan); cada pulso vira efeito na hora dele:
--   * Impact / Cone / Ring / Storm -> efeito de um golpe (client/City/ElementFx: bola, raio, rajada);
--   * Path do Fogo (Inferno) -> coluna de fogo que anda; Path do Vento -> vórtice / tornado / furacão.
-- Também desenha a cadeia do raio (ChainFx) e as construções pegando fogo (BurnFx).
-- Orçamento (client/City/QualityTier): efeitos que duram até Persistent; prédios em chamas até BurnFoci; cada
-- um tem no máximo 1 emissor ligado (o resto é Emit). Tudo do pool; um único Heartbeat anima tudo.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ElementConfig = require(Shared.Config.ElementConfig)
local ElementFxConfig = require(Shared.Config.ElementFxConfig)
local ElementPlan = require(Shared.Logic.ElementPlan)
local Remotes = require(Shared.Remotes)

local CityClient = require(script.Parent.CityClient)
local ElementFx = require(script.Parent.ElementFx)
local QualityTier = require(script.Parent.QualityTier)

local ElementCasts = {}

type Cast = {
	Element: ElementConfig.Element,
	Caster: number,
	Plan: ElementPlan.Plan,
	Points: { Vector3 }, -- pulso i no chão
	Next: number, -- próximo pulso a disparar
	Age: number,
	Persistent: Persistent?,
}

type Persistent = {
	Kind: string, -- "Inferno" | "Twister"
	Root: Part,
	Center: Attachment,
	Flames: ParticleEmitter?,
	Dust: ParticleEmitter?,
	Bits: ParticleEmitter?,
	Light: PointLight?,
	Beams: { { Beam: Beam, A0: Attachment, A1: Attachment } }?,
	Radius: number,
	Height: number,
	Start: number, -- tempo do 1º pulso do caminho
	Duration: number,
	Path: { Vector3 },
	Puff: number,
}

type Burn = { Root: Part, Flames: ParticleEmitter, Until: number }

local F = ElementFxConfig
local localPlayer = Players.LocalPlayer
local casts: { Cast } = {}
local persistentCount = 0
local pools: { [string]: { Persistent } } = { Inferno = {}, Twister = {} }
local burns: { [number]: Burn } = {}
local burnCount = 0
local burnPool: { Burn } = {}
local folder: Folder? = nil
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function container(): Folder
	if folder == nil or folder.Parent == nil then
		local f = Instance.new("Folder")
		f.Name = "ElementCasts"
		f.Parent = Workspace
		folder = f
	end
	return folder :: Folder
end

local function anchor(name: string): (Part, Attachment)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = Vector3.one
	local a = Instance.new("Attachment")
	a.Parent = p
	p.Parent = container()
	return p, a
end

local function emitter(texture: string, color: ColorSequence, parent: Instance): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = texture
	e.Color = color
	e.Enabled = false
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-90, 90)
	e.Parent = parent
	return e
end

-- Altura do chão em (x, z) (efeito no chão, mesmo no morro). Sem chão: y de referência.
local function ground(x: number, z: number, fallback: number): Vector3
	local city = Workspace:FindFirstChild("City")
	local g = city and city:FindFirstChild("Ground")
	if g then
		groundParams.FilterDescendantsInstances = { g }
		local hit = Workspace:Raycast(Vector3.new(x, fallback + 300, z), Vector3.new(0, -600, 0), groundParams)
		if hit then
			return hit.Position
		end
	end
	return Vector3.new(x, fallback, z)
end

local function quality(): number
	return QualityTier.current().Particles
end

-- ===== efeitos que duram (coluna de fogo, tornado) =====

local function newPersistent(kind: string): Persistent
	local root, center = anchor(kind)
	local p: Persistent = {
		Kind = kind,
		Root = root,
		Center = center,
		Radius = 1,
		Height = 1,
		Start = 0,
		Duration = 0,
		Path = {},
		Puff = 0,
	}
	if kind == "Inferno" then
		local c = F.Fire
		local flames = emitter(
			F.Textures.Fire,
			ColorSequence.new({
				ColorSequenceKeypoint.new(0, rgb(c.Core)),
				ColorSequenceKeypoint.new(0.4, rgb(c.Hot)),
				ColorSequenceKeypoint.new(1, rgb(c.Deep)),
			}),
			center
		)
		flames.Transparency = NumberSequence.new(0.05, 1)
		flames.Lifetime = NumberRange.new(0.5, 0.8)
		flames.SpreadAngle = Vector2.new(25, 25)
		flames.Drag = 1.5
		p.Flames = flames
		local smoke = emitter(F.Textures.Smoke, ColorSequence.new(rgb(c.SmokeColor)), center)
		smoke.LightEmission = 0
		smoke.LightInfluence = 1
		smoke.Transparency = NumberSequence.new(0.5, 1)
		smoke.Lifetime = NumberRange.new(0.7, 1)
		p.Dust = smoke
		local light = Instance.new("PointLight")
		light.Color = rgb(c.Hot)
		light.Shadows = false
		light.Enabled = false
		light.Parent = root
		p.Light = light
	else
		local c = F.Wind
		local dust = emitter(F.Textures.Smoke, ColorSequence.new(rgb(c.DustColor)), center)
		dust.LightEmission = 0
		dust.LightInfluence = 1
		dust.Transparency = NumberSequence.new(0.35, 1)
		dust.Lifetime = NumberRange.new(0.5, 0.8)
		dust.SpreadAngle = Vector2.new(180, 10)
		dust.Drag = 2
		p.Dust = dust
		local bits = emitter(F.Textures.Sparkle, ColorSequence.new(rgb(c.BitsColor), rgb(c.Strand)), center)
		bits.LightEmission = 0.4
		bits.Transparency = NumberSequence.new(0, 1)
		bits.Lifetime = NumberRange.new(0.6, 1)
		bits.SpreadAngle = Vector2.new(60, 60)
		p.Bits = bits
		local beams = {}
		for k = 1, 5 do
			local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
			a0.Parent, a1.Parent = root, root
			local beam = Instance.new("Beam")
			beam.Attachment0, beam.Attachment1 = a0, a1
			beam.Color = ColorSequence.new(rgb(c.Strand), rgb(c.DustColor))
			beam.LightEmission = 0.5
			beam.FaceCamera = true
			beam.Segments = 10
			beam.Enabled = false
			beam.Parent = root
			beams[k] = { Beam = beam, A0 = a0, A1 = a1 }
		end
		p.Beams = beams
	end
	return p
end

local function hidePersistent(p: Persistent)
	if p.Flames then
		p.Flames.Enabled = false
	end
	if p.Light then
		p.Light.Enabled = false
	end
	if p.Beams then
		for _, b in p.Beams do
			b.Beam.Enabled = false
		end
	end
end

-- Posição no caminho no tempo t (entre os pulsos, liso).
local function along(p: Persistent, t: number): Vector3
	local path = p.Path
	if #path == 1 then
		return path[1]
	end
	local k = math.clamp(t / math.max(p.Duration, 1e-3), 0, 1) * (#path - 1)
	local i = math.floor(k)
	local a, b = path[i + 1], path[math.min(i + 2, #path)]
	return a:Lerp(b, k - i)
end

local function stepPersistent(p: Persistent, t: number, dt: number): boolean
	local life = p.Duration + 0.4 -- some um pouco depois do último pulso
	if t >= life then
		return true
	end
	local fade = math.clamp(math.min(t / 0.3, (life - t) / 0.5), 0, 1)
	local at = along(p, math.min(t, p.Duration))
	p.Root.CFrame = CFrame.new(at)
	p.Puff += dt
	local r = p.Radius
	if p.Kind == "Inferno" then
		local flames = p.Flames :: ParticleEmitter
		flames.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, r * 0.35),
			NumberSequenceKeypoint.new(0.5, r * 0.6),
			NumberSequenceKeypoint.new(1, 0),
		})
		flames.Speed = NumberRange.new(r * 0.8, r * 1.6)
		flames.Acceleration = Vector3.new(0, r * 3, 0)
		flames.Rate = 45 * quality() * fade
		flames.Enabled = fade > 0.05
		local light = p.Light :: PointLight
		light.Enabled = true
		light.Range = math.min(r * 2.5 + 8, 60)
		light.Brightness = 4 * fade
		if p.Puff >= 0.3 then
			p.Puff = 0
			local smoke = p.Dust :: ParticleEmitter
			smoke.Size = NumberSequence.new(r * 0.5, r * 1.1)
			smoke.Speed = NumberRange.new(r * 0.6, r)
			smoke.Acceleration = Vector3.new(0, r * 0.8, 0)
			smoke:Emit(math.max(1, math.floor(3 * quality())))
		end
	else
		-- funil: fios que saem finos do chão e abrem lá em cima, girando
		local spin = t * 6
		local transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.9),
			NumberSequenceKeypoint.new(0.4, 1 - 0.7 * fade),
			NumberSequenceKeypoint.new(1, 1),
		})
		for k, b in p.Beams :: { { Beam: Beam, A0: Attachment, A1: Attachment } } do
			local a = (k - 1) / 5 * math.pi * 2 + spin
			b.A0.Position = Vector3.new(math.cos(a) * r * 0.2, 0.5, math.sin(a) * r * 0.2)
			b.A1.Position = Vector3.new(math.cos(a + 1.4) * r * 0.9, p.Height, math.sin(a + 1.4) * r * 0.9)
			b.Beam.CurveSize0 = r * 0.5
			b.Beam.CurveSize1 = -r * 0.3
			b.Beam.Width0 = r * 0.15
			b.Beam.Width1 = r * 0.6
			b.Beam.Transparency = transparency
			b.Beam.Enabled = fade > 0.02
		end
		if p.Puff >= 0.25 then
			p.Puff = 0
			local dust = p.Dust :: ParticleEmitter
			dust.Size = NumberSequence.new(r * 0.35, r * 0.8)
			dust.Speed = NumberRange.new(r * 0.8, r * 1.5)
			dust:Emit(math.max(1, math.floor(4 * quality())))
			local bits = p.Bits :: ParticleEmitter
			bits.Size = NumberSequence.new(r * 0.08, r * 0.02)
			bits.Speed = NumberRange.new(r * 0.5, r)
			bits.Acceleration = Vector3.new(0, r * 2.5, 0)
			bits:Emit(math.max(1, math.floor(3 * quality())))
		end
	end
	return false
end

-- ===== golpes =====

local function onCastFx(
	elementId: unknown,
	casterId: unknown,
	at: unknown,
	level: unknown,
	seed: unknown,
	origin: unknown
)
	local element = if type(elementId) == "string" then ElementConfig.ById[elementId] else nil
	if
		element == nil
		or type(casterId) ~= "number"
		or typeof(at) ~= "Vector3"
		or type(level) ~= "number"
		or type(seed) ~= "number"
		or typeof(origin) ~= "Vector3"
	then
		return
	end
	local target, from = at :: Vector3, origin :: Vector3
	local plan = ElementPlan.build(element, level, ElementConfig.MaxLevel, from.X, from.Z, target.X, target.Z, seed)
	local points = {}
	local pathPoints = {}
	local pathStart, pathRadius = nil, 0
	for i, p in plan.Pulses do
		points[i] = if p.X == target.X and p.Z == target.Z then target else ground(p.X, p.Z, target.Y)
		if p.Shape == "Path" then
			table.insert(pathPoints, points[i])
			pathStart = pathStart or p.At
			pathRadius = p.Radius
		end
	end
	local cast: Cast = {
		Element = element,
		Caster = casterId :: number,
		Plan = plan,
		Points = points,
		Next = 1,
		Age = 0,
		Persistent = nil,
	}
	if #pathPoints > 0 and (element.Id == "Fire" or element.Id == "Wind") then
		local own = casterId == localPlayer.UserId
		if persistentCount < QualityTier.current().Persistent then
			local kind = if element.Id == "Fire" then "Inferno" else "Twister"
			local p = table.remove(pools[kind]) or newPersistent(kind)
			local scale = if own then 1 else F.OthersSize
			p.Radius = pathRadius * scale
			p.Height = pathRadius * (if plan.Visual == "Vortex" then 1.6 else 2.6) * scale
			p.Start = pathStart :: number
			p.Duration = plan.Duration - p.Start
			p.Path = pathPoints
			p.Puff = 1
			p.Root.CFrame = CFrame.new(pathPoints[1])
			persistentCount += 1
			cast.Persistent = p
		end
	end
	table.insert(casts, cast)
end

local function stepCast(c: Cast, dt: number): boolean
	c.Age += dt
	local pulses = c.Plan.Pulses
	while c.Next <= #pulses and pulses[c.Next].At <= c.Age do
		local i = c.Next
		local p = pulses[i]
		c.Next += 1
		if p.Shape ~= "Path" then
			ElementFx.spawn(c.Element.Id, c.Caster, c.Points[i], p.Radius, { Fall = i == 1 })
		end
	end
	local done = c.Next > #pulses
	local p = c.Persistent
	if p then
		if stepPersistent(p, c.Age - p.Start, dt) then
			hidePersistent(p)
			table.insert(pools[p.Kind], p)
			persistentCount -= 1
			c.Persistent = nil
		else
			done = false
		end
	end
	return done
end

-- ===== cadeia do raio =====

local function onChainFx(casterId: unknown, points: unknown)
	if type(casterId) ~= "number" or type(points) ~= "table" then
		return
	end
	local list = points :: { any }
	for i = 2, math.min(#list, 8) do
		local a, b = list[i - 1], list[i]
		if typeof(a) == "Vector3" and typeof(b) == "Vector3" then
			task.delay((i - 2) * 0.06, function()
				ElementFx.spawn("Lightning", casterId :: number, b, 5, { ArcFrom = a + Vector3.new(0, 4, 0) })
			end)
		end
	end
end

-- ===== construções pegando fogo =====

local function stopBurn(id: number)
	local b = burns[id]
	if b then
		b.Flames.Enabled = false
		burns[id] = nil
		burnCount -= 1
		table.insert(burnPool, b)
	end
end

local function onBurnFx(ids: unknown, seconds: unknown)
	if type(ids) ~= "table" or type(seconds) ~= "number" then
		return
	end
	local c = F.Fire
	local cap = QualityTier.current().BurnFoci
	for _, id in ids :: { any } do
		if type(id) ~= "number" or burns[id] or burnCount >= cap then
			continue
		end
		local base, height, w, d = CityClient.site(id)
		if base == nil then
			continue
		end
		local b = table.remove(burnPool)
		if b == nil then
			local root = anchor("Burn")
			local flames = emitter(
				F.Textures.Fire,
				ColorSequence.new({
					ColorSequenceKeypoint.new(0, rgb(c.Core)),
					ColorSequenceKeypoint.new(0.5, rgb(c.Hot)),
					ColorSequenceKeypoint.new(1, rgb(c.Deep)),
				}),
				root -- na peça: sai da caixa toda (Shape Box), não de um ponto
			)
			flames.Transparency = NumberSequence.new(0.15, 1)
			flames.Lifetime = NumberRange.new(0.5, 0.9)
			flames.SpreadAngle = Vector2.new(10, 10)
			flames.EmissionDirection = Enum.NormalId.Top
			b = { Root = root, Flames = flames, Until = 0 }
		end
		local burn = b :: Burn
		local size = math.clamp(math.min(w, d) * 0.35, 1.5, 8)
		burn.Root.CFrame = CFrame.new(base + Vector3.new(0, height * 0.8, 0))
		burn.Root.Size = Vector3.new(w * 0.6, 1, d * 0.6)
		burn.Flames.Shape = Enum.ParticleEmitterShape.Box
		burn.Flames.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, size * 0.6),
			NumberSequenceKeypoint.new(0.4, size),
			NumberSequenceKeypoint.new(1, 0),
		})
		burn.Flames.Speed = NumberRange.new(size * 0.8, size * 1.4)
		burn.Flames.Rate = 10 * quality()
		burn.Flames.Enabled = true
		burn.Until = os.clock() + (seconds :: number)
		burns[id] = burn
		burnCount += 1
	end
end

function ElementCasts.init()
	Remotes.unreliable(Remotes.Names.Unreliable.CastFx).OnClientEvent:Connect(onCastFx)
	Remotes.unreliable(Remotes.Names.Unreliable.ChainFx).OnClientEvent:Connect(onChainFx)
	Remotes.unreliable(Remotes.Names.Unreliable.BurnFx).OnClientEvent:Connect(onBurnFx)
	CityClient.onDestroyed(function(id)
		stopBurn(id)
	end)
	local clock = 0
	RunService.Heartbeat:Connect(function(dt)
		for i = #casts, 1, -1 do
			if stepCast(casts[i], dt) then
				casts[i] = casts[#casts]
				casts[#casts] = nil
			end
		end
		clock += dt
		if clock >= 0.25 and burnCount > 0 then
			clock = 0
			local now = os.clock()
			for id, b in burns do
				if now >= b.Until then
					stopBurn(id)
				end
			end
		end
	end)
end

-- Para medição (pior caso da Etapa 4): o que está ligado agora.
function ElementCasts.stats(): { [string]: number }
	return { Casts = #casts, Persistent = persistentCount, Burning = burnCount }
end

return ElementCasts
