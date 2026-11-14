--!strict
-- Lobby: ilha flutuante low-poly (referências de mapa 8-11) alta, de frente para a cidade.
-- Tem loja, roleta da sorte física, mural de recompensas, salão de classes e o portal PLAY.
-- As estações abrem as telas no cliente por ProximityPrompts (nomes fixos: OpenShop, OpenWheel,
-- OpenRewards, OpenClasses).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LobbyConfig = require(Shared.Config.LobbyConfig)
local MapConfig = require(Shared.Config.MapConfig)
local WheelConfig = require(Shared.Config.WheelConfig)
local Templates = require(Shared.Buildings.Templates)

local Builder = require(script.Parent.Builder)

local LobbyService = {}

local origin = CFrame.new(0, LobbyConfig.FloorHeight, LobbyConfig.CenterZ)
local lobbyFolder: Model? = nil
local onPortal: ((Player) -> ())? = nil

local COLORS = {
	Grass = Color3.fromRGB(96, 214, 98),
	GrassDark = Color3.fromRGB(70, 180, 80),
	Dirt = Color3.fromRGB(150, 98, 70),
	DirtDark = Color3.fromRGB(118, 76, 58),
	Stone = Color3.fromRGB(205, 205, 220),
	Path = Color3.fromRGB(230, 212, 170),
	Wood = Color3.fromRGB(150, 100, 64),
	Red = Color3.fromRGB(214, 58, 84),
	White = Color3.fromRGB(250, 250, 255),
	Blue = Color3.fromRGB(56, 110, 230),
	Gold = Color3.fromRGB(255, 200, 60),
	Purple = Color3.fromRGB(150, 80, 230),
	Neon = Color3.fromRGB(120, 230, 255),
}

-- Peça simples no espaço local do lobby (centro do gramado = origem, +Z = cidade).
local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	localCFrame: CFrame,
	color: Color3,
	shape: string?
): BasePart
	local b = {
		Size = { size.X, size.Y, size.Z },
		Pos = { 0, 0, 0 },
		Role = name,
		Shape = shape,
	}
	local p = Builder.shapedPart(b, origin * localCFrame)
	p.Name = name
	p.Anchored = true
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function label(target: BasePart, face: Enum.NormalId, text: string, color: Color3?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	-- poucos pixels por stud: o TextScaled do Roblox para em 100px, então assim o texto enche a placa
	gui.PixelsPerStud = 10
	gui.LightInfluence = 0
	local textLabel = Instance.new("TextLabel")
	textLabel.BackgroundTransparency = 1
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.Font = Enum.Font.FredokaOne
	textLabel.TextScaled = true
	textLabel.Text = text
	textLabel.TextColor3 = color or Color3.new(1, 1, 1)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 6
	stroke.Color = Color3.fromRGB(11, 18, 48)
	stroke.Parent = textLabel
	textLabel.Parent = gui
	gui.Parent = target
end

local function prompt(target: BasePart, name: string, action: string, objectText: string)
	local p = Instance.new("ProximityPrompt")
	p.Name = name
	p.ActionText = action
	p.ObjectText = objectText
	p.MaxActivationDistance = 16
	p.RequiresLineOfSight = false
	p.HoldDuration = 0
	p.Parent = target
end

-- Coloca um modelo dos Templates (árvores, cogumelos…) no lobby.
local function decor(parent: Instance, templateName: string, x: number, z: number, scale: number)
	local template = Templates[templateName]
	local palette = MapConfig[1].Palette
	local model = Builder.build(template, palette, math.floor(x * 7 + z * 13), origin * CFrame.new(x, 0, z))
	-- escala a partir da base (WorldPivot), sem perder a rotação das peças
	model:ScaleTo(scale)
	model.Parent = parent
end

local function buildIsland(parent: Instance)
	local w, d = LobbyConfig.Width, LobbyConfig.Depth
	part(parent, "Grass", Vector3.new(w, 4, d), CFrame.new(0, -2, 0), COLORS.Grass)
	part(parent, "GrassLip", Vector3.new(w + 4, 2, d + 4), CFrame.new(0, -4, 0), COLORS.GrassDark)
	-- terra em camadas, cada vez menor (ilha flutuante)
	local layers = {
		{ 0, 16, COLORS.Dirt },
		{ 30, 18, COLORS.DirtDark },
		{ 70, 20, COLORS.Dirt },
		{ 120, 16, COLORS.DirtDark },
	}
	local y = -5
	for _, layer in layers do
		local inset, height, color = layer[1], layer[2], layer[3]
		part(parent, "Dirt", Vector3.new(w - inset, height, d - inset * 0.8), CFrame.new(0, y - height / 2, 0), color)
		y -= height
	end
	-- pedras penduradas
	for _, spot in { { -60, -30 }, { 50, 20 }, { -20, 40 }, { 70, -40 }, { 0, -10 } } do
		part(
			parent,
			"HangingRock",
			Vector3.new(26, 26, 26),
			CFrame.new(spot[1], y - 6, spot[2]),
			COLORS.DirtDark,
			"Ball"
		)
	end
	-- paredes invisíveis na borda
	for _, spec in
		{
			{ Vector3.new(w, 80, 2), CFrame.new(0, 40, -d / 2) },
			{ Vector3.new(w, 80, 2), CFrame.new(0, 40, d / 2) },
			{ Vector3.new(2, 80, d), CFrame.new(-w / 2, 40, 0) },
			{ Vector3.new(2, 80, d), CFrame.new(w / 2, 40, 0) },
		}
	do
		local wall = part(parent, "Boundary", spec[1], spec[2], COLORS.White)
		wall.Transparency = 1
		wall.CastShadow = false
	end
	-- cerquinha de madeira nas laterais e no fundo
	for x = -w / 2 + 4, w / 2 - 4, 8 do
		part(parent, "FencePost", Vector3.new(1, 3.4, 1), CFrame.new(x, 1.7, -d / 2 + 2), COLORS.Wood)
	end
	part(parent, "FenceRail", Vector3.new(w - 6, 0.6, 0.6), CFrame.new(0, 2.6, -d / 2 + 2), COLORS.Wood)
	for z = -d / 2 + 4, d / 2 - 12, 8 do
		part(parent, "FencePost", Vector3.new(1, 3.4, 1), CFrame.new(-w / 2 + 2, 1.7, z), COLORS.Wood)
		part(parent, "FencePost", Vector3.new(1, 3.4, 1), CFrame.new(w / 2 - 2, 1.7, z), COLORS.Wood)
	end
	-- mirante de vidro na frente (lado da cidade)
	local glass = part(parent, "ViewGlass", Vector3.new(w - 8, 4, 0.6), CFrame.new(0, 2, d / 2 - 1.5), COLORS.Neon)
	glass.Transparency = 0.6
	part(parent, "ViewRail", Vector3.new(w - 8, 0.8, 1.2), CFrame.new(0, 4.4, d / 2 - 1.5), COLORS.White)
end

local function buildPlaza(parent: Instance)
	part(parent, "Plaza", Vector3.new(64, 0.4, 64), CFrame.new(0, 0.2, -10), COLORS.Stone, "Cylinder")
	for _, path in
		{
			{ Vector3.new(60, 0.3, 10), CFrame.new(-50, 0.15, -20) },
			{ Vector3.new(60, 0.3, 10), CFrame.new(50, 0.15, -20) },
			{ Vector3.new(10, 0.3, 70), CFrame.new(0, 0.15, 50) },
			{ Vector3.new(50, 0.3, 10), CFrame.new(-40, 0.15, 40) },
			{ Vector3.new(50, 0.3, 10), CFrame.new(40, 0.15, 40) },
		}
	do
		part(parent, "Path", path[1], path[2], COLORS.Path)
	end
	decor(parent, "Fountain", 0, -10, 1.2)
	local sign = part(parent, "TitleSign", Vector3.new(44, 12, 1), CFrame.new(0, 26, -60), COLORS.Gold)
	label(sign, Enum.NormalId.Back, "EAT CITY", COLORS.White)
	part(parent, "SignPostL", Vector3.new(1.5, 26, 1.5), CFrame.new(-18, 13, -60), COLORS.Wood)
	part(parent, "SignPostR", Vector3.new(1.5, 26, 1.5), CFrame.new(18, 13, -60), COLORS.Wood)
end

-- Loja: prédio em camadas vermelho e branco com placa azul "SHOP" (referência 8).
local function buildShop(parent: Instance)
	-- frente da loja (-Z local) virada para +X, para a praça
	local base = CFrame.new(-78, 0, -20) * CFrame.Angles(0, math.rad(-90), 0)
	local function at(x: number, y: number, z: number)
		return base * CFrame.new(x, y, z)
	end
	part(parent, "ShopFloor", Vector3.new(30, 1, 24), at(0, 0.5, 0), COLORS.Stone)
	part(parent, "ShopBody1", Vector3.new(28, 12, 22), at(0, 7, 0), COLORS.Red)
	part(parent, "ShopTrim1", Vector3.new(30, 1.6, 24), at(0, 13.8, 0), COLORS.White)
	part(parent, "ShopBody2", Vector3.new(24, 10, 18), at(0, 19.6, 0), COLORS.Red)
	part(parent, "ShopTrim2", Vector3.new(26, 1.6, 20), at(0, 25.4, 0), COLORS.White)
	local sign = part(parent, "ShopSign", Vector3.new(18, 7, 2), at(0, 30, -6), COLORS.Blue)
	label(sign, Enum.NormalId.Front, "SHOP", COLORS.White)
	for _, x in { -8, 8 } do
		part(parent, "ShopWindow", Vector3.new(5, 5, 0.4), at(x, 8, -11.2), Color3.fromRGB(140, 200, 255))
		part(parent, "ShopWindow2", Vector3.new(4, 4, 0.4), at(x, 20, -9.2), Color3.fromRGB(140, 200, 255))
	end
	part(parent, "ShopDoor", Vector3.new(5, 8, 0.4), at(0, 5, -11.2), COLORS.Wood)
	local counter = part(parent, "ShopCounter", Vector3.new(14, 3.4, 3), at(0, 1.7, -15), COLORS.Gold)
	-- toldo listrado
	for i = 0, 5 do
		local stripe = Builder.shapedPart(
			{ Size = { 4, 2, 4 }, Pos = { 0, 0, 0 }, Role = "Awning", Shape = "Wedge", Rot = 0 },
			origin * at(-10 + i * 4, 12, -13)
		)
		stripe.Anchored = true
		stripe.Color = if i % 2 == 0 then COLORS.Red else COLORS.White
		stripe.Material = Enum.Material.SmoothPlastic
		stripe.Parent = parent
	end
	prompt(counter, "OpenShop", "Open Shop", "Gem Shop")
end

-- Roleta da sorte física (referência 1): fatias coloridas, aro com pinos, ponteiro no topo.
-- A parte que gira fica no Model "Rotor" (o cliente anima).
local function buildWheel(parent: Instance)
	local radius = 14
	local center = Vector3.new(78, 22, -20)
	-- de frente para o centro da praça
	local facing = CFrame.lookAt(center, Vector3.new(0, 22, -10))
	local wheelModel = Instance.new("Model")
	wheelModel.Name = "LuckyWheel"

	local rotor = Instance.new("Model")
	rotor.Name = "Rotor"
	local segments = WheelConfig.Segments
	local count = #segments
	local slice = math.rad(360 / count)
	local half = slice / 2
	local a, b = radius * math.cos(half), radius * math.sin(half)
	local frame = origin * facing
	local worldCenter = frame.Position
	local look = frame.LookVector -- aponta para o espectador
	local function dir(angle: number): Vector3
		-- sentido horário visto por quem olha para a roda (direita do espectador = -RightVector)
		return frame.UpVector * math.cos(angle) - frame.RightVector * math.sin(angle)
	end
	for index, segment in segments do
		local mid = (index - 0.5) * slice
		local radial = dir(mid)
		local color = Color3.fromRGB(segment.Color[1], segment.Color[2], segment.Color[3])
		for _, side in { -1, 1 } do
			local tangent = dir(mid + side * math.pi / 2)
			local m = worldCenter + radial * a
			local position = m - radial * (a / 2) + tangent * (b / 2)
			local zAxis = radial
			local yAxis = tangent
			local xAxis = yAxis:Cross(zAxis)
			local wedge = Instance.new("WedgePart")
			wedge.Size = Vector3.new(1, b, a)
			wedge.CFrame = CFrame.fromMatrix(position, xAxis, yAxis, zAxis)
			wedge.Anchored = true
			wedge.Color = color
			wedge.Material = Enum.Material.SmoothPlastic
			wedge.Name = "Slice" .. index
			wedge.Parent = rotor
		end
		-- etiqueta da fatia (ícone + texto), virada para o espectador
		local tag = Instance.new("Part")
		tag.Name = "Tag" .. index
		tag.Size = Vector3.new(5, 4, 0.2)
		tag.Transparency = 1
		tag.CanCollide = false
		tag.Anchored = true
		-- texto "em pé" apontando para fora do centro; a face Front (-Z local) olha para o espectador
		local zAxis = -look
		tag.CFrame = CFrame.fromMatrix(worldCenter + radial * radius * 0.62 + look * 0.7, radial:Cross(zAxis), radial)
		label(tag, Enum.NormalId.Front, segment.Icon .. "\n" .. segment.Label)
		tag.Parent = rotor
		-- pino do aro na divisa entre fatias
		local peg = Instance.new("Part")
		peg.Shape = Enum.PartType.Ball
		peg.Size = Vector3.new(1.4, 1.4, 1.4)
		peg.Position = worldCenter + dir(index * slice) * (radius + 0.6) + look * 0.6
		peg.Anchored = true
		peg.Color = COLORS.Gold
		peg.Material = Enum.Material.Neon
		peg.Parent = rotor
	end
	local hub = Instance.new("Part")
	hub.Name = "Hub"
	hub.Shape = Enum.PartType.Cylinder
	hub.Size = Vector3.new(1.6, 6, 6)
	hub.CFrame = CFrame.fromMatrix(worldCenter + look * 0.6, look, frame.UpVector)
	hub.Anchored = true
	hub.Color = Color3.fromRGB(60, 64, 80)
	hub.Parent = rotor
	rotor.PrimaryPart = hub
	rotor.Parent = wheelModel

	-- aro de trás (não gira), suporte e ponteiro
	local back = Instance.new("Part")
	back.Shape = Enum.PartType.Cylinder
	back.Size = Vector3.new(1, radius * 2 + 3, radius * 2 + 3)
	back.CFrame = CFrame.fromMatrix(worldCenter - look * 0.8, look, frame.UpVector)
	back.Anchored = true
	back.Color = Color3.fromRGB(40, 60, 120)
	back.Parent = wheelModel
	for _, side in { -1, 1 } do
		local leg = Instance.new("Part")
		leg.Size = Vector3.new(2, 24, 2)
		leg.CFrame = frame * CFrame.new(side * 8, -10, 1.5) * CFrame.Angles(0, 0, math.rad(side * 12))
		leg.Anchored = true
		leg.Color = COLORS.Wood
		leg.Parent = wheelModel
	end
	-- ponteiro: triângulo (duas cunhas) com a ponta encostando no aro, em cima
	local tip = worldCenter + frame.UpVector * (radius + 0.4) + look * 1.2
	local pointerHeight, pointerHalf = 3.6, 1.6
	for _, side in { -1, 1 } do
		local tangent = frame.RightVector * side
		local m = tip + frame.UpVector * pointerHeight
		local yAxis, zAxis = tangent, frame.UpVector
		local pointerPart = Instance.new("WedgePart")
		pointerPart.Name = "Pointer"
		pointerPart.Size = Vector3.new(1, pointerHalf, pointerHeight)
		pointerPart.CFrame =
			CFrame.fromMatrix(m - zAxis * (pointerHeight / 2) + yAxis * (pointerHalf / 2), yAxis:Cross(zAxis), yAxis)
		pointerPart.Anchored = true
		pointerPart.Color = COLORS.Red
		pointerPart.Parent = wheelModel
	end
	local base = Instance.new("Part")
	base.Name = "WheelBase"
	base.Size = Vector3.new(24, 3, 10)
	base.CFrame = frame * CFrame.new(0, -20.5, 2)
	base.Anchored = true
	base.Color = COLORS.Wood
	base.Parent = wheelModel
	local sign = Instance.new("Part")
	sign.Name = "WheelSign"
	sign.Size = Vector3.new(22, 4, 1)
	sign.CFrame = frame * CFrame.new(0, -17, -1)
	sign.Anchored = true
	sign.Color = COLORS.Purple
	sign.Parent = wheelModel
	label(sign, Enum.NormalId.Front, "LUCKY WHEEL")
	prompt(base, "OpenWheel", "Spin", "Lucky Wheel")
	wheelModel.Parent = parent
end

local function buildStation(
	parent: Instance,
	name: string,
	x: number,
	z: number,
	color: Color3,
	title: string,
	promptName: string,
	action: string
)
	local board = part(parent, name .. "Board", Vector3.new(20, 12, 1.4), CFrame.new(x, 9, z), color)
	label(board, Enum.NormalId.Front, title)
	part(parent, name .. "PostL", Vector3.new(1.4, 15, 1.4), CFrame.new(x - 9, 7.5, z), COLORS.Wood)
	part(parent, name .. "PostR", Vector3.new(1.4, 15, 1.4), CFrame.new(x + 9, 7.5, z), COLORS.Wood)
	local pedestal = part(parent, name .. "Pedestal", Vector3.new(10, 3, 6), CFrame.new(x, 1.5, z + 5), COLORS.Stone)
	prompt(pedestal, promptName, action, title)
end

-- Portal PLAY na frente (lado da cidade): encostar nele entra na partida.
local function buildPortal(parent: Instance)
	local z = 70
	part(parent, "PortalPillarL", Vector3.new(4, 24, 4), CFrame.new(-12, 12, z), COLORS.Blue)
	part(parent, "PortalPillarR", Vector3.new(4, 24, 4), CFrame.new(12, 12, z), COLORS.Blue)
	local top = part(parent, "PortalTop", Vector3.new(30, 6, 5), CFrame.new(0, 27, z), COLORS.Gold)
	label(top, Enum.NormalId.Front, "PLAY ▶")
	local field = part(parent, "PortalField", Vector3.new(20, 22, 1), CFrame.new(0, 12, z), COLORS.Neon)
	field.Material = Enum.Material.Neon
	field.Transparency = 0.35
	field.CanCollide = false
	field.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if player and onPortal then
			onPortal(player)
		end
	end)
end

local function buildNature(parent: Instance)
	local spots = {
		{ "Pine", -105, -75, 2 },
		{ "Pine", -95, -50, 1.6 },
		{ "Tree", -105, 10, 1.8 },
		{ "Pine", -100, 60, 1.8 },
		{ "Mushroom", -88, 30, 2.4 },
		{ "Mushroom", -70, 62, 2 },
		{ "Pine", 105, -75, 2 },
		{ "Tree", 100, 20, 1.8 },
		{ "Pine", 100, 62, 1.6 },
		{ "Mushroom", 88, 40, 2.2 },
		{ "Bush", -30, -75, 2 },
		{ "Bush", 30, -75, 2 },
		{ "Rock", -40, 75, 1.4 },
		{ "Rock", 45, 75, 1.2 },
		{ "FlowerPot", -16, 20, 1.5 },
		{ "FlowerPot", 16, 20, 1.5 },
		{ "Tree", -60, -70, 1.6 },
		{ "Tree", 60, -70, 1.6 },
		{ "Bench", -24, -32, 1 },
		{ "Bench", 24, -32, 1 },
		{ "Lamp", -12, 40, 1 },
		{ "Lamp", 12, 40, 1 },
	}
	for _, spot in spots do
		decor(parent, spot[1] :: string, spot[2] :: number, spot[3] :: number, spot[4] :: number)
	end
end

function LobbyService.build()
	if lobbyFolder then
		lobbyFolder:Destroy()
	end
	local model = Instance.new("Model")
	model.Name = "Lobby"
	buildIsland(model)
	buildPlaza(model)
	buildShop(model)
	buildWheel(model)
	buildStation(model, "Rewards", -45, 45, COLORS.Gold, "DAILY REWARDS", "OpenRewards", "Claim")
	buildStation(model, "Classes", 45, 45, COLORS.Purple, "CLASSES", "OpenClasses", "Choose")
	buildPortal(model)
	buildNature(model)
	model.Parent = Workspace
	lobbyFolder = model
end

function LobbyService.onPortalTouched(callback: (Player) -> ())
	onPortal = callback
end

-- Ponto de spawn em volta da fonte, virado para a cidade.
function LobbyService.spawnCFrame(): CFrame
	local angle = math.random() * math.pi * 2
	local r = LobbyConfig.SpawnRadius + math.random() * 6
	local position = origin * CFrame.new(math.cos(angle) * r, 4, -10 + math.sin(angle) * r)
	return CFrame.lookAt(position.Position, position.Position + Vector3.new(0, 0, 1))
end

function LobbyService.teleport(player: Player)
	local character = player.Character
	if character then
		character:PivotTo(LobbyService.spawnCFrame())
	end
end

function LobbyService.isBelowLobby(position: Vector3): boolean
	return position.Y < LobbyConfig.FallKillHeight and math.abs(position.Z - LobbyConfig.CenterZ) < LobbyConfig.Depth
end

return LobbyService
