--!strict
-- Lobby: ilha flutuante no estilo voxel com stud (referência da ilha: grama xadrez, borda de areia,
-- palmeiras, guarda-sóis e flores), alta e de frente para a cidade.
-- Tem loja, mural de recompensas, salão de classes e a área "START A RUN"
-- (quadrados no chão: pisar num vazio cria uma party; o PartyService cuida do resto).
-- A loja e as placas DAILY REWARDS e CLASSES abrem as janelas quando o jogador pisa no quadrado neon
-- do chão na frente delas (LobbyController).

local MaterialService = game:GetService("MaterialService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LobbyConfig = require(Shared.Config.LobbyConfig)
local MapConfig = require(Shared.Config.MapConfig)
local PartyConfig = require(Shared.Config.PartyConfig)
local RunArea = require(Shared.Logic.RunArea)
local Fountain = require(Shared.Logic.Fountain)
local LobbyTown = require(Shared.Logic.LobbyTown)
local LobbyPaths = require(Shared.Logic.LobbyPaths)
local BlockTrees = require(Shared.Logic.BlockTrees)
local Hedges = require(Shared.Logic.Hedges)
local WheelConfig = require(Shared.Config.WheelConfig)
local Templates = require(Shared.Buildings.Templates)
local PaletteConfig = require(Shared.Config.PaletteConfig)
local FountainMeshConfig = require(Shared.Config.FountainMeshConfig)
local FountainWaterMeshConfig = require(Shared.Config.FountainWaterMeshConfig)
local SignWoodConfig = require(Shared.Config.SignWoodConfig)

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

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local COLORS: { [string]: Color3 } = {}
for name, c in PaletteConfig.Lobby do
	COLORS[name] = rgb(c)
end
local INK = rgb(PaletteConfig.Ink)
local FONT = (Enum.Font :: any)[PaletteConfig.Font] :: Enum.Font

-- Textura estilizada da peça (LobbyConfig.Materials / WoodPrefixes): dá profundidade ao lobby.
local WOOD = { Material = "WoodPlanks", Variant = "SignWood" }
local function texture(p: BasePart, name: string)
	if not (LobbyConfig.Textured or LobbyConfig.TexturedParts[name]) then
		return
	end
	local spec = LobbyConfig.Materials[name]
	if spec == nil then
		for _, prefix in LobbyConfig.WoodPrefixes do
			if string.sub(name, 1, #prefix) == prefix then
				spec = WOOD
				break
			end
		end
	end
	if spec == nil or p.Material == Enum.Material.Neon or p.Transparency >= 1 then
		return
	end
	p.Material = (Enum.Material :: any)[spec.Material]
	if MaterialService:FindFirstChild(spec.Variant, true) then
		p.MaterialVariant = spec.Variant
	end
	local tint = (spec :: any).Tint
	if tint then
		p.Color = Color3.fromRGB(tint[1], tint[2], tint[3])
	end
end

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
	-- blocos com o kit do Blender (cantos chanfrados); finos/compridos demais continuam peça lisa
	local p = Builder.kitPart(b, origin * localCFrame)
	p.Name = name
	p.Anchored = true
	p.Color = color
	-- stud do Roblox em tudo, menos nas peças redondas, de vidro/neon e nas paredes invisíveis
	Builder.studify(p, shape ~= nil or name == "Boundary" or color == COLORS.Neon)
	texture(p, name)
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
	textLabel.Font = FONT
	textLabel.TextScaled = true
	textLabel.Text = text
	textLabel.TextColor3 = color or Color3.new(1, 1, 1)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 6
	stroke.Color = INK
	stroke.Parent = textLabel
	textLabel.Parent = gui
	gui.Parent = target
end

-- Peça invisível que só segura o texto (SurfaceGui) na frente de uma placa do Blender
-- (LobbyConfig.SignText). Não colide e fica fora da varredura de sobreposição.
local function textHolder(parent: Instance, name: string, spec: { Size: { number }, Pos: { number } }, base: CFrame)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = Vector3.new(spec.Size[1], spec.Size[2], 0.1)
	p.CFrame = origin * base * CFrame.new(spec.Pos[1], spec.Pos[2], spec.Pos[3])
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p:SetAttribute("NoAudit", true)
	p.Parent = parent
	return p
end

-- Modelo do Blender do lobby (LobbyConfig.Props) apoiado no chão em `base` (coordenadas locais do lobby).
-- nil = a mesh ainda não foi importada (quem chamou usa as peças antigas).
local function prop(parent: Instance, kind: string, base: CFrame, scale: number?): MeshPart?
	local spec = LobbyConfig.Props[kind]
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local mesh = spec and assets and assets:FindFirstChild(spec.Mesh, true)
	if not (mesh and mesh:IsA("MeshPart")) then
		return nil
	end
	local k = scale or 1
	local p = mesh:Clone()
	p.Name = kind
	p.Anchored = true
	p.Size = Vector3.new(spec.Size[1], spec.Size[2], spec.Size[3]) * k
	p.CFrame = origin * base * CFrame.new(spec.Center[1] * k, spec.Center[2] * k, spec.Center[3] * k)
	p.Parent = parent
	return p
end

-- Partes de madeira de uma placa do Blender (Config/SignWoodConfig): uma mesh por tom de madeira, com a cor
-- da madeira e o veio discreto (LobbyConfig.WoodVariant), na mesma base da placa.
local function signWood(parent: Instance, kind: string, base: CFrame)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local variant = MaterialService:FindFirstChild(LobbyConfig.WoodVariant, true) ~= nil
	for _, spec in SignWoodConfig[kind] or {} do
		local mesh = assets and assets:FindFirstChild(spec.Mesh, true)
		if mesh and mesh:IsA("MeshPart") then
			local p = mesh:Clone()
			p.Name = kind .. "Wood"
			p.Anchored = true
			p.Size = Vector3.new(spec.Size[1], spec.Size[2], spec.Size[3])
			p.CFrame = origin * base * CFrame.new(spec.Center[1], spec.Center[2], spec.Center[3])
			p.Color = rgb(spec.Color)
			p.Material = Enum.Material.Wood
			if variant then
				p.MaterialVariant = LobbyConfig.WoodVariant
			end
			p.Parent = parent
		end
	end
end

-- O modelo do Blender já foi importado?
local function hasProp(kind: string): boolean
	local spec = LobbyConfig.Props[kind]
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local mesh = spec and assets and assets:FindFirstChild(spec.Mesh, true)
	return mesh ~= nil and mesh:IsA("MeshPart")
end

-- Coloca um modelo dos Templates (árvores, cogumelos…) no lobby.
-- y = altura do chão onde ele fica (0 = grama; a praça é mais alta).
local function decor(parent: Instance, templateName: string, x: number, z: number, scale: number, y: number?)
	-- árvores, palmeiras, arbustos, guarda-sóis e bancos têm modelo do Blender (giro fixo pela posição;
	-- os bancos olham para a fonte)
	local natureScale = LobbyConfig.NatureScale[templateName]
	if natureScale and hasProp(templateName) then
		local yaw = if templateName == "Bench" then math.pi else ((x * 7 + z * 13) % 360) * math.pi / 180
		prop(parent, templateName, CFrame.new(x, y or 0, z) * CFrame.Angles(0, yaw, 0), scale * natureScale)
		return
	end
	local template = Templates[templateName]
	local palette = MapConfig[1].Palette
	local model = Builder.build(template, palette, math.floor(x * 7 + z * 13), origin * CFrame.new(x, y or 0, z))
	-- escala a partir da base (WorldPivot), sem perder a rotação das peças
	model:ScaleTo(scale)
	model.Parent = parent
end

-- Cerca no fundo e nas laterais. Com o Blender: trechos de poste + trilhos (passo 8, trilhos só entre os
-- postes) e um poste no fim. Sem: postes e trilhos em peças.
local function buildFence(parent: Instance, w: number, d: number)
	if not hasProp("Fence") then
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
		return
	end
	-- Cerca fechada em volta do parque todo (é o limite de onde o jogador pode ir): um poste em cada canto e,
	-- entre eles, trechos esticados para caber certinho (sem vão nas pontas).
	local fence = LobbyConfig.Props.Fence
	local post = 1.2
	local cx, cz = w / 2 - 2, d / 2 - 2 -- linha da cerca
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local corner = part(
				parent,
				"FencePost",
				Vector3.new(post, fence.Size[2] + 0.2, post),
				CFrame.new(sx * cx, (fence.Size[2] + 0.2) / 2, sz * cz),
				COLORS.Wood
			)
			corner.Material = Enum.Material.SmoothPlastic
		end
	end
	-- de `a` até `b` (pontos na linha da cerca, já descontando os postes dos cantos)
	local function run(a: Vector3, b: Vector3)
		local length = (b - a).Magnitude
		local dir = (b - a).Unit
		local yaw = math.atan2(-dir.Z, dir.X)
		local count = math.max(1, math.floor(length / 8 + 0.5))
		local each = length / count
		for i = 0, count - 1 do
			local section = prop(parent, "Fence", CFrame.new(a + dir * (each * (i + 0.5))) * CFrame.Angles(0, yaw, 0))
			if section then
				-- estica o trecho para ter o comprimento exato do espaço: os trechos e os postes dos cantos só encostam
				section.Size = Vector3.new(each, section.Size.Y, section.Size.Z)
				section.CFrame = origin
					* CFrame.new(a + dir * (each * (i + 0.5)) + Vector3.new(0, fence.Center[2], 0))
					* CFrame.Angles(0, yaw, 0)
			end
		end
	end
	local g = post / 2
	for _, s in { -1, 1 } do
		run(Vector3.new(-cx + g, 0, s * cz), Vector3.new(cx - g, 0, s * cz)) -- fundo e frente
		run(Vector3.new(s * cx, 0, -cz + g), Vector3.new(s * cx, 0, cz - g)) -- laterais
	end
end
local function buildIsland(parent: Instance)
	local w, d = LobbyConfig.Width, LobbyConfig.Depth
	-- gramado uniforme: uma peça só, lisa, de uma cor (pedido do usuário: sem o xadrez de quadrados)
	part(parent, "Grass", Vector3.new(w, 4, d), CFrame.new(0, -2, 0), COLORS.Grass)
	-- em volta: a cidadezinha (buildTown); o parque é um gramado no meio dela
	-- paredes invisíveis na borda
	for _, spec in
		{
			-- logo atrás da cerca (que fica a 2 da borda): ninguém sobe nela para sair
			{ Vector3.new(w, 120, 2), CFrame.new(0, 60, -d / 2 + 1) },
			{ Vector3.new(w, 120, 2), CFrame.new(0, 60, d / 2 - 1) },
			{ Vector3.new(2, 120, d - 4), CFrame.new(-w / 2 + 1, 60, 0) },
			{ Vector3.new(2, 120, d - 4), CFrame.new(w / 2 - 1, 60, 0) },
		}
	do
		local wall = part(parent, "Boundary", spec[1], spec[2], COLORS.White)
		wall.Transparency = 1
		wall.CastShadow = false
	end
	buildFence(parent, w, d)
	-- moitas de folhas por dentro da cerca, em grupinhos com falhas (Logic/Hedges), com a textura das árvores
	for _, c in Hedges.build(w, d, LobbyConfig.Hedge) do
		local p = part(
			parent,
			"Hedge",
			Vector3.new(c.Size, c.Height, c.Size),
			CFrame.new(c.X, c.Height / 2, c.Z),
			COLORS.Leaves
		)
		p.Material = Enum.Material.Grass
		if MaterialService:FindFirstChild(LobbyConfig.LeafVariant, true) then
			p.MaterialVariant = LobbyConfig.LeafVariant
		end
	end
end

-- Árvore de blocos (Logic/BlockTrees): tronco de madeira e camadas de folhas com a textura BlockLeaves.
local function blockTree(parent: Instance, x: number, z: number, scale: number, variant: number)
	local shape = BlockTrees.pick(variant)
	local model = Instance.new("Model")
	model.Name = "Tree"
	local base = origin * CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad((variant % 2) * 180), 0) -- 0 ou 180: a caixa no chão não muda
	for _, b in shape.Boxes do
		local p = Instance.new("Part")
		p.Anchored = true
		p.Size = Vector3.new(b.Size[1], b.Size[2], b.Size[3]) * scale
		p.CFrame = base * CFrame.new(b.Pos[1] * scale, b.Pos[2] * scale, b.Pos[3] * scale)
		Builder.studify(p, true)
		if b.Role == "Trunk" then
			p.Name = "Trunk"
			p.Color = COLORS.Trunk
			p.Material = Enum.Material.SmoothPlastic
		else
			p.Name = "Leaves"
			p.Color = COLORS.Leaves
			p.Material = Enum.Material.Grass
			if MaterialService:FindFirstChild(LobbyConfig.LeafVariant, true) then
				p.MaterialVariant = LobbyConfig.LeafVariant
			end
		end
		p.Parent = model
	end
	model.Parent = parent
	return model
end

-- Moita de folha (cubo com a textura das árvores) apoiada no chão.
local function leafCube(parent: Instance, x: number, z: number, size: number, height: number)
	local p = Instance.new("Part")
	p.Name = "Bush"
	p.Anchored = true
	p.Size = Vector3.new(size, height, size)
	p.CFrame = origin * CFrame.new(x, height / 2, z)
	Builder.studify(p, true)
	p.Color = COLORS.Leaves
	p.Material = Enum.Material.Grass
	if MaterialService:FindFirstChild(LobbyConfig.LeafVariant, true) then
		p.MaterialVariant = LobbyConfig.LeafVariant
	end
	p.Parent = parent
	return p
end

-- Cidadezinha em volta do parque (Logic/LobbyTown + LobbyConfig.Town): calçadas um degrau acima da rua,
-- rua com faixa amarela, casas dos Templates de frente para a rua, árvores, carros e gramado até o horizonte.
-- Só enfeite: as paredes invisíveis do parque não deixam ninguém sair.
local function buildTown(parent: Instance)
	local town = LobbyTown.build(LobbyConfig.Width, LobbyConfig.Depth, LobbyConfig.Town)
	local folder = Instance.new("Model")
	folder.Name = "Town"
	local function slab(name: string, r: LobbyTown.Rect, top: number, height: number, color: Color3)
		local size = Vector3.new(r.X1 - r.X0, height, r.Z1 - r.Z0)
		local center = CFrame.new((r.X0 + r.X1) / 2, top - height / 2, (r.Z0 + r.Z1) / 2)
		return part(folder, name, size, center, color)
	end
	for _, r in town.Ground do
		slab("TownGrass", r, 0, 4, COLORS.Grass)
	end
	for _, r in town.Roads do
		slab("Road", r, 0, 4, COLORS.Road)
	end
	for _, r in town.Sidewalks do
		slab("Sidewalk", r, 0.3, 4.3, COLORS.Sidewalk)
	end
	for _, r in town.Dashes do
		slab("RoadLine", r, 0.05, 0.05, COLORS.RoadLine)
	end
	local palette = MapConfig[1].Palette
	local houses = table.clone(town.Houses)
	for _, b in town.Buildings do
		table.insert(houses, b) -- prédios do fundo: mesmo jeito de montar
	end
	for _, s in town.Suburb do
		table.insert(houses, s) -- casas e prédios sortidos no meio da floresta
	end
	for _, o in town.Outskirts do
		if o.Template ~= "BlockTree" then
			table.insert(houses, o) -- casinhas dos arredores
		end
	end
	for i, item in houses do
		local template = Templates[item.Template]
		local at = origin * CFrame.new(item.X, 0, item.Z) * CFrame.Angles(0, math.rad(item.Yaw), 0)
		local model = Builder.build(template, palette, i * 7, at)
		model:ScaleTo(item.Scale)
		model.Parent = folder
	end
	for _, item in town.Cars do
		local at = origin * CFrame.new(item.X, 0, item.Z) * CFrame.Angles(0, math.rad(item.Yaw), 0)
		local model = Builder.build(Templates.Car, palette, math.floor(item.X), at)
		model:ScaleTo(item.Scale)
		model.Parent = folder
	end
	for _, group in { town.Trees, town.Forest, town.Outskirts } do
		for _, item in group do
			if item.Template ~= "BlockTree" then
				continue
			end
			blockTree(folder, item.X, item.Z, item.Scale, item.Variant or 1)
		end
	end
	for _, b in town.Bushes do
		leafCube(folder, b.X, b.Z, b.Scale, b.Variant or 2)
	end
	-- terreno redondo em volta de tudo (borda do mundo some no horizonte), com o material de grama
	local land = prop(folder, "Land", CFrame.new(0, 0, 0))
	if land then
		land.Name = "Land"
		land.Color = COLORS.Grass
		land.CanCollide = false
		land.CanQuery = false
		land.CastShadow = false
		texture(land, "TownGrass")
	end
	-- morros do horizonte (mesh do Blender com o material de grama do lobby)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local hills = table.clone(town.Hills)
	for _, m in town.Mountains do
		table.insert(hills, m)
	end
	for _, item in hills do
		local source = assets and assets:FindFirstChild("Lobby_" .. item.Template, true)
		if source and source:IsA("MeshPart") then
			local hill = source:Clone()
			hill.Name = "Hill"
			hill.Anchored = true
			hill.CFrame = origin * CFrame.new(item.X, hill.Size.Y / 2, item.Z)
			hill.Color = COLORS.Grass
			texture(hill, "TownGrass")
			hill.Parent = folder
		end
	end
	folder.Parent = parent
end

local PLAZA_TOP = 0.4

-- Água animada da fonte (LobbyConfig.FountainWater): jato no topo; em cada bacia de cima a água transborda
-- numa cortina (faixas translúcidas curvas, uma encostada na outra) com gotas caindo e respingos
-- onde ela bate na água de baixo.
local DROP = "rbxasset://textures/particles/smoke_main.dds" -- borrão macio: esticado vira gota/filete

local function waterEmitter(at: Attachment, rate: number, speed: NumberRange, lifetime: NumberRange): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = DROP
	e.Color = ColorSequence.new(COLORS.White, COLORS.FountainWater)
	e.Rate = rate
	e.Speed = speed
	e.Lifetime = lifetime
	e.EmissionDirection = Enum.NormalId.Right -- +X do attachment
	e.Acceleration = Vector3.new(0, -LobbyConfig.FountainWater.Gravity, 0)
	e.Parent = at
	return e
end

-- `host` = peça que segura os attachments; `center` = centro da base da fonte no mundo (a fonte não gira).
-- beams = false: as cortinas são os quadros do Blender (só ficam as gotas e os respingos aqui).
local function addFountainWater(host: BasePart, center: Vector3, pieces: { Fountain.Piece }, beams: boolean)
	local cfg = LobbyConfig.FountainWater
	local g = cfg.Gravity
	-- attachment no espaço da fonte (y a partir da base), com o eixo X apontando para `xAxis`
	local function point(name: string, pos: Vector3, xAxis: Vector3, yAxis: Vector3): Attachment
		local at = Instance.new("Attachment")
		at.Name = name
		at.CFrame = host.CFrame:ToObjectSpace(CFrame.fromMatrix(center + pos, xAxis, yAxis))
		at.Parent = host
		return at
	end

	-- jato: sobe da bola do topo e cai de volta na bacia de cima (gotas esticadas)
	local jet = cfg.Jet
	local top = pieces[#pieces].Pos[2] + pieces[#pieces].Size[2] / 2
	local up = point("Jet", Vector3.new(0, top, 0), Vector3.yAxis, Vector3.xAxis)
	local jetE =
		waterEmitter(up, jet.Rate, NumberRange.new(jet.Speed[1], jet.Speed[2]), NumberRange.new(2 * jet.Speed[2] / g))
	jetE.SpreadAngle = Vector2.new(jet.Spread, jet.Spread)
	jetE.Size = NumberSequence.new(jet.Size[1], jet.Size[2])
	jetE.Transparency = NumberSequence.new(0, 0.3)
	jetE.Orientation = Enum.ParticleOrientation.VelocityParallel
	jetE.Squash = NumberSequence.new(-1.5)

	local curtain, spill, splash = cfg.Curtain, cfg.Spill, cfg.Splash
	for _, s in Fountain.spills(pieces, LobbyConfig.Fountain) do
		local fall = math.sqrt(2 * s.Fall / g)
		local land = s.Radius + cfg.SpillOut
		local width = 2 * math.pi * land / curtain.Points * curtain.Overlap
		for i = 0, curtain.Points - 1 do
			local a = (i / curtain.Points) * math.pi * 2
			local out = Vector3.new(math.sin(a), 0, math.cos(a))
			local edge = point("Spill" .. s.Basin, out * s.Radius + Vector3.new(0, s.Top, 0), out, Vector3.yAxis)
			local hit = point("Land" .. s.Basin, out * land + Vector3.new(0, s.Top - s.Fall, 0), -Vector3.yAxis, out)
			-- cortina: sai da borda para fora (X da borda) e chega na água caindo reto (X do ponto de queda)
			if beams then
				local sheet = Instance.new("Beam")
				sheet.Attachment0 = edge
				sheet.Attachment1 = hit
				sheet.FaceCamera = true
				sheet.Segments = 10
				sheet.CurveSize0 = curtain.Curve
				sheet.CurveSize1 = curtain.Curve
				sheet.Width0 = width
				sheet.Width1 = width * 1.15
				sheet.Color = ColorSequence.new(COLORS.White, COLORS.FountainWater)
				sheet.Transparency = NumberSequence.new(curtain.Transparency[1], curtain.Transparency[2])
				sheet.LightEmission = 0.2 -- sem textura: lâmina de água lisa (o movimento vem das gotas)
				sheet.Parent = edge
			end
			-- gotas soltas na frente da cortina
			local drops = waterEmitter(
				edge,
				spill.Rate / curtain.Points,
				NumberRange.new(spill.Speed * 0.8, spill.Speed * 1.2),
				NumberRange.new(fall)
			)
			drops.SpreadAngle = Vector2.new(10, 10)
			drops.Size = NumberSequence.new(spill.Size)
			drops.Transparency = NumberSequence.new(0, 0.3)
			drops.Orientation = Enum.ParticleOrientation.VelocityParallel
			drops.Squash = NumberSequence.new(-spill.Stretch)
			-- respingo: espuma branca subindo onde a cortina bate na água
			local foam = waterEmitter(
				hit,
				splash.Rate / curtain.Points,
				NumberRange.new(splash.Speed[1], splash.Speed[2]),
				NumberRange.new(splash.Lifetime)
			)
			foam.EmissionDirection = Enum.NormalId.Left -- -X do ponto de queda = para cima
			foam.Color = ColorSequence.new(COLORS.White)
			foam.SpreadAngle = Vector2.new(35, 35)
			foam.Size = NumberSequence.new(splash.Size[1], splash.Size[2])
			foam.Transparency = NumberSequence.new(0.1, 1)
		end
	end

	local light = Instance.new("PointLight")
	light.Color = COLORS.FountainWater
	light.Range = 18
	light.Brightness = 0.5
	light.Parent = up
end

-- Fonte da praça (Logic/Fountain + LobbyConfig.Fountain): 3 bacias de pedra, a de baixo é o pé, com água
-- azul animada. A pedra são as meshes do Blender (assets/blender/build_fountain.py, FountainMeshConfig) quando
-- ela já foi importada; sem ela, a mesma fonte em peças lisas. A água é sempre peça do Roblox (transparente).
local FOUNTAIN_COLORS: { [string]: Color3 } = {
	Stone = COLORS.FountainStone,
	Trim = COLORS.FountainTrim,
	Water = COLORS.FountainWater,
}
-- meshes da pedra (FountainMeshConfig: nome -> base); nil se faltar alguma
local function fountainMeshes(): { [string]: MeshPart }?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if not assets then
		return nil
	end
	local found = {}
	for name in FountainMeshConfig.Bottom do
		local mesh = assets:FindFirstChild(name, true)
		if not (mesh and mesh:IsA("MeshPart")) then
			return nil
		end
		found[name] = mesh
	end
	return found
end

-- Quadros da água do Blender (FW_<Grupo>_<n>, assets/blender/build_fountain_water.py) numa pasta WaterFrames;
-- o FountainController do cliente troca o quadro visível. false = nem todos foram importados (usa Beams).
local function addWaterFrames(model: Model, base: CFrame): boolean
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if not assets then
		return false
	end
	local frames = Instance.new("Folder")
	frames.Name = "WaterFrames"
	for group, bottom in FountainWaterMeshConfig.Bottom do
		for n = 1, FountainWaterMeshConfig.Frames do
			local source = assets:FindFirstChild("FW_" .. group .. "_" .. n, true)
			if not (source and source:IsA("MeshPart")) then
				frames:Destroy()
				return false
			end
			local p = source:Clone()
			p.Name = group .. "_" .. n
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.Transparency = if n == 1 then LobbyConfig.FountainWater.FrameTransparency else 1
			p:SetAttribute("Group", group)
			p:SetAttribute("Frame", n)
			p:SetAttribute("NoAudit", true) -- água que escorre por cima da pedra
			-- meshes giradas em volta do eixo: centro X/Z no eixo, base na altura gerada pelo Blender
			p.CFrame = origin * base * CFrame.new(0, bottom + p.Size.Y / 2, 0)
			p.Parent = frames
		end
	end
	frames.Parent = model
	return true
end

local function buildFountain(parent: Instance, base: CFrame)
	local model = Instance.new("Model")
	model.Name = "Fountain"
	local center = (origin * base).Position
	local pieces = Fountain.pieces(LobbyConfig.Fountain)
	local source = fountainMeshes()
	local host: BasePart? = nil
	if source then
		for name, mesh in source do
			local stone = mesh:Clone()
			stone.Name = if name == "Lobby_FountainMesh" then "Stone" else "Trim"
			stone.Anchored = true
			-- giradas em volta do eixo: centro X/Z no eixo, base na altura gerada pelo Blender
			stone.CFrame = origin * base * CFrame.new(0, FountainMeshConfig.Bottom[name] + stone.Size.Y / 2, 0)
			stone:SetAttribute("NoAudit", true) -- a água encosta na pedra curva; a caixa da mesh não é a forma real
			stone.Parent = model
			host = host or stone
		end
	end
	local hasFrames = addWaterFrames(model, base)
	for _, piece in pieces do
		if source and piece.Role ~= "Water" then
			continue
		end
		local cf = origin * base * CFrame.new(piece.Pos[1], piece.Pos[2], piece.Pos[3]) * CFrame.Angles(0, piece.Yaw, 0)
		local box = { Size = piece.Size, Pos = { 0, 0, 0 }, Role = piece.Role, Shape = piece.Shape }
		local p = Builder.shapedPart(box :: any, cf)
		p.Name = piece.Name
		p.Anchored = true
		p.Color = FOUNTAIN_COLORS[piece.Role]
		Builder.studify(p, true)
		p.Material = Enum.Material.SmoothPlastic
		if piece.Role == "Water" then
			p.Transparency = 0.15
			p.Reflectance = 0.1
		end
		p.Parent = model
		if piece.Name == "Crown" then
			host = p
		end
	end
	if host then
		-- com a água do Blender, nada de partículas (jato, gotas, respingos): só os quadros animados
		if not hasFrames then
			addFountainWater(host, center, pieces, true)
		end
	end
	model.Parent = parent
end

local function buildPlaza(parent: Instance)
	-- praça (o 1º) e caminhos de pedra (LobbyConfig.Paths) com a borda de lajota em volta do contorno
	local rects: { LobbyPaths.Rect } = {}
	for i, p in LobbyConfig.Paths do
		local r = { X0 = p[1], Z0 = p[2], X1 = p[3], Z1 = p[4] }
		table.insert(rects, r)
		local height = if i == 1 then PLAZA_TOP else 0.3
		local size = Vector3.new(r.X1 - r.X0, height, r.Z1 - r.Z0)
		local center = CFrame.new((r.X0 + r.X1) / 2, height / 2, (r.Z0 + r.Z1) / 2)
		part(parent, if i == 1 then "Plaza" else "Path", size, center, if i == 1 then COLORS.Stone else COLORS.Path)
	end
	local edge = LobbyConfig.PathBorder
	for _, r in LobbyPaths.border(rects, edge.Width) do
		local size = Vector3.new(r.X1 - r.X0, edge.Height, r.Z1 - r.Z0)
		local center = CFrame.new((r.X0 + r.X1) / 2, edge.Height / 2, (r.Z0 + r.Z1) / 2)
		part(parent, "PathBorder", size, center, COLORS.PathBorder)
	end
	buildFountain(parent, CFrame.new(0, PLAZA_TOP, -10))
end

-- Quadrado no chão (LobbyConfig.ShopPad / StationPad): moldura neon de largura Strip. `at` leva das
-- coordenadas da loja/placa (z negativo = na frente) para o lobby. back = false deixa sem o lado de trás
-- (na loja o lado de trás é a casa). Quem entra abre a janela (LobbyController + RunArea.isOnFloorPad).
local function buildFloorPad(
	parent: Instance,
	name: string,
	pad: { X: number, Z0: number, Z1: number, Strip: number, Height: number },
	at: (number, number, number) -> CFrame,
	back: boolean
)
	local s, h = pad.Strip, pad.Height
	local z0, z1 = pad.Z0 + s, if back then pad.Z1 - s else pad.Z1 -- lados entre a frente e o fundo
	local strips = {
		{ Vector3.new(s, h, z1 - z0), at(-pad.X + s / 2, h / 2, (z0 + z1) / 2) },
		{ Vector3.new(s, h, z1 - z0), at(pad.X - s / 2, h / 2, (z0 + z1) / 2) },
		{ Vector3.new(pad.X * 2, h, s), at(0, h / 2, pad.Z0 + s / 2) },
	}
	if back then
		table.insert(strips, { Vector3.new(pad.X * 2, h, s), at(0, h / 2, pad.Z1 - s / 2) })
	end
	for _, strip in strips do
		local p = part(parent, name, strip[1], strip[2], COLORS.Neon)
		p.Material = Enum.Material.Neon
		p.CanCollide = false
	end
end

-- Loja: base em LobbyConfig.Shop, frente (-Z local) virada para a praça.
local function buildShop(parent: Instance)
	local cfg = LobbyConfig.Shop
	local base = CFrame.new(cfg.X, 0, cfg.Z) * CFrame.Angles(0, math.rad(cfg.Yaw), 0)
	local function at(x: number, y: number, z: number)
		return base * CFrame.new(x, y, z)
	end
	-- loja do Blender (assets/blender/build_shop_signs.py): casa de enxaimel, telhado vermelho, toldo
	-- listrado, vitrines acesas, placa com as letras SHOP em 3D e o carrinho na empena da frente; em volta,
	-- cerca de estacas com portão e lanternas, lampiões, barris, caixotes, vasos e canteiros
	if prop(parent, "ShopHouse", base) then
		for _, kind in { "ShopFence", "ShopYard" } do
			prop(parent, kind, base)
		end
		-- sem a mesh das letras, o SHOP vira texto na placa
		if not prop(parent, "ShopLetters", base) then
			local sign = textHolder(parent, "ShopSign", LobbyConfig.SignText.Shop, base)
			label(sign, Enum.NormalId.Front, "SHOP", COLORS.White)
		end
		buildFloorPad(parent, "ShopPad", LobbyConfig.ShopPad, at, false)
		return
	end
	-- sem a mesh: prédio em camadas de peças
	part(parent, "ShopFloor", Vector3.new(30, 1, 24), at(0, 0.5, 0), COLORS.Stone)
	part(parent, "ShopBody1", Vector3.new(28, 12, 22), at(0, 7, 0), COLORS.Red)
	part(parent, "ShopTrim1", Vector3.new(30, 1.6, 24), at(0, 13.8, 0), COLORS.White)
	part(parent, "ShopBody2", Vector3.new(24, 10, 18), at(0, 19.6, 0), COLORS.Red)
	part(parent, "ShopTrim2", Vector3.new(26, 1.6, 20), at(0, 25.4, 0), COLORS.White)
	local sign = part(parent, "ShopSign", Vector3.new(18, 7, 2), at(0, 26.2 + 3.5, -6), COLORS.Blue)
	label(sign, Enum.NormalId.Front, "SHOP", COLORS.White)
	for _, x in { -8, 8 } do
		part(parent, "ShopWindow", Vector3.new(5, 5, 0.4), at(x, 8, -11.2), COLORS.ShopWindow)
		part(parent, "ShopWindow2", Vector3.new(4, 4, 0.4), at(x, 20, -9.2), COLORS.ShopWindow)
	end
	part(parent, "ShopDoor", Vector3.new(5, 8, 0.4), at(0, 5, -11.2), COLORS.Wood)
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
	buildFloorPad(parent, "ShopPad", LobbyConfig.ShopPad, at, false)
end

-- Roleta da sorte (fatias coloridas, aro com pinos, ponteiro no topo). Não fica no lobby: vai para o
-- ReplicatedStorage e o cliente copia para dentro da janela SPIN. A parte que gira é o Model "Rotor".
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
	hub.Color = COLORS.Hub
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
	back.Color = COLORS.Board
	back.Parent = wheelModel
	-- suporte do ponteiro em cima do disco de trás
	local mount = Instance.new("Part")
	mount.Name = "PointerMount"
	mount.Size = Vector3.new(2.4, 2.4, 1)
	mount.CFrame = frame * CFrame.new(0, radius + 1.5 + 1.2, 1.0)
	mount.Anchored = true
	mount.Color = COLORS.Board
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
	for _, p in wheelModel:GetDescendants() do
		if p:IsA("BasePart") and p.Material == Enum.Material.Plastic then
			p.Material = Enum.Material.SmoothPlastic
		end
	end
	local old = parent:FindFirstChild(wheelModel.Name)
	if old then
		old:Destroy()
	end
	wheelModel.Parent = parent
end

local function buildStation(
	parent: Instance,
	name: string,
	x: number,
	z: number,
	color: Color3,
	title: string,
	mesh: string
)
	-- placa do Blender (placa azul com ícone, moldura de madeira, arco e floreira); o texto fica numa peça
	-- invisível na frente da placa azul. Na frente dela, o quadrado neon que abre a janela (como na loja).
	local base = CFrame.new(x, 0, z)
	buildFloorPad(parent, name .. "Pad", LobbyConfig.StationPad, function(px: number, py: number, pz: number)
		return base * CFrame.new(px, py, pz)
	end, true)
	if prop(parent, mesh, base) then
		signWood(parent, mesh, base)
		local holder = textHolder(parent, name .. "Board", LobbyConfig.SignText.Station, base)
		label(holder, Enum.NormalId.Front, title)
		return
	end
	-- sem a mesh: placa entre dois postes, postes encostados nas laterais e viga em cima
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
		text.Font = FONT
		text.TextScaled = true
		text.TextColor3 = if index == 1 then COLORS.White else COLORS.Gold
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 5
		stroke.Color = INK
		stroke.Parent = text
		text.Parent = gui
		labels[index] = text
	end
	gui.Parent = target
	return labels[1], labels[2]
end

local RUN_AREA_COLORS: { [string]: Color3 } = {
	Border = COLORS.Neon,
	Board = COLORS.Board,
	Wood = COLORS.Wood,
	Sign = COLORS.Gold,
}

-- Área START A RUN na frente da ilha (lado da borda +Z): quadrados, placas e a placa grande.
local function buildRunArea(parent: Instance)
	local cfg = LobbyConfig.RunArea
	local byPad: { [number]: { Border: { BasePart }, Board: BasePart? } } = {}
	-- portal do Blender (placas azuis entre postes, prancha em arco com a faixa do título): substitui as
	-- placas, postes e vigas em peças; os textos ficam em peças invisíveis na frente das placas azuis
	local gateBase = CFrame.new(0, 0, cfg.BoardZ)
	local gate = prop(parent, "RunGate", gateBase) ~= nil
	if gate then
		signWood(parent, "RunGate", gateBase)
	end
	local text = LobbyConfig.SignText
	for _, b in RunArea.boxes(cfg, PartyConfig.Pads) do
		if gate and b.Kind == "Wood" then
			continue
		end
		if gate and (b.Kind == "Board" or b.Kind == "Sign") then
			local spec = if b.Kind == "Sign"
				then text.RunTitle
				else {
					Size = { cfg.BoardWidth - text.RunBoard.Inset * 2, cfg.BoardHeight - text.RunBoard.Inset * 2 },
					Pos = { b.Pos[1], b.Pos[2], text.RunBoard.Front },
				}
			local holder = textHolder(parent, b.Name, spec, gateBase)
			if b.Kind == "Sign" then
				local title, line = statusBoard(holder)
				title.Text = "Start a Run"
				line.Text = "Step on a pad - play solo or bring up to 3 friends!"
				line.TextColor3 = COLORS.White
			elseif b.Pad then
				local entry = byPad[b.Pad] or { Border = {} }
				byPad[b.Pad] = entry
				entry.Board = holder
			end
			continue
		end
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
			title.Text = "Start a Run"
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
		{ "Umbrella", -84, 30, 1.6 },
		{ "Umbrella", 86, 40, 1.6 },
		{ "Bench", -14, -26, 1, PLAZA_TOP },
		{ "Bench", 14, -26, 1, PLAZA_TOP },
	}
	for _, spot in spots do
		decor(parent, spot[1] :: string, spot[2] :: number, spot[3] :: number, spot[4] :: number, spot[5] :: number?)
	end
	-- parque: floreiras, bancos, postes de luz (meshes do Blender) e árvores de blocos (Templates.Tree)
	local park = LobbyConfig.Park
	local function at(spot: { number }): CFrame
		return CFrame.new(spot[1], 0, spot[2]) * CFrame.Angles(0, math.rad(spot[3]), 0)
	end
	for _, spot in park.Planters do
		if not prop(parent, "PlanterLong", at(spot)) then
			prop(parent, "Planter", at(spot))
		end
	end
	for _, b in park.Bushes do
		leafCube(parent, b[1], b[2], b[3], b[3] * 0.8)
	end
	-- tulipas avulsas espalhadas no gramado (mesmo modelo das floreiras, sem o canteiro)
	for i, f in park.Flowers do
		local kind = if f[3] == 2 then "TulipPink" else "TulipRed"
		prop(parent, kind, CFrame.new(f[1], 0, f[2]) * CFrame.Angles(0, math.rad(i * 47 % 360), 0), park.FlowerScale)
	end
	for _, spot in park.WidePlanters do
		if not prop(parent, "PlanterWide", at(spot)) then
			prop(parent, "Planter", at(spot))
		end
	end
	for _, spot in park.Benches do
		if not prop(parent, "Bench", at(spot)) then
			decor(parent, "Bench", spot[1], spot[2], 1)
		end
	end
	for _, spot in park.Lamps do
		if not prop(parent, "ParkLamp", at(spot)) then
			decor(parent, "Lamp", spot[1], spot[2], 1)
		end
	end
	for i, spot in park.Trees do
		blockTree(parent, spot[1], spot[2], spot[3], i)
	end
	-- cogumelos de enfeite (mesh do Blender; sem ela, o cogumelo em blocos dos Templates)
	for _, m in LobbyConfig.Mushrooms do
		local x, z, k = m[1], m[2], m[3]
		local yaw = math.rad((x * 37 + z * 11) % 360) -- giro fixo pela posição
		if not prop(parent, "Mushroom", CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0), k) then
			decor(parent, "Mushroom", x, z, k * 1.2)
		end
	end
end

function LobbyService.build()
	if lobbyFolder then
		lobbyFolder:Destroy()
	end
	local model = Instance.new("Model")
	model.Name = "Lobby"
	buildIsland(model)
	buildTown(model)
	buildPlaza(model)
	buildShop(model)
	buildWheel(ReplicatedStorage)
	local stations = LobbyConfig.Stations
	local rewards, classes = stations.Rewards, stations.Classes
	buildStation(model, "Rewards", rewards[1], rewards[2], COLORS.Gold, "DAILY REWARDS", "SignRewards")
	buildStation(model, "Classes", classes[1], classes[2], COLORS.Purple, "CLASSES", "SignClasses")
	buildRunArea(model)
	buildNature(model)
	-- lobby liso igual à run: o Plastic (modelos do Blender, roleta) tem granulado, vira SmoothPlastic
	if not LobbyConfig.Textured then
		for _, p in model:GetDescendants() do
			if p:IsA("BasePart") and p.Material == Enum.Material.Plastic then
				p.Material = Enum.Material.SmoothPlastic
			end
		end
	end
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
