--!strict
-- Números gerais de economia fora da partida. O dinheiro da partida fica em MatchConfig.Money.
-- DuplicateGems: cosmético que o jogador já tem (prêmio repetido) vira essas gemas, pela raridade.

return table.freeze({
	StartingCoins = 0,
	DuplicateGems = table.freeze({ Common = 25, Rare = 50, Epic = 200, Legendary = 600 }),
})
