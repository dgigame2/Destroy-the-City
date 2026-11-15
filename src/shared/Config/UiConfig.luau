--!strict
-- Medidas das interfaces, em pixels de um layout de referência 1280x720 (área abaixo da barra do Roblox).
-- Na tela real tudo é multiplicado por um UIScale (ver Logic/UiLayout).
-- Todo botão tem pelo menos 88 de altura: na menor escala (0.5) continua com 44px (tamanho do polegar).

return table.freeze({
	DesignWidth = 1280,
	DesignHeight = 720,
	MinScale = 0.5,
	MaxScale = 3,
	MinTouch = 44,
	Margin = 16,
	TopbarInset = 58,
	Gap = 12,

	Currency = { W = 210, H = 56 }, -- dinheiro e gemas, empilhados no topo esquerdo
	IconButton = { W = 88, H = 88 }, -- coluna de atalhos (loja, roleta, recompensas, classes)
	IconCount = 4,
	-- Telas baixas (celulares deitados): atalhos em 2 colunas (SHOP e SPIN na primeira, GIFT e CLASS na segunda).
	-- Decide pela altura da área da interface, que não muda durante o jogo.
	CompactHeight = 500,
	Timer = { W = 270, H = 84 }, -- na run: "% EATEN", nome do mapa e barra de progresso
	TimerTop = 6, -- o relógio sobe para a faixa da barra do Roblox (centro, que fica livre): px do topo da tela
	Toast = { W = 900, H = 64, Y = 140 },
	Combo = { W = 320, H = 60 },

	-- Botões da run (embaixo, centralizados)
	UpgradesButton = { W = 260, H = 92 },
	LobbyButton = { W = 200, H = 88 },
	LeaveConfirmSeconds = 3, -- o botão LOBBY pede um segundo toque dentro desse tempo

	-- Janela padrão (loja, roleta, recompensas)
	Window = { W = 860, H = 520 }, -- cabe em celulares curtos (640x360) na escala mínima
	HeaderH = 92,
	CloseButton = { W = 88, H = 88 },
	Tab = { W = 180, H = 88 },
	TabCount = 3, -- ITEMS, CLASSES, ROBUX (upgrades têm janela própria na partida)
	UpgradeWindow = { W = 860, H = 430 },
	Card = { W = 190, H = 280 },
	CardButton = { H = 88 },

	WheelView = 400,
	WheelButton = { W = 320, H = 88 },
	-- Prêmios na roda da janela: ícone grande perto da borda e texto curto ao longo do raio.
	-- Raios em fração do raio da roda; tamanhos em fração do diâmetro.
	WheelPrize = { IconRadius = 0.86, IconSize = 0.1, TextFrom = 0.24, TextTo = 0.74, TextThickness = 0.09 },
	WheelCamera = { Fov = 40, Distance = 46, Lift = 1.5 }, -- câmera da roda dentro da janela

	DayTile = { W = 104, H = 150 },
	ClaimButton = { W = 360, H = 88 },
	WeeklyPanel = { W = 360, H = 200 },

	-- Janela CREATE PARTY (lobby): coluna da esquerda com mapa, dificuldade, tamanho e botões;
	-- coluna da direita com as runs salvas. Posições internas em Logic/UiLayout.partyWindow.
	PartyWindow = { W = 860, H = 520 },
	PartyColumn = 480,
	MapArrow = { W = 88, H = 100 },
	DifficultyButton = { W = 152, H = 88 },
	StepButton = { W = 88, H = 88 }, -- botões - e + do tamanho da party
	BackButton = { W = 180, H = 88 },
	CreateButton = { W = 288, H = 88 },
	SavedCard = { W = 300, H = 248 },
	TextRow = 28, -- linha de texto: 28 x escala mínima (0.5) = 14px, a fonte mínima
	TouchPad = 8, -- folga em volta do botão de pulo do celular (px)
	MinTextSize = 14, -- igual ao UITextSizeConstraint do Style ("No Tiny Text")
	WinnerBanner = { W = 1000, H = 160 }, -- vitória da run
	-- Áreas da cidade: aviso de FRENZY embaixo do progresso e a comemoração ao limpar uma área
	Frenzy = { W = 300, H = 56 },
	Celebration = { W = 820, H = 290 },
	RewardChip = { W = 240, H = 66 },
	ContinueButton = { W = 300, H = 88, Gap = 16 }, -- embaixo da comemoração: fecha antes do tempo
	ConfettiPieces = 60,
	Popup = { W = 520, H = 140 },
	-- placa flutuante de cada área da cidade (client/Controllers/AreaSignsController), em studs
	AreaSign = table.freeze({
		PixelWidth = 260, -- largura na tela (px numa tela de 720 de altura): tamanho fixo, sem zoom gigante
		Aspect = 0.3, -- altura = largura x isso
		MinScreenScale = 0.6, -- celulares: placa encolhe com a tela até este limite
		Height = 30, -- quanto fica acima do chão (studs, x escala do jogador ^ GrowExponent)
		GrowExponent = 0.8,
		MaxDistance = 6000,
		TouchPadding = 1.2, -- folga (studs) em volta do corpo: só conta encostar de verdade na barreira
		WarningCooldown = 2.5, -- segundos entre dois avisos de área bloqueada
	}),
	-- borda da área atual (client/Controllers/AreaSignsController): só a barreira da PRÓXIMA área brilha,
	-- numa altura que acompanha o seu tamanho (não vira um paredão)
	BarrierGlow = table.freeze({
		HeightPerScale = 3, -- altura = isso x escala do jogador (no mínimo a altura da barreira)
		Transparency = 0.5,
		TopLine = 0.4, -- linha forte no topo (x escala)
		Color = { 255, 60, 90 },
	}),
})
