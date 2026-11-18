-- Borda dos caminhos de pedra do lobby: contorna todos os caminhos sem cobrir nenhum, sem peças sobrepostas,
-- e não encosta nas placas, loja, quadrados START A RUN, postes, bancos e floreiras.
local LobbyPaths = require("../src/shared/Logic/LobbyPaths")
local LobbyConfig = require("../src/shared/Config/LobbyConfig")
local RW, CL = LobbyConfig.Stations.Rewards, LobbyConfig.Stations.Classes
local SH = LobbyConfig.Shop

local TOL = 0.001
local paths = {}
for _, p in LobbyConfig.Paths do
	table.insert(paths, { X0 = p[1], Z0 = p[2], X1 = p[3], Z1 = p[4] })
end
local width = LobbyConfig.PathBorder.Width
local border = LobbyPaths.border(paths, width)

local function overlap(a, b): boolean
	return a.X0 < b.X1 - TOL and b.X0 < a.X1 - TOL and a.Z0 < b.Z1 - TOL and b.Z0 < a.Z1 - TOL
end

local function box(x0, z0, x1, z1)
	return { X0 = x0, Z0 = z0, X1 = x1, Z1 = z1 }
end

-- coisas no chão perto dos caminhos (MEDIDAS do LobbyService / LobbyConfig)
local SOLID = {
	{ "Mural", box(RW[1] - 12.1, RW[2] - 1.4, RW[1] + 12.1, RW[2] + 1.1) }, -- pé da placa no chão (floreira na frente)
	{ "Classes", box(CL[1] - 12.1, CL[2] - 1.4, CL[1] + 12.1, CL[2] + 1.1) },
	{ "Loja", box(SH.X - 13, SH.Z - 17, SH.X + 14, SH.Z + 17) }, -- cerca da loja (LobbyConfig.Shop)
	{ "Quadrados START A RUN", box(-45.3, 58, 45.3, 90) },
}
do
	local P = LobbyConfig.Props
	for i, s in LobbyConfig.Park.Lamps do
		local h = P.ParkLamp.Size[1] / 2
		table.insert(SOLID, { "Poste " .. i, box(s[1] - h, s[2] - h, s[1] + h, s[2] + h) })
	end
end

return function(t)
	t.test("caminhos: borda em volta, sem cobrir caminho nem se sobrepor", function()
		t.truthy(#border > 4)
		for i, b in border do
			for j, p in paths do
				t.truthy(not overlap(b, p), `borda {i} x caminho {j}`)
			end
			for j = i + 1, #border do
				t.truthy(not overlap(b, border[j]), `borda {i} x {j}`)
			end
		end
	end)

	t.test("caminhos: todo lado de caminho que dá para a grama tem borda encostada", function()
		-- ponto logo fora do meio de cada lado: ou é outro caminho, ou é borda
		local function covered(x, z)
			for _, r in paths do
				if x > r.X0 and x < r.X1 and z > r.Z0 and z < r.Z1 then
					return true
				end
			end
			for _, r in border do
				if x > r.X0 and x < r.X1 and z > r.Z0 and z < r.Z1 then
					return true
				end
			end
			return false
		end
		for j, p in paths do
			local mx, mz = (p.X0 + p.X1) / 2, (p.Z0 + p.Z1) / 2
			for _, pt in { { p.X0 - 0.2, mz }, { p.X1 + 0.2, mz }, { mx, p.Z0 - 0.2 }, { mx, p.Z1 + 0.2 } } do
				t.truthy(covered(pt[1], pt[2]), `caminho {j} sem borda em {pt[1]},{pt[2]}`)
			end
		end
	end)

	t.test("caminhos: borda não encosta em placas, loja, quadrados e postes", function()
		for i, b in border do
			for _, s in SOLID do
				t.truthy(not overlap(b, s[2]), `borda {i} x {s[1]}`)
			end
		end
	end)
end
