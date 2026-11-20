local PaletteConfig = require("../src/shared/Config/PaletteConfig")

local function isRgb(c): boolean
	if type(c) ~= "table" or #c ~= 3 then
		return false
	end
	for _, v in c do
		if type(v) ~= "number" or v < 0 or v > 255 or v ~= math.floor(v) then
			return false
		end
	end
	return true
end

-- temas que o Style (client/Ui/Style) pede pelo nome
local USED_THEMES = { "Sky", "Sea", "Grass", "Sand", "Roof", "Violet", "Blossom", "Sunset", "Stone", "Paper", "Night" }
-- cores de texto que as telas usam (Style.Colors.X)
local USED_TEXT =
	{ "White", "Gold", "Cream", "Danger", "Gem", "Cash", "Track", "Fill", "LevelFill", "Badge", "Ray", "Combo" }

return function(t)
	t.test("paleta: todo tema usado existe com Top, Bottom e Outline válidos", function()
		for _, name in USED_THEMES do
			local theme = PaletteConfig.Themes[name]
			t.truthy(theme ~= nil, name)
			t.truthy(isRgb(theme.Top) and isRgb(theme.Bottom) and isRgb(theme.Outline), name)
		end
	end)

	t.test("paleta: cores de texto, lobby, desastres e confete são RGB válidos", function()
		for _, name in USED_TEXT do
			t.truthy(isRgb(PaletteConfig.Text[name]), name)
		end
		for name, c in PaletteConfig.Lobby do
			t.truthy(isRgb(c), name)
		end
		for _, id in { "Meteor", "Tornado", "Lightning" } do
			t.truthy(isRgb(PaletteConfig.Disasters[id]), id)
		end
		t.truthy(#PaletteConfig.Confetti >= 3)
		for _, c in PaletteConfig.Confetti do
			t.truthy(isRgb(c))
		end
		t.truthy(isRgb(PaletteConfig.Ink) and isRgb(PaletteConfig.Shadow))
		for name, c in PaletteConfig.Vfx do
			t.truthy(isRgb(c), name)
		end
	end)

	t.test("paleta: contorno azul-ardósia, nunca preto puro (vibe dos mapas)", function()
		local ink = PaletteConfig.Ink
		t.truthy(ink[3] > ink[1] and ink[3] > ink[2])
		t.truthy(ink[1] + ink[2] + ink[3] > 120)
	end)

	t.test("paleta: gradiente dos temas vai do claro (Top) para o escuro (Bottom)", function()
		for name, theme in PaletteConfig.Themes do
			local top = theme.Top[1] + theme.Top[2] + theme.Top[3]
			local bottom = theme.Bottom[1] + theme.Bottom[2] + theme.Bottom[3]
			t.truthy(top > bottom, name)
		end
	end)
end
