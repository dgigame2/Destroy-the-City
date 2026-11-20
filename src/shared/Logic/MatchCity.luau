--!strict
-- Da cidade gerada (Logic/CityGen) para os dados da partida (puro, testável no Lune):
--   * valor de destruição e vida de cada construção (MatchConfig.Value / HpPerValue);
--   * caixa do footprint no mundo (XZ) para a grade espacial do servidor;
--   * altura do chão numa posição (validar a mira sem raycast em peças).
-- Servidor e clientes geram o MESMO layout pela semente do mapa, então os ids (índice da Placement) batem.

local MatchCity = {}

export type Info = {
	MaxHp: number,
	Value: number,
	Box: { number }, -- {minX, minZ, maxX, maxZ} no mundo
	Height: number,
	Category: string,
}

type Template = { Boxes: { { Min: { number }?, Max: { number }? } } }
type Placement = { Template: string, X: number, Y: number, Z: number, Rotation: number }

-- Caixa local do modelo (todas as peças): min/max em X, Y, Z.
function MatchCity.bounds(template: Template): ({ number }, { number })
	local min = { math.huge, math.huge, math.huge }
	local max = { -math.huge, -math.huge, -math.huge }
	for _, b in template.Boxes do
		local bmin, bmax = b.Min :: { number }, b.Max :: { number }
		for k = 1, 3 do
			min[k] = math.min(min[k], bmin[k])
			max[k] = math.max(max[k], bmax[k])
		end
	end
	if min[1] == math.huge then
		return { 0, 0, 0 }, { 0, 0, 0 }
	end
	return min, max
end

-- Caixa XZ no mundo depois de girar em Y (graus) e mover para (x, z).
function MatchCity.worldBox(min: { number }, max: { number }, rotation: number, x: number, z: number): { number }
	local r = math.rad(rotation)
	local c, s = math.cos(r), math.sin(r)
	local minX, minZ, maxX, maxZ = math.huge, math.huge, -math.huge, -math.huge
	for _, px in { min[1], max[1] } do
		for _, pz in { min[3], max[3] } do
			-- mesma rotação do CFrame.Angles(0, r, 0) do Roblox
			local wx = px * c + pz * s
			local wz = -px * s + pz * c
			minX, maxX = math.min(minX, wx), math.max(maxX, wx)
			minZ, maxZ = math.min(minZ, wz), math.max(maxZ, wz)
		end
	end
	local e = 1e-6 -- arredonda o ruído do seno/cosseno
	return {
		math.floor((x + minX) / e + 0.5) * e,
		math.floor((z + minZ) / e + 0.5) * e,
		math.floor((x + maxX) / e + 0.5) * e,
		math.floor((z + maxZ) / e + 0.5) * e,
	}
end

function MatchCity.value(width: number, depth: number, height: number, weight: number, cfg: any): number
	if weight <= 0 then
		return 0
	end
	local area = math.max(width * depth, 1)
	return area * math.max(height, 1) ^ cfg.Value.HeightExp * weight * cfg.Value.Scale
end

-- Uma Info por Placement (mesmo índice = BuildingId).
function MatchCity.infos(
	placements: { Placement },
	templates: { [string]: Template },
	catalog: { [string]: { Category: string } },
	cfg: any
): { Info }
	local cache: { [string]: { any } } = {}
	local list = table.create(#placements)
	for i, p in placements do
		local cached = cache[p.Template]
		if cached == nil then
			local min, max = MatchCity.bounds(templates[p.Template])
			local entry = catalog[p.Template]
			local category = if entry then entry.Category else "Building"
			local weight = cfg.Value.Weight[category] or 0
			local value = MatchCity.value(max[1] - min[1], max[3] - min[3], max[2] - min[2], weight, cfg)
			cached = { min, max, value, category, max[2] - min[2] }
			cache[p.Template] = cached
		end
		local value = cached[3]
		list[i] = {
			MaxHp = if value > 0 then value * cfg.HpPerValue else cfg.PropHp,
			Value = value,
			Box = MatchCity.worldBox(cached[1], cached[2], p.Rotation, p.X, p.Z),
			Height = cached[5],
			Category = cached[4],
		}
	end
	return list
end

-- Altura do chão na grade (nil = fora da cidade ou no mar).
function MatchCity.groundAt(grid: any, cellSize: number, x: number, z: number): number?
	local cx = math.floor(x / cellSize + grid.Width / 2)
	local cz = math.floor(z / cellSize + grid.Depth / 2)
	if cx < 0 or cz < 0 or cx >= grid.Width or cz >= grid.Depth then
		return nil
	end
	local i = cz * grid.Width + cx + 1
	if grid.Zone[i] == nil or grid.Zone[i] == 0 then
		return nil
	end
	return grid.Height[i] or 0
end

return MatchCity
