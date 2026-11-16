--!strict
-- Lobby: ilha flutuante no estilo voxel com stud (referência da ilha: grama xadrez, borda de areia,
-- palmeiras, guarda-sóis e flores), alta e de frente para a cidade.
-- Tem loja, roleta da sorte física, mural de recompensas, salão de classes e a área "START A RUN"
-- (quadrados no chão: pisar num vazio cria uma party; o PartyService cuida do resto).
-- As estações abrem as telas no cliente por ProximityPrompts (nomes fixos: OpenShop, OpenWheel,
-- OpenRewards, OpenClasses).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LobbyConfig = require(Shared.Config.LobbyConfig)
local MapConfig = require(Shared.Config.MapConfig)
local PartyConfig = require(Shared.Config.PartyConfig)
local RunArea = require(Shared.Logic.RunArea)
local WheelConfig = require(Shared.Config.WheelConfig)
local Templates = require(Shared.Buildings.Templates)

local Builder = require(script.Parent.Builder)

local LobbyService = {}

local origin = CFrame.new(0, LobbyConfig.FloorHeight, LobbyConfig.CenterZ)
local lobbyFolder: Model? = nil

-- Quadrado da área START A RUN, como o PartyService enxerga.
export type PadInfo = {
	Index: number,
	Area: RunArea.Pad, -- coordenadas locais do lobby
	Border: { BasePart },
	Title: TextLabel,
	Line: TextLabel,
	Exit: CFrame, -- para onde vai quem é tirado do quadrado
}
local padInfos: { PadInfo } = {}

local COLORS = {
	Grass = Color3.fromRGB(92, 214, 44),
	GrassDark = Color3.fromRGB(76, 196, 36),
	Sand = Color3.fromRGB(248, 220, 140),
	Dirt = Color3.fromRGB(150, 98, 60),
	DirtDark = Color3.fromRGB(128, 82, 50),
	Stone = Color3.fromRGB(205, 205, 220),
	Path = Color3.fromRGB(232, 206, 150),
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
	-- stud do Roblox em tudo, menos nas peças redondas, de vidro/neon e nas paredes invisíveis
	Builder.studify(p, shape ~= nil or name == "Boundary" or color == COLORS.Neon)
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

-- O "E" aparece dentro da própria placa/prédio: o prompt fica num Attachment na face da peça.
-- offset: posição local na peça (ex.: um pouco à frente da face Front, que é -Z).
local function prompt(target: BasePart, name: string, action: string, objectText: string, offset: Vector3)
	local anchor = Instance.new("Attachment")
	anchor.Name = name .. "Point"
	anchor.Position = offset
	anchor.Parent = target
	local p = Instance.new("ProximityPrompt")
	p.Name = name
	p.ActionText = action
	p.ObjectText = objectText
	p.MaxActivationDistance = LobbyConfig.PromptDistance
	p.RequiresLineOfSight = false
	p.HoldDuration = 0
	p.Parent = anchor
end

-- Coloca um modelo dos Templates (árvores, cogumelos…) no lobby.
-- y = altura do chão onde ele fica (0 = grama; a praça é mais alta).
local function decor(parent: Instance, templateName: string, x: number, z: number, scale: number, y: number?)
	local template = Templates[templateName]
	local palette = MapConfig[1].Palette
	local model = Builder.build(template, palette, math.floor(x * 7 + z * 13), origin * CFrame.new(x, y or 0, z))
	-- escala a partir da base (WorldPivot), sem perder a rotação das peças
	model:ScaleTo(scale)
	model.Parent = parent
end

local function buildIsland(parent: Instance)
	local w, d = LobbyConfig.Width, LobbyConfig.Depth
	-- gramado em xadrez: quadrados de 15 studs com a espessura toda (nenhum enfiado no outro)
	local tile = 15
	for i = 0, w // tile - 1 do
		for j = 0, d // tile - 1 do
			local x, z = -w / 2 + (i + 0.5) * tile, -d / 2 + (j + 0.5) * tile
			local color = if (i + j) % 2 == 1 then COLORS.GrassDark else COLORS.Grass
			part(parent, "Grass", Vector3.new(tile, 4, tile), CFrame.new(x, -2, z), color)
		end
	end
	-- praia de areia em volta, um degrau abaixo da grama: 4 faixas encostadas no gramado (não passam por baixo dele)
	local sand = 14
	part(parent, "Sand", Vector3.new(w + sand * 2, 4, sand), CFrame.new(0, -3, -d / 2 - sand / 2), COLORS.Sand)
	part(parent, "Sand", Vector3.new(w + sand * 2, 4, sand), CFrame.new(0, -3, d / 2 + sand / 2), COLORS.Sand)
	part(parent, "Sand", Vector3.new(sand, 4, d), CFrame.new(-w / 2 - sand / 2, -3, 0), COLORS.Sand)
	part(parent, "Sand", Vector3.new(sand, 4, d), CFrame.new(w / 2 + sand / 2, -3, 0), COLORS.Sand)
	-- terra em camadas, cada vez menor (ilha flutuante); a primeira encosta embaixo do gramado
	local layers = {
		{ 0, 16, COLORS.Dirt },
		{ 30, 18, COLORS.DirtDark },
		{ 70, 20, COLORS.Dirt },
		{ 120, 16, COLORS.DirtDark },
	}
	local y = -4
	for _, layer in layers do
		local inset, height, color = layer[1], layer[2], layer[3]
		part(parent, "Dirt", Vector3.new(w - inset, height, d - inset * 0.8), CFrame.new(0, y - height / 2, 0), color)
		y -= height
	end
	-- pedras penduradas embaixo da última camada (encostadas, uma embaixo da outra)
	for _, spot in { { -40, -20 }, { 40, 15 }, { -15, 25 }, { 45, -25 }, { 0, -5 } } do
		part(parent, "HangingRock", Vector3.new(24, 20, 24), CFrame.new(spot[1], y - 10, spot[2]), COLORS.DirtDark)
		part(parent, "HangingRock", Vector3.new(12, 10, 12), CFrame.new(spot[1] + 3, y - 25, spot[2] - 2), COLORS.Dirt)
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
	-- trilhos só entre os postes (não atravessam)
	local postX = -w / 2 + 4
	while postX <= w / 2 - 4 do
		part(parent, "FencePost", Vector3.new(1, 3.4, 1), CFrame.new(postX, 1.7, -d / 2 + 2), COLORS.Wood)
		if postX + 8 <= w / 2 - 4 then
			part(parent, "FenceRail", Vector3.new(7, 0.6, 0.6), CFrame.new(postX + 4, 2.6, -d / 2 + 2), COLORS.Wood)
		end
		postX += 8
	end
	for z = -d / 2 + 4, d / 2 - 12, 8 do
		part(parent, "FencePost", Vector3.new(1, 3.4, 1), CFrame.new(-w / 2 + 2, 1.7, z), COLORS.Wood)
		part(parent, "FencePost", Vector3.new(1, 3.4, 1), CFrame.new(w / 2 - 2, 1.7, z), COLORS.Wood)
	end
	-- mirante de vidro na frente (lado da cidade)
	local glass = part(parent, "ViewGlass", Vector3.new(w - 8, 4, 0.6), CFrame.new(0, 2, d / 2 - 1.5), COLORS.Neon)
	glass.Transparency = 0.6
	part(parent, "ViewRail", Vector3.new(w - 8, 0.8, 1.2), CFrame.new(0, 4.4, d / 2 - 1.5), COLORS.White)
end

local PLAZA_TOP = 0.4

local function buildPlaza(parent: Instance)
	part(parent, "Plaza", Vector3.new(56, PLAZA_TOP, 56), CFrame.new(0, PLAZA_TOP / 2, -10), COLORS.Stone)
	for _, path in
		{
			-- caminhos encostam na praça e terminam antes da loja, da roleta e das placas
			{ Vector3.new(22, 0.3, 10), CFrame.new(-39, 0.15, -20) },
			{ Vector3.new(22, 0.3, 10), CFrame.new(39, 0.15, -20) },
			{ Vector3.new(10, 0.3, 38), CFrame.new(0, 0.15, 37) }, -- até a área START A RUN
			{ Vector3.new(50, 0.3, 9), CFrame.new(-40, 0.15, 39.5) },
			{ Vector3.new(50, 0.3, 9), CFrame.new(40, 0.15, 39.5) },
		}
	do
		part(parent, "Path", path[1], path[2], COLORS.Path)
	end
	decor(parent, "Fountain", 0, -10, 1.2, PLAZA_TOP)
	-- placa entre dois postes encostados nas laterais (nada atravessa a placa) e viga em cima
	local signW, signH, signBottom, post = 44, 12, 20, 1.5
	local sign =
		part(parent, "TitleSign", Vector3.new(signW, signH, 1), CFrame.new(0, signBottom + signH / 2, -60), COLORS.Gold)
	label(sign, Enum.NormalId.Back, "EAT CITY", COLORS.White)
	local postH = signBottom + signH + 1
	for _, side in { -1, 1 } do
		part(
			parent,
			"SignPost",
			Vector3.new(post, postH, post),
			CFrame.new(side * (signW / 2 + post / 2), postH / 2, -60),
			COLORS.Wood
		)
	end
	part(
		parent,
		"SignBeam",
		Vector3.new(signW + post * 2 + 1, 1.2, post + 1),
		CFrame.new(0, postH + 0.6, -60),
		COLORS.Wood
	)
end

-- Loja: prédio em camadas vermelho e branco com placa azul "SHOP" (referência 8).
local function buildShop(parent: Instance)
	-- frente da loja (-Z local) virada para +X, para a praça
	local base = CFrame.new(-78, 0, -20) * CFrame.Angles(0, math.rad(-90), 0)
	local function at(x: number, y: number, z: number)
		return base * CFrame.new(x, y, z)
	end
	part(parent, "ShopFloor", Vector3.new(30, 1, 24), at(0, 0.5, 0), COLORS.Stone)
	local body = part(parent, "ShopBody1", Vector3.new(28, 12, 22), at(0, 7, 0), COLORS.Red)
	part(parent, "ShopTrim1", Vector3.new(30, 1.6, 24), at(0, 13.8, 0), COLORS.White)
	part(parent, "ShopBody2", Vector3.new(24, 10, 18), at(0, 19.6, 0), COLORS.Red)
	part(parent, "ShopTrim2", Vector3.new(26, 1.6, 20), at(0, 25.4, 0), COLORS.White)
	local sign = part(parent, "ShopSign", Vector3.new(18, 7, 2), at(0, 26.2 + 3.5, -6), COLORS.Blue)
	label(sign, Enum.NormalId.Front, "SHOP", COLORS.White)
	for _, x in { -8, 8 } do
		part(parent, "ShopWindow", Vector3.new(5, 5, 0.4), at(x, 8, -11.2), Color3.fromRGB(140, 200, 255))
		part(parent, "ShopWindow2", Vector3.new(4, 4, 0.4), at(x, 20, -9.2), Color3.fromRGB(140, 200, 255))
	end
	part(parent, "ShopDoor", Vector3.new(5, 8, 0.4), at(0, 5, -11.2), COLORS.Wood)
	-- toldo listrado
	for i = 0, 5 do
		local stripe = Builder.shapedPart(
			{ Size = { 4, 2, 4 }, Pos = { 0, 0, 0 }, Role = "Awning", Shape = "Wedge", Rot = 0 },
			origin * at(-10 + i * 4, 12, -13)
		)
		stripe.Anchored = true
		stripe.Color = if i % 2 == 0 then COLORS.Red else COLORS.White
		Builder.studify(stripe)
		stripe.Parent = parent
	end
	-- "E" na fachada da loja, na altura da porta
	prompt(body, "OpenShop", "Open Shop", "Gem Shop", Vector3.new(0, -1, -11.4))

	-- Indicador de compra (referência do "SELL"): anel de traços neon no chão na frente da porta
	-- e um ícone flutuante. O cliente gira o anel e faz o ícone subir e descer (LobbyController).
	local ringCenter = at(0, 0, -11 - LobbyConfig.ShopRingRadius - 2)
	local ring = Instance.new("Model")
	ring.Name = "ShopRing"
	local dashes = LobbyConfig.ShopRingDashes
	for k = 0, dashes - 1 do
		local angle = k * (2 * math.pi / dashes)
		local dash = part(
			ring,
			"RingDash",
			Vector3.new(1.8, 0.2, 0.6),
			ringCenter * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0.1, -LobbyConfig.ShopRingRadius),
			COLORS.Red
		)
		dash.Material = Enum.Material.Neon
		dash.CanCollide = false
	end
	ring.WorldPivot = origin * ringCenter
	ring.Parent = parent
	local floor = parent:FindFirstChild("ShopFloor") :: BasePart
	local anchor = Instance.new("Attachment")
	anchor.Name = "ShopIndicatorPoint"
	anchor.Parent = floor
	anchor.WorldPosition = (origin * ringCenter).Position + Vector3.new(0, 7, 0)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ShopIndicator"
	billboard.Size = UDim2.fromScale(10, 4)
	billboard.LightInfluence = 0
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 140
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.Text = "💎 BUY HERE"
	text.TextColor3 = Color3.fromRGB(255, 236, 90)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Color = Color3.fromRGB(11, 18, 48)
	stroke.Parent = text
	text.Parent = billboard
	billboard.Adornee = anchor
	billboard.Parent = anchor
end

-- Roleta da sorte física (referência 1): fatias coloridas, aro com pinos, ponteiro no topo.
-- A parte que gira fica no Model "Rotor" (o cliente anima).
local function buildWheel(parent: Instance)
	local radius = LobbyConfig.WheelRadius
	local center = Vector3.new(78, 22, -20)
	-- de frente para o centro da praça
	local facing = CFrame.lookAt(center, Vector3.new(0, 22, -10))
	local wheelModel = Instance.new("Model")
	wheelModel.Name = "LuckyWheel"
	-- a roda chega inteira no cliente e nunca sai da memória: o cliente gira o Rotor em volta do cubo
	-- central (PrimaryPart). Com streaming, uma roda pela metade girava em volta do ponto errado e "sumia".
	wheelModel.ModelStreamingMode = Enum.ModelStreamingMode.Persistent

	local rotor = Instance.new("Model")
	rotor.Name = "Rotor"
	local segments = WheelConfig.Segments
	local count = #segments
	local slice = math.rad(360 / count)
	local frame = origin * facing
	local worldCenter = frame.Position
	local look = frame.LookVector -- aponta para o espectador
	local function dir(angle: number): Vector3
		-- sentido horário visto por quem olha para a roda (direita do espectador = -RightVector)
		return frame.UpVector * math.cos(angle) - frame.RightVector * math.sin(angle)
	end
	local subSlices = LobbyConfig.WheelSubSlices
	local subHalf = slice / subSlices / 2
	local a, b = radius * math.cos(subHalf), radius * math.sin(subHalf)
	for index, segment in segments do
		local mid = (index - 0.5) * slice
		local radial = dir(mid)
		local color = Color3.fromRGB(segment.Color[1], segment.Color[2], segment.Color[3])
		-- a fatia é um leque de triângulos finos (cada um = 2 cunhas): a borda fica redonda
		for k = 0, subSlices - 1 do
			local subMid = (index - 1) * slice + (k + 0.5) * (slice / subSlices)
			local subRadial = dir(subMid)
			for _, side in { -1, 1 } do
				local tangent = dir(subMid + side * math.pi / 2)
				local m = worldCenter + subRadial * a
				local position = m - subRadial * (a / 2) + tangent * (b / 2)
				local zAxis = subRadial
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
		-- no mesmo plano das fatias, logo fora da borda; encosta no disco de trás
		peg.Size = Vector3.new(1, 1, 1)
		peg.Position = worldCenter + dir(index * slice) * (radius + 0.7)
		peg.Anchored = true
		peg.Color = COLORS.Gold
		peg.Material = Enum.Material.Neon
		peg.Parent = rotor
	end
	local hub = Instance.new("Part")
	hub.Name = "Hub"
	hub.Shape = Enum.PartType.Cylinder
	hub.Size = Vector3.new(1.6, 6, 6)
	-- cubo central na frente das fatias (encosta nelas, sem entrar)
	hub.CFrame = CFrame.fromMatrix(worldCenter + look * 1.3, look, frame.UpVector)
	hub.Anchored = true
	hub.Color = Color3.fromRGB(60, 64, 80)
	hub.Parent = rotor
	rotor.PrimaryPart = hub
	rotor.Parent = wheelModel

	-- aro de trás (não gira), suporte e ponteiro
	local back = Instance.new("Part")
	back.Shape = Enum.PartType.Cylinder
	back.Size = Vector3.new(1, radius * 2 + 3, radius * 2 + 3)
	-- disco de trás encostado atrás das fatias (as fatias têm 1 de espessura: de -0.5 a 0.5)
	back.CFrame = CFrame.fromMatrix(worldCenter - look * 1.0, look, frame.UpVector)
	back.Anchored = true
	back.Color = Color3.fromRGB(40, 60, 120)
	back.Parent = wheelModel
	-- pernas retas: em cima da base e encostadas atrás do disco
	for _, side in { -1, 1 } do
		local leg = Instance.new("Part")
		leg.Size = Vector3.new(2, 21, 2)
		leg.CFrame = frame * CFrame.new(side * 8, -8.5, 2.5)
		leg.Anchored = true
		leg.Color = COLORS.Wood
		leg.Parent = wheelModel
	end
	-- suporte do ponteiro em cima do disco de trás
	local mount = Instance.new("Part")
	mount.Name = "PointerMount"
	mount.Size = Vector3.new(2.4, 2.4, 1)
	mount.CFrame = frame * CFrame.new(0, radius + 1.5 + 1.2, 1.0)
	mount.Anchored = true
	mount.Color = Color3.fromRGB(40, 60, 120)
	mount.Parent = wheelModel
	-- ponteiro: triângulo (duas cunhas) no plano das fatias, acima dos pinos, encostado no suporte e no disco
	local tip = worldCenter + frame.UpVector * (radius + 1.25)
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
	prompt(sign, "OpenWheel", "Spin", "Lucky Wheel", Vector3.new(0, 0, -0.8))
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
	-- placa entre dois postes, sem nada atravessando: postes encostados nas laterais e viga em cima
	local boardW, boardH, thick = 20, 12, 1.4
	local bottom, post = 3, 1.4
	local board =
		part(parent, name .. "Board", Vector3.new(boardW, boardH, thick), CFrame.new(x, bottom + boardH / 2, z), color)
	label(board, Enum.NormalId.Front, title)
	local postH = bottom + boardH + 1
	for _, side in { -1, 1 } do
		part(
			parent,
			name .. "Post",
			Vector3.new(post, postH, post),
			CFrame.new(x + side * (boardW / 2 + post / 2), postH / 2, z),
			COLORS.Wood
		)
	end
	part(
		parent,
		name .. "Beam",
		Vector3.new(boardW + post * 2 + 1, 1.2, post + 1),
		CFrame.new(x, postH + 0.6, z),
		COLORS.Wood
	)
	-- "E" no meio da placa, um pouco à frente da face com o texto
	prompt(board, promptName, action, title, Vector3.new(0, -1, -(thick / 2 + 0.3)))
end

-- Placa com duas linhas (título e situação), atualizada pelo PartyService.
local function statusBoard(target: BasePart): (TextLabel, TextLabel)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.LightInfluence = 0
	local labels = {}
	for index, spec in { { 0.08, 0.5 }, { 0.6, 0.32 } } do
		local text = Instance.new("TextLabel")
		text.Name = if index == 1 then "Title" else "Line"
		text.BackgroundTransparency = 1
		text.Position = UDim2.fromScale(0.06, spec[1])
		text.Size = UDim2.fromScale(0.88, spec[2])
		text.Font = Enum.Font.FredokaOne
		text.TextScaled = true
		text.TextColor3 = if index == 1 then COLORS.White else COLORS.Gold
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 5
		stroke.Color = Color3.fromRGB(11, 18, 48)
		stroke.Parent = text
		text.Parent = gui
		labels[index] = text
	end
	gui.Parent = target
	return labels[1], labels[2]
end

local RUN_AREA_COLORS: { [string]: Color3 } = {
	Floor = Color3.fromRGB(196, 140, 86),
	Border = COLORS.Neon,
	Board = Color3.fromRGB(40, 64, 140),
	Wood = COLORS.Wood,
	Sign = COLORS.Gold,
}

-- Área START A RUN na frente da ilha (lado da borda +Z): quadrados, placas e a placa grande.
local function buildRunArea(parent: Instance)
	local cfg = LobbyConfig.RunArea
	local byPad: { [number]: { Border: { BasePart }, Board: BasePart? } } = {}
	for _, b in RunArea.boxes(cfg, PartyConfig.Pads) do
		local color = RUN_AREA_COLORS[b.Kind]
		local p = part(
			parent,
			b.Name,
			Vector3.new(b.Size[1], b.Size[2], b.Size[3]),
			CFrame.new(b.Pos[1], b.Pos[2], b.Pos[3]),
			color
		)
		if b.Kind == "Border" then
			p.Material = Enum.Material.Neon
		elseif b.Kind == "Sign" then
			local title, line = statusBoard(p)
			title.Text = "START A RUN"
			line.Text = "Step on a pad - play solo or bring up to 3 friends"
			line.TextColor3 = COLORS.White
		end
		if b.Pad then
			local entry = byPad[b.Pad] or { Border = {} }
			byPad[b.Pad] = entry
			if b.Kind == "Border" then
				table.insert(entry.Border, p)
			elseif b.Kind == "Board" then
				entry.Board = p
			end
		end
	end
	table.clear(padInfos)
	for _, pad in RunArea.pads(cfg, PartyConfig.Pads) do
		local entry = byPad[pad.Index]
		local title, line = statusBoard(entry.Board :: BasePart)
		local exitPosition = origin * Vector3.new(pad.X, 4, pad.Z - cfg.ExitBack)
		table.insert(padInfos, {
			Index = pad.Index,
			Area = pad,
			Border = entry.Border,
			Title = title,
			Line = line,
			Exit = CFrame.lookAt(exitPosition, exitPosition + Vector3.new(0, 0, 1)),
		})
	end
end

-- Posição em coordenadas locais do lobby (para conferir quem está em cima dos quadrados).
function LobbyService.toLocal(position: Vector3): Vector3
	return origin:PointToObjectSpace(position)
end

function LobbyService.pads(): { PadInfo }
	return padInfos
end

local function buildNature(parent: Instance)
	local spots = {
		{ "Palm", -108, -78, 1.8 },
		{ "Palm", -100, -40, 1.5 },
		{ "Tree", -105, 10, 1.6 },
		{ "Palm", -102, 62, 1.8 },
		{ "Umbrella", -84, 30, 1.6 },
		{ "Flowers", -70, 62, 1.6 },
		{ "Palm", 108, -78, 1.8 },
		{ "Tree", 100, 20, 1.6 },
		{ "Palm", 102, 62, 1.6 },
		{ "Umbrella", 86, 40, 1.6 },
		{ "Bush", -30, -75, 2 },
		{ "Bush", 30, -75, 2 },
		{ "Rock", -62, 75, 1.4 },
		{ "Rock", 62, 75, 1.2 },
		{ "Flowers", -18, 24, 1.4 },
		{ "Flowers", 18, 24, 1.4 },
		{ "Flowers", -55, -5, 1.2 },
		{ "Flowers", 60, 5, 1.2 },
		{ "Palm", -60, -72, 1.4 },
		{ "Palm", 60, -72, 1.4 },
		{ "Bench", -24, -32, 1, PLAZA_TOP },
		{ "Bench", 24, -32, 1, PLAZA_TOP },
		{ "Lamp", -12, 40, 1 },
		{ "Lamp", 12, 40, 1 },
	}
	for _, spot in spots do
		decor(parent, spot[1] :: string, spot[2] :: number, spot[3] :: number, spot[4] :: number, spot[5] :: number?)
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
	buildRunArea(model)
	buildNature(model)
	model.Parent = Workspace
	lobbyFolder = model
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
