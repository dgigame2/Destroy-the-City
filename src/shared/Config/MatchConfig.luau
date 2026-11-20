--!strict
-- Partida nova (docs/AUDITORIA.md, seção 8): a cidade é DADO no servidor e modelo no cliente.
-- Milestones = marcos compartilhados do progresso (fração do VALOR total destruído, não da contagem).
-- CompleteAt = com essa fração o servidor derruba o que sobrou e a cidade chega a 100% (ninguém caça a
--   última casinha escondida).
-- DeltaInterval = de quanto em quanto tempo o servidor junta as mudanças num lote (CityDelta).
-- HpLevels = degraus da vida enviada ao cliente (1 byte: 1..255 vivo, 0 = destruída).
-- Cast = limite de pedidos por jogador (token bucket): Rate por segundo, até Burst seguidos.
-- GridCell = tamanho da célula da grade espacial do servidor (studs).
-- Value = valor de destruição: área (studs²) × altura^HeightExp × Weight[categoria] × Scale.
--   Categorias com peso 0 (flores, postes...) quebram, mas não contam no progresso.
-- HpPerValue = vida por ponto de valor (PROVISÓRIO: o simulador da Etapa 1 calibra; ver AUDITORIA §11).
-- PropHp = vida dos objetos que não contam no progresso.
-- VictorySeconds = tempo da comemoração antes de voltar ao lobby.

return table.freeze({
	Milestones = table.freeze({ 0.25, 0.5, 0.75, 1 }),
	CompleteAt = 0.985,
	DeltaInterval = 0.1,
	HpLevels = 255,
	Cast = table.freeze({ Rate = 8, Burst = 12 }),
	GridCell = 32,
	-- queima do Fogo (Etapa 4): o servidor aplica o dano a cada Tick s; no máximo MaxBurning construções
	-- queimando na partida inteira (teto de CPU do servidor e de efeitos no cliente)
	Burn = table.freeze({ Tick = 0.5, MaxBurning = 120 }),
	-- alvos que a cadeia do raio / o fogo que espalha consideram em volta de cada ponto
	ChainCandidates = 24,
	Value = table.freeze({
		Scale = 0.01,
		HeightExp = 0.5,
		Weight = table.freeze({
			Building = 1,
			Aircraft = 1,
			Stall = 0.6,
			Yard = 0.5,
			Vehicle = 0,
			Boat = 0,
			Tree = 0,
			Plant = 0,
			Leisure = 0,
			Street = 0,
			Beach = 0,
		}),
	}),
	HpPerValue = 10,
	PropHp = 20,
	VictorySeconds = 8,
	-- dinheiro da partida por destruição: Value × PerValue; quem destrói fica com DestroyerShare e o resto é
	-- dividido entre a party inteira (D5: com 4 jogadores o dinheiro não fica 4× menor). PROVISÓRIO.
	Money = table.freeze({ PerValue = 1, DestroyerShare = 0.6 }),
	-- gemas extras de cada marco (25, 50 e 75%) em fração das gemas da vitória: somam +30% (AUDITORIA §11)
	MilestoneGems = table.freeze({ 0.1, 0.1, 0.1, 0 }),
})
