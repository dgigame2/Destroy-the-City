--!strict
-- Layout das interfaces para qualquer aparelho. Funções puras (testáveis no Lune).
-- Um layout só para todos os aparelhos (não troca entre "celular" e "PC" no meio do jogo):
--   dinheiro e gemas lado a lado em cima à esquerda, atalhos logo abaixo (1 coluna; 2 em telas baixas como
--   celulares deitados), progresso da run em cima no centro, botões da run embaixo no centro (longe do pulo).
-- As medidas de saída são pixels reais da área da interface (já descontando barra do Roblox e bordas seguras
-- do aparelho). As medidas de entrada (UiConfig) são do layout de referência 1280x720.

local UiLayout = {}

export type Rect = { X0: number, Y0: number, X1: number, Y1: number }

export type UiConfig = {
	DesignWidth: number,
	DesignHeight: number,
	MinScale: number,
	MaxScale: number,
	[string]: any,
}

-- O layout de referência cabe inteiro na tela (usa o lado mais apertado).
function UiLayout.scale(viewportW: number, viewportH: number, config: UiConfig): number
	local s = math.min(viewportW / config.DesignWidth, viewportH / config.DesignHeight)
	return math.clamp(s, config.MinScale, config.MaxScale)
end

function UiLayout.rect(x: number, y: number, w: number, h: number): Rect
	return { X0 = x, Y0 = y, X1 = x + w, Y1 = y + h }
end

local rect = UiLayout.rect

export type Layout = {
	Scale: number,
	Cash: Rect,
	Gems: Rect,
	Icons: Rect,
	IconCells: { Rect }, -- SHOP, SPIN, GIFT, CLASS
	IconColumns: number,
	Timer: Rect,
	MatchBar: Rect,
	MatchButtons: { Rect }, -- UPGRADES, LOBBY
	Toast: Rect,
	Popup: Rect,
	Victory: Rect,
	Frenzy: Rect,
	Celebration: Rect,
	Chips: { Rect }, -- prêmios dentro da comemoração (coordenadas da tela)
	Continue: Rect, -- botão CONTINUE embaixo da comemoração
}

-- Fila de botões lado a lado, alinhados por baixo, a partir de (x, y) com altura total h.
local function row(
	x: number,
	y: number,
	h: number,
	sizes: { { W: number, H: number } },
	s: number,
	gap: number
): { Rect }
	local list = {}
	for _, size in sizes do
		table.insert(list, rect(x, y + h - size.H * s, size.W * s, size.H * s))
		x += size.W * s + gap
	end
	return list
end

local function rowWidth(sizes: { { W: number, H: number } }, s: number, gap: number): number
	local w = 0
	for _, size in sizes do
		w += size.W * s
	end
	return w + gap * (#sizes - 1)
end

function UiLayout.place(w: number, h: number, c: UiConfig): Layout
	local s = UiLayout.scale(w, h, c)
	local m, gap = c.Margin, c.Gap * s

	-- dinheiro e gemas lado a lado (assim a coluna de atalhos fica mais alta na tela)
	local cash = rect(m, m, c.Currency.W * s, c.Currency.H * s)
	local gems = rect(cash.X1 + gap, m, c.Currency.W * s, c.Currency.H * s)

	-- atalhos logo abaixo do dinheiro: uma coluna, ou duas em telas baixas (preenchidas coluna por coluna)
	local columns = if h < c.CompactHeight then 2 else 1
	local rows = math.ceil(c.IconCount / columns)
	local cell = c.IconButton.W * s
	local iconsY = cash.Y1 + gap * 2
	local icons = rect(m, iconsY, columns * cell + (columns - 1) * gap, rows * cell + (rows - 1) * gap)
	local cells = {}
	for index = 0, c.IconCount - 1 do
		local col, r = index // rows, index % rows
		table.insert(cells, rect(m + col * (cell + gap), iconsY + r * (cell + gap), cell, cell))
	end

	-- barra da run embaixo no centro
	local matchSizes = { c.UpgradesButton, c.LobbyButton }
	local barH = math.max(c.UpgradesButton.H, c.LobbyButton.H) * s
	local matchW = rowWidth(matchSizes, s, gap)
	local barY = h - m - barH
	local matchBar = rect((w - matchW) / 2, barY, matchW, barH)
	local matchButtons = row(matchBar.X0, barY, barH, matchSizes, s, gap)

	-- relógio em cima no centro, subindo para a faixa da barra do Roblox (o centro dela fica livre)
	local timerW, timerH = c.Timer.W * s, c.Timer.H * s
	local timer = rect((w - timerW) / 2, c.TimerTop - c.TopbarInset, timerW, timerH)

	-- textos de aviso (não são botões)
	local toastW, toastH = math.min(c.Toast.W * s, w - 2 * m), c.Toast.H * s
	local toast = rect((w - toastW) / 2, c.Toast.Y * s, toastW, toastH)
	local popupW, popupH = c.Popup.W * s, c.Popup.H * s
	local popup = rect((w - popupW) / 2, toast.Y1 + 20 * s, popupW, popupH)
	-- vitória: faixa grande no meio (não é botão), nunca maior que a tela
	local victoryW = math.min(c.WinnerBanner.W * s, w - 2 * m)
	local victoryH = c.WinnerBanner.H * s
	local victory = rect((w - victoryW) / 2, (h - victoryH) * 0.35, victoryW, victoryH)

	-- FRENZY: logo abaixo do progresso da run (não é botão)
	local frenzyW, frenzyH = c.Frenzy.W * s, c.Frenzy.H * s
	local frenzy = rect((w - frenzyW) / 2, math.max(timer.Y1 + gap, m), frenzyW, frenzyH)

	-- comemoração de área limpa: painel no meio, com três prêmios embaixo do título
	local celebW = math.min(c.Celebration.W * s, w - 2 * m)
	local celebScale = celebW / c.Celebration.W
	local celebH = c.Celebration.H * celebScale
	-- painel + CONTINUE embaixo: o conjunto sobe se preciso para não encostar na barra da run
	local cb = c.ContinueButton
	local continueH = math.max(cb.H * celebScale, c.MinTouch)
	local continueW = math.max(cb.W * celebScale, continueH * cb.W / cb.H)
	local stackH = celebH + cb.Gap * celebScale + continueH
	local celebY = math.min((h - stackH) * 0.38, matchBar.Y0 - gap - stackH)
	local celebration = rect((w - celebW) / 2, math.max(m, celebY), celebW, celebH)
	local chipW, chipH = c.RewardChip.W * celebScale, c.RewardChip.H * celebScale
	local chipGap = 24 * celebScale
	local chipsW = 3 * chipW + 2 * chipGap
	local chips = {}
	for i = 0, 2 do
		table.insert(
			chips,
			rect(
				celebration.X0 + (celebW - chipsW) / 2 + i * (chipW + chipGap),
				celebration.Y1 - (24 * celebScale) - chipH,
				chipW,
				chipH
			)
		)
	end

	local continue =
		rect(celebration.X0 + (celebW - continueW) / 2, celebration.Y1 + cb.Gap * celebScale, continueW, continueH)

	return {
		Scale = s,
		Frenzy = frenzy,
		Celebration = celebration,
		Chips = chips,
		Continue = continue,
		Cash = cash,
		Gems = gems,
		Icons = icons,
		IconCells = cells,
		IconColumns = columns,
		Timer = timer,
		MatchBar = matchBar,
		MatchButtons = matchButtons,
		Toast = toast,
		Popup = popup,
		Victory = victory,
	}
end

-- Escala de uma janela: a mesma do HUD, mas nunca maior que a tela (celulares bem curtos).
function UiLayout.windowScale(w: number, h: number, size: { W: number, H: number }, c: UiConfig): number
	local fit = math.min((w - 2 * c.Margin) / size.W, (h - 2 * c.Margin) / size.H)
	return math.min(UiLayout.scale(w, h, c), fit)
end

export type PartyWindow = {
	Prev: Rect,
	MapCard: Rect,
	Next: Rect,
	Difficulty: { Rect }, -- NORMAL, HARD, INSANE
	SizeLabel: Rect,
	Minus: Rect,
	Size: Rect,
	Plus: Rect,
	Back: Rect,
	Create: Rect,
	SavedTitle: Rect,
	SavedList: Rect,
	-- dentro de cada card de run salva (coordenadas do card)
	SavedCard: {
		Title: Rect,
		With: Rect,
		DifficultyTag: Rect,
		ProgressTag: Rect,
		Expires: Rect,
		Load: Rect,
	},
}

-- Posições dentro da janela CREATE PARTY (pixels do layout de referência; a janela inteira é escalada).
function UiLayout.partyWindow(c: UiConfig): PartyWindow
	local g = c.Gap
	local pad = g * 2
	local col = c.PartyColumn
	local x0 = pad

	-- 1ª linha: < [mapa] >
	local y1 = c.HeaderH + 18
	local arrow = c.MapArrow
	local prev = rect(x0, y1, arrow.W, arrow.H)
	local mapCard = rect(prev.X1 + g, y1, col - 2 * arrow.W - 2 * g, arrow.H)
	local nextR = rect(mapCard.X1 + g, y1, arrow.W, arrow.H)

	-- 2ª linha: três dificuldades
	local y2 = prev.Y1 + g
	local d = c.DifficultyButton
	local difficulty = {}
	for i = 0, 2 do
		table.insert(difficulty, rect(x0 + i * (d.W + g), y2, d.W, d.H))
	end

	-- 3ª linha: PARTY  [-] [n] [+]
	local y3 = y2 + d.H + g
	local step = c.StepButton
	local sizeLabel = rect(x0, y3, 100, step.H)
	local minus = rect(sizeLabel.X1 + g, y3, step.W, step.H)
	local size = rect(minus.X1 + g, y3, step.W, step.H)
	local plus = rect(size.X1 + g, y3, step.W, step.H)

	-- 4ª linha: BACK e CREATE
	local y4 = y3 + step.H + g
	local back = rect(x0, y4, c.BackButton.W, c.BackButton.H)
	local create = rect(back.X1 + g, y4, c.CreateButton.W, c.CreateButton.H)

	-- coluna da direita: runs salvas
	local rightX = x0 + col + pad
	local rightW = c.PartyWindow.W - rightX - pad
	local savedTitle = rect(rightX, c.HeaderH + g, rightW, 40)
	local listY = savedTitle.Y1 + g
	local savedList = rect(rightX, listY, rightW, c.PartyWindow.H - listY - g)

	-- card de run salva
	local card = c.SavedCard
	local inner = card.W - 24
	local textRow = c.TextRow
	local title = rect(12, 10, inner, 32)
	local with = rect(12, title.Y1 + 4, inner, textRow)
	local tagY = with.Y1 + 6
	local difficultyTag = rect(12, tagY, 112, 32)
	local progressTag = rect(difficultyTag.X1 + 8, tagY, inner - 112 - 8, 32)
	local expires = rect(12, difficultyTag.Y1 + 4, inner, textRow)
	local load = rect(12, expires.Y1 + 6, inner, c.CardButton.H)

	return {
		Prev = prev,
		MapCard = mapCard,
		Next = nextR,
		Difficulty = difficulty,
		SizeLabel = sizeLabel,
		Minus = minus,
		Size = size,
		Plus = plus,
		Back = back,
		Create = create,
		SavedTitle = savedTitle,
		SavedList = savedList,
		SavedCard = {
			Title = title,
			With = with,
			DifficultyTag = difficultyTag,
			ProgressTag = progressTag,
			Expires = expires,
			Load = load,
		},
	}
end

-- Áreas dos controles de toque do Roblox (analógico e pulo), em pixels da TELA INTEIRA.
-- Pulo: ESTIMATIVA do PlayerModule padrão do Roblox (TouchJump): telas com lado menor <= 500 px: botão de 70 px
--   em (W-95, H-90); senão 120 px em (W-170, H-210).
-- Analógico: MEDIDO no emulador do Studio (print de 14/11/2026, celular deitado): área cinza de ~40,6% da largura
--   à esquerda, começando em ~45,6% da altura até embaixo.
-- Uma folga (Pad) é somada em volta para o dedo não esbarrar nos botões.
function UiLayout.touchZones(screenW: number, screenH: number, pad: number): { Rect }
	local small = math.min(screenW, screenH) <= 500
	local jumpSize = if small then 70 else 120
	local jumpX = if small then screenW - 95 else screenW - 170
	local jumpY = if small then screenH - 90 else screenH - 210
	return {
		rect(0, screenH * 0.456 - pad, screenW * 0.406 + pad, screenH * 0.544 + pad), -- analógico
		rect(jumpX - pad, jumpY - pad, jumpSize + pad * 2, jumpSize + pad * 2), -- pulo
	}
end

function UiLayout.intersects(a: Rect, b: Rect, gap: number?): boolean
	local g = gap or 0
	return a.X0 < b.X1 + g and b.X0 < a.X1 + g and a.Y0 < b.Y1 + g and b.Y0 < a.Y1 + g
end

-- Largura aproximada de um texto em px no tamanho dado. ESTIMATIVA para a fonte Fredoka One:
-- ~0.58 do tamanho por caractere (emoji conta como 1 caractere).
function UiLayout.textWidth(text: string, size: number): number
	return utf8.len(text) :: number * size * 0.58
end

return UiLayout
