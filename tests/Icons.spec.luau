local IconConfig = require("../src/shared/Config/IconConfig")
local ElementConfig = require("../src/shared/Config/ElementConfig")

-- emojis que o HUD mostra como ícone (Screens: moedas e atalhos; UpgradesController)

local HUD = { "💵", "💎", "🏆", "🛒", "🎡", "🎁", "⚔️", "⏱️", "🎯", "⭐" }

return function(t)
	t.test("ícones: todo id é um asset do Roblox", function()
		for glyph, id in IconConfig do
			t.truthy(string.match(id, "^rbxassetid://%d+$") ~= nil, glyph)
		end
	end)

	t.test("ícones: atalhos do HUD têm imagem", function()
		for _, glyph in HUD do
			t.truthy(IconConfig[glyph] ~= nil, glyph)
		end
	end)

	t.test("ícones: todo elemento da hotbar tem imagem", function()
		for _, e in ElementConfig.List do
			t.truthy(IconConfig[e.Icon] ~= nil, e.Id)
		end
	end)
end
