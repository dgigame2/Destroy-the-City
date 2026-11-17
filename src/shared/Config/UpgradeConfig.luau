--!strict
-- Upgrades comprados com moedas (valem na run). Bonus = BonusPerLevel * nível (ex.: 0.04 = +4% por nível).
-- Entram no DisasterService (Logic/Disasters.mods) e no GrowthService:
--   Cooldown = recarga mais rápida (cooldown / multiplicador); Range = alcance da mira;
--   Xp = XP dos desastres (sobem de nível mais rápido, MasteryService.record); Coins = dinheiro.
-- As classes (ClassConfig) ainda podem dar Damage, Magnet (tamanho), Duration e Chain sem upgrade.

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
		Id = "Cooldown",
		DisplayName = "Recharge",
		Description = "+4% recharge speed",
		BaseCost = 30,
		CostGrowth = 1.5,
		BonusPerLevel = 0.04,
		MaxLevel = 10,
	},
	{
		Id = "Range",
		DisplayName = "Reach",
		Description = "+5% cast range",
		BaseCost = 15,
		CostGrowth = 1.4,
		BonusPerLevel = 0.05,
		MaxLevel = 10,
	},
	{
		Id = "Xp",
		DisplayName = "XP",
		Description = "+10% disaster XP",
		BaseCost = 30,
		CostGrowth = 1.45,
		BonusPerLevel = 0.1,
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
