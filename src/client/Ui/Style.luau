--!strict
-- Padrão visual "Depth Stack" do goat: sombra azulada, gradiente, elevação (lift) e contorno uniforme.
-- Inspirado nas referências de UI: janelas claras com cabeçalho colorido e X vermelho, cards por raridade
-- com listras diagonais, etiquetas de preço verdes, coluna de botões-ícone.

local Style = {}

Style.Font = Enum.Font.FredokaOne
Style.TextStroke = Color3.fromRGB(11, 18, 48)
Style.Shadow = Color3.fromRGB(10, 20, 64)
Style.Robux = utf8.char(0xE002) -- ícone de Robux das fontes do Roblox

export type Theme = { Top: Color3, Bottom: Color3, Outline: Color3 }

local function theme(top: { number }, bottom: { number }, outline: { number }): Theme
	return {
		Top = Color3.fromRGB(top[1], top[2], top[3]),
		Bottom = Color3.fromRGB(bottom[1], bottom[2], bottom[3]),
		Outline = Color3.fromRGB(outline[1], outline[2], outline[3]),
	}
end

Style.Themes = {
	Blue = theme({ 58, 111, 224 }, { 29, 60, 154 }, { 11, 18, 48 }),
	LightBlue = theme({ 111, 180, 255 }, { 45, 106, 214 }, { 11, 31, 87 }),
	Green = theme({ 98, 227, 122 }, { 47, 174, 74 }, { 12, 58, 24 }),
	Yellow = theme({ 255, 216, 77 }, { 242, 165, 30 }, { 74, 42, 0 }),
	Red = theme({ 255, 107, 107 }, { 201, 42, 42 }, { 74, 11, 11 }),
	Purple = theme({ 194, 123, 255 }, { 123, 53, 214 }, { 42, 11, 87 }),
	Pink = theme({ 255, 122, 200 }, { 214, 51, 154 }, { 74, 11, 51 }),
	Orange = theme({ 255, 190, 80 }, { 240, 120, 30 }, { 74, 30, 0 }),
	Gray = theme({ 154, 160, 184 }, { 106, 112, 136 }, { 30, 32, 48 }),
	Paper = theme({ 246, 248, 255 }, { 220, 228, 255 }, { 11, 18, 48 }),
	-- raridades
	Common = theme({ 206, 210, 220 }, { 150, 156, 172 }, { 30, 32, 48 }),
	Rare = theme({ 111, 180, 255 }, { 45, 106, 214 }, { 11, 31, 87 }),
	Epic = theme({ 194, 123, 255 }, { 123, 53, 214 }, { 42, 11, 87 }),
	Legendary = theme({ 255, 216, 77 }, { 242, 150, 30 }, { 74, 42, 0 }),
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
	shadow.BackgroundTransparency = 0.55
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
	lift.BackgroundTransparency = 0.82
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
	local iconLabel = Style.label("Icon", icon)
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
