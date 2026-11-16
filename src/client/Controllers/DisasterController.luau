--!strict
-- Barra de desastres e mira (modo desastres). O cliente só PEDE; o servidor (DisasterService) decide tudo.
--   PC: teclas 1-2-3 (ou clique no botão) escolhem o desastre; o círculo segue o mouse; clique esquerdo lança.
--       Clicar de novo no mesmo botão (ou botão direito / Esc) cancela.
--   Toque: toque no botão escolhe; o próximo toque na cidade lança ali. Analógico e câmera seguem normais.
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

local localPlayer = Players.LocalPlayer

local DisasterController = {}

local KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three }
local THEMES = { Style.Themes.Orange, Style.Themes.LightBlue, Style.Themes.Yellow }
local AIM_OK = Color3.fromRGB(255, 227, 107)
local AIM_FAR = Color3.fromRGB(255, 110, 110)

type Slot = { Disaster: DisasterConfig.Disaster, Holder: Frame, Face: Frame, Cooldown: Frame, Timer: TextLabel }

local slots: { Slot } = {}
local selected: number? = nil
local lastUse: { [string]: number } = {}
local gui: ScreenGui
local aimRing: Part
local aimLine: Part

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
	local ignore: { Instance } = { aimRing, aimLine }
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
	-- barreiras das áreas e escombros também não são chão
	for _, name in { "Barriers", "Ruins" } do
		local extra = city and city:FindFirstChild(name)
		if extra then
			table.insert(ignore, extra)
		end
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
	aimRing.Transparency = 1
	aimLine.Transparency = 1
end

local function choose(index: number?)
	if index ~= nil and selected == index then
		index = nil -- tocar de novo cancela
	end
	selected = index
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

local function showAim(d: DisasterConfig.Disaster, point: Vector3)
	local target, far = clampedAim(d, point)
	local r = aimRadius(d, power())
	aimRing.Size = Vector3.new(0.2, r * 2, r * 2)
	aimRing.CFrame = CFrame.new(target + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90))
	aimRing.Color = if far then AIM_FAR else AIM_OK
	aimRing.Transparency = 0.55
	-- tornado: linha mostrando para onde ele vai andar
	local character = root()
	if d.Speed and character then
		local from = Vector3.new(character.Position.X, target.Y + 0.3, character.Position.Z)
		local to = target + Vector3.new(0, 0.3, 0)
		local length = (to - from).Magnitude
		if length > 1 then
			local dir = (to - from).Unit
			local travel = Disasters.speed(d, power(), DisasterConfig) * d.Duration
			aimLine.Size = Vector3.new(r * 0.6, 0.2, travel)
			aimLine.CFrame = CFrame.lookAt(to + dir * travel / 2, to + dir * travel)
			aimLine.Color = aimRing.Color
			aimLine.Transparency = 0.6
		end
	else
		aimLine.Transparency = 1
	end
end

local function cast(point: Vector3)
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
	Remotes.event(Remotes.Names.Events.UseDisaster):FireServer(d.Id, target)
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

local function layoutSlots()
	local size = gui.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then
		return
	end
	local layout = UiLayout.place(size.X, size.Y, UiConfig)
	for i, slot in slots do
		local r = layout.Disasters[i]
		slot.Holder.Position = UDim2.fromOffset(r.X0, r.Y0)
		slot.Holder.Size = UDim2.fromOffset(r.X1 - r.X0, r.Y1 - r.Y0)
	end
end

local function makeAimPart(name: string, shape: Enum.PartType): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Transparency = 1
	part.Parent = Workspace.CurrentCamera
	return part
end

function DisasterController.init()
	gui = Instance.new("ScreenGui")
	gui.Name = "Disasters"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.DisplayOrder = 5
	gui.Parent = localPlayer:WaitForChild("PlayerGui")
	aimRing = makeAimPart("DisasterAim", Enum.PartType.Cylinder)
	aimLine = makeAimPart("DisasterPath", Enum.PartType.Block)

	for i, d in DisasterConfig.List do
		local holder, hit = Style.iconButton(d.Id, THEMES[i], d.Icon, d.Name)
		holder.AnchorPoint = Vector2.zero
		holder.Parent = gui
		local face = holder:FindFirstChild("Face", true) :: Frame
		-- cortina escura do cooldown (desce de cima) + segundos restantes
		local cooldown = Instance.new("Frame")
		cooldown.Name = "Cooldown"
		cooldown.BackgroundColor3 = Color3.fromRGB(11, 18, 48)
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
		if input.KeyCode == Enum.KeyCode.Escape or input.UserInputType == Enum.UserInputType.MouseButton2 then
			choose(nil)
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 and selected then
			local point = groundAt(UserInputService:GetMouseLocation(), true)
			if point then
				cast(point)
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
			cast(point)
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
