--!strict
-- Simulação de tempo de partida (pura, AUDITORIA §11). Usa a cidade REAL gerada (MatchCity.infos) e os
-- números do ElementConfig. É ESTIMATIVA: o modelo é simples e serve para calibrar e comparar cenários,
-- não para prometer tempo exato.
--   * cada golpe acerta até MaxTargets construções no raio; quantas, em média, depende da densidade da
--     cidade (construções por stud² de chão construído) × área do golpe;
--   * Efficiency = fração do tempo em que o jogador está acertando algo útil (mira, andar, alvos já mortos);
--   * o dano em objetos que não contam (Value 0) é desperdício, mas entra na conta (eles estão no caminho);
--   * vida ∝ valor, então o progresso por valor cresce ~linear com o tempo: marco f ≈ f × tempo total.

local ElementPlan = if script then require(script.Parent.ElementPlan) else require("./ElementPlan")

local MatchSim = {}

export type Result = {
	Seconds: number, -- tempo até 100% (com CompleteAt já aplicado)
	Milestones: { number }, -- segundos até cada marco
	CastsPerTarget: number, -- alvos médios por golpe
}

-- Densidade: construções por stud² na área ocupada pelos footprints (aproximação do chão construído).
function MatchSim.density(infos: { any }, landArea: number): number
	return #infos / math.max(landArea, 1)
end

-- Dano útil por segundo de UM jogador com um elemento no nível dado: o golpe REAL do nível (Logic/ElementPlan,
-- com pulsos, cadeia e queima), x a eficiência. Segundo valor: alvos médios do 1º pulso (informativo).
function MatchSim.playerDps(element: any, level: number, density: number, efficiency: number): (number, number)
	local area = math.pi * element.Radius * element.Radius
	local targets = math.clamp(density * area, 1, element.MaxTargets)
	return ElementPlan.expectedDps(element, level, 5, density) * efficiency, targets
end

-- Tempo para `players` jogadores destruírem a cidade, cada um com `element` no `level`.
-- Multiplicadores de identidade (Strong/TallBonus) entram pela média ponderada por vida.
function MatchSim.run(
	infos: { any },
	landArea: number,
	element: any,
	level: number,
	players: number,
	efficiency: number,
	milestones: { number },
	completeAt: number,
	tallBonus: number
): Result
	local hp = 0
	for _, info in infos do
		local m = element.Strong[info.Category] or 1
		if element.TallFrom and info.Height >= element.TallFrom then
			m *= tallBonus
		end
		hp += info.MaxHp / m
	end
	local dps, targets = MatchSim.playerDps(element, level, MatchSim.density(infos, landArea), efficiency)
	-- quem destrói junto não soma 100%: alvos disputados (ESTIMATIVA: −10% por jogador extra, até −30%)
	local team = players * (1 - math.min((players - 1) * 0.1, 0.3))
	local total = hp * completeAt / (dps * team)
	local marks = {}
	for i, f in milestones do
		marks[i] = total * math.min(f, completeAt) / completeAt
	end
	return { Seconds = total, Milestones = marks, CastsPerTarget = targets }
end

return MatchSim
