--!strict
-- Crescimento do jogador. Os pontos de crescimento ficam só no servidor; o jogador vê apenas o próprio tamanho.

return table.freeze({
	-- Escala do personagem = BaseScale + ScalePerSqrtPoint * sqrt(pontos)
	BaseScale = 1,
	ScalePerSqrtPoint = 0.2,
	-- Teto: pouco acima do maior WinScale. Personagens muito maiores (~29x+) fazem o Studio parar de renderizar.
	MaxScale = 26,

	-- Só reescala o personagem quando a escala muda mais que isso (evita custo de ScaleTo a cada mordida).
	RescaleStep = 0.03,

	-- Raio de "boca" (studs) em escala 1; cresce junto com a escala.
	BaseEatRadius = 4,

	-- Comer outro jogador: precisa ser pelo menos X vezes maior que ele.
	PlayerEatRatio = 1.25,
	-- Fração dos pontos da vítima que o predador ganha.
	PlayerEatGainFraction = 0.5,
	-- Fração dos pontos que o jogador engolido mantém ao renascer.
	RespawnKeepFraction = 0.35,
})
