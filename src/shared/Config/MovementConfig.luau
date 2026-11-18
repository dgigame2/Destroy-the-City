--!strict
-- Todos os números de movimento do jogador ficam aqui.

return table.freeze({
	WalkSpeed = 24, -- studs/s em tamanho 1 (padrão Roblox 16 + 50%)
	-- velocidade em que a animação padrão de andar/correr do Roblox (ritmo 1) tem o pé parado no chão: a
	-- animação toca na proporção velocidade real / isso (MovementController), sem parecer que desliza
	AnimationWalkSpeed = 16,
	-- Pulo só no lobby. Na run não tem pulo (o botão de pulo do celular some com 0).
	-- Os mesmos valores vão para o StarterPlayer nos arquivos do Rojo (default.project.json e run.project.json).
	LobbyJumpPower = 50, -- padrão Roblox (UseJumpPower = true)
	RunJumpPower = 0,
	Gravity = 196.2, -- studs/s² (padrão Workspace.Gravity)
	-- Quanto a velocidade cresce com o tamanho: valor = base * escala ^ expoente.
	-- Menor que 1 para gigantes não atravessarem o mapa em 1 segundo.
	SpeedScaleExponent = 0.45,
	-- ESTIMATIVA: degrau que o Humanoid sobe andando, sem pular (na escala 1). Chão e lobby ficam abaixo disso.
	MaxStepHeight = 1,
	RespawnSeconds = 3,
})
