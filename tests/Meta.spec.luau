-- Testes de recompensas, loja de cosméticos e produtos.
local Rewards = require("../src/shared/Logic/Rewards")
local RewardConfig = require("../src/shared/Config/RewardConfig")
local ShopConfig = require("../src/shared/Config/ShopConfig")
local ProductConfig = require("../src/shared/Config/ProductConfig")
local EconomyConfig = require("../src/shared/Config/EconomyConfig")

local DAY = 86400

return function(t)
	-- Recompensas -------------------------------------------------------------
	t.test("diária: primeira vez dá o dia 1", function()
		local ok, day = Rewards.daily(-1, 0, 100, 7)
		t.truthy(ok)
		t.equal(day, 1)
	end)

	t.test("diária: dias seguidos avançam a sequência e o dia 7 volta ao 1", function()
		local _, d2 = Rewards.daily(99, 1, 100, 7)
		t.equal(d2, 2)
		local _, d1 = Rewards.daily(99, 7, 100, 7)
		t.equal(d1, 1)
	end)

	t.test("diária: não resgata duas vezes no mesmo dia", function()
		t.truthy(not (Rewards.daily(100, 3, 100, 7)))
	end)

	t.test("diária: pular um dia volta ao dia 1", function()
		local ok, day = Rewards.daily(97, 5, 100, 7)
		t.truthy(ok)
		t.equal(day, 1)
	end)

	t.test("semana vira na segunda-feira (UTC)", function()
		-- dia 0 = 01/01/1970 (quinta); dia 3 = domingo 04/01; dia 4 = segunda 05/01; dia 10 = domingo 11/01
		t.equal(Rewards.weekIndex(3 * DAY + 100) + 1, Rewards.weekIndex(4 * DAY))
		t.equal(Rewards.weekIndex(4 * DAY), Rewards.weekIndex(10 * DAY + DAY - 1))
		t.truthy(Rewards.weekly(1, 2))
		t.truthy(not Rewards.weekly(2, 2))
	end)

	t.test("recompensas configuradas: 7 diárias e semanal com prêmio", function()
		t.equal(#RewardConfig.Daily, 7)
		t.truthy(#RewardConfig.Weekly > 0)
	end)

	t.test("ids únicos entre itens e produtos", function()
		local seen = {}
		for _, entry in ShopConfig do
			t.truthy(not seen[entry.Id])
			seen[entry.Id] = true
		end
		for _, product in ProductConfig do
			t.truthy(not seen[product.Key])
			seen[product.Key] = true
		end
	end)

	t.test("prêmios das recompensas e dos produtos apontam para itens que existem", function()
		local items = {}
		for _, item in ShopConfig do
			items[item.Id] = item
		end
		local kinds = { Gems = true, Item = true }
		for _, list in { RewardConfig.Daily, RewardConfig.Weekly } do
			for _, reward in list do
				t.truthy(kinds[reward.Kind], reward.Label)
				if reward.Kind == "Item" then
					t.truthy(items[reward.Id :: string] ~= nil)
				end
			end
		end
	end)

	t.test("cosmético repetido vira gemas em toda raridade", function()
		for _, item in ShopConfig do
			t.truthy(item.Kind == "Trail" or item.Kind == "Aura", item.Id) -- só cosmético na loja
			t.truthy(EconomyConfig.DuplicateGems[item.Rarity] ~= nil)
		end
	end)

	t.test("preço sobe com a raridade dentro de cada tipo", function()
		local order = { Common = 1, Rare = 2, Epic = 3, Legendary = 4 }
		for _, a in ShopConfig do
			for _, b in ShopConfig do
				if a.Kind == b.Kind and order[a.Rarity] < order[b.Rarity] then
					t.truthy(a.Price < b.Price)
				end
			end
		end
	end)

	t.test("ícones usam só emojis que o Roblox mostra (nada do bloco novo U+1FA70 em diante)", function()
		-- MEDIDO no jogo (14/11/2026): 🫧 (U+1FAE7, Emoji 14) aparece em branco no Roblox.
		-- Regra conservadora: nenhum emoji a partir de U+1FA70 (blocos adicionados de 2019 em diante).
		local configs = {
			require("../src/shared/Config/ShopConfig"),
			require("../src/shared/Config/RewardConfig").Daily,
			require("../src/shared/Config/ProductConfig"),
			require("../src/shared/Config/MapConfig"),
		}
		for _, list in configs do
			for _, entry in list do
				local icon = entry.Icon
				if icon then
					for _, code in utf8.codes(icon) do
						if code >= 0x1FA70 then
							error(`ícone "{icon}" de {entry.Name or entry.Label or entry.Id} não aparece no Roblox`)
						end
					end
				end
			end
		end
	end)
end
