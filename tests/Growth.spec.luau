local Growth = require("../src/shared/Logic/Growth")
local GrowthConfig = require("../src/shared/Config/GrowthConfig")
local TierConfig = require("../src/shared/Config/TierConfig")

return function(t)
	local cfg = GrowthConfig

	t.test("0 pontos = escala base", function()
		t.equal(Growth.scaleFromPoints(0, cfg), cfg.BaseScale)
	end)

	t.test("escala nunca passa do máximo", function()
		t.equal(Growth.scaleFromPoints(1e12, cfg), cfg.MaxScale)
	end)

	t.test("pointsForScale é o inverso de scaleFromPoints", function()
		for _, points in { 1, 10, 250, 5000 } do
			t.near(Growth.pointsForScale(Growth.scaleFromPoints(points, cfg), cfg), points)
		end
	end)

	t.test("escala cresce sempre que os pontos crescem", function()
		local last = Growth.scaleFromPoints(0, cfg)
		for points = 1, 2000, 7 do
			local scale = Growth.scaleFromPoints(points, cfg)
			t.truthy(scale > last)
			last = scale
		end
	end)

	t.test("tiers: maior construção = mais crescimento, moedas e tamanho exigido", function()
		for i = 2, #TierConfig do
			t.truthy(TierConfig[i].Growth > TierConfig[i - 1].Growth)
			t.truthy(TierConfig[i].Coins > TierConfig[i - 1].Coins)
			t.truthy(TierConfig[i].RequiredScale > TierConfig[i - 1].RequiredScale)
		end
	end)

	t.test("jogador novo consegue comer o tier 1 (sem ficar travado no início)", function()
		t.truthy(Growth.canEatTier(Growth.scaleFromPoints(0, cfg), TierConfig[1]))
	end)

	t.test("highestEdibleTier respeita o tamanho exigido", function()
		t.equal(Growth.highestEdibleTier(1, TierConfig), 1)
		t.equal(Growth.highestEdibleTier(TierConfig[4].RequiredScale, TierConfig), 4)
		t.equal(Growth.highestEdibleTier(1000, TierConfig), #TierConfig)
	end)

	t.test("comer jogador exige ser 25% maior", function()
		t.truthy(Growth.canEatPlayer(5, 4, cfg))
		t.truthy(not Growth.canEatPlayer(4.9, 4, cfg))
		t.truthy(not Growth.canEatPlayer(4, 4, cfg))
	end)

	t.test("jogador engolido renasce com 35% do progresso", function()
		t.near(Growth.respawnPoints(1000, cfg), 350)
	end)

	t.test("bônus de upgrade aumenta crescimento e moedas", function()
		local tier = TierConfig[3]
		t.near(Growth.gainFromTier(tier, 0), tier.Growth)
		t.near(Growth.gainFromTier(tier, 0.5), tier.Growth * 1.5)
		t.truthy(Growth.coinsFromTier(tier, 1) > Growth.coinsFromTier(tier, 0))
		t.truthy(Growth.coinsFromTier(TierConfig[1], 0) >= 1)
	end)

	t.test("raio de comer escala com o tamanho e com o ímã", function()
		t.near(Growth.eatRadius(2, 0, cfg), cfg.BaseEatRadius * 2)
		t.truthy(Growth.eatRadius(2, 0.5, cfg) > Growth.eatRadius(2, 0, cfg))
	end)
end
