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

local disasters: { Disaster } = {
	{
		Id = "Meteor",
		Name = "METEOR",
		Icon = "☄️",
		PowerTier = 1,
		Cooldown = 3,
		Range = 60,
		Damage = 140,
		TierExponent = 0.4, -- quase o mesmo dano em tudo: bom contra o que é grande
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
		Cooldown = 7,
		Range = 25, -- nasce até essa distância na direção da mira
		Damage = 16, -- por tique
		-- objetos leves (tiers por nome) que o funil arrasta e derruba na hora ao passar por cima: postes,
		-- bancos, lixeiras... (antes sobravam: ficavam só ~2 tiques dentro do funil, Disasters.contactTicks)
		Sweeps = table.freeze({ Prop = true }),
		TierExponent = 1.6, -- moe o que é pequeno, quase não arranha o que é grande
		Radius = 5,
		Speed = 22, -- studs/s
		Duration = 4.5,
		Tick = 0.2,
	},
	{
		Id = "Lightning",
		Name = "BOLT",
		Icon = "⚡",
		PowerTier = 1,
		Cooldown = 2,
		Range = 55,
		Damage = 110, -- buff (antes 70): o raio estava fraco perto do meteoro
		TierExponent = 1,
		Snap = 10, -- procura o primeiro alvo até essa distância da mira (antes 8)
		Hops = 8, -- pulos depois do primeiro alvo (antes 6)
		HopRange = 11, -- distância máxima de um pulo (antes 9)
		HopDecay = 0.85, -- força que sobra a cada pulo (antes 0.75)
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
	RadiusExponent = 1, -- raios crescem junto com o poder (igual ao círculo de comer antigo)
	RangeExponent = 0.8,
	SpeedExponent = 0.45,
	MaxTargetsPerHit = 60, -- teto por acerto/tique (celular e servidor)
	MaxActive = 12, -- desastres ao mesmo tempo no servidor (party de 4 com folga)
})
