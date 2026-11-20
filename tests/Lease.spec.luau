-- Trava de sessão do save: um servidor por vez; quem perdeu a trava não grava.
local Lease = require("../src/shared/Logic/Lease")

return function(t)
	t.test("save sem trava pode ser carregado", function()
		t.truthy(Lease.canClaim(nil, "a", 100))
		t.truthy(Lease.canClaim("lixo", "a", 100))
	end)

	t.test("trava válida de outro servidor bloqueia; vencida libera", function()
		local s = Lease.new("b", "job", 100, 90)
		t.equal(Lease.canClaim(s, "a", 150), false)
		t.truthy(Lease.canClaim(s, "a", 190))
		t.truthy(Lease.canClaim(s, "b", 150)) -- o próprio dono
	end)

	t.test("só grava quem tem o token da trava", function()
		local s = Lease.new("a", "job", 100, 90)
		t.truthy(Lease.owns(s, "a"))
		t.equal(Lease.owns(s, "b"), false)
		t.equal(Lease.owns(nil, "a"), false) -- trava liberada/sumiu: não sobrescreve
	end)
end
