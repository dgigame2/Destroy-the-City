-- Lógica pura: não usa nada do Roblox, então dá pra testar no PC com Lune.
local Economy = {}

function Economy.getUpgradeCost(baseCost: number, growth: number, level: number): number
	assert(level >= 0, "level não pode ser negativo")
	return math.floor(baseCost * growth ^ level)
end

function Economy.canAfford(balance: number, cost: number): boolean
	return balance >= cost
end

return Economy
