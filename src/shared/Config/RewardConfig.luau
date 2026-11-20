--!strict
-- Recompensas de login. Diária: sequência de 7 dias (perder um dia volta ao dia 1).
-- Semanal: uma vez por semana (a semana vira na segunda-feira, horário UTC).
-- Só gemas (moeda permanente) por enquanto: a roleta e os boosts saíram (AUDITORIA D3). Os valores são
-- PROVISÓRIOS até a economia permanente da Etapa 7 (AUDITORIA §11).

export type Reward = { Kind: string, Amount: number?, Id: string?, Label: string, Icon: string }

local daily: { Reward } = {
	{ Kind = "Gems", Amount = 5, Label = "5 Gems", Icon = "💎" },
	{ Kind = "Gems", Amount = 10, Label = "10 Gems", Icon = "💎" },
	{ Kind = "Gems", Amount = 15, Label = "15 Gems", Icon = "💎" },
	{ Kind = "Gems", Amount = 20, Label = "20 Gems", Icon = "💎" },
	{ Kind = "Gems", Amount = 25, Label = "25 Gems", Icon = "💎" },
	{ Kind = "Gems", Amount = 40, Label = "40 Gems", Icon = "💎" },
	{ Kind = "Gems", Amount = 60, Label = "60 Gems", Icon = "💎" },
}

local weekly: { Reward } = {
	{ Kind = "Gems", Amount = 200, Label = "200 Gems", Icon = "💎" },
}

for _, list in { daily, weekly } do
	for _, reward in list do
		table.freeze(reward)
	end
	table.freeze(list)
end

return table.freeze({ Daily = daily, Weekly = weekly })
