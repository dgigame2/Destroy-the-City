-- Relatório de tempo de partida (ESTIMATIVA, Logic/MatchSim) com as cidades reais.
-- Uso: lune run simulate
-- Mostra, por cidade, dificuldade e número de jogadores, o tempo até cada marco e até 100%, com cada
-- elemento no nível 1 e no nível 5. No fim, o HpPerValue que deixaria Garden Village / 1ª dificuldade / solo /
-- nível 1 no alvo da AUDITORIA (§11: ~9 min com evolução, então ~12 min só no nível 1 é o teto aceitável).
local Templates = require("../src/shared/Buildings/Templates")
local MapConfig = require("../src/shared/Config/MapConfig")
local CityPlans = require("../src/shared/Config/CityPlans")
local CityConfig = require("../src/shared/Config/CityConfig")
local DistrictConfig = require("../src/shared/Config/DistrictConfig")
local DifficultyConfig = require("../src/shared/Config/DifficultyConfig")
local ModelCatalog = require("../src/shared/Config/ModelCatalog")
local MatchConfig = require("../src/shared/Config/MatchConfig")
local ElementConfig = require("../src/shared/Config/ElementConfig")
local CityGen = require("../src/shared/Logic/CityGen")
local MatchCity = require("../src/shared/Logic/MatchCity")
local MatchSim = require("../src/shared/Logic/MatchSim")
local Rng = require("../src/shared/Logic/Rng")

local EFFICIENCY = 0.5 -- ESTIMATIVA: metade do tempo acertando algo útil (mira, andar, alvo já destruído)
local TARGET_SOLO_L1 = 12 * 60 -- teto aceitável só no nível 1 (com evolução a meta é ~9 min)

local function minutes(s: number): string
	return string.format("%5.1f", s / 60)
end

local suggestion = nil
for _, map in MapConfig do
	for _, difficulty in DifficultyConfig do
		local layout = CityGen.generate(
			CityPlans[map.Id],
			DistrictConfig[map.Style],
			Templates,
			Rng.new(map.Seed),
			CityConfig,
			difficulty.MapScale
		)
		local infos = MatchCity.infos(layout.Placements, Templates, ModelCatalog, MatchConfig)
		local land, counted, value = 0, 0, 0
		for _, info in infos do
			land += (info.Box[3] - info.Box[1]) * (info.Box[4] - info.Box[2])
			if info.Value > 0 then
				counted += 1
				value += info.Value
			end
		end
		land *= 2.5 -- ESTIMATIVA: rua, calçada e quintal em volta (chão construído ≈ 2,5× os footprints)
		print(
			string.format(
				"\n%s / %s: %d objetos (%d contam), valor %.0f",
				map.DisplayName,
				difficulty.Name,
				#infos,
				counted,
				value
			)
		)
		for _, element in ElementConfig.List do
			for _, level in { 1, 5 } do
				local line = { string.format("  %-9s L%d", element.Id, level) }
				for _, players in { 1, 2, 4 } do
					local r = MatchSim.run(
						infos,
						land,
						element,
						level,
						players,
						EFFICIENCY,
						MatchConfig.Milestones,
						MatchConfig.CompleteAt,
						ElementConfig.TallBonus
					)
					table.insert(
						line,
						string.format("%dP: 50%%%s  100%%%s min", players, minutes(r.Milestones[2]), minutes(r.Seconds))
					)
					if suggestion == nil and players == 1 and level == 1 and element.Id == "Fire" then
						suggestion = MatchConfig.HpPerValue * TARGET_SOLO_L1 / r.Seconds
					end
				end
				print(table.concat(line, "  |  "))
			end
		end
	end
end
print(
	string.format(
		"\nHpPerValue atual %.2f -> sugerido %.2f (Garden / 1ª dificuldade / solo / Fogo L1 em %d min)",
		MatchConfig.HpPerValue,
		suggestion or 0,
		TARGET_SOLO_L1 / 60
	)
)
