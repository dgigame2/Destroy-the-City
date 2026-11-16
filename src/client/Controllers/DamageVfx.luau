--!strict
-- Vida visível das construções no cliente (DamageConfig). Só visual: o servidor já decidiu a vida, quais
-- blocos caíram (já invisíveis e sem colisão) e onde ficam os escombros.
--   * Destroços: cada bloco que caiu (BuildingCracked) vira uma cópia que cai até o chão girando e some.
--     Celular: peças ancoradas e tween (sem física), no máximo DamageConfig.MaxDebris ao mesmo tempo.
--   * Barra de vida: em cima da construção atingida (BuildingDamaged), lê o atributo "Hp" do modelo e some
--     depois de HpBar.Seconds sem dano. No máximo HpBar.Max barras (as mais antigas saem).
--     Visual Depth Stack: sombra azulada, contorno uniforme, gradiente e leve elevação.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DamageConfig = require(Shared.Config.DamageConfig)
local DamageStages = require(Shared.Logic.DamageStages)
local Remotes = require(Shared.Remotes)

local DamageVfx = {}

local cfg = DamageConfig
local folder = Instance.new("Folder")
folder.Name = "DamageVfx"

local debris = 0
local random = Random.new()

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function tween(instance: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?)
	local t = TweenService:Create(
		instance,
		TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		goal
	)
	t:Play()
	return t
end

-- Destroços -------------------------------------------------------------------------------------------

local function onCracked(model: Model?, parts: { BasePart }?)
	if model == nil or parts == nil or model.Parent == nil then
		return
	end
	local pivot = model:GetPivot().Position
	for _, source in parts do
		if debris >= cfg.MaxDebris then
			return
		end
		if typeof(source) ~= "Instance" or not source:IsA("BasePart") then
			continue
		end
		debris += 1
		local copy = source:Clone()
		copy:ClearAllChildren()
		copy.Transparency = (source:GetAttribute("Alpha") :: number?) or 0
		copy.Anchored = true
		copy.CanCollide = false
		copy.CanQuery = false
		copy.CanTouch = false
		copy.CastShadow = false
		copy.Parent = folder
		-- cai para fora da construção, até o chão (base do modelo), girando um pouco
		local from = source.Position
		local out = Vector3.new(from.X - pivot.X, 0, from.Z - pivot.Z)
		out = if out.Magnitude > 1e-3 then out.Unit else Vector3.xAxis
		local landing = Vector3.new(from.X, pivot.Y + math.min(copy.Size.Y, 1) / 2, from.Z)
			+ out * cfg.DebrisSpread * random:NextNumber(0.5, 1)
		local spin = math.rad(cfg.DebrisSpin)
		local goal = CFrame.new(landing)
			* CFrame.Angles(
				random:NextNumber(-spin, spin),
				random:NextNumber(-spin, spin),
				random:NextNumber(-spin, spin)
			)
		local fall = cfg.DebrisSeconds * 0.55
		tween(copy, fall, { CFrame = goal })
		task.delay(fall, function()
			tween(copy, cfg.DebrisSeconds - fall, { Transparency = 1, Size = copy.Size * 0.6 }, Enum.EasingStyle.Sine)
		end)
		task.delay(cfg.DebrisSeconds, function()
			copy:Destroy()
			debris -= 1
		end)
	end
end

-- Barra de vida ---------------------------------------------------------------------------------------

type Bar = { Gui: BillboardGui, Fill: Frame, Until: number, Model: Model }
local bars: { Bar } = {}

local function barColor(fraction: number): Color3
	if fraction > 0.6 then
		return rgb(cfg.HpBar.Full)
	elseif fraction > 0.3 then
		return rgb(cfg.HpBar.Mid)
	end
	return rgb(cfg.HpBar.Low)
end

local function makeBar(model: Model): Bar?
	local adornee = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	if adornee == nil then
		return nil
	end
	local box, size = model:GetBoundingBox()
	local top = box.Position.Y + size.Y / 2
	local w, h = cfg.HpBar.Width, cfg.HpBar.Height

	local gui = Instance.new("BillboardGui")
	gui.Name = "HpBar"
	gui.Adornee = adornee
	gui.Size = UDim2.fromOffset(w + 4, h + 6)
	gui.StudsOffsetWorldSpace = Vector3.new(0, top - adornee.Position.Y + cfg.HpBar.Above, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 300
	gui.ResetOnSpawn = false

	-- Shadow: sombra levemente azulada, deslocada para baixo
	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.AnchorPoint = Vector2.new(0.5, 0)
	shadow.Position = UDim2.new(0.5, 0, 0, 4)
	shadow.Size = UDim2.fromOffset(w, h)
	shadow.BackgroundColor3 = Color3.fromRGB(20, 30, 70)
	shadow.BackgroundTransparency = 0.55
	shadow.BorderSizePixel = 0
	Instance.new("UICorner", shadow).CornerRadius = UDim.new(0, 4)
	shadow.Parent = gui

	-- Lift: a barra fica 2 px acima da sombra; Outline: contorno uniforme de 2 px
	local back = Instance.new("Frame")
	back.Name = "Back"
	back.AnchorPoint = Vector2.new(0.5, 0)
	back.Position = UDim2.new(0.5, 0, 0, 1)
	back.Size = UDim2.fromOffset(w, h)
	back.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
	back.BorderSizePixel = 0
	Instance.new("UICorner", back).CornerRadius = UDim.new(0, 4)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(15, 15, 22)
	stroke.Parent = back
	back.Parent = gui

	-- Gradient: brilho em cima, mais escuro embaixo
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BorderSizePixel = 0
	fill.BackgroundColor3 = barColor(1)
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 4)
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170))
	gradient.Parent = fill
	fill.Parent = back

	gui.Parent = folder
	return { Gui = gui, Fill = fill, Until = 0, Model = model }
end

local function removeBar(index: number)
	local bar = table.remove(bars, index)
	if bar then
		bar.Gui:Destroy()
	end
end

local function showBar(model: Model)
	local fraction = (model:GetAttribute("Hp") :: number?) or 1
	if fraction >= 1 then
		return
	end
	local bar: Bar? = nil
	for _, existing in bars do
		if existing.Model == model then
			bar = existing
			break
		end
	end
	if bar == nil then
		if #bars >= cfg.HpBar.Max then
			removeBar(1) -- a mais antiga sai
		end
		bar = makeBar(model)
		if bar == nil then
			return
		end
		table.insert(bars, bar :: Bar)
	end
	local b = bar :: Bar
	b.Until = os.clock() + cfg.HpBar.Seconds
	local shown = DamageStages.quantize(fraction, cfg.HpBar.Step)
	TweenService:Create(b.Fill, TweenInfo.new(0.15), { Size = UDim2.fromScale(shown, 1) }):Play()
	b.Fill.BackgroundColor3 = barColor(shown)
end

local function onDamaged(models: { Model }?, _origin: Vector3?)
	if models == nil then
		return
	end
	for _, model in models do
		if typeof(model) == "Instance" and model:IsA("Model") and model.Parent then
			showBar(model)
		end
	end
end

-- some quando o tempo acaba ou quando a construção caiu
local function sweep()
	while true do
		task.wait(0.5)
		local now = os.clock()
		for index = #bars, 1, -1 do
			local bar = bars[index]
			if bar.Model.Parent == nil or now > bar.Until then
				removeBar(index)
			end
		end
	end
end

function DamageVfx.init()
	folder.Parent = Workspace
	Remotes.event(Remotes.Names.Events.BuildingCracked).OnClientEvent:Connect(onCracked)
	Remotes.event(Remotes.Names.Events.BuildingDamaged).OnClientEvent:Connect(onDamaged)
	task.spawn(sweep)
end

return DamageVfx
