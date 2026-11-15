-- Regras das parties e das runs: opções da CREATE PARTY, quem entra, quando sai, runs salvas,
-- e o principal: dá para comer a cidade inteira (vitória) em todo mapa e dificuldade.
local Party = require("../src/shared/Logic/Party")
local Runs = require("../src/shared/Logic/Runs")
local MapConfig = require("../src/shared/Config/MapConfig")
local DifficultyConfig = require("../src/shared/Config/DifficultyConfig")
local PartyConfig = require("../src/shared/Config/PartyConfig")
local RunConfig = require("../src/shared/Config/RunConfig")

local DAY = 86400

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
		for _, status in { "Empty", "Creating", "Open", "Loading", "Departing" } do
			t.truthy(PartyConfig.Colors[status])
		end
	end)

	-- Runs salvas --------------------------------------------------------------------
	local function summary(id, updated)
		return {
			Id = id,
			Map = "GardenVillage",
			Difficulty = "Normal",
			Members = { 1 },
			Names = { "a" },
			Progress = 0,
			UpdatedAt = updated,
		}
	end

	t.test("lista de runs salvas: mais recente primeiro, sem repetir, sem expiradas, com limite", function()
		local now = 10 * DAY
		local list = {}
		for i = 1, 7 do
			list = Runs.upsert(list, summary("r" .. i, now - i), now, 7, 5)
		end
		t.equal(#list, 5)
		t.equal(list[1].Id, "r1")
		list = Runs.upsert(list, summary("r3", now), now, 7, 5)
		t.equal(list[1].Id, "r3")
		local count = 0
		for _, e in list do
			if e.Id == "r3" then
				count += 1
			end
		end
		t.equal(count, 1)
		local old = Runs.upsert({ summary("old", now - 8 * DAY) }, summary("new", now), now, 7, 5)
		t.equal(#old, 1)
		t.equal(#Runs.remove(old, "new"), 0)
		t.equal(#Runs.clean({ summary("x", now - 8 * DAY), summary("y", now) }, now, 7), 1)
	end)

	t.test("expiração e texto do tempo", function()
		t.truthy(Runs.isExpired(0, 7 * DAY, 7))
		t.falsy(Runs.isExpired(1, 7 * DAY, 7))
		t.equal(Runs.formatDuration(DAY + 4 * 3600 + 59), "1d 4h")
		t.equal(Runs.formatDuration(3 * 3600 + 12 * 60), "3h 12m")
		t.equal(Runs.formatDuration(45 * 60), "45m")
		t.equal(Runs.formatDuration(-5), "0m")
	end)

	t.test("carregar run salva exige todos os membros", function()
		local ok, missing = Runs.canLoad({ 1, 2, 3 }, { 1, 3 })
		t.falsy(ok)
		t.equal(missing[1], 2)
		t.truthy((Runs.canLoad({ 1, 2 }, { 2, 1, 9 })))
	end)

	t.test("construções comidas: salvar e carregar sem lixo", function()
		local list = Runs.encodeEaten({ [5] = true, [2] = true, [9] = false })
		t.equal(#list, 2)
		t.equal(list[1], 2)
		local set = Runs.decodeEaten({ 2, 5, 999, -1, 1.5, "x" }, 10)
		t.truthy(set[2] and set[5])
		t.equal(set[999], nil)
		t.equal(next(Runs.decodeEaten("lixo", 10)), nil)
	end)

	t.test("progresso, vitória e gemas", function()
		t.equal(Runs.progress(50, 200), 0.25)
		t.falsy(Runs.isVictory(199, 200))
		t.truthy(Runs.isVictory(200, 200))
		t.equal(Runs.winGems(RunConfig.WinGems, 2), RunConfig.WinGems * 2)
	end)
end
