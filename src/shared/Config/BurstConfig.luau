--!strict
-- Resumo por golpe (Logic/Burst + client/Controllers/BurstController): em vez de um número por objeto, a
-- leva inteira de destruição (desastre + cadeia + destroços) vira UM aviso grande quando ela acaba:
-- "MASSIVE! 23 DESTROYED" e o dinheiro somado. Quanto mais coisa caiu, maior a faixa.
--
-- Quiet = segundos sem nada cair para a leva acabar. Tiers = faixas pelo número de objetos (da menor para a
-- maior); abaixo da primeira não aparece nada (golpe pequeno já tem o combo).

export type Tier = { Min: number, Text: string, Color: { number } }

return table.freeze({
	Quiet = 0.7,
	Tiers = table.freeze({
		table.freeze({ Min = 8, Text = "SMASH!", Color = { 255, 214, 90 } }),
		table.freeze({ Min = 16, Text = "MASSIVE!", Color = { 255, 150, 60 } }),
		table.freeze({ Min = 30, Text = "DEVASTATION!", Color = { 255, 90, 70 } }),
		table.freeze({ Min = 60, Text = "APOCALYPSE!", Color = { 214, 110, 255 } }),
	}),
})
