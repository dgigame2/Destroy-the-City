--!strict
-- Gemas: moeda rara. Caem ao comer construções grandes, ao vencer e ao terminar partidas.

return table.freeze({
	-- Por tier (mesmo índice do TierConfig): chance de cair gema e quantidade.
	DropByTier = table.freeze({
		{ Chance = 0, Amount = 0 },
		{ Chance = 0, Amount = 0 },
		{ Chance = 0.03, Amount = 1 },
		{ Chance = 0.08, Amount = 1 },
		{ Chance = 0.2, Amount = 2 },
		{ Chance = 0.5, Amount = 3 },
		{ Chance = 1, Amount = 10 },
	}),
	WinGems = 25, -- vencedor da partida
	PlayedRoundGems = 3, -- quem estava na partida quando ela terminou
})
