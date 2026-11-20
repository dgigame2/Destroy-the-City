--!strict
-- Converte modelos de dados (Templates) em Models do Roblox com as cores da paleta do mapa
-- e o visual de blocos com stud (StudConfig).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StudConfig = require(Shared.Config.StudConfig)
local MeshKitConfig = require(Shared.Config.MeshKitConfig)
local MeshModelsConfig = require(Shared.Config.MeshModelsConfig)
local MeshKit = require(Shared.Logic.MeshKit)

local Builder = {}

type Box = {
	Size: { number },
	Pos: { number },
	Role: string,
	Shape: string?,
	Rot: number?,
	Tilt: { number }?,
}
type Template = { Name: string, Tier: number, Footprint: { number }, Boxes: { Box }, Mesh: string? }
type Palette = { [string]: { { number } } }

local SPECIAL_MATERIALS: { [string]: Enum.Material } = {
	Light = Enum.Material.Neon,
	Water = Enum.Material.Glass,
}

local REFLECTIVE: { [string]: number } = {
	Window = 0.15,
	Glass = 0.2,
	Ice = 0.1,
}

local TRANSPARENT: { [string]: number } = {
	Water = 0.25,
	Ice = 0.15,
}

-- Papéis que usam o mesmo sorteio de cor de outro papel (o telhado e o topo do telhado combinam).
local VARIANT_GROUP: { [string]: string } = {
	RoofTop = "Roof",
	Leaves2 = "Leaves",
	Stripe = "Awning",
}

local STUD_MATERIAL = (Enum.Material :: any)[StudConfig.Material] :: Enum.Material
local STUD_SURFACE = (Enum.SurfaceType :: any)[StudConfig.Surface] :: Enum.SurfaceType
local STUD_BOTTOM = (Enum.SurfaceType :: any)[StudConfig.BottomSurface] :: Enum.SurfaceType

function Builder.color(palette: Palette, role: string, variant: number): Color3
	local options = palette[role]
	local rgb = options[(variant % #options) + 1]
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

-- Aplica o visual de stud do Roblox em todas as faces (ou deixa liso, para luzes e água).
function Builder.studify(part: BasePart, smooth: boolean?)
	local surface = if smooth then Enum.SurfaceType.Smooth else STUD_SURFACE
	part.TopSurface = surface
	part.FrontSurface = surface
	part.BackSurface = surface
	part.LeftSurface = surface
	part.RightSurface = surface
	part.BottomSurface = if smooth then Enum.SurfaceType.Smooth else STUD_BOTTOM
	if not smooth then
		part.Material = STUD_MATERIAL
		if StudConfig.MaterialVariant ~= "" then
			part.MaterialVariant = StudConfig.MaterialVariant
		end
	end
end

-- Cria a peça com a forma certa. Size dos dados é a caixa no espaço do mundo (ou, com Tilt, no espaço
-- local da peça); aqui convertemos para o tamanho/rotação que cada forma do Roblox espera.
function Builder.shapedPart(b: Box, cframe: CFrame): BasePart
	local sx, sy, sz = b.Size[1], b.Size[2], b.Size[3]
	local base = cframe * CFrame.new(b.Pos[1], b.Pos[2], b.Pos[3])
	local shape = b.Shape or "Block"
	if shape == "Wedge" then
		local wedge = Instance.new("WedgePart")
		local rot = b.Rot or 0
		-- WedgePart: parte alta em +Z local. Rot 0 mantém; 180 inverte; 90/270 trocam X e Z.
		local quarter = rot == 90 or rot == 270
		wedge.Size = if quarter then Vector3.new(sz, sy, sx) else Vector3.new(sx, sy, sz)
		local angle = if rot == 90 then -90 elseif rot == 270 then 90 else rot
		wedge.CFrame = base * CFrame.Angles(0, math.rad(angle), 0)
		return wedge
	end
	local part = Instance.new("Part")
	if shape == "Cylinder" then
		-- cilindro do Roblox tem o eixo em X; em pé = girar 90° em Z
		part.Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new(sy, sx, sz)
		part.CFrame = base * CFrame.Angles(0, 0, math.rad(90))
		return part
	elseif shape == "CylinderZ" then
		-- deitado ao longo de Z: o eixo X do cilindro do Roblox gira 90° em Y
		part.Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new(sz, sy, sx)
		part.CFrame = base * CFrame.Angles(0, math.rad(90), 0)
		return part
	elseif shape == "Ball" then
		part.Shape = Enum.PartType.Ball
		part.Size = Vector3.new(sx, sy, sz)
		part.CFrame = base
		return part
	end
	part.Size = Vector3.new(sx, sy, sz)
	local tilt = b.Tilt
	if tilt then
		-- {pitch, yaw, roll} em graus, aplicado como Y * X * Z (igual ao Templates)
		part.CFrame = base * CFrame.fromEulerAnglesYXZ(math.rad(tilt[1]), math.rad(tilt[2]), math.rad(tilt[3]))
	else
		part.CFrame = base
	end
	return part
end

-- Mesh do kit do Blender (DioramaKit) já importada no Studio, por nome. Guarda em cache.
local kitCache: { [string]: MeshPart | false } = {}
local function kitMesh(name: string): MeshPart?
	local cached = kitCache[name]
	if cached ~= nil then
		return cached or nil
	end
	local assets = ReplicatedStorage:FindFirstChild(MeshKitConfig.Folder)
	local found = assets and assets:FindFirstChild(name, true)
	local mesh = if found and found:IsA("MeshPart") then found else nil
	kitCache[name] = mesh or false
	return mesh
end

-- Peça de um bloco com a mesh do kit (cantos chanfrados, copa low-poly...). Sem o kit, a peça normal.
-- A mesh tem caixa 1x1x1: Size do bloco = Size da mesh. O cilindro do kit já fica em pé (eixo Y).
function Builder.kitPart(b: Box, cframe: CFrame): BasePart
	local name = MeshKit.choose(b, MeshKitConfig)
	local mesh = name and kitMesh(name)
	if not mesh then
		return Builder.shapedPart(b, cframe)
	end
	local part = mesh:Clone()
	local base = cframe * CFrame.new(b.Pos[1], b.Pos[2], b.Pos[3])
	if b.Shape == "CylinderZ" then
		-- cilindro do kit (em pé, eixo Y) deitado ao longo de Z: gira 90° em X
		part.Size = Vector3.new(b.Size[1], b.Size[3], b.Size[2])
		part.CFrame = base * CFrame.Angles(math.rad(90), 0, 0)
	else
		part.Size = Vector3.new(b.Size[1], b.Size[2], b.Size[3])
		part.CFrame = base
	end
	part:SetAttribute("Kit", b.Shape or "Block") -- forma original (a varredura de sobreposição usa)
	return part
end

-- Mesh do Blender importada pelo usuário em ReplicatedStorage.Assets (nil = ainda não importou: usa os blocos).
local function meshFor(name: string?): MeshPart?
	if name == nil then
		return nil
	end
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local found = assets and assets:FindFirstChild(name, true)
	return if found and found:IsA("MeshPart") then found else nil
end

-- Contorno dos blocos (a mesh ocupa exatamente esta caixa).
local function hull(template: Template): (Vector3, Vector3)
	local min, max = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, b in template.Boxes do
		local half = Vector3.new(b.Size[1], b.Size[2], b.Size[3]) / 2
		local center = Vector3.new(b.Pos[1], b.Pos[2], b.Pos[3])
		min, max = min:Min(center - half), max:Max(center + half)
	end
	return min, max
end

-- Ponto de apoio do modelo no chão (centro da base). Com PrimaryPart, o GetPivot() usa o PivotOffset dela:
-- sem isso o pivô ficava no meio da 1ª peça e os escombros nasciam flutuando (bug de 16/11/2026).
-- Também guarda o chão no atributo "Ground" (quem precisar do chão não depende do pivô).
local function setGroundPivot(model: Model, cframe: CFrame)
	local primary = model.PrimaryPart
	if primary then
		primary.PivotOffset = primary.CFrame:ToObjectSpace(cframe)
	end
	model.WorldPivot = cframe
	model:SetAttribute("Ground", cframe.Position.Y)
end

-- Modelo feito no Blender (Config/MeshModelsConfig): todas as meshes dele já importadas? (nil = usa os blocos)
local modelCache: { [string]: { MeshPart } | false } = {}
local function blenderModel(name: string): { MeshPart }?
	local cached = modelCache[name]
	if cached ~= nil then
		return cached or nil
	end
	local pieces = MeshModelsConfig.Models[name]
	local assets = ReplicatedStorage:FindFirstChild(MeshModelsConfig.Folder)
	local found: { MeshPart } = {}
	if pieces and assets then
		for _, piece in pieces do
			local mesh = assets:FindFirstChild(piece.Mesh, true)
			if not (mesh and mesh:IsA("MeshPart")) then
				break
			end
			table.insert(found, mesh)
		end
	end
	local ok = pieces ~= nil and #found == #pieces
	modelCache[name] = if ok then found else false
	return if ok then found else nil
end

-- Cria o Model de uma construção já posicionado. Cada papel de cor usa uma variação da semente,
-- assim paredes e telhados não mudam juntos.
function Builder.build(template: Template, palette: Palette, variant: number, cframe: CFrame): Model
	local model = Instance.new("Model")
	model.Name = template.Name
	local roleVariant: { [string]: number } = {}
	local salt = 0
	local function variantFor(role: string): number
		local key = VARIANT_GROUP[role] or role
		if roleVariant[key] == nil then
			salt += 7
			roleVariant[key] = variant + salt
		end
		return roleVariant[key]
	end
	-- modelo do Blender: uma mesh por papel de cor, pintada com a paleta do mapa
	local meshes = blenderModel(template.Name)
	if meshes then
		local biggest = 0
		for index, piece in MeshModelsConfig.Models[template.Name] do
			local part = meshes[index]:Clone()
			part.Name = piece.Role
			part.Anchored = true
			part.Size = Vector3.new(piece.Size[1], piece.Size[2], piece.Size[3])
			part.CFrame = cframe * CFrame.new(piece.Center[1], piece.Center[2], piece.Center[3])
			part.Color = Builder.color(palette, piece.Role, variantFor(piece.Role))
			Builder.studify(part, StudConfig.Smooth[piece.Role] == true)
			part.Material = SPECIAL_MATERIALS[piece.Role] or Enum.Material.SmoothPlastic
			part.Reflectance = REFLECTIVE[piece.Role] or 0
			part.Transparency = TRANSPARENT[piece.Role] or 0
			part.CanCollide = piece.Role ~= "Window" and piece.Role ~= "Light"
			local volume = part.Size.X * part.Size.Y * part.Size.Z
			part.CastShadow = volume > 4
			part.Parent = model
			if volume > biggest then
				biggest = volume
				model.PrimaryPart = part
			end
		end
		setGroundPivot(model, cframe)
		return model
	end
	local mesh = meshFor(template.Mesh)
	if mesh then
		local min, max = hull(template)
		local part = mesh:Clone()
		part.Name = template.Name
		part.Anchored = true
		part.Size = max - min
		part.CFrame = cframe * CFrame.new((min + max) / 2)
		part.Parent = model
		model.PrimaryPart = part
		setGroundPivot(model, cframe)
		return model
	end
	for index, b in template.Boxes do
		local part = Builder.kitPart(b, cframe)
		part.Name = b.Role
		part.Anchored = true
		part.Color = Builder.color(palette, b.Role, variantFor(b.Role))
		Builder.studify(part, StudConfig.Smooth[b.Role] == true)
		local special = SPECIAL_MATERIALS[b.Role]
		if special then
			part.Material = special
		end
		part.Reflectance = REFLECTIVE[b.Role] or 0
		part.Transparency = TRANSPARENT[b.Role] or 0
		part.CanCollide = b.Role ~= "Window" and b.Role ~= "Light"
		part.CastShadow = b.Size[1] * b.Size[2] * b.Size[3] > 4
		-- índice do bloco no modelo: servidor e cliente usam para saber quais blocos caem em cada estágio
		part:SetAttribute("Box", index)
		part.Parent = model
		if index == 1 then
			model.PrimaryPart = part
		end
	end
	-- ponto de apoio = centro da base no chão
	setGroundPivot(model, cframe)
	return model
end

return Builder
