--!strict
-- Desabamento e destroço de cada construção no CLIENTE (AUDITORIA §8.3). O servidor só diz "caiu" (id);
-- O QUE fica é igual em todo cliente (Logic/Wreck.pick + Logic/Ruins pela semente = id); COMO cai é de cada
-- cliente, pelo Tier (client/City/QualityTier):
--   * perto/médio e dentro do teto de desabamentos: o prédio afunda e inclina (CFrame, sem física), solta
--     pedaços que voam em arco (pool, teto do Tier, só perto) e poeira (pool, Tier Medium/High);
--   * longe, fora do teto ou na entrada (snapshot): troca direto pelo destroço.
-- O destroço fica para sempre (a cidade parece devastada): pilha de blocos perto/médio, 1 caixa baixa longe
-- (LodManager). Na Etapa 3 a pilha vira a mesh do Blender escolhida pelo mesmo Wreck.pick.
-- Um único Heartbeat anima desabamentos e pedaços; nada é criado durante a animação além do que vem do pool.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Ruins = require(Shared.Logic.Ruins)
local Wreck = require(Shared.Logic.Wreck)
local WreckConfig = require(Shared.Config.WreckConfig)
local ElementFxConfig = require(Shared.Config.ElementFxConfig)
local Templates = require(Shared.Buildings.Templates)
local Builder = require(Shared.City.Builder)

local LodManager = require(script.Parent.LodManager)
local QualityTier = require(script.Parent.QualityTier)

local WreckPresenter = {}

type Placement = { Template: string, X: number, Y: number, Z: number, Rotation: number }

type Collapse = {
	Model: Model,
	Id: number,
	Start: CFrame, -- pivô do modelo no começo
	Base: CFrame, -- ponto no chão (centro do lote)
	Axis: Vector3,
	Height: number,
	Age: number,
}

type Flying = {
	Part: BasePart,
	Piece: Wreck.Piece,
	Origin: Vector3,
	StartY: number,
	Age: number,
	Spin: Vector3,
}

local C = WreckConfig.Collapse
local P = WreckConfig.Pieces
local CONCRETE = Color3.fromRGB(table.unpack(WreckConfig.Ruins.Concrete))
local DARK = Color3.fromRGB(table.unpack(WreckConfig.Ruins.DarkConcrete))

local collapses: { Collapse } = {}
local flying: { Flying } = {}
local piecePool: { BasePart } = {}
local fxFolder: Folder? = nil
local dust: ParticleEmitter? = nil
local dustAnchor: Attachment? = nil

local function folder(): Folder
	if fxFolder == nil or fxFolder.Parent == nil then
		local f = Instance.new("Folder")
		f.Name = "WreckFx"
		f.Parent = Workspace
		fxFolder = f
	end
	return fxFolder :: Folder
end

local function takePiece(): BasePart
	local part = table.remove(piecePool)
	if part == nil then
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.SmoothPlastic
		part = p
	end
	return part :: BasePart
end

local function givePiece(part: BasePart)
	part.Parent = nil
	table.insert(piecePool, part)
end

-- Poeira: um único emissor (Emit) que muda de lugar a cada desabamento.
local function emitDust(at: Vector3, size: number)
	if dust == nil then
		local holder = Instance.new("Part")
		holder.Name = "Dust"
		holder.Anchored = true
		holder.CanCollide = false
		holder.CanQuery = false
		holder.CanTouch = false
		holder.Transparency = 1
		holder.Size = Vector3.one
		local a = Instance.new("Attachment")
		a.Parent = holder
		local e = Instance.new("ParticleEmitter")
		e.Texture = ElementFxConfig.Textures.Smoke
		e.Color = ColorSequence.new(Color3.fromRGB(196, 186, 168))
		e.LightInfluence = 1
		e.Enabled = false
		e.Lifetime = NumberRange.new(0.6, 0.9)
		e.SpreadAngle = Vector2.new(180, 10)
		e.Drag = 3
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-40, 40)
		e.Transparency = NumberSequence.new(0.35, 1)
		e.Parent = a
		holder.Parent = folder()
		dust, dustAnchor = e, a
	end
	local e = dust :: ParticleEmitter
	(dustAnchor :: Attachment).WorldPosition = at
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size * 0.3),
		NumberSequenceKeypoint.new(1, size * 0.8),
	})
	e.Speed = NumberRange.new(size * 0.8, size * 1.6)
	e:Emit(math.clamp(math.floor(size / 2), 4, 10))
end

local function wallColor(model: Model?): Color3
	local wall = model and model:FindFirstChild("Wall", true)
	return if wall and wall:IsA("BasePart") then wall.Color else CONCRETE
end

-- Pilha de blocos (provisória) no lugar da construção, girada/espelhada pelo Wreck.pick + caixa baixa de longe.
local function buildWreck(id: number, placement: Placement, color: Color3): (Model?, BasePart?, Wreck.Pick?)
	local template = Templates[placement.Template]
	if template == nil or template.Footprint == nil then
		return nil, nil, nil
	end
	local w, d = template.Footprint[1], template.Footprint[2]
	local pick = Wreck.pick(id, placement.Template, w, d, WreckConfig)
	local boxes = Ruins.pile(w, d, template.Tier, id, WreckConfig.Ruins)
	if #boxes == 0 then
		return nil, nil, pick
	end
	local cframe = CFrame.new(placement.X, placement.Y, placement.Z)
		* CFrame.Angles(0, math.rad(placement.Rotation + pick.Rotation), 0)
	local mirror = if pick.Mirror then -1 else 1
	local pile = Instance.new("Model")
	pile.Name = "Wreck" .. id
	local top = 0
	for _, b in boxes do
		local part = Instance.new("Part")
		part.Size = Vector3.new(b.Size[1], b.Size[2], b.Size[3])
		part.CFrame = cframe * CFrame.new(b.Pos[1] * mirror, b.Pos[2], b.Pos[3])
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Color = if b.Role == "RubbleWall" then color elseif b.Role == "RubbleDark" then DARK else CONCRETE
		Builder.studify(part)
		part.Parent = pile
		top = math.max(top, b.Pos[2] + b.Size[2] / 2)
	end
	-- longe: uma caixa baixa só (a cor da parede)
	local box = Instance.new("Part")
	box.Name = "WreckBox" .. id
	box.Anchored = true
	box.CanCollide = false
	box.CanQuery = false
	box.CanTouch = false
	box.CastShadow = false
	box.Material = Enum.Material.SmoothPlastic
	box.Color = color:Lerp(CONCRETE, 0.5)
	box.Size = Vector3.new(w * WreckConfig.Ruins.Margin, math.max(top * 0.6, 0.4), d * WreckConfig.Ruins.Margin)
	box.CFrame = cframe * CFrame.new(0, box.Size.Y / 2, 0)
	return pile, box, pick
end

local function launchPieces(id: number, placement: Placement, sizeName: string, color: Color3, height: number)
	local template = Templates[placement.Template]
	local tier = QualityTier.current()
	local count = Wreck.budget(sizeName, P.PerSize, #flying, tier.FlyingPieces)
	if count <= 0 or template == nil then
		return
	end
	local origin = Vector3.new(placement.X, placement.Y, placement.Z)
	local startY = math.min(height * 0.5, 12)
	for _, piece in Wreck.pieces(id, count, template.Footprint[1], template.Footprint[2], P.Speed, P.MaxSize) do
		local part = takePiece()
		part.Size = Vector3.new(piece.Size, piece.Size * 0.7, piece.Size)
		part.Color = if piece.Size > P.MaxSize * 0.7 then color else CONCRETE
		part.Transparency = 0
		part.CFrame = CFrame.new(origin + Vector3.new(piece.Ox, startY, piece.Oz))
		part.Parent = folder()
		table.insert(flying, {
			Part = part,
			Piece = piece,
			Origin = origin,
			StartY = startY,
			Age = 0,
			Spin = Vector3.new(piece.Spin, piece.Spin * 0.6, 0),
		})
	end
end

local function finishCollapse(c: Collapse)
	c.Model:Destroy()
	LodManager.reveal(c.Id)
end

local function step(dt: number)
	for i = #collapses, 1, -1 do
		local c = collapses[i]
		c.Age += dt
		local t = c.Age / C.Seconds
		if t >= 1 then
			finishCollapse(c)
			collapses[i] = collapses[#collapses]
			collapses[#collapses] = nil
		else
			local sink, tilt = Wreck.collapse(t, c.Height, C.MaxTilt, C.Sink)
			local offset = CFrame.new(0, -sink, 0) * CFrame.fromAxisAngle(c.Axis, math.rad(tilt))
			c.Model:PivotTo(c.Base * offset * c.Base:Inverse() * c.Start)
		end
	end
	for i = #flying, 1, -1 do
		local f = flying[i]
		f.Age += dt
		local x, y, z = Wreck.piece(f.Piece, f.Age, P.Gravity, f.StartY)
		local spin = f.Spin * math.rad(f.Age)
		f.Part.CFrame = CFrame.new(f.Origin + Vector3.new(x, y, z)) * CFrame.Angles(spin.X, spin.Y, 0)
		local fade = (f.Age - P.Seconds * 0.6) / (P.Seconds * 0.4)
		if fade > 0 then
			f.Part.Transparency = math.min(fade, 1)
		end
		if f.Age >= P.Seconds then
			givePiece(f.Part)
			flying[i] = flying[#flying]
			flying[#flying] = nil
		end
	end
end

-- A construção `id` caiu. model = o modelo vivo (pode estar escondido pelo LOD); animate = veio de um golpe
-- agora (false na entrada/snapshot: troca direto). height = altura do modelo (Info.Height).
-- leavesWreck = false: objetos que não contam no progresso (carros, árvores, postes) só somem.
function WreckPresenter.destroy(
	id: number,
	model: Model,
	placement: Placement,
	height: number,
	animate: boolean,
	leavesWreck: boolean
)
	local color = wallColor(model)
	local pile, box, pick = nil, nil, nil
	if leavesWreck then
		pile, box, pick = buildWreck(id, placement, color)
	end
	local band = LodManager.band(id)
	local tier = QualityTier.current()
	local visible = model.Parent ~= nil and band ~= "Far"
	if animate and visible and #collapses < tier.Collapses then
		LodManager.markDead(id, pile, box, false)
		local base = CFrame.new(placement.X, placement.Y, placement.Z)
		local a = Wreck.noise(id, 7) * math.pi * 2
		table.insert(collapses, {
			Model = model,
			Id = id,
			Start = model:GetPivot(),
			Base = base,
			Axis = Vector3.new(math.cos(a), 0, math.sin(a)),
			Height = height,
			Age = 0,
		})
		if band == "Near" and pick then
			launchPieces(id, placement, pick.Size, color, height)
		end
		if tier.Dust then
			emitDust(Vector3.new(placement.X, placement.Y + 1, placement.Z), math.clamp(height, 4, 30))
		end
	else
		LodManager.markDead(id, pile, box, true)
		model:Destroy()
	end
end

-- Para medição: o que está animando agora.
function WreckPresenter.stats(): { [string]: number }
	return { Collapses = #collapses, Flying = #flying, Pool = #piecePool }
end

function WreckPresenter.init()
	RunService.Heartbeat:Connect(function(dt)
		if #collapses > 0 or #flying > 0 then
			step(dt)
		end
	end)
end

return WreckPresenter
