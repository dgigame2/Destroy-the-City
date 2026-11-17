--!strict
-- Plantas das cidades (Logic/CityGen). Coordenadas em unidades de planta (CityConfig.PlanUnit studs);
-- x cresce para a direita (+X), z para baixo no desenho (+Z). Retângulos: {x0, z0, x1, z1} (x1/z1 exclusivos).
-- Ruas e rios: linhas com largura em unidades; ruas passam por cima dos rios (pontes).
-- Streets: grades de ruas automáticas (Every = distância entre ruas; Skip = trechos pulados; Holes = sem ruas).
-- Coast: a terra é uma ilha arredondada com a costa ondulada; fora dela é mar (atrás de paredes invisíveis).
-- Coast.Wild: margem natural entre a cidade e o mar (a cidade acaba antes, com contorno irregular).
--
-- Zonas (áreas de progressão), na ordem: a 1 é onde o jogador começa; cada uma só abre quando a anterior
-- foi toda comida (aos 98% o resto é coletado sozinho). Cada zona tem etapas em ordem (Steps): a região de
-- cada etapa e o maior tamanho de construção dela (Cap). Terminar uma etapa deixa você grande o bastante
-- para comer tudo da próxima (Logic/ZoneBalance), então dá para varrer região por região.
-- Tamanho das zonas: o tempo de cada uma fica parecido (a 1ª é a menor e mais rápida). Como você cresce e
-- anda mais rápido, cada zona é bem maior que a anterior (ESTIMATIVA em CityConfig.Progression; o teste
-- Cities.spec confere).
-- As bordas entre zonas ficam no meio de avenidas (a barreira atravessa a rua, como um portão).

type Point = { number }

local function road(width: number, ...: Point)
	return { Width = width, Points = { ... } }
end

local function rect(x0: number, z0: number, x1: number, z1: number): { number }
	return { x0, z0, x1, z1 }
end

local plans = {}

-- Mapa 1: Garden Village (referência 1). Ilha verde. Começa num cantinho de jardim na costa de baixo,
-- passa pelos subúrbios do lago, pelo aeroporto e termina no centro (usina, torres, rio, morro da TV, estádio).
plans.GardenVillage = {
	Width = 180,
	Depth = 160,
	DefaultDistrict = "Suburb",
	FinalScale = 18,
	Coast = {
		Inset = 6,
		Radius = 26,
		Amplitude = 4,
		Wavelength = 30,
		Shore = 2,
		Seed = 11,
		Wild = { Min = 3, Max = 9, Wavelength = 18 }, -- gramado com árvores antes do mar
	},
	Zones = {
		{
			Name = "MAPLE GARDENS",
			Rects = { rect(120, 132, 145, 160) },
			Steps = {
				{ Cap = 1, Rects = { rect(120, 132, 125, 160) } },
				{ Cap = 2, Rects = { rect(125, 132, 131, 160) } },
				{ Cap = 3 },
			},
		},
		-- casinhas em volta do jardim primeiro; o campo de futebol e as lojas grandes no fim
		{
			Name = "LAKESIDE",
			Rects = { rect(92, 108, 180, 160) },
			Steps = { { Cap = 3, Rects = { rect(119, 118, 180, 160) } }, { Cap = 4 } },
		},
		-- você chega vendo os aviões sem conseguir comê-los: cresce nas ruas de volta e depois come o aeroporto
		{
			Name = "AIRPORT",
			Rects = { rect(0, 96, 92, 160), rect(92, 96, 180, 108) },
			Steps = {
				{ Cap = 4, Rects = { rect(92, 96, 180, 108), rect(0, 96, 36, 160), rect(36, 96, 92, 110) } },
				{ Cap = 5 },
			},
		},
		{
			Name = "DOWNTOWN",
			Rects = { rect(0, 0, 180, 96) },
			Steps = {
				{ Cap = 5, Rects = { rect(0, 72, 180, 96) } },
				{ Cap = 6, Rects = { rect(0, 48, 180, 72) } },
				{ Cap = 7 },
			},
		},
	},
	Districts = {
		-- zona 1: jardim, feirinha e casinhas
		{ Kind = "Garden", Rect = rect(120, 132, 125, 160) },
		{ Kind = "Market", Rect = rect(125, 132, 131, 160) },
		-- zona 2
		{ Kind = "Commercial", Rect = rect(92, 108, 180, 118) },
		{ Kind = "Park", Rect = rect(94, 120, 118, 158) },
		{ Kind = "Park", Rect = rect(148, 120, 170, 136) },
		-- zona 3
		{ Kind = "Apartments", Rect = rect(0, 96, 36, 124) },
		{ Kind = "Commercial", Rect = rect(0, 124, 36, 160) },
		{ Kind = "Airport", Rect = rect(36, 110, 92, 160) },
		{ Kind = "Commercial", Rect = rect(36, 96, 92, 110) },
		{ Kind = "Commercial", Rect = rect(92, 96, 180, 108) },
		-- zona 4
		{ Kind = "Industrial", Rect = rect(0, 48, 48, 90) },
		{ Kind = "Apartments", Rect = rect(48, 48, 180, 96) },
		{ Kind = "Downtown", Rect = rect(0, 0, 180, 48) },
		{ Kind = "Park", Rect = rect(112, 28, 136, 46) },
	},
	Areas = {
		{ Kind = "Plaza", Rect = rect(121, 144, 124, 150) }, -- pracinha do jardim
		{ Kind = "Water", Rect = rect(100, 132, 112, 148) }, -- lago
		{ Kind = "Water", Rect = rect(104, 127, 110, 132) },
		{ Kind = "Runway", Rect = rect(38, 114, 44, 152) }, -- pista
		{ Kind = "Asphalt", Rect = rect(44, 114, 90, 152) }, -- pátio do aeroporto
		{ Kind = "Asphalt", Rect = rect(3, 51, 46, 89) }, -- pátio da usina
		{ Kind = "Asphalt", Rect = rect(60, 60, 72, 70), District = "Parking" },
		{ Kind = "Asphalt", Rect = rect(140, 100, 156, 106), District = "Parking" },
		{ Kind = "Hill", Rect = rect(144, 9, 166, 29), Levels = 3 }, -- morro da torre de TV
		{ Kind = "Plaza", Rect = rect(64, 14, 80, 30) }, -- praça da torre
		{ Kind = "Plaza", Rect = rect(116, 32, 132, 44) }, -- parque central
	},
	Rivers = {
		road(7, { 98, -1 }, { 102, 12 }, { 116, 22 }, { 140, 34 }, { 181, 40 }),
	},
	Roads = {
		-- avenidas nas bordas das zonas
		road(3, { 0, 96 }, { 180, 96 }),
		road(3, { 92, 96 }, { 92, 160 }),
		road(3, { 92, 108 }, { 180, 108 }),
		road(3, { 0, 48 }, { 180, 48 }),
		-- zona 1
		road(2, { 120, 132 }, { 145, 132 }),
		road(2, { 120, 132 }, { 120, 160 }),
		road(2, { 145, 132 }, { 145, 160 }),
		road(2, { 120, 142 }, { 145, 142 }),
		road(2, { 138.5, 142 }, { 138.5, 160 }),
		-- zona 2
		road(3, { 92, 118 }, { 180, 118 }),
		-- zona 3
		road(3, { 36, 96 }, { 36, 160 }),
		road(2, { 36, 110 }, { 92, 110 }),
	},
	Streets = {
		{
			Rect = rect(92, 118, 180, 160),
			Every = { 12, 11 },
			Width = 2,
			Offset = { 4, 0 },
			Skip = 0.1,
			Holes = { rect(92, 119, 119, 160), rect(119, 130, 147, 160) },
		},
		{ Rect = rect(0, 96, 36, 160), Every = { 12, 12 }, Width = 2, Skip = 0.15 },
		{ Rect = rect(92, 96, 180, 108), Every = { 16, 99 }, Width = 2, Skip = 0.1 },
		{ Rect = rect(36, 96, 92, 110), Every = { 14, 99 }, Width = 2 },
		{
			Rect = rect(0, 0, 180, 96),
			Every = { 20, 16 },
			Width = 3,
			Offset = { 6, 0 },
			Skip = 0.15,
			Holes = {
				rect(22, 16, 50, 36),
				rect(62, 12, 82, 32),
				rect(90, 12, 112, 30),
				rect(142, 6, 168, 31),
				rect(2, 50, 47, 90),
				rect(112, 28, 136, 46),
			},
		},
	},
	Sites = {
		{ Template = "SoccerField", X = 106, Z = 123, Rotation = 90 },
		{ Template = "Terminal", X = 66, Z = 118 },
		{ Template = "ControlTower", X = 86, Z = 132 },
		{ Template = "Plane", X = 54, Z = 132, Rotation = 90 },
		{ Template = "Plane", X = 54, Z = 144, Rotation = 90 },
		{ Template = "Plane", X = 72, Z = 140 },
		{ Template = "CoolingTower", X = 12, Z = 60 },
		{ Template = "CoolingTower", X = 22, Z = 60 },
		{ Template = "CoolingTower", X = 32, Z = 60 },
		{ Template = "FactoryHall", X = 22, Z = 76 },
		{ Template = "TVTower", X = 155, Z = 19 },
		{ Template = "SpireTower", X = 72, Z = 22 },
		{ Template = "TwinTowers", X = 101, Z = 21 },
		{ Template = "Stadium", X = 36, Z = 26 },
		{ Template = "Fountain", X = 124, Z = 38 },
	},
}

-- Mapa 2: Palm Beach (referência 2). Praia larga em volta. Começa na orla (calçadão, sorvete, casas de praia),
-- passa pelos bairros da lagoa, pelos dois lados do rio, pela marina e termina no centro com o porto
-- (guindastes, navio, farol), roda-gigante e estádio.
plans.Harbor = {
	Width = 208,
	Depth = 196,
	DefaultDistrict = "Suburb",
	FinalScale = 18,
	Coast = {
		Inset = 9,
		Radius = 30,
		Amplitude = 4,
		Wavelength = 32,
		Shore = 4,
		Seed = 23,
		Wild = { Min = 3, Max = 9, Wavelength = 20 }, -- ilha de areia com coqueiros, mar aberto em volta
	},
	Zones = {
		{
			Name = "BEACHFRONT",
			Rects = { rect(93, 168, 112, 196) },
			Steps = {
				{ Cap = 1, Rects = { rect(93, 168, 97, 196) } },
				{ Cap = 2, Rects = { rect(97, 168, 101, 196) } },
				{ Cap = 3 },
			},
		},
		{
			Name = "PALM SUBURBS",
			Rects = { rect(64, 144, 142, 196) },
			Steps = { { Cap = 3, Rects = { rect(64, 156, 142, 196) } }, { Cap = 4 } },
		},
		{
			Name = "RIVERSIDE",
			Rects = { rect(0, 144, 64, 196), rect(142, 144, 208, 196) },
			Steps = { { Cap = 4, Rects = { rect(0, 170, 64, 196), rect(142, 170, 208, 196) } }, { Cap = 5 } },
		},
		{
			Name = "MARINA",
			Rects = { rect(0, 90, 208, 144) },
			Steps = { { Cap = 5, Rects = { rect(0, 117, 208, 144) } }, { Cap = 6 } },
		},
		-- o porto, a roda-gigante, o estádio e as torres ficam para o fim
		{
			Name = "DOWNTOWN",
			Rects = { rect(0, 0, 208, 90) },
			Steps = { { Cap = 6, Rects = { rect(0, 45, 208, 90) } }, { Cap = 7 } },
		},
	},
	Districts = {
		-- zona 1
		{ Kind = "Garden", Rect = rect(93, 168, 97, 196) },
		{ Kind = "Market", Rect = rect(97, 168, 101, 196) },
		{ Kind = "Resort", Rect = rect(101, 168, 112, 196) },
		-- zona 2
		{ Kind = "Commercial", Rect = rect(64, 144, 142, 152) },
		{ Kind = "Park", Rect = rect(118, 154, 142, 190) },
		-- zona 3
		{ Kind = "Commercial", Rect = rect(0, 144, 64, 168) },
		{ Kind = "Apartments", Rect = rect(0, 168, 64, 196) },
		{ Kind = "Commercial", Rect = rect(142, 144, 208, 170) },
		{ Kind = "Apartments", Rect = rect(142, 170, 208, 196) },
		-- zona 4
		{ Kind = "Apartments", Rect = rect(0, 90, 208, 144) },
		{ Kind = "Commercial", Rect = rect(76, 90, 132, 112) },
		{ Kind = "Resort", Rect = rect(150, 120, 208, 144) },
		-- zona 5
		{ Kind = "Downtown", Rect = rect(36, 0, 130, 90) },
		{ Kind = "Park", Rect = rect(0, 0, 36, 44) },
		{ Kind = "Commercial", Rect = rect(0, 44, 36, 90) },
		{ Kind = "Harbor", Rect = rect(130, 0, 208, 50) },
		{ Kind = "Apartments", Rect = rect(130, 50, 208, 90) },
	},
	Areas = {
		{ Kind = "Plaza", Rect = rect(94, 172, 96, 180) }, -- calçadão
		{ Kind = "Sand", Rect = rect(120, 156, 140, 188) }, -- lagoa com areia em volta
		{ Kind = "Water", Rect = rect(123, 159, 137, 180) },
		{ Kind = "Water", Rect = rect(140, 6, 200, 28) }, -- baía do porto
		{ Kind = "Asphalt", Rect = rect(132, 28, 208, 46) }, -- cais
		{ Kind = "Plaza", Rect = rect(14, 16, 36, 42) }, -- parque de diversões
		{ Kind = "Plaza", Rect = rect(70, 30, 86, 46) }, -- praça das torres
		{ Kind = "Asphalt", Rect = rect(100, 98, 112, 106), District = "Parking" },
	},
	Rivers = {
		road(7, { -1, 118 }, { 30, 122 }, { 60, 114 }, { 100, 120 }, { 140, 112 }, { 180, 118 }, { 209, 114 }),
	},
	Roads = {
		-- avenidas nas bordas das zonas
		road(3, { 0, 90 }, { 208, 90 }),
		road(3, { 0, 144 }, { 208, 144 }),
		road(3, { 64, 144 }, { 64, 196 }),
		road(3, { 142, 144 }, { 142, 196 }),
		-- zona 1
		road(2, { 93, 168 }, { 112, 168 }),
		road(2, { 93, 168 }, { 93, 196 }),
		road(2, { 112, 168 }, { 112, 196 }),
		road(2, { 97, 181 }, { 112, 181 }),
		-- zona 5: avenida da orla do porto
		road(3, { 130, 0 }, { 130, 90 }),
		road(3, { 130, 48 }, { 208, 48 }),
	},
	Streets = {
		{
			Rect = rect(64, 152, 142, 196),
			Every = { 12, 11 },
			Width = 2,
			Offset = { 2, 0 },
			Skip = 0.1,
			Holes = { rect(91, 166, 114, 196), rect(117, 153, 143, 191) },
		},
		{ Rect = rect(64, 144, 142, 152), Every = { 14, 99 }, Width = 2 },
		{ Rect = rect(0, 144, 64, 196), Every = { 14, 12 }, Width = 2, Skip = 0.12 },
		{ Rect = rect(142, 144, 208, 196), Every = { 14, 12 }, Width = 2, Skip = 0.12 },
		{
			Rect = rect(0, 90, 208, 144),
			Every = { 18, 14 },
			Width = 3,
			Offset = { 4, 0 },
			Skip = 0.15,
			Holes = { rect(166, 96, 188, 112) },
		},
		{
			Rect = rect(0, 0, 130, 90),
			Every = { 22, 18 },
			Width = 3,
			Offset = { 4, 0 },
			Skip = 0.15,
			Holes = { rect(12, 14, 38, 44), rect(68, 28, 88, 48), rect(48, 14, 68, 32), rect(96, 14, 112, 30) },
		},
		{ Rect = rect(130, 48, 208, 90), Every = { 20, 14 }, Width = 3, Skip = 0.1 },
	},
	Sites = {
		{ Template = "Fountain", X = 107, Z = 176 },
		{ Template = "Crane", X = 146, Z = 33, AnyGround = true },
		{ Template = "Crane", X = 160, Z = 33, AnyGround = true },
		{ Template = "Crane", X = 174, Z = 33, AnyGround = true },
		{ Template = "CargoShip", X = 166, Z = 16, Rotation = 90 },
		{ Template = "Lighthouse", X = 196, Z = 40 },
		{ Template = "FerrisWheel", X = 25, Z = 24 },
		{ Template = "Fountain", X = 25, Z = 35 },
		{ Template = "Stadium", X = 58, Z = 23 },
		{ Template = "SpireTower", X = 78, Z = 38 },
		{ Template = "TwinTowers", X = 104, Z = 22 },
		{ Template = "Hotel", X = 176, Z = 104 },
	},
}

-- Mapa 3: Frost City (referência 3). Mar de gelo em volta. Começa num vilarejo de neve na costa leste, passa
-- pelo lago congelado, pela beira-rio, pelo porto gelado e termina no centro (usina, morro da TV, aeroporto
-- e estádio).
plans.Metropolis = {
	Width = 204,
	Depth = 196,
	DefaultDistrict = "Suburb",
	FinalScale = 18,
	Coast = {
		Inset = 6,
		Radius = 28,
		Amplitude = 4,
		Wavelength = 30,
		Shore = 3,
		Seed = 37,
		Wild = { Min = 3, Max = 9, Wavelength = 20 }, -- neve com pinheiros, num mar congelado
	},
	Zones = {
		{
			Name = "SNOWY HAMLET",
			Rects = { rect(176, 84, 204, 106) },
			Steps = {
				{ Cap = 1, Rects = { rect(176, 84, 204, 91) } },
				{ Cap = 2, Rects = { rect(176, 91, 204, 98) } },
				{ Cap = 3 },
			},
		},
		{
			Name = "FROZEN LAKE",
			Rects = { rect(150, 62, 204, 132) },
			Steps = { { Cap = 3, Rects = { rect(170, 62, 204, 132) } }, { Cap = 4 } },
		},
		{
			Name = "RIVERSIDE",
			Rects = { rect(150, 0, 204, 62), rect(150, 132, 204, 196) },
			Steps = { { Cap = 4, Rects = { rect(150, 40, 204, 62), rect(150, 132, 204, 154) } }, { Cap = 5 } },
		},
		-- os guindastes e o navio do porto ficam para o fim
		{
			Name = "ICE PORT",
			Rects = { rect(96, 0, 150, 196) },
			Steps = { { Cap = 5, Rects = { rect(96, 100, 150, 196) } }, { Cap = 6 } },
		},
		{
			Name = "DOWNTOWN",
			Rects = { rect(0, 0, 96, 196) },
			Steps = { { Cap = 6, Rects = { rect(0, 104, 96, 196) } }, { Cap = 7 } },
		},
	},
	Districts = {
		-- zona 1
		{ Kind = "Garden", Rect = rect(176, 84, 204, 91) },
		{ Kind = "Market", Rect = rect(176, 91, 204, 98) },
		-- zona 2
		{ Kind = "Park", Rect = rect(152, 64, 176, 92) },
		{ Kind = "Lodge", Rect = rect(176, 112, 204, 132) },
		{ Kind = "Commercial", Rect = rect(150, 62, 204, 68) },
		-- zona 3
		{ Kind = "Commercial", Rect = rect(150, 0, 204, 62) },
		{ Kind = "Apartments", Rect = rect(150, 132, 204, 196) },
		-- zona 4
		{ Kind = "Harbor", Rect = rect(96, 0, 150, 42) },
		{ Kind = "Apartments", Rect = rect(96, 42, 150, 120) },
		{ Kind = "Commercial", Rect = rect(96, 120, 150, 196) },
		-- zona 5
		{ Kind = "Downtown", Rect = rect(30, 0, 96, 104) },
		{ Kind = "Apartments", Rect = rect(0, 0, 30, 104) },
		{ Kind = "Airport", Rect = rect(0, 104, 54, 150) },
		{ Kind = "Industrial", Rect = rect(0, 150, 54, 196) },
		{ Kind = "Downtown", Rect = rect(54, 104, 96, 196) },
	},
	Areas = {
		{ Kind = "Plaza", Rect = rect(184, 85, 190, 90) }, -- pracinha do vilarejo
		{ Kind = "Water", Rect = rect(158, 70, 172, 86) }, -- lago congelado
		{ Kind = "Water", Rect = rect(104, 8, 146, 24) }, -- baía do porto
		{ Kind = "Asphalt", Rect = rect(96, 24, 150, 40) }, -- cais
		{ Kind = "Hill", Rect = rect(10, 12, 32, 32), Levels = 3 }, -- morro da torre de TV
		{ Kind = "Runway", Rect = rect(10, 108, 16, 146) },
		{ Kind = "Asphalt", Rect = rect(16, 108, 52, 146) }, -- pátio do aeroporto
		{ Kind = "Asphalt", Rect = rect(8, 154, 52, 188) }, -- usina
		{ Kind = "Plaza", Rect = rect(56, 40, 72, 56) }, -- praça do centro
		{ Kind = "Asphalt", Rect = rect(112, 60, 124, 68), District = "Parking" },
	},
	Rivers = {
		road(
			7,
			{ 205, 40 },
			{ 180, 46 },
			{ 160, 40 },
			{ 130, 52 },
			{ 110, 48 },
			{ 90, 60 },
			{ 70, 64 },
			{ 40, 58 },
			{ -1, 66 }
		),
	},
	Roads = {
		-- avenidas nas bordas das zonas
		road(3, { 150, 0 }, { 150, 196 }),
		road(3, { 96, 0 }, { 96, 196 }),
		road(3, { 150, 62 }, { 204, 62 }),
		road(3, { 150, 132 }, { 204, 132 }),
		-- zona 1
		road(2, { 176, 84 }, { 204, 84 }),
		road(2, { 176, 106 }, { 204, 106 }),
		road(2, { 176, 84 }, { 176, 106 }),
		road(2, { 184, 91 }, { 204, 91 }),
		-- zona 5
		road(3, { 0, 104 }, { 96, 104 }),
		road(3, { 54, 104 }, { 54, 196 }),
		road(3, { 0, 150 }, { 54, 150 }),
	},
	Streets = {
		{
			Rect = rect(150, 62, 204, 132),
			Every = { 12, 11 },
			Width = 2,
			Skip = 0.1,
			Holes = { rect(151, 63, 177, 93), rect(174, 82, 204, 108) },
		},
		{ Rect = rect(150, 0, 204, 62), Every = { 14, 12 }, Width = 2, Skip = 0.12 },
		{ Rect = rect(150, 132, 204, 196), Every = { 14, 12 }, Width = 2, Skip = 0.12 },
		{ Rect = rect(96, 40, 150, 196), Every = { 18, 14 }, Width = 3, Skip = 0.15 },
		{
			Rect = rect(0, 0, 96, 104),
			Every = { 20, 16 },
			Width = 3,
			Offset = { 2, 0 },
			Skip = 0.15,
			Holes = { rect(8, 10, 34, 34), rect(54, 38, 74, 58), rect(36, 72, 62, 92), rect(70, 14, 86, 30) },
		},
		{ Rect = rect(54, 104, 96, 196), Every = { 21, 16 }, Width = 3, Skip = 0.1 },
	},
	Sites = {
		{ Template = "Fountain", X = 184, Z = 101.5 },
		{ Template = "Crane", X = 108, Z = 29, Rotation = 180, AnyGround = true },
		{ Template = "Crane", X = 122, Z = 29, Rotation = 180, AnyGround = true },
		{ Template = "Crane", X = 136, Z = 29, Rotation = 180, AnyGround = true },
		{ Template = "CargoShip", X = 125, Z = 15, Rotation = 90 },
		{ Template = "TVTower", X = 21, Z = 22 },
		{ Template = "SpireTower", X = 64, Z = 48 },
		{ Template = "TwinTowers", X = 78, Z = 22 },
		{ Template = "Stadium", X = 49, Z = 82 },
		{ Template = "Terminal", X = 36, Z = 112 },
		{ Template = "ControlTower", X = 46, Z = 140 },
		{ Template = "Plane", X = 26, Z = 126, Rotation = 90 },
		{ Template = "Plane", X = 40, Z = 130 },
		{ Template = "CoolingTower", X = 16, Z = 162 },
		{ Template = "CoolingTower", X = 26, Z = 162 },
		{ Template = "CoolingTower", X = 36, Z = 162 },
		{ Template = "FactoryHall", X = 26, Z = 178 },
	},
}

return table.freeze(plans)
