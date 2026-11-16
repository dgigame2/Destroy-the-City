--!strict
-- Vida visível das construções (Logic/DamageStages, Logic/Ruins, server/DamageService, client/DamageVfx).
-- A vida em si continua em Logic/StructureHealth (servidor). Aqui ficam só os números do que o jogador VÊ:
--   Estágios: quando a vida passa de um degrau (Thresholds), a construção perde uma parte dos blocos
--             (Removed = fração dos blocos que podem cair). Os blocos caem de cima para baixo e nunca sobra
--             bloco flutuando (o resto continua ligado ao chão, igual ao teste FLOATING dos modelos).
--   Destroços: os blocos que caem viram pedaços que caem até o chão só no cliente e somem (DebrisSeconds).
--   Barra de vida: aparece em cima da construção atingida e some depois de HpBar.Seconds sem levar dano.
--   Escombros: quando a construção cai (tier >= Ruins.FromTier), fica uma pilha baixa de blocos dentro do
--              terreno dela (não encosta nas vizinhas, não tem colisão: não atrapalha andar na run sem pulo).

return table.freeze({
	-- fração da vida em que cada estágio começa (1 = inteira). Estágio 1 abaixo de 75%, 2 abaixo de 50%...
	Thresholds = table.freeze({ 0.75, 0.5, 0.25 }),
	-- fração dos blocos que já caiu em cada estágio (sempre crescente)
	Removed = table.freeze({ 0.15, 0.3, 0.45 }),
	-- variação para construções iguais não quebrarem igual (até tantos studs de "sorteio" na altura)
	Jitter = 0.8,
	-- quantas variações de quebra cada modelo tem (a construção usa BuildingId % Variants)
	Variants = 3,
	MinBoxes = 4, -- modelos com menos blocos que isso (postes, bancos) não têm estágios: só caem inteiros

	-- destroços no cliente (celular: teto de peças com física ao mesmo tempo)
	-- (peças ancoradas e tween, sem física: mesmo padrão dos efeitos dos desastres no celular)
	DebrisSeconds = 1.2, -- queda + sumir
	MaxDebris = 40,
	DebrisSpread = 4, -- quanto o pedaço se afasta da construção ao cair (studs)
	DebrisSpin = 70, -- giro máximo na queda (graus)

	HpBar = table.freeze({
		Seconds = 3, -- some depois disso sem levar dano
		Max = 8, -- barras ao mesmo tempo (as mais recentes)
		Width = 70, -- px
		Height = 10,
		Above = 3, -- studs acima do topo da construção
		Step = 0.05, -- o servidor só publica a vida em degraus de 5% (menos tráfego)
		Full = table.freeze({ 90, 220, 110 }),
		Mid = table.freeze({ 255, 200, 60 }),
		Low = table.freeze({ 240, 70, 60 }),
	}),

	Ruins = table.freeze({
		FromTier = 3, -- casas para cima deixam escombros
		Cell = 4, -- lado de cada bloco da pilha (studs, aproximado)
		MaxCells = 4, -- no máximo 4 x 4 blocos na base
		Margin = 0.8, -- a pilha ocupa no máximo 80% do terreno da construção
		HeightByTier = table.freeze({ 0, 0, 1.2, 1.6, 2.4, 3.2, 4 }), -- altura máxima da pilha por tier
		MinHeight = 0.4, -- fração mínima da altura máxima em cada bloco
		Chunks = 0.35, -- chance de um pedaço menor em cima de cada bloco
		MaxParts = 20,
		Concrete = table.freeze({ 150, 150, 155 }), -- cinza de concreto (a outra cor vem da parede da construção)
		DarkConcrete = table.freeze({ 105, 105, 112 }),
	}),
})
