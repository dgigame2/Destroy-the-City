--!strict
-- Medidas das cidades (Logic/CityGen e Logic/CityTerrain). Unidades em studs.
-- A cidade é uma grade de células quadradas; cada célula tem um tipo de chão (grama, rua, calçada, água...).
-- Camadas do chão: todas começam em 0 (topo da base) e terminam na altura do tipo. Nenhuma entra na outra.

return table.freeze({
	-- Mudou as plantas/geração das cidades? Aumente: runs salvas de versões antigas recomeçam a cidade.
	LayoutVersion = 10,
	CellSize = 3, -- lado de cada célula da grade
	PlanUnit = 6, -- as plantas (CityPlans) são desenhadas em unidades de 6 studs
	WalkCells = 1, -- largura da calçada (em células) em volta das ruas

	-- Altura do topo de cada tipo de chão. Todas abaixo do degrau que o personagem sobe andando
	-- (MovementConfig.MaxStepHeight): na run não tem pulo.
	Heights = table.freeze({
		Lot = 0.05, -- grama dos terrenos (onde ficam casas, prédios e árvores)
		Wild = 0.05, -- margem natural antes do mar (sem ruas nem casas; árvores e moitas destrutíveis)
		Road = 0.15,
		Walk = 0.3, -- calçada
		Water = -0.6, -- rio, lago, porto: mais baixo que o chão (canal); dá para andar por cima
		Bank = 0.3, -- margem de pedra (cais) em volta da água
		Sand = 0.1,
		Plaza = 0.3,
		Asphalt = 0.12, -- estacionamentos, pátios
		Runway = 0.12, -- pista do aeroporto (fica vazia, com faixas)
		Sea = -1, -- mar (atrás das paredes da costa; a superfície de verdade vem do bioma, SeaLevel)
	}),
	SunkLayer = 0.4, -- espessura da lâmina de água do rio rebaixado (a terra para embaixo dela)
	LineTop = 0.25, -- faixas brancas apoiadas em cima da rua
	HillStep = 0.8, -- cada anel do morro sobe isso (menos que um degrau)
	HillRing = 4, -- largura de cada anel do morro (células)

	-- Xadrez do chão: tamanho dos quadrados em células, por tipo
	Checker = table.freeze({ Lot = 4, Wild = 4, Road = 8, Sand = 4, Plaza = 2, Asphalt = 6, Runway = 12 }),
	BigCheckerZone = 3, -- a partir desta zona os quadrados do xadrez dobram de tamanho
	-- Xadrez como TEXTURA (Etapa 2, otimização): cada área de um tipo vira 1 placa da 1ª cor e o 2º tom vem de
	-- uma imagem 2x2 branca semitransparente (icons/textures/Checker.png) no topo, tingida para dar a 2ª cor
	-- exata (Logic/CityTerrain.checkerTint). Corta ~42% das peças do chão. Os studs aparecem pelos 60% livres.
	-- Eixos da textura no topo da peça (a conferir no Studio: se o xadrez "quebrar" nas emendas entre placas,
	-- trocar FlipU/FlipV/SwapUV até casar).
	CheckerTexture = table.freeze({
		Enabled = true,
		Id = "rbxassetid://114739756585207",
		Alpha = 0.4, -- opacidade das casas tingidas na imagem (= 102/255)
		FlipU = false, -- U corre de X máximo para X mínimo
		FlipV = false, -- V corre de Z máximo para Z mínimo
		SwapUV = false, -- U corre no Z (e V no X)
	}),
	LineDash = 10, -- comprimento de cada faixa branca
	LineEvery = 24, -- distância entre faixas

	Gap = 2, -- espaço mínimo entre construções vizinhas (studs)
	FrontageTries = 6, -- quantos modelos tentar em cada frente de terreno
	LampEvery = 10, -- poste a cada tantas células de calçada
	FarLampCap = 5, -- etapas com construções desse tamanho para cima: poste com o dobro da distância
	TierSpan = 4, -- numa etapa de tamanho máximo N só aparecem coisas de tamanho N-4 para cima
	PropChance = 0.05, -- chance de outro objeto (lixeira, banco, hidrante...) numa célula de calçada

	BaseDepth = 18, -- espessura da terra embaixo do chão (aparece como beirada na costa)
	BaseCheckCells = 4, -- xadrez da terra (células)
	-- Mar (Logic/CityTerrain): a superfície vem do bioma (SeaLevel)
	ShallowCells = 6, -- água clara até tantas células da costa
	FoamHeight = 0.15, -- espuma colada na costa, por cima da água
	SeaSize = 12000, -- o mar vai até o horizonte (a névoa esconde a borda)
	SeaTile = 2000, -- maior lado de cada peça de mar (o Roblox limita a 2048)
	OuterSeaDepth = 4,
	-- Cenário fora da cidade (não é comível)
	Islets = 14,
	IsletSize = { 40, 110 }, -- studs
	IsletNear = 40, -- distância mínima da borda da grade
	IsletFar = 700,
	SeaDecorCount = 45, -- barcos / icebergs no mar de fora
	SeaDecorNear = 15,
	InnerDecorSpacing = 7, -- pedras/barcos no mar entre a costa e a borda da grade (células)
	InnerDecorMinCells = 4,
	InnerDecorChance = 0.35,
	WildChance = 0.05, -- árvores/moitas na margem natural (por célula; destrutíveis, contam na área)
	Mountains = 18, -- montanhas no horizonte
	MountainSize = { 180, 420 },
	MountainNear = 650,
	MountainFar = 1500,

	-- Barreiras entre áreas da cidade (somem quando a área de antes é toda comida)
	BarrierHeight = 10, -- parte visível (campo de força)
	BarrierThickness = 0.6,
	ColliderHeight = 2000, -- parte invisível em cima: ninguém passa por cima
	SpawnsPerZone = 10,

	-- Progressão (Logic/ZoneBalance): cada etapa termina com tamanho para comer tudo da próxima, com folga
	-- Margin; MinGrowth = crescimento mínimo de uma etapa (fração). Cada área começa com coisas que você já
	-- come e termina com os marcos grandes dela (que você vê ao chegar, mas ainda não consegue comer).
	-- Tempo (ESTIMATIVA de varrer a área, ver ZoneBalance.sweepSeconds): total perto do Minutes da
	-- dificuldade (dentro de Tolerance), zonas parecidas entre si e a 1ª a mais curta.
	Progression = table.freeze({
		Margin = 1.06,
		MinGrowth = 0.15,
		SweepEfficiency = 0.4, -- ESTIMATIVA (curvas, voltas e desvios); conferir jogando
		Tolerance = 0.35,
	}),
	BuildYieldEvery = 300, -- peças criadas por frame ao montar o terreno
})
