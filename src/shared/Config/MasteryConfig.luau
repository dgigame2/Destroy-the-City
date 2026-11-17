--!strict
-- Nível de cada desastre (Logic/Mastery + server/MasteryService). Substitui os contratos.
-- Quanto mais você usa um desastre, mais ele sobe de nível: cada construção que ELE derruba dá XP para ele
-- (XpByTier pelo tamanho da construção). O que cai na reação em cadeia dá ChainXp do XP para o desastre que
-- começou a cadeia. Cada nível deixa o desastre mais forte (Damage) e maior (Size); o raio também ganha
-- pulos e o tornado dura mais (Extras). No nível 1 o desastre é exatamente o do DisasterConfig.
-- O nível vale para a run (igual ao poder): começa em 1 em cada partida.

return table.freeze({
	MaxLevel = 30,
	-- XP para passar do nível L para o L+1 = BaseXp x Growth ^ (L - 1)
	BaseXp = 15,
	Growth = 1.3,
	XpByTier = table.freeze({ 1, 2, 4, 7, 12, 20, 35 }),
	ChainXp = 0.5,
	-- bônus por nível acima do 1 (0.05 = +5% de dano por nível)
	PerLevel = table.freeze({ Damage = 0.05, Size = 0.012 }),
	Extras = table.freeze({
		Lightning = table.freeze({ HopsEvery = 10 }), -- +1 pulo a cada 10 níveis (zap continua focado)
		Tornado = table.freeze({ DurationPerLevel = 0.1 }), -- +0,1 s por nível
	}),
})
