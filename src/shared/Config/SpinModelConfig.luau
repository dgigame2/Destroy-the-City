--!strict
-- Tornados feitos em peças (assets/blender). Cada peça gira no PRÓPRIO eixo: nenhum lado pesa mais.
--   Height: altura do modelo. Profile: {altura 0..1, raio}. Origin: eixo da peça. Center: centro da malha em relação ao eixo.
--   Speed: múltiplo do giro do corpo (só múltiplos de 0.5, para o ciclo fechar sem salto).
-- Medidas em unidades do modelo do Blender; o jogo escala pelo tamanho do tornado.

export type Piece = { Origin: { number }, Center: { number }, Speed: number }
export type Model = {
	Light: { number },
	Tint: { number },
	DustColor: { number },
	Height: number,
	Profile: { { number } },
	Pieces: { [string]: Piece },
}

export type Jet = {
	T: number,
	Radius: number,
	Turns: number,
	Out: number,
	Up: number,
	Rate: number,
	Move: number,
	Seconds: number,
	Speed: number,
	Squash: number,
	Size: { { number } },
	Alpha: { { number } },
	Dust: boolean,
}

local models: { [string]: Model } = {
	Breeze = {
		Light = { 235, 245, 252 },
		Tint = { 150, 200, 230 },
		DustColor = { 214, 222, 224 },
		Height = 4.7,
		Profile = {
			{ 0, 0.05 },
			{ 0.08, 0.12 },
			{ 0.2, 0.23 },
			{ 0.35, 0.39 },
			{ 0.5, 0.58 },
			{ 0.65, 0.82 },
			{ 0.8, 1.08 },
			{ 0.92, 1.3 },
			{ 1, 1.36 },
		},
		Pieces = {
			Seg1 = { Origin = { -0.0038, 0.3055, 0.0006 }, Center = { -0.0016, -0.0153, -0.0012 }, Speed = 2 },
			Seg2 = { Origin = { -0.0661, 0.94, 0.0124 }, Center = { -0.0039, 0.0115, -0.0021 }, Speed = 1.5 },
			Seg3 = { Origin = { -0.1201, 1.6215, 0.0409 }, Center = { -0.0058, 0.0123, 0.0036 }, Speed = 1.5 },
			Seg4 = { Origin = { 0, 2.35, 0.06 }, Center = { 0.0024, 0.0131, 0.0111 }, Speed = 1 },
			Seg5 = { Origin = { 0.1492, 3.1725, 0.0512 }, Center = { 0.0189, 0.0155, 0.0018 }, Speed = 1 },
			Seg6 = { Origin = { 0.102, 4.1595, 0.0212 }, Center = { 0.0217, 0.0754, 0.0074 }, Speed = 1 },
			Wind1 = { Origin = { 0, 4.7, 0 }, Center = { 0.0038, -0.0574, 0.0401 }, Speed = 0.5 },
			Wind2 = { Origin = { 0.117, 2.914, 0.0558 }, Center = { 0.0133, -0.1172, -0.0357 }, Speed = 1 },
			Wind3 = { Origin = { -0.1178, 1.41, 0.0315 }, Center = { -0.0352, 0, -0.0098 }, Speed = 1 },
		},
	},
}

return table.freeze({
	Models = table.freeze(models),
	MaxDistance = 260, -- studs: além disso o vento desliga (o corpo continua)
	PieceTilt = 0.9, -- quanto cada peça inclina junto com a curva do corpo
	-- corpo: onda em espiral + topo que atrasa ao andar (Logic/TornadoSway)
	Sway = table.freeze({
		Wave = 0.17,
		WaveSpeed = 2.6,
		MoveWave = 0.8,
		Lean = 0.5,
		Stiffness = 45,
		Damping = 5.5,
	}),
	-- fitas que sobem em espiral (múltiplos de 3). Reach/Gap: distância do corpo. Climb: segundos do pé ao topo
	Ribbon = table.freeze({
		Own = 9,
		Others = 6,
		Seconds = 0.35,
		Climb = 2.4,
		Turns = 4,
		Reach = 1.08,
		Gap = 0.1,
		Size = 0.3,
		Alpha = { { 0, 0.3 }, { 0.6, 0.6 }, { 1, 1 } },
		Width = { { 0, 0.3 }, { 0.2, 1 }, { 1, 0 } },
	}),
	-- trios de jatos que rodam em volta e atiram poeira/vento em espiral (nunca um disco parado = aura).
	--   T: altura 0..1. Radius: unidades. Turns: voltas/s. Out/Up: quanto o jato abre e sobe. Move: extra andando.
	Jets = {
		{ -- poeira do pé
			T = 0.02,
			Radius = 0.35,
			Turns = 1.4,
			Out = 0.4,
			Up = 0.06,
			Rate = 14,
			Move = 1.2,
			Seconds = 0.8,
			Speed = 2.4,
			Squash = 0,
			Size = { { 0, 0.25 }, { 0.3, 0.7 }, { 1, 1.25 } },
			Alpha = { { 0, 1 }, { 0.12, 0.2 }, { 1, 1 } },
			Dust = true,
		},
		{ -- meio do corpo
			T = 0.5,
			Radius = 0.7,
			Turns = 0.8,
			Out = 0.1,
			Up = 0,
			Rate = 6,
			Move = 0.5,
			Seconds = 0.6,
			Speed = 2.2,
			Squash = 1,
			Size = { { 0, 0.25 }, { 0.4, 0.75 }, { 1, 0.25 } },
			Alpha = { { 0, 1 }, { 0.25, 0.35 }, { 1, 1 } },
			Dust = false,
		},
		{ -- boca
			T = 0.98,
			Radius = 1.4,
			Turns = 0.6,
			Out = 0.1,
			Up = 0,
			Rate = 9,
			Move = 0.5,
			Seconds = 0.7,
			Speed = 2.6,
			Squash = 1,
			Size = { { 0, 0.3 }, { 0.4, 1 }, { 1, 0.35 } },
			Alpha = { { 0, 1 }, { 0.2, 0.3 }, { 1, 1 } },
			Dust = false,
		},
	} :: { Jet },
	-- fiapos que saem das fitas, esticados na direção do vento
	Wisp = table.freeze({
		Rate = 11,
		Seconds = 0.55,
		Speed = 2.2,
		Squash = 1.2,
		Size = { { 0, 0.12 }, { 0.4, 0.42 }, { 1, 0.1 } },
		Alpha = { { 0, 1 }, { 0.2, 0.35 }, { 1, 1 } },
	}),
})
