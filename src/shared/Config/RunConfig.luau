--!strict
-- Partida: a party destrói a cidade inteira (sem tempo). 100% destruído = vitória.
-- O resto dos números da partida fica em MatchConfig.

return table.freeze({
	WinGems = 50, -- gemas da vitória (multiplicadas pela dificuldade). PROVISÓRIO (AUDITORIA §11)
	-- No Studio não existe teleporte: a partida começa direto com estas opções (e não é salva)
	Studio = table.freeze({ Map = "GardenVillage", Difficulty = "Normal" }),
})
