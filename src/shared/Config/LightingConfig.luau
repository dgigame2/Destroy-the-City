--!strict
-- Iluminação do lobby: a mesma manhã ensolarada do Garden Village (MapConfig), para o lobby ter a vibe dos
-- mapas (diorama pastel, céu azul-claro, sombras macias e azuladas). Cores em RGB 0-255.

return table.freeze({
	ClockTime = 10.6,
	Brightness = 2.6,
	Ambient = { 124, 118, 128 },
	OutdoorAmbient = { 158, 152, 160 },
	EnvironmentDiffuseScale = 1,
	EnvironmentSpecularScale = 0.4,
	ShadowSoftness = 0.35,
	ExposureCompensation = -0.1,

	ColorCorrection = { Saturation = 0.38, Contrast = 0.14, Brightness = 0.02, TintColor = { 255, 248, 236 } },
	Bloom = { Intensity = 0.5, Size = 28, Threshold = 1.4 },
	Atmosphere = {
		Density = 0.26,
		Offset = 0.1,
		Color = { 196, 220, 255 },
		Decay = { 120, 156, 232 },
		Glare = 0.35,
		Haze = 1.4,
	},
	SunRays = { Intensity = 0.1, Spread = 0.7 },
	Clouds = { Cover = 0.62, Density = 0.6, Color = { 255, 255, 255 } },
})
