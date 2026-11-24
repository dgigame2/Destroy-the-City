--!strict
-- O jogador é um tornado. Números do crescimento (fórmulas em Logic/Tornado, testadas no Lune).
-- Calibragem (Garden Village, escala 1 [MEDIDO]): 2442 objetos; metade são props com vida 20;
-- casas/prédios de 20 a ~2456 de vida.
--   Nível 1: raio 6, 30 de dano/s  -> prop cai em < 1 s, casa pequena (~60) em ~2 s.
--   Nível 15: raio ~28, ~1.360 de dano/s -> o maior prédio cai em ~2 s.
-- Nível máximo: MaxLevels[rebirths + 1]; cada rebirth libera mais níveis que o anterior (decisão do usuário, 23/11).
-- Subir de nível é na mão: a barra enche, o XP continua juntando e o jogador aperta EVOLVE (R), que sobe todos os níveis pagos.

return table.freeze({
	MaxLevels = table.freeze({ 15, 17, 20, 24, 29 }), -- por quantidade de rebirths (0 a 4)
	Tick = 0.2, -- segundos entre cada checagem de contato (servidor)
	MaxTargets = 24, -- construções atingidas por tick, no máximo

	-- XP da barra de cada nível. Meta por ciclo: 15, 20, 30, 45 e 70 min (3 h no total).
	-- Conta: minutos da barra x XP/min do nível x bônus do ciclo em que o nível estreia (`lune run xprate`).
	Xp = table.freeze({
		-- sem rebirth (1 a 15)
		31,
		43,
		58,
		80,
		109,
		148,
		205,
		281,
		383,
		523,
		716,
		978,
		1183,
		1344,
		1533,
		-- 1 rebirth (16 e 17)
		8050,
		12075,
		-- 2 rebirths (18 a 20)
		25700,
		30400,
		37400,
		-- 3 rebirths (21 a 24)
		55800,
		65100,
		74400,
		83700,
		-- 4 rebirths (25 a 29)
		174000,
		197000,
		220000,
		243000,
		267000,
	}),
	-- XP de cada objeto destruído = valor da construção + PropXp (props valem 0 de valor e dão só isto)
	PropXp = 0.4,

	-- EVOLVE: segundos da animação e da proteção. FormSeconds = virou outra forma (o tornado para).
	-- Durante a animação não leva nem dá dano em jogadores; continua destruindo a cidade.
	Evolve = table.freeze({
		Seconds = 0.6,
		FormSeconds = 1.2,
		ChangeAt = 0.75, -- fração da animação em que a forma nova aparece
		SpinBoost = 3,
		WindStart = 2, -- o vento vem de fora (múltiplos do raio) e fecha no tornado
		Flash = 0.5, -- segundos do clarão (forma nova e rebirth)
	}),

	-- Crescimento por nível (L-1 vezes o passo)
	Radius = table.freeze({ Base = 6, Step = 1.6 }), -- studs
	Dps = table.freeze({ Base = 30, Growth = 1.25 }), -- dano por segundo
	WalkSpeed = table.freeze({ Base = 16, Step = 0.8 }),
	RootToGround = 3, -- studs entre a raiz do personagem e o pé do funil

	Camera = table.freeze({
		Padding = 1.08,
		MinMaxDistance = 160,
		MaxDistanceScale = 1.35,
		TransitionSeconds = 0.55,
	}),

	Visual = table.freeze({
		StormTint = table.freeze({ 23, 25, 33 }),
		SmokeTint = 0.76,
		CloudTint = 0.87,
		SmokeTransparency = 0.08,
		CloudTransparency = 0.12,
		BandEdgeTransparency = 0.16,
		BandCenterTransparency = 0.04,
		SmokeLightInfluence = 0.28,
		BandWidthAtBase = 0.4,
		BandWidthAtTop = 1.3,
		BandSegments = 12, -- escala com o tier de qualidade
		BandCurve = 0.15,
		ContourWidthScale = 0.45,
		ContourEdgeTransparency = 0.65,
		ContourCenterTransparency = 0.27,
		OrbitRadiusScale = 0.52,
		SmokeWidthScale = 1.7,
		CoreWidthScale = 1.56,
		CoreTransparency = 0.11,
		CoreEdgeTransparency = 0.38,
		CameraClearEnter = 1.25,
		CameraClearExit = 1.5,
		CameraClearTransparency = 0.86,
	}),

	RebirthFx = table.freeze({
		Colors = table.freeze({
			table.freeze({ From = 1, Color = table.freeze({ 78, 241, 128 }) }),
			table.freeze({ From = 2, Color = table.freeze({ 28, 150, 255 }) }),
			table.freeze({ From = 3, Color = table.freeze({ 174, 78, 255 }) }),
			table.freeze({ From = 4, Color = table.freeze({ 255, 195, 40 }) }),
		}),
		Heights = table.freeze({ 0.12, 0.30, 0.48, 0.67, 0.85 }),
		Arc = math.rad(175),
		Stagger = math.rad(92),
		Rise = 0.085,
		Width = 0.021, -- fraction of funnel height
		TipWidth = 0.16,
		BaseRadius = 0.15,
		Clearance = 1.10,
		Segments = 10,
		Spin = 1.7, -- radians per second
	}),

	BurstWind = table.freeze({
		Seconds = 0.32,
		Bands = 2,
		Segments = 8,
		Arc = 1.35, -- radianos por fita
		Sweep = 4.8, -- radianos percorridos durante a rajada
		RadiusStart = 0.55,
		RadiusEnd = 1.28,
		HeightStart = 0.12,
		HeightEnd = 0.54,
		AimDrift = 0.42,
		Width = 0.30,
		TailWidth = 0.32,
		EdgeColor = table.freeze({ 65, 104, 148 }),
		CenterColor = table.freeze({ 223, 247, 255 }),
	}),

	-- Rebirth: volta ao nível 1; cada um multiplica o XP por XpFactor (2x, 4x, 8x, 16x), dá +10% de dano
	-- e aumenta o nível máximo
	Rebirth = table.freeze({ XpFactor = 2, DamageBonus = 0.1 }),

	-- Medidas da forma visual em múltiplos do raio. Spin em voltas/s, Twist em radianos.
	Forms = table.freeze({
		table.freeze({
			From = 1,
			Name = "Breeze",
			Color = { 135, 190, 220 },
			Height = 1.55,
			Base = 0.12,
			Top = 0.55,
			Bend = 0.22,
			Crown = 0,
			Density = 0.52,
			Spin = 0.95,
			Twist = 2.1,
			Bands = 2,
		}),
		table.freeze({
			From = 4,
			Name = "Dust Devil",
			Color = { 204, 147, 89 },
			Height = 2.7,
			Base = 0.23,
			Top = 0.48,
			Bend = 0.18,
			Crown = 0.65,
			Density = 0.72,
			Spin = 1.8,
			Twist = 3.45,
			Bands = 2,
		}),
		table.freeze({
			From = 8,
			Name = "Tornado",
			Color = { 117, 139, 165 },
			Height = 2.6,
			Base = 0.18,
			Top = 0.96,
			Bend = 0.08,
			Crown = 1.8,
			Density = 0.88,
			Spin = 1.5,
			Twist = 2.85,
			Bands = 3,
		}),
		table.freeze({
			From = 12,
			Name = "Supertornado",
			Color = { 105, 111, 155 },
			Height = 2.85,
			Base = 0.5,
			Top = 0.84,
			Bend = 0.08,
			Crown = 1.65,
			Density = 0.96,
			Spin = 1.3,
			Twist = 2.45,
			Bands = 3,
		}),
		table.freeze({
			From = 15,
			Name = "Hurricane",
			Color = { 65, 97, 170 },
			Height = 1.8,
			Base = 0.42,
			Top = 1,
			Bend = 0,
			Crown = 2.2,
			Density = 1,
			Spin = 1.1,
			Twist = 2.95,
			Bands = 3,
		}),
		table.freeze({
			From = 19,
			Name = "Typhoon",
			Color = { 64, 202, 213 },
			Height = 2.25,
			Base = 0.26,
			Top = 0.95,
			Bend = 0.18,
			Crown = 1.65,
			Density = 0.94,
			Spin = 1.65,
			Twist = 3.15,
			Bands = 3,
		}),
		table.freeze({
			From = 23,
			Name = "Firenado",
			Color = { 247, 114, 39 },
			Height = 2.9,
			Base = 0.36,
			Top = 0.67,
			Bend = 0.14,
			Crown = 1,
			Density = 0.85,
			Spin = 1.95,
			Twist = 3.75,
			Bands = 3,
		}),
		table.freeze({
			From = 27,
			Name = "Void Storm",
			Color = { 144, 74, 207 },
			Height = 2.6,
			Base = 0.62,
			Top = 1,
			Bend = 0.05,
			Crown = 2.2,
			Density = 1,
			Spin = 1.25,
			Twist = 3.2,
			Bands = 3,
		}),
	}),
})
