--!strict
-- Balanceamento das áreas e etapas da cidade (puro, testável no Lune).
--
-- A cidade é dividida em zonas (barreiras) e cada zona em etapas (regiões em ordem). Cada etapa tem um
-- tamanho máximo de construção (Cap). Para o jogador nunca precisar "caçar" coisas pequenas no meio das
-- grandes, terminar uma etapa precisa deixá-lo grande o bastante para comer TUDO da próxima, mesmo na
-- dificuldade que cresce mais devagar. Por isso cada etapa tem um tamanho-alvo para o fim dela, e o
-- crescimento de cada construção é o Growth do tier vezes um multiplicador da etapa, calculado para que
-- comer a etapa inteira leve exatamente do alvo anterior ao alvo dela (na dificuldade normal).
--
-- Tempo: estimativa de "varrer" a área com o círculo de comer. Ver ZoneBalance.sweepSeconds.

local ZoneBalance = {}

type Tier = { RequiredScale: number, Growth: number }
type GrowthConfig = { BaseScale: number, ScalePerSqrtPoint: number, MaxScale: number }
type Item = { Step: number, Tier: number }

local function pointsFor(scale: number, cfg: GrowthConfig): number
	if scale <= cfg.BaseScale then
		return 0
	end
	return ((scale - cfg.BaseScale) / cfg.ScalePerSqrtPoint) ^ 2
end

local function scaleFor(points: number, cfg: GrowthConfig): number
	return math.min(cfg.BaseScale + cfg.ScalePerSqrtPoint * math.sqrt(math.max(points, 0)), cfg.MaxScale)
end

-- Tamanho (dificuldade normal) que garante comer `tier` na dificuldade com crescimento `worstGrowth`,
-- com folga `margin` (1.06 = 6% a mais). Na dificuldade lenta os pontos são worstGrowth vezes os normais.
function ZoneBalance.scaleToEat(tier: Tier, worstGrowth: number, margin: number, cfg: GrowthConfig): number
	local needed = pointsFor(cfg.BaseScale + (tier.RequiredScale - cfg.BaseScale) * margin, cfg) / worstGrowth
	return scaleFor(needed, cfg)
end

-- Alvo do fim de cada etapa: o tamanho para comer tudo da etapa seguinte; a última termina em finalScale.
-- caps[k] = maior tier da etapa k. Os alvos sempre crescem (no mínimo minGrowth, em fração, por etapa).
function ZoneBalance.stepTargets(
	caps: { number },
	tiers: { Tier },
	worstGrowth: number,
	margin: number,
	finalScale: number,
	minGrowth: number,
	cfg: GrowthConfig
): { number }
	local targets = {}
	local previous = cfg.BaseScale
	for k = 1, #caps do
		local target = if k < #caps
			then ZoneBalance.scaleToEat(tiers[caps[k + 1]], worstGrowth, margin, cfg)
			else finalScale
		target = math.max(target, previous * (1 + minGrowth))
		targets[k] = target
		previous = target
	end
	return targets
end

-- Multiplicador de crescimento de cada etapa. targets[k] = tamanho no fim da etapa k (dificuldade normal).
function ZoneBalance.multipliers(items: { Item }, tiers: { Tier }, targets: { number }, cfg: GrowthConfig): { number }
	local raw: { number } = {}
	for k = 1, #targets do
		raw[k] = 0
	end
	for _, item in items do
		raw[item.Step] += tiers[item.Tier].Growth
	end
	local result = {}
	local previous = 0
	for k, target in targets do
		local points = pointsFor(target, cfg)
		result[k] = if raw[k] > 0 then math.max(points - previous, 0) / raw[k] else 0
		previous = points
	end
	return result
end

-- Entry = tamanho ao entrar na etapa; Exit = ao terminar; Biggest = maior tier dela;
-- Stuck = tier que não deu para comer na entrada (a etapa tem algo grande demais para quem chega).
export type StepReport = { Entry: number, Exit: number, Biggest: number, Stuck: number? }

-- Simula um jogador (a party cresce junto, então um basta) comendo etapa por etapa.
-- Exige que, ao ENTRAR numa etapa, tudo dela já caiba (é o que deixa varrer a região sem caçar).
-- growthFactor = dificuldade (e bônus). Devolve se terminou e o relatório de cada etapa.
function ZoneBalance.simulate(
	items: { Item },
	tiers: { Tier },
	multipliers: { number },
	growthFactor: number,
	cfg: GrowthConfig
): (boolean, { StepReport })
	local byStep: { { number } } = {}
	for k = 1, #multipliers do
		byStep[k] = {}
	end
	for _, item in items do
		table.insert(byStep[item.Step], item.Tier)
	end
	local points = 0
	local reports: { StepReport } = {}
	for k, list in byStep do
		local entry = scaleFor(points, cfg)
		local biggest = 0
		for _, tier in list do
			biggest = math.max(biggest, tier)
		end
		local report: StepReport = { Entry = entry, Exit = 0, Biggest = biggest, Stuck = nil }
		if biggest > 0 and entry < tiers[biggest].RequiredScale then
			report.Stuck = biggest
			report.Exit = entry
			table.insert(reports, report)
			return false, reports
		end
		for _, tier in list do
			points += tiers[tier].Growth * multipliers[k] * growthFactor
		end
		report.Exit = scaleFor(points, cfg)
		table.insert(reports, report)
	end
	return true, reports
end

export type SweepConfig = {
	BaseEatRadius: number, -- raio de comer na escala 1 (GrowthConfig)
	WalkSpeed: number, -- velocidade na escala 1 (MovementConfig)
	SpeedScaleExponent: number,
	Efficiency: number, -- ESTIMATIVA: fração do tempo varrendo área nova (curvas, voltas, desvios)
}

-- ESTIMATIVA do tempo (s) para varrer `area` studs² crescendo de `fromScale` até `toScale`.
-- Andando, o círculo de comer (raio r = BaseEatRadius·escala) limpa uma faixa de 2r de largura a
-- v = WalkSpeed·escala^expoente: 2·r·v studs² por segundo, vezes a eficiência. O crescimento é
-- proporcional à área comida (pontos lineares na área), então a escala sobe como √ da área.
function ZoneBalance.sweepSeconds(
	area: number,
	fromScale: number,
	toScale: number,
	sweep: SweepConfig,
	cfg: GrowthConfig
): number
	local p0, p1 = pointsFor(fromScale, cfg), pointsFor(toScale, cfg)
	local samples = 64
	local sum = 0
	for i = 0, samples - 1 do
		local scale = scaleFor(p0 + (p1 - p0) * (i + 0.5) / samples, cfg)
		local rate = 2 * sweep.BaseEatRadius * scale * sweep.WalkSpeed * scale ^ sweep.SpeedScaleExponent
		sum += 1 / (rate * sweep.Efficiency)
	end
	return area * sum / samples
end

return ZoneBalance
