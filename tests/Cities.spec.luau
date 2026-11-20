-- As três cidades montadas de verdade (CityGen + CityTerrain + modelos), conferindo as 9 verificações do mapa
-- que dá para medir nos dados:
--   OVERLAPS: nenhuma peça entra em outra (chão, construções, decoração e barreiras, todas juntas);
--   FLOATING/NO FOOTING: toda construção apoiada no chão da célula mais alta que ocupa;
--   UNREACHABLE/NO WAY OUT: sem pulo na run, todo chão é degrau que dá para subir andando; cada zona tem
--     pontos de nascer na rua e encosta na zona seguinte;
--   SHOULDN'T REACH: paredes invisíveis em toda a costa (ninguém entra no mar), mais altas que o maior jogador;
local Templates = require("../src/shared/Buildings/Templates")
local MapConfig = require("../src/shared/Config/MapConfig")
local CityPlans = require("../src/shared/Config/CityPlans")
local CityConfig = require("../src/shared/Config/CityConfig")
local DistrictConfig = require("../src/shared/Config/DistrictConfig")
local DifficultyConfig = require("../src/shared/Config/DifficultyConfig")
local GrowthConfig = require("../src/shared/Config/GrowthConfig")
local MovementConfig = require("../src/shared/Config/MovementConfig")
local CityGen = require("../src/shared/Logic/CityGen")
local CityTerrain = require("../src/shared/Logic/CityTerrain")
local CityBoxes = require("../src/shared/Logic/CityBoxes")
local Rng = require("../src/shared/Logic/Rng")

local TOL = 0.001
local HASH = 24 -- tamanho da célula do índice espacial (studs)

local function slabBox(s)
	return {
		Min = { s.Pos[1] - s.Size[1] / 2, s.Pos[2] - s.Size[2] / 2, s.Pos[3] - s.Size[3] / 2 },
		Max = { s.Pos[1] + s.Size[1] / 2, s.Pos[2] + s.Size[2] / 2, s.Pos[3] + s.Size[3] / 2 },
		Role = s.Name,
	}
end

-- Procura pares que se interpenetram com um índice espacial em X/Z.
local function findOverlaps(boxes, limit)
	local buckets = {}
	local problems = {}
	for index, b in boxes do
		local big = (b.Max[1] - b.Min[1]) > HASH * 20 or (b.Max[3] - b.Min[3]) > HASH * 20
		if big then
			-- peças enormes (base, mar, paredes): confere contra todas no fim
			continue
		end
		for gx = math.floor(b.Min[1] / HASH), math.floor(b.Max[1] / HASH) do
			for gz = math.floor(b.Min[3] / HASH), math.floor(b.Max[3] / HASH) do
				local key = gx * 100000 + gz
				local bucket = buckets[key]
				if bucket == nil then
					bucket = {}
					buckets[key] = bucket
				end
				for _, other in bucket do
					if CityBoxes.overlaps(b, boxes[other], TOL) then
						table.insert(problems, `{b.Owner}:{b.Role} x {boxes[other].Owner}:{boxes[other].Role}`)
						if #problems >= limit then
							return problems
						end
					end
				end
				table.insert(bucket, index)
			end
		end
	end
	for index, b in boxes do
		local big = (b.Max[1] - b.Min[1]) > HASH * 20 or (b.Max[3] - b.Min[3]) > HASH * 20
		if big then
			for other, c in boxes do
				if other ~= index and CityBoxes.overlaps(b, c, TOL) then
					table.insert(problems, `{b.Owner}:{b.Role} x {c.Owner}:{c.Role}`)
					if #problems >= limit then
						return problems
					end
				end
			end
		end
	end
	return problems
end

return function(t)
	for _, map in MapConfig do
		for _, difficulty in DifficultyConfig do
			local plan = CityPlans[map.Id]
			local layout = CityGen.generate(
				plan,
				DistrictConfig[map.Style],
				Templates,
				Rng.new(map.Seed),
				CityConfig,
				difficulty.MapScale
			)
			local terrain = CityTerrain.generate(layout.Grid, map.Biome, Rng.new(map.Seed + 77), CityConfig, Templates)
			local name = `{map.Id} {difficulty.Name}`

			t.test(`{name}: planta sem problemas (marcos cabem, zonas limitam o tamanho)`, function()
				if #layout.Problems > 0 then
					error(table.concat(layout.Problems, "; "))
				end
			end)

			t.test(`{name}: geração é determinística`, function()
				local again = CityGen.generate(
					plan,
					DistrictConfig[map.Style],
					Templates,
					Rng.new(map.Seed),
					CityConfig,
					difficulty.MapScale
				)
				t.equal(#again.Placements, #layout.Placements)
				t.equal(again.Placements[#again.Placements].Template, layout.Placements[#layout.Placements].Template)
			end)

			t.test(`{name}: nenhuma peça dentro de outra (cidade montada inteira)`, function()
				local boxes = {}
				for _, s in terrain.Slabs do
					local b = slabBox(s)
					b.Owner = "chão"
					table.insert(boxes, b)
				end
				for _, p in layout.Placements do
					for _, b in CityBoxes.place(Templates[p.Template].Boxes, p.X, p.Y, p.Z, p.Rotation) do
						b.Owner = p.Template
						table.insert(boxes, b)
					end
				end
				for _, d in terrain.Decor do
					for _, b in CityBoxes.place(Templates[d.Template].Boxes, d.X, d.Y, d.Z, d.Rotation) do
						b.Owner = "decor " .. d.Template
						table.insert(boxes, b)
					end
				end
				for _, barrier in layout.Barriers do
					local b = slabBox({ Pos = barrier.Pos, Size = barrier.Size, Name = "Barrier" })
					b.Owner = "barreira"
					table.insert(boxes, b)
				end
				for _, wall in layout.Walls do
					local b = slabBox({ Pos = wall.Pos, Size = wall.Size, Name = "Wall" })
					b.Owner = "costa"
					table.insert(boxes, b)
				end
				local problems = findOverlaps(boxes, 10)
				if #problems > 0 then
					error(`{#problems}+ sobreposições: {table.concat(problems, "; ")}`)
				end
			end)

			t.test(`{name}: toda construção apoiada no chão (nada flutuando, nada afundado)`, function()
				local grid = layout.Grid
				for _, p in layout.Placements do
					local r = p.Cells
					local top = 0
					for x = r[1], r[3] - 1 do
						for z = r[2], r[4] - 1 do
							top = math.max(top, grid.Height[z * grid.Width + x + 1])
						end
					end
					t.near(p.Y, top)
					-- o modelo começa no chão (o bloco mais baixo encosta em Y = 0 do modelo)
					local lowest = math.huge
					for _, b in Templates[p.Template].Boxes do
						lowest = math.min(lowest, b.Pos[2] - b.Size[2] / 2)
					end
					t.near(lowest, 0)
				end
			end)

			t.test(
				`{name}: sem pulo dá para andar por tudo (degraus menores que {MovementConfig.MaxStepHeight})`,
				function()
					local grid = layout.Grid
					local function check(i: number, j: number)
						if grid.Kind[i] ~= "Sea" and grid.Kind[j] ~= "Sea" then
							t.truthy(math.abs(grid.Height[i] - grid.Height[j]) < MovementConfig.MaxStepHeight)
						end
					end
					for z = 0, grid.Depth - 1 do
						for x = 0, grid.Width - 2 do
							check(z * grid.Width + x + 1, z * grid.Width + x + 2)
						end
					end
					for z = 0, grid.Depth - 2 do
						for x = 0, grid.Width - 1 do
							check(z * grid.Width + x + 1, (z + 1) * grid.Width + x + 1)
						end
					end
				end
			)

			t.test(`{name}: cada zona tem lugar para nascer na rua e encosta na próxima`, function()
				for zone = 1, #plan.Zones do
					t.truthy(#layout.Spawns[zone] > 0)
				end
				for zone = 2, #plan.Zones do
					local touching = false
					for _, b in layout.Barriers do
						if b.Zone == zone then
							touching = true
						end
					end
					t.truthy(touching)
				end
			end)

			t.test(`{name}: nenhuma faixa da rua embaixo de uma barreira (não pisca)`, function()
				for _, sl in terrain.Slabs do
					if sl.Name == "Line" then
						local box = slabBox(sl)
						for _, b in layout.Barriers do
							local bb = slabBox({ Pos = b.Pos, Size = b.Size, Name = "Barrier" })
							local touchX = box.Min[1] < bb.Max[1] and box.Max[1] > bb.Min[1]
							local touchZ = box.Min[3] < bb.Max[3] and box.Max[3] > bb.Min[3]
							t.falsy(touchX and touchZ)
						end
					end
				end
			end)

			t.test(`{name}: a placa de cada área fica dentro da própria área`, function()
				local anchors = CityGen.zoneAnchors(layout, CityConfig.CellSize)
				t.equal(#anchors, #plan.Zones)
				for zone, a in anchors do
					t.equal(CityGen.zoneAt(layout, CityConfig.CellSize, a[1], a[3]), zone)
				end
			end)

			t.test(
				`{name}: nenhuma peça passa de 2048 studs (limite do Roblox) e o mar vai até o horizonte`,
				function()
					local far = 0
					for _, s in terrain.Slabs do
						t.truthy(s.Size[1] <= 2048 and s.Size[2] <= 2048 and s.Size[3] <= 2048)
						if s.Name == "Sea" then
							far = math.max(far, math.abs(s.Pos[1]) + s.Size[1] / 2)
						end
					end
					t.truthy(far >= terrain.Half[1] + CityConfig.SeaSize - 1)
				end
			)

			t.test(`{name}: a terra nunca encosta na borda da grade (mar em volta)`, function()
				local grid = layout.Grid
				for x = 0, grid.Width - 1 do
					t.equal(grid.Kind[x + 1], "Sea")
					t.equal(grid.Kind[(grid.Depth - 1) * grid.Width + x + 1], "Sea")
				end
				for z = 0, grid.Depth - 1 do
					t.equal(grid.Kind[z * grid.Width + 1], "Sea")
					t.equal(grid.Kind[z * grid.Width + grid.Width], "Sea")
				end
			end)

			t.test(
				`{name}: paredes invisíveis em toda a costa, mais altas que o maior jogador (SHOULDN'T REACH)`,
				function()
					local grid = layout.Grid
					local size = CityConfig.CellSize
					-- índice das paredes por célula do mundo
					local buckets = {}
					local function bucketKey(x, z)
						return math.floor(x / HASH) * 100000 + math.floor(z / HASH)
					end
					for _, wall in layout.Walls do
						-- VALOR CALCULADO: corpo ~5 studs por escala na escala máxima
						t.truthy(wall.Size[2] > 5 * GrowthConfig.MaxScale)
						local x0, x1 = wall.Pos[1] - wall.Size[1] / 2, wall.Pos[1] + wall.Size[1] / 2
						local z0, z1 = wall.Pos[3] - wall.Size[3] / 2, wall.Pos[3] + wall.Size[3] / 2
						for gx = math.floor(x0 / HASH), math.floor(x1 / HASH) do
							for gz = math.floor(z0 / HASH), math.floor(z1 / HASH) do
								local k = gx * 100000 + gz
								buckets[k] = buckets[k] or {}
								table.insert(buckets[k], { x0, z0, x1, z1 })
							end
						end
					end
					local function covered(px, pz)
						for _, r in buckets[bucketKey(px, pz)] or {} do
							if px >= r[1] - TOL and px <= r[3] + TOL and pz >= r[2] - TOL and pz <= r[4] + TOL then
								return true
							end
						end
						return false
					end
					local missing = 0
					for z = 0, grid.Depth - 1 do
						for x = 0, grid.Width - 1 do
							local i = z * grid.Width + x + 1
							if grid.Kind[i] ~= "Sea" then
								for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
									local j = (z + d[2]) * grid.Width + (x + d[1]) + 1
									if grid.Kind[j] == "Sea" then
										-- ponto no meio da borda, um pouco para o lado do mar
										local wx, wz =
											CityGen.cellToWorld(grid, size, x + 0.5 + d[1] * 0.5, z + 0.5 + d[2] * 0.5)
										if not covered(wx + d[1] * 0.1, wz + d[2] * 0.1) then
											missing += 1
										end
									end
								end
							end
						end
					end
					t.equal(missing, 0)
				end
			)
		end
	end
end
