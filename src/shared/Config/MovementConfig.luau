--!strict
-- Todos os números de movimento do jogador ficam aqui.

return table.freeze({
	WalkSpeed = 16, -- studs/s em tamanho 1 (padrão Roblox)
	JumpPower = 50, -- padrão Roblox (UseJumpPower = true)
	Gravity = 196.2, -- studs/s² (padrão Workspace.Gravity)
	-- Quanto velocidade e pulo crescem com o tamanho: valor = base * escala ^ expoente.
	-- Menor que 1 para gigantes não atravessarem o mapa em 1 segundo.
	SpeedScaleExponent = 0.45,
	JumpScaleExponent = 0.5,
	RespawnSeconds = 3,
})
