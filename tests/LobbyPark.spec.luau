-- Enfeites do parque do lobby (LobbyConfig.Park): floreiras, bancos, postes e árvores não encostam em nada
-- (praça, caminhos, estações, sebe, natureza, cogumelos) nem uns nos outros, e ficam dentro do parque.
local LobbyConfig = require("../src/shared/Config/LobbyConfig")
local RW, CL = LobbyConfig.Stations.Rewards, LobbyConfig.Stations.Classes
local SH = LobbyConfig.Shop
local BlockTrees = require("../src/shared/Logic/BlockTrees")

local TOL = 0.001
local W, D = LobbyConfig.Width, LobbyConfig.Depth
local Hedges = require("../src/shared/Logic/Hedges")

-- caixa no chão (x0, z0, x1, z1) de um objeto com meia largura hx / meia profundidade hz girado em 90° passos
local function rect(x: number, z: number, hx: number, hz: number, yaw: number)
	if math.abs(yaw) % 180 == 90 then
		hx, hz = hz, hx
	end
	return { x - hx, z - hz, x + hx, z + hz }
end

local function overlap(a, b): boolean
	return a[1] < b[3] - TOL and b[1] < a[3] - TOL and a[2] < b[4] - TOL and b[2] < a[4] - TOL
end

-- áreas ocupadas (MEDIDAS do LobbyService)
local AREAS = {
	{ "Quadrados START A RUN", { -45.3, 58, 45.3, 90 } },
	{ "Mural", { RW[1] - 12.2, RW[2] - 5, RW[1] + 12.2, RW[2] + 5 } },
	{ "Classes", { CL[1] - 12.2, CL[2] - 5, CL[1] + 12.2, CL[2] + 5 } },
	-- quadrados neon na frente das placas (LobbyConfig.StationPad)
	{
		"Quadrado recompensas",
		{ RW[1] - 9, RW[2] + LobbyConfig.StationPad.Z0, RW[1] + 9, RW[2] + LobbyConfig.StationPad.Z1 },
	},
	{
		"Quadrado classes",
		{ CL[1] - 9, CL[2] + LobbyConfig.StationPad.Z0, CL[1] + 9, CL[2] + LobbyConfig.StationPad.Z1 },
	},
	{ "Loja", { SH.X - 13, SH.Z - 17, SH.X + 14, SH.Z + 17 } }, -- cerca da loja (LobbyConfig.Shop)
	-- cerca em volta do parque todo (a 2 da borda, 1.2 de grossura): nada encosta nela
	{ "Cerca do fundo", { -W / 2, -D / 2, W / 2, -D / 2 + 2.7 } },
	{ "Cerca da frente", { -W / 2, D / 2 - 2.7, W / 2, D / 2 } },
	{ "Cerca esq.", { -W / 2, -D / 2, -W / 2 + 2.7, D / 2 } },
	{ "Cerca dir.", { W / 2 - 2.7, -D / 2, W / 2, D / 2 } },
}
-- caminhos de pedra (LobbyConfig.Paths) com a borda de lajota em volta
do
	local b = LobbyConfig.PathBorder.Width
	for i, p in LobbyConfig.Paths do
		table.insert(AREAS, { "Caminho " .. i, { p[1] - b, p[2] - b, p[3] + b, p[4] + b } })
	end
end
-- natureza do buildNature (x, z, raio) e flores
local NATURE = {
	{ -84, 30, 5.5 },
	{ 86, 40, 5.5 },
	{ -14, -26, 2.6 },
	{ 14, -26, 2.6 },
}

local function items()
	local list = {}
	local P = LobbyConfig.Props
	local park = LobbyConfig.Park
	local function add(kind, spot, hx, hz)
		table.insert(list, { kind, rect(spot[1], spot[2], hx, hz, spot[3] or 0) })
	end
	for _, s in park.Planters do
		add("Floreira", s, P.PlanterLong.Size[1] / 2, P.PlanterLong.Size[3] / 2)
	end
	for _, s in park.WidePlanters do
		add("Floreira larga", s, P.PlanterWide.Size[1] / 2, P.PlanterWide.Size[3] / 2)
	end
	for _, s in park.Benches do
		add("Banco", s, P.Bench.Size[1] / 2, P.Bench.Size[3] / 2)
	end
	for _, s in park.Lamps do
		add("Poste", s, P.ParkLamp.Size[1] / 2, P.ParkLamp.Size[3] / 2)
	end
	for i, s in park.Trees do
		local hx, hz = BlockTrees.half(BlockTrees.pick(i), s[3])
		add("Árvore", { s[1], s[2], 0 }, hx, hz)
	end
	for _, b in park.Bushes do
		add("Moita solta", { b[1], b[2], 0 }, b[3] / 2, b[3] / 2)
	end
	for _, fl in park.Flowers do
		local spec = if fl[3] == 2 then P.TulipPink else P.TulipRed
		local r = math.max(spec.Size[1], spec.Size[3]) / 2 * park.FlowerScale // 1 + 1 -- gira: usa um quadrado folgado
		add("Tulipas", { fl[1], fl[2], 0 }, r, r)
	end
	for _, c in Hedges.build(W, D, LobbyConfig.Hedge) do
		add("Moita", { c.X, c.Z, 0 }, c.Size / 2, c.Size / 2)
	end
	local r = math.max(P.Mushroom.Size[1], P.Mushroom.Size[3]) / 2
	for _, m in LobbyConfig.Mushrooms do
		add("Cogumelo", { m[1], m[2], 0 }, r * m[3], r * m[3])
	end
	return list
end

return function(t)
	t.test("parque: enfeites dentro do parque e longe da praça, caminhos, estações e sebe", function()
		for i, it in items() do
			local b = it[2]
			t.truthy(b[1] > -W / 2 and b[3] < W / 2 and b[2] > -D / 2 and b[4] < D / 2, `{it[1]} {i}`)
			if it[1] ~= "Cogumelo" then -- cogumelos já têm o teste deles
				for _, a in AREAS do
					t.truthy(not overlap(b, a[2]), `{it[1]} {i} em {a[1]}`)
				end
			end
		end
	end)

	t.test("parque: enfeites não encostam na natureza nem uns nos outros", function()
		local list = items()
		for i, it in list do
			local b = it[2]
			for _, n in NATURE do
				t.truthy(
					not overlap(b, { n[1] - n[3], n[2] - n[3], n[1] + n[3], n[2] + n[3] }),
					`{it[1]} {i} x {n[1]},{n[2]}`
				)
			end
			for j = i + 1, #list do
				t.truthy(not overlap(b, list[j][2]), `{it[1]} {i} x {list[j][1]} {j}`)
			end
		end
	end)
end
