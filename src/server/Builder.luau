--!strict
-- Converte modelos de dados (Templates) em Models do Roblox com as cores da paleta do mapa.

local Builder = {}

type Box = { Size: { number }, Pos: { number }, Role: string, Shape: string?, Rot: number? }
type Template = { Name: string, Tier: number, Footprint: { number }, Boxes: { Box } }
type Palette = { [string]: { { number } } }

local MATERIALS: { [string]: Enum.Material } = {
	Light = Enum.Material.Neon,
	Water = Enum.Material.Glass,
	Window = Enum.Material.SmoothPlastic,
	Glass = Enum.Material.SmoothPlastic,
	Metal = Enum.Material.SmoothPlastic,
	Leaves = Enum.Material.SmoothPlastic,
}

local REFLECTIVE: { [string]: number } = {
	Window = 0.25,
	Glass = 0.3,
	Metal = 0.1,
}

function Builder.color(palette: Palette, role: string, variant: number): Color3
	local options = palette[role]
	local rgb = options[(variant % #options) + 1]
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

-- Cria a peça com a forma certa. Size dos dados é a caixa no espaço do mundo; aqui convertemos
-- para o tamanho/rotação local que cada forma do Roblox espera.
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
		-- 90 = alta em -X: girar o +Z local para -X é -90° em Y.
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
	elseif shape == "DiscZ" then
		part.Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new(sz, sy, sx)
		part.CFrame = base * CFrame.Angles(0, math.rad(90), 0)
	elseif shape == "DiscX" then
		part.Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new(sx, sy, sz)
		part.CFrame = base
	elseif shape == "Ball" then
		part.Shape = Enum.PartType.Ball
		part.Size = Vector3.new(sx, sy, sz)
		part.CFrame = base
	else
		part.Size = Vector3.new(sx, sy, sz)
		part.CFrame = base
	end
	return part
end

-- Cria o Model de uma construção já posicionado. Cada papel de cor usa uma variação da semente,
-- assim paredes e telhados não mudam juntos.
function Builder.build(template: Template, palette: Palette, variant: number, cframe: CFrame): Model
	local model = Instance.new("Model")
	model.Name = template.Name
	local roleVariant: { [string]: number } = {}
	local salt = 0
	for index, b in template.Boxes do
		if roleVariant[b.Role] == nil then
			salt += 7
			roleVariant[b.Role] = variant + salt
		end
		local part = Builder.shapedPart(b, cframe)
		part.Name = b.Role
		part.Anchored = true
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Color = Builder.color(palette, b.Role, roleVariant[b.Role])
		part.Material = MATERIALS[b.Role] or Enum.Material.SmoothPlastic
		part.Reflectance = REFLECTIVE[b.Role] or 0
		part.CanCollide = b.Role ~= "Window" and b.Role ~= "Light"
		part.CastShadow = b.Size[1] * b.Size[2] * b.Size[3] > 4
		part.Parent = model
		if index == 1 then
			model.PrimaryPart = part
		end
	end
	-- ponto de apoio = centro da base no chão (a primeira peça pode estar girada, ex.: cilindro)
	model.WorldPivot = cframe
	return model
end

return Builder
