--!strict
-- Tiers de construções. Construção menor = menos crescimento; maior = mais crescimento.
-- O crescimento real ainda é multiplicado pelo multiplicador da área da cidade (Logic/ZoneBalance).
-- RequiredScale: escala mínima do jogador para conseguir comer.

export type Tier = {
	Name: string,
	DisplayName: string, -- usado no aviso "YOU CAN NOW EAT ...!"
	RequiredScale: number,
	Growth: number,
	Coins: number,
}

local tiers: { Tier } = {
	{ Name = "Prop", DisplayName = "LAMPS & BENCHES", RequiredScale = 1, Growth = 1, Coins = 1 }, -- poste, banco, lixeira
	{ Name = "Small", DisplayName = "TREES & CARS", RequiredScale = 1.4, Growth = 2, Coins = 2 }, -- árvore, carro
	{ Name = "House", DisplayName = "HOUSES", RequiredScale = 2, Growth = 4, Coins = 5 }, -- casas, parquinho
	{ Name = "BigHouse", DisplayName = "SHOPS & BIG HOUSES", RequiredScale = 3.2, Growth = 8, Coins = 12 }, -- lojas
	{ Name = "Building", DisplayName = "BUILDINGS", RequiredScale = 5, Growth = 16, Coins = 30 }, -- prédios, aviões
	{ Name = "Tower", DisplayName = "TOWERS", RequiredScale = 8, Growth = 32, Coins = 80 }, -- torres, guindastes
	{ Name = "Landmark", DisplayName = "LANDMARKS", RequiredScale = 13, Growth = 64, Coins = 200 }, -- arranha-céus
}

for _, tier in tiers do
	table.freeze(tier)
end

return table.freeze(tiers)
