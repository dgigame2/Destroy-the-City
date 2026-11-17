-- Fonte da praça do lobby: nenhuma peça dentro da outra, tudo apoiado, cabe na praça sem pegar o spawn.
local Fountain = require("../src/shared/Logic/Fountain")
local LobbyConfig = require("../src/shared/Config/LobbyConfig")

local cfg = LobbyConfig.Fountain
local pieces = Fountain.pieces(cfg)
local TOL = 0.001

local function span(p)
	return p.Pos[2] - p.Size[2] / 2, p.Pos[2] + p.Size[2] / 2
end

local function overlapY(a, b): boolean
	local a0, a1 = span(a)
	local b0, b1 = span(b)
	return a0 < b1 - TOL and b0 < a1 - TOL
end

-- raio de fora (ou da face de dentro) de uma peça
local function outer(p): number
	if p.Shape == "Block" then
		return p.Outer
	end
	return p.Size[1] / 2
end

return function(t)
	t.test("fonte: tem as 3 bacias, colunas, água e a bola no topo", function()
		local names = {}
		for _, p in pieces do
			names[p.Name] = true
		end
		for i = 1, #cfg.Basins do
			t.truthy(names["Basin" .. i .. "Water"], i)
			t.truthy(names["Basin" .. i .. "Wall"], i)
		end
		t.truthy(names.Crown)
		t.equal(#cfg.Columns, #cfg.Basins - 1)
	end)

	t.test("fonte: nenhuma peça dentro da outra", function()
		for i = 1, #pieces do
			for j = i + 1, #pieces do
				local a, b = pieces[i], pieces[j]
				if overlapY(a, b) then
					local ok
					if a.Shape ~= "Block" and b.Shape ~= "Block" then
						ok = false -- discos e bola no mesmo eixo: só podem empilhar
					elseif a.Shape == "Block" and b.Shape == "Block" then
						-- blocos do mesmo anel: a largura cabe na face de dentro; anéis diferentes não se cruzam
						if a.Name == b.Name then
							ok = a.Size[1] <= 2 * a.Inner * math.tan(math.pi / cfg.Segments) + TOL
						else
							ok = a.Outer <= b.Inner + TOL or b.Outer <= a.Inner + TOL
						end
					else
						local ringPiece = if a.Shape == "Block" then a else b
						local round = if a.Shape == "Block" then b else a
						ok = outer(round) <= ringPiece.Inner + TOL
					end
					t.truthy(ok, a.Name .. " x " .. b.Name)
				end
			end
		end
	end)

	t.test("fonte: cada peça está apoiada (no chão ou em cima de outra)", function()
		for _, p in pieces do
			local bottom = span(p)
			local supported = math.abs(bottom) < TOL
			for _, q in pieces do
				local _, top = span(q)
				if q ~= p and math.abs(top - bottom) < TOL then
					supported = true
					break
				end
			end
			t.truthy(supported, p.Name)
		end
	end)

	t.test("fonte: água abaixo da parede e cada bacia de cima menor que a de baixo", function()
		for i, b in cfg.Basins do
			t.truthy(b.Water < b.Wall.Height, i)
			t.truthy(b.Bowl.Radius < b.Radius, i)
			if i > 1 then
				t.truthy(b.Radius + b.Rim.Overhang < cfg.Basins[i - 1].Radius - cfg.Basins[i - 1].Wall.Thickness, i)
			end
		end
	end)

	t.test("fonte: a água que transborda de cada bacia cai dentro da água da bacia de baixo", function()
		local spills = Fountain.spills(pieces, cfg)
		t.equal(#spills, #cfg.Basins - 1)
		for _, s in spills do
			t.truthy(s.Fall > 0, s.Basin)
			-- a cortina sai um pouco para fora da borda (LobbyConfig.FountainWater.SpillOut) e ainda cai na água
			t.truthy(s.Radius + LobbyConfig.FountainWater.SpillOut < s.Land, s.Basin)
		end
	end)

	t.test("fonte: cabe na praça e ninguém nasce dentro", function()
		local r = Fountain.extent(pieces)
		t.truthy(r < LobbyConfig.SpawnRadius)
		t.truthy(r < 56 / 2) -- praça 56x56 (LobbyService.buildPlaza)
	end)
end
