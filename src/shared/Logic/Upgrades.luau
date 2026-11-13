--!strict
-- Custos e bônus dos upgrades. Funções puras.

export type Upgrade = {
	Id: string,
	BaseCost: number,
	CostGrowth: number,
	BonusPerLevel: number,
	MaxLevel: number,
}

local Upgrades = {}

function Upgrades.find(list: { Upgrade }, id: string): Upgrade?
	for _, upgrade in list do
		if upgrade.Id == id then
			return upgrade
		end
	end
	return nil
end

-- Custo para subir do nível atual para o próximo.
function Upgrades.nextCost(upgrade: Upgrade, level: number): number
	assert(level >= 0 and level == math.floor(level), "level deve ser inteiro >= 0")
	return math.floor(upgrade.BaseCost * upgrade.CostGrowth ^ level)
end

function Upgrades.bonus(upgrade: Upgrade, level: number): number
	return upgrade.BonusPerLevel * math.clamp(level, 0, upgrade.MaxLevel)
end

-- Retorna (pode comprar, custo). Custo é 0 quando já está no nível máximo.
function Upgrades.canBuy(upgrade: Upgrade, level: number, coins: number): (boolean, number)
	if level >= upgrade.MaxLevel then
		return false, 0
	end
	local cost = Upgrades.nextCost(upgrade, level)
	return coins >= cost, cost
end

return Upgrades
