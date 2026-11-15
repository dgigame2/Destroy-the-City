--!strict
-- Ritmo do loop de comer no servidor da run e o indicador de comer do cliente.

return table.freeze({
	EatTickSeconds = 0.1, -- intervalo do loop de comer
	-- teto de segurança por tick (alto o bastante para nada no círculo ficar para trás: até 300 por segundo)
	MaxEatsPerTick = 30,
	-- construções grandes demais no alcance ganham contorno vermelho e "🔒 BIGGER" (no máximo tantas de uma vez)
	MaxLockedHints = 4,
	LockedHintSeconds = 0.25, -- frequência da checagem desse aviso
	AutoCollectSeconds = 1.5, -- a coleta automática do fim da área (RunConfig.AutoCollect) suga tudo nesse tempo
})
