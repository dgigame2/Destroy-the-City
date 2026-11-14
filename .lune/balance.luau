-- Relatório de balanceamento (ESTIMATIVA): quantos itens do maior tier comível são necessários
-- para alcançar o próximo tier. Uso: lune run balance
local Growth = require("../src/shared/Logic/Growth")
local TierConfig = require("../src/shared/Config/TierConfig")
local GrowthConfig = require("../src/shared/Config/GrowthConfig")

local SECONDS_PER_BITE = 1.5 -- ESTIMATIVA: tempo médio para achar e comer um item do tier atual

local total = 0
for i = 2, #TierConfig do
	local need = Growth.pointsForScale(TierConfig[i].RequiredScale, GrowthConfig)
	local have = Growth.pointsForScale(TierConfig[i - 1].RequiredScale, GrowthConfig)
	local bites = math.ceil((need - have) / TierConfig[i - 1].Growth)
	total += bites * SECONDS_PER_BITE
	print(
		string.format(
			"%-9s -> %-9s: %5.0f pontos, ~%3d mordidas de %-8s (~%3.0fs, acumulado ~%4.0fs)",
			TierConfig[i - 1].Name,
			TierConfig[i].Name,
			need - have,
			bites,
			TierConfig[i - 1].Name,
			bites * SECONDS_PER_BITE,
			total
		)
	)
end
