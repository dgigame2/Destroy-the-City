--!strict
-- Tiers de construções. Construção menor = menos crescimento; maior = mais crescimento.
-- RequiredScale: escala mínima do jogador para conseguir comer.

export type Tier = {
	Name: string,
	DisplayName: string, -- usado no aviso "YOU CAN NOW EAT ...!"
	RequiredScale: number,
	Growth: number,
	Coins: number,
}

local tiers: { Tier } = {
	{ Name = "Prop", DisplayName = "LAMPS & BENCHES", RequiredScale = 1, Growth = 1, Coins = 1 }, -- poste, banco, lixeira, arbusto
	{ Name = "Small", DisplayName = "TREES & CARS", RequiredScale = 1.6, Growth = 4, Coins = 2 }, -- árvore, carro
	{ Name = "House", DisplayName = "HOUSES", RequiredScale = 2.5, Growth = 12, Coins = 5 }, -- casa pequena
	{ Name = "BigHouse", DisplayName = "SHOPS & BIG HOUSES", RequiredScale = 4, Growth = 35, Coins = 12 }, -- sobrado, loja
	{ Name = "Building", DisplayName = "BUILDINGS", RequiredScale = 6.5, Growth = 100, Coins = 30 }, -- prédio, galpão
	{ Name = "Tower", DisplayName = "TOWERS & MUSEUMS", RequiredScale = 10, Growth = 300, Coins = 80 }, -- torre, museu
	{ Name = "Landmark", DisplayName = "SKYSCRAPERS", RequiredScale = 16, Growth = 900, Coins = 200 }, -- marco do mapa
}

for _, tier in tiers do
	table.freeze(tier)
end

return table.freeze(tiers)
