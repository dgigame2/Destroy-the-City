--!strict
-- Pontuação da run (pura, simples e transparente): cada construção destruída vale os pontos do tier dela.
-- Quem dá o golpe final leva (StructureHealth garante uma vez só por construção).

local Score = {}

function Score.forDestroy(tierIndex: number, pointsByTier: { number }): number
	return pointsByTier[tierIndex] or 0
end

-- Ranking da party: lista ordenada do maior para o menor (empate: nome).
export type Entry = { Name: string, Score: number }
function Score.ranking(entries: { Entry }): { Entry }
	local list = table.clone(entries)
	table.sort(list, function(a, b)
		if a.Score ~= b.Score then
			return a.Score > b.Score
		end
		return a.Name < b.Name
	end)
	return list
end

return Score
