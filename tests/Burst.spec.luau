local Burst = require("../src/shared/Logic/Burst")
local BurstConfig = require("../src/shared/Config/BurstConfig")
local FeedbackConfig = require("../src/shared/Config/FeedbackConfig")

return function(t)
	t.test("leva só acaba depois de Quiet segundos sem nada cair, e soma tudo", function()
		local s = Burst.new()
		Burst.add(s, 5, 0)
		Burst.add(s, 7, 0.3)
		t.equal(Burst.flush(s, 0.5, BurstConfig), 0) -- ainda caindo
		local count, coins = Burst.flush(s, 0.3 + BurstConfig.Quiet, BurstConfig)
		t.equal(count, 2)
		t.equal(coins, 12)
		t.equal(Burst.flush(s, 10, BurstConfig), 0) -- zerou
	end)

	t.test("faixas: golpe pequeno sem aviso; mais objetos = faixa maior", function()
		t.equal(Burst.tier(BurstConfig.Tiers[1].Min - 1, BurstConfig), nil)
		local last = 0
		for k, tier in BurstConfig.Tiers do
			t.truthy(tier.Min > last)
			last = tier.Min
			t.equal(Burst.tier(tier.Min, BurstConfig), tier)
			t.equal(Burst.tier(tier.Min + 0, BurstConfig).Text, BurstConfig.Tiers[k].Text)
		end
		t.equal(Burst.tier(10000, BurstConfig), BurstConfig.Tiers[#BurstConfig.Tiers])
	end)

	t.test("resumo tem o feedback triplo (som, tremor, número)", function()
		local kind = FeedbackConfig.Kinds.Burst
		t.truthy(kind and kind.Sound and kind.Shake and kind.Number)
	end)
end
