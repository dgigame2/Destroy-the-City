--!strict
-- Parties no lobby (área "START A RUN"): quadrados no chão; quem pisa num quadrado vazio cria a party.

return table.freeze({
	Pads = 4, -- quantos quadrados existem
	MaxSize = 4, -- jogadores por party (o dono + 3 amigos)
	OpenSeconds = 25, -- depois de criar, a party sai sozinha nesse tempo (mesmo sem lotar)
	FullSeconds = 5, -- quando lota (ou todos da run salva chegam), sai nesse tempo
	LoadWaitSeconds = 60, -- run salva: tempo para todos os membros chegarem no quadrado
	CreateTimeoutSeconds = 60, -- quem está escolhendo as opções perde o quadrado depois disso
	TickSeconds = 0.25, -- frequência da checagem de quem está em cima dos quadrados
	-- cor da borda neon de cada situação do quadrado
	Colors = table.freeze({
		Empty = { 120, 230, 255 },
		Creating = { 255, 210, 70 },
		Open = { 90, 230, 110 },
		Loading = { 190, 120, 255 },
		Departing = { 255, 255, 255 },
	}),
})
