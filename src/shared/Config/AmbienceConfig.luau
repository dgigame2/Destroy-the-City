--!strict
-- Partículas de clima em volta da câmera, por estilo de mapa (client/Controllers/AmbienceController).
-- Garden: pétalas e pólen flutuando; Beach: ar limpo (só brilhinhos raros); Frost: neve caindo.
-- A área cobre o que a câmera vê e cresce junto com o jogador (câmera mais longe quando você é gigante).

export type Weather = {
	Texture: string,
	Colors: { { number } },
	Rate: number, -- partículas por segundo (com a área no tamanho base)
	Lifetime: { number },
	Speed: { number },
	Size: { number },
	Fall: number, -- aceleração para baixo (studs/s²)
	Drift: { number }, -- vento (X, Z)
	Spin: number, -- graus/s
	LightEmission: number,
}

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"

return table.freeze({
	AreaSize = 160, -- lado da área (studs) em volta da câmera, no tamanho 1
	AreaHeight = 50, -- altura da área acima da câmera
	MaxAreaScale = 6, -- a área cresce com o jogador até este multiplicador
	Weather = table.freeze({
		Garden = {
			Texture = SPARKLE,
			Colors = { { 255, 190, 220 }, { 255, 250, 210 } },
			Rate = 18,
			Lifetime = { 6, 9 },
			Speed = { 1, 3 },
			Size = { 0.35, 0.6 },
			Fall = 0.6,
			Drift = { 2, 1 },
			Spin = 60,
			LightEmission = 0.3,
		},
		Beach = {
			Texture = SPARKLE,
			Colors = { { 255, 255, 240 } },
			Rate = 4,
			Lifetime = { 3, 5 },
			Speed = { 0.5, 1.5 },
			Size = { 0.25, 0.4 },
			Fall = 0,
			Drift = { 3, 0 },
			Spin = 30,
			LightEmission = 0.6,
		},
		Frost = {
			Texture = SPARKLE,
			Colors = { { 255, 255, 255 }, { 225, 240, 255 } },
			Rate = 70,
			Lifetime = { 7, 10 },
			Speed = { 2, 4 },
			Size = { 0.35, 0.7 },
			Fall = 4,
			Drift = { 1.5, 0.8 },
			Spin = 90,
			LightEmission = 0.2,
		},
	}),
})
