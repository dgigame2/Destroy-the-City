--!strict
-- Benchmark da partida (SÓ no Studio; não existe no jogo publicado). Simula N "casters" lançando golpes
-- de verdade (ElementService.strike, o mesmo caminho do Cast) por alguns segundos, no ritmo do cooldown, e
-- mede o servidor: tempo de CPU dos golpes, construções destruídas, progresso e tráfego (Stats).
-- Uso (barra de comandos do servidor, no Play):
--   game.ServerStorage.DevBench:Invoke(4, 10)   -- 4 casters por 10 segundos
--   game.ServerStorage.DevBench:Invoke(4, 10, true) -- idem, mandando os efeitos para os clientes (pior caso)
--   game.ServerStorage.DevLevel:Invoke(5)       -- todos os elementos no nível 5
--   game.ServerStorage.DevWreck:Invoke(90, 40)  -- derruba a cidade até 90%, 40 construções/s (pior caso
--                                               -- do cliente: muito destroço e desabamentos seguidos)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Stats = game:GetService("Stats")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CityState = require(Shared.Logic.CityState)
local ElementConfig = require(Shared.Config.ElementConfig)
local Remotes = require(Shared.Remotes)

local CityService = require(script.Parent.CityService)
local ElementService = require(script.Parent.ElementService)

local DevBench = {}

local function run(casters: number, seconds: number, fx: boolean): { [string]: any }
	local player = Players:GetPlayers()[1]
	local state = CityService.state()
	local layout = CityService.layout()
	if player == nil or state == nil or layout == nil then
		return { Error = "partida ainda não começou" }
	end
	local before = state.DestroyedCount
	local cpu, strikes, peakSend = 0, 0, 0
	local started = os.clock()
	local sendSamples, sendTotal = 0, 0
	local i = 0
	while os.clock() - started < seconds do
		for c = 1, casters do
			i += 1
			-- cada caster mira uma construção viva diferente (o pior caso: tudo acerta alguma coisa)
			local p = layout.Placements[(i * 37 + c * 101) % #layout.Placements + 1]
			local element = ElementConfig.List[(i + c) % #ElementConfig.List + 1]
			local t = os.clock()
			-- golpe de verdade, com direção, e o efeito para os clientes (pior caso visual também)
			local ox, oz = p.X - 60, p.Z - 60
			local _, seed = ElementService.cast(player, element, ox, oz, p.X, p.Z)
			if fx then
				local ground = CityService.groundAt(p.X, p.Z) or p.Y
				Remotes.unreliable(Remotes.Names.Unreliable.CastFx):FireAllClients(
					element.Id,
					player.UserId,
					Vector3.new(p.X, ground, p.Z),
					ElementService.levelOf(player, element.Id),
					seed,
					Vector3.new(ox, ground, oz)
				)
			end
			cpu += os.clock() - t
			strikes += 1
		end
		task.wait(1) -- ~1 golpe por segundo por caster (cooldown dos elementos)
		local send = Stats.DataSendKbps
		peakSend = math.max(peakSend, send)
		sendTotal += send
		sendSamples += 1
	end
	return {
		Casters = casters,
		Seconds = seconds,
		Strikes = strikes,
		Destroyed = state.DestroyedCount - before,
		Progress = math.floor(CityState.progress(state) * 1000) / 10,
		CpuPerStrikeMs = math.floor(cpu / math.max(strikes, 1) * 1e5) / 100,
		SendKbpsAvg = math.floor(sendTotal / math.max(sendSamples, 1) * 100) / 100,
		SendKbpsPeak = math.floor(peakSend * 100) / 100,
		ServerMemoryMb = math.floor(Stats:GetTotalMemoryUsageMb()),
	}
end

-- Derruba construções vivas (ordem embaralhada, semente fixa) até o progresso chegar em `pct`%.
local function wreckTo(pct: number, perSecond: number): { [string]: any }
	local state = CityService.state()
	local layout = CityService.layout()
	if state == nil or layout == nil then
		return { Error = "partida ainda não começou" }
	end
	local order = {}
	for id = 1, #layout.Placements do
		table.insert(order, id)
	end
	local rng = Random.new(1)
	for i = #order, 2, -1 do
		local j = rng:NextInteger(1, i)
		order[i], order[j] = order[j], order[i]
	end
	local started, count = os.clock(), 0
	for _, id in order do
		if CityState.progress(state) * 100 >= pct then
			break
		end
		if not state.Dead[id] then
			local info = CityService.info(id)
			CityService.hit(id, if info then info.MaxHp else 1e9)
			count += 1
			if count % perSecond == 0 then
				task.wait(1)
			end
		end
	end
	return {
		Destroyed = count,
		Progress = math.floor(CityState.progress(state) * 1000) / 10,
		Seconds = math.floor((os.clock() - started) * 10) / 10,
	}
end

function DevBench.start()
	-- nível de todos os elementos de todos os jogadores (testar os 5 níveis sem XP): DevLevel:Invoke(5)
	local devLevel = Instance.new("BindableFunction")
	devLevel.Name = "DevLevel"
	devLevel.OnInvoke = function(level: number?)
		for _, player in Players:GetPlayers() do
			for _, element in ElementConfig.List do
				ElementService.setLevel(player, element.Id, level or 1)
			end
		end
		return level or 1
	end
	devLevel.Parent = ServerStorage
	local wreck = Instance.new("BindableFunction")
	wreck.Name = "DevWreck"
	wreck.OnInvoke = function(pct: number?, perSecond: number?)
		return wreckTo(math.clamp(pct or 90, 1, 98), math.clamp(perSecond or 40, 1, 500))
	end
	wreck.Parent = ServerStorage
	local bench = Instance.new("BindableFunction")
	bench.Name = "DevBench"
	bench.OnInvoke = function(casters: number?, seconds: number?, fx: boolean?)
		return run(math.clamp(casters or 4, 1, 8), math.clamp(seconds or 10, 1, 120), fx == true)
	end
	bench.Parent = ServerStorage
end

return DevBench
