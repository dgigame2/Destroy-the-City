--!strict
-- Produtos comprados com Robux (Developer Products).
-- COMO PREENCHER: publique o jogo, abra create.roblox.com > seu jogo > Monetização > Developer Products,
-- crie cada produto com o preço abaixo e cole o ID em ProductId. Com ProductId = 0 o botão aparece
-- como "SOON" e não abre compra.
-- PriceLabel é só o texto mostrado no botão; o preço real é o que estiver no site.

export type Product = {
	Key: string,
	ProductId: number,
	PriceLabel: string,
	Name: string,
	Icon: string,
	Grant: { Kind: string, Amount: number },
}

local products: { Product } = {
	{
		Key = "Gems100",
		ProductId = 0,
		PriceLabel = "49",
		Name = "100 Gems",
		Icon = "💎",
		Grant = { Kind = "Gems", Amount = 100 },
	},
	{
		Key = "Gems550",
		ProductId = 0,
		PriceLabel = "199",
		Name = "550 Gems",
		Icon = "💎",
		Grant = { Kind = "Gems", Amount = 550 },
	},
	{
		Key = "Gems1500",
		ProductId = 0,
		PriceLabel = "449",
		Name = "1500 Gems",
		Icon = "💎",
		Grant = { Kind = "Gems", Amount = 1500 },
	},
	{
		Key = "Spin1",
		ProductId = 0,
		PriceLabel = "25",
		Name = "1 Spin",
		Icon = "🎡",
		Grant = { Kind = "Spin", Amount = 1 },
	},
	{
		Key = "Spin10",
		ProductId = 0,
		PriceLabel = "199",
		Name = "10 Spins",
		Icon = "🎡",
		Grant = { Kind = "Spin", Amount = 10 },
	},
}

for _, product in products do
	table.freeze(product.Grant)
	table.freeze(product)
end

return table.freeze(products)
