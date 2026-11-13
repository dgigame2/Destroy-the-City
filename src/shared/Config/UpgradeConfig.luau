--!strict
-- Upgrades comprados com moedas. Bonus = BonusPerLevel * nível (ex.: 0.06 = +6% por nível).

export type Upgrade = {
	Id: string,
	DisplayName: string,
	Description: string,
	BaseCost: number,
	CostGrowth: number,
	BonusPerLevel: number,
	MaxLevel: number,
}

local upgrades: { Upgrade } = {
	{
		Id = "Speed",
		DisplayName = "Speed",
		Description = "+6% walk speed",
		BaseCost = 15,
		CostGrowth = 1.35,
		BonusPerLevel = 0.06,
		MaxLevel = 20,
	},
	{
		Id = "Magnet",
		DisplayName = "Big Mouth",
		Description = "+8% eating reach",
		BaseCost = 20,
		CostGrowth = 1.4,
		BonusPerLevel = 0.08,
		MaxLevel = 20,
	},
	{
		Id = "Growth",
		DisplayName = "Hunger",
		Description = "+7% growth",
		BaseCost = 30,
		CostGrowth = 1.45,
		BonusPerLevel = 0.07,
		MaxLevel = 20,
	},
	{
		Id = "Coins",
		DisplayName = "Cash",
		Description = "+10% cash",
		BaseCost = 25,
		CostGrowth = 1.4,
		BonusPerLevel = 0.1,
		MaxLevel = 20,
	},
}

for _, upgrade in upgrades do
	table.freeze(upgrade)
end

return table.freeze(upgrades)
