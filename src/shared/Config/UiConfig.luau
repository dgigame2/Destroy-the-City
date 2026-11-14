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
	Timer = { W = 260, H = 74 },
	Toast = { W = 900, H = 64, Y = 140 },
	Combo = { W = 320, H = 60 },

	-- Botões do lobby (embaixo, centralizados)
	Play = { W = 240, H = 92 },
	Spectate = { W = 200, H = 88 },
	AutoJoin = { W = 190, H = 88 },

	-- Janela padrão (loja, roleta, recompensas)
	Window = { W = 860, H = 560 },
	HeaderH = 92,
	CloseButton = { W = 88, H = 88 },
	Tab = { W = 180, H = 88 },
	Card = { W = 190, H = 300 },
	CardButton = { H = 88 },

	WheelView = 420,
	WheelButton = { W = 320, H = 88 },

	DayTile = { W = 104, H = 150 },
	ClaimButton = { W = 360, H = 88 },
	WeeklyPanel = { W = 360, H = 200 },

	VoteTitleH = 110,
	VoteCard = { W = 300, H = 380 },
	WinnerBanner = { W = 1000, H = 160 },
	Popup = { W = 520, H = 140 },
})
