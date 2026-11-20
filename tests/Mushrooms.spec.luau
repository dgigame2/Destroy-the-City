-- Cogumelos de enfeite do lobby (LobbyConfig.Mushrooms): dentro da ilha, fora da praça, dos caminhos e das
-- áreas das estações, e sem encostar um no outro nem nas árvores/palmeiras/guarda-sóis.
local LobbyConfig = require("../src/shared/Config/LobbyConfig")

local MUSHROOM = LobbyConfig.Props.Mushroom
-- raio de um cogumelo de escala k (meia largura do chapéu)
local function radius(k: number): number
	return math.max(MUSHROOM.Size[1], MUSHROOM.Size[3]) / 2 * k
end

-- áreas ocupadas (retângulos x0, z0, x1, z1 no espaço do lobby; MEDIDAS do LobbyService)
local AREAS = {
	{ "Praça", -28, -38, 28, 18 },
	{ "Caminho esq.", -50, -25, -28, -15 },
	{ "Caminho dir.", 28, -25, 50, -15 },
	{ "Caminho START", -5, 18, 5, 56 },
	{ "Caminho fundo esq.", -65, 35, -15, 44 },
	{ "Caminho fundo dir.", 15, 35, 65, 44 },
	{ "Quadrados START A RUN", -45, 58, 45, 90 },
	{ "Mural de recompensas", -57, 40, -33, 50 },
	{ "Salão de classes", 33, 40, 57, 50 },
	{ "Loja", -93, -33, -63, -7 },
	{ "Roleta", 63, -32, 93, -8 },
	{ "Placa do título", -26, -64, 26, -56 },
}

-- natureza do buildNature (x, z, raio aproximado já com a escala)
local NATURE = {
	{ -100, -66, 6 },
	{ -100, -40, 5 },
	{ -105, 10, 4.5 },
	{ -102, 62, 6 },
	{ -84, 30, 5.5 },
	{ 100, -66, 6 },
	{ 100, 20, 4.5 },
	{ 102, 62, 5.5 },
	{ 86, 40, 5.5 },
	{ -30, -75, 4 },
	{ 30, -75, 4 },
	{ -62, 75, 8.5 },
	{ 62, 75, 7.5 },
	{ -60, -72, 4.5 },
	{ 60, -72, 4.5 },
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
