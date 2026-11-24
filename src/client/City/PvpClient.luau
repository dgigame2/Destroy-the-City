--!strict
-- PvP do jogador local (o servidor decide dano, recarga e morte; ver server/Match/PvpService).
--   * Clique (fora da UI) = rajada na direção do mouse; Q = skill da forma atual (Config/SkillConfig),
--     na direção do mouse (PC) ou da câmera (celular). Efeitos das skills: client/City/SkillFx.
--     No celular: botões RAJADA e Q junto do pulo (embaixo à direita, acima do botão de pulo).
--   * Investida: o servidor aceita (forma + recarga) e o cliente empurra o próprio personagem.
--     Sucção: o servidor manda Knock e o cliente da vítima puxa o próprio tornado (o cliente é dono da física).
--   * Escudo: bolha de ForceField em volta do tornado (todos veem); pisca no último segundo.
--   * Vida própria embaixo no centro (onde era o botão UPGRADES): "HP atual/máx"; nos outros, nível + vida em cima do tornado
--     (vermelho = dá para atacar; cinza com cadeado = diferença de nível grande demais).

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UiConfig = require(Shared.Config.UiConfig)
local healthStyle = UiConfig.HealthBar
local skillStyle = UiConfig.Skill
local art = UiConfig.Art
local Pvp = require(Shared.Logic.Pvp)
local PvpConfig = require(Shared.Config.PvpConfig)
local Tornado = require(Shared.Logic.Tornado)
local TornadoConfig = require(Shared.Config.TornadoConfig)
local Remotes = require(Shared.Remotes)
local Skills = require(Shared.Logic.Skills)
local SkillConfig = require(Shared.Config.SkillConfig)

local Style = require(script.Parent.Parent.Ui.Style)

local PvpClient = {}

local pcfg = PvpConfig :: Pvp.Config
local tcfg = TornadoConfig :: Tornado.Config
local localPlayer = Players.LocalPlayer
local nextBurst = 0
local nextSpecial = 0 -- só para mostrar a recarga; quem confere é o servidor
local crownHolder: Frame? = nil
local crownLabel: TextLabel? = nil

local function myRoot(): BasePart?
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function cameraFlat(): Vector3
	local look = (Workspace.CurrentCamera :: Camera).CFrame.LookVector
	return Vector3.new(look.X, 0, look.Z)
end

-- Direção do tornado até o ponto do chão embaixo do cursor (plano na altura do tornado).
local function aimAt(screen: Vector3, root: BasePart): Vector3
	local ray = (Workspace.CurrentCamera :: Camera):ScreenPointToRay(screen.X, screen.Y)
	if math.abs(ray.Direction.Y) > 1e-3 then
		local t = (root.Position.Y - ray.Origin.Y) / ray.Direction.Y
		if t > 0 then
			local point = ray.Origin + ray.Direction * t
			return Vector3.new(point.X - root.Position.X, 0, point.Z - root.Position.Z)
		end
	end
	return cameraFlat()
end

local function burst(direction: Vector3)
	local now = os.clock()
	if now < nextBurst or myRoot() == nil then
		return
	end
	nextBurst = now + pcfg.Burst.Cooldown
	Remotes.event(Remotes.Names.Events.Burst):FireServer(direction.X, direction.Z)
end

-- Empurra o próprio tornado por alguns segundos (velocidade horizontal; a vertical continua).
local function push(vx: number, vz: number, seconds: number)
	local root = myRoot()
	if root == nil then
		return
	end
	local stopAt = os.clock() + seconds
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function()
		if os.clock() > stopAt or root.Parent == nil then
			connection:Disconnect()
			return
		end
		root.AssemblyLinearVelocity = Vector3.new(vx, root.AssemblyLinearVelocity.Y, vz)
	end)
end

local function onKnock(vx: any, vz: any, seconds: any)
	if type(vx) == "number" and type(vz) == "number" and type(seconds) == "number" then
		push(vx, vz, math.clamp(seconds, 0, 1))
	end
end

local asking = false
local function special()
	local root = myRoot()
	local humanoid = localPlayer.Character and localPlayer.Character:FindFirstChildOfClass("Humanoid")
	if asking or root == nil or humanoid == nil then
		return
	end
	-- PC: para onde o mouse aponta; celular: para onde a câmera olha
	local dir = if UserInputService.MouseEnabled and not UserInputService.TouchEnabled
		then aimAt(
			Vector3.new(
				UserInputService:GetMouseLocation().X,
				UserInputService:GetMouseLocation().Y - GuiService:GetGuiInset().Y,
				0
			),
			root
		)
		else cameraFlat()
	asking = true
	local ok, name = pcall(function()
		return Remotes.func(Remotes.Names.Functions.Special):InvokeServer(dir.X, dir.Z)
	end)
	asking = false
	if not ok or type(name) ~= "string" then
		return
	end
	local level = (localPlayer:GetAttribute("TornadoLevel") :: number?) or 1
	local _, def = Skills.forForm(SkillConfig, Tornado.form(tcfg, level))
	nextSpecial = os.clock() + def.Cooldown
end

-- ===== HUD =====

local function bar(parent: Instance, name: string, color: Color3): (Frame, Frame)
	local back = Instance.new("Frame")
	back.Name = name
	back.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	back.BorderSizePixel = 0
	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(1, 0)
	bc.Parent = back
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	local fc = Instance.new("UICorner")
	fc.CornerRadius = UDim.new(1, 0)
	fc.Parent = fill
	fill.Parent = back
	back.Parent = parent
	return back, fill
end

local function ratioOf(player: Player): number
	local hp = (player:GetAttribute("Hp") :: number?) or 0
	local maxHp = (player:GetAttribute("MaxHp") :: number?) or 1
	return math.clamp(hp / maxHp, 0, 1)
end

local HP_COLOR = Color3.fromRGB(235, 70, 70)
local LOCKED_COLOR = Color3.fromRGB(170, 175, 185)
local SHIELD_COLOR = Color3.fromRGB(120, 200, 255)

local function buildHud(): () -> ()
	local gui = Instance.new("ScreenGui")
	gui.Name = "PvpHud"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.Parent = localPlayer:WaitForChild("PlayerGui")

	-- vida própria: embaixo no centro (onde ficava o UPGRADES do Destroy the City)
	local hpHolder = Instance.new("Frame")
	hpHolder.Name = "Hp"
	hpHolder.BackgroundColor3 = Color3.fromRGB(60, 15, 20)
	hpHolder.BorderSizePixel = 0
	hpHolder.AnchorPoint = Vector2.new(0.5, 1)
	hpHolder.Position = UDim2.new(0.5, healthStyle.HeartW / 4, 1, -healthStyle.Bottom)
	hpHolder.Size = UDim2.fromOffset(healthStyle.Width, healthStyle.Height)
	hpHolder.Parent = gui
	local clip = Instance.new("Frame")
	clip.Name = "Fill"
	clip.BackgroundTransparency = 1
	clip.ClipsDescendants = true
	clip.ZIndex = 2
	clip.Parent = hpHolder
	Style.art("FillArt", art.HpFill, UDim2.fromOffset(healthStyle.Width, healthStyle.Height), 2).Parent = clip
	Style.art("Border", art.HpEmpty, UDim2.fromScale(1, 1), 3).Parent = hpHolder
	local heart = Style.art("Heart", art.Heart, UDim2.fromOffset(healthStyle.HeartW, healthStyle.HeartH), 7)
	heart.AnchorPoint = Vector2.new(0.5, 0.5)
	heart.Position = UDim2.fromScale(0, 0.5)
	heart.Parent = hpHolder
	local hpText = Style.heavy("HpText", "", healthStyle.TextSize)
	hpText.Position = UDim2.fromOffset(healthStyle.HeartW / 2, 0)
	hpText.Size = UDim2.new(1, -healthStyle.HeartW / 2, 1, 0)
	hpText.ZIndex = 6
	hpText.Parent = hpHolder
	local leader, crownFace = Style.panel("Crown", Style.Themes.Blue, 9)
	leader.AnchorPoint = Vector2.new(0.5, 0)
	leader.Size = UDim2.fromOffset(192, 28)
	leader.Visible = false
	local hpScale = Instance.new("UIScale")
	hpScale.Parent = hpHolder
	local function fitHud()
		local compact = gui.AbsoluteSize.Y < UiConfig.CompactHeight
		hpScale.Scale = if compact then UiConfig.XpBar.CompactScale else 1
		leader.Position = UDim2.new(0.5, 0, 0, if compact then -6 else 19)
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitHud)
	fitHud()
	leader.Parent = gui
	local crown = Style.label("Leader", "", 14)
	crown.Position = UDim2.fromOffset(8, 0)
	crown.Size = UDim2.new(1, -16, 1, 0)
	crown.TextColor3 = Color3.fromRGB(255, 214, 70)
	crown.TextTruncate = Enum.TextTruncate.AtEnd
	crown.Parent = crownFace
	crownHolder = leader
	crownLabel = crown

	-- botões junto do pulo (o pulo do Roblox fica no canto de baixo à direita)
	local touch = UserInputService.TouchEnabled
	if touch then
		local holder, hit = Style.button("BurstButton", Style.Themes.Blue, "BLAST")
		holder.AnchorPoint = Vector2.new(1, 1)
		holder.Position = UDim2.new(1, -24, 1, -150)
		holder.Size = UDim2.fromOffset(84, 84)
		holder.Parent = gui
		hit.Activated:Connect(function()
			burst(cameraFlat())
		end)
	end
	-- tecla + nome do lado; no toque, sem a letra e com o nome embaixo
	local keySize = if touch then skillStyle.TouchKey else skillStyle.Key
	local qHit, qText = Style.artButton("SpecialButton", art.Key, "", UDim2.fromOffset(keySize, keySize), 34)
	qHit.AnchorPoint = Vector2.new(1, 1)
	qHit.Position = if touch then UDim2.new(1, -130, 1, -112) else UDim2.new(1, -32 - skillStyle.NameW, 1, -24)
	qHit.Parent = gui
	qHit.Activated:Connect(special)
	local qName = Style.heavy("SkillName", "", if touch then 15 else 20)
	qName.Size = UDim2.fromOffset(skillStyle.NameW, 24)
	if touch then
		qName.AnchorPoint = Vector2.new(0.5, 0)
		qName.Position = UDim2.new(0.5, 0, 1, 2)
	else
		qName.AnchorPoint = Vector2.new(0, 0.5)
		qName.Position = UDim2.new(1, 8, 0.5, 0)
		qName.TextXAlignment = Enum.TextXAlignment.Left
	end
	qName.Parent = qHit

	return function()
		local ratio = ratioOf(localPlayer)
		clip.Size = UDim2.fromScale(ratio, 1)
		local hp = math.ceil((localPlayer:GetAttribute("Hp") :: number?) or 0)
		hpText.Text = `HP {hp}/{math.ceil((localPlayer:GetAttribute("MaxHp") :: number?) or 0)}`
		local level = (localPlayer:GetAttribute("TornadoLevel") :: number?) or 1
		local remaining = nextSpecial - os.clock()
		local _, def = Skills.forForm(SkillConfig, Tornado.form(tcfg, level))
		qName.Text = string.upper(def.Name)
		qText.Text = if remaining > 0 then tostring(math.ceil(remaining)) elseif touch then "" else "Q"
		qHit.ImageColor3 = if remaining > 0 then Color3.fromRGB(110, 110, 110) else Color3.new(1, 1, 1)
	end
end

-- nível + vida em cima do tornado dos outros
type Tag = { Gui: BillboardGui, Label: TextLabel, Fill: Frame }
local tags: { [Player]: Tag } = {}

local function tagFor(player: Player): Tag
	local tag = tags[player]
	if tag then
		return tag
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "PvpTag_" .. player.UserId
	gui.Size = UDim2.fromOffset(110, 34)
	gui.AlwaysOnTop = false
	gui.ResetOnSpawn = false
	local label = Style.label("Level", "", 16)
	label.Size = UDim2.new(1, 0, 0, 20)
	label.Parent = gui
	local back, fill = bar(gui, "Hp", HP_COLOR)
	back.Position = UDim2.fromOffset(5, 22)
	back.Size = UDim2.new(1, -10, 0, 8)
	gui.Parent = localPlayer:WaitForChild("PlayerGui")
	tag = { Gui = gui, Label = label, Fill = fill }
	tags[player] = tag
	return tag
end

local function updateTags()
	local entries = {}
	for _, player in Players:GetPlayers() do
		table.insert(entries, {
			Id = player.UserId,
			Level = (player:GetAttribute("TornadoLevel") :: number?) or 1,
			Rebirths = (player:GetAttribute("Rebirths") :: number?) or 0,
		})
	end
	local king = Tornado.biggest(entries)
	if crownHolder and crownLabel then
		local leader = if king then Players:GetPlayerByUserId(king) else nil
		crownHolder.Visible = leader ~= nil
		if leader then
			crownLabel.Text = `👑 BIGGEST TORNADO · {leader.DisplayName}`
		end
	end
	for _, player in Players:GetPlayers() do
		if player == localPlayer then
			continue
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local tag = tagFor(player)
		if root == nil or not root:IsA("BasePart") then
			tag.Gui.Enabled = false
			continue
		end
		local level = (player:GetAttribute("TornadoLevel") :: number?) or 1
		local form = tcfg.Forms[Tornado.form(tcfg, level)]
		tag.Gui.Enabled = true
		tag.Gui.Adornee = root
		tag.Gui.StudsOffsetWorldSpace =
			Vector3.new(0, Tornado.radius(tcfg, level) * (form.Height + form.Crown / 2) + TornadoConfig.RootToGround, 0)
		local fightUntil = (localPlayer:GetAttribute(Pvp.fightKey(player.UserId)) :: number?) or 0
		local mine = (localPlayer:GetAttribute("TornadoLevel") :: number?) or 1
		local open = Pvp.canFight(pcfg, mine, level, fightUntil - Workspace:GetServerTimeNow())
		local crownText = if king == player.UserId then "👑 " else ""
		tag.Label.Text = `{if open then "" else "🔒 "}{crownText}LV {level}`
		tag.Label.TextColor3 = if open then HP_COLOR else LOCKED_COLOR
		tag.Fill.Size = UDim2.fromScale(ratioOf(player), 1)
	end
end

-- ===== escudo: bolha em volta do tornado =====

local bubbles: { [Player]: BasePart } = {}

local function bubbleFor(player: Player): BasePart
	local bubble = bubbles[player]
	if bubble then
		return bubble
	end
	bubble = Instance.new("Part")
	bubble.Name = "ShieldBubble"
	bubble.Shape = Enum.PartType.Ball
	bubble.Material = Enum.Material.ForceField
	bubble.Color = SHIELD_COLOR
	bubble.Anchored = true
	bubble.CanCollide = false
	bubble.CanQuery = false
	bubble.CanTouch = false
	bubble.CastShadow = false
	bubbles[player] = bubble
	return bubble
end

local function updateBubbles()
	local serverNow = Workspace:GetServerTimeNow()
	for _, player in Players:GetPlayers() do
		local left = ((player:GetAttribute("ShieldUntil") :: number?) or 0) - serverNow
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if left <= 0 or root == nil or not root:IsA("BasePart") then
			if bubbles[player] then
				bubbles[player].Parent = nil
			end
			continue
		end
		local level = (player:GetAttribute("TornadoLevel") :: number?) or 1
		local r = Tornado.radius(tcfg, level)
		local form = tcfg.Forms[Tornado.form(tcfg, level)]
		local h = r * form.Height
		local bubble = bubbleFor(player)
		local size = math.max(h, r * 2) * 1.1 -- cobre o funil inteiro
		bubble.Size = Vector3.new(size, size, size)
		-- pé do tornado = root - 3 (igual ao TornadoClient); centro da bolha no meio da altura
		bubble.CFrame = CFrame.new(root.Position + Vector3.new(0, h * 0.5 - TornadoConfig.RootToGround, 0))
		-- pisca no último segundo (avisa que vai acabar)
		bubble.Transparency = if left < 1 and math.floor(left * 8) % 2 == 0 then 0.7 else 0
		bubble.Parent = Workspace
	end
end

function PvpClient.init()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local root = myRoot()
			if root then
				burst(aimAt(input.Position, root))
			end
		elseif input.KeyCode == Enum.KeyCode.Q then
			task.spawn(special)
		end
	end)
	Remotes.event(Remotes.Names.Events.Knock).OnClientEvent:Connect(onKnock)
	RunService.RenderStepped:Connect(updateBubbles)
	Players.PlayerRemoving:Connect(function(player)
		if bubbles[player] then
			bubbles[player]:Destroy()
			bubbles[player] = nil
		end
		local tag = tags[player]
		if tag then
			tag.Gui:Destroy()
			tags[player] = nil
		end
	end)
	task.spawn(function()
		local refresh = buildHud()
		while true do
			refresh()
			updateTags()
			task.wait(0.1)
		end
	end)
end

return PvpClient
