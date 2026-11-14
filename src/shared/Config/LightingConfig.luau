--!strict
-- Iluminação inspirada na referência 1: dia ensolarado, cores saturadas, céu azul forte, visual cartoon.
-- Cores em RGB 0-255.

return table.freeze({
	ClockTime = 14.5,
	Brightness = 2.2,
	Ambient = { 120, 120, 135 },
	OutdoorAmbient = { 150, 150, 165 },
	EnvironmentDiffuseScale = 1,
	EnvironmentSpecularScale = 0.4,
	ShadowSoftness = 0.25,
	ExposureCompensation = -0.1,

	ColorCorrection = { Saturation = 0.35, Contrast = 0.12, Brightness = 0.02, TintColor = { 255, 252, 245 } },
	Bloom = { Intensity = 0.4, Size = 24, Threshold = 1.6 },
	Atmosphere = {
		Density = 0.22,
		Offset = 0.1,
		Color = { 190, 215, 255 },
		Decay = { 120, 150, 230 },
		Glare = 0.2,
		Haze = 1.2,
	},
	SunRays = { Intensity = 0.06, Spread = 0.6 },
	Clouds = { Cover = 0.55, Density = 0.7, Color = { 255, 255, 255 } },
})
