--!strict
-- Paleta "Diorama": todas as cores de interface e textos do jogo, tiradas dos mapas (MapConfig:
-- Garden Village, Palm Beach, Frost City). Céu, grama, areia, telhado e mar; contorno azul-ardósia
-- (as sombras dos mapas são azuladas) e papel creme (paredes e areia). RGB 0-255.
-- Cada tema de painel/botão tem Top/Bottom (gradiente) e Outline (contorno).

export type RGB = { number }
export type ThemeRGB = { Top: RGB, Bottom: RGB, Outline: RGB }

local INK = { 43, 58, 103 } -- contorno e borda dos textos

local function theme(top: RGB, bottom: RGB, outline: RGB?): ThemeRGB
	return table.freeze({ Top = top, Bottom = bottom, Outline = outline or INK })
end

return table.freeze({
	Font = "FredokaOne",
	Ink = INK,
	Shadow = { 74, 106, 168 }, -- sombra azulada do Depth Stack
	ShadowTransparency = 0.5,
	Lift = 0.78, -- transparência do brilho de cima (lift)
	-- borda de grama em blocos embaixo do cabeçalho das janelas (o "chão" da ilha dos mapas)
	GrassLip = table.freeze({ Light = { 77, 180, 58 }, Dark = { 63, 154, 48 }, Blocks = 14, Height = 10 }),

	Themes = table.freeze({
		Sky = theme({ 143, 211, 255 }, { 62, 155, 234 }),
		Grass = theme({ 168, 234, 111 }, { 77, 180, 58 }),
		Sand = theme({ 255, 229, 144 }, { 240, 174, 62 }),
		Roof = theme({ 255, 146, 130 }, { 223, 70, 80 }),
		Sea = theme({ 134, 236, 239 }, { 34, 163, 212 }),
		Violet = theme({ 207, 166, 255 }, { 138, 90, 224 }),
		Blossom = theme({ 255, 159, 208 }, { 224, 90, 166 }),
		Sunset = theme({ 255, 196, 120 }, { 240, 128, 50 }),
		Stone = theme({ 223, 228, 238 }, { 167, 176, 198 }),
		Paper = theme({ 255, 253, 246 }, { 241, 232, 211 }),
		Night = theme({ 92, 112, 168 }, { 52, 68, 120 }),
	}),

	-- cores de texto e barras (sem gradiente)
	Text = table.freeze({
		White = { 255, 255, 255 },
		Gold = { 255, 229, 120 }, -- nome do mapa, combo, avisos bons
		Cream = { 255, 248, 214 }, -- subtítulos
		Danger = { 255, 140, 130 }, -- avisos ruins, expira
		Gem = { 196, 238, 255 },
		Cash = { 214, 255, 196 },
		Track = { 43, 58, 103 }, -- fundo de barras de progresso
		Fill = { 255, 214, 80 }, -- barra de progresso
		LevelFill = { 140, 236, 120 },
		Badge = { 236, 72, 80 }, -- bolinha "!" nos atalhos
		Ray = { 255, 240, 170 }, -- raios de luz atrás da vitória
		Combo = { 255, 166, 80 },
	}),

	-- uma cor por desastre (barra de nível, avisos, mira)
	Disasters = table.freeze({
		Meteor = { 255, 166, 80 },
		Tornado = { 134, 220, 250 },
		Lightning = { 255, 229, 120 },
		Earthquake = { 196, 140, 96 },
	}),
	-- efeitos dos desastres (client/Controllers/DisasterVfx) e barra de HP das construções (DamageVfx)
	Vfx = table.freeze({
		MeteorShadow = { 70, 40, 60 },
		Meteor = { 72, 58, 70 }, -- pedra (mesh do Blender sem textura)
		Lava = { 255, 128, 48 },
		ImpactRing = { 255, 206, 130 },
		ImpactFlash = { 255, 228, 170 },
		BurstHot = { 255, 176, 96 },
		Smoke = { 112, 104, 120 },
		ImpactLight = { 255, 186, 100 },
		Tornado = { 214, 226, 242 }, -- funil claro azulado (céu dos mapas)
		TornadoRing = { 160, 172, 190 }, -- discos (sem a mesh): + 10 por camada
		Dust = { 214, 200, 168 },
		Cloud = { 104, 116, 150 },
		Bolt = { 160, 226, 255 },
		BoltCore = { 255, 255, 255 },
		Explosion = { 255, 156, 66 },
		Collapse = { 196, 186, 176 },
		ExplosionSmoke = { 255, 176, 90 },
		CollapseDust = { 214, 204, 192 },
		ExplosionLight = { 255, 166, 76 },
		Fire = { 255, 120, 40 }, -- fogo da cadeia (chamas)
		FireCore = { 255, 214, 110 },
		FireSmoke = { 90, 82, 92 },
		Spark = { 150, 230, 255 }, -- faísca do condutor
		ImpactDust = { 200, 186, 160 }, -- batida de objeto que voou
		HpShadow = { 74, 106, 168 },
		HpBack = { 43, 58, 103 },
		HpStroke = { 43, 58, 103 },
	}),

	Aim = table.freeze({ Ok = { 255, 229, 120 }, Far = { 255, 130, 120 } }),

	-- placas das áreas da cidade (mundo 3D)
	AreaSign = table.freeze({
		Pill = { 22, 26, 40 }, -- fundo da pílula (escuro translúcido)
		Locked = { 255, 96, 104 }, -- contorno de cada estado
		Current = { 126, 230, 92 },
		Cleared = { 200, 208, 224 },
	}),

	-- ilha do lobby: mesmas cores do Garden Village (MapConfig) para o lobby ter a vibe dos mapas
	Lobby = table.freeze({
		Grass = { 104, 214, 64 },
		GrassDark = { 88, 198, 52 },
		Sand = { 244, 224, 160 },
		Dirt = { 150, 98, 60 },
		DirtDark = { 128, 82, 50 },
		-- praça e caminhos um tom abaixo: lisos (sem textura) o claro estourava com a luz do lobby
		Stone = { 186, 190, 212 },
		Path = { 212, 202, 178 },
		-- cidadezinha em volta do parque: asfalto azulado, calçada clara e faixa amarela
		Hedge = { 84, 186, 60 },
		-- árvores de blocos: folha (multiplica a textura) e tronco
		Leaves = { 150, 214, 110 },
		Trunk = { 122, 82, 50 },
		PathBorder = { 196, 186, 166 },
		Road = { 78, 84, 98 },
		Sidewalk = { 218, 214, 204 },
		RoadLine = { 255, 214, 80 },
		-- fonte da praça: pedra creme, detalhes um tom abaixo e água azul-piscina
		FountainStone = { 222, 206, 178 },
		FountainTrim = { 190, 170, 140 },
		FountainWater = { 92, 206, 236 },
		Wood = { 170, 110, 60 },
		Red = { 223, 70, 80 },
		White = { 250, 248, 240 },
		Blue = { 62, 155, 234 },
		Gold = { 255, 214, 80 },
		Purple = { 138, 90, 224 },
		Neon = { 134, 236, 239 },
		ShopWindow = { 150, 220, 255 },
		Hub = { 120, 126, 142 },
		Board = { 43, 58, 103 },
		Floor = { 230, 186, 104 },
		SignText = { 255, 229, 120 },
	}),

	Confetti = table.freeze({
		{ 255, 146, 130 },
		{ 143, 211, 255 },
		{ 255, 229, 144 },
		{ 168, 234, 111 },
		{ 207, 166, 255 },
	}),
})
