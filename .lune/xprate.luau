-- ESTIMATIVA do ritmo de XP com a cidade real do servidor: um bot anda até o alvo mais perto e destrói o que encosta.
-- Uso: lune run xprate  -> XP/min por nível (sem rebirth no XP) e o tempo de cada ciclo com o TornadoConfig atual.
-- shortcut: 1 jogador, sem skills/PvP/obstáculos; recalibrar EFFICIENCY com jogadores de verdade.
local Templates = require("../src/shared/Buildings/Templates")
local MapConfig = require("../src/shared/Config/MapConfig")
local CityPlans = require("../src/shared/Config/CityPlans")
local CityConfig = require("../src/shared/Config/CityConfig")
local DistrictConfig = require("../src/shared/Config/DistrictConfig")
local DifficultyConfig = require("../src/shared/Config/DifficultyConfig")
local ModelCatalog = require("../src/shared/Config/ModelCatalog")
local MatchConfig = require("../src/shared/Config/MatchConfig")
local RunConfig = require("../src/shared/Config/RunConfig")
local cfg = require("../src/shared/Config/TornadoConfig")
local CityGen = require("../src/shared/Logic/CityGen")
local CityState = require("../src/shared/Logic/CityState")
local MatchCity = require("../src/shared/Logic/MatchCity")
local SpatialGrid = require("../src/shared/Logic/SpatialGrid")
local Rng = require("../src/shared/Logic/Rng")
local Tornado = require("../src/shared/Logic/Tornado")

local EFFICIENCY = 0.6 -- ESTIMATIVA: fração do tempo que o jogador de verdade rende perto do bot
local WARMUP, MEASURE = 60, 180 -- segundos (aquece mais que a regeneração)

local map, difficulty
for _, m in MapConfig do
	if m.Id == RunConfig.City.Map then
		map = m
	end
end
for _, d in DifficultyConfig do
	if d.Id == RunConfig.City.Difficulty then
		difficulty = d
	end
end
local layout = CityGen.generate(
	CityPlans[map.Id],
	DistrictConfig[map.Style],
	Templates,
	Rng.new(map.Seed),
	CityConfig,
	difficulty.MapScale
)
local infos = MatchCity.infos(layout.Placements, Templates, ModelCatalog, MatchConfig)

-- XP base por minuto (já com a eficiência), no nível e rebirths dados.
local function rate(level: number, rebirths: number): number
	local state = CityState.new(infos)
	local grid = SpatialGrid.new(MatchConfig.GridCell)
	for id, info in infos do
		SpatialGrid.insert(grid, id, info.Box[1], info.Box[2], info.Box[3], info.Box[4])
	end
	local spawn = layout.Spawns[1][1]
	local x, z = spawn[1], spawn[3]
	local radius, speed = Tornado.radius(cfg, level), Tornado.walkSpeed(cfg, level)
	local damage = Tornado.dps(cfg, level, rebirths) * cfg.Tick
	local queue, head, xp = {}, 1, 0
	local time = 0
	while time < WARMUP + MEASURE do
		time += cfg.Tick
		while head <= #queue and queue[head][2] <= time do
			local id = queue[head][1]
			head += 1
			if CityState.revive(state, id) then
				local b = infos[id].Box
				SpatialGrid.insert(grid, id, b[1], b[2], b[3], b[4])
			end
		end
		local near = SpatialGrid.queryCircle(grid, x, z, radius, cfg.MaxTargets)
		for _, id in near do
			local _, killed = CityState.hit(state, id, damage)
			if killed then
				SpatialGrid.remove(grid, id)
				table.insert(queue, { id, time + MatchConfig.RegenSeconds })
				if time > WARMUP then
					xp += state.Value[id] + cfg.PropXp
				end
			end
		end
		-- fica parado enquanto algo que vale XP está ao alcance; senão vai ao alvo mais perto que vale
		local target, best = nil, math.huge
		for _, id in SpatialGrid.queryCircle(grid, x, z, radius + 250, 400) do
			local b = infos[id].Box
			local dx, dz = (b[1] + b[3]) / 2 - x, (b[2] + b[4]) / 2 - z
			local d = math.sqrt(dx * dx + dz * dz)
			if state.Value[id] > 0 and d < best then
				best, target = d, { dx, dz }
			end
		end
		if target and best > radius * 0.8 then
			local step = math.min(speed * cfg.Tick, best)
			x += target[1] / best * step
			z += target[2] / best * step
		end
	end
	return xp / (MEASURE / 60) * EFFICIENCY
end

local total = 0
for r = 0, Tornado.maxRebirths(cfg) do
	local top = Tornado.maxLevel(cfg, r)
	local minutes, returning = 0, 0
	for level = 1, top do
		local base = rate(level, r)
		local spent = Tornado.xpToNext(cfg, level) / (base * Tornado.xpFor(cfg, 1 - cfg.PropXp, r))
		minutes += spent
		if r > 0 and level <= Tornado.maxLevel(cfg, r - 1) then
			returning += spent
		end
		print(string.format("  r%d L%-2d  %8.0f XP/min base  %6.2f min", r, level, base, spent))
	end
	total += minutes
	print(string.format("CICLO %d (até %d): %.1f min, volta %.1f, total %.1f", r, top, minutes, returning, total))
end
