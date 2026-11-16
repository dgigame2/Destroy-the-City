--!strict
-- Desastres no servidor (modo GameplayConfig.Mode = "Disasters"). O cliente só PEDE ("desastre X na mira Y");
-- aqui se confere tudo (dono vivo e na run, cooldown, alcance, desastre existe) e se decide dano, destruição,
-- dinheiro, pontos e poder. A matemática fica em Logic/Disasters e Logic/StructureHealth (testadas no Lune).
-- Celular e servidor: cada acerto só olha a área do desastre (consulta espacial) e atinge no máximo
-- DisasterConfig.MaxTargetsPerHit construções; no máximo MaxActive desastres ao mesmo tempo.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Disasters = require(Shared.Logic.Disasters)
local StructureHealth = require(Shared.Logic.StructureHealth)
local DisasterConfig = require(Shared.Config.DisasterConfig)
local ChainConfig = require(Shared.Config.ChainConfig)
local Chain = require(Shared.Logic.Chain)
local Templates = require(Shared.Buildings.Templates)
local StructureConfig = require(Shared.Config.StructureConfig)
local TierConfig = require(Shared.Config.TierConfig)
local Remotes = require(Shared.Remotes)
local EatQuery = require(Shared.EatQuery)

local MapService = require(script.Parent.MapService)
local EatService = require(script.Parent.EatService)
local GrowthService = require(script.Parent.GrowthService)
local DamageService = require(script.Parent.DamageService)
local MasteryService = require(script.Parent.MasteryService)
local Mastery = require(Shared.Logic.Mastery)
local MasteryConfig = require(Shared.Config.MasteryConfig)
local CityConfig = require(Shared.Config.CityConfig)

local DisasterService = {}

type Disaster = DisasterConfig.Disaster

local health = StructureHealth.new()
local lastUse: { [Player]: { [string]: number } } = {}
local active = 0
local params = OverlapParams.new()
params.FilterType = Enum.RaycastFilterType.Include

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then
		return nil
	end
	return (character :: Model):FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function power(player: Player): number
	return GrowthService.scale(player)
end

-- Construções no círculo (centro x, z; raio r), da mais perto para a mais longe, só das zonas abertas.
local function inCircle(x: number, z: number, r: number): { EatQuery.Hit }
	local buildings = MapService.buildingsFolder()
	if buildings == nil then
		return {}
	end
	params.FilterDescendantsInstances = { buildings }
	local open = EatService.openZone()
	local list = {}
	for _, hit in EatQuery.inReach(Vector3.new(x, 0, z), r, buildings, params) do
		local zone = (hit.Model:GetAttribute("Zone") :: number?) or 1
		if zone <= open and not MapService.isEaten(hit.Model) then
			table.insert(list, hit)
			if #list >= DisasterConfig.MaxTargetsPerHit then
				break
			end
		end
	end
	return list
end

-- Construções travadas (poder baixo demais) atingidas desde o último aviso, por jogador.
local lockedHits: { [Player]: number } = {}
local lastLockedNotice: { [Player]: number } = {}
local usefulHits: { [Player]: number } = {} -- golpes que causaram dano no mesmo lançamento

-- Um lançamento: quem lançou, o desastre, o poder e a contagem da cadeia que ele começou.
type Cast = { Player: Player, Cause: string, Power: number, ChainCount: number, Reactions: number }

local react: (Cast, Vector3, Chain.Reaction, number, number) -> ()

-- Aplica um golpe; destrói se a vida acabar. Devolve true se a construção levou dano e continua de pé.
-- `damageOf(tier)` = dano contra aquele tier; `depth` = 0 pelo desastre, 1+ pela cadeia.
local function strike(
	cast: Cast,
	model: Model,
	origin: Vector3,
	depth: number,
	damageOf: (TierConfig.Tier) -> number
): boolean
	local player = cast.Player
	local id = model:GetAttribute("BuildingId") :: number?
	local tierIndex = (model:GetAttribute("Tier") :: number?) or 0
	local tier = TierConfig[tierIndex]
	if id == nil or tier == nil or MapService.isEaten(model) then
		return false
	end
	local damage = damageOf(tier)
	if damage <= 0 then
		if depth == 0 and cast.Power < tier.RequiredScale then
			lockedHits[player] = (lockedHits[player] or 0) + 1
		end
		return false
	end
	if depth == 0 then
		usefulHits[player] = (usefulHits[player] or 0) + 1
	end
	local hp = Disasters.structureHp(tier, StructureConfig.HpPerScale)
	if not StructureHealth.hit(health, id, damage, hp) then
		-- continua de pé: barra de vida e estágios de dano (blocos caindo)
		DamageService.damaged(model, StructureHealth.fraction(health, id, hp))
		return true
	end
	-- caiu: guarda o que a cadeia precisa antes de a construção sumir
	local position = model:GetPivot().Position
	local template = (model:GetAttribute("Template") :: string?) or model.Name
	local info = Templates[template]
	local footprint = if info then math.max(info.Footprint[1], info.Footprint[2]) else 10
	local reaction = Chain.reaction(template, tierIndex, footprint, ChainConfig)
	DamageService.ruins(model) -- escombros no terreno (antes de a construção sumir)
	EatService.destroy(player, model, origin, Chain.bonus(depth, ChainConfig))
	-- XP para o desastre que derrubou (ou que começou a cadeia): ele sobe de nível
	MasteryService.record(player, cast.Cause, tierIndex, depth > 0)
	if depth > 0 then
		local before = cast.ChainCount
		cast.ChainCount += 1
		if Chain.crossed(before, cast.ChainCount, ChainConfig) then
			local text = Chain.label(cast.ChainCount, ChainConfig)
			Remotes.event(Remotes.Names.Events.ChainReaction):FireClient(player, text, cast.ChainCount, position)
		end
	end
	if reaction and Chain.canPropagate(depth + 1, cast.Reactions, ChainConfig) then
		cast.Reactions += 1
		Remotes.event(Remotes.Names.Events.ChainBlast)
			:FireAllClients({ Kind = reaction.Kind, Position = position, Radius = reaction.Radius })
		task.delay(ChainConfig.StepDelay, react, cast, position, reaction, hp, depth + 1)
	end
	return false
end

local function announceDamage(models: { Model }, origin: Vector3)
	if #models > 0 then
		Remotes.event(Remotes.Names.Events.BuildingDamaged):FireAllClients(models, origin)
	end
end

-- Explosão ou desabamento: atinge as vizinhas com o poder de quem começou a cadeia.
react = function(cast: Cast, position: Vector3, reaction: Chain.Reaction, sourceHp: number, depth: number)
	local damaged = {}
	for _, hit in inCircle(position.X, position.Z, reaction.Radius) do
		local damage = Chain.damageAt(sourceHp, reaction, hit.Distance, ChainConfig)
		local hurt = strike(cast, hit.Model, position, depth, function(tier)
			return if cast.Power + 1e-9 >= tier.RequiredScale then damage else 0
		end)
		if hurt then
			table.insert(damaged, hit.Model)
		end
	end
	announceDamage(damaged, position)
end

-- Chão liberado: terra (zona >= 1) de uma área já aberta. Mar, áreas fechadas e fora do mapa não valem:
-- os desastres só nascem e andam no chão da área em que a party pode estar (não passam da barreira).
local function openGround(x: number, z: number): boolean
	local zone = MapService.groundAt(x, z)
	return zone ~= nil and zone >= 1 and zone <= EatService.openZone()
end

local function groundY(x: number, z: number): number
	local _, height = MapService.groundAt(x, z)
	return height
end

-- Nível do desastre -> multiplicadores (Logic/Mastery).
type Mods = { Level: number, Damage: number, Size: number }
local function modsFor(player: Player, id: string): Mods
	local level = MasteryService.level(player, id)
	return {
		Level = level,
		Damage = Mastery.damage(level, MasteryConfig),
		Size = Mastery.size(level, MasteryConfig),
	}
end

-- Meteoro: aviso, espera, impacto com onda de choque.
local function meteor(cast: Cast, d: Disaster, p: number, m: Mods, tx: number, tz: number)
	task.wait(d.Delay)
	local r = Disasters.radius(d, p, DisasterConfig) * m.Size
	local center = Vector3.new(tx, groundY(tx, tz), tz)
	local damaged = {}
	for _, hit in inCircle(tx, tz, r) do
		local factor = Disasters.meteorFalloff(hit.Distance, r, d.Core, d.EdgeDamage)
		local hurt = strike(cast, hit.Model, center, 0, function(tier)
			return Disasters.hitDamage(d, p, tier, m.Damage) * factor
		end)
		if hurt then
			table.insert(damaged, hit.Model)
		end
	end
	announceDamage(damaged, center)
end

-- Tornado: anda em linha reta e atinge o que estiver no raio a cada tique.
-- `duration` já vem cortada para o tornado não sair do chão liberado (Disasters.travelTime).
local function tornado(
	cast: Cast,
	d: Disaster,
	p: number,
	m: Mods,
	sx: number,
	sz: number,
	dx: number,
	dz: number,
	duration: number
)
	local r = Disasters.radius(d, p, DisasterConfig) * m.Size
	local speed = Disasters.speed(d, p, DisasterConfig)
	local t = 0
	while t <= duration do
		local x, z = Disasters.tornadoAt(sx, sz, dx, dz, speed, t)
		local center = Vector3.new(x, groundY(x, z), z)
		local damaged = {}
		for _, hit in inCircle(x, z, r) do
			local hurt = strike(cast, hit.Model, center, 0, function(tier)
				return Disasters.hitDamage(d, p, tier, m.Damage)
			end)
			if hurt then
				table.insert(damaged, hit.Model)
			end
		end
		announceDamage(damaged, center)
		task.wait(d.Tick)
		t += d.Tick
	end
end

-- Raio: calcula a cadeia (pura) e atinge cada elo com a força dele. Devolve os pontos da cadeia (efeito).
local function lightningChain(
	d: Disaster,
	p: number,
	m: Mods,
	tx: number,
	tz: number
): ({ Disasters.Hop }, { [number]: Model })
	local hopRange = d.HopRange * p ^ DisasterConfig.RadiusExponent * m.Size
	local snap = d.Snap * p ^ DisasterConfig.RadiusExponent * m.Size
	local hops = d.Hops + Mastery.extraHops(d.Id, m.Level, MasteryConfig)
	-- candidatos: tudo num círculo que cobre a cadeia inteira (pulos x alcance do condutor)
	local reach = snap + hopRange * d.ConductorRange * hops
	local nodes = {}
	local models: { [number]: Model } = {}
	for _, hit in inCircle(tx, tz, reach) do
		local id = hit.Model:GetAttribute("BuildingId") :: number?
		if id then
			local pos = hit.Model:GetPivot().Position
			local name = (hit.Model:GetAttribute("Template") :: string?) or hit.Model.Name
			table.insert(nodes, { Id = id, X = pos.X, Z = pos.Z, Conductor = StructureConfig.Conductors[name] == true })
			models[id] = hit.Model
		end
	end
	local chain = Disasters.lightningChain(nodes, tx, tz, snap, hops, hopRange, d.HopDecay, d.ConductorRange)
	return chain, models
end

local function onUse(player: Player, id: unknown, target: unknown)
	if typeof(id) ~= "string" or typeof(target) ~= "Vector3" then
		return
	end
	local d = DisasterConfig.ById[id :: string]
	local root = rootOf(player)
	if d == nil or root == nil or not EatService.inMatch(player) or active >= DisasterConfig.MaxActive then
		return
	end
	local aim = target :: Vector3
	if aim.X ~= aim.X or aim.Z ~= aim.Z or math.abs(aim.X) > 1e6 or math.abs(aim.Z) > 1e6 then
		return -- NaN ou absurdo
	end
	local now = os.clock()
	local uses = lastUse[player] or {}
	lastUse[player] = uses
	if not Disasters.ready(uses[d.Id], d.Cooldown, now) then
		return
	end
	local p = power(player)
	local m = modsFor(player, d.Id)
	local origin = root.Position
	local tx, tz = Disasters.clampTarget(origin.X, origin.Z, aim.X, aim.Z, Disasters.range(d, p, DisasterConfig))
	-- só no chão da área liberada: mira em cima do mar, de parede invisível ou atrás da barreira volta para
	-- o último ponto de chão liberado na linha jogador -> mira
	local found
	tx, tz, found = Disasters.pullInside(origin.X, origin.Z, tx, tz, CityConfig.CellSize, openGround)
	if not found then
		return -- nem o jogador está em chão liberado: não gasta o cooldown
	end
	uses[d.Id] = now
	local look = root.CFrame.LookVector
	local dx, dz = Disasters.direction(origin.X, origin.Z, tx, tz, look.X, look.Z)
	local cast: { [string]: any } = {
		Id = d.Id,
		Caster = player,
		Origin = origin,
		Target = Vector3.new(tx, groundY(tx, tz), tz),
		Power = p,
		Size = m.Size, -- o cliente desenha o efeito do tamanho do nível
		Time = Workspace:GetServerTimeNow(),
	}
	local run: Cast = { Player = player, Cause = d.Id, Power = p, ChainCount = 0, Reactions = 0 }
	active += 1
	task.spawn(function()
		local ok, err = pcall(function()
			if d.Id == "Meteor" then
				Remotes.event(Remotes.Names.Events.DisasterCast):FireAllClients(cast)
				meteor(run, d, p, m, tx, tz)
			elseif d.Id == "Tornado" then
				-- nasce entre o jogador e a mira (no máximo Range), anda para a frente
				cast.Dir = Vector3.new(dx, 0, dz)
				local full = d.Duration + Mastery.extraDuration(d.Id, m.Level, MasteryConfig)
				local speed = Disasters.speed(d, p, DisasterConfig)
				-- para na borda do chão liberado (não atravessa a barreira nem entra no mar)
				cast.Duration = Disasters.travelTime(tx, tz, dx, dz, speed, full, CityConfig.CellSize, openGround)
				Remotes.event(Remotes.Names.Events.DisasterCast):FireAllClients(cast)
				tornado(run, d, p, m, tx, tz, dx, dz, cast.Duration)
			elseif d.Id == "Lightning" then
				local chain, models = lightningChain(d, p, m, tx, tz)
				local points = {}
				for _, hop in chain do
					local model = models[hop.Id]
					table.insert(points, model:GetPivot().Position)
				end
				cast.Hops = points
				Remotes.event(Remotes.Names.Events.DisasterCast):FireAllClients(cast)
				local damaged = {}
				for index, hop in chain do
					local model = models[hop.Id]
					local hurt = model.Parent ~= nil
						and strike(run, model, points[index], 0, function(tier)
							return Disasters.hitDamage(d, p, tier, m.Damage) * hop.Strength
						end)
					if hurt then
						table.insert(damaged, model)
					end
				end
				announceDamage(damaged, Vector3.new(tx, 0, tz))
			end
		end)
		active -= 1
		-- só acertou coisas fortes demais (nada levou dano): avisa (no máximo a cada 4 s)
		local onlyLocked = (lockedHits[player] or 0) > 0 and (usefulHits[player] or 0) == 0
		if onlyLocked and os.clock() - (lastLockedNotice[player] or 0) > 4 then
			lastLockedNotice[player] = os.clock()
			Remotes.event(Remotes.Names.Events.Notice):FireClient(player, "TOO STRONG! DESTROY SMALLER THINGS FIRST")
		end
		lockedHits[player] = 0
		usefulHits[player] = 0
		if not ok then
			warn("[DisasterService]", d.Id, err)
		end
	end)
end

function DisasterService.start()
	Remotes.event(Remotes.Names.Events.UseDisaster).OnServerEvent:Connect(onUse)
	Players.PlayerRemoving:Connect(function(player)
		lastUse[player] = nil
		lockedHits[player] = nil
		lastLockedNotice[player] = nil
		usefulHits[player] = nil
	end)
end

return DisasterService
