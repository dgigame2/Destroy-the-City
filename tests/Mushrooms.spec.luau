-- Cogumelos de enfeite do lobby (LobbyConfig.Mushrooms): dentro da ilha, fora da praça, dos caminhos e das
-- áreas das estações, e sem encostar um no outro nem nas árvores/palmeiras/guarda-sóis.
local LobbyConfig = require("../src/shared/Config/LobbyConfig")
local RW, CL = LobbyConfig.Stations.Rewards, LobbyConfig.Stations.Classes
local SH = LobbyConfig.Shop

local MUSHROOM = LobbyConfig.Props.Mushroom
-- raio de um cogumelo de escala k (meia largura do chapéu)
local function radius(k: number): number
	return math.max(MUSHROOM.Size[1], MUSHROOM.Size[3]) / 2 * k
end

-- áreas ocupadas (retângulos x0, z0, x1, z1 no espaço do lobby; MEDIDAS do LobbyService)
local AREAS = {
	{ "Quadrados START A RUN", -45.3, 58, 45.3, 90 },
	{ "Mural de recompensas", RW[1] - 12.2, RW[2] - 5, RW[1] + 12.2, RW[2] + 5 },
	{ "Salão de classes", CL[1] - 12.2, CL[2] - 5, CL[1] + 12.2, CL[2] + 5 },
	{ "Loja", SH.X - 13, SH.Z - 17, SH.X + 14, SH.Z + 17 }, -- cerca da loja (LobbyConfig.Shop)
}
-- caminhos de pedra (LobbyConfig.Paths) com a borda de lajota em volta
do
	local b = LobbyConfig.PathBorder.Width
	for i, p in LobbyConfig.Paths do
		table.insert(AREAS, { "Caminho " .. i, p[1] - b, p[2] - b, p[3] + b, p[4] + b })
	end
end

-- natureza do buildNature (x, z, raio aproximado já com a escala)
local NATURE = {
	{ -84, 30, 5.5 },
	{ 86, 40, 5.5 },
}

return function(t)
	t.test("cogumelos: dentro da ilha", function()
		for i, m in LobbyConfig.Mushrooms do
			local r = radius(m[3])
			t.truthy(math.abs(m[1]) + r < LobbyConfig.Width / 2 - 4, i)
			t.truthy(math.abs(m[2]) + r < LobbyConfig.Depth / 2 - 4, i)
		end
	end)

	t.test("cogumelos: fora da praça, dos caminhos e das estações", function()
		for i, m in LobbyConfig.Mushrooms do
			local r = radius(m[3])
			for _, a in AREAS do
				local outside = m[1] + r < a[2] or m[1] - r > a[4] or m[2] + r < a[3] or m[2] - r > a[5]
				t.truthy(outside, `cogumelo {i} em {a[1]}`)
			end
		end
	end)

	t.test("cogumelos: não encostam um no outro nem nas árvores", function()
		local list = LobbyConfig.Mushrooms
		for i, a in list do
			for j = i + 1, #list do
				local b = list[j]
				local d = math.sqrt((a[1] - b[1]) ^ 2 + (a[2] - b[2]) ^ 2)
				t.truthy(d > radius(a[3]) + radius(b[3]) + 0.5, `{i} x {j}`)
			end
			for _, n in NATURE do
				local d = math.sqrt((a[1] - n[1]) ^ 2 + (a[2] - n[2]) ^ 2)
				t.truthy(d > radius(a[3]) + n[3], `{i} x árvore em {n[1]},{n[2]}`)
			end
		end
	end)
end
