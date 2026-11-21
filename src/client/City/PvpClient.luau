--!strict
-- PvP do jogador local (o servidor decide dano, recarga e morte; ver server/Match/PvpService).
--   * Clique (fora da UI) = rajada na direção do mouse; Q = skill da forma atual (Config/SkillConfig),
--     na direção do mouse (PC) ou da câmera (celular). Efeitos das skills: client/City/SkillFx.
--     No celular: botões RAJADA e Q junto do pulo (embaixo à direita, acima do botão de pulo).
--   * Investida: o servidor aceita (forma + recarga) e o cliente empurra o próprio personagem.
--     Sucção: o servidor manda Knock e o cliente da vítima puxa o próprio tornado (o cliente é dono da física).
--   * Escudo: bolha de ForceField em volta do tornado (todos veem); pisca no último segundo.
--   * Vida própria embaixo no centro (onde era o botão UPGRADES): "HP atual/máx"; nos outros, nível + vida em cima do tornado
--     (vermelho = ele te engole, verde = você engole ele).
--   * Efeito da rajada de todos (BurstFx).

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
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
local crownLabel: TextLabel? = nil -- "👑 BIGGEST TORNADO" acima da vida quando o maior é você

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

-- ===== efeito da rajada (de todos) =====

local function burstFx(origin: Vector3, dx: number, dz: number, reach: number)
	if typeof(origin) ~= "Vector3" or type(dx) ~= "number" or type(dz) ~= "number" or type(reach) ~= "number" then
		return
	end
	local center = origin + Vector3.new(dx, 0, dz) * (reach * 0.5)
	local part = Instance.new("Part")
	part.Name = "BurstFx"
	part.Shape = Enum.PartType.Cylinder
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(220, 235, 255)
	part.Transparency = 0.45
	part.Size = Vector3.new(0.4, reach * 0.4, reach * 0.4)
	part.CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90))
	part.Parent = Workspace
	local tween = TweenService:Create(part, TweenInfo.new(0.25), {
		Size = Vector3.new(0.4, reach, reach),
		Transparency = 1,
	})
	tween.Completed:Once(function()
		part:Destroy()
	end)
	tween:Play()
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
local SHIELD_COLOR = Color3.fromRGB(120, 200, 255)

local function buildHud(): () -> ()
	local gui = Instance.new("ScreenGui")
	gui.Name = "PvpHud"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.Parent = localPlayer:WaitForChild("PlayerGui")

	-- vida própria: embaixo no centro (onde ficava o UPGRADES do Destroy the City)
	local hpHolder, hpFace = Style.panel("Hp", Style.Themes.Night, 14)
	hpHolder.AnchorPoint = Vector2.new(0.5, 1)
	hpHolder.Position = UDim2.new(0.5, 0, 1, -16)
	hpHolder.Size = UDim2.fromOffset(220, 40)
	hpHolder.Parent = gui
	local hpFill = Instance.new("Frame")
	hpFill.Name = "Fill"
	hpFill.AnchorPoint = Vector2.new(0, 0.5)
	hpFill.Position = UDim2.new(0, 6, 0.5, 0)
	hpFill.BackgroundColor3 = HP_COLOR
	hpFill.BorderSizePixel = 0
	hpFill.ZIndex = 4
	local hpCorner = Instance.new("UICorner")
	hpCorner.CornerRadius = UDim.new(0, 10)
	hpCorner.Parent = hpFill
	hpFill.Parent = hpFace
	local hpText = Style.label("HpText", "HP", 18)
	hpText.Size = UDim2.fromScale(1, 1)
	hpText.Parent = hpFace
	local crown = Style.label("Crown", "👑 BIGGEST TORNADO", 16)
	crown.AnchorPoint = Vector2.new(0.5, 1)
	crown.Position = UDim2.new(0.5, 0, 0, -4)
	crown.Size = UDim2.new(1, 0, 0, 20)
	crown.TextColor3 = Color3.fromRGB(255, 214, 70)
	crown.Visible = false
	crown.Parent = hpHolder
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
	local qHolder, qHit, qFace = Style.button("SpecialButton", Style.Themes.Purple, "Q")
	qHolder.AnchorPoint = Vector2.new(1, 1)
	qHolder.Position = if touch then UDim2.new(1, -118, 1, -110) else UDim2.new(1, -24, 1, -24)
	qHolder.Size = UDim2.fromOffset(150, 64) -- cresce para a esquerda (âncora à direita): cabe o nome da skill
	qHolder.Parent = gui
	-- fwjelaa-ignore: findfirstchild-chain (Style.button sempre cria o "Text" no face)
	local qText = qFace:FindFirstChild("Text") :: TextLabel
	qHit.Activated:Connect(special)

	return function()
		local ratio = ratioOf(localPlayer)
		hpFill.Size = UDim2.new(ratio, -12 * ratio, 1, -12)
		local hp = math.ceil((localPlayer:GetAttribute("Hp") :: number?) or 0)
		hpText.Text = `HP {hp}/{math.ceil((localPlayer:GetAttribute("MaxHp") :: number?) or 0)}`
		local level = (localPlayer:GetAttribute("TornadoLevel") :: number?) or 1
		local remaining = nextSpecial - os.clock()
		local _, def = Skills.forForm(SkillConfig, Tornado.form(tcfg, level))
		local text = if remaining > 0 then `Q {math.ceil(remaining)}` else `Q {string.upper(def.Name)}`
		if qText.Text ~= text then
			qText.Text = text
			Style.recolor(qFace, if remaining > 0 then Style.Themes.Gray else Style.Themes.Purple)
		end
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
	local mine = (localPlayer:GetAttribute("TornadoLevel") :: number?) or 1
	local entries = {}
	for _, player in Players:GetPlayers() do
		table.insert(entries, {
			Id = player.UserId,
			Level = (player:GetAttribute("TornadoLevel") :: number?) or 1,
			Rebirths = (player:GetAttribute("Rebirths") :: number?) or 0,
		})
	end
	local king = Tornado.biggest(entries)
	if crownLabel then
		crownLabel.Visible = king == localPlayer.UserId
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
		tag.Gui.Enabled = true
		tag.Gui.Adornee = root
		tag.Gui.StudsOffsetWorldSpace = Vector3.new(0, Tornado.radius(tcfg, level) * TornadoConfig.Height + 3, 0)
		tag.Label.Text = if king == player.UserId then `👑 LV {level}` else `LV {level}`
		tag.Label.TextColor3 = if Pvp.canEat(pcfg, level, mine)
			then HP_COLOR
			elseif Pvp.canEat(pcfg, mine, level) then Color3.fromRGB(110, 230, 120)
			else Color3.new(1, 1, 1)
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
		local h = r * TornadoConfig.Height
		local bubble = bubbleFor(player)
		local size = math.max(h, r * 2) * 1.1 -- cobre o funil inteiro
		bubble.Size = Vector3.new(size, size, size)
		-- pé do tornado = root - 3 (igual ao TornadoClient); centro da bolha no meio da altura
		bubble.CFrame = CFrame.new(root.Position + Vector3.new(0, h * 0.5 - 3, 0))
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
	Remotes.unreliable(Remotes.Names.Unreliable.BurstFx).OnClientEvent:Connect(burstFx)
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
