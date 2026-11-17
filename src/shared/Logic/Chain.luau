--!strict
-- Regras da destruição em cadeia (puras). O servidor busca as vizinhas e aplica o que estas funções decidem.

local Chain = {}

type Config = {
	MaxDepth: number,
	MaxPerChain: number,
	DepthBonus: number,
	MaxBonus: number,
	EdgeDamage: number,
	Labels: { { At: number, Text: string } },
	Explosive: { [string]: { Radius: number, DamageFactor: number } },
	CollapseFromTier: number,
	Collapse: { RadiusPadding: number, DamageFactor: number },
	MaxPerBuilding: number?,
	Fire: {
		Radius: number,
		DamageFactor: number,
		FlammableBonus: number,
		Flammable: { [string]: boolean },
		Causes: { [string]: boolean }?,
	}?,
	Electric: { Hops: number, HopRange: number, ConductorRange: number, DamageFactor: number }?,
}

export type Reaction = { Kind: string, Radius: number, DamageFactor: number }

-- O que uma construção que caiu faz com as vizinhas (nil = nada).
-- footprint = maior lado da construção em studs.
function Chain.reaction(template: string, tier: number, footprint: number, cfg: Config): Reaction?
	local explosive = cfg.Explosive[template]
	if explosive then
		return { Kind = "Explosion", Radius = explosive.Radius, DamageFactor = explosive.DamageFactor }
	end
	if tier >= cfg.CollapseFromTier then
		return {
			Kind = "Collapse",
			Radius = footprint / 2 + cfg.Collapse.RadiusPadding,
			DamageFactor = cfg.Collapse.DamageFactor,
		}
	end
	return nil
end

-- Todas as reações de uma construção que caiu, na ordem: onda (explosão ou desabamento), faísca (condutor),
-- fogo (inflamável). No máximo cfg.MaxPerBuilding. `conductors` = StructureConfig.Conductors.
-- `cause` = desastre que derrubou (ou começou a cadeia): só os de Fire.Causes acendem fogo (tornado não).
function Chain.reactions(
	template: string,
	tier: number,
	footprint: number,
	cfg: Config,
	conductors: { [string]: boolean },
	cause: string?
): { Reaction }
	local list: { Reaction } = {}
	local blast = Chain.reaction(template, tier, footprint, cfg)
	if blast then
		table.insert(list, blast)
	end
	local electric = cfg.Electric
	if electric and conductors[template] then
		table.insert(list, {
			Kind = "Electric",
			Radius = electric.HopRange * electric.ConductorRange * electric.Hops,
			DamageFactor = electric.DamageFactor,
		})
	end
	local fire = cfg.Fire
	local ignites = fire ~= nil and (fire.Causes == nil or cause == nil or fire.Causes[cause] == true)
	if fire and ignites and fire.Flammable[template] then
		table.insert(list, { Kind = "Fire", Radius = fire.Radius, DamageFactor = fire.DamageFactor })
	end
	local max = cfg.MaxPerBuilding or #list
	while #list > max do
		table.remove(list)
	end
	return list
end

-- Dano de um tique de fogo a `distance` (inflamável leva FlammableBonus x).
function Chain.fireDamage(sourceHp: number, distance: number, flammable: boolean, cfg: Config): number
	local fire = cfg.Fire
	if fire == nil then
		return 0
	end
	local reaction = { Kind = "Fire", Radius = fire.Radius, DamageFactor = fire.DamageFactor }
	local damage = Chain.damageAt(sourceHp, reaction, distance, cfg)
	return if flammable then damage * fire.FlammableBonus else damage
end

-- Pode continuar a cadeia? (profundidade do próximo elo e reações já feitas nesta cadeia)
function Chain.canPropagate(depth: number, reactions: number, cfg: Config): boolean
	return depth <= cfg.MaxDepth and reactions < cfg.MaxPerChain
end

-- Dano da reação a `distance` do centro: cheio no centro, cai até EdgeDamage na borda, zero fora.
function Chain.damageAt(sourceHp: number, reaction: Reaction, distance: number, cfg: Config): number
	if distance > reaction.Radius then
		return 0
	end
	local t = distance / math.max(reaction.Radius, 1e-6)
	return sourceHp * reaction.DamageFactor * (1 + (cfg.EdgeDamage - 1) * t)
end

-- Multiplicador de dinheiro/pontos de uma construção derrubada na profundidade `depth` (0 = pelo desastre).
function Chain.bonus(depth: number, cfg: Config): number
	return 1 + math.min(depth * cfg.DepthBonus, cfg.MaxBonus)
end

-- Aviso de combo para `count` construções na mesma cadeia (nil = ainda não). Só o maior que bateu.
function Chain.label(count: number, cfg: Config): string?
	local text = nil
	for _, label in cfg.Labels do
		if count >= label.At then
			text = string.format(label.Text, count)
		end
	end
	return text
end

-- Mostra aviso agora? Só quando a contagem cruza um degrau (não repete o mesmo aviso a cada construção).
function Chain.crossed(before: number, after: number, cfg: Config): boolean
	for _, label in cfg.Labels do
		if before < label.At and after >= label.At then
			return true
		end
	end
	return false
end

return Chain
