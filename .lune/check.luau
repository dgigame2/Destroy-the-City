-- Pipeline obrigatório do goat: build, testes, linter e formatter.
-- Uso: lune run check        (só verifica)
--      lune run check fix    (formata os arquivos antes de verificar)

local process = require("@lune/process")

local fix = process.args[1] == "fix"

local steps = {
	{ "Rojo build", "rojo", { "build", "default.project.json", "-o", "build.rbxl" } },
	{ "Testes", "lune", { "run", "test" } },
	{ "Linter (Selene)", "selene", { "src", "tests", ".lune" } },
	{
		"Formatter (StyLua)",
		"stylua",
		if fix then { "src", "tests", ".lune" } else { "--check", "src", "tests", ".lune" },
	},
}

for index, step in steps do
	local label, command, args = step[1], step[2], step[3]
	print(`\n[{index}/{#steps}] {label}`)
	local result = process.exec(command, args, { stdio = "inherit" })
	if not result.ok then
		print(`\nFALHOU em: {label}`)
		process.exit(1)
	end
end

print("\nPipeline completo: tudo OK")
