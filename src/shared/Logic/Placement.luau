--!strict
-- Regras espaciais do gerador planejado (puro, testável no Lune). Usa o catálogo (Config/ModelCatalog):
--   * categoria de cada modelo e onde ele pode ficar (chão, bairro);
--   * distância mínima entre modelos do mesmo grupo (índice espacial: não varre a cidade inteira);
--   * grupos naturais: um centro e alguns itens em volta, com espaçamento variado.

export type Entry = {
	Category: string,
	Spacing: number?,
	SpacingGroup: string?,
	Only: { [string]: boolean }?,
	Districts: { [string]: boolean }?,
	FaceRoad: boolean?,
}
export type Catalog = { [string]: Entry }

-- Índice espacial: baldes quadrados de `bucket` studs com os pontos de cada grupo de espaçamento.
export type Index = { Bucket: number, Cells: { [number]: { { any } } } }

local Placement = {}

local BUILDING: Entry = table.freeze({ Category = "Building" })

function Placement.entry(catalog: Catalog, name: string): Entry
	return catalog[name] or BUILDING
end

function Placement.category(catalog: Catalog, name: string): string
	return Placement.entry(catalog, name).Category
end

-- Grupo de espaçamento e distância mínima do modelo (nil, 0 = sem regra).
function Placement.spacing(catalog: Catalog, name: string): (string?, number)
	local entry = catalog[name]
	if entry == nil or entry.Spacing == nil then
		return nil, 0
	end
	return entry.SpacingGroup or name, entry.Spacing
end

-- O modelo pode ficar nesse chão e nesse bairro?
function Placement.allowed(catalog: Catalog, name: string, ground: string, district: string): boolean
	local entry = Placement.entry(catalog, name)
	if entry.Only and not entry.Only[ground] then
		return false
	end
	if entry.Districts and not entry.Districts[district] then
		return false
	end
	return true
end

function Placement.newIndex(bucket: number): Index
	return { Bucket = bucket, Cells = {} }
end

local function key(index: Index, x: number, z: number): number
	return math.floor(x / index.Bucket) * 65536 + math.floor(z / index.Bucket)
end

function Placement.add(index: Index, group: string, x: number, z: number)
	local k = key(index, x, z)
	local list = index.Cells[k]
	if list == nil then
		list = {}
		index.Cells[k] = list
	end
	table.insert(list, { group, x, z })
end

-- Existe algum ponto do grupo a menos de `radius` studs de (x, z)?
function Placement.near(index: Index, group: string, x: number, z: number, radius: number): boolean
	if radius <= 0 then
		return false
	end
	local b = index.Bucket
	local r2 = radius * radius
	for bx = math.floor((x - radius) / b), math.floor((x + radius) / b) do
		for bz = math.floor((z - radius) / b), math.floor((z + radius) / b) do
			for _, p in index.Cells[bx * 65536 + bz] or {} do
				if p[1] == group then
					local dx, dz = p[2] - x, p[3] - z
					if dx * dx + dz * dz < r2 then
						return true
					end
				end
			end
		end
	end
	return false
end

-- O modelo respeita a distância mínima do grupo dele em (x, z)?
function Placement.spaced(index: Index, catalog: Catalog, name: string, x: number, z: number): boolean
	local group, spacing = Placement.spacing(catalog, name)
	return group == nil or not Placement.near(index, group, x, z, spacing)
end

-- Registra o modelo no índice (se ele tem regra de espaçamento).
function Placement.register(index: Index, catalog: Catalog, name: string, x: number, z: number)
	local group = Placement.spacing(catalog, name)
	if group then
		Placement.add(index, group, x, z)
	end
end

-- Quantos itens um grupo natural tem: entre min e max, sorteado com `roll` em [0, 1).
function Placement.groupSize(min: number, max: number, roll: number): number
	return math.clamp(min + math.floor(roll * (max - min + 1)), min, max)
end

-- Deslocamento (dx, dz em células) do item `k` em volta do centro do grupo: espalha em ângulos diferentes
-- (ângulo de ouro) com distância variando entre 1 e `radius` (`roll` em [0, 1)). Nada em fila.
function Placement.groupOffset(k: number, radius: number, roll: number): (number, number)
	local angle = k * 2.39996 + roll * 1.2
	local distance = 1 + roll * math.max(radius - 1, 0)
	return math.floor(math.cos(angle) * distance + 0.5), math.floor(math.sin(angle) * distance + 0.5)
end

return Placement
