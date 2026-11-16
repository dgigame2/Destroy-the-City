--!strict
-- Vida visível das construções no cliente (DamageConfig). Só visual: o servidor já decidiu a vida, quais
-- blocos caíram (já invisíveis e sem colisão) e quando a construção desaba em escombros.
--   * Destroços: cada bloco que caiu (BuildingCracked) vira uma cópia que cai até o chão girando e some.
--     Celular: peças ancoradas e tween (sem física), no máximo DamageConfig.MaxDebris ao mesmo tempo.
--   * Barra de vida: em cima da construção atingida (BuildingDamaged), lê o atributo "Hp" do modelo e some
--     depois de HpBar.Seconds sem dano. No máximo HpBar.Max barras (as mais antigas saem).
--     Visual Depth Stack: sombra azulada, contorno uniforme, gradiente e leve elevação.
--   * Desabar (BuildingCollapsed): os blocos afundam girando, os escombros sobem do chão, poeira.
--   * Sumir (DamageVfx.vanish, chamado pelo EatEffects): os escombros afundam no chão com poeira.

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

-- Poeira, desabar e sumir -----------------------------------------------------------------------------

local function ensureFolder()
	if folder.Parent == nil then
		folder.Parent = Workspace
	end
end

local function quiet(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
end

-- Nuvens de poeira em volta de `center` (bolas que crescem, sobem e somem em menos de 1 s).
local function dust(center: Vector3, width: number)
	ensureFolder()
	local d = cfg.Dust
	for i = 1, d.Puffs do
		local angle = (i / d.Puffs) * math.pi * 2 + random:NextNumber(0, 0.6)
		local r = width * 0.35 * random:NextNumber(0.3, 1)
		local size = math.max(width * d.Size * random:NextNumber(0.4, 0.8), 2)
		local puff = Instance.new("Part")
		puff.Shape = Enum.PartType.Ball
		quiet(puff)
		puff.Material = Enum.Material.SmoothPlastic
		puff.Color = rgb(d.Color)
		puff.Transparency = 0.35
		puff.Size = Vector3.one * size * 0.4
		puff.CFrame = CFrame.new(center + Vector3.new(math.cos(angle) * r, size * 0.2, math.sin(angle) * r))
		puff.Parent = folder
		local drift = Vector3.new(math.cos(angle) * r * 0.6, size * 0.5, math.sin(angle) * r * 0.6)
		TweenService:Create(puff, TweenInfo.new(d.Seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.one * size,
			Transparency = 1,
			CFrame = puff.CFrame + drift,
		}):Play()
		task.delay(d.Seconds, function()
			puff:Destroy()
		end)
	end
end

-- Centro no chão e maior lado da construção (para o tamanho da poeira).
local function groundCenter(model: Model): (Vector3, number)
	local box, size = model:GetBoundingBox()
	local ground = model:GetPivot().Position.Y
	return Vector3.new(box.Position.X, ground, box.Position.Z), math.max(size.X, size.Z)
end

-- Desabou (BuildingCollapsed): os blocos afundam girando e somem, os escombros sobem do chão, poeira.
local function onCollapsed(model: Model?, parts: { BasePart }?)
	if model == nil or parts == nil or model.Parent == nil then
		return
	end
	ensureFolder()
	local c = cfg.Collapse
	local center, width = groundCenter(model)
	local ground = center.Y
	local list = {}
	local top = ground
	for _, part in parts do
		if typeof(part) == "Instance" and part:IsA("BasePart") then
			table.insert(list, part)
			top = math.max(top, part.Position.Y)
		end
	end
	table.sort(list, function(a, b)
		return a.Size.Magnitude > b.Size.Magnitude
	end)
	local spin = math.rad(c.Spin)
	for index = 1, math.min(#list, c.MaxParts) do
		local source = list[index]
		local copy = source:Clone()
		copy:ClearAllChildren()
		copy.Transparency = (source:GetAttribute("Alpha") :: number?) or 0
		quiet(copy)
		copy.Parent = folder
		local height = math.max(source.Position.Y - ground, 0)
		local drop = height + source.Size.Y * 0.5
		local goal = (source.CFrame - Vector3.new(0, drop, 0))
			* CFrame.Angles(random:NextNumber(-spin, spin), 0, random:NextNumber(-spin, spin))
		-- a base cede primeiro e o resto vem atrás (os de cima um pouco depois)
		local wait = 0.15 * height / math.max(top - ground, 1)
		task.delay(wait, function()
			TweenService:Create(copy, TweenInfo.new(c.Seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				CFrame = goal,
				Size = copy.Size * 0.7,
				Transparency = 1,
			}):Play()
		end)
		task.delay(wait + c.Seconds + 0.05, function()
			copy:Destroy()
		end)
	end
	-- escombros (do servidor, dentro do modelo) nascem achatados no chão e sobem até o tamanho certo
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and child:GetAttribute("Rubble") then
			local final, size = child.CFrame, child.Size
			child.Size = Vector3.new(size.X, 0.05, size.Z)
			child.CFrame = final - Vector3.new(0, size.Y / 2 - 0.025, 0)
			TweenService:Create(
				child,
				TweenInfo.new(c.RubbleSeconds, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Size = size, CFrame = final }
			):Play()
		end
	end
	dust(center, width)
end

-- A construção caiu de vez. Se ela tinha desabado, os escombros afundam no chão com poeira e somem.
-- Devolve false se ela não tinha escombros (o EatEffects faz a explosão normal).
function DamageVfx.vanish(model: Model): boolean
	if not model:GetAttribute("Collapsed") then
		return false
	end
	ensureFolder()
	local center, width = groundCenter(model)
	local seconds = cfg.Vanish.Seconds
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and child:GetAttribute("Rubble") then
			local copy = child:Clone()
			quiet(copy)
			copy.Parent = folder
			TweenService:Create(copy, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				CFrame = copy.CFrame - Vector3.new(0, copy.Size.Y, 0),
				Size = Vector3.new(copy.Size.X * 0.8, 0.05, copy.Size.Z * 0.8),
				Transparency = 1,
			}):Play()
			task.delay(seconds + 0.05, function()
				copy:Destroy()
			end)
		end
	end
	dust(center, width)
	return true
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
	Remotes.event(Remotes.Names.Events.BuildingCollapsed).OnClientEvent:Connect(onCollapsed)
	Remotes.event(Remotes.Names.Events.BuildingDamaged).OnClientEvent:Connect(onDamaged)
	task.spawn(sweep)
end

return DamageVfx
