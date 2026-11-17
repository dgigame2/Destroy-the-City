-- Testes de recompensas, roleta, bônus, loja, classes e produtos.
local Rewards = require("../src/shared/Logic/Rewards")
local Wheel = require("../src/shared/Logic/Wheel")
local Buffs = require("../src/shared/Logic/Buffs")
local Rng = require("../src/shared/Logic/Rng")
local RewardConfig = require("../src/shared/Config/RewardConfig")
local WheelConfig = require("../src/shared/Config/WheelConfig")
local ShopConfig = require("../src/shared/Config/ShopConfig")
local ClassConfig = require("../src/shared/Config/ClassConfig")
local ProductConfig = require("../src/shared/Config/ProductConfig")
local GemConfig = require("../src/shared/Config/GemConfig")
local TierConfig = require("../src/shared/Config/TierConfig")

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

	-- Roleta -------------------------------------------------------------------
	local segments = WheelConfig.Segments

	t.test("roleta: probabilidades somam 100%", function()
		local sum = 0
		for _, p in Wheel.probabilities(segments) do
			sum += p
		end
		t.near(sum, 1)
	end)

	t.test("roleta: item lendário é raro (< 3%)", function()
		local probabilities = Wheel.probabilities(segments)
		for index, segment in segments do
			if segment.Reward.Id == "RainbowTrail" then
				t.truthy(probabilities[index] < 0.03)
			end
		end
	end)

	t.test("roleta: sorteio respeita os pesos (10000 giros)", function()
		local rng = Rng.new(11)
		local counts = {}
		for _ = 1, 10000 do
			local index = Wheel.pick(segments, rng)
			counts[index] = (counts[index] or 0) + 1
		end
		local probabilities = Wheel.probabilities(segments)
		for index in segments do
			t.truthy(math.abs((counts[index] or 0) / 10000 - probabilities[index]) < 0.02)
		end
	end)

	t.test("roleta: ângulo final para na fatia sorteada", function()
		for count = 4, 12 do
			for index = 1, count do
				for _, jitter in { 0, 0.5, 1 } do
					local angle = Wheel.targetAngle(index, count, 5, jitter)
					t.equal(Wheel.indexAtAngle(angle, count), index)
				end
			end
		end
	end)

	t.test("roleta: giro grátis a cada 24h", function()
		t.equal(Wheel.freeSpinIn(0, DAY, WheelConfig.FreeCooldownSeconds), 0)
		t.equal(Wheel.freeSpinIn(1000, 1000 + 3600, WheelConfig.FreeCooldownSeconds), DAY - 3600)
	end)

	-- Bônus ----------------------------------------------------------------------
	t.test("bônus: upgrade + classe somam; boost dobra", function()
		t.near(Buffs.multiplier({ Upgrade = 0.2, Class = 0.25, BoostActive = false }), 1.45)
		t.near(Buffs.multiplier({ Upgrade = 0.2, Class = 0.25, BoostActive = true }), 2.9)
	end)

	t.test("bônus: classe Lucky dobra a chance de gema", function()
		local drop = { Chance = 0.1, Amount = 2 }
		t.equal(Buffs.gemDrop(drop, 0.15), 0)
		t.equal(Buffs.gemDrop(drop, 0.15, 2), 2)
		t.equal(Buffs.gemDrop(drop, 0.25, 2), 0)
		local lucky = nil
		for _, class in ClassConfig do
			if class.Id == "Lucky" then
				lucky = class
			end
		end
		t.truthy(lucky)
		t.near(1 + (lucky :: any).Buffs.Gems, 2)
	end)

	t.test("boost: comprar com outro ativo soma o tempo", function()
		t.equal(Buffs.extendBoost(nil, 100, 600), 700)
		t.equal(Buffs.extendBoost(400, 100, 600), 1000)
		t.equal(Buffs.extendBoost(50, 100, 600), 700)
		t.truthy(Buffs.boostActive(200, 100))
		t.truthy(not Buffs.boostActive(100, 100))
	end)

	t.test("gemas: só construções grandes dão gemas", function()
		t.equal(#GemConfig.DropByTier, #TierConfig)
		t.equal(Buffs.gemDrop(GemConfig.DropByTier[1], 0), 0)
		t.equal(Buffs.gemDrop(GemConfig.DropByTier[#TierConfig], 0.99), GemConfig.DropByTier[#TierConfig].Amount)
		for i = 2, #TierConfig do
			t.truthy(GemConfig.DropByTier[i].Chance >= GemConfig.DropByTier[i - 1].Chance)
		end
	end)

	-- Catálogo -------------------------------------------------------------------
	t.test("ids únicos entre itens, classes e produtos", function()
		local seen = {}
		for _, list in { ShopConfig, ClassConfig } do
			for _, entry in list do
				t.truthy(not seen[entry.Id])
				seen[entry.Id] = true
			end
		end
		for _, product in ProductConfig do
			t.truthy(not seen[product.Key])
			seen[product.Key] = true
		end
	end)

	t.test("prêmios da roleta e das recompensas apontam para itens que existem", function()
		local items = {}
		for _, item in ShopConfig do
			items[item.Id] = item
		end
		for _, segment in segments do
			if segment.Reward.Kind == "Item" then
				t.truthy(items[segment.Reward.Id] ~= nil)
			end
		end
		for _, list in { RewardConfig.Daily, RewardConfig.Weekly } do
			for _, reward in list do
				if reward.Kind == "Item" then
					t.truthy(items[reward.Id :: string] ~= nil)
				end
			end
		end
	end)

	t.test("itens raros da roleta valem gemas quando repetidos", function()
		for _, item in ShopConfig do
			if item.Kind ~= "Boost" and item.Rarity ~= "Common" then
				t.truthy(WheelConfig.DuplicateGems[item.Rarity] ~= nil)
			end
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

	t.test("classes custam gemas e têm algum bônus", function()
		for _, class in ClassConfig do
			t.truthy(class.Price > 0)
			t.truthy(next(class.Buffs) ~= nil)
			-- só bônus que algum sistema lê (GrowthService.multiplier / startPoints / Disasters.mods)
			local known = {
				Speed = true,
				Magnet = true,
				Growth = true,
				Coins = true,
				Gems = true,
				StartPoints = true,
				Damage = true,
				Range = true,
				Cooldown = true,
				Duration = true,
				Chain = true,
			}
			for key in class.Buffs do
				t.truthy(known[key], class.Id .. " tem bônus desconhecido: " .. key)
			end
		end
	end)

	t.test("ícones usam só emojis que o Roblox mostra (nada do bloco novo U+1FA70 em diante)", function()
		-- MEDIDO no jogo (14/11/2026): 🫧 (U+1FAE7, Emoji 14) aparece em branco no Roblox.
		-- Regra conservadora: nenhum emoji a partir de U+1FA70 (blocos adicionados de 2019 em diante).
		local configs = {
			require("../src/shared/Config/ShopConfig"),
			require("../src/shared/Config/ClassConfig"),
			require("../src/shared/Config/WheelConfig").Segments,
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
