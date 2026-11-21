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

local TornadoClient = {}

local cfg = TornadoConfig :: Tornado.Config
local SPIN = 1.6 -- voltas por segundo
local STRANDS = 3 -- fitas em espiral
local RINGS = 4 -- níveis de fumaça orbitando o funil
local OTHERS = 0.6 -- tornado dos outros: menos partículas

type Orbit = { Attachment: Attachment, Emitter: ParticleEmitter, Height: number, Width: number }
type Visual = {
	Root: Part,
	Strands: { { Beam: Beam, A0: Attachment, A1: Attachment, Offset: number } },
	Orbits: { Orbit },
	Dust: ParticleEmitter,
	Debris: ParticleEmitter,
	Cloud: ParticleEmitter,
	CloudAt: Attachment,
	Angle: number,
	Level: number,
	Rebirths: number,
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

local function formColor(level: number): Color3
	local c = cfg.Forms[Tornado.form(cfg, level)].Color
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function smoke(name: string, parent: Instance): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Texture = ElementFxConfig.Textures.Smoke
	e.LightEmission = 0
	e.LightInfluence = 0.6
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-120, 120)
	e.Parent = parent
	return e
end

-- Um tornado = uma peça invisível no chão com attachments que giram (o funil é só partícula e beam):
--   fitas em espiral (Beams com textura de fumaça), fumaça orbitando em 4 alturas (o rastro forma o funil),
--   poeira e detritos na base, nuvem no topo. Poucas peças; partículas caem com a qualidade e nos outros.
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
		local a0 = Instance.new("Attachment")
		a0.Parent = root
		local a1 = Instance.new("Attachment")
		a1.Parent = root
		local beam = Instance.new("Beam")
		beam.Texture = ElementFxConfig.Textures.Smoke
		beam.TextureMode = Enum.TextureMode.Stretch
		beam.TextureSpeed = 1.2
		beam.FaceCamera = true
		beam.Segments = 12
		beam.LightInfluence = 0.6
		beam.Transparency =
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 0.35) })
		beam.Attachment0 = a0
		beam.Attachment1 = a1
		beam.Parent = root
		strands[i] = { Beam = beam, A0 = a0, A1 = a1, Offset = (i - 1) * math.pi * 2 / STRANDS }
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
			NumberSequenceKeypoint.new(0.2, 0.45),
			NumberSequenceKeypoint.new(1, 1),
		})
		orbits[i] = { Attachment = a, Emitter = e, Height = f, Width = 0.25 + 0.75 * f } -- funil: fino embaixo
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
		NumberSequenceKeypoint.new(0.3, 0.5),
		NumberSequenceKeypoint.new(1, 1),
	})

	root.Parent = container()
	return {
		Root = root,
		Strands = strands,
		Orbits = orbits,
		Dust = dust,
		Debris = debris,
		Cloud = cloud,
		CloudAt = cloudAt,
		Angle = math.random() * math.pi * 2,
		Level = 0,
		Rebirths = -1, -- força o primeiro resize
		Own = own,
	}
end

-- Tamanho, cor e quantidade de partículas: só quando o nível muda (não a cada frame).
local function resize(v: Visual, level: number, rebirths: number)
	v.Level, v.Rebirths = level, rebirths
	local r = Tornado.radius(cfg, level)
	local h = r * TornadoConfig.Height
	local color = formColor(level)
	local dark = color:Lerp(Color3.new(0, 0, 0), 0.35)
	local q = QualityTier.current().Particles * (if v.Own then 1 else OTHERS)
	local aura = Tornado.aura(cfg, rebirths)
	local strand = if aura then color:Lerp(Color3.fromRGB(aura[1], aura[2], aura[3]), cfg.AuraMix) else color
	for _, s in v.Strands do
		s.Beam.Color = ColorSequence.new(strand)
		s.Beam.Width0 = r * 0.35
		s.Beam.Width1 = r * 1.3
		s.Beam.CurveSize0 = h * 0.15
		s.Beam.CurveSize1 = -h * 0.15
	end
	for _, o in v.Orbits do
		local size = r * o.Width * 1.1
		o.Emitter.Color = ColorSequence.new(color:Lerp(dark, o.Height))
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
	v.Cloud.Color = ColorSequence.new(dark)
	v.Cloud.Size =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, r * 1.4), NumberSequenceKeypoint.new(1, r * 2.2) })
	v.Cloud.Rate = 6 * q
	v.CloudAt.Position = Vector3.new(0, h, 0)
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
		local r = Tornado.radius(cfg, level)
		local h = r * TornadoConfig.Height
		v.Angle = (v.Angle + dt * SPIN * math.pi * 2) % (math.pi * 2)
		v.Root.CFrame = CFrame.new(root.Position - Vector3.new(0, 3, 0)) -- pé do personagem
		for _, s in v.Strands do
			local a = v.Angle + s.Offset
			s.A0.Position = Vector3.new(math.cos(a) * r * 0.2, 0, math.sin(a) * r * 0.2)
			local top = a + math.pi * 0.9 -- a fita dá quase meia volta subindo: espiral
			s.A1.Position = Vector3.new(math.cos(top) * r, h, math.sin(top) * r)
		end
		for i, o in v.Orbits do
			local a = v.Angle * (1.5 + o.Height) + i * 1.7
			local ri = r * o.Width * 0.7
			o.Attachment.Position = Vector3.new(math.cos(a) * ri, h * o.Height, math.sin(a) * ri)
		end
	end
end

-- ===== barra de XP =====

local function buildHud()
	local gui = Instance.new("ScreenGui")
	gui.Name = "TornadoHud"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.Parent = localPlayer:WaitForChild("PlayerGui")

	local holder, face = Style.panel("XpBar", Style.Themes.Night, 14)
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Position = UDim2.new(0.5, 0, 0, 56)
	holder.Size = UDim2.fromOffset(300, 46)
	holder.Parent = gui

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.AnchorPoint = Vector2.new(0, 0.5)
	fill.Position = UDim2.new(0, 6, 0.5, 0)
	fill.Size = UDim2.new(0, 0, 1, -12)
	fill.BackgroundColor3 = Style.Colors.Gold or Color3.fromRGB(255, 205, 70)
	fill.BorderSizePixel = 0
	fill.ZIndex = 4
	local fc = Instance.new("UICorner")
	fc.CornerRadius = UDim.new(0, 10)
	fc.Parent = fill
	fill.Parent = face

	local label = Style.label("Level", "", 20)
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
	actionHolder.Position = UDim2.new(0.5, 0, 0, 110)
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
		label.Text = `LV {level}/{Tornado.maxLevel(cfg, rebirths)} · {form} · {short(xp)}/{short(need)}`
		fill.Size = UDim2.new(ratio, -12 * ratio, 1, -12)
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
			holder.Size = UDim2.fromOffset(330, 52)
			TweenService:Create(holder, TweenInfo.new(0.35, Enum.EasingStyle.Back), {
				Size = UDim2.fromOffset(300, 46),
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
	task.spawn(watchCity)
	RunService.RenderStepped:Connect(update)
	task.spawn(buildHud)
end

return TornadoClient
