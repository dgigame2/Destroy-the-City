--!strict
-- Tiers de qualidade do cliente (AUDITORIA §8.4). Cada cliente escolhe o seu; o estado da cidade é o mesmo.
-- Auto: toque sem teclado -> Low; senão mede o FPS nos primeiros SampleSeconds e cai para Low se ficar abaixo
-- de LowFps. Orçamentos [ESTIMATIVA -> calibrar no benchmark do celular].
--   Particles: multiplicador das partículas dos efeitos (x a qualidade gráfica do Roblox)
--   Near/Mid: raio (studs, no plano) das faixas de LOD em volta do jogador. Near = modelo inteiro;
--             Mid = sem os detalhes pequenos; além = impostor (1 caixa por construção).
--   FlyingPieces: pedaços de destroço voando ao mesmo tempo; Collapses: desabamentos animados ao mesmo tempo
--   MaxOthers/OthersScale: efeitos dos golpes dos outros jogadores (teto e tamanho das partículas)
--   Persistent/BurnFoci: emissores LIGADOS (tornado, coluna de fogo, prédios queimando). No Low a soma fica
--   <= 9, dentro do teto de 12 emissores ativos da AUDITORIA §8.4 (os golpes usam só Emit, sem emissor ligado).

export type Tier = {
	Name: string,
	Particles: number,
	Near: number,
	Mid: number,
	FlyingPieces: number,
	Collapses: number,
	MaxOwn: number,
	MaxOthers: number,
	OthersScale: number,
	Dust: boolean, -- nuvem de poeira no desabamento
	Persistent: number, -- efeitos que duram (tornado, coluna de fogo) ao mesmo tempo
	BurnFoci: number, -- construções pegando fogo com chama visível ao mesmo tempo
}

local tiers: { [string]: Tier } = {
	Low = table.freeze({
		Name = "Low",
		Particles = 0.5,
		Near = 140,
		Mid = 280,
		FlyingPieces = 20,
		Collapses = 4,
		MaxOwn = 4,
		MaxOthers = 2,
		OthersScale = 0.4,
		Dust = false,
		Persistent = 3,
		BurnFoci = 6,
	}),
	Medium = table.freeze({
		Name = "Medium",
		Particles = 0.8,
		Near = 220,
		Mid = 420,
		FlyingPieces = 60,
		Collapses = 8,
		MaxOwn = 6,
		MaxOthers = 4,
		OthersScale = 0.6,
		Dust = true,
		Persistent = 6,
		BurnFoci = 16,
	}),
	High = table.freeze({
		Name = "High",
		Particles = 1,
		Near = 320,
		Mid = 640,
		FlyingPieces = 120,
		Collapses = 14,
		MaxOwn = 8,
		MaxOthers = 6,
		OthersScale = 0.8,
		Dust = true,
		Persistent = 10,
		BurnFoci = 32,
	}),
}

return table.freeze({
	Tiers = table.freeze(tiers),
	Order = table.freeze({ "Low", "Medium", "High" }),
	Default = "High", -- PC sem medição ainda
	SampleSeconds = 15,
	LowFps = 40,
	-- LOD
	ChunkSize = 128, -- studs [ESTIMATIVA, a calibrar]
	LodInterval = 0.5, -- segundos entre atualizações do LOD (não por frame)
	Hysteresis = 0.12, -- sair de uma faixa precisa de +12% de distância (sem troca seca indo e voltando)
	DetailVolume = 6, -- peças com volume até isso (studs³) são "detalhe" e somem na faixa Mid
	ChunksPerStep = 6, -- chunks trocados por atualização (espalha o custo de reparent)
})
