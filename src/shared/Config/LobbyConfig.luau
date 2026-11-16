--!strict
-- Lobby: ilha flutuante alta, de frente para a cidade (+Z aponta para o centro do mapa).
-- Posição fixa, calculada para ficar além dos paredões do maior mapa.

return table.freeze({
	FloorHeight = 450, -- altura do gramado do lobby (studs)
	Width = 240, -- X
	Depth = 180, -- Z
	-- centro do lobby em Z (negativo = antes da borda -Z do mapa). Maior mapa: meia-largura 435 + margem 60
	-- + paredões 90 = 585; mais folga e metade da ilha.
	CenterZ = -(585 + 60 + 90),
	SpawnRadius = 18,
	FallKillHeight = 300, -- caiu abaixo disso estando no lobby: volta para o lobby
	WheelRadius = 14, -- raio da roleta física (a janela da roleta usa para encaixar os nomes dos prêmios)
	WheelSubSlices = 6, -- cada fatia é feita de 6 triângulos: a borda fica redonda
	ShopRingRadius = 5, -- anel de traços neon na frente da loja (indicador de compra)
	ShopRingDashes = 14,
	ShopRingSpin = 25, -- graus por segundo
	PromptDistance = 18, -- distância para o "E" das placas, loja e roleta aparecer
	-- Modelos do Blender (assets/blender/build_lobby.py -> LobbyProps.fbx), importados em ReplicatedStorage.Assets.
	-- Size = caixa da mesh em studs (MEDIDO: assets/blender/lobby_sizes.txt); Center = centro da caixa em relação
	-- ao ponto de apoio no chão (x, y, z do Roblox). Sem a mesh importada, o lobby usa as peças antigas.
	Props = table.freeze({
		Fountain = { Mesh = "Lobby_Fountain", Size = { 25.26, 13.6, 25.27 }, Center = { 0, 6.8, 0 } },
		Shop = { Mesh = "Lobby_Shop", Size = { 30, 28, 26.4 }, Center = { 0, 14, -1.2 } },
		Tree = { Mesh = "Lobby_Tree", Size = { 6.32, 10.73, 6.33 }, Center = { 0, 5.37, 0.09 } },
		Palm = { Mesh = "Lobby_Palm", Size = { 9.57, 12.6, 9.81 }, Center = { 2.12, 6.3, 0.03 } },
		Bush = { Mesh = "Lobby_Bush", Size = { 4.8, 2.6, 3.05 }, Center = { 0.03, 1.28, 0.03 } },
		Fence = { Mesh = "Lobby_Fence", Size = { 8.06, 3.6, 1.03 }, Center = { -0.48, 1.8, 0 } }, -- poste em x = -4
		Umbrella = { Mesh = "Lobby_Umbrella", Size = { 8.4, 7.4, 8.4 }, Center = { 0, 3.7, 0 } },
		Bench = { Mesh = "Lobby_Bench", Size = { 5, 2.6, 1.5 }, Center = { 0, 1.3, 0 } },
		SignSmall = { Mesh = "Lobby_SignSmall", Size = { 27, 17.2, 2.49 }, Center = { 0, 8.6, -0.14 } },
		SignBig = { Mesh = "Lobby_SignBig", Size = { 51, 34.2, 2.49 }, Center = { 0, 17.1, -0.14 } },
	}),
	-- Texturas do lobby (profundidade): MaterialVariants estilizados gerados no Studio do lobby
	-- (MaterialService). Por nome da peça. Tint = cor da peça (multiplica a textura); sem Tint, a cor da paleta.
	-- Sem o MaterialVariant no place, a peça fica com o material base (Grass, Pavement...).
	Materials = table.freeze({
		Grass = { Material = "Grass", Variant = "LobbyGrass", Tint = { 255, 255, 255 } },
		Sand = { Material = "Sand", Variant = "BeachSand", Tint = { 255, 255, 255 } },
		Dirt = { Material = "Ground", Variant = "IslandDirt", Tint = { 255, 255, 255 } },
		HangingRock = { Material = "Ground", Variant = "IslandDirt", Tint = { 220, 220, 220 } },
		Plaza = { Material = "Pavement", Variant = "PlazaStone", Tint = { 255, 255, 255 } },
		Path = { Material = "Cobblestone", Variant = "PathCobble", Tint = { 255, 255, 255 } },
		-- placas: madeira pintada na cor de cada placa
		TitleSign = { Material = "WoodPlanks", Variant = "SignWood" },
		RewardsBoard = { Material = "WoodPlanks", Variant = "SignWood" },
		ClassesBoard = { Material = "WoodPlanks", Variant = "SignWood" },
		ShopSign = { Material = "WoodPlanks", Variant = "SignWood" },
		FencePost = { Material = "WoodPlanks", Variant = "SignWood" },
	}),
	-- prefixos de peças da área START A RUN (placas dos quadrados e postes) que também ficam de madeira
	WoodPrefixes = table.freeze({ "PadBoard", "PadPost", "RunSign", "SignPost", "SignBeam", "Wheel" }),
	FountainScale = 1.15, -- a fonte é o destaque da praça (raio ~14.5 < SpawnRadius: ninguém nasce dentro)
	-- árvores, arbustos e guarda-sóis do Blender já têm tamanho real: escala da natureza x isso
	NatureScale = table.freeze({ Palm = 0.8, Tree = 0.85, Bush = 0.8, Umbrella = 0.8, Bench = 1 }),
	-- jatos da fonte (partículas de água subindo da coroa e caindo nas bacias)
	FountainJets = table.freeze({ Rate = 70, Speed = { 14, 18 }, Lifetime = { 1.1, 1.4 }, Size = { 1, 0.4 } }),
	-- Área "START A RUN" na frente da ilha (+Z): quadrados no chão com uma placa atrás de cada um.
	RunArea = table.freeze({
		PadSize = 16, -- lado do quadrado (com a borda neon)
		Border = 1, -- largura da borda neon
		PadSpacing = 22, -- distância entre centros (sobra 6 de grama entre eles)
		PadZ = 68, -- centro dos quadrados em Z
		PadHeight = 0.4, -- espessura do piso do quadrado
		DetectHeight = 14, -- até essa altura acima do quadrado o jogador conta como "em cima"
		BoardWidth = 14,
		BoardHeight = 8,
		BoardBottom = 3,
		BoardZ = 81, -- placa de cada quadrado, atrás dele (lado da borda da ilha)
		Post = 1.4,
		SignWidth = 80,
		SignHeight = 9,
		SignBottom = 15,
		SignZ = 86, -- placa grande "START A RUN"
		ExitBack = 12, -- quem sai à força do quadrado vai para tantos studs na frente dele (-Z)
	}),
})
