--!strict
-- Crescimento do jogador. Os pontos de crescimento ficam só no servidor; o jogador vê apenas o próprio tamanho.

return table.freeze({
	-- Escala do personagem = BaseScale + ScalePerSqrtPoint * sqrt(pontos)
	BaseScale = 1,
	ScalePerSqrtPoint = 0.2,
	-- Teto: acima do tamanho para comer o maior marco (16). Personagens muito maiores (~29x+) fazem o Studio
	-- parar de renderizar.
	MaxScale = 26,

	-- Só reescala o personagem quando a escala muda mais que isso (evita custo de ScaleTo a cada mordida).
	RescaleStep = 0.03,

	-- Raio de "boca" (studs) em escala 1; cresce junto com a escala.
	BaseEatRadius = 4,
})
