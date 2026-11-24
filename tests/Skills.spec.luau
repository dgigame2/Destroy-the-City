-- Skills (Q) dos tornados: uma por forma, zonas determinísticas, explosão que cresce com o destruído.
local Skills = require("../src/shared/Logic/Skills")
local skills = require("../src/shared/Config/SkillConfig")
local tcfg = require("../src/shared/Config/TornadoConfig")

local function find(name: string): any
	for _, s in skills do
		if s.Name == name then
			return s
		end
	end
	error("skill não existe: " .. name)
end

return function(t)
	t.test("uma skill por forma, todas com nome, cor, recarga e movimento válido", function()
		t.equal(#skills, #tcfg.Forms)
		for _, s in skills do
			t.truthy(type(s.Name) == "string" and #s.Color == 3 and s.Cooldown > 0)
			t.truthy(s.Move == "Line" or s.Move == "Self" or s.Move == "Fixed" or s.Move == "Orbit")
			t.truthy(Skills.duration(s) > 0)
			t.truthy(s.CityRate > 0)
		end
		local index, def = Skills.forForm(skills, 99)
		t.equal(index, #skills)
		t.equal(def, skills[#skills])
	end)

	t.test("Line anda na direção e para no fim do caminho", function()
		local s = find("Dust Dash")
		local z0 = Skills.zones(s, 0, 0, 0, 10, 0, 1, 0, 2)[1]
		t.near(z0.X, 10)
		local z1 = Skills.zones(s, 999, 0, 0, 10, 0, 1, 0, 2)[1]
		t.near(z1.X, 10 + s.Travel * 2)
		t.near(z1.Z, 0)
	end)

	t.test("Self segue o tornado; Fixed fica onde foi usada", function()
		local follow = Skills.zones(find("Vortex Slam"), 1, 50, 60, 0, 0, 1, 0, 2)[1]
		t.near(follow.X, 50)
		t.near(follow.Z, 60)
		local hole = find("Black Hole")
		local fixed = Skills.zones(hole, 1, 50, 60, 0, 0, 1, 0, 2)[1]
		t.near(fixed.X, hole.Ahead * 2)
	end)

	t.test("Orbit: Count zonas em volta, voltando ao centro no fim", function()
		local s = find("Twin Cyclones")
		local zones = Skills.zones(s, 0.5, 0, 0, 0, 0, 1, 0, 2)
		t.equal(#zones, s.Count)
		t.near(math.sqrt(zones[1].X ^ 2 + zones[1].Z ^ 2), s.Orbit * 2)
		local back = Skills.zones(s, Skills.duration(s), 0, 0, 0, 0, 1, 0, 2)
		t.near(math.sqrt(back[1].X ^ 2 + back[1].Z ^ 2), 0)
		t.near(Skills.burstAt(s, 7, 8, 0, 0, 1, 0, 2), 7)
	end)

	t.test("buraco negro cresce até Size * (1 + Grow)", function()
		local s = find("Black Hole")
		local start = Skills.zones(s, 0, 0, 0, 0, 0, 1, 0, 2)[1].R
		local finish = Skills.zones(s, Skills.duration(s), 0, 0, 0, 0, 1, 0, 2)[1].R
		t.near(start, s.Size * 2)
		t.near(finish, s.Size * 2 * (1 + s.Grow))
	end)

	t.test("explosão final cresce com o destruído, até o limite", function()
		local s = find("Vortex Slam")
		t.near(Skills.burstMult(s, 0), 1)
		t.near(Skills.burstMult(s, 10), 1 + 10 * s.Burst.PerItem)
		t.near(Skills.burstMult(s, 1e6), 1 + s.Burst.Cap * s.Burst.PerItem)
		t.equal(Skills.burstMult(find("Wind Burst"), 50), 0) -- sem explosão
	end)
end
