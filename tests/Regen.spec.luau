-- Regeneração da cidade: construção destruída volta inteira, o progresso desconta e o cliente espelha a volta.
local CityState = require("../src/shared/Logic/CityState")
local Protocol = require("../src/shared/Logic/Protocol")
local MatchConfig = require("../src/shared/Config/MatchConfig")

local L = MatchConfig.HpLevels

local function city(): CityState.State
	return CityState.new({ { MaxHp = 100, Value = 10 }, { MaxHp = 400, Value = 60 } })
end

return function(t)
	t.test("revive: volta com vida cheia, desconta o progresso e pode cair de novo", function()
		local s = city()
		CityState.hit(s, 2, 1000)
		t.truthy(s.Dead[2])
		CityState.takeDirty(s)
		t.truthy(CityState.revive(s, 2))
		t.falsy(s.Dead[2])
		t.equal(s.Hp[2], 400)
		t.equal(s.DestroyedCount, 0)
		t.near(CityState.progress(s), 0)
		t.equal(CityState.takeDirty(s)[1], 2) -- sai no próximo lote para os clientes
		local _, killed = CityState.hit(s, 2, 1000)
		t.truthy(killed)
		t.equal(s.DestroyedCount, 1)
	end)

	t.test("revive: viva ou id inválido não muda nada", function()
		local s = city()
		t.falsy(CityState.revive(s, 1))
		t.falsy(CityState.revive(s, 99))
		t.equal(s.Hp[1], 100)
	end)

	t.test("espelho do cliente: o lote da volta reconstrói a construção", function()
		local s, mirror = city(), city()
		CityState.hit(s, 1, 1000)
		CityState.apply(mirror, 1, 0, L)
		CityState.takeDirty(s)
		CityState.revive(s, 1)
		local d = Protocol.decodeDelta(Protocol.encodeDelta(1, s, CityState.takeDirty(s), L)) :: Protocol.Delta
		local fell, revived = CityState.apply(mirror, d.Entries[1].Id, d.Entries[1].Hp, L)
		t.falsy(fell)
		t.truthy(revived)
		t.falsy(mirror.Dead[1])
		t.near(CityState.progress(mirror), CityState.progress(s))
	end)
end
