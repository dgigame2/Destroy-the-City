--!strict
-- Efeitos visuais dos elementos (client/City/ElementFx). Só visual: o dano é do servidor.
-- Tamanhos em múltiplos do raio do golpe (R). Texturas = partículas que vêm junto com o Roblox
-- (rbxasset://textures/particles, sem upload). Toda explosão some em menos de 1 s (regra do goat).
-- Barato para celular: tudo vem de um pool montado uma vez; partículas por Emit() (sem emissor ligado);
-- um único Heartbeat anima tudo; a quantidade de partículas cai com a qualidade gráfica e para os outros.

local TEX = "rbxasset://textures/particles/"

return table.freeze({
	Textures = table.freeze({
		Fire = TEX .. "fire_main.dds",
		Sparks = TEX .. "fire_sparks_main.dds",
		Sparkle = TEX .. "sparkles_main.dds",
		Smoke = TEX .. "smoke_main.dds",
		Shock = TEX .. "explosion01_shockwave_main.dds",
	}),

	-- tetos de efeitos ao mesmo tempo e partículas dos outros: pelo Tier (Config/QualityConfig)
	OthersSize = 0.8, -- golpes dos outros: efeito um pouco menor
	-- qualidade gráfica do Roblox -> fator das partículas (ElementFxMath.quality)
	QualityMin = 0.35,
	QualityAuto = 0.6,

	Fire = table.freeze({
		FallSeconds = 0.2, -- bola de fogo caindo do céu até o impacto
		FallHeight = 70,
		FallBack = 30, -- vem do lado de quem lançou
		BallSize = 0.45, -- x R
		TrailSeconds = 0.18,
		ImpactSeconds = 0.75, -- depois do impacto (< 1 s)
		Flames = 18,
		Embers = 14,
		Smoke = 5,
		RingFrom = 0.3,
		RingTo = 2.2, -- diâmetro final do anel = x R
		LightRange = 2.5,
		LightBrightness = 5,
		Core = { 255, 236, 140 },
		Hot = { 255, 140, 40 },
		Deep = { 210, 50, 20 },
		SmokeColor = { 70, 58, 55 },
	}),

	Lightning = table.freeze({
		Seconds = 0.45,
		Height = 95,
		Segments = 10,
		Jitter = 0.45, -- x R (desvio lateral do zigue-zague)
		Branches = 2,
		BranchLength = 0.35, -- da altura
		BranchSegments = 4,
		Width = 0.9,
		BranchWidth = 0.45,
		-- pisca: aceso até FlickerOff, apaga, reacende com outro desenho em FlickerOn, some até o fim
		FlickerOff = 0.07,
		FlickerOn = 0.11,
		Sparks = 20,
		RingFrom = 0.2,
		RingTo = 1.8,
		LightRange = 3,
		LightBrightness = 9,
		Core = { 235, 248, 255 },
		Glow = { 120, 200, 255 },
	}),

	Wind = table.freeze({
		Seconds = 0.8,
		Strands = 3, -- fios do redemoinho (Beams)
		Turns = 1.25, -- voltas na vida do efeito
		Radius0 = 0.3,
		Radius1 = 1.1,
		Rise = 0.9,
		Arc = 1.7, -- quanto cada fio curva (radianos)
		StrandWidth = 0.18,
		Dust = 8,
		Bits = 10,
		RingFrom = 0.4,
		RingTo = 2.4,
		Strand = { 225, 255, 245 },
		DustColor = { 205, 192, 160 },
		BitsColor = { 170, 235, 150 },
	}),
})
