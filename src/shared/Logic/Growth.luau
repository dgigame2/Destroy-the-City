--!strict
-- Regras de crescimento. Funções puras: recebem a configuração e valores, retornam resultados.

export type GrowthConfig = {
	BaseScale: number,
	ScalePerSqrtPoint: number,
	MaxScale: number,
	BaseEatRadius: number,
	PlayerEatRatio: number,
	PlayerEatGainFraction: number,
	RespawnKeepFraction: number,
}

export type Tier = {
	RequiredScale: number,
	Growth: number,
	Coins: number,
}

local Growth = {}

function Growth.scaleFromPoints(points: number, config: GrowthConfig): number
	assert(points >= 0, "points deve ser >= 0")
	local scale = config.BaseScale + config.ScalePerSqrtPoint * math.sqrt(points)
	return math.min(scale, config.MaxScale)
end

-- Inverso de scaleFromPoints (sem considerar o teto).
function Growth.pointsForScale(scale: number, config: GrowthConfig): number
	if scale <= config.BaseScale then
		return 0
	end
	return ((scale - config.BaseScale) / config.ScalePerSqrtPoint) ^ 2
end

function Growth.canEatTier(scale: number, tier: Tier): boolean
	return scale >= tier.RequiredScale
end

function Growth.eatRadius(scale: number, magnetBonus: number, config: GrowthConfig): number
	return config.BaseEatRadius * scale * (1 + magnetBonus)
end

function Growth.canEatPlayer(eaterScale: number, victimScale: number, config: GrowthConfig): boolean
	return eaterScale >= victimScale * config.PlayerEatRatio
end

function Growth.gainFromTier(tier: Tier, growthBonus: number): number
	return tier.Growth * (1 + growthBonus)
end

function Growth.coinsFromTier(tier: Tier, coinBonus: number): number
	return math.max(1, math.floor(tier.Coins * (1 + coinBonus) + 0.5))
end

function Growth.gainFromPlayer(victimPoints: number, config: GrowthConfig): number
	return victimPoints * config.PlayerEatGainFraction
end

function Growth.respawnPoints(points: number, config: GrowthConfig): number
	return points * config.RespawnKeepFraction
end

-- Índice do maior tier que a escala permite comer (0 se nenhum).
function Growth.highestEdibleTier(scale: number, tiers: { Tier }): number
	local highest = 0
	for index, tier in tiers do
		if Growth.canEatTier(scale, tier) then
			highest = index
		end
	end
	return highest
end

return Growth
