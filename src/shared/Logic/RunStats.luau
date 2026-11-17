--!strict
-- Estatísticas de cada jogador na run (pura). O servidor (StatsService) guarda uma por jogador e mostra no
-- placar (leaderstats). Cada número só entra uma vez:
--   Damage: dano que realmente entrou (StructureHealth.hitDealt, sem passar da vida que sobrava);
--   Destroyed: construções em que ESTE jogador deu o golpe final (StructureHealth garante uma vez só);
--   Chains: reações em cadeia que ele começou (explosão, desabamento, fogo, faísca, batida de destroço);
--   Score: pontos do tier x bônus da cadeia (Logic/Score).

local RunStats = {}

export type Stats = { Score: number, Damage: number, Destroyed: number, Chains: number }

-- Ordem das colunas no placar (a primeira é a que o Roblox usa para ordenar).
RunStats.Columns = table.freeze({ "Score", "Damage", "Destroyed", "Chains" })

function RunStats.new(): Stats
	return { Score = 0, Damage = 0, Destroyed = 0, Chains = 0 }
end

function RunStats.addDamage(stats: Stats, dealt: number)
	if dealt > 0 and dealt == dealt then
		stats.Damage += dealt
	end
end

function RunStats.addDestroy(stats: Stats, points: number)
	stats.Destroyed += 1
	if points > 0 then
		stats.Score += points
	end
end

function RunStats.addChain(stats: Stats)
	stats.Chains += 1
end

-- Valor inteiro mostrado no placar.
function RunStats.display(stats: Stats, column: string): number
	return math.floor(((stats :: any)[column] or 0) + 0.5)
end

return RunStats
