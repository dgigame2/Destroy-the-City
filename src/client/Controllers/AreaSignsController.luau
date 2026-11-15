--!strict
-- Sinalização das áreas da cidade (só na run):
--   * uma placa grande flutuando no meio de cada área: "AREA 2 · LAKESIDE" e o estado dela
--     (🔒 bloqueada: qual área limpar antes / ▶ área atual / ✔ limpa);
--   * encostou (o corpo, não o alcance) numa barreira de uma área bloqueada: aviso
--     "NEED TO CLEAN <área> FIRST" com feedback (som + tremor + 🔒).
-- Os pontos das placas vêm do servidor (City/ZoneLabels, MapService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local UiConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.UiConfig)

local Feedback = require(script.Parent.Parent.Feedback)
local InterfaceController = require(script.Parent.InterfaceController)

local localPlayer = Players.LocalPlayer

local AreaSignsController = {}

local SIGN = UiConfig.AreaSign
local GLOW = UiConfig.BarrierGlow
local glowFolder = Instance.new("Folder")
glowFolder.Name = "AreaBorder"
local glowZone = 0 -- zona cuja barreira está brilhando
local glowCount = 0 -- quantas barreiras dela já tinham chegado (a cidade chega aos poucos no cliente)
local signs: { [number]: { Gui: BillboardGui, Face: Frame, Title: TextLabel, State: TextLabel, Gradient: UIGradient } } =
	{}
local names: { [number]: string } = {}
local lastWarning = 0

local THEMES = {
	Locked = { Top = Color3.fromRGB(255, 120, 130), Bottom = Color3.fromRGB(214, 50, 70) },
	Current = { Top = Color3.fromRGB(130, 236, 120), Bottom = Color3.fromRGB(40, 170, 70) },
	Cleared = { Top = Color3.fromRGB(190, 196, 214), Bottom = Color3.fromRGB(120, 128, 150) },
}

local function city(): Instance?
	return Workspace:FindFirstChild("City")
end

local function openZone(): number
	return (ReplicatedStorage:GetAttribute("RunZone") :: number?) or 1
end

local function label(name: string, parent: Instance, y: number, h: number, color: Color3): TextLabel
	local text = Instance.new("TextLabel")
	text.Name = name
	text.BackgroundTransparency = 1
	text.Position = UDim2.fromScale(0.04, y)
	text.Size = UDim2.fromScale(0.92, h)
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = color
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(11, 18, 48)
	stroke.Parent = text
	text.Parent = parent
	return text
end

-- Placa em estilo Depth Stack: sombra azulada, face com gradiente, contorno uniforme.
local function makeSign(point: BasePart, zone: number)
	local gui = Instance.new("BillboardGui")
	gui.Name = "AreaSign"
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = SIGN.MaxDistance
	gui.StudsOffsetWorldSpace = Vector3.new(0, SIGN.Height, 0)
	gui.Adornee = point
	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.BackgroundColor3 = Color3.fromRGB(20, 30, 80)
	shadow.BackgroundTransparency = 0.4
	shadow.Position = UDim2.fromScale(0, 0.08)
	shadow.Size = UDim2.fromScale(1, 0.92)
	local shadowCorner = Instance.new("UICorner")
	shadowCorner.CornerRadius = UDim.new(0.25, 0)
	shadowCorner.Parent = shadow
	shadow.Parent = gui
	local face = Instance.new("Frame")
	face.Name = "Face"
	face.BackgroundColor3 = Color3.new(1, 1, 1)
	face.Size = UDim2.fromScale(1, 0.92)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.25, 0)
	corner.Parent = face
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(11, 18, 48)
	stroke.Parent = face
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Parent = face
	face.Parent = gui
	local title = label("Title", face, 0.06, 0.5, Color3.new(1, 1, 1))
	local state = label("State", face, 0.56, 0.36, Color3.fromRGB(255, 240, 180))
	gui.Parent = point
	signs[zone] = { Gui = gui, Face = face, Title = title, State = state, Gradient = gradient }
end

-- Borda da área atual: a barreira da próxima área (open + 1) ganha uma parede de luz baixa e uma linha forte
-- no topo, do seu tamanho. As outras áreas fechadas não brilham.
local function updateGlow()
	local zone = openZone() + 1
	local barriers = city() and (city() :: Instance):FindFirstChild("Barriers")
	local folder = barriers and barriers:FindFirstChild("Zone" .. zone)
	local fields = {}
	if folder then
		for _, field in folder:GetChildren() do
			if field:IsA("BasePart") and field.Name == "Field" then
				table.insert(fields, field)
			end
		end
	end
	if zone ~= glowZone or #fields ~= glowCount then
		glowFolder:ClearAllChildren()
		glowZone, glowCount = zone, #fields
		for _, field in fields do
			for _, name in { "Wall", "Line" } do
				local part = Instance.new("Part")
				part.Name = name
				part.Anchored = true
				part.CanCollide = false
				part.CanQuery = false
				part.CanTouch = false
				part.CastShadow = false
				part.Material = Enum.Material.Neon
				part.Color = Color3.fromRGB(GLOW.Color[1], GLOW.Color[2], GLOW.Color[3])
				part.Transparency = if name == "Wall" then GLOW.Transparency else 0
				part:SetAttribute("SourceSize", field.Size)
				part:SetAttribute("SourceBottom", field.Position - Vector3.new(0, field.Size.Y / 2, 0))
				part.Parent = glowFolder
			end
		end
	end
	local scale = math.max((localPlayer:GetAttribute("Scale") :: number?) or 1, 1)
	for _, part in glowFolder:GetChildren() do
		local p = part :: BasePart
		local size = p:GetAttribute("SourceSize") :: Vector3
		local bottom = p:GetAttribute("SourceBottom") :: Vector3
		-- a luz começa em cima do campo de força (as duas no mesmo lugar ficavam piscando ao mexer a câmera)
		bottom += Vector3.new(0, size.Y, 0)
		local height = math.max(GLOW.HeightPerScale * scale - size.Y, 1)
		-- mesma base da barreira (que já fica em cima do chão e das faixas): nada entra na rua
		local sx, sz = size.X, size.Z
		if p.Name == "Wall" then
			p.Size = Vector3.new(sx, height, sz)
			p.Position = bottom + Vector3.new(0, height / 2, 0)
		else
			local lineH = GLOW.TopLine * scale
			p.Size = Vector3.new(sx, lineH, sz)
			p.Position = bottom + Vector3.new(0, height + lineH / 2, 0)
		end
	end
end

local function refresh()
	local open = openZone()
	local scale = (localPlayer:GetAttribute("Scale") :: number?) or 1
	local grow = math.max(1, scale) ^ SIGN.GrowExponent
	local camera = Workspace.CurrentCamera
	local screen = if camera then camera.ViewportSize.Y / 720 else 1
	local pixelW = SIGN.PixelWidth * math.clamp(screen, SIGN.MinScreenScale, 1.2)
	for zone, sign in signs do
		local name = names[zone] or ""
		sign.Title.Text = `AREA {zone} · {name}`
		local theme
		if zone > open then
			theme = THEMES.Locked
			sign.State.Text = `🔒 CLEAN {names[zone - 1] or "THE AREA BEFORE"} FIRST`
		elseif zone == open then
			theme = THEMES.Current
			sign.State.Text = "▶ YOU ARE HERE"
		else
			theme = THEMES.Cleared
			sign.State.Text = "✔ CLEANED"
		end
		sign.Gradient.Color = ColorSequence.new(theme.Top, theme.Bottom)
		-- tamanho fixo na tela (não vira um painel gigante quando a câmera chega perto)
		sign.Gui.Size = UDim2.fromOffset(pixelW, pixelW * SIGN.Aspect)
		sign.Gui.StudsOffsetWorldSpace = Vector3.new(0, SIGN.Height * grow, 0)
	end
end

local function scan()
	local folder = city() and (city() :: Instance):FindFirstChild("ZoneLabels")
	if folder == nil then
		return
	end
	local added = false
	for _, point in folder:GetChildren() do
		local zone = point:GetAttribute("Zone") :: number?
		if point:IsA("BasePart") and zone and signs[zone] == nil then
			names[zone] = (point:GetAttribute("ZoneName") :: string?) or ""
			makeSign(point, zone)
			added = true
		end
	end
	if added then
		refresh()
	end
end

-- Encostou numa barreira de área bloqueada?
local params = OverlapParams.new()
params.FilterType = Enum.RaycastFilterType.Include
local function checkBarrier()
	local barriers = city() and (city() :: Instance):FindFirstChild("Barriers")
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if barriers == nil or root == nil or os.clock() - lastWarning < SIGN.WarningCooldown then
		return
	end
	params.FilterDescendantsInstances = { barriers }
	-- só o corpo encostando (o tronco do personagem com uma folga pequena), não o alcance de comer
	local body = (root :: BasePart).Size
	local box = Vector3.new(body.X + SIGN.TouchPadding * 2, body.Y * 3, body.Z + SIGN.TouchPadding * 2)
	for _, part in Workspace:GetPartBoundsInBox((root :: BasePart).CFrame, box, params) do
		local folder = part.Parent
		local zone = folder and tonumber(string.match(folder.Name, "^Zone(%d+)$"))
		if zone and zone > openZone() then
			lastWarning = os.clock()
			local need = names[zone - 1] or "THE AREA BEFORE"
			InterfaceController.toast(`NEED TO CLEAN {need} FIRST`, Color3.fromRGB(255, 120, 120))
			Feedback.play("Fail", { Gui = InterfaceController.refs().Toast, Text = "🔒" })
			return
		end
	end
end

function AreaSignsController.init()
	glowFolder.Parent = Workspace
	Workspace.ChildAdded:Connect(function(child)
		if child.Name == "City" then
			task.wait(1)
			scan()
		end
	end)
	ReplicatedStorage:GetAttributeChangedSignal("RunZone"):Connect(refresh)
	localPlayer:GetAttributeChangedSignal("Scale"):Connect(refresh)
	task.spawn(function()
		while true do
			-- a cidade chega aos poucos: placas e barreiras que chegaram depois entram aqui
			scan()
			updateGlow()
			checkBarrier()
			task.wait(0.2)
		end
	end)
end

return AreaSignsController
