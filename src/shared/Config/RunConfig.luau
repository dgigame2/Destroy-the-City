--!strict
-- Runs: a party come a cidade inteira (sem tempo). Comer tudo = vitória.

return table.freeze({
	SaveEverySeconds = 60, -- salva a run sozinha nesse intervalo (e ao sair)
	SavedRunDays = 7, -- run salva some depois de tantos dias parada
	MaxSavedRuns = 5, -- quantas runs salvas cada conta guarda (as mais antigas saem)
	WinGems = 50, -- gemas da vitória (multiplicadas pela dificuldade)
	VictorySeconds = 8, -- tela de vitória antes de voltar ao lobby
	RevealRemaining = 25, -- quando faltam tantas construções na zona atual, elas ficam destacadas para achar
	-- Coleta automática: comeu At (98%) da área atual -> o resto da área é sugado sozinho.
	-- Na tela a porcentagem é mostrada em escala, então At aparece como ShowAs (95%).
	AutoCollect = table.freeze({ At = 0.98, ShowAs = 0.95 }),
	-- Prêmio ao limpar uma área da cidade (zona): gemas x número da zona x dificuldade, dinheiro x zona²,
	-- e um FRENZY: tudo que a party come rende FrenzyMultiplier vezes (crescimento e dinheiro) por um tempo.
	ZoneRewards = table.freeze({ GemsPerZone = 5, CashPerZone = 60, FrenzySeconds = 20 }),
	FrenzyMultiplier = 2,
	ZoneCelebrationSeconds = 4, -- tempo da comemoração na tela antes da barreira cair
	-- No Studio não existe teleporte: a run começa direto com estas opções (e não é salva)
	Studio = table.freeze({ Map = "GardenVillage", Difficulty = "Normal" }),
})
