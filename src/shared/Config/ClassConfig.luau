--!strict
-- Classes compradas com gemas. Só uma fica equipada; os bônus valem enquanto você joga.
-- Ids antigos do Eat City continuam iguais (quem já comprou continua com a classe), com tema de desastres.
-- Buffs somam ao bônus dos upgrades do mesmo nome (0.25 = +25%), ver UpgradeConfig:
--   Damage, Magnet (tamanho), Range, Cooldown (recarga), Duration (tornado), Chain (reações), Growth (poder),
--   Speed, Coins.
-- Gems: multiplica a chance de cair gema (1 = +100%, ou seja, 2x).
-- StartPoints: pontos de poder ao começar cada run.

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
		Name = "Stormcaller",
		Description = "+25% power gain",
		Icon = "⛈️",
		Price = 150,
		Buffs = { Growth = 0.25 },
	},
	{
		Id = "Sprinter",
		Name = "Chaser",
		Description = "+25% speed\n+15% range",
		Icon = "👟",
		Price = 150,
		Buffs = { Speed = 0.25, Range = 0.15 },
	},
	{
		Id = "Vacuum",
		Name = "Twister",
		Description = "+30% tornado time\n+10% size",
		Icon = "🌀",
		Price = 250,
		Buffs = { Duration = 0.3, Magnet = 0.1 },
	},
	{ Id = "Tycoon", Name = "Looter", Description = "+50% cash", Icon = "💰", Price = 250, Buffs = { Coins = 0.5 } },
	{
		Id = "Demolisher",
		Name = "Demolisher",
		Description = "+25% damage",
		Icon = "💥",
		Price = 300,
		Buffs = { Damage = 0.25 },
	},
	{
		Id = "Pyro",
		Name = "Pyro",
		Description = "+50% chain damage",
		Icon = "🔥",
		Price = 350,
		Buffs = { Chain = 0.5 },
	},
	{
		Id = "Lucky",
		Name = "Lucky",
		Description = "2x gem drops",
		Icon = "🍀",
		Price = 400,
		Buffs = { Gems = 1 },
	},
	{
		Id = "Overcharge",
		Name = "Overcharge",
		Description = "+30% recharge speed",
		Icon = "🔋",
		Price = 450,
		Buffs = { Cooldown = 0.3 },
	},
	{
		Id = "Titan",
		Name = "Titan",
		Description = "Start every run stronger",
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
