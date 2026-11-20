--!strict
-- Elementos (AUDITORIA §10). Cada um tem 5 níveis; cada nível muda a MECÂNICA, não só o dano (Etapa 4).
--   Damage/Radius/Cooldown/Range/MaxTargets = base. Power[n] = dano do nível n = Damage x Power[n], CALIBRADO
--   (lune run simulate, Garden Village solo) para a velocidade de destruir seguir ~1 / 1,5 / 2,3 / 3,4 / 5x do
--   nível 1 já contando a mecânica nova de cada nível (área maior, cadeia, tornado...). Por isso não cresce
--   reto: um nível com mecânica forte precisa de menos dano por golpe. O teste Elements.spec confere a curva.
--   Levels[n] = o golpe do nível n, montado por Logic/ElementPlan a partir de "partes" (Parts):
--     Impact: Count golpes em volta do alvo (Spread x R), Stagger s entre eles; Chain = salta para Hops vizinhos
--     Cone:   Steps círculos seguindo a direção do golpe (de quem lançou para o alvo), um a cada Interval s
--     Ring:   Steps círculos que abrem de RadiusFrom a RadiusTo (x R) em volta do alvo
--     Storm:  Count golpes sorteados (semente) numa área Area x R durante Duration s
--     Path:   um centro que anda na direção do golpe a Speed studs/s por Duration s, batendo a cada Interval s
--             (Speed 0 = parado: vórtice)
--   Radius e Mult de cada parte são x Radius e x dano do nível. Burn (Fogo) = queima: Dps x dano do nível
--   por Seconds s em cada construção atingida; Foci > 0 = o fogo se espalha para vizinhos (até Foci focos
--   por golpe, dentro de SpreadRange studs). Cooldown do nível substitui o base quando existe.
--   Visual = efeito do cliente (client/City/ElementFx).
--   Strong = multiplicador contra o que o elemento faz de melhor (identidade de cada um).
--   TallFrom = altura (studs) a partir da qual o Raio leva o bônus de prédio alto.

export type Element = {
	Id: string,
	Name: string,
	Short: string, -- nome no botão (cabe no celular curto)
	Icon: string, -- emoji do ícone (IconConfig troca por imagem)
	Theme: string, -- cor do botão na hotbar (Style.Themes)
	Damage: number,
	Radius: number,
	Cooldown: number,
	Range: number,
	MaxTargets: number,
	Power: { number },
	Strong: { [string]: number },
	TallFrom: number?,
	Color: { number },
	Levels: { Level },
}

export type Part = { [string]: any }
export type Level = {
	Visual: string,
	Cooldown: number?,
	Parts: { Part },
	Burn: { Seconds: number, Dps: number, Foci: number, SpreadRange: number }?,
}

local list: { Element } = {
	{
		Id = "Fire",
		Name = "FIRE",
		Short = "FIRE",
		Icon = "🔥",
		Theme = "Orange",
		Damage = 52,
		Radius = 14,
		Cooldown = 0.9,
		Range = 220,
		MaxTargets = 8,
		Power = { 1, 0.8, 0.97, 0.83, 1.8 },
		Strong = { Building = 1.25, Tree = 2 },
		Color = { 255, 120, 40 },
		Levels = {
			-- 1 bola de fogo: impacto e queima por 3 s
			{
				Visual = "Fireball",
				Parts = { { Shape = "Impact", Radius = 1, Mult = 1 } },
				Burn = { Seconds = 3, Dps = 0.1, Foci = 0, SpreadRange = 0 },
			},
			-- 2 bola maior, queima mais longa
			{
				Visual = "Fireball",
				Parts = { { Shape = "Impact", Radius = 1.3, Mult = 1 } },
				Burn = { Seconds = 4.5, Dps = 0.1, Foci = 0, SpreadRange = 0 },
			},
			-- 3 incêndio que se espalha (só para vizinhos, teto de focos)
			{
				Visual = "Fireball",
				Parts = { { Shape = "Impact", Radius = 1.3, Mult = 1 } },
				Burn = { Seconds = 4.5, Dps = 0.1, Foci = 5, SpreadRange = 18 },
			},
			-- 4 explosão de calor: onda que abre em volta do impacto
			{
				Visual = "HeatWave",
				Cooldown = 1.4,
				Parts = {
					{ Shape = "Impact", Radius = 1.2, Mult = 1 },
					{ Shape = "Ring", Steps = 3, RadiusFrom = 1.6, RadiusTo = 2.8, Interval = 0.15, Mult = 0.3 },
				},
				Burn = { Seconds = 4.5, Dps = 0.1, Foci = 7, SpreadRange = 20 },
			},
			-- 5 inferno: coluna de fogo que anda
			{
				Visual = "Inferno",
				Cooldown = 3,
				Parts = {
					{ Shape = "Path", Duration = 3, Interval = 0.25, Speed = 22, Radius = 1.4, Mult = 0.42 },
				},
				Burn = { Seconds = 4.5, Dps = 0.1, Foci = 10, SpreadRange = 22 },
			},
		},
	},
	{
		Id = "Lightning",
		Name = "LIGHTNING",
		Short = "BOLT",
		Icon = "⚡",
		Theme = "Blue",
		Damage = 318,
		Radius = 7,
		Cooldown = 1.2,
		Range = 260,
		MaxTargets = 3,
		Power = { 1, 0.94, 0.78, 2.06, 0.96 },
		Strong = {},
		TallFrom = 30,
		Color = { 120, 200, 255 },
		Levels = {
			-- 1 raio único
			{ Visual = "Bolt", Parts = { { Shape = "Impact", Radius = 1, Mult = 1 } } },
			-- 2 raio duplo
			{
				Visual = "Bolt",
				Parts = { { Shape = "Impact", Radius = 1, Mult = 0.8, Count = 2, Spread = 0.9, Stagger = 0.08 } },
			},
			-- 3 raio em cadeia: salta para 3 vizinhos
			{
				Visual = "Bolt",
				Parts = {
					{ Shape = "Impact", Radius = 1, Mult = 1, Chain = { Hops = 3, Range = 40, Falloff = 0.8 } },
				},
			},
			-- 4 tempestade: raios na área por 4 s
			{
				Visual = "Storm",
				Cooldown = 4,
				Parts = { { Shape = "Storm", Count = 10, Duration = 4, Area = 3, Radius = 1, Mult = 0.55 } },
			},
			-- 5 supercélula: impacto gigante e cadeia de 6
			{
				Visual = "Supercell",
				Cooldown = 2.5,
				Parts = {
					{ Shape = "Impact", Radius = 2.2, Mult = 1.4, Chain = { Hops = 6, Range = 50, Falloff = 0.85 } },
				},
			},
		},
	},
	{
		Id = "Wind",
		Name = "WIND",
		Short = "WIND",
		Icon = "🌪️",
		Theme = "LightBlue",
		Damage = 31,
		Radius = 22,
		Cooldown = 1,
		Range = 200,
		MaxTargets = 14,
		Power = { 1, 0.73, 1.43, 2.56, 1.3 },
		Strong = { Vehicle = 3, Tree = 3, Plant = 3, Street = 3, Leisure = 3, Beach = 3, Stall = 1.5 },
		Color = { 200, 245, 230 },
		Levels = {
			-- 1 rajada em cone curto
			{
				Visual = "Gust",
				Parts = { { Shape = "Cone", Steps = 2, Interval = 0.08, RadiusFrom = 0.8, RadiusTo = 1, Mult = 0.55 } },
			},
			-- 2 ventania: cone maior
			{
				Visual = "Gust",
				Parts = {
					{ Shape = "Cone", Steps = 3, Interval = 0.08, RadiusFrom = 0.9, RadiusTo = 1.3, Mult = 0.5 },
				},
			},
			-- 3 vórtice parado que gira
			{
				Visual = "Vortex",
				Cooldown = 2.5,
				Parts = { { Shape = "Path", Duration = 2.5, Interval = 0.25, Speed = 0, Radius = 1.1, Mult = 0.3 } },
			},
			-- 4 tornado que anda na direção do golpe
			{
				Visual = "Tornado",
				Cooldown = 4,
				Parts = { { Shape = "Path", Duration = 4, Interval = 0.25, Speed = 14, Radius = 1, Mult = 0.3 } },
			},
			-- 5 furacão: tornado gigante
			{
				Visual = "Hurricane",
				Cooldown = 5,
				Parts = { { Shape = "Path", Duration = 5, Interval = 0.25, Speed = 12, Radius = 1.7, Mult = 0.3 } },
			},
		},
	},
}

local byId: { [string]: Element } = {}
local function deepFreeze(t: any)
	for _, v in t do
		if type(v) == "table" and not table.isfrozen(v) then
			deepFreeze(v)
		end
	end
	table.freeze(t)
end

for _, e in list do
	deepFreeze(e.Levels)
	table.freeze(e.Power)
	table.freeze(e.Strong)
	table.freeze(e.Color)
	byId[e.Id] = table.freeze(e)
end

return table.freeze({
	List = table.freeze(list),
	ById = table.freeze(byId),
	MaxLevel = 5,
	TallBonus = 1.5,
})
