--!strict
-- O jogador é um tornado. Números do crescimento (fórmulas em Logic/Tornado, testadas no Lune).
-- Calibragem (Garden Village, escala 1 [MEDIDO]): 2442 objetos; metade são props com vida 20;
-- casas/prédios de 20 a ~2456 de vida.
--   Nível 1: raio 6, 30 de dano/s  -> prop cai em < 1 s, casa pequena (~60) em ~2 s.
--   Nível 15: raio ~28, ~1.360 de dano/s -> o maior prédio cai em ~2 s.
-- Nível máximo: BaseMaxLevel sem rebirth; cada rebirth soma +1, até MaxLevel (decisão do usuário, 20/11).
-- Subir de nível é na mão: a barra enche, o XP continua juntando e o jogador aperta EVOLVE (R).

return table.freeze({
	BaseMaxLevel = 15, -- máximo sem rebirth
	MaxLevel = 30, -- teto absoluto (15 rebirths)
	Tick = 0.2, -- segundos entre cada checagem de contato (servidor)
	MaxTargets = 24, -- construções atingidas por tick, no máximo

	-- XP para passar do nível L para o L+1 = XpBase * XpGrowth^(L-1). Soma até o 15: ~1.900 XP.
	XpBase = 8,
	XpGrowth = 1.38,
	-- XP de cada objeto destruído = valor da construção + PropXp (props valem 0 de valor e dão só isto)
	PropXp = 0.4,

	-- Crescimento por nível (L-1 vezes o passo)
	Radius = table.freeze({ Base = 6, Step = 1.6 }), -- studs
	Dps = table.freeze({ Base = 30, Growth = 1.25 }), -- dano por segundo
	WalkSpeed = table.freeze({ Base = 16, Step = 0.8 }),
	Height = 2.6, -- altura do visual = raio x isto

	-- Rebirth: volta ao nível 1; cada um dá +50% de XP, +10% de dano e +1 no nível máximo
	Rebirth = table.freeze({ XpBonus = 0.5, DamageBonus = 0.1 }),

	-- Formas (nível a partir do qual vale). As 3 últimas só existem com rebirth.
	Forms = table.freeze({
		table.freeze({ From = 1, Name = "Breeze", Color = { 214, 236, 245 } }),
		table.freeze({ From = 4, Name = "Dust Devil", Color = { 222, 196, 150 } }),
		table.freeze({ From = 8, Name = "Tornado", Color = { 150, 160, 175 } }),
		table.freeze({ From = 12, Name = "Supertornado", Color = { 100, 105, 140 } }),
		table.freeze({ From = 15, Name = "Hurricane", Color = { 70, 90, 150 } }),
		table.freeze({ From = 19, Name = "Typhoon", Color = { 60, 170, 190 } }),
		table.freeze({ From = 23, Name = "Firenado", Color = { 255, 120, 40 } }),
		table.freeze({ From = 27, Name = "Void Storm", Color = { 120, 60, 170 } }),
	}),
})
