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
	-- Caminhos de pedra do parque (x0, z0, x1, z1 no espaço do lobby; a praça da fonte é o 1º) e a borda de
	-- lajota mais escura em volta do contorno de todos juntos (Logic/LobbyPaths). Os caminhos do fundo acabam
	-- antes das placas de recompensas/classes (z 43.8).
	Paths = table.freeze({
		{ -28, -38, 28, 18 }, -- praça
		{ -50, -25, -28, -15 }, -- para a loja
		{ 28, -25, 50, -15 }, -- para a roleta
		{ -5, 18, 5, 56 }, -- até a área START A RUN
		{ -65, 34, -15, 42 }, -- recompensas (borda acaba em 43.5)
		{ 15, 34, 65, 42 }, -- classes
	}),
	PathBorder = table.freeze({ Width = 1.5, Height = 0.45 }),
	-- sebe de cubinhos por dentro da cerca do parque (fundo e laterais até SideEndZ)
	Hedge = table.freeze({ Size = 3.6, Height = 3, Gap = 1.2, Inset = 5, SideEndZ = 80 }),
	-- Cidadezinha em volta do parque (Logic/LobbyTown): calçada, rua com faixa, calçada, lotes com casas
	-- dos Templates viradas para a rua, árvores entre elas, carros parados e gramado até o horizonte.
	Town = table.freeze({
		Sidewalk = 8,
		Road = 18,
		Lot = 44,
		Horizon = 330, -- o gramado vai até depois dos morros
		HousePitch = 42,
		HouseScale = 1.6,
		Houses = table.freeze({ "House", "BigHouse", "Cottage", "House", "Cottage" }),
		TreeScale = 1,
		Dash = table.freeze({ 6, 0.6, 14 }),
		Cars = 5,
		-- floresta de árvores de blocos atrás dos prédios e morros no horizonte (assets/blender/build_nature.py)
		ForestGap = 8,
		ForestDepth = 80,
		ForestPitch = 24,
		ForestDensity = 0.6,
		ForestScale = table.freeze({ 1.1, 1.6 }),
		HillGap = 10,
		HillPitch = 170,
		Hills = table.freeze({ { 125.74, 115.82 }, { 160.05, 166.43 }, { 94.49, 85.51 } }),
		-- prédios maiores atrás das casas (horizonte da cidade)
		BuildingGap = 12,
		BuildingLot = 44,
		BuildingPitch = 48,
		BuildingScale = 1.3,
		Buildings = table.freeze({
			"Apartment",
			"Office",
			"ApartmentTall",
			"Hotel",
			"GlassTower",
			"Apartment",
			"OfficeTower",
			"RedTower",
		}),
	}),
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
		Mushroom = { Mesh = "Lobby_Mushroom", Size = { 3.33, 2.78, 3.35 }, Center = { 0.03, 1.39, 0 } },
		Shop = { Mesh = "Lobby_Shop", Size = { 30, 28, 26.4 }, Center = { 0, 14, -1.2 } },
		Tree = { Mesh = "Lobby_Tree", Size = { 6.32, 10.73, 6.33 }, Center = { 0, 5.37, 0.09 } },
		Palm = { Mesh = "Lobby_Palm", Size = { 9.57, 12.6, 9.81 }, Center = { 2.12, 6.3, 0.03 } },
		Bush = { Mesh = "Lobby_Bush", Size = { 4.8, 2.6, 3.05 }, Center = { 0.03, 1.28, 0.03 } },
		-- cerca do parque: tábuas em pé com poste em x = -4 (assets/blender/build_park.py)
		Fence = { Mesh = "Lobby_ParkFence", Size = { 8.15, 6.9, 1.2 }, Center = { -0.08, 3.45, 0 } },
		ParkLamp = { Mesh = "Lobby_ParkLamp", Size = { 1.6, 10.65, 1.6 }, Center = { 0, 5.32, 0 } },
		Planter = { Mesh = "Lobby_Planter", Size = { 10.2, 2.42, 2.2 }, Center = { 0, 1.21, 0 } },
		-- floreiras com madeira e terra de verdade e tulipas low-poly (assets/blender/build_nature.py)
		PlanterLong = { Mesh = "Lobby_PlanterLong", Size = { 12, 2.22, 2 }, Center = { 0, 1.11, 0 } },
		PlanterWide = { Mesh = "Lobby_PlanterWide", Size = { 7, 2.17, 3.2 }, Center = { 0, 1.09, 0 } },
		Umbrella = { Mesh = "Lobby_Umbrella", Size = { 8.4, 7.4, 8.4 }, Center = { 0, 3.7, 0 } },
		Bench = { Mesh = "Lobby_Bench", Size = { 5, 2.6, 1.5 }, Center = { 0, 1.3, 0 } },
		SignSmall = { Mesh = "Lobby_SignSmall", Size = { 27, 17.2, 2.49 }, Center = { 0, 8.6, -0.14 } },
		SignBig = { Mesh = "Lobby_SignBig", Size = { 51, 34.2, 2.49 }, Center = { 0, 17.1, -0.14 } },
	}),
	-- Texturas do lobby (profundidade): MaterialVariants estilizados gerados no Studio do lobby
	-- (MaterialService). Por nome da peça. Tint = cor da peça (multiplica a textura); sem Tint, a cor da paleta.
	-- Sem o MaterialVariant no place, a peça fica com o material base (Grass, Pavement...).
	-- Textured = false: lobby liso igual à run (SmoothPlastic nas cores da paleta); true volta às texturas.
	-- TexturedParts: mesmo liso, essas peças ficam com a textura (grama e chão de pedra da praça/caminhos).
	Textured = false,
	TexturedParts = table.freeze({ Grass = true, TownGrass = true, Plaza = true, Path = true, PathBorder = true }),
	Materials = table.freeze({
		-- grama com a textura LobbyGrass (MaterialVariant do place), igual à imagem de referência do usuário
		Grass = { Material = "Grass", Variant = "LobbyGrass", Tint = { 255, 255, 255 } },
		TownGrass = { Material = "Grass", Variant = "LobbyGrass", Tint = { 255, 255, 255 } },
		Sand = { Material = "Sand", Variant = "BeachSand", Tint = { 255, 255, 255 } },
		Dirt = { Material = "Ground", Variant = "IslandDirt", Tint = { 255, 255, 255 } },
		HangingRock = { Material = "Ground", Variant = "IslandDirt", Tint = { 220, 220, 220 } },
		-- lajotas cinza-claras (assets/blender/make_flagstone.py -> MaterialVariant "LobbyFlagstone", base Slate)
		Plaza = { Material = "Slate", Variant = "LobbyFlagstone", Tint = { 240, 238, 232 } },
		Path = { Material = "Slate", Variant = "LobbyFlagstone", Tint = { 240, 238, 232 } },
		-- borda dos caminhos: a mesma lajota num tom mais escuro
		PathBorder = { Material = "Slate", Variant = "LobbyFlagstone", Tint = { 196, 186, 166 } },
		-- placas: madeira pintada na cor de cada placa
		TitleSign = { Material = "WoodPlanks", Variant = "SignWood" },
		RewardsBoard = { Material = "WoodPlanks", Variant = "SignWood" },
		ClassesBoard = { Material = "WoodPlanks", Variant = "SignWood" },
		ShopSign = { Material = "WoodPlanks", Variant = "SignWood" },
		FencePost = { Material = "WoodPlanks", Variant = "SignWood" },
	}),
	-- prefixos de peças da área START A RUN (placas dos quadrados e postes) que também ficam de madeira
	WoodPrefixes = table.freeze({ "PadBoard", "PadPost", "RunSign", "SignPost", "SignBeam", "Wheel" }),
	-- Fonte da praça em peças lisas (Logic/Fountain): 3 bacias de pedra, a de baixo é o pé. Raios e alturas
	-- em studs. Raio total < SpawnRadius (ninguém nasce dentro); testado em tests/Fountain.spec.luau.
	-- mesh da pedra da fonte (assets/blender/Fountain.fbx) em ReplicatedStorage.Assets; sem ela, peças lisas
	FountainMesh = "Lobby_FountainMesh",
	Fountain = table.freeze({
		Segments = 32, -- blocos de cada anel (parede e borda das bacias)
		Basins = table.freeze({
			{
				Radius = 11.5,
				Bowl = { Radius = 9.5, Height = 1.2 },
				Floor = 0.8,
				Wall = { Thickness = 1.3, Height = 2 },
				Rim = { Height = 0.6, Overhang = 0.6 },
				Water = 1.2,
			},
			{
				Radius = 6,
				Bowl = { Radius = 3.6, Height = 1 },
				Floor = 0.6,
				Wall = { Thickness = 0.8, Height = 1 },
				Rim = { Height = 0.4, Overhang = 0.4 },
				Water = 0.5,
			},
			{
				Radius = 3.2,
				Bowl = { Radius = 1.8, Height = 0.7 },
				Floor = 0.5,
				Wall = { Thickness = 0.6, Height = 0.7 },
				Rim = { Height = 0.3, Overhang = 0.3 },
				Water = 0.35,
			},
		}),
		-- colunas entre as bacias (discos de baixo para cima, alternando largo/fino como a coluna lavrada)
		Columns = table.freeze({
			{
				{ Radius = 2.6, Height = 0.8 },
				{ Radius = 1.7, Height = 2.6 },
				{ Radius = 2.3, Height = 1 },
				{ Radius = 1.4, Height = 1.6 },
			},
			{
				{ Radius = 1.5, Height = 0.6 },
				{ Radius = 1, Height = 1.8 },
				{ Radius = 1.4, Height = 0.6 },
			},
		}),
		Finial = table.freeze({ { Radius = 0.9, Height = 0.6 }, { Radius = 0.55, Height = 1 } }),
		Crown = 2,
	}),
	-- cogumelos de enfeite na grama (assets/blender/build_mushroom.py): { x, z, escala } no espaço do lobby,
	-- longe da praça, dos caminhos, das estações e das árvores (tests/Mushrooms.spec.luau)
	-- enfeites do parque { x, z, giro em graus }: floreiras na frente da sebe do fundo com banco na frente,
	-- postes de luz ao lado dos caminhos e árvores de blocos (Templates.Tree). Testado em LobbyPark.spec.
	-- MaterialVariant das folhas das árvores de blocos (LeafTexture.png, criado no Studio)
	LeafVariant = "BlockLeaves",
	Park = table.freeze({
		Planters = table.freeze({ { -88, -80.5, 0 }, { -40, -80.5, 0 }, { 40, -80.5, 0 }, { 88, -80.5, 0 } }),
		WidePlanters = table.freeze({ { -36, 8, 0 }, { 36, 8, 0 }, { -36, -50, 0 }, { 36, -50, 0 } }),
		Benches = table.freeze({ { -88, -76, 180 }, { -40, -76, 180 }, { 40, -76, 180 }, { 88, -76, 180 } }),
		Lamps = table.freeze({
			{ -31, 21, 0 },
			{ 31, 21, 0 },
			{ -31, -41, 0 },
			{ 31, -41, 0 },
			{ -8, 28, 0 },
			{ 8, 28, 0 },
			{ -8, 48, 0 },
			{ 8, 48, 0 },
			{ -52, -28, 0 },
			{ 52, -28, 0 },
			{ -52, -12, 0 },
			{ 52, -12, 0 },
		}),
		Trees = table.freeze({ { -70, -52, 1.5 }, { 70, -52, 1.5 }, { -104, 4, 1.5 }, { 103, 10, 1.5 } }),
	}),
	Mushrooms = table.freeze({
		{ -96, 16, 1 },
		{ -92, 21, 0.7 },
		{ 94, 27, 1 },
		{ 90, 31, 0.7 },
		{ -38, -62, 0.9 },
		{ 40, -60, 0.9 },
		{ -62, 22, 0.8 },
		{ 64, 25, 0.8 },
		{ -80, 50, 0.9 },
		{ 82, 55, 0.9 },
		{ -20, -72, 0.7 },
		{ 22, -70, 0.7 },
	}),
	-- árvores, arbustos e guarda-sóis do Blender já têm tamanho real: escala da natureza x isso
	NatureScale = table.freeze({ Palm = 0.8, Tree = 0.85, Bush = 0.8, Umbrella = 0.8, Bench = 1 }),
	-- jatos da fonte (partículas de água subindo da coroa e caindo nas bacias)
	-- água animada da fonte: jato fino saindo do topo, cortinas caindo da borda de cada bacia de cima
	-- (gotas esticadas na direção da queda) e respingos onde a cortina bate na água de baixo.
	FountainWater = table.freeze({
		Gravity = 50, -- aceleração das gotas (studs/s²)
		Jet = table.freeze({ Rate = 45, Speed = { 9, 11 }, Spread = 5, Size = { 0.9, 0.6 } }),
		-- cortina: Points faixas em volta da borda (Overlap > 1 = encostam uma na outra), Curve = quanto
		-- a água sai para fora antes de cair; Transparency = na borda e na queda
		Curtain = table.freeze({
			Points = 16,
			Overlap = 1.15,
			Curve = 1,
			Transparency = { 0.45, 0.7 },
		}),
		-- quadros da água do Blender (FountainWaterMeshConfig): troca FrameRate vezes por segundo; o quadro
		-- visível fica com essa transparência. Sem as meshes importadas, as cortinas são Beams.
		FrameRate = 8,
		FrameTransparency = 0.35,
		Spill = table.freeze({ Rate = 120, Speed = 1.5, Size = 0.8, Stretch = 2.5 }),
		SpillOut = 1, -- quanto a cortina se afasta da borda até bater na água (studs)
		Splash = table.freeze({ Rate = 80, Speed = { 2, 4 }, Lifetime = 0.45, Size = { 1, 2 } }),
	}),
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
