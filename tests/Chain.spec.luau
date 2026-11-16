-- Destruição em cadeia (Fase 4).
local Chain = require("../src/shared/Logic/Chain")
local ChainConfig = require("../src/shared/Config/ChainConfig")
local Templates = require("../src/shared/Buildings/Templates")

return function(t)
	local cfg = ChainConfig

	t.test("cadeia: todo explosivo existe nos modelos da cidade", function()
		for name in cfg.Explosive do
			if Templates[name] == nil then
				error(`explosivo "{name}" não existe`)
			end
		end
	end)

	t.test("cadeia: carro explode, prédio grande desaba, casa não faz nada", function()
		t.equal((Chain.reaction("Car", 2, 11, cfg) :: any).Kind, "Explosion")
		local collapse = Chain.reaction("OfficeTower", 6, 23, cfg) :: any
		t.equal(collapse.Kind, "Collapse")
		t.near(collapse.Radius, 23 / 2 + cfg.Collapse.RadiusPadding)
		t.equal(Chain.reaction("House", 3, 15, cfg), nil)
	end)

	t.test("cadeia: dano cheio no centro, cai até a borda, zero fora", function()
		local r = { Kind = "Explosion", Radius = 10, DamageFactor = 2 }
		t.near(Chain.damageAt(100, r, 0, cfg), 200)
		t.near(Chain.damageAt(100, r, 10, cfg), 200 * cfg.EdgeDamage)
		t.equal(Chain.damageAt(100, r, 10.5, cfg), 0)
	end)

	t.test("cadeia: limites de profundidade e de reações (nada de cadeia infinita)", function()
		t.truthy(Chain.canPropagate(1, 0, cfg))
		t.falsy(Chain.canPropagate(cfg.MaxDepth + 1, 0, cfg))
		t.falsy(Chain.canPropagate(1, cfg.MaxPerChain, cfg))
	end)

	t.test("cadeia: bônus cresce com a profundidade, com teto", function()
		t.near(Chain.bonus(0, cfg), 1)
		t.near(Chain.bonus(1, cfg), 1 + cfg.DepthBonus)
		t.near(Chain.bonus(99, cfg), 1 + cfg.MaxBonus)
	end)

	t.test("cadeia: aviso só ao cruzar um degrau, sem repetir", function()
		t.equal(Chain.label(2, cfg), nil)
		t.equal(Chain.label(3, cfg), "CHAIN x3")
		t.equal(Chain.label(20, cfg), "MEGA CHAIN x20!")
		t.truthy(Chain.crossed(2, 3, cfg))
		t.falsy(Chain.crossed(3, 4, cfg))
		t.truthy(Chain.crossed(7, 9, cfg))
	end)
end
