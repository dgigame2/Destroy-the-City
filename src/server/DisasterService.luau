--!strict
-- Desastres no servidor (modo GameplayConfig.Mode = "Disasters"). O cliente só PEDE ("desastre X na mira Y");
-- aqui se confere tudo (dono vivo e na run, cooldown, alcance, desastre existe) e se decide dano, destruição,
-- dinheiro, pontos e poder. A matemática fica em Logic/Disasters, Logic/Chain, Logic/Debris e
-- Logic/StructureHealth (testadas no Lune).
-- Celular e servidor: cada acerto só olha a área do desastre (consulta espacial) e atinge no máximo
-- DisasterConfig.MaxTargetsPerHit construções; no máximo MaxActive desastres ao mesmo tempo; objetos voando
-- (DebrisConfig.MaxActive) e focos de fogo (ChainConfig.Fire.MaxActive) também têm teto.
--
-- Reações em cadeia (ChainConfig): quando uma construção cai ela pode explodir, desabar, soltar faísca
-- (condutor) e/ou pegar fogo (inflamável); explosões e desabamentos soltam pedaços que voam e batem em outras
-- construções. Tudo passa por `strike` (StructureHealth + DamageService), com o poder de quem começou.
-- Placar individual (StatsService): dano que entrou, construções derrubadas, reações começadas.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Disasters = require(Shared.Logic.Disasters)
local StructureHealth = require(Shared.Logic.StructureHealth)
local DisasterConfig = require(Shared.Config.DisasterConfig)
local ChainConfig = require(Shared.Config.ChainConfig)
local DebrisConfig = require(Shared.Config.DebrisConfig)
local Chain = require(Shared.Logic.Chain)
local Debris = require(Shared.Logic.Debris)
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
local StatsService = require(script.Parent.StatsService)
local DebrisService = require(script.Parent.DebrisService)
local Mastery = require(Shared.Logic.Mastery)
local MasteryConfig = require(Shared.Config.MasteryConfig)
local CityConfig = require(Shared.Config.CityConfig)

local DisasterService = {}

type Disaster = DisasterConfig.Disaster

local health = StructureHealth.new()
local lastUse: { [Player]: { [string]: number } } = {}
local active = 0
local fires = 0
local random = Random.new()
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

local function templateName(model: Model): string
	return (model:GetAttribute("Template") :: string?) or model.Name
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

-- Um lançamento: quem lançou, o desastre, o poder, o bônus das reações (upgrade/classe Chain) e a contagem da
-- cadeia que ele começou.
type Cast = { Player: Player, Cause: string, Power: number, Chain: number, ChainCount: number, Reactions: number }

local react: (Cast, Vector3, Chain.Reaction, number, number, Color3) -> ()

local function announceDamage(models: { Model }, origin: Vector3)
	if #models > 0 then
		Remotes.event(Remotes.Names.Events.BuildingDamaged):FireAllClients(models, origin)
	end
end

local function blast(payload: { [string]: any })
	Remotes.event(Remotes.Names.Events.ChainBlast):FireAllClients(payload)
end

-- Começa uma reação (conta no limite da cadeia e no placar de quem lançou). false = limite atingido.
local function startReaction(cast: Cast, depth: number): boolean
	if not Chain.canPropagate(depth, cast.Reactions, ChainConfig) then
		return false
	end
	cast.Reactions += 1
	StatsService.addChain(cast.Player)
	return true
end

-- Conta uma construção que caiu na cadeia (aviso de combo "CHAIN x3").
local function countChain(cast: Cast, position: Vector3)
	local before = cast.ChainCount
	cast.ChainCount += 1
	if Chain.crossed(before, cast.ChainCount, ChainConfig) then
		local text = Chain.label(cast.ChainCount, ChainConfig)
		Remotes.event(Remotes.Names.Events.ChainReaction):FireClient(cast.Player, text, cast.ChainCount, position)
	end
end

local function colorOf(model: Model): Color3
	local wall = model:FindFirstChild("Wall")
	if wall and wall:IsA("BasePart") then
		return wall.Color
	end
	local primary = model.PrimaryPart
	return if primary then primary.Color else Color3.fromRGB(196, 186, 176)
end

local strike: (Cast, Model, Vector3, number, (TierConfig.Tier) -> number) -> boolean

-- Batida de algo que voou (objeto do tornado ou pedaço de explosão) em `position`: dano em volta, como uma
-- reação da cadeia na profundidade `depth`. `sourceHp` = HP de quem voou. Devolve se acertou alguma coisa.
local function debrisImpact(cast: Cast, position: Vector3, sourceHp: number, depth: number): boolean
	local hits = inCircle(position.X, position.Z, DebrisConfig.ImpactRadius)
	if #hits == 0 or not startReaction(cast, depth) then
		return false
	end
	blast({ Kind = "Impact", Position = position, Radius = DebrisConfig.ImpactRadius })
	local damaged = {}
	for _, hit in hits do
		local damage = Debris.impactDamage(sourceHp, hit.Distance, DebrisConfig) * cast.Chain
		local hurt = strike(cast, hit.Model, position, depth, function(tier)
			return damage * Disasters.underPower(cast.Power, tier, StructureConfig.UnderPower)
		end)
		if hurt then
			table.insert(damaged, hit.Model)
		end
	end
	announceDamage(damaged, position)
	return true
end

-- Explosão/desabamento solta pedaços de escombro que voam e batem em volta.
local function flingChunks(
	cast: Cast,
	position: Vector3,
	footprint: number,
	sourceHp: number,
	depth: number,
	color: Color3
)
	local cfg = DebrisConfig.Blast
	local pieceHp = Debris.blastPieceHp(sourceHp, DebrisConfig)
	for _ = 1, Debris.blastPieces(DebrisService.active(), DebrisConfig) do
		local angle = random:NextNumber() * math.pi * 2
		local speed = cfg.Speed * random:NextNumber(0.7, 1.1)
		local start = position + Vector3.new(0, footprint * 0.3 + 2, 0)
		DebrisService.launch({
			Parts = DebrisService.chunk(start, math.clamp(footprint * cfg.Size, 1.2, 6), color),
			Velocity = Vector3.new(
				math.cos(angle) * speed,
				cfg.Lift * random:NextNumber(0.8, 1.2),
				math.sin(angle) * speed
			),
			OnImpact = function(at: Vector3)
				debrisImpact(cast, at, pieceHp, depth + 1)
			end,
		})
	end
end

-- Fogo: queima por Ticks x TickDelay segundos e machuca o que está em volta (inflamável leva mais).
local function burn(cast: Cast, position: Vector3, sourceHp: number, depth: number)
	local cfg = ChainConfig.Fire
	if fires >= cfg.MaxActive then
		return
	end
	fires += 1
	blast({ Kind = "Fire", Position = position, Radius = cfg.Radius, Duration = cfg.Ticks * cfg.TickDelay })
	local ok, err = pcall(function()
		for _ = 1, cfg.Ticks do
			task.wait(cfg.TickDelay)
			local damaged = {}
			for _, hit in inCircle(position.X, position.Z, cfg.Radius) do
				local flammable = cfg.Flammable[templateName(hit.Model)] == true
				local damage = Chain.fireDamage(sourceHp, hit.Distance, flammable, ChainConfig) * cast.Chain
				local hurt = strike(cast, hit.Model, position, depth, function(tier)
					return damage * Disasters.underPower(cast.Power, tier, StructureConfig.UnderPower)
				end)
				if hurt then
					table.insert(damaged, hit.Model)
				end
			end
			announceDamage(damaged, position)
		end
	end)
	fires -= 1
	if not ok then
		warn("[DisasterService] fogo", err)
	end
end

type NodeSet = { Nodes: { Disasters.Node }, Models: { [number]: Model } }

-- Construções em volta como nós do raio/faísca (condutor = StructureConfig.Conductors).
local function nodesAround(x: number, z: number, reach: number): NodeSet
	local nodes = {}
	local models: { [number]: Model } = {}
	for _, hit in inCircle(x, z, reach) do
		local id = hit.Model:GetAttribute("BuildingId") :: number?
		if id then
			local pos = hit.Model:GetPivot().Position
			local name = templateName(hit.Model)
			table.insert(nodes, { Id = id, X = pos.X, Z = pos.Z, Conductor = StructureConfig.Conductors[name] == true })
			models[id] = hit.Model
		end
	end
	return { Nodes = nodes, Models = models }
end

-- Faísca: o condutor que caiu solta uma mini cadeia de raio a partir dele.
local function spark(cast: Cast, position: Vector3, sourceHp: number, depth: number)
	local cfg = ChainConfig.Electric
	local set = nodesAround(position.X, position.Z, cfg.HopRange * cfg.ConductorRange * cfg.Hops)
	local chain = Disasters.lightningChain(
		set.Nodes,
		position.X,
		position.Z,
		cfg.HopRange,
		cfg.Hops - 1,
		cfg.HopRange,
		cfg.Decay,
		cfg.ConductorRange
	)
	if #chain == 0 then
		return
	end
	local points = { position }
	for _, hop in chain do
		table.insert(points, set.Models[hop.Id]:GetPivot().Position)
	end
	blast({ Kind = "Electric", Position = position, Radius = cfg.HopRange, Points = points })
	local damaged = {}
	for _, hop in chain do
		local model = set.Models[hop.Id]
		local damage = sourceHp * cfg.DamageFactor * hop.Strength * cast.Chain
		local hurt = model.Parent ~= nil
			and strike(cast, model, position, depth, function(tier)
				return damage * Disasters.underPower(cast.Power, tier, StructureConfig.UnderPower)
			end)
		if hurt then
			table.insert(damaged, model)
		end
	end
	announceDamage(damaged, position)
end

-- Aplica um golpe; destrói se a vida acabar. Devolve true se a construção levou dano e continua de pé.
-- `damageOf(tier)` = dano contra aquele tier; `depth` = 0 pelo desastre, 1+ pela cadeia.
strike = function(
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
	if depth == 0 then
		-- forte demais para o seu poder: leva pouco dano (aviso "TOO STRONG" se só acertou essas)
		if cast.Power + 1e-9 < tier.RequiredScale then
			lockedHits[player] = (lockedHits[player] or 0) + 1
		else
			usefulHits[player] = (usefulHits[player] or 0) + 1
		end
	end
	if damage <= 0 then
		return false
	end
	local hp = Disasters.structureHp(tier, StructureConfig.HpPerScale)
	local fell, dealt = StructureHealth.hitDealt(health, id, damage, hp)
	StatsService.addDamage(player, dealt)
	if not fell then
		-- continua de pé: barra de vida e estágios de dano (blocos caindo)
		DamageService.damaged(model, StructureHealth.fraction(health, id, hp))
		return true
	end
	-- caiu: guarda o que a cadeia precisa antes de a construção sumir
	local position = model:GetPivot().Position
	local template = templateName(model)
	local info = Templates[template]
	local footprint = if info then math.max(info.Footprint[1], info.Footprint[2]) else 10
	local color = colorOf(model)
	local reactions =
		Chain.reactions(template, tierIndex, footprint, ChainConfig, StructureConfig.Conductors, cast.Cause)
	EatService.destroy(player, model, origin, Chain.bonus(depth, ChainConfig))
	-- XP para o desastre que derrubou (ou que começou a cadeia): ele sobe de nível
	MasteryService.record(player, cast.Cause, tierIndex, depth > 0, GrowthService.multiplier(player, "Xp"))
	if depth > 0 then
		countChain(cast, position)
	end
	for _, reaction in reactions do
		if not startReaction(cast, depth + 1) then
			break
		end
		if reaction.Kind == "Fire" then
			task.delay(ChainConfig.StepDelay, burn, cast, position, hp, depth + 1)
		elseif reaction.Kind == "Electric" then
			task.delay(ChainConfig.StepDelay, spark, cast, position, hp, depth + 1)
		else
			blast({ Kind = reaction.Kind, Position = position, Radius = reaction.Radius })
			task.delay(ChainConfig.StepDelay, react, cast, position, reaction, hp, depth + 1, color)
		end
	end
	return false
end

-- Explosão ou desabamento: atinge as vizinhas com o poder de quem começou a cadeia e solta pedaços voando.
react = function(
	cast: Cast,
	position: Vector3,
	reaction: Chain.Reaction,
	sourceHp: number,
	depth: number,
	color: Color3
)
	local damaged = {}
	for _, hit in inCircle(position.X, position.Z, reaction.Radius) do
		local damage = Chain.damageAt(sourceHp, reaction, hit.Distance, ChainConfig) * cast.Chain
		local hurt = strike(cast, hit.Model, position, depth, function(tier)
			return damage * Disasters.underPower(cast.Power, tier, StructureConfig.UnderPower)
		end)
		if hurt then
			table.insert(damaged, hit.Model)
		end
	end
	announceDamage(damaged, position)
	if Chain.canPropagate(depth + 1, cast.Reactions, ChainConfig) then
		-- tamanho dos pedaços pelo raio da onda (a construção já sumiu)
		flingChunks(cast, position, math.min(reaction.Radius, 20), sourceHp, depth, color)
	end
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

-- Nível do desastre + upgrades/classe -> multiplicadores (Logic/Mastery, Logic/Disasters.mods).
type Mods = {
	Level: number,
	Damage: number,
	Size: number,
	Range: number,
	Cooldown: number,
	Duration: number,
	Chain: number,
}
local function modsFor(player: Player, id: string): Mods
	local level = MasteryService.level(player, id)
	local bonus = Disasters.mods(function(stat)
		return GrowthService.multiplier(player, stat)
	end)
	return {
		Level = level,
		Damage = Mastery.damage(level, MasteryConfig) * bonus.Damage,
		Size = Mastery.size(level, MasteryConfig) * bonus.Size,
		Range = bonus.Range,
		Cooldown = bonus.Cooldown,
		Duration = bonus.Duration,
		Chain = bonus.Chain,
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
			return Disasters.hitDamage(d, p, tier, m.Damage, StructureConfig.UnderPower, DisasterConfig.OverkillCap)
				* factor
		end)
		if hurt then
			table.insert(damaged, hit.Model)
		end
	end
	announceDamage(damaged, center)
end

-- O funil arranca um objeto leve: ele cai (prêmios para quem lançou), vira um objeto físico que gira no funil
-- e depois é arremessado; onde bater, machuca (e se for explosivo, explode lá).
local function lift(cast: Cast, model: Model, tierIndex: number, tier: TierConfig.Tier, funnel: { [string]: any })
	local id = model:GetAttribute("BuildingId") :: number
	local hp = Disasters.structureHp(tier, StructureConfig.HpPerScale)
	local fell, dealt = StructureHealth.hitDealt(health, id, hp, hp)
	if not fell then
		return
	end
	StatsService.addDamage(cast.Player, dealt)
	local template = templateName(model)
	local info = Templates[template]
	local footprint = if info then math.max(info.Footprint[1], info.Footprint[2]) else 4
	local explosive = Chain.reaction(template, tierIndex, footprint, ChainConfig)
	local color = colorOf(model)
	local parts = DebrisService.copyOf(model)
	-- o cliente não anima a explosão de sumir: quem aparece voando é a cópia física
	model:SetAttribute("Flung", true)
	EatService.destroy(cast.Player, model, funnel.Center, 1)
	MasteryService.record(cast.Player, cast.Cause, tierIndex, false, GrowthService.multiplier(cast.Player, "Xp"))
	DebrisService.launch({
		Parts = parts,
		Orbit = {
			Center = function(): Vector3?
				return if funnel.Alive then funnel.Center else nil
			end,
			Radius = funnel.Radius,
			Throw = random:NextNumber(),
		},
		OnImpact = function(at: Vector3)
			debrisImpact(cast, at, hp, 1)
			if explosive and explosive.Kind == "Explosion" and startReaction(cast, 1) then
				blast({ Kind = "Explosion", Position = at, Radius = explosive.Radius })
				task.delay(ChainConfig.StepDelay, react, cast, at, explosive, hp, 1, color)
			end
		end,
	})
end

-- Tornado: anda em linha reta e atinge o que estiver no raio a cada tique. Objetos leves num anel maior
-- (DebrisConfig.Lift.Radius) são arrancados e puxados para o funil (enquanto houver vaga de objeto voando).
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
	local pullRadius = r * DebrisConfig.Lift.Radius
	local speed = Disasters.speed(d, p, DisasterConfig)
	local funnel = { Center = Vector3.new(sx, groundY(sx, sz), sz), Radius = r, Alive = true }
	local t = 0
	while t <= duration do
		local x, z = Disasters.tornadoAt(sx, sz, dx, dz, speed, t)
		local center = Vector3.new(x, groundY(x, z), z)
		funnel.Center = center
		local damaged = {}
		for _, hit in inCircle(x, z, pullRadius) do
			local tierIndex = (hit.Model:GetAttribute("Tier") :: number?) or 0
			local tier = TierConfig[tierIndex]
			if tier == nil then
				continue
			end
			if Debris.lifts(tier.Name, tier.RequiredScale, p, DebrisConfig) and DebrisService.canSpawn() then
				usefulHits[cast.Player] = (usefulHits[cast.Player] or 0) + 1
				lift(cast, hit.Model, tierIndex, tier, funnel)
			elseif hit.Distance <= r then
				local hurt = strike(cast, hit.Model, center, 0, function(target)
					-- objeto leve (poste, banco...) sem vaga para voar: o funil derruba na hora
					if Disasters.sweeps(d, p, target) then
						return Disasters.structureHp(target, StructureConfig.HpPerScale)
					end
					return Disasters.hitDamage(
						d,
						p,
						target,
						m.Damage,
						StructureConfig.UnderPower,
						DisasterConfig.OverkillCap
					)
				end)
				if hurt then
					table.insert(damaged, hit.Model)
				end
			end
		end
		announceDamage(damaged, center)
		task.wait(d.Tick)
		t += d.Tick
	end
	funnel.Alive = false
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
	local set = nodesAround(tx, tz, snap + hopRange * d.ConductorRange * hops)
	local chain = Disasters.lightningChain(set.Nodes, tx, tz, snap, hops, hopRange, d.HopDecay, d.ConductorRange)
	return chain, set.Models
end

-- `heading` (opcional, só tornado): ponto para onde ele deve andar a partir da mira (2º clique do jogador).
-- Sem ele, anda na direção jogador -> mira.
local function onUse(player: Player, id: unknown, target: unknown, heading: unknown)
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
	local p = power(player)
	local m = modsFor(player, d.Id)
	if not Disasters.ready(uses[d.Id], Disasters.cooldown(d, m.Cooldown), now) then
		return
	end
	local origin = root.Position
	local range = Disasters.range(d, p, DisasterConfig) * m.Range
	local tx, tz = Disasters.clampTarget(origin.X, origin.Z, aim.X, aim.Z, range)
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
	if typeof(heading) == "Vector3" then
		local h = heading :: Vector3
		if h.X == h.X and h.Z == h.Z and math.abs(h.X) < 1e6 and math.abs(h.Z) < 1e6 then
			dx, dz = Disasters.direction(tx, tz, h.X, h.Z, dx, dz)
		end
	end
	local cast: { [string]: any } = {
		Id = d.Id,
		Caster = player,
		Origin = origin,
		Target = Vector3.new(tx, groundY(tx, tz), tz),
		Power = p,
		Size = m.Size, -- o cliente desenha o efeito do tamanho do nível + upgrades
		Time = Workspace:GetServerTimeNow(),
	}
	local run: Cast = { Player = player, Cause = d.Id, Power = p, Chain = m.Chain, ChainCount = 0, Reactions = 0 }
	active += 1
	task.spawn(function()
		local ok, err = pcall(function()
			if d.Id == "Meteor" then
				Remotes.event(Remotes.Names.Events.DisasterCast):FireAllClients(cast)
				meteor(run, d, p, m, tx, tz)
			elseif d.Id == "Tornado" then
				-- nasce entre o jogador e a mira (no máximo Range), anda para a frente
				cast.Dir = Vector3.new(dx, 0, dz)
				local full = (d.Duration + Mastery.extraDuration(d.Id, m.Level, MasteryConfig)) * m.Duration
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
							return Disasters.hitDamage(
								d,
								p,
								tier,
								m.Damage,
								StructureConfig.UnderPower,
								DisasterConfig.OverkillCap
							) * hop.Strength
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
