local Upgrades = require("../src/shared/Logic/Upgrades")
local UpgradeConfig = require("../src/shared/Config/UpgradeConfig")

return function(t)
	t.test("ids de upgrade são únicos", function()
		local seen = {}
		for _, upgrade in UpgradeConfig do
			t.truthy(not seen[upgrade.Id])
			seen[upgrade.Id] = true
		end
	end)

	t.test("find acha por id e retorna nil para id inexistente", function()
		t.equal(Upgrades.find(UpgradeConfig, "Speed").Id, "Speed")
		t.equal(Upgrades.find(UpgradeConfig, "Nada"), nil)
	end)

	t.test("custo nunca diminui e é sempre >= 1", function()
		for _, upgrade in UpgradeConfig do
			local last = 0
			for level = 0, upgrade.MaxLevel - 1 do
				local cost = Upgrades.nextCost(upgrade, level)
				t.truthy(cost >= 1 and cost >= last)
				last = cost
			end
		end
	end)

	t.test("não compra sem moedas suficientes", function()
		local upgrade = UpgradeConfig[1]
		local ok, cost = Upgrades.canBuy(upgrade, 0, 0)
		t.truthy(not ok)
		t.equal(cost, upgrade.BaseCost)
		t.truthy((Upgrades.canBuy(upgrade, 0, upgrade.BaseCost)))
	end)

	t.test("não compra além do nível máximo", function()
		local upgrade = UpgradeConfig[1]
		local ok, cost = Upgrades.canBuy(upgrade, upgrade.MaxLevel, 1e15)
		t.truthy(not ok)
		t.equal(cost, 0)
	end)

	t.test("bônus é proporcional ao nível e limitado ao máximo", function()
		local upgrade = UpgradeConfig[1]
		t.near(Upgrades.bonus(upgrade, 0), 0)
		t.near(Upgrades.bonus(upgrade, 3), upgrade.BonusPerLevel * 3)
		t.near(Upgrades.bonus(upgrade, upgrade.MaxLevel + 50), upgrade.BonusPerLevel * upgrade.MaxLevel)
	end)

	t.test("nível fracionário ou negativo é rejeitado", function()
		t.throws(function()
			Upgrades.nextCost(UpgradeConfig[1], 1.5)
		end)
		t.throws(function()
			Upgrades.nextCost(UpgradeConfig[1], -1)
		end)
	end)
end
