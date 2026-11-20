-- Fundação da partida nova: estado da cidade em dados, grade espacial, limite de frequência e protocolo.
local CityState = require("../src/shared/Logic/CityState")
local SpatialGrid = require("../src/shared/Logic/SpatialGrid")
local RateLimit = require("../src/shared/Logic/RateLimit")
local Protocol = require("../src/shared/Logic/Protocol")
local MatchConfig = require("../src/shared/Config/MatchConfig")

local L = MatchConfig.HpLevels

local function city(): CityState.State
	return CityState.new({
		{ MaxHp = 100, Value = 10 }, -- casa
		{ MaxHp = 100, Value = 10 },
		{ MaxHp = 400, Value = 60 }, -- prédio comercial vale mais
		{ MaxHp = 50, Value = 20 },
	})
end

return function(t)
	t.test("cidade: destruída uma vez só, dano somado nunca passa da vida", function()
		local s = city()
		local d1, k1 = CityState.hit(s, 1, 70)
		local d2, k2 = CityState.hit(s, 1, 70) -- 2º jogador no mesmo frame
		local d3, k3 = CityState.hit(s, 1, 70)
		t.equal(d1, 70)
		t.falsy(k1)
		t.equal(d2, 30)
		t.truthy(k2)
		t.equal(d3, 0)
		t.falsy(k3)
		t.equal(s.DestroyedCount, 1)
	end)

	t.test("cidade: progresso pelo VALOR, não pela contagem", function()
		local s = city()
		CityState.hit(s, 3, 1000)
		t.near(CityState.progress(s), 60 / 100)
		CityState.hit(s, 1, 1000)
		t.near(CityState.progress(s), 70 / 100)
	end)

	t.test("cidade: entradas falsas não fazem nada", function()
		local s = city()
		for _, bad in { { 0, 10 }, { 5, 10 }, { 1.5, 10 }, { 1, -5 }, { 1, 0 / 0 }, { 1, math.huge } } do
			local dealt, killed = CityState.hit(s, bad[1], bad[2])
			t.equal(dealt, 0)
			t.falsy(killed)
		end
		t.equal(s.DestroyedCount, 0)
		t.equal(next(s.Dirty), nil)
	end)

	t.test("marcos 25/50/75/100: cada um sai uma vez, vários de uma vez quando pula", function()
		local s = city()
		local marks = MatchConfig.Milestones
		t.equal(#CityState.newMilestones(s, marks), 0)
		CityState.hit(s, 3, 1000) -- 60%
		local got = CityState.newMilestones(s, marks)
		t.equal(#got, 2)
		t.equal(got[1], 1)
		t.equal(got[2], 2)
		t.equal(#CityState.newMilestones(s, marks), 0) -- repetido não paga
		CityState.hit(s, 1, 1000)
		CityState.hit(s, 2, 1000)
		CityState.hit(s, 4, 1000)
		got = CityState.newMilestones(s, marks)
		t.equal(#got, 2)
		t.equal(got[2], 4)
		t.near(CityState.progress(s), 1)
	end)

	t.test("vida em 1 byte: viva nunca vira 0, destruída é 0", function()
		local s = city()
		t.equal(CityState.hpByte(s, 3, L), L)
		CityState.hit(s, 3, 399.99)
		t.equal(CityState.hpByte(s, 3, L), 1)
		CityState.hit(s, 3, 1)
		t.equal(CityState.hpByte(s, 3, L), 0)
	end)

	t.test("dirty: lista ordenada e limpa depois de tirar", function()
		local s = city()
		CityState.hit(s, 4, 10)
		CityState.hit(s, 2, 10)
		CityState.hit(s, 4, 10)
		local ids = CityState.takeDirty(s)
		t.equal(#ids, 2)
		t.equal(ids[1], 2)
		t.equal(ids[2], 4)
		t.equal(#CityState.takeDirty(s), 0)
	end)

	t.test("grade: acha só quem cruza o círculo, uma vez cada, o mais perto primeiro", function()
		local g = SpatialGrid.new(MatchConfig.GridCell)
		SpatialGrid.insert(g, 1, 0, 0, 10, 10)
		SpatialGrid.insert(g, 2, 100, 100, 180, 140) -- grande: várias células
		SpatialGrid.insert(g, 3, -50, -50, -40, -40)
		local near = SpatialGrid.queryCircle(g, 5, 5, 3)
		t.equal(#near, 1)
		t.equal(near[1], 1)
		local big = SpatialGrid.queryCircle(g, 140, 120, 60)
		t.equal(#big, 1)
		local all = SpatialGrid.queryCircle(g, 0, 0, 400)
		t.equal(#all, 3)
		t.equal(all[1], 1)
		t.equal(#SpatialGrid.queryCircle(g, 0, 0, 400, 2), 2)
		SpatialGrid.remove(g, 1)
		t.equal(#SpatialGrid.queryCircle(g, 5, 5, 3), 0)
		t.equal(#SpatialGrid.queryCircle(g, 5, 5, 0 / 0), 0)
	end)

	t.test("grade: canto da caixa fora do círculo não conta", function()
		local g = SpatialGrid.new(32)
		SpatialGrid.insert(g, 1, 10, 10, 20, 20)
		t.equal(#SpatialGrid.queryCircle(g, 0, 0, 14), 0) -- distância até o canto = 14,14
		t.equal(#SpatialGrid.queryCircle(g, 0, 0, 14.2), 1)
	end)

	t.test("limite de frequência: rajada até Burst, depois só na velocidade Rate", function()
		local cfg = MatchConfig.Cast
		local b = RateLimit.new(cfg.Rate, cfg.Burst, 0)
		local ok = 0
		for _ = 1, 100 do
			if RateLimit.take(b, 0) then
				ok += 1
			end
		end
		t.equal(ok, cfg.Burst)
		ok = 0
		for i = 1, 100 do
			if RateLimit.take(b, i / 100) then -- 1 segundo de spam
				ok += 1
			end
		end
		t.truthy(ok <= cfg.Rate + 1)
		t.falsy(RateLimit.take(b, -50)) -- relógio voltando não dá ficha
	end)

	t.test("protocolo: delta vai e volta igual e é pequeno", function()
		local s = city()
		CityState.hit(s, 3, 100)
		CityState.hit(s, 1, 1000)
		local ids = CityState.takeDirty(s)
		local b = Protocol.encodeDelta(42, s, ids, L)
		t.equal(buffer.len(b), 7 + 2 * 3)
		local d = Protocol.decodeDelta(b) :: Protocol.Delta
		t.equal(d.Seq, 42)
		t.equal(d.Entries[1].Id, 1)
		t.equal(d.Entries[1].Hp, 0)
		t.equal(d.Entries[2].Hp, CityState.hpByte(s, 3, L))
		-- espelho do cliente chega ao mesmo estado lógico
		local mirror = city()
		for _, e in d.Entries do
			CityState.apply(mirror, e.Id, e.Hp, L)
		end
		t.truthy(mirror.Dead[1])
		t.near(CityState.progress(mirror), CityState.progress(s))
	end)

	t.test("protocolo: snapshot para quem entra no meio", function()
		local s = CityState.new(table.create(2442, { MaxHp = 100, Value = 1 }))
		for id = 1, 2442, 3 do
			CityState.hit(s, id, 1000)
		end
		CityState.hit(s, 2, 30)
		local b = Protocol.encodeSnapshot(7, s, L)
		t.truthy(buffer.len(b) < 400) -- 2442 construções em menos de 400 bytes
		local snap = Protocol.decodeSnapshot(b) :: Protocol.Snapshot
		t.equal(snap.Count, 2442)
		for id = 1, 2442 do
			t.equal(snap.Dead[id], s.Dead[id])
		end
		t.equal(#snap.Damaged, 1)
		t.equal(snap.Damaged[1].Id, 2)
	end)

	t.test("protocolo: mensagem mal formada vira nil", function()
		t.equal(Protocol.decodeDelta("oi"), nil)
		t.equal(Protocol.decodeDelta(buffer.create(3)), nil)
		local b = Protocol.encodeDelta(1, city(), { 1 }, L)
		local cut = buffer.create(buffer.len(b) - 1)
		buffer.copy(cut, 0, b, 0, buffer.len(cut))
		t.equal(Protocol.decodeDelta(cut), nil)
		t.equal(Protocol.decodeSnapshot(b), nil) -- tipo errado
		local mirror = city()
		t.falsy(CityState.apply(mirror, 999, 0, L)) -- id que não existe
	end)
end
