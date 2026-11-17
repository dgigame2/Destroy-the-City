--!strict
-- Desastres (Logic/Disasters calcula, server/DisasterService executa, client/DisasterVfx desenha).
-- Medidas em studs NO PODER 1; raios, alcance e velocidade crescem com o poder (Power ^ expoente).
-- Dano: Damage x Power x bônus de tamanho (TierExponent) contra o HP da construção (StructureConfig).
-- Curva de poder: Tier 1 = iniciais (ponto, linha, rede); tiers maiores entram nas próximas fases.
--
-- Cada desastre destrói de um jeito diferente:
--   Meteor: cai num ponto depois de um aviso; dano forte no centro e onda de choque que enfraquece.
--   Tornado: anda em linha reta na direção da mira e moe o que é pequeno no caminho (fraco contra grandes).
--   Lightning: acerta a construção mais perto da mira e PULA para as vizinhas, perdendo força a cada pulo;
--              construções condutoras (StructureConfig.Conductors) não perdem força e esticam o pulo.

export type Disaster = {
	Id: string,
	Name: string,
	Icon: string,
	PowerTier: number, -- degrau da curva de poder (1 iniciais ... 4 fim de jogo)
	Key: Enum.KeyCode?,
	Cooldown: number, -- segundos
	Range: number, -- distância máxima do jogador até a mira (x Power ^ RangeExponent)
	Damage: number, -- dano base por acerto (ou por tique)
	TierExponent: number, -- bônus contra coisas menores que o seu poder: (Power / RequiredScale) ^ isso
	[string]: any,
}

-- PAPÉIS (Vs = multiplicador de dano contra cada tier do TierConfig; 1 = normal, 2 = dobro, 0.2 = 20%):
--   Tornado = varre o PEQUENO (postes, bancos, árvores, carros): arrasta e derruba na hora; quase não
--             arranha prédio.
--   Meteor  = derruba o GRANDE: um meteoro no meio de um prédio; contra coisa pequena é desperdício.
--   Bolt    = ZAP de acabamento: rápido, mira certeira, mata na hora o pequeno que sobrou; quase só 1 alvo.
local disasters: { Disaster } = {
	{
		Id = "Meteor",
		Name = "METEOR",
		Icon = "☄️",
		PowerTier = 1,
		Cooldown = 4,
		Range = 60,
		Damage = 140,
		TierExponent = 0.2, -- quase o mesmo dano em tudo (o papel vem do Vs)
		UnderPower = 0.6, -- contra o que é maior que você perde menos que os outros (StructureConfig: 0.35)
		Vs = table.freeze({
			Prop = 0.4,
			Small = 0.5,
			House = 1,
			BigHouse = 1.4,
			Building = 1.8,
			Tower = 2,
			Landmark = 2.2,
		}),
		Delay = 0.9, -- segundos entre o aviso no chão e o impacto
		Radius = 9, -- onda de choque
		Core = 0.35, -- fração do raio com dano cheio
		EdgeDamage = 0.25, -- fração do dano na borda da onda
	},
	{
		Id = "Tornado",
		Name = "TORNADO",
		Icon = "🌪️",
		PowerTier = 1,
		Cooldown = 8,
		Range = 25, -- nasce até essa distância na direção da mira
		Damage = 10, -- por tique
		-- tiers que o funil arrasta e derruba na hora ao passar por cima (se o seu poder já alcança o tier)
		Sweeps = table.freeze({ Prop = true, Small = true }),
		TierExponent = 1.6, -- moe o que é pequeno, quase não arranha o que é grande
		Vs = table.freeze({
			Prop = 3,
			Small = 3,
			House = 0.6,
			BigHouse = 0.2,
			Building = 0.08,
			Tower = 0.05,
			Landmark = 0.03,
		}),
		Radius = 4.5,
		Speed = 22, -- studs/s
		Duration = 3.5,
		Tick = 0.2,
	},
	{
		Id = "Lightning",
		Name = "BOLT",
		Icon = "⚡",
		PowerTier = 1,
		Cooldown = 1.5,
		Range = 55,
		Damage = 110,
		TierExponent = 1,
		Vs = table.freeze({
			Prop = 4,
			Small = 5,
			House = 0.6,
			BigHouse = 0.3,
			Building = 0.15,
			Tower = 0.1,
			Landmark = 0.08,
		}),
		Snap = 10, -- procura o primeiro alvo até essa distância da mira
		Hops = 2, -- pulos depois do primeiro alvo (zap: quase só o alvo)
		HopRange = 9, -- distância máxima de um pulo
		HopDecay = 0.7, -- força que sobra a cada pulo
		ConductorRange = 1.6, -- condutor: pulo até HopRange x isso, sem perder força
	},
}

local byId: { [string]: Disaster } = {}
for _, disaster in disasters do
	table.freeze(disaster)
	byId[disaster.Id] = disaster
end

return table.freeze({
	List = table.freeze(disasters),
	ById = table.freeze(byId),
	-- raios crescem mais devagar que o poder (no poder 26 o raio é ~7x, não 26x: o end game não apaga a cidade)
	RadiusExponent = 0.6,
	RangeExponent = 0.65,
	-- teto do bônus contra coisas menores: (Power / RequiredScale) conta no máximo até isso
	OverkillCap = 4,
	SpeedExponent = 0.45,
	MaxTargetsPerHit = 60, -- teto por acerto/tique (celular e servidor)
	MaxActive = 12, -- desastres ao mesmo tempo no servidor (party de 4 com folga)
})
