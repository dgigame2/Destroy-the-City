--!strict
-- Grade espacial pura (XZ) para o servidor achar construções sem consultar peças do Roblox.
-- Cada id guarda a caixa do footprint (AABB) e entra em todas as células que ela toca.
-- query devolve cada id uma vez só, e só os que a caixa realmente cruza o círculo.

local SpatialGrid = {}

export type Grid = {
	Cell: number,
	Cells: { [number]: { number } },
	Boxes: { [number]: { number } }, -- id -> {minX, minZ, maxX, maxZ}
	Mark: { [number]: number },
	Stamp: number,
}

local OFFSET = 32768

local function key(cx: number, cz: number): number
	return (cx + OFFSET) * 65536 + (cz + OFFSET)
end

function SpatialGrid.new(cell: number): Grid
	assert(cell > 0, "SpatialGrid: célula precisa ser > 0")
	return { Cell = cell, Cells = {}, Boxes = {}, Mark = {}, Stamp = 0 }
end

function SpatialGrid.insert(grid: Grid, id: number, minX: number, minZ: number, maxX: number, maxZ: number)
	assert(grid.Boxes[id] == nil, "SpatialGrid: id repetido")
	grid.Boxes[id] = { minX, minZ, maxX, maxZ }
	local c = grid.Cell
	for cx = math.floor(minX / c), math.floor(maxX / c) do
		for cz = math.floor(minZ / c), math.floor(maxZ / c) do
			local k = key(cx, cz)
			local list = grid.Cells[k]
			if list == nil then
				list = {}
				grid.Cells[k] = list
			end
			table.insert(list, id)
		end
	end
end

-- Tira o id da busca (ex.: construção destruída). As células ficam com ele, mas sem caixa ele é pulado.
function SpatialGrid.remove(grid: Grid, id: number)
	grid.Boxes[id] = nil
end

-- Ids cujo footprint cruza o círculo (x, z, raio), até `limit` (os mais perto primeiro).
function SpatialGrid.queryCircle(grid: Grid, x: number, z: number, radius: number, limit: number?): { number }
	local found: { { number } } = {}
	if not (radius >= 0) then
		return {}
	end
	grid.Stamp += 1
	local stamp = grid.Stamp
	local c = grid.Cell
	local r2 = radius * radius
	for cx = math.floor((x - radius) / c), math.floor((x + radius) / c) do
		for cz = math.floor((z - radius) / c), math.floor((z + radius) / c) do
			local list = grid.Cells[key(cx, cz)]
			if list then
				for _, id in list do
					local box = grid.Boxes[id]
					if box and grid.Mark[id] ~= stamp then
						grid.Mark[id] = stamp
						local dx = math.max(box[1] - x, 0, x - box[3])
						local dz = math.max(box[2] - z, 0, z - box[4])
						local d2 = dx * dx + dz * dz
						if d2 <= r2 then
							table.insert(found, { id, d2 })
						end
					end
				end
			end
		end
	end
	table.sort(found, function(a, b)
		return if a[2] == b[2] then a[1] < b[1] else a[2] < b[2]
	end)
	local ids = {}
	for i, entry in found do
		if limit and i > limit then
			break
		end
		ids[i] = entry[1]
	end
	return ids
end

return SpatialGrid
