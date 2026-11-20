--!strict
-- Cidade da partida no SERVIDOR: só dados (sem montar peças de construção).
--   CityState (vida, destruição, progresso) + SpatialGrid (quem está numa área) + lote de mudanças.
-- A cada MatchConfig.DeltaInterval as mudanças saem num buffer só (Protocol.Delta) para todos.
-- Quem entra, reconecta ou perde um lote pede o snapshot (CitySnapshot) e fica igual aos outros.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CityState = require(Shared.Logic.CityState)
local SpatialGrid = require(Shared.Logic.SpatialGrid)
local Protocol = require(Shared.Logic.Protocol)
local MatchCity = require(Shared.Logic.MatchCity)
local MatchConfig = require(Shared.Config.MatchConfig)
local CityConfig = require(Shared.Config.CityConfig)
local ModelCatalog = require(Shared.Config.ModelCatalog)
local Templates = require(Shared.Buildings.Templates)
local CityWorld = require(Shared.City.CityWorld)
local Remotes = require(Shared.Remotes)
local RateLimit = require(Shared.Logic.RateLimit)

local Players = game:GetService("Players")

local CityService = {}

local state: CityState.State? = nil
local grid: SpatialGrid.Grid? = nil
local infos: { MatchCity.Info } = {}
local layout: any = nil
local seq = 0
-- regeneração: construções destruídas, em ordem de quando voltam
local regen: { { Id: number, At: number } } = {}
local regenHead = 1

function CityService.load(map: CityWorld.MapInfo, mapScale: number)
	layout = CityWorld.layout(map, mapScale)
	infos = MatchCity.infos(layout.Placements, Templates :: any, ModelCatalog :: any, MatchConfig)
	state = CityState.new(infos)
	local g = SpatialGrid.new(MatchConfig.GridCell)
	for id, info in infos do
		local b = info.Box
		SpatialGrid.insert(g, id, b[1], b[2], b[3], b[4])
	end
	grid = g
	seq = 0
	table.clear(regen)
	regenHead = 1
end

function CityService.state(): CityState.State?
	return state
end

function CityService.info(id: number): MatchCity.Info?
	return infos[id]
end

function CityService.layout(): any
	return layout
end

function CityService.groundAt(x: number, z: number): number?
	if layout == nil then
		return nil
	end
	return MatchCity.groundAt(layout.Grid, CityConfig.CellSize, x, z)
end

-- Construções vivas que cruzam o círculo (as mais perto primeiro).
function CityService.query(x: number, z: number, radius: number, limit: number): { number }
	if grid == nil then
		return {}
	end
	return SpatialGrid.queryCircle(grid, x, z, radius, limit)
end

-- Dano com autoridade do servidor. Devolve (dano que entrou, destruiu agora?).
function CityService.hit(id: number, damage: number): (number, boolean)
	local s = state
	if s == nil then
		return 0, false
	end
	local dealt, killed = CityState.hit(s, id, damage)
	if killed then
		SpatialGrid.remove(grid :: SpatialGrid.Grid, id)
		table.insert(regen, { Id = id, At = os.clock() + MatchConfig.RegenSeconds })
	end
	return dealt, killed
end

local function flush()
	local s = state
	if s == nil or next(s.Dirty) == nil then
		return
	end
	local ids = CityState.takeDirty(s)
	-- lote muito grande (raro: fim da cidade) vai em pedaços de até 4000 ids
	for start = 1, #ids, 4000 do
		seq += 1
		local chunk = table.move(ids, start, math.min(start + 3999, #ids), 1, {})
		Remotes.event(Remotes.Names.Events.CityDelta)
			:FireAllClients(Protocol.encodeDelta(seq, s, chunk, MatchConfig.HpLevels))
	end
end

-- Volta as construções cujo tempo passou (a fila está em ordem: todas esperam o mesmo tempo).
local function regenerate()
	local s, g = state, grid
	if s == nil or g == nil then
		return
	end
	local now = os.clock()
	while regenHead <= #regen and regen[regenHead].At <= now do
		local id = regen[regenHead].Id
		regenHead += 1
		if CityState.revive(s, id) then
			local b = infos[id].Box
			SpatialGrid.insert(g, id, b[1], b[2], b[3], b[4])
		end
	end
	if regenHead > 512 then -- compacta a fila de vez em quando
		regen = table.move(regen, regenHead, #regen, 1, {})
		regenHead = 1
	end
end

-- Comando de teste (/regen): tudo que está destruído volta agora. Devolve quantas voltaram.
function CityService.reviveAll(): number
	local s, g = state, grid
	if s == nil or g == nil then
		return 0
	end
	local count = 0
	for id = 1, s.Count do
		if CityState.revive(s, id) then
			local b = infos[id].Box
			SpatialGrid.insert(g, id, b[1], b[2], b[3], b[4])
			count += 1
		end
	end
	table.clear(regen)
	regenHead = 1
	return count
end

function CityService.flushNow()
	flush()
end

function CityService.start()
	local buckets: { [Player]: RateLimit.Bucket } = {}
	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
	end)
	Remotes.func(Remotes.Names.Functions.CitySnapshot).OnServerInvoke = function(player: Player)
		local bucket = buckets[player] or RateLimit.new(1, 3, os.clock())
		buckets[player] = bucket
		if not RateLimit.take(bucket, os.clock()) then
			return nil -- pedido demais: o cliente tenta de novo depois
		end
		local s = state
		if s == nil then
			return nil
		end
		flush() -- o snapshot sai com o seq mais novo: o cliente não reaplica lote antigo
		return Protocol.encodeSnapshot(seq, s, MatchConfig.HpLevels)
	end
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= MatchConfig.DeltaInterval then
			acc = 0
			regenerate()
			flush()
		end
	end)
end

return CityService
