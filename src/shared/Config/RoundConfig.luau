--!strict
-- Duração e regras das partidas.

return table.freeze({
	IntermissionSeconds = 20, -- tempo no lobby antes de cada partida
	RoundSeconds = 300, -- 5 minutos
	WinnerScreenSeconds = 6,
	VoteSeconds = 15,
	VoteOptions = 3,
	RegenSeconds = 30, -- tempo para uma construção comida reaparecer
	MinPlayersToStart = 1,
	EatTickSeconds = 0.1, -- intervalo do loop de comer no servidor
	MaxEatsPerTick = 4, -- limita mordidas por tick por jogador (ritmo do efeito)
})
