local Voting = require("../src/shared/Logic/Voting")
local Rng = require("../src/shared/Logic/Rng")
local MapConfig = require("../src/shared/Config/MapConfig")
local RoundConfig = require("../src/shared/Config/RoundConfig")

return function(t)
	local ids = {}
	for _, map in MapConfig do
		table.insert(ids, map.Id)
	end

	t.test("existem 5 mapas com ids únicos", function()
		t.equal(#ids, 5)
		local seen = {}
		for _, id in ids do
			t.truthy(not seen[id])
			seen[id] = true
		end
	end)

	t.test("votação mostra 3 opções diferentes, sem o mapa atual", function()
		for seed = 1, 200 do
			local options = Voting.pickOptions(ids, RoundConfig.VoteOptions, ids[1], Rng.new(seed))
			t.equal(#options, 3)
			local seen = {}
			for _, id in options do
				t.truthy(id ~= ids[1])
				t.truthy(not seen[id])
				seen[id] = true
			end
		end
	end)

	t.test("vence a opção mais votada", function()
		local options = { "A", "B", "C" }
		local votes = { p1 = "B", p2 = "B", p3 = "C" }
		t.equal(Voting.winner(options, votes, Rng.new(1)), "B")
	end)

	t.test("voto em mapa que não é opção é ignorado", function()
		local options = { "A", "B", "C" }
		local votes = { p1 = "Z", p2 = "Z", p3 = "C" }
		t.equal(Voting.winner(options, votes, Rng.new(1)), "C")
	end)

	t.test("sem votos: escolhe uma das opções", function()
		local options = { "A", "B", "C" }
		local winner = Voting.winner(options, {}, Rng.new(7))
		t.truthy(table.find(options, winner) ~= nil)
	end)

	t.test("empate: vencedor é um dos empatados", function()
		local options = { "A", "B", "C" }
		for seed = 1, 50 do
			local winner = Voting.winner(options, { p1 = "A", p2 = "C" }, Rng.new(seed))
			t.truthy(winner == "A" or winner == "C")
		end
	end)

	t.test("contagem de votos", function()
		local counts = Voting.counts({ "A", "B" }, { p1 = "A", p2 = "A", p3 = "B", p4 = "X" })
		t.equal(counts.A, 2)
		t.equal(counts.B, 1)
	end)
end
