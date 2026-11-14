--!strict
-- Fórmulas de economia. Funções puras: recebem valores e retornam resultados previsíveis.

local Economy = {}

-- Custo do upgrade ao passar do nível `level` para `level + 1`.
function Economy.upgradeCost(baseCost: number, growth: number, level: number): number
	assert(level >= 0 and level == math.floor(level), "level deve ser inteiro >= 0")
	return math.floor(baseCost * growth ^ level)
end

-- Custo total para ir do nível `fromLevel` até `toLevel`.
function Economy.totalCost(baseCost: number, growth: number, fromLevel: number, toLevel: number): number
	assert(toLevel >= fromLevel, "toLevel deve ser >= fromLevel")
	local total = 0
	for level = fromLevel, toLevel - 1 do
		total += Economy.upgradeCost(baseCost, growth, level)
	end
	return total
end

return Economy
