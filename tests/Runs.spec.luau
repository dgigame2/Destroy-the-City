-- Regras da partida: mapas liberados e gemas da vitória.
local Runs = require("../src/shared/Logic/Runs")
local MapConfig = require("../src/shared/Config/MapConfig")
local DifficultyConfig = require("../src/shared/Config/DifficultyConfig")
local RunConfig = require("../src/shared/Config/RunConfig")

return function(t)
	t.test("primeiro capítulo e Normal sempre liberados; capítulos pedem vitórias crescentes", function()
		t.equal(MapConfig[1].RequiredWins, 0)
		t.equal(DifficultyConfig[1].RequiredWins, 0)
		for i = 2, #MapConfig do
			t.truthy(MapConfig[i].RequiredWins >= MapConfig[i - 1].RequiredWins)
		end
	end)

	t.test("gemas da vitória", function()
		t.equal(Runs.winGems(RunConfig.WinGems, 2), RunConfig.WinGems * 2)
	end)
end
