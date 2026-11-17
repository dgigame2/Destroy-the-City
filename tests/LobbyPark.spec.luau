-- Enfeites do parque do lobby (LobbyConfig.Park): floreiras, bancos, postes e árvores não encostam em nada
-- (praça, caminhos, estações, sebe, natureza, cogumelos) nem uns nos outros, e ficam dentro do parque.
local LobbyConfig = require("../src/shared/Config/LobbyConfig")
local BlockTrees = require("../src/shared/Logic/BlockTrees")

local TOL = 0.001
local W, D = LobbyConfig.Width, LobbyConfig.Depth
local hedge = LobbyConfig.Hedge

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
	{ "Praça", { -28, -38, 28, 18 } },
	{ "Caminho esq.", { -50, -25, -28, -15 } },
	{ "Caminho dir.", { 28, -25, 50, -15 } },
	{ "Caminho START", { -5, 18, 5, 56 } },
	{ "Caminho fundo esq.", { -65, 35, -15, 44 } },
	{ "Caminho fundo dir.", { 15, 35, 65, 44 } },
	{ "Quadrados START A RUN", { -45, 58, 45, 90 } },
	{ "Mural", { -57, 40, -33, 50 } },
	{ "Classes", { 33, 40, 57, 50 } },
	{ "Loja", { -93, -33, -63, -7 } },
	{ "Roleta", { 63, -32, 93, -8 } },
	{ "Placa do título", { -26, -64, 26, -56 } },
	{ "Sebe do fundo", { -W / 2, -D / 2, W / 2, -D / 2 + hedge.Inset + hedge.Size / 2 } },
	{ "Sebe esq.", { -W / 2, -D / 2, -W / 2 + hedge.Inset + hedge.Size / 2, hedge.SideEndZ + hedge.Size } },
	{ "Sebe dir.", { W / 2 - hedge.Inset - hedge.Size / 2, -D / 2, W / 2, hedge.SideEndZ + hedge.Size } },
}
-- natureza do buildNature (x, z, raio) e flores
local NATURE = {
	{ -100, -66, 6 },
	{ -100, -40, 5 },
	{ -102, 62, 6 },
	{ -84, 30, 5.5 },
	{ 100, -66, 6 },
	{ 102, 62, 5.5 },
	{ 86, 40, 5.5 },
	{ -30, -75, 4 },
	{ 30, -75, 4 },
	{ -62, 75, 8.5 },
	{ 62, 75, 7.5 },
	{ -60, -72, 4.5 },
	{ 60, -72, 4.5 },
	{ -18, 24, 2.2 },
	{ 18, 24, 2.2 },
	{ -55, -5, 2 },
	{ 60, 5, 2 },
	{ -24, -32, 2.6 },
	{ 24, -32, 2.6 },
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
