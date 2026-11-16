--!strict
-- Barra de desastres e mira (modo desastres). O cliente só PEDE; o servidor (DisasterService) decide tudo.
--   PC: teclas 1-2-3 (ou clique no botão) escolhem o desastre; o círculo tracejado segue o mouse; clique
--       esquerdo lança. Clicar de novo no mesmo botão (ou Esc) cancela. O botão direito NÃO cancela (é a câmera).
--   Tornado (dois cliques): o 1º fixa o círculo no chão; o 2º escolhe para onde ele anda (setas mostram o
--       caminho). Esc com o círculo fixo solta o círculo.
--   Toque: toque no botão escolhe; o próximo toque na cidade lança ali (tornado: dois toques). Analógico e
--       câmera seguem normais.
-- Posições da barra: Logic/UiLayout (Disasters), a mesma conta testada em todos os aparelhos.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DisasterConfig = require(Shared.Config.DisasterConfig)
local UiConfig = require(Shared.Config.UiConfig)
local UiLayout = require(Shared.Logic.UiLayout)
local Disasters = require(Shared.Logic.Disasters)
local Mastery = require(Shared.Logic.Mastery)
local MasteryConfig = require(Shared.Config.MasteryConfig)
local Remotes = require(Shared.Remotes)
local HttpService = game:GetService("HttpService")

local Style = require(script.Parent.Parent.Ui.Style)
local Feedback = require(script.Parent.Parent.Feedback)
local AimVisual = require(script.Parent.AimVisual)

local localPlayer = Players.LocalPlayer

local DisasterController = {}

local KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three }
local THEMES = { Style.Themes.Orange, Style.Themes.LightBlue, Style.Themes.Yellow }
local AIM_OK = Style.Colors.Gold
local AIM_FAR = Style.Colors.Danger

type Slot = { Disaster: DisasterConfig.Disaster, Holder: Frame, Face: Frame, Cooldown: Frame, Timer: TextLabel }

local slots: { Slot } = {}
local selected: number? = nil
local lastUse: { [string]: number } = {}
local gui: ScreenGui
local anchor: Vector3? = nil -- tornado: círculo já fixado no chão (falta escolher a direção)

local function power(): number
	return (localPlayer:GetAttribute("Power") :: number?) or 1
end

local function root(): BasePart?
	local character = localPlayer.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Ponto do chão embaixo de uma posição da tela (ignora o próprio personagem e os efeitos).
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
-- viewport = coordenadas do mouse (GetMouseLocation); senão, coordenadas do toque (descontam a barra do topo)
local function groundAt(screen: Vector2, viewport: boolean): Vector3?
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return nil
	end
	local ray = if viewport
		then camera:ViewportPointToRay(screen.X, screen.Y)
		else camera:ScreenPointToRay(screen.X, screen.Y)
	-- a mira fica no CHÃO (passa através das construções): o círculo não flutua em cima dos telhados
	local ignore: { Instance } = { AimVisual.folder() }
	if localPlayer.Character then
		table.insert(ignore, localPlayer.Character :: Instance)
	end
	local city = Workspace:FindFirstChild("City")
	local buildings = city and city:FindFirstChild("Buildings")
	if buildings then
		table.insert(ignore, buildings)
	end
	for _, name in { "DisasterVfx", "DamageVfx" } do
		local effects = Workspace:FindFirstChild(name)
		if effects then
			table.insert(ignore, effects)
		end
	end
	-- barreiras das áreas também não são chão
	local barriers = city and city:FindFirstChild("Barriers")
	if barriers then
		table.insert(ignore, barriers)
	end
	-- peças invisíveis (paredes da costa, colisores) não são chão: passa através delas
	for _ = 1, 6 do
		rayParams.FilterDescendantsInstances = ignore
		local hit = Workspace:Raycast(ray.Origin, ray.Direction * 5000, rayParams)
		if hit == nil then
			break
		end
		if hit.Instance.Transparency < 0.95 then
			return hit.Position
		end
		table.insert(ignore, hit.Instance)
	end
	-- sem nada: plano do chão (y = 0)
	if ray.Direction.Y < -1e-3 then
		local t = -ray.Origin.Y / ray.Direction.Y
		return ray.Origin + ray.Direction * t
	end
	return nil
end

-- Nível do desastre (servidor publica no atributo "Mastery" do jogador). Decodifica só quando muda.
local levelCache: { raw: string?, levels: { [string]: number } } = { raw = nil, levels = {} }
local function levelOf(id: string): number
	local raw = localPlayer:GetAttribute("Mastery")
	if type(raw) ~= "string" then
		return 1
	end
	if raw ~= levelCache.raw then
		levelCache.raw = raw
		table.clear(levelCache.levels)
		local ok, list = pcall(HttpService.JSONDecode, HttpService, raw)
		if ok and type(list) == "table" then
			for _, entry in list do
				levelCache.levels[entry.Id] = entry.Level
			end
		end
	end
	return levelCache.levels[id] or 1
end

local function aimRadius(d: DisasterConfig.Disaster, p: number): number
	local size = Mastery.size(levelOf(d.Id), MasteryConfig)
	if d.Radius then
		return Disasters.radius(d, p, DisasterConfig) * size
	end
	return (d.Snap or 6) * p ^ DisasterConfig.RadiusExponent * size
end

local function hideAim()
	AimVisual.hide()
end

-- O desastre anda (tornado): mira em dois cliques.
local function isMoving(d: DisasterConfig.Disaster): boolean
	return d.Speed ~= nil
end

local function choose(index: number?)
	if index ~= nil and selected == index then
		index = nil -- tocar de novo cancela
	end
	selected = index
	anchor = nil
	for i, slot in slots do
		local stroke = slot.Face:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Thickness = if i == selected then 5 else 3
			stroke.Color = if i == selected then Color3.new(1, 1, 1) else THEMES[i].Outline
		end
	end
	if selected == nil then
		hideAim()
	end
end

-- Mira trazida para o alcance (o servidor faz a mesma conta; aqui é só para o círculo não mentir).
local function clampedAim(d: DisasterConfig.Disaster, point: Vector3): (Vector3, boolean)
	local r = root()
	if r == nil then
		return point, false
	end
	local range = Disasters.range(d, power(), DisasterConfig)
	local x, z = Disasters.clampTarget(r.Position.X, r.Position.Z, point.X, point.Z, range)
	local far = math.abs(x - point.X) > 0.5 or math.abs(z - point.Z) > 0.5
	return Vector3.new(x, point.Y, z), far
end

-- Mira no chão: círculo tracejado; tornado também mostra as setas do caminho.
-- Antes de fixar, o caminho sai do jogador para o mouse (prévia); depois de fixar, sai do círculo para o mouse.
local function showAim(d: DisasterConfig.Disaster, point: Vector3)
	local clock = os.clock()
	local r = aimRadius(d, power())
	local center, far
	if anchor then
		center, far = anchor :: Vector3, false
	else
		center, far = clampedAim(d, point)
	end
	local color = if far then AIM_FAR else AIM_OK
	AimVisual.ring(center, r, color, clock)
	if not isMoving(d) then
		AimVisual.hideArrows()
		return
	end
	local from: Vector3
	if anchor then
		from = anchor :: Vector3
	else
		local character = root()
		from = if character then Vector3.new(character.Position.X, center.Y, character.Position.Z) else center
	end
	local toward = if anchor then point else center
	local flat = Vector3.new(toward.X - from.X, 0, toward.Z - from.Z)
	if flat.Magnitude < 0.5 then
		AimVisual.hideArrows()
		return
	end
	local travel = Disasters.speed(d, power(), DisasterConfig) * d.Duration
	-- as setas saem da borda do círculo (sem fixar: na direção jogador -> círculo, como prévia)
	AimVisual.path(center, flat.Unit, travel, r, color, clock)
end

local function cast(point: Vector3, heading: Vector3?)
	local index = selected
	if index == nil then
		return
	end
	local slot = slots[index]
	local d = slot.Disaster
	local now = os.clock()
	if lastUse[d.Id] and now - lastUse[d.Id] < d.Cooldown then
		Feedback.play("Fail", { Gui = slot.Holder, Text = "⏳" })
		return
	end
	lastUse[d.Id] = now
	local target = clampedAim(d, point)
	anchor = nil
	Remotes.event(Remotes.Names.Events.UseDisaster):FireServer(d.Id, target, heading)
	Feedback.play("Cast", { Gui = slot.Holder, Text = d.Icon })
	-- toque: cada lançamento precisa escolher de novo (evita lançar sem querer ao mexer a câmera)
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		choose(nil)
	end
end

local function updateCooldowns()
	local now = os.clock()
	for _, slot in slots do
		local d = slot.Disaster
		local last = lastUse[d.Id]
		local left = if last then d.Cooldown - (now - last) else 0
		if left > 0 then
			slot.Cooldown.Visible = true
			slot.Cooldown.Size = UDim2.fromScale(1, math.clamp(left / d.Cooldown, 0, 1))
			slot.Timer.Visible = true
			slot.Timer.Text = string.format("%.1f", left)
		else
			slot.Cooldown.Visible = false
			slot.Timer.Visible = false
		end
	end
end

-- Clique/toque no chão com uma skill na mão. Tornado: 1º fixa o círculo, 2º lança na direção escolhida.
local function aimAt(point: Vector3)
	local index = selected
	if index == nil then
		return
	end
	local d = slots[index].Disaster
	if isMoving(d) and anchor == nil then
		local last = lastUse[d.Id]
		if last and os.clock() - last < d.Cooldown then
			Feedback.play("Fail", { Gui = slots[index].Holder, Text = "⏳" })
			return
		end
		anchor = clampedAim(d, point)
		return
	end
	if isMoving(d) and anchor then
		cast(anchor :: Vector3, point)
		return
	end
	cast(point)
end

local function layoutSlots()
	local size = gui.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then
		return
	end
	local layout = UiLayout.place(
		size.X,
		size.Y,
		UiConfig,
		UiLayout.isDesktop(UserInputService.TouchEnabled, UserInputService.KeyboardEnabled)
	)
	for i, slot in slots do
		local r = layout.Disasters[i]
		slot.Holder.Position = UDim2.fromOffset(r.X0, r.Y0)
		slot.Holder.Size = UDim2.fromOffset(r.X1 - r.X0, r.Y1 - r.Y0)
	end
end

function DisasterController.init()
	gui = Instance.new("ScreenGui")
	gui.Name = "Disasters"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.DisplayOrder = 5
	gui.Parent = localPlayer:WaitForChild("PlayerGui")
	AimVisual.init()

	for i, d in DisasterConfig.List do
		local holder, hit = Style.iconButton(d.Id, THEMES[i], d.Icon, d.Name)
		holder.AnchorPoint = Vector2.zero
		holder.Parent = gui
		local face = holder:FindFirstChild("Face", true) :: Frame
		-- cortina escura do cooldown (desce de cima) + segundos restantes
		local cooldown = Instance.new("Frame")
		cooldown.Name = "Cooldown"
		cooldown.BackgroundColor3 = Style.TextStroke
		cooldown.BackgroundTransparency = 0.35
		cooldown.BorderSizePixel = 0
		cooldown.Size = UDim2.fromScale(1, 0)
		cooldown.ZIndex = 6
		cooldown.Visible = false
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 14)
		corner.Parent = cooldown
		cooldown.Parent = face
		local timer = Style.label("Timer", "")
		timer.AnchorPoint = Vector2.new(0.5, 0.5)
		timer.Position = UDim2.fromScale(0.5, 0.42)
		timer.Size = UDim2.fromScale(0.7, 0.4)
		timer.ZIndex = 7
		timer.Visible = false
		timer.Parent = face
		-- tecla no canto (só PC)
		if UserInputService.KeyboardEnabled then
			local key = Style.label("Key", tostring(i))
			key.AnchorPoint = Vector2.new(0, 0)
			key.Position = UDim2.fromOffset(6, 4)
			key.Size = UDim2.fromScale(0.22, 0.26)
			key.ZIndex = 7
			key.Parent = face
		end
		hit.Activated:Connect(function()
			choose(i)
		end)
		slots[i] = { Disaster = d, Holder = holder, Face = face, Cooldown = cooldown, Timer = timer }
	end
	choose(nil)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutSlots)
	layoutSlots()

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		for i, key in KEYS do
			if input.KeyCode == key and slots[i] then
				choose(i)
				return
			end
		end
		if input.KeyCode == Enum.KeyCode.Escape then
			if anchor then
				anchor = nil -- tornado: solta o círculo, continua com a skill na mão
			else
				choose(nil)
			end
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 and selected then
			local point = groundAt(UserInputService:GetMouseLocation(), true)
			if point then
				aimAt(point)
			end
		end
	end)
	-- toque: lança no ponto tocado (o toque que move o analógico ou a câmera vem com processed = true)
	UserInputService.TouchTapInWorld:Connect(function(position, processed)
		if processed or selected == nil then
			return
		end
		local point = groundAt(position, false)
		if point then
			aimAt(point)
		end
	end)

	RunService.RenderStepped:Connect(function()
		updateCooldowns()
		local index = selected
		if index == nil then
			return
		end
		local d = slots[index].Disaster
		local screen = if UserInputService.MouseEnabled
			then UserInputService:GetMouseLocation()
			else Workspace.CurrentCamera.ViewportSize / 2
		local point = groundAt(screen, true)
		if point then
			showAim(d, point)
		else
			hideAim()
		end
	end)
end

return DisasterController
