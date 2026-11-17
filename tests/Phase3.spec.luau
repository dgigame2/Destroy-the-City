-- Fase 3: tornado arrastando/arremessando, reações em cadeia (fogo, faísca, destroços), placar individual e
-- classes/upgrades de desastre.
local Chain = require("../src/shared/Logic/Chain")
local ChainConfig = require("../src/shared/Config/ChainConfig")
local Debris = require("../src/shared/Logic/Debris")
local DebrisConfig = require("../src/shared/Config/DebrisConfig")
local Disasters = require("../src/shared/Logic/Disasters")
local DisasterConfig = require("../src/shared/Config/DisasterConfig")
local RunStats = require("../src/shared/Logic/RunStats")
local StructureHealth = require("../src/shared/Logic/StructureHealth")
local StructureConfig = require("../src/shared/Config/StructureConfig")
local Templates = require("../src/shared/Buildings/Templates")
local TierConfig = require("../src/shared/Config/TierConfig")
local UpgradeConfig = require("../src/shared/Config/UpgradeConfig")
local ClassConfig = require("../src/shared/Config/ClassConfig")
local MovementConfig = require("../src/shared/Config/MovementConfig")

return function(t)
	local cfg = ChainConfig

	-- Reações --------------------------------------------------------------------
	t.test("cadeia: todo inflamável e todo condutor existem nos modelos da cidade", function()
		for name in cfg.Fire.Flammable do
			if Templates[name] == nil then
				error(`inflamável "{name}" não existe`)
			end
		end
		for name in StructureConfig.Conductors do
			if Templates[name] == nil then
				error(`condutor "{name}" não existe`)
			end
		end
	end)

	t.test("cadeia: casa pega fogo, poste solta faísca, carro explode e solta faísca", function()
		local house = Chain.reactions("House", 3, 15, cfg, StructureConfig.Conductors)
		t.equal(#house, 1)
		t.equal(house[1].Kind, "Fire")
		local lamp = Chain.reactions("Lamp", 1, 2, cfg, StructureConfig.Conductors)
		t.equal(#lamp, 1)
		t.equal(lamp[1].Kind, "Electric")
		local car = Chain.reactions("Car", 2, 11, cfg, StructureConfig.Conductors)
		t.equal(car[1].Kind, "Explosion")
		t.equal(car[2].Kind, "Electric")
		t.equal(#Chain.reactions("Snowman", 1, 3, cfg, StructureConfig.Conductors), 0)
	end)

	t.test("cadeia: no máximo MaxPerBuilding reações por construção", function()
		-- posto de gasolina: explode e pega fogo (2); nada passa do teto
		for name, template in Templates do
			if type(template) == "table" and template.Tier then
				local list = Chain.reactions(name, template.Tier, 20, cfg, StructureConfig.Conductors)
				t.truthy(#list <= cfg.MaxPerBuilding)
			end
		end
		local gas = Chain.reactions("GasStation", 4, 20, cfg, StructureConfig.Conductors)
		t.equal(gas[1].Kind, "Explosion")
		t.equal(gas[2].Kind, "Fire")
	end)

	t.test("fogo: inflamável leva o bônus; zero fora do raio", function()
		local plain = Chain.fireDamage(100, 0, false, cfg)
		t.near(plain, 100 * cfg.Fire.DamageFactor)
		t.near(Chain.fireDamage(100, 0, true, cfg), plain * cfg.Fire.FlammableBonus)
		t.equal(Chain.fireDamage(100, cfg.Fire.Radius + 0.1, true, cfg), 0)
	end)

	t.test("fogo e faísca: limites de celular/servidor", function()
		t.truthy(cfg.Fire.MaxActive > 0 and cfg.Fire.MaxActive <= 12)
		t.truthy(cfg.Fire.Ticks * cfg.Fire.TickDelay <= 4) -- um foco não queima para sempre
		t.truthy(cfg.Electric.Hops >= 1 and cfg.Electric.Hops <= 6)
		t.truthy(cfg.Electric.Decay < 1)
	end)

	t.test("faísca: pula para o vizinho e prefere condutores (sem repetir)", function()
		local nodes = {
			{ Id = 1, X = 5, Z = 0, Conductor = true },
			{ Id = 2, X = 22, Z = 0, Conductor = false }, -- 17 studs: passa de HopRange, só um condutor alcança
			{ Id = 3, X = 0, Z = 40, Conductor = false },
		}
		local e = cfg.Electric
		local chain =
			Disasters.lightningChain(nodes, 0, 0, e.HopRange, e.Hops - 1, e.HopRange, e.Decay, e.ConductorRange)
		t.equal(chain[1].Id, 1)
		t.equal(chain[2].Id, 2)
		t.near(chain[2].Strength, 1) -- saiu de condutor: não perde força
		local seen = {}
		for _, hop in chain do
			t.falsy(seen[hop.Id])
			seen[hop.Id] = true
		end
	end)

	-- Tornado / objetos voando ---------------------------------------------------
	t.test("tornado: só arranca leves e só com poder suficiente", function()
		local prop, small, house = TierConfig[1], TierConfig[2], TierConfig[3]
		t.truthy(Debris.lifts(prop.Name, prop.RequiredScale, 1, DebrisConfig))
		t.falsy(Debris.lifts(small.Name, small.RequiredScale, 1, DebrisConfig))
		t.truthy(Debris.lifts(small.Name, small.RequiredScale, small.RequiredScale, DebrisConfig))
		t.falsy(Debris.lifts(house.Name, house.RequiredScale, 99, DebrisConfig))
	end)

	t.test(
		"tornado: objeto longe é puxado para dentro, perto do centro é empurrado para o anel, sempre gira",
		function()
			local r = 5
			local vx, vy, vz = Debris.orbitVelocity(20, 0, 0, 0, r, DebrisConfig)
			t.truthy(vx < 0) -- longe à direita: vem para a esquerda (para o funil)
			t.truthy(vy > 0)
			t.truthy(math.abs(vz) > 0) -- gira
			local nx = Debris.orbitVelocity(0.5, 0, 0, 0, r, DebrisConfig)
			t.truthy(nx > 0) -- quase no centro: sai para o anel
			local cx, _, cz = Debris.orbitVelocity(0, 0, 0, 0, r, DebrisConfig) -- bem no centro: sem NaN
			t.truthy(cx == cx and cz == cz)
		end
	)

	t.test("tornado: arremesso sai para fora do funil", function()
		local vx, vy, vz = Debris.throwVelocity(3, 4, 0, 0, 50, 20)
		t.near(vx, 30)
		t.near(vz, 40)
		t.equal(vy, 20)
		t.truthy(Debris.thrown(0, DebrisConfig))
		t.falsy(Debris.thrown(0.999, DebrisConfig))
	end)

	t.test("tornado: arremessado volta ao chão antes de sumir (Lifetime)", function()
		-- MEDIDO: gravidade do jogo (MovementConfig.Gravity); CALCULADO: tempo de voo do pior caso
		local g = MovementConfig.Gravity
		local orbitRise = DebrisConfig.Lift.Rise * DebrisConfig.Lift.OrbitTime + 10 -- altura ao sair (+ objeto alto)
		local flight = Debris.flightTime(DebrisConfig.ThrowLift, orbitRise, g)
		t.truthy(DebrisConfig.Lift.OrbitTime + flight < DebrisConfig.Lifetime)
		local blastFlight = Debris.flightTime(DebrisConfig.Blast.Lift * 1.2, 30, g)
		t.truthy(blastFlight < DebrisConfig.Lifetime)
	end)

	t.test("objetos voando: teto de quantidade (celular/servidor)", function()
		t.truthy(Debris.canSpawn(0, DebrisConfig))
		t.falsy(Debris.canSpawn(DebrisConfig.MaxActive, DebrisConfig))
		t.equal(Debris.blastPieces(DebrisConfig.MaxActive, DebrisConfig), 0)
		t.equal(Debris.blastPieces(DebrisConfig.MaxActive - 1, DebrisConfig), 1)
		t.truthy(DebrisConfig.MaxActive <= 20)
	end)

	t.test("objetos voando: batida machuca mais no centro, nada fora do raio", function()
		local center = Debris.impactDamage(100, 0, DebrisConfig)
		t.near(center, 100 * DebrisConfig.ImpactDamage)
		t.near(Debris.impactDamage(100, DebrisConfig.ImpactRadius, DebrisConfig), center * DebrisConfig.ImpactEdge)
		t.equal(Debris.impactDamage(100, DebrisConfig.ImpactRadius + 0.1, DebrisConfig), 0)
		-- pedaços de explosão: somados, dão DamageFactor x HP da construção no centro
		local piece = Debris.blastPieceHp(1000, DebrisConfig)
		t.near(
			Debris.impactDamage(piece, 0, DebrisConfig) * DebrisConfig.Blast.Pieces,
			1000 * DebrisConfig.Blast.DamageFactor
		)
	end)

	-- Placar individual ----------------------------------------------------------
	t.test("placar: 4 jogadores na mesma construção somam no máximo a vida dela", function()
		local state = StructureHealth.new()
		local total = 0
		local kills = 0
		for _ = 1, 4 do
			local fell, dealt = StructureHealth.hitDealt(state, 7, 90, 200)
			total += dealt
			if fell then
				kills += 1
			end
		end
		t.near(total, 200)
		t.equal(kills, 1) -- só um golpe final (uma recompensa)
		local fell, dealt = StructureHealth.hitDealt(state, 7, 90, 200)
		t.falsy(fell)
		t.equal(dealt, 0)
	end)

	t.test("placar: cada jogador tem os próprios números", function()
		local a, b = RunStats.new(), RunStats.new()
		RunStats.addDamage(a, 120.4)
		RunStats.addDestroy(a, 25)
		RunStats.addChain(a)
		RunStats.addDamage(b, 0 / 0) -- NaN não entra
		RunStats.addDamage(b, -5)
		t.equal(RunStats.display(a, "Damage"), 120)
		t.equal(RunStats.display(a, "Destroyed"), 1)
		t.equal(RunStats.display(a, "Chains"), 1)
		t.equal(RunStats.display(a, "Score"), 25)
		t.equal(RunStats.display(b, "Damage"), 0)
		t.equal(RunStats.display(b, "Destroyed"), 0)
		t.equal(#RunStats.Columns, 4) -- o Roblox mostra até 4 colunas
		t.equal(RunStats.Columns[1], "Score")
	end)

	-- Classes e upgrades ---------------------------------------------------------
	t.test("upgrades: só Recharge, Reach, XP e Cash", function()
		local seen = {}
		for _, upgrade in UpgradeConfig do
			t.falsy(seen[upgrade.Id])
			seen[upgrade.Id] = true
		end
		t.equal(#UpgradeConfig, 4)
		for _, id in { "Cooldown", "Range", "Xp", "Coins" } do
			t.truthy(seen[id], id)
		end
	end)

	t.test("papéis: tornado = pequeno, meteoro = grande, raio = zap no que sobrou", function()
		local Tiers = require("../src/shared/Config/TierConfig")
		local cap, under = DisasterConfig.OverkillCap, StructureConfig.UnderPower
		local function hits(id, tierIndex)
			local tier = Tiers[tierIndex]
			-- poder igual ao exigido pelo tier
			local dmg = Disasters.hitDamage(DisasterConfig.ById[id], tier.RequiredScale, tier, 1, under, cap)
			return Disasters.structureHp(tier, StructureConfig.HpPerScale) / dmg
		end
		local tornado = DisasterConfig.ById.Tornado
		-- tornado: arrasta poste/banco/árvore/carro na hora
		t.truthy(Disasters.sweeps(tornado, Tiers[1].RequiredScale, Tiers[1]))
		t.truthy(Disasters.sweeps(tornado, Tiers[2].RequiredScale, Tiers[2]))
		t.falsy(Disasters.sweeps(tornado, 50, Tiers[3]))
		-- meteoro: 1 acerto num prédio do seu poder; tornado e raio quase não arranham
		t.truthy(hits("Meteor", 5) <= 1)
		t.truthy(hits("Tornado", 5) > 10)
		t.truthy(hits("Lightning", 5) > 3)
		-- raio: 1 zap mata poste e árvore do seu poder
		t.truthy(hits("Lightning", 1) <= 1)
		t.truthy(hits("Lightning", 2) <= 1)
	end)

	t.test("fogo: só meteoro e raio acendem; tornado derruba árvore sem incendiar", function()
		local function hasFire(cause)
			for _, r in Chain.reactions("Tree", 1, 4, cfg, StructureConfig.Conductors, cause) do
				if r.Kind == "Fire" then
					return true
				end
			end
			return false
		end
		t.truthy(hasFire("Meteor"))
		t.truthy(hasFire("Lightning"))
		t.falsy(hasFire("Tornado"))
	end)

	t.test("end game: vantagem contra prédio pequeno tem teto e raio cresce menos que o poder", function()
		local d = DisasterConfig.ById.Tornado
		local tier = { RequiredScale = 1 }
		local cap = DisasterConfig.OverkillCap
		local capped = Disasters.hitDamage(d, 26, tier, 1, 0, cap)
		t.near(capped, d.Damage * 26 * cap ^ d.TierExponent)
		t.truthy(capped < Disasters.hitDamage(d, 26, tier, 1, 0))
		-- CALCULADO: poder 26 -> raio 26^0.6 ~ 7x (antes 26x)
		t.truthy(Disasters.radius(d, 26, DisasterConfig) / d.Radius < 8)
	end)

	t.test("classes: ids antigos continuam (quem comprou não perde)", function()
		local seen = {}
		for _, class in ClassConfig do
			seen[class.Id] = true
		end
		for _, id in { "Glutton", "Sprinter", "Vacuum", "Tycoon", "Lucky", "Titan" } do
			t.truthy(seen[id], id)
		end
	end)

	t.test("bônus: mods juntam os multiplicadores e recarga divide o cooldown", function()
		local values = { Damage = 1.25, Magnet = 1.1, Range = 1.15, Cooldown = 1.3, Duration = 1.3, Chain = 1.5 }
		local m = Disasters.mods(function(stat)
			return values[stat] or 1
		end)
		t.near(m.Damage, 1.25)
		t.near(m.Size, 1.1)
		t.near(m.Range, 1.15)
		t.near(m.Chain, 1.5)
		local meteor = DisasterConfig.ById.Meteor
		t.near(Disasters.cooldown(meteor, m.Cooldown), meteor.Cooldown / 1.3)
		t.near(Disasters.cooldown(meteor), meteor.Cooldown)
	end)

	t.test("bônus: upgrade no máximo + melhor classe não deixa cooldown absurdo", function()
		-- CALCULADO: recarga máxima = 1 + upgrade máximo + classe Overcharge
		local upgrade, class = 0, 0
		for _, u in UpgradeConfig do
			if u.Id == "Cooldown" then
				upgrade = u.BonusPerLevel * u.MaxLevel
			end
		end
		for _, c in ClassConfig do
			class = math.max(class, c.Buffs.Cooldown or 0)
		end
		for _, d in DisasterConfig.List do
			t.truthy(Disasters.cooldown(d, 1 + upgrade + class) >= d.Cooldown * 0.5)
		end
	end)
end
