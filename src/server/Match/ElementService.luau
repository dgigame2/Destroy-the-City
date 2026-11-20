--!strict
-- Golpes dos elementos no SERVIDOR. O cliente só PEDE (Cast: elemento + alvo); aqui se confere tudo:
-- tipos dos argumentos, jogador na partida e vivo, limite de frequência (token bucket), cooldown do nível,
-- alcance e alvo dentro da cidade. O dano vai direto nos dados (CityService), sem consultar peças.
-- Etapa 4: cada nível monta um PLANO (Logic/ElementPlan) com pulsos no tempo; aqui cada pulso vira dano na
-- hora certa, mais a cadeia do raio e a queima do fogo (que se espalha a partir do nível 3). Os clientes
-- recebem só (elemento, nível, semente, alvo, origem) e montam o mesmo plano para desenhar.
-- Nível de cada elemento: levels[player] (Etapa 5 traz o XP); o cliente vê pelo atributo "Level<Id>".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Elements = require(Shared.Logic.Elements)
local ElementPlan = require(Shared.Logic.ElementPlan)
local RateLimit = require(Shared.Logic.RateLimit)
local ElementConfig = require(Shared.Config.ElementConfig)
local MatchConfig = require(Shared.Config.MatchConfig)
local Remotes = require(Shared.Remotes)

local CityService = require(script.Parent.CityService)

local ElementService = {}

type BurnCast = { Left: number, Range: number, Seconds: number, Dps: number }
type Burning = { Owner: Player, Element: ElementConfig.Element, Until: number, Dps: number, Cast: BurnCast }

local MAX = ElementConfig.MaxLevel
local buckets: { [Player]: RateLimit.Bucket } = {}
local lastCast: { [Player]: { [string]: number } } = {}
local levels: { [Player]: { [string]: number } } = {}
local burning: { [number]: Burning } = {}
local burningCount = 0
local destroyedBy: ((Player, number) -> ())? = nil
local canPlay: (Player) -> boolean = function(_player: Player)
	return false
end

local function finite(v: Vector3): boolean
	return v.X == v.X and v.Y == v.Y and v.Z == v.Z and math.abs(v.X) < 1e6 and math.abs(v.Z) < 1e6
end

function ElementService.onDestroyed(callback: (Player, number) -> ())
	destroyedBy = callback
end

function ElementService.setGate(gate: (Player) -> boolean)
	canPlay = gate
end

function ElementService.levelOf(player: Player, elementId: string): number
	local list = levels[player]
	return if list and list[elementId] then list[elementId] else 1
end

-- Muda o nível de um elemento (XP na Etapa 5; DevLevel no Studio). O cliente vê pelo atributo.
function ElementService.setLevel(player: Player, elementId: string, level: number)
	local list = levels[player]
	if list == nil then
		list = {}
		levels[player] = list
	end
	list[elementId] = ElementPlan.clampLevel(level, MAX)
	player:SetAttribute("Level" .. elementId, list[elementId])
end

local function center(id: number): (number, number)
	local info = CityService.info(id)
	if info == nil then
		return 0, 0
	end
	local b = info.Box
	return (b[1] + b[3]) / 2, (b[2] + b[4]) / 2
end

-- Dano com a identidade do elemento; avisa quem destruiu. Devolve se a construção ainda está de pé.
local function damage(player: Player, element: ElementConfig.Element, id: number, amount: number): boolean
	local info = CityService.info(id)
	if info == nil then
		return false
	end
	local mult = Elements.against(element, info.Category, info.Height, ElementConfig.TallBonus)
	local _, killed = CityService.hit(id, amount * mult)
	if killed and destroyedBy then
		destroyedBy(player, id)
	end
	local state = CityService.state()
	return state ~= nil and not state.Dead[id]
end

-- Vizinhos vivos em volta de (x, z) como candidatos da cadeia / do fogo que espalha.
local function candidates(x: number, z: number, range: number): { ElementPlan.Candidate }
	local list = {}
	for _, id in CityService.query(x, z, range, MatchConfig.ChainCandidates) do
		local cx, cz = center(id)
		table.insert(list, { Id = id, X = cx, Z = cz })
	end
	return list
end

local burnFxQueue: { number } = {}
local burnFxSeconds = 0

local function ignite(player: Player, element: ElementConfig.Element, id: number, cast: BurnCast)
	if burning[id] or burningCount >= MatchConfig.Burn.MaxBurning then
		return
	end
	burning[id] = { Owner = player, Element = element, Until = os.clock() + cast.Seconds, Dps = cast.Dps, Cast = cast }
	burningCount += 1
	table.insert(burnFxQueue, id)
	burnFxSeconds = math.max(burnFxSeconds, cast.Seconds)
end

local function pulse(
	player: Player,
	element: ElementConfig.Element,
	base: number,
	p: ElementPlan.Pulse,
	burn: BurnCast?
)
	local hits = CityService.query(p.X, p.Z, p.Radius, p.MaxTargets)
	for _, id in hits do
		local alive = damage(player, element, id, base * p.Mult)
		if alive and burn then
			ignite(player, element, id, burn)
		end
	end
	local chain = p.Chain
	if chain then
		-- salta a partir do 1º atingido (ou do centro, se não acertou nada)
		local sx, sz = p.X, p.Z
		local used: { [number]: boolean } = {}
		if hits[1] then
			sx, sz = center(hits[1])
		end
		for _, id in hits do
			used[id] = true
		end
		local hops =
			ElementPlan.chain(sx, sz, candidates(sx, sz, chain.Range * chain.Hops), chain.Hops, chain.Range, used)
		if #hops > 0 then
			local points = { Vector3.new(sx, CityService.groundAt(sx, sz) or 0, sz) }
			local k = 1
			for _, hop in hops do
				k *= chain.Falloff
				damage(player, element, hop.Id, base * p.Mult * k)
				table.insert(points, Vector3.new(hop.X, CityService.groundAt(hop.X, hop.Z) or 0, hop.Z))
			end
			Remotes.unreliable(Remotes.Names.Unreliable.ChainFx):FireAllClients(player.UserId, points)
		end
	end
end

-- Lança o golpe do nível atual: aplica cada pulso do plano no tempo dele. Também usado pelo DevBench.
-- Devolve o plano (para o CastFx) e a semente.
function ElementService.cast(
	player: Player,
	element: ElementConfig.Element,
	ox: number,
	oz: number,
	tx: number,
	tz: number,
	seed: number?
): (ElementPlan.Plan, number)
	local level = ElementService.levelOf(player, element.Id)
	local s = seed or math.random(1, 2 ^ 30)
	local plan = ElementPlan.build(element, level, MAX, ox, oz, tx, tz, s)
	local base = Elements.damage(element, level, MAX)
	local burn: BurnCast? = nil
	if plan.Burn then
		burn = {
			Left = plan.Burn.Foci,
			Range = plan.Burn.SpreadRange,
			Seconds = plan.Burn.Seconds,
			Dps = base * plan.Burn.Dps,
		}
	end
	for _, p in plan.Pulses do
		if p.At <= 0 then
			pulse(player, element, base, p, burn)
		else
			task.delay(p.At, function()
				if player.Parent and canPlay(player) then
					pulse(player, element, base, p, burn)
				end
			end)
		end
	end
	return plan, s
end

-- Benchmark antigo: golpe no alvo, sem direção.
function ElementService.strike(player: Player, element: ElementConfig.Element, x: number, z: number)
	ElementService.cast(player, element, x, z, x, z)
end

-- Queima: dano a cada Tick; a partir do nível 3 cada foco passa o fogo para 1 vizinho (até Left por golpe).
local function burnTick()
	local now = os.clock()
	local state = CityService.state()
	if state == nil then
		return
	end
	-- fogo novo entra DEPOIS da volta (não se mexe na tabela que está sendo percorrida)
	local spread: { { Owner: Player, Element: ElementConfig.Element, Id: number, Cast: BurnCast } } = {}
	for id, b in burning do
		if state.Dead[id] or now >= b.Until or b.Owner.Parent == nil then
			burning[id] = nil
			burningCount -= 1
			continue
		end
		local alive = damage(b.Owner, b.Element, id, b.Dps * MatchConfig.Burn.Tick)
		if alive and b.Cast.Left > 0 then
			local x, z = center(id)
			local used: { [number]: boolean } = {}
			for other in burning do
				used[other] = true
			end
			for _, s in spread do
				used[s.Id] = true
			end
			local pick = ElementPlan.chain(x, z, candidates(x, z, b.Cast.Range), 1, b.Cast.Range, used)
			if pick[1] then
				b.Cast.Left -= 1
				table.insert(spread, { Owner = b.Owner, Element = b.Element, Id = pick[1].Id, Cast = b.Cast })
			end
		end
	end
	for _, s in spread do
		ignite(s.Owner, s.Element, s.Id, s.Cast)
	end
	if #burnFxQueue > 0 then
		Remotes.unreliable(Remotes.Names.Unreliable.BurnFx):FireAllClients(burnFxQueue, burnFxSeconds)
		burnFxQueue = {}
		burnFxSeconds = 0
	end
end

local function onCast(player: Player, elementId: unknown, target: unknown)
	if type(elementId) ~= "string" or typeof(target) ~= "Vector3" then
		return
	end
	local element = ElementConfig.ById[elementId]
	local aim = target :: Vector3
	if element == nil or not finite(aim) or not canPlay(player) then
		return
	end
	local now = os.clock()
	local bucket = buckets[player]
	if bucket == nil then
		bucket = RateLimit.new(MatchConfig.Cast.Rate, MatchConfig.Cast.Burst, now)
		buckets[player] = bucket
	end
	if not RateLimit.take(bucket, now) then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root == nil or humanoid == nil or humanoid.Health <= 0 then
		return
	end
	local ground = CityService.groundAt(aim.X, aim.Z)
	if ground == nil then
		return
	end
	local flat = Vector3.new(aim.X - root.Position.X, 0, aim.Z - root.Position.Z)
	local times = lastCast[player]
	if times == nil then
		times = {}
		lastCast[player] = times
	end
	local level = ElementService.levelOf(player, element.Id)
	local ok =
		Elements.canCast(element, times[element.Id], now, flat.Magnitude, ElementPlan.cooldown(element, level, MAX))
	if not ok then
		return
	end
	times[element.Id] = now
	local origin = root.Position
	local _, seed = ElementService.cast(player, element, origin.X, origin.Z, aim.X, aim.Z)
	Remotes.unreliable(Remotes.Names.Unreliable.CastFx)
		:FireAllClients(element.Id, player.UserId, Vector3.new(aim.X, ground, aim.Z), level, seed, origin)
end

function ElementService.start()
	Remotes.event(Remotes.Names.Events.Cast).OnServerEvent:Connect(onCast)
	local function join(player: Player)
		for _, element in ElementConfig.List do
			if player:GetAttribute("Level" .. element.Id) == nil then
				ElementService.setLevel(player, element.Id, 1)
			end
		end
	end
	Players.PlayerAdded:Connect(join)
	for _, player in Players:GetPlayers() do
		join(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
		lastCast[player] = nil
		levels[player] = nil
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= MatchConfig.Burn.Tick then
			acc = 0
			if next(burning) ~= nil or #burnFxQueue > 0 then
				burnTick()
			end
		end
	end)
end

return ElementService
