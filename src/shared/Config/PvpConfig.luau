--!strict
-- PvP entre tornados. Fórmulas em Logic/Pvp (testadas no Lune); servidor em server/Match/PvpService.
-- Vida = Hp.Base * Hp.Growth^(nível-1): nível 1 = 100, nível 16 = ~1.540.

return table.freeze({
	Hp = table.freeze({ Base = 100, Growth = 1.2 }),

	-- Rajada (clique / botão no celular): cone na frente do tornado
	Burst = table.freeze({
		Cooldown = 0.6, -- segundos (conferido no servidor)
		Reach = 1.5, -- alcance = raio do tornado x isto + ReachExtra
		ReachExtra = 6,
		MinDot = 0.5, -- cone de ~120°
		HpShare = 0.12, -- dano em tornados = 12% da vida máxima de QUEM ataca (igual contra igual: ~9 rajadas)
		CitySeconds = 0.6, -- dano em construções = este tanto de segundos do dano passivo
	}),

	-- Skills (Q) de cada forma: Config/SkillConfig.

	-- Escudo (ninguém dá dano): ao nascer e ao subir de nível. Atacar tira o próprio escudo.
	Shield = table.freeze({ Spawn = 5, LevelUp = 2 }),

	-- Regenera fora de combate: Share da vida máxima por segundo, depois de Delay segundos sem levar dano
	Regen = table.freeze({ Delay = 4, Share = 0.05 }),

	-- Quem mata ganha este tanto da barra de XP do nível da vítima
	KillXpShare = 0.25,
})
