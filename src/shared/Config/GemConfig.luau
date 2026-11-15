--!strict
-- Gemas: moeda rara (da conta). Caem ao comer construções grandes; a vitória da run dá mais (RunConfig).

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
})
