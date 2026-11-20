-- Regras do gerador planejado (Logic/Placement + Config/ModelCatalog), em toda cidade que tem Planner:
-- cada objeto no lugar da função dele, sem fileiras nem amontoados, portas livres e prédios com acesso.
local Templates = require("../src/shared/Buildings/Templates")
local MapConfig = require("../src/shared/Config/MapConfig")
local CityPlans = require("../src/shared/Config/CityPlans")
local CityConfig = require("../src/shared/Config/CityConfig")
local DistrictConfig = require("../src/shared/Config/DistrictConfig")
local ModelCatalog = require("../src/shared/Config/ModelCatalog")
local CityGen = require("../src/shared/Logic/CityGen")
local Placement = require("../src/shared/Logic/Placement")
local Rng = require("../src/shared/Logic/Rng")

return function(t)
	t.test("placement: índice acha vizinho do mesmo grupo dentro do raio e ignora outros grupos", function()
		local idx = Placement.newIndex(24)
		Placement.add(idx, "Bench", 10, 10)
		t.truthy(Placement.near(idx, "Bench", 30, 10, 24))
		t.falsy(Placement.near(idx, "Bench", 40, 10, 24))
		t.falsy(Placement.near(idx, "Lamp", 10, 10, 24))
		t.falsy(Placement.spaced(idx, ModelCatalog, "Bench", 20, 10))
		t.truthy(Placement.spaced(idx, ModelCatalog, "House", 20, 10)) -- casa não tem distância mínima
	end)

	t.test("placement: guarda-sol só na areia, hangar só no aeroporto", function()
		t.truthy(Placement.allowed(ModelCatalog, "Umbrella", "Sand", "Suburb"))
		t.falsy(Placement.allowed(ModelCatalog, "Umbrella", "Lot", "Market"))
		t.truthy(Placement.allowed(ModelCatalog, "Hangar", "Asphalt", "Airport"))
		t.falsy(Placement.allowed(ModelCatalog, "Hangar", "Asphalt", "Industrial"))
	end)

	t.test("placement: grupos com tamanho dentro do limite e itens fora do centro", function()
		for roll = 0, 0.99, 0.11 do
			local n = Placement.groupSize(2, 5, roll)
			t.truthy(n >= 2 and n <= 5)
			for k = 1, 5 do
				local dx, dz = Placement.groupOffset(k, 3, roll)
				t.truthy(math.abs(dx) <= 3 and math.abs(dz) <= 3)
				t.truthy(dx ~= 0 or dz ~= 0)
			end
		end
	end)

	t.test("catálogo: todo modelo listado existe", function()
		for name in ModelCatalog do
			t.truthy(Templates[name] ~= nil, name)
		end
	end)

	for _, map in MapConfig do
		local fill = DistrictConfig[map.Style]
		local planner = fill.Planner
		if planner == nil then
			continue
		end
		local layout = CityGen.generate(CityPlans[map.Id], fill, Templates, Rng.new(map.Seed), CityConfig, 1)
		local grid = layout.Grid
		local function at(x, z)
			if x < 0 or z < 0 or x >= grid.Width or z >= grid.Depth then
				return nil
			end
			return z * grid.Width + x + 1
		end
		local function groundOf(p)
			return grid.Kind[at(p.Cells[1], p.Cells[2])], grid.District[at(p.Cells[1], p.Cells[2])]
		end
		local function category(p)
			return Placement.category(ModelCatalog, p.Template)
		end

		t.test(
			`{map.Id}: cada objeto só no chão/bairro permitido (guarda-sol na areia, avião no aeroporto)`,
			function()
				for _, p in layout.Placements do
					local ground, district = groundOf(p)
					if not Placement.allowed(ModelCatalog, p.Template, ground, district) then
						error(`{p.Template} em {ground}/{district}`)
					end
				end
			end
		)

		t.test(`{map.Id}: carro só na rua, estacionamento, pátio ou entrada de casa`, function()
			for _, p in layout.Placements do
				if category(p) == "Vehicle" then
					local ground = groundOf(p)
					t.truthy(ground == "Asphalt" or ground == "Lot" or ground == "Road", `{p.Template} em {ground}`)
					if ground == "Road" then
						-- meio-fio: comprido ao longo da calçada (alinhado com a rua) e encostado nela
						local r = p.Cells
						local long = if (r[3] - r[1]) > (r[4] - r[2]) then "X" else "Z"
						local touches = false
						for x = r[1] - 1, r[3] do
							for z = r[2] - 1, r[4] do
								local i = at(x, z)
								if i and grid.Kind[i] == "Walk" then
									-- a calçada fica do lado comprido do carro
									local side = if long == "X"
										then (z == r[2] - 1 or z == r[4])
										else (x == r[1] - 1 or x == r[3])
									touches = touches or side
								end
							end
						end
						t.truthy(touches, `carro atravessado na rua em {r[1]},{r[2]}`)
					end
					if ground == "Lot" then
						-- encostado numa casa (entrada) e na calçada
						local besideHouse, byWalk = false, false
						local r = p.Cells
						for _, q in layout.Placements do
							if planner.Houses[q.Template] then
								local c = q.Cells
								if c[1] <= r[3] and c[3] >= r[1] and c[2] <= r[4] and c[4] >= r[2] then
									besideHouse = true
									break
								end
							end
						end
						for x = r[1] - 1, r[3] do
							for z = r[2] - 1, r[4] do
								local i = at(x, z)
								if i and grid.Kind[i] == "Walk" then
									byWalk = true
								end
							end
						end
						t.truthy(besideHouse and byWalk, `carro solto no gramado em {r[1]},{r[2]}`)
					end
				end
			end
		end)

		t.test(`{map.Id}: distância mínima entre objetos iguais (sem fileira de banco, vaso ou poste)`, function()
			local seen = {}
			for _, p in layout.Placements do
				local group, spacing = Placement.spacing(ModelCatalog, p.Template)
				-- peças de um kit ficam onde o kit desenha (um parquinho tem 2 bancos de propósito)
				if group and p.Kit == nil then
					for _, q in seen[group] or {} do
						local dx, dz = p.X - q.X, p.Z - q.Z
						if dx * dx + dz * dz < spacing * spacing - 1e-6 then
							error(`{p.Template} a {math.sqrt(dx * dx + dz * dz)} de outro (mín {spacing})`)
						end
					end
					seen[group] = seen[group] or {}
					table.insert(seen[group], p)
				end
			end
		end)

		t.test(`{map.Id}: nada em cima da calçada na frente das portas`, function()
			for _, p in layout.Placements do
				for x = p.Cells[1], p.Cells[3] - 1 do
					for z = p.Cells[2], p.Cells[4] - 1 do
						local i = at(x, z)
						if i and layout.Access[i] then
							error(`{p.Template} na frente de uma porta`)
						end
					end
				end
			end
		end)

		t.test(
			`{map.Id}: toda construção tem acesso (calçada, praça ou pátio a até BlockReach células)`,
			function()
				local reach = planner.BlockReach
				-- marcos fixos da planta (CityPlans.Sites) ficam onde a planta manda
				local fixed = {}
				for _, site in CityPlans[map.Id].Sites do
					fixed[site.Template] = true
				end
				local ACCESS = { Walk = true, Road = true, Plaza = true, Asphalt = true }
				for _, p in layout.Placements do
					if category(p) == "Building" and not fixed[p.Template] then
						local ok = false
						local r = p.Cells
						for x = r[1] - reach, r[3] - 1 + reach do
							for z = r[2] - reach, r[4] - 1 + reach do
								local i = at(x, z)
								if i and ACCESS[grid.Kind[i]] then
									ok = true
									break
								end
							end
							if ok then
								break
							end
						end
						t.truthy(ok, `{p.Template} sem acesso em {r[1]},{r[2]}`)
					end
				end
			end
		)

		t.test(`{map.Id}: decoração variada (nenhum modelo passa de 30% da decoração)`, function()
			local counts, total = {}, 0
			for _, p in layout.Placements do
				local c = category(p)
				if c == "Plant" or c == "Leisure" or c == "Beach" then
					counts[p.Template] = (counts[p.Template] or 0) + 1
					total += 1
				end
			end
			for name, n in counts do
				if n > total * 0.3 then
					error(`{name} = {n} de {total}`)
				end
			end
		end)

		t.test(`{map.Id}: microambientes completos (nenhum kit com peça solta)`, function()
			local kits = {}
			for _, p in layout.Placements do
				if p.Kit then
					kits[p.Kit] = kits[p.Kit] or {}
					table.insert(kits[p.Kit], p)
				end
			end
			local count = 0
			for tag, pieces in kits do
				count += 1
				t.truthy(#pieces >= 3, `{tag} só com {#pieces} peças`)
				-- todas as peças perto umas das outras (o kit cabe num retângulo de até 15 células)
				local x0, z0, x1, z1 = math.huge, math.huge, -math.huge, -math.huge
				for _, p in pieces do
					x0, z0 = math.min(x0, p.Cells[1]), math.min(z0, p.Cells[2])
					x1, z1 = math.max(x1, p.Cells[3]), math.max(z1, p.Cells[4])
				end
				t.truthy(x1 - x0 <= 15 and z1 - z0 <= 15, `{tag} espalhado`)
			end
			t.truthy(count >= 5, `poucos microambientes ({count})`)
		end)

		t.test(`{map.Id}: cerca e portão sempre fechando um quintal (perto de uma casa)`, function()
			local houses = {}
			for _, q in layout.Placements do
				if planner.Houses[q.Template] then
					table.insert(houses, q.Cells)
				end
			end
			for _, p in layout.Placements do
				if (p.Template == "Fence" or p.Template == "SnowFence" or p.Template == "Gate") and p.Kit == nil then
					local r, near = p.Cells, false
					for _, c in houses do
						if c[1] - 5 <= r[3] and c[3] + 5 >= r[1] and c[2] - 5 <= r[4] and c[4] + 5 >= r[2] then
							near = true
							break
						end
					end
					t.truthy(near, `{p.Template} solta em {r[1]},{r[2]}`)
				end
			end
		end)

		t.test(`{map.Id}: aviões na pista`, function()
			local onRunway = 0
			for _, p in layout.Placements do
				if p.Template == "Plane" and groundOf(p) == "Runway" then
					onRunway += 1
				end
			end
			local hasRunway = false
			for _, kind in grid.Kind do
				hasRunway = hasRunway or kind == "Runway"
			end
			t.truthy(onRunway >= 1 or not hasRunway)
		end)
	end
end
