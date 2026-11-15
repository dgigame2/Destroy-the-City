--!strict
-- Junta a cidade gerada (Logic/CityGen) com o balanceamento (Logic/ZoneBalance): alvos de tamanho de cada
-- etapa, multiplicadores de crescimento e a estimativa de tempo de cada zona. Puro (testável no Lune);
-- usado pelo servidor (MapService), pelos testes e pelos relatórios.

local ZoneBalance = if script then require(script.Parent.ZoneBalance) else require("./ZoneBalance")

local CityProgress = {}

type Tier = { RequiredScale: number, Growth: number }
type Template = { Tier: number }
type GrowthConfig = { BaseScale: number, ScalePerSqrtPoint: number, MaxScale: number }
type Progression = { Margin: number, MinGrowth: number, SweepEfficiency: number }
type SweepConfig = { BaseEatRadius: number, WalkSpeed: number, SpeedScaleExponent: number, Efficiency: number }
type Layout = {
	Grid: { Step: { number } },
	Placements: { { Template: string, Step: number } },
	Steps: { { Zone: number, Cap: number } },
	ZoneNames: { string },
}

export type Balance = {
	Items: { { Step: number, Tier: number } },
	Targets: { number }, -- tamanho no fim de cada etapa (dificuldade normal)
	Multipliers: { number }, -- crescimento de cada etapa
}

function CityProgress.balance(
	layout: Layout,
	templates: { [string]: Template },
	tiers: { Tier },
	finalScale: number,
	worstGrowth: number,
	progression: Progression,
	growth: GrowthConfig
): Balance
	local items = {}
	for _, p in layout.Placements do
		table.insert(items, { Step = p.Step, Tier = templates[p.Template].Tier })
	end
	local caps = {}
	for _, step in layout.Steps do
		table.insert(caps, step.Cap)
	end
	local targets =
		ZoneBalance.stepTargets(caps, tiers, worstGrowth, progression.Margin, finalScale, progression.MinGrowth, growth)
	return {
		Items = items,
		Targets = targets,
		Multipliers = ZoneBalance.multipliers(items, tiers, targets, growth),
	}
end

-- ESTIMATIVA do tempo de cada zona (s): soma das etapas, cada uma varrendo a própria área de terra.
function CityProgress.zoneSeconds(
	layout: Layout,
	targets: { number },
	cellSize: number,
	sweep: SweepConfig,
	growth: GrowthConfig
): { number }
	local cells: { number } = {}
	for k = 1, #layout.Steps do
		cells[k] = 0
	end
	for _, step in layout.Grid.Step do
		if step > 0 then
			cells[step] += 1
		end
	end
	local seconds: { number } = {}
	for zone = 1, #layout.ZoneNames do
		seconds[zone] = 0
	end
	for k, step in layout.Steps do
		local from = if k > 1 then targets[k - 1] else growth.BaseScale
		local area = cells[k] * cellSize * cellSize
		seconds[step.Zone] += ZoneBalance.sweepSeconds(area, from, targets[k], sweep, growth)
	end
	return seconds
end

return CityProgress
