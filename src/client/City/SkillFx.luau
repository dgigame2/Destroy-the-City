--!strict
-- Efeitos das skills (Q) de todos os jogadores — VISUAL SIMPLES (passe de VFX caprichado fica para depois).
-- O servidor manda só o início (SkillFx); o cliente recalcula as zonas a cada frame com Logic/Skills,
-- igual ao servidor. Cada zona: coluna girando + disco no chão + blocos sendo arrastados em volta
-- (cosmético: a cidade é dado no servidor, nada voa de verdade). Rastro de fogo e explosão final (SkillEndFx).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Skills = require(Shared.Logic.Skills)
local SkillConfig = require(Shared.Config.SkillConfig)
local Remotes = require(Shared.Remotes)

local SkillFx = {}

local DEBRIS_PER_ZONE = 6

type ZoneFx = { Column: BasePart, Disc: BasePart, Debris: { BasePart } }
type Running = {
	Def: any,
	UserId: number,
	Start: number,
	OX: number,
	OY: number,
	OZ: number,
	DX: number,
	DZ: number,
	Radius: number,
	Zones: { ZoneFx },
	NextTrail: number,
}

local running: { Running } = {}
local lastY: { [number]: number } = {} -- altura do chão de cada jogador (para a explosão)
local folder: Folder? = nil

local function container(): Folder
	if folder == nil or folder.Parent == nil then
		local f = Instance.new("Folder")
		f.Name = "SkillFx"
		f.Parent = Workspace
		folder = f
	end
	return folder :: Folder
end

local function part(name: string, color: Color3, material: Enum.Material, transparency: number): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = material
	p.Color = color
	p.Transparency = transparency
	p.Parent = container()
	return p
end

local function colorOf(def: any): Color3
	return Color3.fromRGB(def.Color[1], def.Color[2], def.Color[3])
end

local function newZone(def: any): ZoneFx
	local color = colorOf(def)
	local hole = def.Name == "Black Hole"
	local column = part("Column", if hole then Color3.fromRGB(20, 5, 35) else color, Enum.Material.ForceField, 0.1)
	column.Shape = if hole then Enum.PartType.Ball else Enum.PartType.Cylinder
	local disc = part("Disc", color, Enum.Material.Neon, 0.7)
	disc.Shape = Enum.PartType.Cylinder
	local debris = {}
	for _ = 1, DEBRIS_PER_ZONE do
		local block = part("Debris", Color3.fromRGB(150, 140, 130), Enum.Material.Concrete, 0)
		block.Size = Vector3.new(1.5, 1.2, 1.5) * (0.7 + math.random() * 0.8)
		table.insert(debris, block)
	end
	return { Column = column, Disc = disc, Debris = debris }
end

local function destroyZone(z: ZoneFx)
	z.Column:Destroy()
	z.Disc:Destroy()
	for _, d in z.Debris do
		d:Destroy()
	end
end

local function fade(p: BasePart, seconds: number, size: Vector3?)
	local goal: { [string]: any } = { Transparency = 1 }
	if size then
		goal.Size = size
	end
	local tween = TweenService:Create(p, TweenInfo.new(seconds), goal)
	tween.Completed:Once(function()
		p:Destroy()
	end)
	tween:Play()
end

local function casterPosition(r: Running): (number, number)
	local player = Players:GetPlayerByUserId(r.UserId)
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.Position.X, root.Position.Z
	end
	return r.OX, r.OZ
end

local function step()
	local now = Workspace:GetServerTimeNow()
	local spin = os.clock() * 3
	for i = #running, 1, -1 do
		local r = running[i]
		local t = now - r.Start
		local duration = Skills.duration(r.Def)
		if t >= duration then
			for _, z in r.Zones do
				destroyZone(z)
			end
			table.remove(running, i)
			continue
		end
		local cx, cz = casterPosition(r)
		local zones = Skills.zones(r.Def, math.max(t, 0), cx, cz, r.OX, r.OZ, r.DX, r.DZ, r.Radius)
		local ground = r.OY - 3
		for k, zone in zones do
			local fx = r.Zones[k]
			if fx == nil then
				fx = newZone(r.Def)
				r.Zones[k] = fx
			end
			local center = Vector3.new(zone.X, ground, zone.Z)
			if fx.Column.Shape == Enum.PartType.Ball then
				fx.Column.Size = Vector3.one * zone.R * 1.2
				fx.Column.CFrame = CFrame.new(center + Vector3.new(0, zone.R * 0.8, 0))
			else
				local height = zone.R * 1.6
				fx.Column.Size = Vector3.new(height, zone.R * 1.4, zone.R * 1.4)
				fx.Column.CFrame = CFrame.new(center + Vector3.new(0, height / 2, 0))
					* CFrame.Angles(0, spin, math.rad(90))
			end
			fx.Disc.Size = Vector3.new(0.3, zone.R * 2, zone.R * 2)
			fx.Disc.CFrame = CFrame.new(center + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, spin, math.rad(90))
			-- blocos "arrastados": giram em volta subindo e descendo
			for j, block in fx.Debris do
				local a = spin * 1.5 + j * (math.pi * 2 / #fx.Debris)
				local d = zone.R * (0.4 + 0.3 * math.sin(spin + j))
				local h = zone.R * (0.3 + 0.5 * (0.5 + 0.5 * math.sin(spin * 2 + j * 1.3)))
				block.CFrame = CFrame.new(center + Vector3.new(math.cos(a) * d, h, math.sin(a) * d))
					* CFrame.Angles(a, a * 0.7, 0)
			end
		end
		if r.Def.Trail and now >= r.NextTrail then
			r.NextTrail = now + 0.4
			local zone = zones[1]
			local fire = part("Fire", Color3.fromRGB(255, 110, 30), Enum.Material.Neon, 0.35)
			fire.Shape = Enum.PartType.Cylinder
			fire.Size = Vector3.new(0.4, zone.R * 1.4, zone.R * 1.4)
			fire.CFrame = CFrame.new(zone.X, ground + 0.25, zone.Z) * CFrame.Angles(0, 0, math.rad(90))
			fade(fire, r.Def.TrailSeconds)
		end
	end
end

local function onStart(index: any, userId: any, start: any, ox: any, oy: any, oz: any, dx: any, dz: any, radius: any)
	local def = if type(index) == "number" then SkillConfig[index] else nil
	for _, v in { userId, start, ox, oy, oz, dx, dz, radius } do
		if type(v) ~= "number" then
			return
		end
	end
	if def == nil then
		return
	end
	lastY[userId] = oy
	table.insert(running, {
		Def = def,
		UserId = userId,
		Start = start,
		OX = ox,
		OY = oy,
		OZ = oz,
		DX = dx,
		DZ = dz,
		Radius = radius,
		Zones = {},
		NextTrail = 0,
	})
end

local function onEnd(userId: any, x: any, z: any, radius: any, mult: any)
	if type(userId) ~= "number" or type(x) ~= "number" or type(z) ~= "number" or type(radius) ~= "number" then
		return
	end
	local strength = if type(mult) == "number" then math.clamp(mult, 1, 4) else 1
	local ball = part("Burst", Color3.fromRGB(255, 255, 255), Enum.Material.ForceField, 0)
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.one * radius * 0.3
	ball.Position = Vector3.new(x, (lastY[userId] or 0) - 3 + radius * 0.3, z)
	fade(ball, 0.35 + 0.1 * strength, Vector3.one * radius * 2)
end

function SkillFx.init()
	Remotes.unreliable(Remotes.Names.Unreliable.SkillFx).OnClientEvent:Connect(onStart)
	Remotes.unreliable(Remotes.Names.Unreliable.SkillEndFx).OnClientEvent:Connect(onEnd)
	RunService.RenderStepped:Connect(step)
	Players.PlayerRemoving:Connect(function(player)
		lastY[player.UserId] = nil
	end)
end

return SkillFx
