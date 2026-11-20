-- Roda todos os arquivos tests/*.spec.luau fora do Roblox Studio.
-- Uso: lune run test

local fs = require("@lune/fs")
local process = require("@lune/process")

local EPSILON = 1e-6

local passed, failed = 0, 0

local function makeContext()
	local t = {}

	function t.test(name: string, fn: () -> ())
		local ok, err = pcall(fn)
		if ok then
			passed += 1
			print(`  ok    {name}`)
		else
			failed += 1
			print(`  FALHA {name}\n        {err}`)
		end
	end

	function t.equal(actual, expected)
		if actual ~= expected then
			error(`esperado {expected}, obtido {actual}`, 2)
		end
	end

	function t.near(actual: number, expected: number)
		if math.abs(actual - expected) > EPSILON then
			error(`esperado ~{expected}, obtido {actual}`, 2)
		end
	end

	function t.truthy(value)
		if not value then
			error("condição falsa", 2)
		end
	end

	function t.falsy(value)
		if value then
			error("condição deveria ser falsa", 2)
		end
	end

	function t.throws(fn: () -> ())
		if pcall(fn) then
			error("deveria ter dado erro", 2)
		end
	end

	return t
end

local files = {}
for _, name in fs.readDir("tests") do
	if string.match(name, "%.spec%.luau$") then
		table.insert(files, name)
	end
end
table.sort(files)

for _, name in files do
	print(name)
	local suite = require(`../tests/{string.gsub(name, "%.luau$", "")}`)
	suite(makeContext())
end

print(`\n{passed} passaram, {failed} falharam`)
process.exit(if failed == 0 then 0 else 1)
