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
})
