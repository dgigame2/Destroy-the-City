--!strict
-- Regras da partida no lobby (puras, testáveis no Lune): recompensa da vitória e desbloqueio por vitórias.
-- O progresso da cidade fica em Logic/CityState (pelo valor destruído).

local Runs = {}

function Runs.winGems(base: number, rewardMultiplier: number): number
	return math.floor(base * rewardMultiplier + 0.5)
end

function Runs.unlocked(requiredWins: number, wins: number): boolean
	return wins >= requiredWins
end

return Runs
