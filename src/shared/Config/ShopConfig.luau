--!strict
-- Itens da loja comprados com gemas.
-- Kind: "Trail" (rastro ao andar), "Aura" (brilho em volta), "Boost" (bônus temporário).
-- Rarity: Common, Rare, Epic, Legendary. Itens lendários também saem na roleta.

export type Item = {
	Id: string,
	Name: string,
	Kind: string,
	Rarity: string,
	Price: number,
	Icon: string,
	Colors: { { number } }?, -- cores do rastro/aura (RGB)
	Boost: string?, -- "Cash" ou "Growth"
	Minutes: number?,
}

local items: { Item } = {
	{
		Id = "SparkleTrail",
		Name = "Sparkle Trail",
		Kind = "Trail",
		Rarity = "Common",
		Price = 100,
		Icon = "✨",
		Colors = { { 255, 255, 255 }, { 255, 240, 150 } },
	},
	{
		Id = "BubbleTrail",
		Name = "Bubble Trail",
		Kind = "Trail",
		Rarity = "Rare",
		Price = 250,
		Icon = "🔵", -- 🫧 (emoji de 2021) não aparece no Roblox
		Colors = { { 120, 210, 255 }, { 200, 240, 255 } },
	},
	{
		Id = "FireTrail",
		Name = "Fire Trail",
		Kind = "Trail",
		Rarity = "Epic",
		Price = 600,
		Icon = "🔥",
		Colors = { { 255, 220, 60 }, { 255, 70, 30 } },
	},
	{
		Id = "RainbowTrail",
		Name = "Rainbow Trail",
		Kind = "Trail",
		Rarity = "Legendary",
		Price = 1500,
		Icon = "🌈",
		Colors = { { 255, 70, 70 }, { 255, 200, 50 }, { 80, 220, 90 }, { 60, 150, 255 }, { 190, 90, 255 } },
	},
	{
		Id = "LeafAura",
		Name = "Leaf Aura",
		Kind = "Aura",
		Rarity = "Rare",
		Price = 300,
		Icon = "🍃",
		Colors = { { 90, 230, 110 } },
	},
	{
		Id = "FrostAura",
		Name = "Frost Aura",
		Kind = "Aura",
		Rarity = "Epic",
		Price = 800,
		Icon = "❄️",
		Colors = { { 160, 230, 255 } },
	},
	{
		Id = "GoldenAura",
		Name = "Golden Aura",
		Kind = "Aura",
		Rarity = "Legendary",
		Price = 2000,
		Icon = "👑",
		Colors = { { 255, 210, 60 } },
	},
	{
		Id = "CashBoost",
		Name = "2x Cash",
		Kind = "Boost",
		Rarity = "Rare",
		Price = 60,
		Icon = "💵",
		Boost = "Cash",
		Minutes = 10,
	},
	{
		Id = "GrowthBoost",
		Name = "2x Growth",
		Kind = "Boost",
		Rarity = "Epic",
		Price = 80,
		Icon = "📈",
		Boost = "Growth",
		Minutes = 10,
	},
}

for _, item in items do
	table.freeze(item)
end

return table.freeze(items)
