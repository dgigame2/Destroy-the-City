--!strict
-- Efeitos visuais dos desastres (só visual; o servidor já decidiu o dano). Todos os jogadores veem.
-- Celular: peças ancoradas e tweens (sem física), poucas peças por efeito, tudo some sozinho, e no máximo
-- MAX_EFFECTS efeitos ao mesmo tempo (os mais novos esperam o slot ou são pulados).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DisasterConfig = require(Shared.Config.DisasterConfig)
local Disasters = require(Shared.Logic.Disasters)
local Remotes = require(Shared.Remotes)

local MeshKitConfig = require(Shared.Config.MeshKitConfig)
local PaletteConfig = require(Shared.Config.PaletteConfig)

local Feedback = require(script.Parent.Parent.Feedback)
local Style = require(script.Parent.Parent.Ui.Style)

local localPlayer = Players.LocalPlayer

local DisasterVfx = {}

local MAX_EFFECTS = 10
local MAX_FLASHES = 4
local MAX_FIRES = require(Shared.Config.ChainConfig).Fire.MaxActive -- mesmo teto do servidor
local active = 0
local burning = 0
local flashes = 0

local folder = Instance.new("Folder")
folder.Name = "DisasterVfx"

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = folder
	return p
end

local function tween(
	instance: Instance,
	seconds: number,
	goal: { [string]: any },
	style: Enum.EasingStyle?,
	dir: Enum.EasingDirection?
)
	local t = TweenService:Create(
		instance,
		TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
		goal
	)
	t:Play()
	return t
end

-- Cópia de uma mesh do Blender importada em ReplicatedStorage.Assets (nil = ainda não importou).
local function kitAsset(name: string): MeshPart?
	local assets = ReplicatedStorage:FindFirstChild(MeshKitConfig.Folder)
	local mesh = assets and assets:FindFirstChild(name, true)
	if not (mesh and mesh:IsA("MeshPart")) then
		return nil
	end
	local clone = mesh:Clone()
	clone.Anchored = true
	clone.CanCollide = false
	clone.CanQuery = false
	clone.CanTouch = false
	clone.CastShadow = false
	clone.Material = Enum.Material.SmoothPlastic
	clone.Parent = folder
	return clone
end

local function flat(position: Vector3): CFrame
	return CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
end

-- Tremor proporcional à distância do impacto até a câmera do jogador.
local function shakeNear(position: Vector3, radius: number, strength: number)
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root == nil then
		return
	end
	local d = (root.Position - position).Magnitude
	if d < radius * 3 then
		Feedback.shake(strength * (1 - d / (radius * 3)), 0.35)
	end
end

local function meteor(cast: { [string]: any })
	local d = DisasterConfig.ById.Meteor
	local p = cast.Power :: number
	local target = (cast.Target :: Vector3) + Vector3.new(0, 0.2, 0)
	local r = Disasters.radius(d, p, DisasterConfig) * ((cast.Size :: number?) or 1) -- tamanho do nível
	local delay = math.max(d.Delay - (Workspace:GetServerTimeNow() - cast.Time), 0.05)
	-- sombra/aviso no chão crescendo até o tamanho da onda
	local shadow = part({
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.SmoothPlastic,
		Color = Style.rgb(PaletteConfig.Vfx.MeteorShadow),
		Transparency = 0.5,
		Size = Vector3.new(0.15, r * 0.2, r * 0.2),
		CFrame = flat(target),
	})
	tween(shadow, delay, { Size = Vector3.new(0.15, r * 2, r * 2) })
	-- a pedra caindo na diagonal, com fogo; para no primeiro telhado no caminho (não atravessa a casa)
	local size = 2.5 * p ^ 0.7
	local start = target + Vector3.new(r * 1.5, 80 * p ^ 0.6, r * 0.8)
	local landing = target
	local landParams = RaycastParams.new()
	landParams.FilterType = Enum.RaycastFilterType.Exclude
	landParams.FilterDescendantsInstances = { folder }
	local hit = Workspace:Raycast(start, target - start, landParams)
	if hit then
		landing = hit.Position
	end
	-- pedra de lava do Blender (ReplicatedStorage.Assets.Meteor) ou, se ainda não importou, uma bola neon
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local mesh = assets and assets:FindFirstChild("Meteor", true)
	local rock: BasePart
	if mesh and mesh:IsA("MeshPart") then
		local clone = mesh:Clone()
		clone.Anchored = true
		clone.CanCollide = false
		clone.CanQuery = false
		clone.CanTouch = false
		clone.CastShadow = false
		if clone.TextureID == "" then
			clone.Color = Style.rgb(PaletteConfig.Vfx.Meteor) -- mesh nova do kit (sem textura)
		end
		clone.Size = Vector3.one * size * 1.3
		clone.CFrame = CFrame.new(start)
		clone.Parent = folder
		local glow = Instance.new("PointLight")
		glow.Color = Style.rgb(PaletteConfig.Vfx.Lava)
		glow.Range = size * 4
		glow.Brightness = 3
		glow.Parent = clone
		rock = clone
	else
		rock = part({
			Shape = Enum.PartType.Ball,
			Color = Style.rgb(PaletteConfig.Vfx.Lava),
			Size = Vector3.one * size,
			CFrame = CFrame.new(start),
		})
	end
	local fire = Instance.new("Fire")
	fire.Size = size * 1.5
	fire.Heat = 15
	fire.Parent = rock
	local spin = CFrame.Angles(math.rad(200), math.rad(120), math.rad(60))
	tween(rock, delay, { CFrame = CFrame.new(landing) * spin }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.wait(delay)
	rock:Destroy()
	shadow:Destroy()
	-- impacto: anel de choque + clarão
	local ring = part({
		Shape = Enum.PartType.Cylinder,
		Color = Style.rgb(PaletteConfig.Vfx.ImpactRing),
		Transparency = 0.2,
		Size = Vector3.new(0.4, r * 0.3, r * 0.3),
		CFrame = flat(target),
	})
	-- clarão pequeno e rápido no ponto do impacto (antes era uma bola enorme cobrindo as casas)
	local flash = part({
		Shape = Enum.PartType.Ball,
		Color = Style.rgb(PaletteConfig.Vfx.ImpactFlash),
		Transparency = 0.35,
		Size = Vector3.one * size * 1.5,
		CFrame = CFrame.new(landing),
	})
	local burst = Instance.new("ParticleEmitter")
	burst.Texture = "rbxasset://textures/particles/smoke_main.dds"
	burst.Color = ColorSequence.new(Style.rgb(PaletteConfig.Vfx.BurstHot), Style.rgb(PaletteConfig.Vfx.Smoke))
	burst.Size = NumberSequence.new(size * 0.8, size * 2)
	burst.Transparency = NumberSequence.new(0.2, 1)
	burst.Lifetime = NumberRange.new(0.4, 0.7)
	burst.Speed = NumberRange.new(r * 0.8, r * 1.4)
	burst.SpreadAngle = Vector2.new(180, 180)
	burst.Rate = 0
	burst.Parent = flash
	burst:Emit(14)
	local light = Instance.new("PointLight")
	light.Range = math.min(r * 2, 60)
	light.Brightness = 6
	light.Color = Style.rgb(PaletteConfig.Vfx.ImpactLight)
	light.Parent = flash
	tween(ring, 0.4, { Size = Vector3.new(0.2, r * 2.1, r * 2.1), Transparency = 1 })
	tween(flash, 0.2, { Size = Vector3.one * size * 3, Transparency = 1 })
	tween(light, 0.35, { Brightness = 0 })
	shakeNear(target, r, 1.2)
	task.wait(0.8)
	ring:Destroy()
	flash:Destroy()
end

local function tornado(cast: { [string]: any })
	local d = DisasterConfig.ById.Tornado
	local p = cast.Power :: number
	local r = Disasters.radius(d, p, DisasterConfig) * ((cast.Size :: number?) or 1) -- tamanho do nível
	local speed = Disasters.speed(d, p, DisasterConfig)
	local start = cast.Target :: Vector3
	local dir = cast.Dir :: Vector3
	-- o servidor corta a duração para o tornado parar na borda do chão liberado (e o nível aumenta)
	local duration = (cast.Duration :: number?) or d.Duration
	-- funil do Blender (MeshKitConfig.Disasters.Tornado) girando; sem ele, discos empilhados
	local rings = {}
	local funnel = kitAsset(MeshKitConfig.Disasters.Tornado)
	local height = r * 5.4
	if funnel then
		funnel.Color = Style.rgb(PaletteConfig.Vfx.Tornado)
		funnel.Transparency = 0.15
		funnel.Size = Vector3.new(r * 2.4, height, r * 2.4)
		table.insert(rings, funnel)
	end
	local layers = if funnel then 0 else 6
	for i = 1, layers do
		local width = r * (0.45 + 0.75 * (i / layers) ^ 1.4) * 2
		table.insert(
			rings,
			part({
				Shape = Enum.PartType.Cylinder,
				Material = Enum.Material.SmoothPlastic,
				Color = Style.rgb(PaletteConfig.Vfx.TornadoRing):Lerp(Color3.new(1, 1, 1), i * 0.05),
				Transparency = 0.25 + i * 0.06,
				Size = Vector3.new(r * 0.9, width, width),
			})
		)
	end
	local dust = Instance.new("ParticleEmitter")
	dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
	dust.Color = ColorSequence.new(Style.rgb(PaletteConfig.Vfx.Dust))
	dust.Size = NumberSequence.new(r * 0.5, r * 1.2)
	dust.Transparency = NumberSequence.new(0.4, 1)
	dust.Lifetime = NumberRange.new(0.6, 1)
	dust.Rate = 25
	dust.Speed = NumberRange.new(r * 0.8)
	dust.SpreadAngle = Vector2.new(80, 10)
	dust.Parent = rings[1]
	local began = cast.Time :: number
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local t = Workspace:GetServerTimeNow() - began
		if t > duration then
			connection:Disconnect()
			for _, ring in rings do
				tween(ring, 0.4, { Transparency = 1 })
			end
			task.delay(0.45, function()
				for _, ring in rings do
					ring:Destroy()
				end
			end)
			return
		end
		local x, z = Disasters.tornadoAt(start.X, start.Z, dir.X, dir.Z, speed, math.max(t, 0))
		local spin = t * 8
		if funnel then
			local lean = math.sin(t * 2) * 0.08
			funnel.CFrame = CFrame.new(x, start.Y + height / 2, z) * CFrame.Angles(lean, spin, lean * 0.5)
			return
		end
		for i, ring in rings do
			local y = (i - 0.5) * r * 0.9
			local wobble = math.sin(t * 3 + i) * r * 0.08 * i
			ring.CFrame = CFrame.new(x + wobble, start.Y + y, z) * CFrame.Angles(0, spin * (1 + i * 0.1), math.rad(90))
		end
	end)
	shakeNear(start, r, 0.4)
	task.wait(duration + 0.5)
end

-- Segmento de raio em zigue-zague de a até b.
local function bolt(a: Vector3, b: Vector3, thickness: number, color: Color3): { Part }
	local list = {}
	local pieces = 3
	local previous = a
	for i = 1, pieces do
		local t = i / pieces
		local point = a:Lerp(b, t)
		if i < pieces then
			local jitter = (b - a).Magnitude * 0.12
			point += Vector3.new(
				(math.random() - 0.5) * jitter,
				(math.random() - 0.5) * jitter,
				(math.random() - 0.5) * jitter
			)
		end
		local length = (point - previous).Magnitude
		if length > 0.05 then
			table.insert(
				list,
				part({
					Color = color,
					Size = Vector3.new(thickness, thickness, length),
					CFrame = CFrame.lookAt((previous + point) / 2, point),
				})
			)
		end
		previous = point
	end
	return list
end

local function lightning(cast: { [string]: any })
	local hops = cast.Hops :: { Vector3 }?
	local p = cast.Power :: number
	local target = cast.Target :: Vector3
	local color = Style.rgb(PaletteConfig.Vfx.Bolt)
	local thickness = 0.5 * p ^ 0.6
	local pieces = {}
	local first = if hops and #hops > 0 then hops[1] else target
	for _, piece in
		bolt(first + Vector3.new(0, 90 * p ^ 0.5, 0), first, thickness * 1.6, Style.rgb(PaletteConfig.Vfx.BoltCore))
	do
		table.insert(pieces, piece)
	end
	if hops then
		for i = 2, #hops do
			for _, piece in bolt(hops[i - 1], hops[i], thickness, color) do
				table.insert(pieces, piece)
			end
		end
	end
	-- nuvem de tempestade do Blender em cima do primeiro raio
	local top = first + Vector3.new(0, 90 * p ^ 0.5, 0)
	local cloud = kitAsset(MeshKitConfig.Disasters.Cloud)
	if cloud then
		local w = 18 * p ^ 0.5
		cloud.Color = Style.rgb(PaletteConfig.Vfx.Cloud)
		cloud.Size = Vector3.new(w, w * 0.375, w * 0.67)
		cloud.CFrame = CFrame.new(top + Vector3.new(0, w * 0.15, 0)) * CFrame.Angles(0, math.random() * math.pi, 0)
		table.insert(pieces, cloud)
	end
	local flash = part({ Transparency = 1, Size = Vector3.one, CFrame = CFrame.new(first) })
	local light = Instance.new("PointLight")
	light.Range = 40
	light.Brightness = 8
	light.Color = color
	light.Parent = flash
	shakeNear(first, 10 * p, 0.6)
	-- pisca duas vezes e some
	for _, on in { false, true, false } do
		task.wait(0.06)
		for _, piece in pieces do
			piece.Transparency = if on then 0 else 0.6
		end
	end
	for _, piece in pieces do
		tween(piece, 0.2, { Transparency = 1 })
	end
	tween(light, 0.2, { Brightness = 0 })
	task.wait(0.25)
	for _, piece in pieces do
		piece:Destroy()
	end
	flash:Destroy()
end

local HANDLERS: { [string]: ({ [string]: any }) -> () } = {
	Meteor = meteor,
	Tornado = tornado,
	Lightning = lightning,
}

local function onCast(cast: { [string]: any })
	local handler = HANDLERS[cast.Id]
	if handler == nil or active >= MAX_EFFECTS then
		return
	end
	active += 1
	task.spawn(function()
		local ok, err = pcall(handler, cast)
		active -= 1
		if not ok then
			warn("[DisasterVfx]", cast.Id, err)
		end
	end)
end

-- Fogo da cadeia: chamas + fumaça + luz tremendo enquanto queima (Duration s), depois apaga.
local function fireEffect(blast: { [string]: any })
	local r = blast.Radius :: number
	local seconds = (blast.Duration :: number?) or 2.5
	local base =
		part({ Transparency = 1, Size = Vector3.one, CFrame = CFrame.new(blast.Position + Vector3.new(0, 1, 0)) })
	local flames = Instance.new("ParticleEmitter")
	flames.Texture = "rbxasset://textures/particles/fire_main.dds"
	flames.Color = ColorSequence.new(Style.rgb(PaletteConfig.Vfx.FireCore), Style.rgb(PaletteConfig.Vfx.Fire))
	flames.LightEmission = 0.8
	flames.Size = NumberSequence.new(r * 0.35, r * 0.1)
	flames.Transparency = NumberSequence.new(0.1, 1)
	flames.Lifetime = NumberRange.new(0.4, 0.7)
	flames.Speed = NumberRange.new(r * 0.6, r)
	flames.SpreadAngle = Vector2.new(25, 25)
	flames.Shape = Enum.ParticleEmitterShape.Disc
	flames.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	flames.EmissionDirection = Enum.NormalId.Top
	flames.Rate = 30
	flames.Parent = base
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Style.rgb(PaletteConfig.Vfx.FireSmoke))
	smoke.Size = NumberSequence.new(r * 0.3, r * 0.8)
	smoke.Transparency = NumberSequence.new(0.5, 1)
	smoke.Lifetime = NumberRange.new(1, 1.6)
	smoke.Speed = NumberRange.new(r * 0.5)
	smoke.Rate = 6
	smoke.Parent = base
	local light = Instance.new("PointLight")
	light.Range = math.min(r * 1.6, 40)
	light.Brightness = 3
	light.Color = Style.rgb(PaletteConfig.Vfx.Fire)
	light.Parent = base
	local ends = os.clock() + seconds
	while os.clock() < ends do
		light.Brightness = 2.5 + math.random() * 1.5
		task.wait(0.12)
	end
	flames.Enabled = false
	smoke.Enabled = false
	tween(light, 0.5, { Brightness = 0 })
	task.wait(1.6)
	base:Destroy()
end

-- Faísca do condutor: raios curtos entre os pontos da mini cadeia.
local function sparkEffect(blast: { [string]: any })
	local points = blast.Points :: { Vector3 }?
	if points == nil or #points < 2 then
		return
	end
	local color = Style.rgb(PaletteConfig.Vfx.Spark)
	local pieces = {}
	for i = 2, #points do
		for _, piece in bolt(points[i - 1] + Vector3.new(0, 2, 0), points[i] + Vector3.new(0, 2, 0), 0.35, color) do
			table.insert(pieces, piece)
		end
	end
	shakeNear(points[1], 8, 0.3)
	for _, on in { false, true } do
		task.wait(0.05)
		for _, piece in pieces do
			piece.Transparency = if on then 0 else 0.5
		end
	end
	for _, piece in pieces do
		tween(piece, 0.15, { Transparency = 1 })
	end
	task.wait(0.2)
	for _, piece in pieces do
		piece:Destroy()
	end
end

-- Batida de objeto que voou: anel de poeira pequeno.
local function impactEffect(blast: { [string]: any })
	local r = blast.Radius :: number
	local ring = part({
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.SmoothPlastic,
		Color = Style.rgb(PaletteConfig.Vfx.ImpactDust),
		Transparency = 0.35,
		Size = Vector3.new(0.3, r * 0.4, r * 0.4),
		CFrame = flat(blast.Position + Vector3.new(0, 0.3, 0)),
	})
	tween(ring, 0.3, { Size = Vector3.new(0.2, r * 1.8, r * 1.8), Transparency = 1 })
	shakeNear(blast.Position, r, 0.35)
	task.wait(0.4)
	ring:Destroy()
end

local CHAIN_EFFECTS: { [string]: ({ [string]: any }) -> () } = {
	Electric = sparkEffect,
	Impact = impactEffect,
}

-- Elo da cadeia: explosão (laranja, clarão), desabamento (poeira cinza), fogo, faísca ou batida de destroço.
-- Conta no limite de efeitos.
local function onChainBlast(blast: { [string]: any })
	-- fogo dura alguns segundos: tem o próprio teto para não tomar a vaga dos outros efeitos
	if blast.Kind == "Fire" then
		if burning >= MAX_FIRES then
			return
		end
		burning += 1
		task.spawn(function()
			local ok, err = pcall(fireEffect, blast)
			burning -= 1
			if not ok then
				warn("[DisasterVfx] Fire", err)
			end
		end)
		return
	end
	if active >= MAX_EFFECTS then
		return
	end
	active += 1
	local special = CHAIN_EFFECTS[blast.Kind]
	if special then
		task.spawn(function()
			local ok, err = pcall(special, blast)
			active -= 1
			if not ok then
				warn("[DisasterVfx]", blast.Kind, err)
			end
		end)
		return
	end
	task.spawn(function()
		local explosion = blast.Kind == "Explosion"
		local r = blast.Radius
		local ground = blast.Position + Vector3.new(0, 0.3, 0)
		local ring = part({
			Shape = Enum.PartType.Cylinder,
			Material = if explosion then Enum.Material.Neon else Enum.Material.SmoothPlastic,
			Color = if explosion then Style.rgb(PaletteConfig.Vfx.Explosion) else Style.rgb(PaletteConfig.Vfx.Collapse),
			Transparency = 0.3,
			Size = Vector3.new(0.3, r * 0.3, r * 0.3),
			CFrame = flat(ground),
		})
		tween(ring, 0.35, { Size = Vector3.new(0.2, r * 2, r * 2), Transparency = 1 })
		local puff = part({ Transparency = 1, Size = Vector3.one, CFrame = CFrame.new(ground + Vector3.new(0, 2, 0)) })
		local smoke = Instance.new("ParticleEmitter")
		smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
		smoke.Color = if explosion
			then ColorSequence.new(Style.rgb(PaletteConfig.Vfx.ExplosionSmoke), Style.rgb(PaletteConfig.Vfx.Smoke))
			else ColorSequence.new(Style.rgb(PaletteConfig.Vfx.CollapseDust))
		smoke.Size = NumberSequence.new(r * 0.25, r * 0.6)
		smoke.Transparency = NumberSequence.new(0.2, 1)
		smoke.Lifetime = NumberRange.new(0.5, 0.9)
		smoke.Speed = NumberRange.new(r * 0.5, r)
		smoke.SpreadAngle = Vector2.new(180, if explosion then 180 else 20)
		smoke.Rate = 0
		smoke.Parent = puff
		smoke:Emit(if explosion then 12 else 8)
		if explosion then
			local light = Instance.new("PointLight")
			light.Range = math.min(r * 1.5, 50)
			light.Brightness = 5
			light.Color = Style.rgb(PaletteConfig.Vfx.ExplosionLight)
			light.Parent = puff
			tween(light, 0.4, { Brightness = 0 })
		end
		shakeNear(ground, r, if explosion then 0.8 else 0.5)
		task.wait(1)
		ring:Destroy()
		puff:Destroy()
		active -= 1
	end)
end

-- Construção que levou dano e continua de pé: pisca branco rapidinho (poucas por vez).
local function onDamaged(models: { Model }, _origin: Vector3)
	for _, model in models do
		if flashes >= MAX_FLASHES or model.Parent == nil then
			continue
		end
		flashes += 1
		local highlight = Instance.new("Highlight")
		highlight.FillColor = Color3.new(1, 1, 1)
		highlight.FillTransparency = 0.4
		highlight.OutlineTransparency = 1
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.Adornee = model
		highlight.Parent = folder
		tween(highlight, 0.25, { FillTransparency = 1 })
		task.delay(0.3, function()
			highlight:Destroy()
			flashes -= 1
		end)
	end
end

function DisasterVfx.init()
	folder.Parent = Workspace
	Remotes.event(Remotes.Names.Events.DisasterCast).OnClientEvent:Connect(onCast)
	Remotes.event(Remotes.Names.Events.BuildingDamaged).OnClientEvent:Connect(onDamaged)
	Remotes.event(Remotes.Names.Events.ChainBlast).OnClientEvent:Connect(onChainBlast)
end

return DisasterVfx
