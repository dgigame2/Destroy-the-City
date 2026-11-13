--!strict
-- Roleta da sorte. Um giro grátis a cada 24h; giros extras com gemas ou Robux.
-- Weight: chance relativa de cair em cada fatia. Reward: o que a fatia dá.
-- Itens que o jogador já tem viram gemas (DuplicateGems).

export type Segment = {
	Label: string,
	Icon: string,
	Color: { number },
	Weight: number,
	Reward: { Kind: string, Amount: number?, Id: string? },
}

local segments: { Segment } = {
	{
		Label = "500 Cash",
		Icon = "💵",
		Color = { 80, 200, 90 },
		Weight = 22,
		Reward = { Kind = "Coins", Amount = 500 },
	},
	{
		Label = "25 Gems",
		Icon = "💎",
		Color = { 70, 150, 255 },
		Weight = 18,
		Reward = { Kind = "Gems", Amount = 25 },
	},
	{
		Label = "2x Cash",
		Icon = "💰",
		Color = { 255, 200, 50 },
		Weight = 14,
		Reward = { Kind = "Item", Id = "CashBoost" },
	},
	{
		Label = "Free Spin",
		Icon = "🎡",
		Color = { 255, 120, 180 },
		Weight = 10,
		Reward = { Kind = "Spin", Amount = 1 },
	},
	{
		Label = "2x Growth",
		Icon = "📈",
		Color = { 255, 140, 50 },
		Weight = 12,
		Reward = { Kind = "Item", Id = "GrowthBoost" },
	},
	{
		Label = "100 Gems",
		Icon = "💎",
		Color = { 40, 90, 220 },
		Weight = 8,
		Reward = { Kind = "Gems", Amount = 100 },
	},
	{
		Label = "Frost Aura",
		Icon = "❄️",
		Color = { 150, 90, 240 },
		Weight = 4,
		Reward = { Kind = "Item", Id = "FrostAura" },
	},
	{
		Label = "Rainbow Trail",
		Icon = "🌈",
		Color = { 240, 70, 90 },
		Weight = 1.5,
		Reward = { Kind = "Item", Id = "RainbowTrail" },
	},
}

for _, segment in segments do
	table.freeze(segment.Reward)
	table.freeze(segment)
end

return table.freeze({
	Segments = table.freeze(segments),
	FreeCooldownSeconds = 24 * 60 * 60,
	GemCost = 75,
	DuplicateGems = { Rare = 50, Epic = 200, Legendary = 600 },
	SpinSeconds = 5, -- duração da animação
})
