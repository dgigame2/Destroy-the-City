--!strict
-- Objetos que voam (DebrisConfig + Logic/Debris). Só movimento e detecção de batida; quem decide o dano é quem
-- lançou (DisasterService passa `onImpact`). Física no servidor (SetNetworkOwner(nil)): todo mundo vê o mesmo
-- voo, sem o cliente poder mexer. Peças sem colisão (não empurram nem prendem jogador: NO WAY OUT) e sem
-- consulta (os desastres não acertam destroços). No máximo DebrisConfig.MaxActive voando; cada um some em
-- até Lifetime segundos, batendo ou não.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Debris = require(Shared.Logic.Debris)
local DebrisConfig = require(Shared.Config.DebrisConfig)
local EatQuery = require(Shared.EatQuery)

local MapService = require(script.Parent.MapService)

local DebrisService = {}

local cfg = DebrisConfig
local active = 0
local random = Random.new()
local params = OverlapParams.new()
params.FilterType = Enum.RaycastFilterType.Include

local folder: Folder? = nil
local function container(): Folder
	if folder == nil or folder.Parent == nil then
		local created = Instance.new("Folder")
		created.Name = "FlyingDebris"
		created.Parent = Workspace
		folder = created
	end
	return folder :: Folder
end

-- Orbit: enquanto o funil existir, o objeto gira em volta dele. `center()` devolve o centro atual (nil =
-- o tornado acabou) e `radius` o raio do funil.
export type Orbit = { Center: () -> Vector3?, Radius: number, Throw: number }
-- onImpact(posição, construção atingida ou nil = caiu no chão)
export type Spec = {
	Parts: { BasePart },
	Velocity: Vector3?, -- velocidade inicial (pedaço de explosão)
	Orbit: Orbit?,
	OnImpact: (Vector3, Model?) -> (),
}

function DebrisService.active(): number
	return active
end

function DebrisService.canSpawn(): boolean
	return Debris.canSpawn(active, cfg)
end

local function prepare(part: BasePart)
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = false
	for _, child in part:GetChildren() do
		if child:IsA("JointInstance") or child:IsA("WeldConstraint") then
			child:Destroy()
		end
	end
end

-- Cópia leve de uma construção para voar: as peças visíveis (até MaxParts) soldadas na maior; acima disso
-- uma caixa só, do tamanho e da cor dela. Chame ANTES de a construção sumir (MapService.consume).
function DebrisService.copyOf(model: Model): { BasePart }
	local visible = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			table.insert(visible, d)
		end
	end
	if #visible == 0 then
		return {}
	end
	table.sort(visible, function(a, b)
		return a.Size.Magnitude > b.Size.Magnitude
	end)
	if #visible > cfg.MaxParts then
		local cf, size = model:GetBoundingBox()
		local box = Instance.new("Part")
		box.Size = size
		box.CFrame = cf
		box.Color = visible[1].Color
		box.Material = Enum.Material.SmoothPlastic
		return { box }
	end
	local list = {}
	for _, part in visible do
		local copy = part:Clone()
		for _, child in copy:GetChildren() do
			if not (child:IsA("Decal") or child:IsA("Texture") or child:IsA("SurfaceAppearance")) then
				child:Destroy()
			end
		end
		table.insert(list, copy)
	end
	return list
end

-- Pedaço de escombro (explosão/desabamento).
function DebrisService.chunk(position: Vector3, size: number, color: Color3): { BasePart }
	local part = Instance.new("Part")
	part.Size = Vector3.new(size, size * 0.7, size * 0.9)
	part.CFrame = CFrame.new(position) * CFrame.Angles(random:NextNumber() * math.pi, random:NextNumber() * math.pi, 0)
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	return { part }
end

local function hitBuilding(root: BasePart, extents: Vector3): Model?
	local buildings = MapService.buildingsFolder()
	if buildings == nil then
		return nil
	end
	params.FilterDescendantsInstances = { buildings }
	for _, part in Workspace:GetPartBoundsInBox(root.CFrame, extents, params) do
		local model = EatQuery.buildingOf(part, buildings)
		if model and not MapService.isEaten(model) then
			return model
		end
	end
	return nil
end

local function groundY(x: number, z: number): number
	local _, height = MapService.groundAt(x, z)
	return height
end

-- Lança. Devolve false (e não cria nada) se já tem MaxActive voando.
function DebrisService.launch(spec: Spec): boolean
	if not Debris.canSpawn(active, cfg) or #spec.Parts == 0 then
		for _, part in spec.Parts do
			part:Destroy()
		end
		return false
	end
	active += 1
	local model = Instance.new("Model")
	model.Name = "Debris"
	local root = spec.Parts[1]
	for _, part in spec.Parts do
		prepare(part)
		part.Parent = model
		if part ~= root then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = part
			weld.Parent = root
		end
	end
	model.PrimaryPart = root
	model.Parent = container()
	local _, size = model:GetBoundingBox()
	local extents = size + Vector3.new(1, 1, 1)
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	root.AssemblyAngularVelocity =
		Vector3.new(random:NextNumber(-6, 6), random:NextNumber(-8, 8), random:NextNumber(-6, 6))
	if spec.Velocity then
		root.AssemblyLinearVelocity = spec.Velocity
	end
	-- girando no funil o objeto não cai (força para cima = peso); ao sair, a gravidade volta
	local antigravity: VectorForce? = nil
	if spec.Orbit then
		local attachment = Instance.new("Attachment")
		attachment.Parent = root
		local force = Instance.new("VectorForce")
		force.Attachment0 = attachment
		force.RelativeTo = Enum.ActuatorRelativeTo.World
		force.ApplyAtCenterOfMass = true
		force.Force = Vector3.new(0, root.AssemblyMass * Workspace.Gravity, 0)
		force.Parent = root
		antigravity = force
	end
	task.spawn(function()
		local started = os.clock()
		local orbit = spec.Orbit
		local flying = orbit == nil
		local impact: Vector3? = nil
		local struck: Model? = nil
		while os.clock() - started < cfg.Lifetime and root.Parent do
			local pos = root.Position
			if not flying then
				local o = orbit :: Orbit
				local center = o.Center()
				if center and os.clock() - started < cfg.Lift.OrbitTime then
					local vx, vy, vz = Debris.orbitVelocity(pos.X, pos.Z, center.X, center.Z, o.Radius, cfg)
					root.AssemblyLinearVelocity = Vector3.new(vx, vy, vz)
				else
					-- sai do funil: arremessado para fora ou cai perto
					local c = center or pos
					local thrown = Debris.thrown(o.Throw, cfg)
					local speed = if thrown then cfg.ThrowSpeed else cfg.ThrowSpeed * 0.15
					local lift = if thrown then cfg.ThrowLift else 0
					local vx, vy, vz = Debris.throwVelocity(pos.X, pos.Z, c.X, c.Z, speed, lift)
					root.AssemblyLinearVelocity = Vector3.new(vx, vy, vz)
					if antigravity then
						antigravity:Destroy()
					end
					flying = true
				end
			else
				if pos.Y <= groundY(pos.X, pos.Z) + size.Y * 0.3 then
					impact = pos
					break
				end
				local building = hitBuilding(root, extents)
				if building then
					impact, struck = pos, building
					break
				end
			end
			task.wait(cfg.CheckEvery)
		end
		model:Destroy()
		active -= 1
		if impact then
			local ok, err = pcall(spec.OnImpact, impact :: Vector3, struck)
			if not ok then
				warn("[DebrisService]", err)
			end
		end
	end)
	return true
end

return DebrisService
