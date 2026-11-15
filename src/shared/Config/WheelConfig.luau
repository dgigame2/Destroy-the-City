--!strict
-- Roleta da sorte. Um giro grátis a cada 24h; giros extras com gemas ou Robux.
-- Weight: chance relativa de cair em cada fatia. Reward: o que a fatia dá.
-- Itens que o jogador já tem viram gemas (DuplicateGems).

export type Segment = {
	Label: string,
	Short: string, -- texto curto mostrado na fatia da roleta da janela (o ícone diz o que é)
	Icon: string,
	Color: { number },
	Weight: number,
	Reward: { Kind: string, Amount: number?, Id: string? },
}

local segments: { Segment } = {
	{
		Label = "10 Gems", -- dinheiro agora é da run; prêmios do lobby são em gemas
		Short = "10",
		Icon = "💎",
		Color = { 80, 200, 90 },
		Weight = 22,
		Reward = { Kind = "Gems", Amount = 10 },
	},
	{
		Label = "25 Gems",
		Short = "25",
		Icon = "💎",
		Color = { 70, 150, 255 },
		Weight = 18,
		Reward = { Kind = "Gems", Amount = 25 },
	},
	{
		Label = "2x Cash",
		Short = "2X",
		Icon = "💰",
		Color = { 255, 200, 50 },
		Weight = 14,
		Reward = { Kind = "Item", Id = "CashBoost" },
	},
	{
		Label = "Free Spin",
		Short = "+1",
		Icon = "🎡",
		Color = { 255, 120, 180 },
		Weight = 10,
		Reward = { Kind = "Spin", Amount = 1 },
	},
	{
		Label = "2x Growth",
		Short = "2X",
		Icon = "📈",
		Color = { 255, 140, 50 },
		Weight = 12,
		Reward = { Kind = "Item", Id = "GrowthBoost" },
	},
	{
		Label = "100 Gems",
		Short = "100",
		Icon = "💎",
		Color = { 40, 90, 220 },
		Weight = 8,
		Reward = { Kind = "Gems", Amount = 100 },
	},
	{
		Label = "Frost Aura",
		Short = "AURA",
		Icon = "❄️",
		Color = { 150, 90, 240 },
		Weight = 4,
		Reward = { Kind = "Item", Id = "FrostAura" },
	},
	{
		Label = "Rainbow Trail",
		Short = "TRAIL",
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
