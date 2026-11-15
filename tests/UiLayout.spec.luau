-- Checklist de UI do goat em APARELHOS REAIS (não só 4 resoluções):
-- celulares curtos e com entalhe, tablet e PCs. Para cada aparelho, a área da interface desconta a barra do
-- Roblox (TopbarInset) e as bordas seguras do aparelho (entalhe, cantos arredondados, barra de gestos).
-- Verifica: cabe na tela, nada encosta, botões do tamanho do polegar, textos cabem sem cortar e, no toque,
-- NENHUM botão na área do pulo.
-- Decisão do usuário (14/11/2026): atalhos ficam na coluna da esquerda (um pouco mais alta) e a barra de
-- botões embaixo no centro, igual em todos os aparelhos. Por isso a área do analógico não é exigida aqui.
-- Janelas (loja, roleta, recompensas, upgrades, CREATE PARTY) abrem no meio e escondem o HUD; o jogador
-- fica parado enquanto escolhe.
local UiLayout = require("../src/shared/Logic/UiLayout")
local UiConfig = require("../src/shared/Config/UiConfig")
local LobbyConfig = require("../src/shared/Config/LobbyConfig")
local WheelConfig = require("../src/shared/Config/WheelConfig")
local MapConfig = require("../src/shared/Config/MapConfig")
local DifficultyConfig = require("../src/shared/Config/DifficultyConfig")
local CityPlans = require("../src/shared/Config/CityPlans")

-- Tamanhos em pontos (como o Roblox enxerga), deitado. Insets: L, R, B (pontos).
-- MEDIDOS das especificações públicas dos aparelhos; bordas seguras = ESTIMATIVA dos valores do iOS/Android.
local DEVICES = {
	{ Name = "Android pequeno 640x360", W = 640, H = 360, L = 0, R = 0, B = 0, Touch = true },
	{ Name = "iPhone SE 667x375", W = 667, H = 375, L = 0, R = 0, B = 0, Touch = true },
	{ Name = "Galaxy S8/A curto 740x360", W = 740, H = 360, L = 24, R = 24, B = 0, Touch = true },
	{ Name = "Android 800x360 (tela 20:9)", W = 800, H = 360, L = 32, R = 32, B = 0, Touch = true },
	{ Name = "iPhone 14 844x390 (entalhe)", W = 844, H = 390, L = 47, R = 47, B = 21, Touch = true },
	{ Name = "iPhone 15 Pro Max 932x430", W = 932, H = 430, L = 59, R = 59, B = 21, Touch = true },
	{ Name = "iPad mini 1133x744", W = 1133, H = 744, L = 0, R = 0, B = 20, Touch = true },
	{ Name = "Notebook HD 1366x768", W = 1366, H = 768, L = 0, R = 0, B = 0, Touch = false },
	{ Name = "Full HD 1920x1080", W = 1920, H = 1080, L = 0, R = 0, B = 0, Touch = false },
	{ Name = "4K 3840x2160", W = 3840, H = 2160, L = 0, R = 0, B = 0, Touch = false },
}

local function inside(r, w, h)
	return r.X0 >= -0.5 and r.Y0 >= -0.5 and r.X1 <= w + 0.5 and r.Y1 <= h + 0.5
end

local function shifted(r, dx, dy)
	return { X0 = r.X0 + dx, Y0 = r.Y0 + dy, X1 = r.X1 + dx, Y1 = r.Y1 + dy }
end

-- Texto cabe num rótulo de largura/altura (px reais) sem ficar menor que MinTextSize?
local function textFits(text, labelW, labelH)
	local lines = 1
	return UiLayout.textWidth(text, UiConfig.MinTextSize) <= labelW and labelH >= UiConfig.MinTextSize * lines
end

return function(t)
	local c = UiConfig

	t.test("todos os botões têm >= 88 de altura/largura no layout de referência", function()
		for name, size in
			{
				IconButton = c.IconButton,
				UpgradesButton = c.UpgradesButton,
				LobbyButton = c.LobbyButton,
				Close = c.CloseButton,
				Tab = c.Tab,
				CardButton = { W = c.Card.W - 24, H = c.CardButton.H },
				WheelButton = c.WheelButton,
				Claim = c.ClaimButton,
				MapArrow = c.MapArrow,
				Difficulty = c.DifficultyButton,
				Step = c.StepButton,
				Back = c.BackButton,
				Create = c.CreateButton,
				Load = { W = c.SavedCard.W - 24, H = c.CardButton.H },
			}
		do
			if size.W < 88 or size.H < 88 then
				error(`{name} menor que 88: {size.W}x{size.H}`)
			end
		end
	end)

	t.test("celulares deitados usam 2 colunas de atalhos; tablet e PC usam 1", function()
		for _, device in DEVICES do
			local h = device.H - c.TopbarInset - device.B
			local layout = UiLayout.place(device.W - device.L - device.R, h, c)
			local expected = if device.H <= 500 then 2 else 1
			if layout.IconColumns ~= expected then
				error(`{device.Name}: {layout.IconColumns} colunas`)
			end
		end
	end)

	for _, device in DEVICES do
		local top = c.TopbarInset
		local w, h = device.W - device.L - device.R, device.H - top - device.B
		local layout = UiLayout.place(w, h, c)
		local s = layout.Scale
		local gap = c.Gap * s
		local name = device.Name

		local buttons = {}
		for _, r in layout.IconCells do
			table.insert(buttons, r)
		end
		local matchButtons = layout.MatchButtons
		local hud = { layout.Cash, layout.Gems, layout.Timer }

		t.test(`{name}: menor botão >= {c.MinTouch}px`, function()
			t.truthy(88 * s >= c.MinTouch)
		end)

		t.test(`{name}: HUD inteiro dentro da área segura (nada cortado)`, function()
			for label, r in
				{
					Cash = layout.Cash,
					Gems = layout.Gems,
					Icons = layout.Icons,
					MatchBar = layout.MatchBar,
					Toast = layout.Toast,
					Popup = layout.Popup,
					Victory = layout.Victory,
					Frenzy = layout.Frenzy,
					Celebration = layout.Celebration,
				}
			do
				if not inside(r, w, h) then
					error(`{label} sai da tela: {r.X0},{r.Y0} - {r.X1},{r.Y1} (área {w}x{h})`)
				end
			end
		end)

		t.test(`{name}: relógio no centro da faixa da barra do Roblox, dentro da tela`, function()
			local r = layout.Timer
			t.truthy(r.Y0 >= -c.TopbarInset) -- não sai por cima da tela
			t.truthy(r.X0 >= 0 and r.X1 <= w)
			-- longe dos botões do Roblox: logo, menu e chat ficam à esquerda da barra. MEDIDO no print do emulador
			-- de 14/11/2026: terminam a ~210 pontos da borda esquerda da tela (folga até 220).
			t.truthy(r.X0 + device.L >= 220)
		end)

		t.test(`{name}: nada encosta (HUD, atalhos e barra da run)`, function()
			for _, bar in { matchButtons } do
				local list = table.clone(hud)
				for _, r in buttons do
					table.insert(list, r)
				end
				for _, r in bar do
					table.insert(list, r)
				end
				for i = 1, #list do
					for j = i + 1, #list do
						if UiLayout.intersects(list[i], list[j], gap - 0.01) then
							error(`elementos {i} e {j} encostam`)
						end
					end
				end
			end
		end)

		t.test(`{name}: janelas cabem na tela (com o ajuste automático)`, function()
			for _, size in { c.Window, c.UpgradeWindow, c.PartyWindow } do
				local scale = UiLayout.windowScale(w, h, size, c)
				t.truthy(size.W * scale <= w - 2 * c.Margin + 0.5)
				t.truthy(size.H * scale <= h - 2 * c.Margin + 0.5)
				-- e os botões das janelas continuam do tamanho do polegar
				if 88 * scale < c.MinTouch then
					error(`botões da janela ficam com {88 * scale}px`)
				end
			end
		end)

		t.test(`{name}: textos dos botões cabem sem cortar (fonte >= {c.MinTextSize}px)`, function()
			-- rótulo do Style.button: 86% da largura e 60% da altura; legenda dos atalhos: largura - 6 e 34%
			local function buttonFits(text, size)
				return textFits(text, size.W * s * 0.86, size.H * s * 0.6)
			end
			for text, size in
				{
					["⬆️ UPGRADES"] = c.UpgradesButton,
					["🏠 LOBBY"] = c.LobbyButton,
					["SURE?"] = c.LobbyButton,
				}
			do
				if not buttonFits(text, size) then
					error(`"{text}" não cabe no botão`)
				end
			end
			for _, caption in { "SHOP", "SPIN", "GIFT", "CLASS" } do
				if not textFits(caption, (c.IconButton.W - 6) * s, c.IconButton.H * 0.34 * s) then
					error(`legenda "{caption}" não cabe no atalho`)
				end
			end
			-- progresso da run no relógio (o nome do mapa fica na linha de baixo)
			if not textFits("100% EATEN", (c.Timer.W - 24) * s, 38 * s) then
				error("progresso não cabe no relógio")
			end
			for _, map in MapConfig do
				if not textFits(map.DisplayName, (c.Timer.W - 24) * s, c.TextRow * s) then
					error(`nome do mapa "{map.DisplayName}" não cabe no relógio`)
				end
			end
		end)

		t.test(`{name}: áreas da cidade: nome da área, FRENZY e comemoração cabem sem cortar`, function()
			-- nome da área no lugar do relógio (título de 38) e a linha "AREA 2 OF 5" (a barra mostra quanto falta)
			for _, plan in CityPlans do
				for _, zone in plan.Zones do
					if not textFits(zone.Name, (c.Timer.W - 24) * s, 38 * s) then
						error(`nome da área "{zone.Name}" não cabe`)
					end
					if
						not textFits(
							`NEXT: {zone.Name}  →`,
							layout.Celebration.X1 - layout.Celebration.X0 - 40 * s,
							40 * s
						)
					then
						error(`"NEXT: {zone.Name}" não cabe na comemoração`)
					end
					-- aviso ao encostar na barreira de uma área bloqueada
					if
						not textFits(
							`NEED TO CLEAN {zone.Name} FIRST`,
							layout.Toast.X1 - layout.Toast.X0,
							layout.Toast.Y1 - layout.Toast.Y0
						)
					then
						error(`aviso "NEED TO CLEAN {zone.Name} FIRST" não cabe`)
					end
				end
			end
			t.truthy(textFits("AREA 5/5 • 100%", (c.Timer.W - 24) * s, c.TextRow * s))
			local fr = layout.Frenzy
			t.truthy(textFits("⚡ FRENZY 20s", (fr.X1 - fr.X0) * 0.86, (fr.Y1 - fr.Y0) * 0.6))
			local cel = layout.Celebration
			local cs = (cel.X1 - cel.X0) / c.Celebration.W
			-- CONTINUE: na tela, do tamanho do polegar, sem encostar na barra da run nem no painel
			local cont = layout.Continue
			t.truthy(inside(cont, w, h))
			t.truthy(cont.Y1 - cont.Y0 >= c.MinTouch)
			t.falsy(UiLayout.intersects(cont, layout.MatchBar, 1))
			t.truthy(cont.Y0 >= cel.Y1)
			t.truthy(textFits("CONTINUE ▶", (cont.X1 - cont.X0) * 0.86, (cont.Y1 - cont.Y0) * 0.6))
			t.truthy(textFits("AREA CLEARED!", (cel.X1 - cel.X0) * 0.9, 80 * cs))
			for i, chip in layout.Chips do
				t.truthy(inside(chip, w, h))
				t.truthy(chip.X0 >= cel.X0 and chip.X1 <= cel.X1 and chip.Y0 >= cel.Y0 and chip.Y1 <= cel.Y1)
				for _, text in { "+999 💎", "+$9.999", "⚡ FRENZY 20s" } do
					t.truthy(textFits(text, (chip.X1 - chip.X0) * 0.9, (chip.Y1 - chip.Y0) * 0.6))
				end
				for j = i + 1, #layout.Chips do
					t.falsy(UiLayout.intersects(chip, layout.Chips[j], 1))
				end
			end
			-- o FRENZY fica logo abaixo do progresso, sem encostar nele
			t.truthy(layout.Frenzy.Y0 >= layout.Timer.Y1)
		end)

		t.test(`{name}: CREATE PARTY: textos cabem na escala da janela`, function()
			local ws = UiLayout.windowScale(w, h, c.PartyWindow, c)
			local p = UiLayout.partyWindow(c)
			local function fits(text, r, wFrac, hFrac)
				return textFits(text, (r.X1 - r.X0) * ws * wFrac, (r.Y1 - r.Y0) * ws * hFrac)
			end
			-- cartão do mapa: linha do capítulo (32) e nome (40), largura menos 24
			local cardW = p.MapCard.X1 - p.MapCard.X0 - 24
			for index, map in MapConfig do
				for _, text in { `{map.Icon} CHAPTER {index}`, `🔒 {map.RequiredWins} WINS NEEDED`, map.DisplayName } do
					if not textFits(text, cardW * ws, 32 * ws) then
						error(`"{text}" não cabe no cartão do mapa`)
					end
				end
			end
			-- dificuldade: nome em cima (44) e caveiras/cadeado embaixo (28), largura menos 12
			local dw = (c.DifficultyButton.W - 12) * ws
			for _, d in DifficultyConfig do
				t.truthy(textFits(d.Name, dw, 40 * ws))
				t.truthy(textFits(`🔒 {d.RequiredWins} WINS`, dw, c.TextRow * ws))
				t.truthy(textFits(string.rep("💀", d.Skulls), dw, c.TextRow * ws))
			end
			for text, r in { BACK = p.Back, CREATE = p.Create, ["-"] = p.Minus, ["+"] = p.Plus, ["4"] = p.Size } do
				t.truthy(fits(text, r, 0.86, 0.6))
			end
			t.truthy(fits("PARTY", p.SizeLabel, 1, 0.5))
			t.truthy(fits("SAVED RUNS", p.SavedTitle, 1, 1))
			-- card de run salva
			local card = p.SavedCard
			local longest = ""
			for _, map in MapConfig do
				local text = `{map.Icon} {map.DisplayName}`
				if utf8.len(text) :: number > utf8.len(longest) :: number then
					longest = text
				end
			end
			t.truthy(fits(longest, card.Title, 1, 1))
			t.truthy(fits("⏳ 6d 23h left", card.Expires, 1, 1))
			t.truthy(fits("🍔 99%", card.ProgressTag, 0.9, 1))
			for _, d in DifficultyConfig do
				t.truthy(fits(d.Name, card.DifficultyTag, 0.9, 1))
			end
			t.truthy(fits("LOAD GAME", card.Load, 0.86, 0.6))
		end)

		if device.Touch then
			t.test(`{name}: nenhum botão na área do pulo`, function()
				local zones = { UiLayout.touchZones(device.W, device.H, c.TouchPad)[2] }
				-- confere nas duas referências possíveis dos controles de toque (tela inteira e área abaixo da barra)
				local function check(r, label)
					for _, offset in { { device.L, top }, { device.L, 0 } } do
						local onScreen = shifted(r, offset[1], offset[2])
						for zi, zone in zones do
							if UiLayout.intersects(onScreen, zone) then
								error(`{label} fica na área do pulo ({zi})`)
							end
						end
					end
				end
				for i, r in buttons do
					check(r, `atalho {i}`)
				end
				for i, r in matchButtons do
					check(r, `botão da run {i}`)
				end
			end)
		end
	end

	t.test("janela: cabeçalho comporta o botão X; abas cabem na largura", function()
		t.truthy(c.CloseButton.H <= c.HeaderH)
		t.truthy(c.TabCount * c.Tab.W + (c.TabCount + 1) * c.Gap <= c.Window.W - c.Gap * 2)
	end)

	t.test("janela: área de cards comporta um card inteiro", function()
		local content = c.Window.H - c.HeaderH - c.Tab.H - 4 * c.Gap
		t.truthy(c.Card.H <= content)
		t.truthy(4 * c.Card.W + 5 * c.Gap <= c.Window.W)
	end)

	t.test("card: legenda acima do botão de preço (nada encosta dentro do card)", function()
		-- Screens.card: legenda de 138 a 178; botão começa em Card.H - 10 - CardButton.H
		t.truthy(178 + 4 <= c.Card.H - 10 - c.CardButton.H)
	end)

	t.test("upgrades: 4 cards numa fileira abaixo do cabeçalho", function()
		t.truthy(4 * c.Card.W + 5 * c.Gap <= c.UpgradeWindow.W)
		t.truthy(c.HeaderH + c.Gap + c.Card.H + c.Gap <= c.UpgradeWindow.H)
	end)

	t.test("roleta: ícones e textos dos prêmios cabem na fatia, até no menor celular", function()
		-- VALOR CALCULADO: diâmetro da roda na janela pela câmera (FOV vertical); no celular a janela fica na
		-- escala mínima (MinScale).
		local cam = c.WheelCamera
		local halfHeight = cam.Distance * math.tan(math.rad(cam.Fov / 2))
		local wheelDesign = c.WheelView * LobbyConfig.WheelRadius / halfHeight
		t.truthy(wheelDesign <= c.WheelView)
		local p = c.WheelPrize
		local segments = #WheelConfig.Segments
		for _, scale in { c.MinScale, 1 } do
			local d = wheelDesign * scale -- diâmetro em px reais
			local r = d / 2
			-- texto curto: cabe no comprimento (ao longo do raio) e na espessura, na fonte mínima
			local length = (p.TextTo - p.TextFrom) * r
			local thickness = p.TextThickness * d
			t.truthy(thickness >= c.MinTextSize)
			for _, segment in WheelConfig.Segments do
				if UiLayout.textWidth(segment.Short, c.MinTextSize) > length then
					error(`"{segment.Short}" não cabe na fatia com a roda de {math.floor(d)}px`)
				end
			end
			-- o texto não encosta no ícone nem no centro (cubo de 3 studs de raio)
			local iconInner = p.IconRadius * r - p.IconSize * d / 2
			t.truthy(p.TextTo * r <= iconInner)
			t.truthy(p.TextFrom >= 3 / LobbyConfig.WheelRadius)
			-- o ícone cabe na largura da fatia nessa altura
			local arc = 2 * math.pi * p.IconRadius * r / segments
			t.truthy(p.IconSize * d <= arc)
			-- e o texto (espessura) cabe na largura da fatia já onde ele começa (perto do centro, a fatia é estreita)
			t.truthy(thickness <= 2 * math.pi * p.TextFrom * r / segments)
		end
	end)

	t.test("roleta: roda + 4 botões cabem lado a lado", function()
		local content = c.Window.H - c.HeaderH - 2 * c.Gap
		t.truthy(c.WheelView <= content)
		t.truthy(4 * c.WheelButton.H + 3 * c.Gap <= content)
		t.truthy(c.WheelView + c.WheelButton.W + 3 * c.Gap * 2 <= c.Window.W)
	end)

	t.test("CREATE PARTY: tudo dentro da janela, abaixo do cabeçalho, e nenhum botão encosta", function()
		local p = UiLayout.partyWindow(c)
		local W, H = c.PartyWindow.W, c.PartyWindow.H
		local buttons = { p.Prev, p.Next, p.Minus, p.Plus, p.Back, p.Create }
		for _, r in p.Difficulty do
			table.insert(buttons, r)
		end
		local all = table.clone(buttons)
		for _, r in { p.MapCard, p.SizeLabel, p.Size, p.SavedTitle, p.SavedList } do
			table.insert(all, r)
		end
		for i, r in all do
			if r.X0 < c.Gap or r.X1 > W - c.Gap or r.Y0 < c.HeaderH or r.Y1 > H - 8 then
				error(`elemento {i} sai da janela: {r.X0},{r.Y0} - {r.X1},{r.Y1}`)
			end
			for j = i + 1, #all do
				if UiLayout.intersects(r, all[j], c.Gap - 0.01) then
					error(`elementos {i} e {j} da CREATE PARTY encostam`)
				end
			end
		end
		-- a coluna das runs salvas comporta um card inteiro
		t.truthy(p.SavedList.X1 - p.SavedList.X0 >= c.SavedCard.W)
		t.truthy(p.SavedList.Y1 - p.SavedList.Y0 >= c.SavedCard.H)
	end)

	t.test("CREATE PARTY: card de run salva sem nada encostando e com linhas >= TextRow", function()
		local card = UiLayout.partyWindow(c).SavedCard
		local list = { card.Title, card.With, card.DifficultyTag, card.ProgressTag, card.Expires, card.Load }
		for i, r in list do
			t.truthy(r.X0 >= 0 and r.X1 <= c.SavedCard.W and r.Y0 >= 0 and r.Y1 <= c.SavedCard.H)
			t.truthy(r.Y1 - r.Y0 >= c.TextRow)
			for j = i + 1, #list do
				if UiLayout.intersects(r, list[j]) then
					error(`partes {i} e {j} do card encostam`)
				end
			end
		end
	end)

	t.test("recompensas: 7 dias numa fileira e o resgate abaixo", function()
		t.truthy(7 * c.DayTile.W + 8 * c.Gap <= c.Window.W)
		local content = c.Window.H - c.HeaderH
		t.truthy(c.Gap + c.DayTile.H + c.Gap * 2 + c.WeeklyPanel.H + c.Gap <= content)
		t.truthy(c.ClaimButton.W + c.WeeklyPanel.W + 3 * c.Gap * 2 <= c.Window.W)
	end)
end
