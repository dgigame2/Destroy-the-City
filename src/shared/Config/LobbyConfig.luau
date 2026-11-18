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
		{ -65, 34, -5, 42 }, -- recompensas (encosta no caminho do meio; borda acaba em 43.5)
		{ 5, 34, 65, 42 }, -- classes
	}),
	PathBorder = table.freeze({ Width = 1.5, Height = 0.45 }),
	-- sebe de cubinhos por dentro da cerca do parque (fundo e laterais até SideEndZ)
	Hedge = table.freeze({
		Inset = 5,
		Pitch = 14,
		Density = 0.55,
		Size = table.freeze({ 2.6, 4.2 }),
		Height = table.freeze({ 2.2, 3.6 }),
		-- sem moita: frente da área START A RUN e as pedras perto dela
		Skip = table.freeze({ { -50, 60, 50, 90 }, { -71, 64, -53, 90 }, { 53, 64, 71, 90 } }),
	}),
	-- Terreno redondo em volta da cidade (assets/blender/build_land.py -> Lobby_Land): começa onde o gramado
	-- retangular da cidade acaba, vai até Radius (com ondulação Wobble) e desce suave numa saia de Skirt
	-- studs até Drop abaixo do chão (assim a borda do mundo some no horizonte).
	Land = table.freeze({ Radius = 880, Wobble = 40, Skirt = 90, Drop = 90 }), -- diâmetro < 2048 (limite de mesh)
	-- Cidadezinha em volta do parque (Logic/LobbyTown): calçada, rua com faixa, calçada, lotes com casas
	-- dos Templates viradas para a rua, árvores entre elas, carros parados e gramado até o horizonte.
	Town = table.freeze({
		Sidewalk = 8,
		Road = 18,
		Lot = 44,
		Horizon = 260, -- o gramado retangular vai até a floresta; dali para fora é o terreno redondo (Land)
		HousePitch = 42,
		HouseScale = 1.6,
		Houses = table.freeze({ "House", "BigHouse", "Cottage", "House", "Cottage" }),
		TreeScale = 1,
		Dash = table.freeze({ 6, 0.6, 14 }),
		Cars = 5,
		-- floresta de árvores de blocos atrás dos prédios e morros no horizonte (assets/blender/build_nature.py)
		ForestGap = 8,
		ForestDepth = 180,
		ForestPitch = 26,
		ForestDensity = 0.45,
		ForestScale = table.freeze({ 1.1, 1.6 }),
		HillRing = 720, -- raio do círculo de morros (fora da floresta)
		-- casas e prédios sortidos no lugar de parte da floresta e nos arredores
		SuburbChance = 0.4,
		SuburbScale = 1.3,
		YardBush = table.freeze({ 2.6, 2.2, 9 }),
		Suburbs = table.freeze({
			"House",
			"Cottage",
			"BigHouse",
			"Townhouse",
			"Shop",
			"Apartment",
			"Office",
			"Villa",
		}),
		-- arredores no terreno redondo: grade com casinhas e árvores sorteadas, mais 4 montanhas menores
		Outskirts = table.freeze({
			Pitch = 44,
			HillMargin = 90, -- para antes dos morros do horizonte
			HouseChance = 0.4,
			TreeChance = 0.4,
			TreeScale = table.freeze({ 1.3, 2 }),
			Mountains = table.freeze({ { 545, 0, 3 }, { -545, 0, 3 }, { 0, 530, 3 }, { 0, -530, 3 } }),
		}),
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
		-- tulipas avulsas (3 juntas) para espalhar no gramado, e o terreno redondo (assets/blender/build_land.py)
		TulipRed = { Mesh = "Lobby_TulipRed", Size = { 1.41, 1.66, 1.22 }, Center = { 0.06, 0.83, -0.03 } },
		TulipPink = { Mesh = "Lobby_TulipPink", Size = { 1.33, 1.66, 1.19 }, Center = { 0.03, 0.83, -0.05 } },
		Land = { Mesh = "Lobby_Land", Size = { 1940, 90, 1940 }, Center = { -34.74, -45, 19.63 } }, -- o importador gira a mesh 180° (X e Z invertidos)
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
		-- tulipas avulsas no gramado { x, z, 1 = vermelha / 2 = rosa } (escala FlowerScale)
		-- moitas de folha soltas no gramado { x, z, lado do cubo } (altura = 0.8 do lado)
		Bushes = table.freeze({
			{ -22, -50, 3 },
			{ 22, -50, 3.4 },
			{ -52, -40, 3 },
			{ 52, -40, 2.8 },
			{ -85, 12, 3.2 },
			{ 88, 14, 3 },
			{ -55, 55, 3 },
			{ 56, 56, 3.2 },
			{ -36, 22, 2.8 },
			{ 36, 24, 2.8 },
			{ -32, -60, 3 },
			{ 32, -60, 3 },
		}),
		FlowerScale = 1.6,
		Flowers = table.freeze({
			{ -45, -45, 1 },
			{ 45, -45, 2 },
			{ -15, -48, 2 },
			{ 15, -48, 1 },
			{ -86, -48, 2 },
			{ 86, -48, 1 },
			{ -40, 0, 1 },
			{ 40, -2, 2 },
			{ -12, 30, 2 },
			{ 12, 26, 1 },
			{ -25, 50, 1 },
			{ 25, 52, 2 },
			{ -75, 2, 2 },
			{ 75, 2, 1 },
			{ -95, 40, 1 },
			{ 95, 46, 2 },
			{ -48, 76, 2 },
			{ 50, 77, 1 },
			{ -105, -15, 1 },
			{ 105, -15, 2 },
			{ -40, -70, 2 },
			{ 42, -68, 1 },
			{ -74, 44, 1 },
			{ 72, 48, 2 },
		}),
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
		-- árvores de blocos (no lugar das palmeiras e mais algumas para o parque não ficar vazio)
		Trees = table.freeze({
			{ -70, -52, 1.5 },
			{ 70, -52, 1.5 },
			{ -104, 4, 1.5 },
			{ 103, 10, 1.5 },
			{ -98, -66, 1.3 },
			{ 98, -66, 1.3 },
			{ -100, -36, 1.2 },
			{ 100, -36, 1.2 },
			{ -100, 62, 1.3 },
			{ 100, 62, 1.3 },
			{ -60, -72, 1.2 },
			{ 60, -72, 1.2 },
			{ -82, 66, 1.2 },
			{ 86, 66, 1.1 },
			{ 0, -76, 1.3 },
			{ -70, 15, 1.1 },
		}),
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
		FrameRate = 24,
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
