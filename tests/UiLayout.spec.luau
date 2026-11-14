-- Checklist de UI do goat em 4 tamanhos reais de tela:
-- botões do tamanho do polegar, nada encostando, janelas cabendo na tela.
-- As telas descontam a barra do Roblox (TopbarInset): a interface começa abaixo dela.
local UiLayout = require("../src/shared/Logic/UiLayout")
local UiConfig = require("../src/shared/Config/UiConfig")

local SCREENS = {
	{ Name = "Celular pequeno (iPhone SE)", W = 667, H = 375 },
	{ Name = "Notebook HD", W = 1366, H = 768 },
	{ Name = "Full HD", W = 1920, H = 1080 },
	{ Name = "4K", W = 3840, H = 2160 },
}

local function rect(x, y, w, h)
	return { X0 = x, Y0 = y, X1 = x + w, Y1 = y + h }
end

-- Distância entre dois retângulos (0 = encostando ou sobrepostos).
local function separated(a, b, gap)
	return a.X1 + gap <= b.X0 or b.X1 + gap <= a.X0 or a.Y1 + gap <= b.Y0 or b.Y1 + gap <= a.Y0
end

return function(t)
	local c = UiConfig

	t.test("todos os botões têm >= 88 de altura/largura no layout de referência", function()
		for name, size in
			{
				IconButton = c.IconButton,
				Play = c.Play,
				Spectate = c.Spectate,
				AutoJoin = c.AutoJoin,
				Close = c.CloseButton,
				Tab = c.Tab,
				CardButton = { W = c.Card.W - 24, H = c.CardButton.H },
				WheelButton = c.WheelButton,
				Claim = c.ClaimButton,
				VoteCard = c.VoteCard,
			}
		do
			if size.W < 88 or size.H < 88 then
				error(`{name} menor que 88: {size.W}x{size.H}`)
			end
		end
	end)

	for _, full in SCREENS do
		local screen = { Name = full.Name, W = full.W, H = full.H - c.TopbarInset }
		local s = UiLayout.scale(screen.W, screen.H, c)
		local m, gap = c.Margin, c.Gap * s

		-- posições reais (px) dos elementos do HUD
		local cash = rect(m, m, c.Currency.W * s, c.Currency.H * s)
		local gems = rect(m, cash.Y1 + gap, c.Currency.W * s, c.Currency.H * s)
		local iconsH = (c.IconCount * c.IconButton.H + (c.IconCount - 1) * c.Gap) * s
		local icons = rect(m, gems.Y1 + 2 * gap, c.IconButton.W * s, iconsH)
		local timer = rect((screen.W - c.Timer.W * s) / 2, m, c.Timer.W * s, c.Timer.H * s)
		local bottomW = (c.Play.W + c.Spectate.W + c.AutoJoin.W + 2 * c.Gap) * s
		local bottomH = c.Play.H * s
		local lobbyButtons = rect((screen.W - bottomW) / 2, screen.H - m - bottomH, bottomW, bottomH)

		t.test(`{screen.Name}: menor botão >= {c.MinTouch}px`, function()
			t.truthy(88 * s >= c.MinTouch)
		end)

		t.test(`{screen.Name}: HUD cabe na tela`, function()
			t.truthy(icons.Y1 <= screen.H - m)
			t.truthy(lobbyButtons.Y0 >= 0)
		end)

		t.test(`{screen.Name}: nada encosta (moedas, gemas, atalhos, relógio, botões do lobby)`, function()
			local list = { cash, gems, icons, timer, lobbyButtons }
			for i = 1, #list do
				for j = i + 1, #list do
					if not separated(list[i], list[j], gap) then
						error(`elementos {i} e {j} encostam`)
					end
				end
			end
		end)

		t.test(`{screen.Name}: janela cabe na tela com margem`, function()
			t.truthy(c.Window.W * s <= screen.W - 2 * m)
			t.truthy(c.Window.H * s <= screen.H - 2 * m)
		end)

		t.test(`{screen.Name}: votação (3 cards) cabe na tela`, function()
			local width = (3 * c.VoteCard.W + 2 * c.Gap * 2) * s
			local height = (c.VoteTitleH + c.VoteCard.H + c.Gap) * s
			t.truthy(width <= screen.W - 2 * m)
			t.truthy(height <= screen.H - 2 * m)
		end)
	end

	t.test("janela: cabeçalho comporta o botão X; abas cabem na largura", function()
		t.truthy(c.CloseButton.H <= c.HeaderH)
		t.truthy(4 * c.Tab.W + 5 * c.Gap <= c.Window.W - c.Gap * 2)
	end)

	t.test("janela: área de cards comporta um card inteiro", function()
		local content = c.Window.H - c.HeaderH - c.Tab.H - 4 * c.Gap
		t.truthy(c.Card.H <= content)
		t.truthy(4 * c.Card.W + 5 * c.Gap <= c.Window.W)
	end)

	t.test("roleta: roda + 4 botões cabem lado a lado", function()
		local content = c.Window.H - c.HeaderH - 2 * c.Gap
		t.truthy(c.WheelView <= content)
		t.truthy(4 * c.WheelButton.H + 3 * c.Gap <= content)
		t.truthy(c.WheelView + c.WheelButton.W + 3 * c.Gap * 2 <= c.Window.W)
	end)

	t.test("recompensas: 7 dias numa fileira e o resgate abaixo", function()
		t.truthy(7 * c.DayTile.W + 8 * c.Gap <= c.Window.W)
		local content = c.Window.H - c.HeaderH
		t.truthy(c.Gap + c.DayTile.H + c.Gap * 2 + c.WeeklyPanel.H + c.Gap <= content)
		t.truthy(c.ClaimButton.W + c.WeeklyPanel.W + 3 * c.Gap * 2 <= c.Window.W)
	end)
end
