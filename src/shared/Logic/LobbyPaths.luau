--!strict
-- Borda dos caminhos de pedra do lobby: uma faixa de largura fixa em volta do contorno de TODOS os caminhos
-- juntos (onde um caminho encosta no outro não tem borda). Lógica pura: testada no Lune (LobbyPaths.spec).
-- Faz numa grade (Cell studs): marca as células dos caminhos, pega as células de grama até `width` de
-- distância delas e junta em retângulos (corridas por linha, depois linhas iguais seguidas).

local LobbyPaths = {}

export type Rect = { X0: number, Z0: number, X1: number, Z1: number }

local CELL = 0.5

function LobbyPaths.border(paths: { Rect }, width: number): { Rect }
	local reach = math.floor(width / CELL + 0.5)
	local x0, z0, x1, z1 = math.huge, math.huge, -math.huge, -math.huge
	for _, r in paths do
		x0, z0 = math.min(x0, r.X0), math.min(z0, r.Z0)
		x1, z1 = math.max(x1, r.X1), math.max(z1, r.Z1)
	end
	x0, z0 = x0 - width, z0 - width
	local nx = math.floor((x1 + width - x0) / CELL + 0.5)
	local nz = math.floor((z1 + width - z0) / CELL + 0.5)
	local function index(i: number, j: number): number
		return j * nx + i
	end
	-- células dos caminhos (centro da célula dentro de algum retângulo)
	local path: { [number]: boolean } = {}
	for _, r in paths do
		local i0 = math.floor((r.X0 - x0) / CELL + 0.5)
		local i1 = math.floor((r.X1 - x0) / CELL + 0.5) - 1
		local j0 = math.floor((r.Z0 - z0) / CELL + 0.5)
		local j1 = math.floor((r.Z1 - z0) / CELL + 0.5) - 1
		for j = j0, j1 do
			for i = i0, i1 do
				path[index(i, j)] = true
			end
		end
	end
	-- borda: fora dos caminhos e até `reach` células (quadrado) de um caminho
	local border: { [number]: boolean } = {}
	for key in path do
		local i, j = key % nx, key // nx
		for dj = -reach, reach do
			for di = -reach, reach do
				local ii, jj = i + di, j + dj
				if ii >= 0 and ii < nx and jj >= 0 and jj < nz then
					local k = index(ii, jj)
					if not path[k] then
						border[k] = true
					end
				end
			end
		end
	end
	-- corridas por linha
	local open: { [string]: Rect } = {} -- corrida "i0:i1" ainda crescendo nas linhas de baixo
	local rects: { Rect } = {}
	for j = 0, nz do
		local runs: { [string]: boolean } = {}
		local i = 0
		while j < nz and i < nx do
			if border[index(i, j)] then
				local start = i
				while i < nx and border[index(i, j)] do
					i += 1
				end
				runs[start .. ":" .. (i - 1)] = true
			else
				i += 1
			end
		end
		for key, r in open do
			if runs[key] then
				r.Z1 = z0 + (j + 1) * CELL -- a mesma corrida continua: cresce o retângulo
				runs[key] = nil
			else
				table.insert(rects, r)
				open[key] = nil
			end
		end
		for key in runs do
			local a, b = string.match(key, "(%d+):(%d+)")
			local ia, ib = tonumber(a) :: number, tonumber(b) :: number
			open[key] = { X0 = x0 + ia * CELL, X1 = x0 + (ib + 1) * CELL, Z0 = z0 + j * CELL, Z1 = z0 + (j + 1) * CELL }
		end
	end
	table.sort(rects, function(a, b)
		if a.Z0 ~= b.Z0 then
			return a.Z0 < b.Z0
		end
		return a.X0 < b.X0
	end)
	return rects
end

return LobbyPaths
