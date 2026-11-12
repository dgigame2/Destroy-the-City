-- Todos os números de economia do jogo ficam aqui.
local EconomyConfig = {
	StartingCoins = 0,
	BaseUpgradeCost = 10,
	UpgradeCostGrowth = 1.15,
}

return table.freeze(EconomyConfig)
