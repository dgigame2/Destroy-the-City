--!strict
-- Lobby: ilha flutuante alta, de frente para a cidade (+Z aponta para o centro do mapa).
-- Posição fixa, calculada para ficar além dos paredões do maior mapa.

return table.freeze({
	FloorHeight = 450, -- altura do gramado do lobby (studs)
	Width = 240, -- X
	Depth = 180, -- Z
	-- centro do lobby em Z (negativo = antes da borda -Z do mapa). Maior mapa: meia-largura 435 + margem 60
	-- + paredões 90 = 585; mais folga e metade da ilha.
	CenterZ = -(585 + 60 + 90),
	SpawnRadius = 18,
	FallKillHeight = 300, -- caiu abaixo disso estando no lobby: volta para o lobby
	WheelRadius = 14, -- raio da roleta física (a janela da roleta usa para encaixar os nomes dos prêmios)
	WheelSubSlices = 6, -- cada fatia é feita de 6 triângulos: a borda fica redonda
	ShopRingRadius = 5, -- anel de traços neon na frente da loja (indicador de compra)
	ShopRingDashes = 14,
	ShopRingSpin = 25, -- graus por segundo
	PromptDistance = 18, -- distância para o "E" das placas, loja e roleta aparecer
	-- Área "START A RUN" na frente da ilha (+Z): quadrados no chão com uma placa atrás de cada um.
	RunArea = table.freeze({
		PadSize = 16, -- lado do quadrado (com a borda neon)
		Border = 1, -- largura da borda neon
		PadSpacing = 22, -- distância entre centros (sobra 6 de grama entre eles)
		PadZ = 68, -- centro dos quadrados em Z
		PadHeight = 0.4, -- espessura do piso do quadrado
		DetectHeight = 14, -- até essa altura acima do quadrado o jogador conta como "em cima"
		BoardWidth = 14,
		BoardHeight = 8,
		BoardBottom = 3,
		BoardZ = 81, -- placa de cada quadrado, atrás dele (lado da borda da ilha)
		Post = 1.4,
		SignWidth = 80,
		SignHeight = 9,
		SignBottom = 15,
		SignZ = 86, -- placa grande "START A RUN"
		ExitBack = 12, -- quem sai à força do quadrado vai para tantos studs na frente dele (-Z)
	}),
})
