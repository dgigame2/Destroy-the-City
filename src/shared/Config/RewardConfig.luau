--!strict
-- Recompensas de login. Diária: sequência de 7 dias (perder um dia volta ao dia 1).
-- Semanal: uma vez por semana (a semana vira na segunda-feira, horário UTC).

export type Reward = { Kind: string, Amount: number?, Id: string?, Label: string, Icon: string }

local daily: { Reward } = {
	{ Kind = "Gems", Amount = 5, Label = "5 Gems", Icon = "💎" },
	{ Kind = "Gems", Amount = 10, Label = "10 Gems", Icon = "💎" },
	{ Kind = "Gems", Amount = 15, Label = "15 Gems", Icon = "💎" },
	{ Kind = "Spin", Amount = 1, Label = "1 Spin", Icon = "🎡" },
	{ Kind = "Gems", Amount = 25, Label = "25 Gems", Icon = "💎" },
	{ Kind = "Item", Id = "GrowthBoost", Label = "2x Growth", Icon = "📈" },
	{ Kind = "Gems", Amount = 60, Label = "60 Gems", Icon = "💎" },
}

local weekly: { Reward } = {
	{ Kind = "Gems", Amount = 150, Label = "150 Gems", Icon = "💎" },
	{ Kind = "Spin", Amount = 2, Label = "2 Spins", Icon = "🎡" },
}

for _, list in { daily, weekly } do
	for _, reward in list do
		table.freeze(reward)
	end
	table.freeze(list)
end

return table.freeze({ Daily = daily, Weekly = weekly })
