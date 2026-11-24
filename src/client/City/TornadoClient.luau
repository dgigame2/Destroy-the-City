--!strict
-- Visual do jogador-tornado (só cliente; o dano e o XP são do servidor, ver server/Match/TornadoService).
--   * Esconde o corpo de todos os jogadores e desenha um funil no lugar, do tamanho do nível
--     (raio e altura de Logic/Tornado) e da cor da forma (TornadoConfig.Forms).
--   * Põe o personagem no grupo de colisão "Tornado" e a cidade em "CityBuildings": o tornado atravessa
--     construções e destroços, mas pisa no chão (grupos registrados no servidor).
--   * Barra de XP do jogador local ("LV 12/15 · forma · XP/precisa") + botão EVOLVE / REBIRTH! (tecla R)
--     e a janela de confirmação do rebirth.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Tornado = require(Shared.Logic.Tornado)
local TornadoConfig = require(Shared.Config.TornadoConfig)
local ElementFxConfig = require(Shared.Config.ElementFxConfig)
local Remotes = require(Shared.Remotes)

local Style = require(script.Parent.Parent.Ui.Style)
local QualityTier = require(script.Parent.QualityTier)

local VisualModels = require(script.Parent.VisualModels)

local TornadoClient = {}

local cfg = TornadoConfig :: Tornado.Config
local fx = TornadoConfig.Visual
local rebirthFx = TornadoConfig.RebirthFx
local wind = TornadoConfig.BurstWind
local STRANDS = 3 -- fitas em espiral
local RINGS = 4 -- níveis de fumaça orbitando o funil
local OTHERS = 0.6 -- tornado dos outros: menos partículas
local stormTint = Color3.fromRGB(fx.StormTint[1], fx.StormTint[2], fx.StormTint[3])

local bandTransparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, fx.BandEdgeTransparency),
	NumberSequenceKeypoint.new(0.5, fx.BandCenterTransparency),
	NumberSequenceKeypoint.new(1, fx.BandEdgeTransparency),
})
local contourTransparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, fx.ContourEdgeTransparency),
	NumberSequenceKeypoint.new(0.5, fx.ContourCenterTransparency),
	NumberSequenceKeypoint.new(1, fx.ContourEdgeTransparency),
})
local coreTransparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, fx.CoreEdgeTransparency),
	NumberSequenceKeypoint.new(0.5, fx.CoreTransparency),
	NumberSequenceKeypoint.new(1, fx.CoreEdgeTransparency),
})
local closeTransparency = NumberSequence.new(fx.CameraClearTransparency)
local windTransparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.5, fx.BandCenterTransparency),
	NumberSequenceKeypoint.new(1, 1),
})
local windColor = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(table.unpack(wind.EdgeColor))),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(table.unpack(wind.CenterColor))),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(table.unpack(wind.EdgeColor))),
})

type Ribbon = { Beam: Beam, A0: Attachment, A1: Attachment }
type Orbit = { Attachment: Attachment, Emitter: ParticleEmitter, Height: number }
type Visual = {
	Root: Part,
	Model: Model?,
	Strands: { Ribbon },
	Core: Ribbon,
	Aura: { Ribbon },
	AuraPivot: Attachment,
	Rebirths: number,
	HasAura: boolean,
	CameraClose: boolean,
	Wind: { Ribbon },
	WindAge: number,
	WindDirection: Vector3,
	WindBands: number,
	Orbits: { Orbit },
	Dust: ParticleEmitter,
	Debris: ParticleEmitter,
	Cloud: ParticleEmitter,
	CloudAt: Attachment,
	Angle: number,
	Level: number,
	Form: Tornado.Form,
	Radius: number,
	Own: boolean,
}

local localPlayer = Players.LocalPlayer
local visuals: { [Player]: Visual } = {}
local folder: Folder? = nil

local function container(): Folder
	if folder == nil or folder.Parent == nil then
		local f = Instance.new("Folder")
		f.Name = "Tornadoes"
		f.Parent = Workspace
		folder = f
	end
	return folder :: Folder
end

local function ribbon(root: Instance, name: string): Ribbon
	local a0 = Instance.new("Attachment")
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.Parent = root
	local beam = Instance.new("Beam")
	beam.Name = name
	beam.FaceCamera = true
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Enabled = false
	beam.Parent = root
	return { Beam = beam, A0 = a0, A1 = a1 }
end

local function smoke(name: string, parent: Instance): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Texture = ElementFxConfig.Textures.Smoke
	e.LightEmission = 0
	e.LightInfluence = fx.SmokeLightInfluence
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-120, 120)
	e.Parent = parent
	return e
end

-- O núcleo segura a silhueta; as fitas e a fumaça em órbita dão movimento.
local function newVisual(own: boolean): Visual
	local root = Instance.new("Part")
	root.Name = "Tornado"
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CastShadow = false
	root.Transparency = 1
	root.Size = Vector3.one

	local strands = {}
	for i = 1, STRANDS do
		local strand = ribbon(root, "Funnel")
		local beam = strand.Beam
		beam.TextureMode = Enum.TextureMode.Stretch
		beam.TextureSpeed = 1.2
		beam.LightInfluence = fx.SmokeLightInfluence
		strands[i] = strand
	end
	local auraPivot = Instance.new("Attachment")
	auraPivot.Name = "RebirthPivot"
	auraPivot.Parent = root
	local aura = {}
	local core = ribbon(root, "FunnelCore")
	core.Beam.Segments = 2
	core.Beam.LightInfluence = fx.SmokeLightInfluence
	local windRibbons = {}
	for i = 1, wind.Bands do
		local band = ribbon(root, "BurstWind")
		band.Beam.Color = windColor
		band.Beam.Transparency = windTransparency
		windRibbons[i] = band
	end

	local orbits = {}
	for i = 1, RINGS do
		local f = (i - 0.5) / RINGS -- 0 = embaixo, 1 = em cima
		local a = Instance.new("Attachment")
		a.Parent = root
		local e = smoke("Ring" .. i, a)
		e.Lifetime = NumberRange.new(0.45, 0.7)
		e.Speed = NumberRange.new(0)
		e.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.2, fx.SmokeTransparency),
			NumberSequenceKeypoint.new(1, 1),
		})
		orbits[i] = { Attachment = a, Emitter = e, Height = f }
	end

	local baseAt = Instance.new("Attachment")
	baseAt.Parent = root
	local dust = smoke("Dust", baseAt)
	dust.Color = ColorSequence.new(Color3.fromRGB(196, 178, 140))
	dust.Lifetime = NumberRange.new(0.7, 1.3)
	dust.SpreadAngle = Vector2.new(85, 85)
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })

	local debris = Instance.new("ParticleEmitter")
	debris.Name = "Debris"
	debris.Texture = ElementFxConfig.Textures.Sparks
	debris.Color = ColorSequence.new(Color3.fromRGB(110, 90, 70))
	debris.LightEmission = 0
	debris.Lifetime = NumberRange.new(0.8, 1.4)
	debris.SpreadAngle = Vector2.new(30, 30)
	debris.Rotation = NumberRange.new(0, 360)
	debris.RotSpeed = NumberRange.new(-360, 360)
	debris.Parent = baseAt

	local cloudAt = Instance.new("Attachment")
	cloudAt.Parent = root
	local cloud = smoke("Cloud", cloudAt)
	cloud.Lifetime = NumberRange.new(1.2, 2)
	cloud.Speed = NumberRange.new(0, 2)
	cloud.SpreadAngle = Vector2.new(180, 20)
	cloud.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, fx.CloudTransparency),
		NumberSequenceKeypoint.new(1, 1),
	})
	root.Parent = container()
	return {
		Root = root,
		Strands = strands,
		Core = core,
		Aura = aura,
		AuraPivot = auraPivot,
		Rebirths = -1,
		HasAura = false,
		CameraClose = false,
		Wind = windRibbons,
		WindAge = wind.Seconds,
		WindDirection = Vector3.xAxis,
		WindBands = 0,
		Orbits = orbits,
		Dust = dust,
		Debris = debris,
		Cloud = cloud,
		CloudAt = cloudAt,
		Angle = math.random() * math.pi * 2,
		Level = 0,
		Form = cfg.Forms[1],
		Radius = 0,
		Own = own,
	}
end

local function updateVisibility(v: Visual)
	local close = v.CameraClose
	if v.Model then
		for _, part in v.Model:GetChildren() do
			if part:IsA("BasePart") then
				part.LocalTransparencyModifier = if close then fx.CameraClearTransparency else 0
			end
		end
	end
	v.Core.Beam.Transparency = if close then closeTransparency else coreTransparency
	for i, strand in v.Strands do
		strand.Beam.Transparency = if close
			then closeTransparency
			elseif i == STRANDS then contourTransparency
			else bandTransparency
	end
	for _, arc in v.Aura do
		arc.Beam.Enabled = v.HasAura and not close
	end
	for _, orbit in v.Orbits do
		orbit.Emitter.Enabled = not close and v.Model == nil
		if close then
			orbit.Emitter:Clear()
		end
	end
	v.Cloud.Enabled = v.Model == nil and not close and v.Form.Crown > 0
	v.Dust.Enabled = not close
	if close then
		v.Cloud:Clear()
		v.Dust:Clear()
	end
end

-- Tamanho, cor e quantidade de partículas: só quando o nível muda (não a cada frame).
local function resize(v: Visual, level: number, rebirths: number)
	local form = cfg.Forms[Tornado.form(cfg, level)]
	if form ~= v.Form or level < v.Level then
		for _, orbit in v.Orbits do
			orbit.Emitter:Clear()
		end
		v.Dust:Clear()
		v.Debris:Clear()
		v.Cloud:Clear()
	end
	v.Rebirths = rebirths
	local r = Tornado.radius(cfg, level)
	if form ~= v.Form or v.Model == nil then
		if v.Model then
			v.Model:Destroy()
		end
		v.Model = VisualModels.clone((form.Name:gsub(" ", "_")))
		if v.Model then
			v.Model.Parent = v.Root
		end
	end
	v.Level, v.Form, v.Radius = level, form, r
	local h = r * form.Height
	if v.Model then
		v.Model:ScaleTo(v.Model:GetScale() * h / v.Model:GetExtentsSize().Y)
	end
	local color = Color3.fromRGB(form.Color[1], form.Color[2], form.Color[3])
	local smokeColor = color:Lerp(stormTint, fx.SmokeTint * form.Density)
	local cloudColor = color:Lerp(stormTint, fx.CloudTint * form.Density)
	local aura = Tornado.rebirthColor(rebirthFx.Colors, rebirths)
	local auraColor = if aura then Color3.fromRGB(aura[1], aura[2], aura[3]) else color
	v.HasAura = aura ~= nil
	local quality = QualityTier.current().Particles
	local q = quality * (if v.Own then 1 else OTHERS) * form.Density
	v.WindBands = math.max(1, math.round(wind.Bands * quality))
	for _, band in v.Wind do
		band.Beam.Segments = math.round(wind.Segments * quality)
	end
	for i, s in v.Strands do
		-- Uma fita limpa mantém a silhueta das formas grandes quando a fumaça perde detalhe à distância.
		local contour = i == STRANDS
		local widthScale = if contour then fx.ContourWidthScale else 1
		s.Beam.Enabled = v.Model == nil and i <= form.Bands
		s.Beam.Texture = if contour then "" else ElementFxConfig.Textures.Smoke
		s.Beam.Color = ColorSequence.new(smokeColor, cloudColor)
		s.Beam.Segments = math.round(fx.BandSegments * quality)
		s.Beam.Width0 = r * fx.BandWidthAtBase * form.Density * widthScale
		s.Beam.Width1 = r * fx.BandWidthAtTop * form.Top * widthScale
		s.Beam.CurveSize0 = h * fx.BandCurve
		s.Beam.CurveSize1 = -h * fx.BandCurve
	end
	v.Core.A1.Position = Vector3.new(r * form.Bend, h, 0)
	v.Core.Beam.Enabled = v.Model == nil
	v.Core.Beam.Color = ColorSequence.new(smokeColor, cloudColor)
	v.Core.Beam.Width0 = r * form.Base * fx.CoreWidthScale
	v.Core.Beam.Width1 = r * form.Top * fx.CoreWidthScale
	for _, o in v.Orbits do
		local size = r * Tornado.visualRadius(form, o.Height) * fx.SmokeWidthScale
		o.Emitter.Color = ColorSequence.new(smokeColor:Lerp(cloudColor, o.Height))
		o.Emitter.Size =
			NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, size * 1.4) })
		o.Emitter.Acceleration = Vector3.new(0, r * 1.5, 0)
		o.Emitter.Rate = 28 * q
	end
	v.Dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, r * 0.4), NumberSequenceKeypoint.new(1, r * 1.1) })
	v.Dust.Speed = NumberRange.new(r * 0.8, r * 1.6)
	v.Dust.Rate = 22 * q
	v.Debris.Size = NumberSequence.new(math.max(0.4, r * 0.06))
	v.Debris.Speed = NumberRange.new(r * 1.2, r * 2.2)
	v.Debris.Acceleration = Vector3.new(0, -r * 0.8, 0)
	v.Debris.Rate = 14 * q
	v.Cloud.Color = ColorSequence.new(cloudColor)
	v.Cloud.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, r * form.Crown * 0.64),
		NumberSequenceKeypoint.new(1, r * form.Crown),
	})
	v.Cloud.Rate = if form.Crown > 0 then 6 * q else 0
	v.CloudAt.Position = Vector3.new(r * form.Bend, h, 0)
	if aura then
		local topRadius = r * form.Top
		if v.Model then
			local size = v.Model:GetExtentsSize()
			topRadius = math.max(size.X, size.Z) / 2
		end
		for i, fraction in rebirthFx.Heights do
			local arc = v.Aura[i]
			if not arc then
				arc = ribbon(v.AuraPivot, "RebirthArc")
				arc.Beam.Transparency = NumberSequence.new(0)
				v.Aura[i] = arc
			end
			local radius = topRadius
				* rebirthFx.Clearance
				* (rebirthFx.BaseRadius + (1 - rebirthFx.BaseRadius) * fraction)
			local start = i * rebirthFx.Stagger
			local rise = h * rebirthFx.Rise
			for j, attachment in { arc.A0, arc.A1 } do
				local t = j - 1
				local angle = start + t * rebirthFx.Arc
				attachment.Position =
					Vector3.new(radius * math.cos(angle), h * fraction + t * rise, radius * math.sin(angle))
				attachment.Axis = Vector3.new(-math.sin(angle), rise / (radius * rebirthFx.Arc), math.cos(angle)).Unit
			end
			local curve = radius * (4 / 3) * math.tan(rebirthFx.Arc / 4)
			arc.Beam.CurveSize0 = curve
			arc.Beam.CurveSize1 = curve
			arc.Beam.Color = ColorSequence.new(auraColor)
			arc.Beam.LightInfluence = 0
			arc.Beam.Width0 = h * rebirthFx.Width
			arc.Beam.Width1 = arc.Beam.Width0 * rebirthFx.TipWidth
			arc.Beam.Segments = math.round(rebirthFx.Segments * quality)
		end
	end
	updateVisibility(v)
end

local function windAttachment(angle: number, center: Vector3, radius: number): CFrame
	local cos, sin = math.cos(angle), math.sin(angle)
	local point = center + Vector3.new(cos * radius, 0, sin * radius)
	return CFrame.fromMatrix(point, Vector3.new(-sin, 0, cos), Vector3.yAxis)
end

local function updateWind(v: Visual, dt: number)
	if v.WindAge >= wind.Seconds then
		return
	end
	v.WindAge = math.min(v.WindAge + dt, wind.Seconds)
	local progress = v.WindAge / wind.Seconds
	local eased = 1 - (1 - progress) ^ 2
	local r = v.Radius
	local radius = r * (wind.RadiusStart + (wind.RadiusEnd - wind.RadiusStart) * eased)
	local height = r * v.Form.Height * (wind.HeightStart + (wind.HeightEnd - wind.HeightStart) * progress)
	local angle = math.atan2(v.WindDirection.Z, v.WindDirection.X) + wind.Sweep * eased
	local drift = v.WindDirection * (r * wind.AimDrift * eased)
	local width = r * wind.Width * (1 - progress)
	for i, band in v.Wind do
		band.Beam.Enabled = i <= v.WindBands and progress < 1
		if band.Beam.Enabled then
			local sweep = angle + (i - 1) * math.pi
			local center = drift + Vector3.yAxis * (height * i / v.WindBands)
			band.A0.CFrame = windAttachment(sweep - wind.Arc, center, radius)
			band.A1.CFrame = windAttachment(sweep, center, radius)
			local curve = radius * 4 / 3 * math.tan(wind.Arc / 4)
			band.Beam.CurveSize0 = curve
			band.Beam.CurveSize1 = curve
			band.Beam.Width0 = width * wind.TailWidth
			band.Beam.Width1 = width
		end
	end
end

-- Grupo de colisão do tornado (o corpo fica invisível pelo servidor, ver TornadoService).
local function hidePart(part: Instance)
	if part:IsA("BasePart") then
		part.CollisionGroup = "Tornado"
	end
end

local function onCharacter(player: Player, character: Model)
	for _, d in character:GetDescendants() do
		hidePart(d)
	end
	character.DescendantAdded:Connect(hidePart)
	if visuals[player] == nil then
		visuals[player] = newVisual(player == localPlayer)
	end
end

local function watch(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		onCharacter(player, player.Character)
	end
end

-- A cidade é montada aqui no cliente: construções e destroços entram no grupo que o tornado atravessa.
local function watchCity()
	local city = Workspace:WaitForChild("City")
	local function mark(d: Instance)
		if d:IsA("BasePart") then
			d.CollisionGroup = "CityBuildings"
		end
	end
	for _, name in { "Buildings", "Wrecks" } do
		local f = city:WaitForChild(name)
		for _, d in f:GetDescendants() do
			mark(d)
		end
		f.DescendantAdded:Connect(mark)
	end
end

local function update(dt: number)
	for player, v in visuals do
		-- fwjelaa-ignore: findfirstchild-chain (resultado guardado e conferido abaixo)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if player.Parent == nil then
			v.Root:Destroy()
			visuals[player] = nil
			continue
		end
		if root == nil then
			v.Root.Parent = nil
			continue
		end
		v.Root.Parent = container()
		local level = (player:GetAttribute("TornadoLevel") :: number?) or 1
		local rebirths = (player:GetAttribute("Rebirths") :: number?) or 0
		if level ~= v.Level or rebirths ~= v.Rebirths then
			resize(v, level, rebirths)
		end
		local r, form = v.Radius, v.Form
		local h = r * form.Height
		local bend = r * form.Bend
		v.Angle = (v.Angle + dt * form.Spin * math.pi * 2) % (math.pi * 2)
		v.Root.CFrame = CFrame.new(root.Position - Vector3.new(0, TornadoConfig.RootToGround, 0))
		if v.Model then
			v.Model:PivotTo(v.Root.CFrame * CFrame.Angles(0, v.Angle, 0))
		end
		if v.HasAura and not v.CameraClose then
			v.AuraPivot.CFrame = CFrame.Angles(0, os.clock() * rebirthFx.Spin, 0)
		end
		local camera = Workspace.CurrentCamera
		if v.Own and camera then
			local relative = camera.CFrame.Position - v.Root.Position
			local threshold = r * (if v.CameraClose then fx.CameraClearExit else fx.CameraClearEnter)
			local close = math.abs(relative.Y - h / 2) <= h / 2 + threshold
				and relative.X ^ 2 + relative.Z ^ 2 < threshold ^ 2
			if close ~= v.CameraClose then
				v.CameraClose = close
				updateVisibility(v)
			end
		end
		for i = 1, form.Bands do
			local s = v.Strands[i]
			local a = v.Angle + (i - 1) * math.pi * 2 / form.Bands
			s.A0.Position = Vector3.new(math.cos(a) * r * form.Base, 0, math.sin(a) * r * form.Base)
			local top = a + form.Twist
			s.A1.Position = Vector3.new(bend + math.cos(top) * r * form.Top, h, math.sin(top) * r * form.Top)
		end
		for i, o in v.Orbits do
			local a = v.Angle * (1.5 + o.Height) + i * 1.7
			local ri = r * Tornado.visualRadius(form, o.Height) * fx.OrbitRadiusScale
			o.Attachment.Position = Vector3.new(bend * o.Height + math.cos(a) * ri, h * o.Height, math.sin(a) * ri)
		end
		updateWind(v, dt)
	end
end

local function onBurstFx(userId: number, dx: number, dz: number)
	local player = Players:GetPlayerByUserId(userId)
	local v = player and visuals[player]
	if v then
		v.WindDirection = Vector3.new(dx, 0, dz)
		v.WindAge = 0
	end
end

-- ===== barra de XP =====

local function xpSurface(parent: GuiObject, name: string, radius: UDim, colors: { Color3 }, layer: number)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.BorderSizePixel = 0
	frame.ZIndex = layer
	frame.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius
	corner.Parent = frame
	local keys = {}
	for i, color in colors do
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / (#colors - 1), color))
	end
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(keys)
	gradient.Rotation = 90
	gradient.Parent = frame
	return frame
end

local navy = Color3.fromRGB(3, 15, 44)
local cobalt = {
	Color3.fromRGB(57, 141, 255),
	Color3.fromRGB(17, 70, 190),
	Color3.fromRGB(10, 42, 140),
	Color3.fromRGB(34, 101, 235),
}
local function portrait(parent: Frame, side: number)
	local ring = xpSurface(parent, if side == 0 then "CurrentRing" else "NextRing", UDim.new(0.5, 0), cobalt, 6)
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(side, 0.5)
	ring.Size = UDim2.fromOffset(80, 80)
	local outline = Instance.new("UIStroke")
	outline.Thickness = 3
	outline.Color = navy
	outline.Parent = ring
	local view = Instance.new("ViewportFrame")
	view.Name = if side == 0 then "CurrentForm" else "NextForm"
	view.AnchorPoint = Vector2.new(0.5, 0.5)
	view.Position = UDim2.fromScale(0.5, 0.5)
	view.Size = UDim2.new(1, -12, 1, -12)
	view.BackgroundColor3 = Color3.fromRGB(181, 232, 255)
	view.BorderSizePixel = 0
	view.ZIndex = 7
	view.Parent = ring
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = view
	outline:Clone().Parent = view
	local camera = Instance.new("Camera")
	camera.FieldOfView = 32
	camera.Parent = view
	view.CurrentCamera = camera
	view.Ambient = Color3.fromRGB(205, 215, 230)
	if side == 1 then
		view.Ambient = Color3.new(0, 0, 0)
		view.LightColor = Color3.new(0, 0, 0)
	end
	local displayed: Model? = nil
	return function(name: string?)
		ring.Visible = name ~= nil
		if not name or (displayed and displayed.Name == name) then
			return
		end
		if displayed then
			displayed:Destroy()
		end
		displayed = VisualModels.clone((name:gsub(" ", "_")))
		if displayed then
			displayed.Name = name
			displayed:PivotTo(CFrame.identity)
			displayed.Parent = view
			local bounds, size = displayed:GetBoundingBox()
			local distance = size.Magnitude / (2 * math.sin(math.rad(camera.FieldOfView / 2)))
			camera.CFrame = CFrame.lookAt(bounds.Position + Vector3.new(0, 0.35, 1).Unit * distance, bounds.Position)
		end
	end
end
local function buildHud()
	local gui = Instance.new("ScreenGui")
	gui.Name = "TornadoHud"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.Parent = localPlayer:WaitForChild("PlayerGui")

	local holder = Instance.new("Frame")
	holder.Name = "XpBar"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Position = UDim2.new(0.5, 0, 0, 69)
	holder.Size = UDim2.fromOffset(318, 48)
	holder.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Parent = holder
	local function fitBar()
		scale.Scale = math.clamp((gui.AbsoluteSize.X - 24) / 404, 0.1, 1)
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitBar)
	fitBar()
	local rim = xpSurface(holder, "CobaltFrame", UDim.new(0, 12), cobalt, 2)
	rim.Size = UDim2.fromScale(1, 1)
	local edge = Instance.new("UIStroke")
	edge.Color = navy
	edge.Thickness = 3
	edge.Parent = rim
	local face = xpSurface(rim, "Track", UDim.new(0, 8), { Color3.fromRGB(26, 60, 105), navy }, 3)
	face.Position = UDim2.fromOffset(2, 6)
	face.Size = UDim2.new(1, -4, 1, -12)
	edge:Clone().Parent = face
	local currentPortrait = portrait(holder, 0)
	local nextPortrait = portrait(holder, 1)
	local caption = Style.label("FormAndBonus", "", 14)
	caption.AnchorPoint = Vector2.new(0.5, 0)
	caption.Position = UDim2.fromScale(0.5, 1)
	caption.Size = UDim2.fromOffset(188, 19)
	caption.Font = Enum.Font.GothamMedium
	caption.BackgroundTransparency = 0
	caption.BackgroundColor3 = Color3.fromRGB(12, 30, 57)
	caption.BorderSizePixel = 0
	caption.Parent = holder
	local captionCorner = Instance.new("UICorner")
	captionCorner.CornerRadius = UDim.new(0, 6)
	captionCorner.Parent = caption
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.AnchorPoint = Vector2.new(0, 0.5)
	fill.Position = UDim2.fromScale(0, 0.5)
	fill.Size = UDim2.new(0, 0, 1, -12)
	fill.BackgroundColor3 = Color3.fromRGB(19, 215, 241)
	fill.BorderSizePixel = 0
	fill.ZIndex = 4
	local fc = Instance.new("UICorner")
	fc.CornerRadius = UDim.new(0, 10)
	fc.Parent = fill
	fill.Parent = face
	local sheen = Instance.new("UIGradient")
	sheen.Rotation = 90
	sheen.Color = ColorSequence.new(Color3.fromRGB(101, 255, 255), Color3.fromRGB(0, 203, 234))
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	sheen.Parent = fill

	local label = Style.label("Level", "", 23)
	label.Size = UDim2.fromScale(1, 1)
	label.Parent = face

	local function short(n: number): string
		if n >= 1e6 then
			return string.format("%.1fM", n / 1e6)
		elseif n >= 1e3 then
			return string.format("%.1fK", n / 1e3)
		end
		return tostring(math.floor(n))
	end

	local function progress(): (number, number, number)
		return (localPlayer:GetAttribute("TornadoLevel") :: number?) or 1,
			(localPlayer:GetAttribute("TornadoXp") :: number?) or 0,
			(localPlayer:GetAttribute("Rebirths") :: number?) or 0
	end

	-- Janela de confirmação do rebirth: o que ganha, o que fica e o que zera.
	local W, H = 440, 340
	local window, body, closeHit = Style.window("RebirthWindow", Style.Themes.Yellow, "REBIRTH", W, H, 56, 44)
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.5)
	window.Visible = false
	window.ZIndex = 20
	window.Parent = gui
	local fit = Instance.new("UIScale") -- celular curto: a janela encolhe para caber
	fit.Parent = window
	local list = Instance.new("Frame")
	list.Name = "Rows"
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromOffset(20, 68)
	list.Size = UDim2.new(1, -40, 1, -140)
	list.Parent = body
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.Parent = list
	local rows: { TextLabel } = {}
	for i = 1, 6 do
		local row = Style.label("Row" .. i, "", 18)
		row.Size = UDim2.new(1, 0, 0, 26)
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.LayoutOrder = i
		row.Parent = list
		rows[i] = row
	end
	local confirmHolder, confirmHit = Style.button("Confirm", Style.Themes.Green, "REBIRTH")
	confirmHolder.AnchorPoint = Vector2.new(0.5, 1)
	confirmHolder.Position = UDim2.new(0.5, 0, 1, -16)
	confirmHolder.Size = UDim2.fromOffset(220, 52)
	confirmHolder.Parent = body

	local function openWindow()
		local level, xp, rebirths = progress()
		if not Tornado.canRebirth(cfg, level, xp, rebirths) then
			return
		end
		local viewport = (workspace.CurrentCamera :: Camera).ViewportSize
		fit.Scale = math.min(1, (viewport.X - 32) / W, (viewport.Y - 32) / H)
		local r = rebirths
		local fromMax, toMax = Tornado.maxLevel(cfg, r), Tornado.maxLevel(cfg, r + 1)
		local unlocked = nil
		for _, f in cfg.Forms do
			if f.From > fromMax and f.From <= toMax then
				unlocked = f.Name
			end
		end
		rows[1].Text = `REBIRTHS  {r}  >>  {r + 1}`
		rows[2].Text = `XP  x{1 + cfg.Rebirth.XpBonus * r}  >>  x{1 + cfg.Rebirth.XpBonus * (r + 1)}`
		rows[3].Text = `DAMAGE  x{1 + cfg.Rebirth.DamageBonus * r}  >>  x{1 + cfg.Rebirth.DamageBonus * (r + 1)}`
		rows[4].Text = `MAX LEVEL  {fromMax}  >>  {toMax}`
			.. (if unlocked then `   NEW: {string.upper(unlocked)}` else "")
		rows[5].Text = "KEEP: rebirths and bonuses"
		rows[6].Text = "RESETS: level 1, XP bar 0, back to spawn"
		window.Visible = true
	end
	closeHit.Activated:Connect(function()
		window.Visible = false
	end)

	local asking = false
	local function ask(name: string)
		if asking then
			return
		end
		asking = true
		pcall(function()
			Remotes.func(name):InvokeServer()
		end)
		asking = false
	end
	confirmHit.Activated:Connect(function()
		window.Visible = false
		ask(Remotes.Names.Functions.Rebirth)
	end)

	-- Botão logo abaixo da barra: EVOLVE (sobe 1 nível) ou, no máximo, REBIRTH! (abre a janela). Tecla R.
	local actionHolder, actionHit, actionFace = Style.button("Evolve", Style.Themes.Green, "R  EVOLVE")
	actionHolder.AnchorPoint = Vector2.new(0.5, 0)
	actionHolder.Position = UDim2.new(0.5, 0, 0, 143)
	actionHolder.Size = UDim2.fromOffset(220, 48)
	actionHolder.Visible = false
	actionHolder.Parent = gui
	-- fwjelaa-ignore: findfirstchild-chain (Style.button sempre cria o "Text" no face)
	local actionText = actionFace:FindFirstChild("Text") :: TextLabel

	local function act()
		local level, xp, rebirths = progress()
		if Tornado.canEvolve(cfg, level, xp, rebirths) then
			ask(Remotes.Names.Functions.Evolve)
		elseif Tornado.canRebirth(cfg, level, xp, rebirths) then
			if window.Visible then
				window.Visible = false
				ask(Remotes.Names.Functions.Rebirth)
			else
				openWindow()
			end
		end
	end
	actionHit.Activated:Connect(act)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.R then
			task.spawn(act)
		end
	end)

	local function refresh()
		local level, xp, rebirths = progress()
		local need = Tornado.xpToNext(cfg, level)
		local form = cfg.Forms[Tornado.form(cfg, level)].Name
		local ratio = math.clamp(xp / need, 0, 1)
		local maxLevel = Tornado.maxLevel(cfg, rebirths)
		currentPortrait(form)
		nextPortrait(if level < maxLevel then cfg.Forms[Tornado.form(cfg, level + 1)].Name else nil)
		label.Text = `{short(xp)} / {short(need)} XP`
		caption.Text = `{form}   Nv. {level}   {1 + cfg.Rebirth.XpBonus * rebirths}× XP`
		fill.Size = UDim2.fromScale(ratio, 1)
		local evolve = Tornado.canEvolve(cfg, level, xp, rebirths)
		local rebirth = Tornado.canRebirth(cfg, level, xp, rebirths)
		actionHolder.Visible = evolve or rebirth
		local text = if evolve then "R  EVOLVE" else "R  REBIRTH!"
		if actionText.Text ~= text then
			actionText.Text = text
			Style.recolor(actionFace, if evolve then Style.Themes.Green else Style.Themes.Yellow)
		end
		if not rebirth then
			window.Visible = false
		end
	end
	localPlayer:GetAttributeChangedSignal("Rebirths"):Connect(refresh)

	local lastLevel = (localPlayer:GetAttribute("TornadoLevel") :: number?) or 1
	localPlayer:GetAttributeChangedSignal("TornadoXp"):Connect(refresh)
	localPlayer:GetAttributeChangedSignal("TornadoLevel"):Connect(function()
		refresh()
		local level = (localPlayer:GetAttribute("TornadoLevel") :: number?) or 1
		if level > lastLevel then
			-- comemoração curta do nível novo (pulo da barra)
			holder.Size = UDim2.fromOffset(326, 50)
			TweenService:Create(holder, TweenInfo.new(0.35, Enum.EasingStyle.Back), {
				Size = UDim2.fromOffset(318, 48),
			}):Play()
		end
		lastLevel = level
	end)
	refresh()
end

function TornadoClient.init()
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	QualityTier.onChanged(function()
		for _, v in visuals do
			if v.Level > 0 then
				resize(v, v.Level, v.Rebirths)
			end
		end
	end)
	Remotes.unreliable(Remotes.Names.Unreliable.BurstFx).OnClientEvent:Connect(onBurstFx)
	task.spawn(watchCity)
	RunService.RenderStepped:Connect(update)
	task.spawn(buildHud)
end

return TornadoClient
