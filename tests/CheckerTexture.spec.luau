-- Xadrez do chão como textura (CityConfig.CheckerTexture): o chão novo, com bem menos peças, mostra
-- EXATAMENTE as mesmas cores do xadrez antigo (1 peça por quadrado) em cada ponto da cidade.
local CityGen = require("../src/shared/Logic/CityGen")
local CityTerrain = require("../src/shared/Logic/CityTerrain")
local Rng = require("../src/shared/Logic/Rng")
local Templates = require("../src/shared/Buildings/Templates")
local CityConfig = require("../src/shared/Config/CityConfig")
local CityPlans = require("../src/shared/Config/CityPlans")
local DistrictConfig = require("../src/shared/Config/DistrictConfig")
local MapConfig = require("../src/shared/Config/MapConfig")

local function withTexture(overrides)
	local tex = table.clone(CityConfig.CheckerTexture)
	for k, v in overrides do
		tex[k] = v
	end
	return setmetatable({ CheckerTexture = tex }, { __index = CityConfig })
end

local function top(s)
	return s.Pos[2] + s.Size[2] / 2
end

local function contains(s, x, z)
	-- estritamente dentro (um ponto na emenda entre duas placas é das duas)
	return math.abs(x - s.Pos[1]) < s.Size[1] / 2 - 1e-6 and math.abs(z - s.Pos[3]) < s.Size[3] / 2 - 1e-6
end

-- Confere pontos no meio de cada quadrado antigo: a placa nova que cobre o ponto (mesmo nome e topo)
-- mostra a mesma cor (diferença <= 1.5 por canal, arredondamento da tinta).
local function compare(map, cfgNew, step)
	local layout =
		CityGen.generate(CityPlans[map.Id], DistrictConfig[map.Style], Templates, Rng.new(map.Seed), CityConfig, 1)
	local old = CityTerrain.generate(
		layout.Grid,
		map.Biome,
		Rng.new(map.Seed + 77),
		withTexture({ Enabled = false }),
		Templates
	).Slabs
	local new = CityTerrain.generate(layout.Grid, map.Biome, Rng.new(map.Seed + 77), cfgNew, Templates).Slabs
	local byName = {}
	for _, s in new do
		byName[s.Name] = byName[s.Name] or {}
		table.insert(byName[s.Name], s)
	end
	local checked = 0
	for i = 1, #old, step do
		local o = old[i]
		-- pontos perto dos cantos e no meio do quadrado antigo (frações que não caem em linha de célula)
		for _, f in { { 0.47, 0.53 }, { 0.13, 0.11 }, { 0.89, 0.91 }, { 0.11, 0.87 } } do
			local x = o.Pos[1] - o.Size[1] / 2 + o.Size[1] * f[1]
			local z = o.Pos[3] - o.Size[3] / 2 + o.Size[3] * f[2]
			local found = nil
			for _, s in byName[o.Name] or {} do
				if math.abs(top(s) - top(o)) < 1e-3 and contains(s, x, z) then
					found = s
					break
				end
			end
			if found == nil then
				error(`{o.Name} em ({x}, {z}) sem placa nova`)
			end
			local c = CityTerrain.checkerAt(found, x, z, cfgNew)
			for k = 1, 3 do
				if math.abs(c[k] - o.Color[k]) > 1.5 then
					error(
						`{o.Name} em ({x}, {z}): cor {c[1]},{c[2]},{c[3]} em vez de {o.Color[1]},{o.Color[2]},{o.Color[3]}`
					)
				end
			end
			checked += 1
		end
	end
	return #old, #new, checked
end

return function(t)
	t.test("tinta: A coberto pela tinta com a opacidade dá B", function()
		local a, b = { 122, 204, 82 }, { 110, 194, 74 }
		local tint = CityTerrain.checkerTint(a, b, 0.4)
		for k = 1, 3 do
			t.truthy(math.abs(a[k] * 0.6 + tint[k] * 0.4 - b[k]) <= 0.5)
		end
	end)

	for _, map in MapConfig do
		if CityPlans[map.Id] then
			t.test(`{map.Id}: xadrez em textura = mesmas cores e bem menos peças de chão`, function()
				local before, after = compare(map, CityConfig, 3)
				t.truthy(after < before * 0.7, `{before} -> {after}`)
			end)
		end
	end

	t.test("xadrez em textura: cores certas em qualquer orientação dos eixos (FlipU/FlipV/SwapUV)", function()
		local map = MapConfig[1]
		for _, flipU in { false, true } do
			for _, flipV in { false, true } do
				for _, swap in { false, true } do
					compare(map, withTexture({ FlipU = flipU, FlipV = flipV, SwapUV = swap }), 17)
				end
			end
		end
	end)

	t.test("tinta dentro de 0..255 em todos os biomas (sem cor cortada)", function()
		local a = CityConfig.CheckerTexture.Alpha
		for _, map in MapConfig do
			for _, key in { "Ground", "Wild", "Road", "Sand", "Plaza", "Asphalt", "Runway" } do
				local list = map.Biome[key]
				if type(list) == "table" and type(list[1]) == "table" then
					for k = 1, 3 do
						local v = list[1][k] + (list[2][k] - list[1][k]) / a
						if v < -0.5 or v > 255.5 then
							error(`{map.Id} {key}: tinta {v} fora de 0..255`)
						end
					end
				end
			end
		end
	end)
end
