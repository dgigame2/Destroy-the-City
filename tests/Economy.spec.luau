-- Rodar com: lune run tests/Economy.spec
local Economy = require("../src/shared/Logic/Economy")

local passed, failed = 0, 0

local function check(name: string, condition: boolean)
	if condition then
		passed += 1
		print("  OK   " .. name)
	else
		failed += 1
		print("  FAIL " .. name)
	end
end

check("custo no nível 0 = custo base", Economy.getUpgradeCost(10, 1.15, 0) == 10)
check("custo no nível 1 arredonda pra baixo", Economy.getUpgradeCost(10, 1.15, 1) == 11)
check("custo sobe com o nível", Economy.getUpgradeCost(10, 1.15, 10) > Economy.getUpgradeCost(10, 1.15, 9))
check("nível negativo dá erro", not pcall(Economy.getUpgradeCost, 10, 1.15, -1))
check("consegue pagar com saldo exato", Economy.canAfford(10, 10))
check("não paga com saldo menor", not Economy.canAfford(9, 10))

print(`\n{passed} passaram, {failed} falharam`)
if failed > 0 then
	error("Testes falharam")
end
