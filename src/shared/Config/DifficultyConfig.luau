--!strict
-- Dificuldades da run. Quanto mais difícil, maior a cidade e mais devagar você varre:
--   MapScale = tamanho da cidade (multiplica as medidas da planta; a área cresce com o quadrado);
--   Reach = alcance da boca; Speed = velocidade de andar;
--   Minutes = tempo-alvo para zerar a cidade (ESTIMATIVA conferida no teste Cities.spec).
-- Growth multiplica o crescimento (o balanceamento de cada cidade já conta com ele); Reward multiplica as gemas.
-- O crescimento é da party inteira: tudo que alguém come faz todos crescerem.
-- RequiredWins: vitórias da conta necessárias para liberar.

export type Difficulty = {
	Id: string,
	Name: string,
	Skulls: number, -- quantas caveiras aparecem no botão
	Growth: number,
	Reward: number,
	RequiredWins: number,
	MapScale: number,
	Reach: number,
	Speed: number,
	Minutes: number,
}

local difficulties: { Difficulty } = {
	{
		Id = "Normal",
		Name = "EASY",
		Skulls = 1,
		Growth = 1,
		Reward = 1,
		RequiredWins = 0,
		MapScale = 1,
		Reach = 1.4,
		Speed = 1.3,
		Minutes = 10,
	},
	{
		Id = "Hard",
		Name = "MEDIUM",
		Skulls = 2,
		Growth = 1,
		Reward = 2,
		RequiredWins = 0,
		MapScale = 1.25,
		Reach = 1.1,
		Speed = 1,
		Minutes = 30,
	},
	{
		Id = "Insane",
		Name = "HARD",
		Skulls = 3,
		Growth = 1,
		Reward = 3,
		RequiredWins = 5,
		MapScale = 1.5,
		Reach = 0.9,
		Speed = 0.9,
		Minutes = 60,
	},
}

for _, d in difficulties do
	table.freeze(d)
end
return table.freeze(difficulties)
