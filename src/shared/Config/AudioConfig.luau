--!strict
-- Sons do jogo (Creator Store, gratuitos). Volume e pitch ajustados para o efeito de comer.

return table.freeze({
	Bite = { Id = "rbxassetid://9125467298", Volume = 0.6 }, -- mordida curta (ProSoundEffects)
	Pop = { Id = "rbxassetid://109359226723492", Volume = 0.35 }, -- cada bloco engolido
	Coin = { Id = "rbxassetid://135483737426662", Volume = 0.35 },
	TierUp = { Id = "rbxassetid://134821092416328", Volume = 0.6 }, -- desbloqueou construções maiores
	Gulp = { Id = "rbxassetid://102367379211988", Volume = 0.8 }, -- comeu um jogador
	-- Combo: cada mordida seguida sobe o pitch um pouco (sensação de "subindo").
	ComboPitchStep = 0.04,
	ComboPitchMax = 1.6,
	ComboWindowSeconds = 1.5,
	MaxPopsPerSecond = 18, -- evita barulho excessivo quando muitos blocos chegam juntos
})
