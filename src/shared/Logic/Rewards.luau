--!strict
-- Calendário das recompensas de login. Funções puras com tempo Unix (segundos, UTC).

local DAY = 24 * 60 * 60

local Rewards = {}

function Rewards.dayIndex(unix: number): number
	return math.floor(unix / DAY)
end

-- 01/01/1970 foi quinta-feira; +3 faz a semana virar na segunda-feira.
function Rewards.weekIndex(unix: number): number
	return math.floor((math.floor(unix / DAY) + 3) / 7)
end

-- Estado da diária. lastDay = dia do último resgate (ou -1), streak = dia da sequência já resgatado (0..7).
-- Retorna: pode resgatar hoje, dia da sequência que será dado (1..cycle).
function Rewards.daily(lastDay: number, streak: number, today: number, cycle: number): (boolean, number)
	if lastDay == today then
		return false, streak
	end
	if lastDay == today - 1 then
		return true, (streak % cycle) + 1
	end
	return true, 1 -- perdeu um dia (ou primeira vez): volta ao começo
end

function Rewards.weekly(lastWeek: number, thisWeek: number): boolean
	return lastWeek ~= thisWeek
end

-- Segundos até a próxima meia-noite UTC.
function Rewards.secondsToNextDay(unix: number): number
	return DAY - (unix % DAY)
end

return Rewards
