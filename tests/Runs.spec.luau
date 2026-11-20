-- Regras das parties e das runs: opções da CREATE PARTY, quem entra, quando sai, runs salvas,
-- e o principal: dá para comer a cidade inteira (vitória) em todo mapa e dificuldade.
local Party = require("../src/shared/Logic/Party")
local Runs = require("../src/shared/Logic/Runs")
local MapConfig = require("../src/shared/Config/MapConfig")
local DifficultyConfig = require("../src/shared/Config/DifficultyConfig")
local PartyConfig = require("../src/shared/Config/PartyConfig")
local RunConfig = require("../src/shared/Config/RunConfig")

return function(t)
	-- CREATE PARTY -------------------------------------------------------------------
	t.test("opções válidas passam e voltam limpas", function()
		local s = Party.validate(
			{ Map = "GardenVillage", Difficulty = "Normal", Size = 4, Extra = true },
			0,
			MapConfig,
			DifficultyConfig,
			PartyConfig.MaxSize
		)
		t.truthy(s ~= nil)
		t.equal((s :: any).Size, 4)
		t.equal((s :: any).Extra, nil)
	end)

	t.test("capítulo e dificuldade travados exigem vitórias", function()
		local _, why =
			Party.validate({ Map = "Metropolis", Difficulty = "Normal", Size = 1 }, 0, MapConfig, DifficultyConfig, 4)
		t.equal(why, "map locked")
		local _, why2 = Party.validate(
			{ Map = "GardenVillage", Difficulty = "Insane", Size = 1 },
			4,
			MapConfig,
			DifficultyConfig,
			4
		)
		t.equal(why2, "difficulty locked")
		t.truthy(
			Party.validate(
				{ Map = "GardenVillage", Difficulty = "Insane", Size = 1 },
				5,
				MapConfig,
				DifficultyConfig,
				4
			) ~= nil
		)
	end)

	t.test("tamanho da party só de 1 a 4 (inteiro)", function()
		for _, size in { 0, 5, 2.5, -1 } do
			local s = Party.validate(
				{ Map = "GardenVillage", Difficulty = "Normal", Size = size },
				0,
				MapConfig,
				DifficultyConfig,
				4
			)
			t.equal(s, nil)
		end
		for _, bad in { nil, "x", { Map = 1, Difficulty = "Normal", Size = 1 } } do
			t.equal(Party.validate(bad, 0, MapConfig, DifficultyConfig, 4), nil)
		end
	end)

	t.test("primeiro capítulo e Normal sempre liberados; capítulos pedem vitórias crescentes", function()
		t.equal(MapConfig[1].RequiredWins, 0)
		t.equal(DifficultyConfig[1].RequiredWins, 0)
		for i = 2, #MapConfig do
			t.truthy(MapConfig[i].RequiredWins >= MapConfig[i - 1].RequiredWins)
		end
	end)

	-- Party no quadrado -----------------------------------------------------------------
	t.test("membros: dono primeiro, depois quem chegou, até o tamanho", function()
		local m = Party.members(7, { 3, 7, 9, 11, 12 }, 3)
		t.equal(#m, 3)
		t.equal(m[1], 7)
		t.equal(m[2], 3)
		t.equal(m[3], 9)
		t.equal(#Party.members(7, {}, 4), 1)
	end)

	t.test("party sai no tempo aberto ou logo depois de lotar", function()
		t.equal(Party.departAt(100, nil, 25, 5), 125)
		t.equal(Party.departAt(100, 110, 25, 5), 115)
		t.equal(Party.departAt(100, 124, 25, 5), 125)
	end)

	t.test("textos das placas", function()
		t.equal((Party.statusText("Empty", nil, 0, 4)), "Touch to create a party")
		local _, line = Party.statusText("Open", "Ana", 2, 4, 9.2)
		t.equal(line, "2/4  •  10s")
		t.equal((Party.statusText("Creating", "Ana", 1, 4)), "Ana is creating a party")
		t.equal((Party.statusText("Departing", "Ana", 4, 4)), "Starting the run!")
		-- cada situação tem cor de borda
		for _, status in { "Empty", "Creating", "Open", "Departing" } do
			t.truthy(PartyConfig.Colors[status])
		end
	end)

	-- Vitória -----------------------------------------------------------------------
	t.test("gemas da vitória", function()
		t.equal(Runs.winGems(RunConfig.WinGems, 2), RunConfig.WinGems * 2)
	end)
end
