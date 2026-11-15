--!strict
-- Junta os bônus de upgrades, classe e boosts temporários. Funções puras.

local Buffs = {}

export type Sources = {
	Upgrade: number, -- bônus do upgrade (0.12 = +12%)
	Class: number, -- bônus da classe
	BoostActive: boolean, -- boost 2x ativo para esse atributo
}

-- Multiplicador final: (1 + upgrade + classe) * (2 se boost ativo).
function Buffs.multiplier(sources: Sources): number
	local base = 1 + sources.Upgrade + sources.Class
	return if sources.BoostActive then base * 2 else base
end

function Buffs.boostActive(untilTime: number?, now: number): boolean
	return untilTime ~= nil and untilTime > now
end

-- Boost comprado com outro já ativo: soma o tempo ao que falta.
function Buffs.extendBoost(untilTime: number?, now: number, seconds: number): number
	local start = if untilTime and untilTime > now then untilTime else now
	return start + seconds
end

-- Gemas que caem ao comer uma construção do tier dado. luck multiplica a chance (classe Lucky = 2).
function Buffs.gemDrop(drop: { Chance: number, Amount: number }?, roll: number, luck: number?): number
	if drop == nil or roll >= drop.Chance * (luck or 1) then
		return 0
	end
	return drop.Amount
end

return Buffs
