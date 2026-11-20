--!strict
-- Padrão visual "Depth Stack" do goat: sombra azulada, gradiente, elevação (lift) e contorno uniforme.
-- Estrutura das referências de UI: janelas claras com cabeçalho colorido e X vermelho, cards por raridade
-- com listras diagonais, etiquetas de preço verdes, atalhos-ícone.
-- Cores: paleta "Diorama" (Config/PaletteConfig), tirada dos mapas.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PaletteConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.PaletteConfig)
local IconConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.IconConfig)

local Style = {}

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end
Style.rgb = rgb

Style.Font = (Enum.Font :: any)[PaletteConfig.Font] :: Enum.Font
Style.TextStroke = rgb(PaletteConfig.Ink)
Style.Shadow = rgb(PaletteConfig.Shadow)
Style.Robux = utf8.char(0xE002) -- ícone de Robux das fontes do Roblox

-- cores de texto/barras prontas (Style.Colors.Gold etc.)
Style.Colors = {} :: { [string]: Color3 }
for name, c in PaletteConfig.Text do
	Style.Colors[name] = rgb(c)
end

export type Theme = { Top: Color3, Bottom: Color3, Outline: Color3 }

local function theme(name: string): Theme
	local t = PaletteConfig.Themes[name]
	assert(t, "tema inexistente no PaletteConfig: " .. name)
	return { Top = rgb(t.Top), Bottom = rgb(t.Bottom), Outline = rgb(t.Outline) }
end

-- Nomes usados pelas telas -> tema da paleta Diorama.
Style.Themes = {
	Blue = theme("Sky"),
	LightBlue = theme("Sea"),
	Green = theme("Grass"),
	Yellow = theme("Sand"),
	Red = theme("Roof"),
	Purple = theme("Violet"),
	Pink = theme("Blossom"),
	Orange = theme("Sunset"),
	Gray = theme("Stone"),
	Paper = theme("Paper"),
	Night = theme("Night"),
	-- raridades
	Common = theme("Stone"),
	Rare = theme("Sky"),
	Epic = theme("Violet"),
	Legendary = theme("Sand"),
}

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

-- Painel com profundidade. Retorna (holder, face): posicione/dimensione o holder; conteúdo vai na face.
function Style.panel(name: string, t: Theme, radius: number?): (Frame, Frame)
	local r = radius or 18
	local holder = Instance.new("Frame")
	holder.Name = name
	holder.BackgroundTransparency = 1

	-- 1. Shadow
	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.Size = UDim2.fromScale(1, 1)
	shadow.Position = UDim2.fromOffset(0, 6)
	shadow.BackgroundColor3 = Style.Shadow
	shadow.BackgroundTransparency = PaletteConfig.ShadowTransparency
	shadow.BorderSizePixel = 0
	shadow.ZIndex = 1
	corner(shadow, r)
	shadow.Parent = holder

	-- 2. Gradient
	local face = Instance.new("Frame")
	face.Name = "Face"
	face.Size = UDim2.fromScale(1, 1)
	face.BackgroundColor3 = Color3.new(1, 1, 1)
	face.BorderSizePixel = 0
	face.ZIndex = 2
	corner(face, r)
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(t.Top, t.Bottom)
	gradient.Parent = face

	-- 4. Outline
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Color = t.Outline
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = face
	face.Parent = holder

	-- 3. Lift
	local lift = Instance.new("Frame")
	lift.Name = "Lift"
	lift.AnchorPoint = Vector2.new(0.5, 0)
	lift.Position = UDim2.new(0.5, 0, 0, 5)
	lift.Size = UDim2.new(1, -12, 0.3, 0)
	lift.BackgroundColor3 = Color3.new(1, 1, 1)
	lift.BackgroundTransparency = PaletteConfig.Lift
	lift.BorderSizePixel = 0
	lift.ZIndex = 3
	corner(lift, math.max(r - 6, 4))
	lift.Parent = face

	return holder, face
end

-- Listras diagonais suaves dentro de uma face (cards por raridade, referência "store").
function Style.stripes(face: Frame)
	local clip = Instance.new("Frame")
	clip.Name = "Stripes"
	clip.BackgroundTransparency = 1
	clip.Size = UDim2.fromScale(1, 1)
	clip.ClipsDescendants = true
	clip.ZIndex = 2
	corner(clip, 16)
	for i = -6, 14 do
		local stripe = Instance.new("Frame")
		stripe.BackgroundColor3 = Color3.new(1, 1, 1)
		stripe.BackgroundTransparency = 0.87
		stripe.BorderSizePixel = 0
		stripe.AnchorPoint = Vector2.new(0.5, 0.5)
		stripe.Position = UDim2.fromScale(i * 0.12, 0.5)
		stripe.Size = UDim2.new(0, 14, 2.5, 0)
		stripe.Rotation = 30
		stripe.ZIndex = 2
		stripe.Parent = clip
	end
	clip.Parent = face
end

-- Texto branco com contorno escuro.
function Style.label(name: string, text: string, textSize: number?): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = Style.Font
	label.Text = text
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = textSize == nil
	if textSize then
		label.TextSize = textSize
	end
	label.ZIndex = 5
	local stroke = Instance.new("UIStroke")
	stroke.Color = Style.TextStroke
	stroke.Thickness = if (textSize or 40) >= 36 then 3 else 2
	stroke.Parent = label
	local limit = Instance.new("UITextSizeConstraint")
	limit.MinTextSize = 14 -- regra "No Tiny Text"
	limit.MaxTextSize = 96
	limit.Parent = label
	return label
end

-- Ícone: imagem do IconConfig quando o emoji tem uma (contorno Ink já desenhado no PNG),
-- senão o próprio emoji como texto.
function Style.glyph(name: string, glyph: string): GuiObject
	local id = IconConfig[glyph]
	if not id then
		return Style.label(name, glyph)
	end
	local image = Instance.new("ImageLabel")
	image.Name = name
	image.BackgroundTransparency = 1
	image.Image = id
	image.ScaleType = Enum.ScaleType.Fit
	image.ZIndex = 5
	return image
end

-- Botão com profundidade. Retorna (holder, área de clique, face).
function Style.button(name: string, t: Theme, text: string): (Frame, TextButton, Frame)
	local holder, face = Style.panel(name, t, 14)
	local label = Style.label("Text", text)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(0.86, 0.6)
	label.Parent = face

	local hit = Instance.new("TextButton")
	hit.Name = "Hit"
	hit.Text = ""
	hit.BackgroundTransparency = 1
	hit.Size = UDim2.fromScale(1, 1)
	hit.ZIndex = 8
	hit.Parent = holder

	hit.MouseButton1Down:Connect(function()
		face.Position = UDim2.fromOffset(0, 4)
	end)
	local function release()
		face.Position = UDim2.fromOffset(0, 0)
	end
	hit.MouseButton1Up:Connect(release)
	hit.MouseLeave:Connect(release)
	return holder, hit, face
end

-- Troca as cores de um painel/botão já criado (ex.: botão desativado fica cinza).
function Style.recolor(face: Frame, t: Theme)
	local gradient = face:FindFirstChildOfClass("UIGradient")
	if gradient then
		gradient.Color = ColorSequence.new(t.Top, t.Bottom)
	end
	local stroke = face:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = t.Outline
	end
end

-- Botão-ícone quadrado (coluna de atalhos): emoji grande + nome embaixo.
function Style.iconButton(name: string, t: Theme, icon: string, text: string): (Frame, TextButton)
	local holder, hit, face = Style.button(name, t, "")
	local iconLabel = Style.glyph("Icon", icon)
	iconLabel.AnchorPoint = Vector2.new(0.5, 0)
	iconLabel.Position = UDim2.new(0.5, 0, 0, 6)
	iconLabel.Size = UDim2.new(1, -16, 0.5, 0)
	iconLabel.Parent = face
	local caption = Style.label("Caption", text)
	caption.AnchorPoint = Vector2.new(0.5, 1)
	caption.Position = UDim2.new(0.5, 0, 1, -4)
	caption.Size = UDim2.new(1, -6, 0.34, 0) -- alto o bastante para a fonte mínima no celular
	caption.Parent = face
	return holder, hit
end

-- Faixa de grama em blocos (duas cores alternadas) na base de um cabeçalho: o "chão" da ilha dos mapas.
-- Fica dentro da face (não ocupa espaço do conteúdo) e afastada dos cantos arredondados.
function Style.grassLip(face: Frame)
	local lip = PaletteConfig.GrassLip
	local strip = Instance.new("Frame")
	strip.Name = "GrassLip"
	strip.BackgroundTransparency = 1
	strip.AnchorPoint = Vector2.new(0.5, 1)
	strip.Position = UDim2.fromScale(0.5, 1)
	strip.Size = UDim2.new(1, -28, 0, lip.Height)
	strip.ZIndex = 3
	local light, dark = rgb(lip.Light), rgb(lip.Dark)
	for i = 0, lip.Blocks - 1 do
		local block = Instance.new("Frame")
		block.BorderSizePixel = 0
		block.BackgroundColor3 = if i % 2 == 0 then light else dark
		block.Position = UDim2.fromScale(i / lip.Blocks, 0)
		block.Size = UDim2.fromScale(1 / lip.Blocks, 1)
		block.ZIndex = 3
		block.Parent = strip
	end
	strip.Parent = face
end

-- Janela: corpo claro + faixa de cabeçalho colorida com título à esquerda e X vermelho à direita.
-- Retorna (holder, corpo para o conteúdo, botão X, título).
function Style.window(
	name: string,
	headerTheme: Theme,
	title: string,
	width: number,
	height: number,
	headerH: number,
	closeSize: number
): (Frame, Frame, TextButton, TextLabel)
	local holder, body = Style.panel(name, Style.Themes.Paper, 26)
	holder.Size = UDim2.fromOffset(width, height)
	local header, headerFace = Style.panel("Header", headerTheme, 26)
	header.Size = UDim2.new(1, 0, 0, headerH)
	header.ZIndex = 4
	header.Parent = body
	Style.grassLip(headerFace)
	local titleLabel = Style.label("Title", title)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.AnchorPoint = Vector2.new(0, 0.5)
	titleLabel.Position = UDim2.new(0, 28, 0.5, 0)
	titleLabel.Size = UDim2.fromScale(0.6, 0.6)
	titleLabel.Parent = headerFace
	local closeHolder, closeHit = Style.button("Close", Style.Themes.Red, "X")
	closeHolder.AnchorPoint = Vector2.new(1, 0.5)
	closeHolder.Position = UDim2.new(1, -2, 0.5, -2)
	closeHolder.Size = UDim2.fromOffset(closeSize, closeSize)
	closeHolder.Parent = headerFace
	return holder, body, closeHit, titleLabel
end

return Style
