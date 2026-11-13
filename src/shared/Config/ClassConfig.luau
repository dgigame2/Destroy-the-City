--!strict
-- Classes compradas com gemas. Só uma fica equipada; os bônus valem enquanto você joga.
-- Buffs: Speed/Magnet/Growth/Coins somam ao bônus dos upgrades (0.25 = +25%).
-- RespawnKeep: fração do tamanho mantida ao ser engolido (substitui os 35% padrão se for maior).
-- StartPoints: pontos de crescimento ao começar cada partida.

export type ClassInfo = {
	Id: string,
	Name: string,
	Description: string,
	Icon: string,
	Price: number,
	Buffs: { [string]: number },
}

local classes: { ClassInfo } = {
	{
		Id = "Glutton",
		Name = "Glutton",
		Description = "+25% growth",
		Icon = "🍔",
		Price = 150,
		Buffs = { Growth = 0.25 },
	},
	{
		Id = "Sprinter",
		Name = "Sprinter",
		Description = "+25% speed",
		Icon = "👟",
		Price = 150,
		Buffs = { Speed = 0.25 },
	},
	{
		Id = "Vacuum",
		Name = "Vacuum",
		Description = "+30% eating reach",
		Icon = "🌀",
		Price = 250,
		Buffs = { Magnet = 0.3 },
	},
	{ Id = "Tycoon", Name = "Tycoon", Description = "+50% cash", Icon = "💰", Price = 250, Buffs = { Coins = 0.5 } },
	{
		Id = "Survivor",
		Name = "Survivor",
		Description = "Keep 60% size when eaten",
		Icon = "🛡️",
		Price = 400,
		Buffs = { RespawnKeep = 0.6 },
	},
	{
		Id = "Titan",
		Name = "Titan",
		Description = "Start every round bigger",
		Icon = "🦖",
		Price = 600,
		Buffs = { StartPoints = 60 },
	},
}

for _, class in classes do
	table.freeze(class.Buffs)
	table.freeze(class)
end

return table.freeze(classes)
