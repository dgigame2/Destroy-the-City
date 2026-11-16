--!strict
-- Vida VISÍVEL das construções no servidor (DamageConfig). A vida em si fica no DisasterService
-- (Logic/StructureHealth); aqui o servidor decide o que todo mundo vê:
--   * atributo "Hp" no modelo (fração da vida em degraus de 5%) para a barra de vida do cliente;
--   * estágios de dano: os blocos que caem (Logic/DamageStages) ficam invisíveis e sem colisão, e o
--     servidor avisa os clientes (BuildingCracked) para eles soltarem os destroços;
--   * desabar: no último estágio a construção some e no lugar dela ficam escombros (Logic/Ruins), DENTRO do
--     próprio modelo (os desastres continuam acertando: os escombros são a construção até a vida acabar).
--     Os clientes animam (BuildingCollapsed). Quando a vida acaba, o modelo some e o cliente anima o sumir.
-- Modelos com mesh do Blender (uma peça só) não perdem blocos, mas também desabam em escombros.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DamageStages = require(Shared.Logic.DamageStages)
local Ruins = require(Shared.Logic.Ruins)
local DamageConfig = require(Shared.Config.DamageConfig)
local Templates = require(Shared.Buildings.Templates)
local Remotes = require(Shared.Remotes)

local Builder = require(script.Parent.Builder)

local DamageService = {}

local cfg = DamageConfig
local orders: { [string]: { number } } = {} -- ordem de queda por modelo + variação (calculada uma vez)

local function templateOf(model: Model): (string, any)
	local name = (model:GetAttribute("Template") :: string?) or model.Name
	return name, Templates[name]
end

local function orderFor(name: string, template: any, variant: number): { number }
	local key = `{name}#{variant}`
	local order = orders[key]
	if order == nil then
		local n = #template.Boxes
		order =
			DamageStages.order(template.Boxes, variant, cfg.Jitter, DamageStages.count(n, #cfg.Removed, cfg.Removed))
		orders[key] = order
	end
	return order :: { number }
end

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- Cor da parede da construção (os escombros usam junto com o concreto).
local function wallColor(model: Model): Color3
	local wall = model:FindFirstChild("Wall")
	if wall and wall:IsA("BasePart") then
		return wall.Color
	end
	local primary = model.PrimaryPart
	return if primary then primary.Color else rgb(cfg.Ruins.Concrete)
end

-- A construção desaba: some e no lugar dela ficam os escombros (dentro do modelo). Devolve false se ela não
-- desaba (pequena demais ou sem modelo de dados): aí continua só perdendo blocos.
local function collapse(model: Model): boolean
	if model:GetAttribute("Collapsed") then
		return true
	end
	local tier = (model:GetAttribute("Tier") :: number?) or 0
	local _, template = templateOf(model)
	if tier < cfg.Ruins.FromTier or template == nil then
		return false
	end
	local id = (model:GetAttribute("BuildingId") :: number?) or 0
	local boxes = Ruins.pile(template.Footprint[1], template.Footprint[2], tier, id, cfg.Ruins)
	if #boxes == 0 then
		return false
	end
	local colors = {
		Rubble = rgb(cfg.Ruins.Concrete),
		RubbleDark = rgb(cfg.Ruins.DarkConcrete),
		RubbleWall = wallColor(model),
	}
	-- a construção some (o cliente anima os blocos afundando a partir das cópias)
	local hidden = {}
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and child.Transparency < 1 then
			child:SetAttribute("Alpha", child.Transparency)
			child.Transparency = 1
			child.CanCollide = false
			child.CanQuery = false
			child.CanTouch = false
			child.CastShadow = false
			table.insert(hidden, child)
		end
	end
	-- escombros: continuam "consultáveis" para os desastres acertarem; sem colisão (NO WAY OUT)
	local pivot = model:GetPivot()
	for _, b in boxes do
		local part = Instance.new("Part")
		part.Name = b.Role
		part.Size = Vector3.new(b.Size[1], b.Size[2], b.Size[3])
		part.CFrame = pivot * CFrame.new(b.Pos[1], b.Pos[2], b.Pos[3])
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = true
		part.CanTouch = false
		part.Color = colors[b.Role] or colors.Rubble
		Builder.studify(part)
		part:SetAttribute("Rubble", true)
		part.Parent = model
	end
	model:SetAttribute("Collapsed", true)
	Remotes.event(Remotes.Names.Events.BuildingCollapsed):FireAllClients(model, hidden)
	return true
end

-- Construção levou dano e continua de pé (fraction = vida que sobrou, 0..1).
function DamageService.damaged(model: Model, fraction: number)
	local hp = DamageStages.quantize(fraction, cfg.HpBar.Step)
	if model:GetAttribute("Hp") ~= hp then
		model:SetAttribute("Hp", hp)
	end
	local stage = DamageStages.stage(fraction, cfg.Thresholds)
	local before = (model:GetAttribute("DamageStage") :: number?) or 0
	if stage <= before then
		return
	end
	model:SetAttribute("DamageStage", stage)
	-- último estágio: desaba em escombros (casas para cima)
	if stage >= #cfg.Thresholds and collapse(model) then
		return
	end
	local name, template = templateOf(model)
	if template == nil or #template.Boxes < cfg.MinBoxes then
		return
	end
	local id = (model:GetAttribute("BuildingId") :: number?) or 0
	local order = orderFor(name, template, id % cfg.Variants)
	local n = #template.Boxes
	local from = math.min(DamageStages.count(n, before, cfg.Removed), #order)
	local to = math.min(DamageStages.count(n, stage, cfg.Removed), #order)
	if to <= from then
		return
	end
	local falling: { [number]: boolean } = {}
	for k = from + 1, to do
		falling[order[k]] = true
	end
	local broken = {}
	for _, child in model:GetChildren() do
		local index = child:GetAttribute("Box")
		if child:IsA("BasePart") and type(index) == "number" and falling[index] then
			-- guarda a transparência original: o cliente copia o bloco para virar destroço
			child:SetAttribute("Alpha", child.Transparency)
			child.Transparency = 1
			child.CanCollide = false
			child.CanQuery = false
			child.CanTouch = false
			child.CastShadow = false
			table.insert(broken, child)
		end
	end
	if #broken > 0 then
		Remotes.event(Remotes.Names.Events.BuildingCracked):FireAllClients(model, broken)
	end
end

return DamageService
