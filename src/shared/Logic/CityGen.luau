--!strict
-- Gera a cidade de um mapa a partir de uma planta (Config/CityPlans). Função pura e determinística:
-- a mesma planta sempre gera a mesma cidade (testável fora do Roblox).
--
-- A cidade é uma grade de células (CityConfig.CellSize). A planta desenha, em ordem:
--   0. o litoral: a terra é um retângulo arredondado com a borda ondulada (ruído), o resto é mar;
--      uma faixa de areia (orla) acompanha a costa;
--   1. áreas especiais (praça, areia, estacionamento, lago, morro em anéis);
--   2. rios (água) e ruas por cima (rua sobre a água vira ponte), mais as grades de ruas automáticas;
--   3. calçadas em volta das ruas;
--   4. bairros (o tipo de construção de cada terreno), áreas de progressão (zonas) e etapas dentro delas.
-- Depois coloca as construções fixas da planta (marcos), enche os terrenos de frente para a rua com as
-- construções do bairro, o miolo com natureza, as calçadas com postes e objetos, estacionamentos com carros.
-- Zona: só dá para entrar na zona N depois de comer tudo da zona N-1. Barreiras ficam nas bordas entre zonas.
-- Etapa: cada zona é dividida em regiões em ordem; cada etapa tem um tamanho máximo de construção (Cap) e o
-- balanceamento garante que, ao terminar uma etapa, você já come tudo da próxima (varre região por região).
-- Paredes invisíveis acompanham a costa (ninguém entra no mar).

local Placement = if script then require(script.Parent.Placement) else require("./Placement")

local CityGen = {}

export type Rect = { number } -- {x0, z0, x1, z1} em células; x1/z1 são exclusivos
export type Line = { Width: number, Points: { { number } } }
export type Area = { Kind: string, Rect: Rect, Levels: number?, District: string? }
export type District = { Kind: string, Rect: Rect }
-- Etapa: Rects = região da etapa dentro da zona (sem Rects = o resto da zona)
export type StepDef = { Cap: number, Rects: { Rect }? }
export type ZoneDef = { Name: string, Rects: { Rect }, Steps: { StepDef } }
-- centro em células; AnyGround = pode ficar em cima de tipos de chão diferentes (ex.: guindaste no cais
-- com a lança sobre a água): apoia na célula mais alta
export type Site = { Template: string, X: number, Z: number, Rotation: number?, AnyGround: boolean? }
-- Litoral: Inset = largura do mar dentro do retângulo; Radius = arredondamento dos cantos;
-- Amplitude/Wavelength = ondulação da costa; Shore = largura da orla de areia. Tudo em unidades da planta.
-- Wild = margem natural (grama/areia/neve, sem construções nem ruas) entre a cidade e a costa, com largura
-- variando de Min a Max: a cidade acaba antes do mar com um contorno irregular, como nas referências.
export type Coast = {
	Inset: number,
	Radius: number,
	Amplitude: number,
	Wavelength: number,
	Shore: number,
	Seed: number,
	Wild: { Min: number, Max: number, Wavelength: number }?,
}
-- Grade de ruas automática dentro de Rect: uma rua a cada Every = {x, z}, a partir de Offset;
-- Skip = chance de pular um trecho (quarteirões maiores e irregulares); Holes = retângulos sem ruas
-- (praças, estádio, aeroporto...).
export type StreetGrid = {
	Rect: Rect,
	Every: { number },
	Width: number,
	Offset: { number }?,
	Skip: number?,
	Holes: { Rect }?,
}

export type Plan = {
	Width: number,
	Depth: number,
	DefaultDistrict: string,
	Coast: Coast,
	FinalScale: number, -- tamanho no fim da cidade (dificuldade normal; Logic/ZoneBalance)
	Roads: { Line },
	Rivers: { Line },
	Streets: { StreetGrid }?,
	Areas: { Area },
	Districts: { District },
	Zones: { ZoneDef },
	Sites: { Site },
}

export type Placement = {
	Template: string,
	X: number,
	Y: number,
	Z: number,
	Rotation: number,
	Variant: number,
	Zone: number,
	Step: number, -- índice global da etapa (Layout.Steps)
	Cells: Rect, -- células ocupadas (com a folga)
	Kit: string?, -- microambiente (kit) de que faz parte: "Playground#3" (as peças de um kit ficam juntas)
}

export type Wall = { Size: { number }, Pos: { number } }
export type Barrier = { Zone: number, Size: { number }, Pos: { number } }
export type StepInfo = { Zone: number, Cap: number }

export type Grid = {
	Width: number,
	Depth: number,
	Kind: { string }, -- "Sea" = fora da terra (mar)
	Height: { number },
	Zone: { number }, -- 0 no mar
	Step: { number }, -- etapa global; 0 no mar
	District: { string },
	Edge: { boolean }, -- encosta numa célula de outra zona (ou no mar)
	Occupied: { boolean },
}

export type Layout = {
	Size: { number }, -- tamanho da grade em studs (X, Z)
	Grid: Grid,
	Placements: { Placement },
	Barriers: { Barrier },
	Walls: { Wall }, -- paredes invisíveis da costa
	Spawns: { { { number } } }, -- por zona: lista de {x, y, z} (na primeira etapa da zona)
	ZoneNames: { string },
	Steps: { StepInfo },
	Problems: { string }, -- marcos que não couberam (os testes exigem lista vazia)
	-- só no gerador planejado (Fill.Planner): distâncias mínimas por grupo e células reservadas de acesso
	-- (porta / entrada de carro na calçada: nada de poste, vaso ou banco em cima)
	Planner: Planner?,
	Index: Placement.Index?,
	Access: { [number]: boolean }?,
}

type Template = { Tier: number, Footprint: { number } }
type FillSpec = {
	Ground: string, -- tipo de célula onde as construções ficam
	BlockFill: number, -- chance de tentar uma construção em cada célula livre do miolo do quarteirão
	Buildings: { [string]: number },
	Nature: { [string]: number },
	NatureChance: number,
}
type Config = {
	CellSize: number,
	PlanUnit: number,
	WalkCells: number,
	HillRing: number,
	Heights: { [string]: number },
	LineTop: number,
	HillStep: number,
	Gap: number,
	FrontageTries: number,
	LampEvery: number,
	WildChance: number, -- árvores/moitas por célula na margem natural
	FarLampCap: number,
	TierSpan: number,
	PropChance: number,
	BarrierHeight: number,
	BarrierThickness: number,
	ColliderHeight: number,
	SpawnsPerZone: number,
}
type Rng = {
	next: (any) -> number,
	int: (any, number, number) -> number,
	weighted: (any, { [string]: number }) -> string,
}

export type Fill = {
	Districts: { [string]: FillSpec },
	Sidewalk: { [string]: number }, -- objetos de calçada (além dos postes)
	Parking: { [string]: number }, -- veículos nos estacionamentos
	Beach: { [string]: number }, -- objetos na areia
	Plaza: { [string]: number }, -- objetos nas praças
	Boats: { [string]: number }, -- barcos na água do porto
	BoatChance: number,
	Wild: { [string]: number }, -- natureza da margem antes do mar (Coast.Wild): destrutível, conta na área
	Planner: Planner?, -- gerador planejado (regras espaciais); nil = gerador antigo (sorteio por célula)
}

-- Grupo natural: Chance = chance de uma célula livre virar centro de grupo; Min/Max itens; Radius em células.
export type GroupSpec = { Chance: number, Min: number, Max: number, Radius: number }

-- Regras da cidade planejada (DistrictConfig). Ordem: construções -> acessos -> infraestrutura -> natureza
-- -> decoração de cada região. Catalog = Config/ModelCatalog.
export type Planner = {
	Catalog: Placement.Catalog,
	BlockReach: number, -- construção do miolo só até tantas células da calçada (mais fundo = quintal)
	FrontClear: number, -- faixa (células) junto da calçada sem árvore (não tampa a fachada)
	Groups: GroupSpec, -- grupos de natureza padrão
	DistrictGroups: { [string]: GroupSpec }?, -- por bairro (ex.: jardim da 1ª etapa mais cheio)
	DrivewayCar: number, -- chance de uma casa ter carro na entrada
	Houses: { [string]: boolean }, -- modelos que têm entrada de carro
	EntrancePots: number, -- chance de vasos ao lado da porta de lojas/cafés
	Storefronts: { [string]: boolean },
	Sidewalk: { [string]: number },
	SidewalkChance: number,
	Beach: { Anchor: { [string]: number }, Companions: { [string]: number }, NearWater: number, Group: GroupSpec },
	Runway: { [string]: number }, -- aviões na pista
	RunwayChance: number,
	Apron: { [string]: number }, -- aviões no pátio do aeroporto
	ApronChance: number,
	Wild: GroupSpec, -- grupos na margem antes do mar
	-- quintal das casas: chance de caixa de correio, cerca no fundo (a BackGap células) e planta atrás
	Yard: { Mailbox: number, Fence: number, BackGap: number, Plant: number, Plants: { [string]: number } }?,
	-- carros estacionados no meio-fio (só em ruas largas, longe de esquinas e portas)
	CurbCars: { Chance: number, Spacing: number, MinRoad: number }?,
	ParkingChance: number?, -- estacionamento: chance por célula (lotado = alto)
	PlazaChance: number?,
	Backs: { [string]: BackSpec }?, -- fundo e lados das construções (quintal, carga e descarga)
	Kits: { Kit }?, -- microambientes soltos (parquinho, praça, obra, pátio)
	FenceModel: string?, -- cerca dos quintais (padrão "Fence"; a Ice City usa a cerca com neve)
	Boost: { [string]: { [string]: number } }?, -- pesos extras de construção por bairro (DistrictConfig.fill)
}

-- Fundo e lados de uma construção. Fence/Gate/SideFence: chances da cerca do fundo, do portão nela e das
-- cercas laterais (só onde há Yard). Items: o que vai no quintal/pátio de trás (Count = {mín, máx}).
-- Side: o que vai ao lado da fachada, encostado na calçada (SideCount no máximo).
export type BackSpec = {
	Gate: number?,
	SideFence: number?,
	Items: { [string]: number }?,
	Count: { number }?,
	Depth: number?, -- células do pátio atrás (sem cerca)
	Side: { [string]: number }?,
	SideCount: number?,
}

-- Peça de kit: canto (X, Z) em células no espaço do kit (frente = Z 0, virada para a calçada), Rot em graus.
export type KitPiece = { Model: string, X: number, Z: number, Rot: number?, Chance: number? }
-- Microambiente: Size {W, D} em células; Districts = chance por célula livre de virar kit; Spacing (studs)
-- entre kits iguais; Front = a calçada (ou praça/pátio) precisa estar a até Front células da frente.
export type Kit = {
	Name: string,
	Ground: string,
	Districts: { [string]: number },
	Size: { number },
	Spacing: number,
	Front: number?,
	Pieces: { KitPiece },
}

local DIRS = { { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } }
-- rotação (graus em Y) que deixa a frente do modelo (-Z) virada para cada direção
local ROTATION_FOR = { [1] = 0, [2] = 180, [3] = 90, [4] = 270 }

local function index(grid: Grid, x: number, z: number): number?
	if x < 0 or z < 0 or x >= grid.Width or z >= grid.Depth then
		return nil
	end
	return z * grid.Width + x + 1
end

local function inRect(r: Rect, x: number, z: number): boolean
	return x >= r[1] and x < r[3] and z >= r[2] and z < r[4]
end

-- Centro de uma célula (ou de um retângulo de células) em studs.
function CityGen.cellToWorld(grid: Grid, cellSize: number, x: number, z: number): (number, number)
	return (x - grid.Width / 2) * cellSize, (z - grid.Depth / 2) * cellSize
end

local function paintLine(grid: Grid, line: Line, kind: string, heights: { [string]: number }, bridge: boolean)
	local w = line.Width
	for s = 1, #line.Points - 1 do
		local a, b = line.Points[s], line.Points[s + 1]
		local length = math.max(math.abs(b[1] - a[1]), math.abs(b[2] - a[2]))
		local steps = math.max(1, math.ceil(length * 4))
		for k = 0, steps do
			local t = k / steps
			local px, pz = a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t
			for cx = math.floor(px - w / 2 + 0.5), math.floor(px + w / 2 - 0.5) do
				for cz = math.floor(pz - w / 2 + 0.5), math.floor(pz + w / 2 - 0.5) do
					local i = index(grid, cx, cz)
					-- nada é pintado no mar
					if i and grid.Kind[i] ~= "Sea" and (bridge or grid.Kind[i] ~= "Road") then
						grid.Kind[i] = kind
						grid.Height[i] = heights[kind]
					end
				end
			end
		end
	end
end

-- Rio com cara de rio (referências de rio de cidade): a linha da planta vira uma curva suave (Catmull-Rom)
-- pintada com pincel redondo, então as margens ficam arredondadas em vez de degraus retos.
local function paintRiver(grid: Grid, line: Line, heights: { [string]: number })
	local pts = line.Points
	local r = line.Width / 2
	local function at(i: number): { number }
		return pts[math.clamp(i, 1, #pts)]
	end
	for s = 1, #pts - 1 do
		local p0, p1, p2, p3 = at(s - 1), at(s), at(s + 1), at(s + 2)
		local length = math.sqrt((p2[1] - p1[1]) ^ 2 + (p2[2] - p1[2]) ^ 2)
		local steps = math.max(1, math.ceil(length * 3))
		for k = 0, steps do
			local t = k / steps
			local t2, t3 = t * t, t * t * t
			local function cr(a: number, b: number, c: number, d: number): number
				return 0.5 * (2 * b + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t2 + (-a + 3 * b - 3 * c + d) * t3)
			end
			local px, pz = cr(p0[1], p1[1], p2[1], p3[1]), cr(p0[2], p1[2], p2[2], p3[2])
			for cx = math.floor(px - r), math.ceil(px + r) do
				for cz = math.floor(pz - r), math.ceil(pz + r) do
					if (cx + 0.5 - px) ^ 2 + (cz + 0.5 - pz) ^ 2 <= r * r then
						local i = index(grid, cx, cz)
						if i and grid.Kind[i] ~= "Sea" and grid.Kind[i] ~= "Road" then
							grid.Kind[i] = "Water"
							grid.Height[i] = heights.Water
						end
					end
				end
			end
		end
	end
end

-- Ruído suave determinístico (inteiros + bit32: igual no Lune e no Roblox), em [0, 1).
local function hash(ix: number, iz: number, seed: number): number
	local h = (ix * 73856093 + iz * 19349663 + seed * 83492791) % 4294967296
	h = bit32.bxor(h, bit32.rshift(h, 13))
	h = (h * 1274126177) % 4294967296
	h = bit32.bxor(h, bit32.rshift(h, 16))
	return h / 4294967296
end

local function valueNoise(x: number, z: number, seed: number): number
	local ix, iz = math.floor(x), math.floor(z)
	local fx, fz = x - ix, z - iz
	local ux, uz = fx * fx * (3 - 2 * fx), fz * fz * (3 - 2 * fz)
	local a, b = hash(ix, iz, seed), hash(ix + 1, iz, seed)
	local c, d = hash(ix, iz + 1, seed), hash(ix + 1, iz + 1, seed)
	local top = a + (b - a) * ux
	local bottom = c + (d - c) * ux
	return top + (bottom - top) * uz
end

function CityGen.coastNoise(x: number, z: number, wavelength: number, seed: number): number
	return 0.65 * valueNoise(x / wavelength, z / wavelength, seed)
		+ 0.35 * valueNoise(x / (wavelength * 0.43), z / (wavelength * 0.43), seed + 17)
end

-- Terra: retângulo arredondado (afastado Inset da borda) com a costa ondulada. Depois tira lagos presos
-- na terra e ilhotas soltas (só fica a ilha principal, ligada).
local function landMask(width: number, depth: number, coast: Coast): { boolean }
	local land: { boolean } = {}
	local cx, cz = width / 2, depth / 2
	local hx, hz = width / 2 - coast.Inset, depth / 2 - coast.Inset
	local r = math.min(coast.Radius, hx, hz)
	for z = 0, depth - 1 do
		for x = 0, width - 1 do
			local qx = math.abs(x + 0.5 - cx) - (hx - r)
			local qz = math.abs(z + 0.5 - cz) - (hz - r)
			local outside = math.sqrt(math.max(qx, 0) ^ 2 + math.max(qz, 0) ^ 2)
			local sd = outside + math.min(math.max(qx, qz), 0) - r
			local wobble = coast.Amplitude * (2 * CityGen.coastNoise(x, z, coast.Wavelength, coast.Seed) - 1)
			land[z * width + x + 1] = sd + wobble < 0
		end
	end
	-- mar ligado à borda (o que não estiver ligado vira terra)
	local function flood(start: { number }, passable: (number) -> boolean): { [number]: boolean }
		local seen: { [number]: boolean } = {}
		local queue = start
		for _, i in queue do
			seen[i] = true
		end
		local head = 1
		while head <= #queue do
			local i = queue[head]
			head += 1
			local x, z = (i - 1) % width, (i - 1) // width
			for _, d in { { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } } do
				local nx, nz = x + d[1], z + d[2]
				if nx >= 0 and nz >= 0 and nx < width and nz < depth then
					local j = nz * width + nx + 1
					if not seen[j] and passable(j) then
						seen[j] = true
						table.insert(queue, j)
					end
				end
			end
		end
		return seen
	end
	local border = {}
	for x = 0, width - 1 do
		for _, z in { 0, depth - 1 } do
			local i = z * width + x + 1
			if not land[i] then
				table.insert(border, i)
			end
		end
	end
	for z = 0, depth - 1 do
		for _, x in { 0, width - 1 } do
			local i = z * width + x + 1
			if not land[i] then
				table.insert(border, i)
			end
		end
	end
	local sea = flood(border, function(j)
		return not land[j]
	end)
	for i = 1, width * depth do
		land[i] = not sea[i]
	end
	-- só a ilha principal (a que tem o centro)
	local center = math.floor(cz) * width + math.floor(cx) + 1
	local main = flood({ center }, function(j)
		return land[j]
	end)
	for i = 1, width * depth do
		land[i] = main[i] == true
	end
	return land
end

local function newGrid(plan: Plan, cfg: Config): (Grid, { StepInfo })
	local grid: Grid = {
		Width = plan.Width,
		Depth = plan.Depth,
		Kind = {},
		Height = {},
		Zone = {},
		Step = {},
		District = {},
		Edge = {},
		Occupied = {},
	}
	local land = landMask(plan.Width, plan.Depth, plan.Coast)
	for i = 1, plan.Width * plan.Depth do
		grid.Kind[i] = if land[i] then "Lot" else "Sea"
		grid.Height[i] = if land[i] then cfg.Heights.Lot else cfg.Heights.Sea
		grid.Zone[i] = if land[i] then #plan.Zones else 0
		grid.Step[i] = 0
		grid.District[i] = if land[i] then plan.DefaultDistrict else ""
		grid.Edge[i] = false
		grid.Occupied[i] = false
	end

	-- 0. orla: terra a até Shore células do mar (contando diagonais) vira areia
	local shore = plan.Coast.Shore
	if shore > 0 then
		local sand = {}
		for z = 0, grid.Depth - 1 do
			for x = 0, grid.Width - 1 do
				local i = index(grid, x, z) :: number
				if land[i] then
					local near = false
					for dx = -shore, shore do
						for dz = -shore, shore do
							local j = index(grid, x + dx, z + dz)
							if j and not land[j] then
								near = true
							end
						end
					end
					if near then
						sand[i] = true
					end
				end
			end
		end
		for i in sand do
			grid.Kind[i] = "Sand"
			grid.Height[i] = cfg.Heights.Sand
		end
	end

	-- 1. áreas especiais (o morro sobe em anéis)
	for _, area in plan.Areas do
		local r = area.Rect
		for x = r[1], r[3] - 1 do
			for z = r[2], r[4] - 1 do
				local i = index(grid, x, z)
				if i and land[i] then
					if area.Kind == "Hill" then
						local ring = math.min(x - r[1], r[3] - 1 - x, z - r[2], r[4] - 1 - z) // cfg.HillRing
						grid.Kind[i] = "Lot"
						grid.Height[i] = cfg.Heights.Lot + math.min(ring, (area.Levels or 4) - 1) * cfg.HillStep
					else
						grid.Kind[i] = area.Kind
						grid.Height[i] = cfg.Heights[area.Kind]
					end
				end
			end
		end
	end
	-- 2. rios e ruas (rua por cima do rio = ponte)
	for _, river in plan.Rivers do
		paintRiver(grid, river, cfg.Heights)
	end
	for _, road in plan.Roads do
		paintLine(grid, road, "Road", cfg.Heights, true)
	end
	-- 3. calçadas: grama no chão (sem morro) encostada numa rua, inclusive na diagonal
	local walks = {}
	for z = 0, grid.Depth - 1 do
		for x = 0, grid.Width - 1 do
			local i = index(grid, x, z) :: number
			if grid.Kind[i] == "Lot" and grid.Height[i] == cfg.Heights.Lot then
				for dx = -cfg.WalkCells, cfg.WalkCells do
					for dz = -cfg.WalkCells, cfg.WalkCells do
						local j = index(grid, x + dx, z + dz)
						if j and grid.Kind[j] == "Road" then
							walks[i] = true
						end
					end
				end
			end
		end
	end
	for i in walks do
		grid.Kind[i] = "Walk"
		grid.Height[i] = cfg.Heights.Walk
	end
	-- 3a. margem de pedra (cais) em volta de rios, lagos e portos: o rio fica mais baixo que o chão
	-- (CityConfig.Heights.Water) e a margem mais alta, como um canal de cidade
	local banks = {}
	for z = 0, grid.Depth - 1 do
		for x = 0, grid.Width - 1 do
			local i = index(grid, x, z) :: number
			local kind = grid.Kind[i]
			if (kind == "Lot" or kind == "Walk") and grid.Height[i] == cfg.Heights[kind] then
				for dx = -1, 1 do
					for dz = -1, 1 do
						local j = index(grid, x + dx, z + dz)
						if j and grid.Kind[j] == "Water" then
							banks[i] = true
						end
					end
				end
			end
		end
	end
	for i in banks do
		grid.Kind[i] = "Bank"
		grid.Height[i] = cfg.Heights.Bank
	end
	-- 3b. margem natural: perto da costa (largura sorteada pelo ruído) o chão volta a ser natureza e as ruas
	-- acabam antes do mar. Rio, orla, pista e pátios ficam (o rio continua até o mar).
	local wild = plan.Coast.Wild
	if wild then
		local dist: { number } = {}
		local queue = {}
		for i = 1, grid.Width * grid.Depth do
			if not land[i] then
				dist[i] = 0
				table.insert(queue, i)
			end
		end
		local head = 1
		while head <= #queue do
			local i = queue[head]
			head += 1
			if dist[i] > wild.Max then
				continue
			end
			local x, z = (i - 1) % grid.Width, (i - 1) // grid.Width
			for dx = -1, 1 do
				for dz = -1, 1 do
					local j = index(grid, x + dx, z + dz)
					if j and dist[j] == nil then
						dist[j] = dist[i] + 1
						table.insert(queue, j)
					end
				end
			end
		end
		local natural = { Lot = true, Road = true, Walk = true, Plaza = true }
		for z = 0, grid.Depth - 1 do
			for x = 0, grid.Width - 1 do
				local i = index(grid, x, z) :: number
				local d = dist[i]
				local band = wild.Min
					+ (wild.Max - wild.Min) * CityGen.coastNoise(x, z, wild.Wavelength, plan.Coast.Seed + 5)
				local flat = grid.Height[i] == cfg.Heights[grid.Kind[i]] -- morro (Lot mais alto) fica
				if land[i] and d and d <= band and natural[grid.Kind[i]] and flat then
					grid.Kind[i] = "Wild"
					grid.Height[i] = cfg.Heights.Wild
				end
			end
		end
	end
	-- 4. bairros, zonas e etapas (só na terra)
	local steps: { StepInfo } = {}
	local firstStep: { number } = {}
	for zoneIndex, zone in plan.Zones do
		firstStep[zoneIndex] = #steps + 1
		for _, step in zone.Steps do
			table.insert(steps, { Zone = zoneIndex, Cap = step.Cap })
		end
	end
	for z = 0, grid.Depth - 1 do
		for x = 0, grid.Width - 1 do
			local i = index(grid, x, z) :: number
			if not land[i] then
				continue
			end
			for _, district in plan.Districts do
				if inRect(district.Rect, x, z) then
					grid.District[i] = district.Kind
				end
			end
			for _, area in plan.Areas do
				if area.District and inRect(area.Rect, x, z) then
					grid.District[i] = area.District
				end
			end
			for zoneIndex, zone in plan.Zones do
				local found = false
				for _, r in zone.Rects do
					if inRect(r, x, z) then
						found = true
					end
				end
				if found then
					grid.Zone[i] = zoneIndex
					break
				end
			end
			-- etapa: a primeira cujos retângulos têm a célula; senão a última da zona
			local zone = plan.Zones[grid.Zone[i]]
			local chosen = #zone.Steps
			for stepIndex, step in zone.Steps do
				local found = false
				for _, r in step.Rects or {} do
					if inRect(r, x, z) then
						found = true
					end
				end
				if found then
					chosen = stepIndex
					break
				end
			end
			grid.Step[i] = firstStep[grid.Zone[i]] + chosen - 1
		end
	end
	for z = 0, grid.Depth - 1 do
		for x = 0, grid.Width - 1 do
			local i = index(grid, x, z) :: number
			for _, d in DIRS do
				local j = index(grid, x + d[1], z + d[2])
				if j and grid.Zone[j] ~= grid.Zone[i] then
					grid.Edge[i] = true
				end
			end
		end
	end
	return grid, steps
end

-- Tamanho do modelo em células (com a folga), já girado. Objetos pequenos (tier 1) não precisam de folga.
local function cellsFor(template: Template, rotation: number, cfg: Config): (number, number)
	local w, d = template.Footprint[1], template.Footprint[2]
	if rotation % 180 ~= 0 then
		w, d = d, w
	end
	local gap = if template.Tier <= 1 then 0 else cfg.Gap
	return math.ceil((w + gap) / cfg.CellSize - 0.001), math.ceil((d + gap) / cfg.CellSize - 0.001)
end

-- Todas as células livres, do mesmo tipo de chão, mesma altura, mesma zona e etapa e longe da borda da zona?
-- ground = nil: qualquer tipo de chão (sem rua, calçada nem mar) e qualquer altura.
local function fits(grid: Grid, r: Rect, ground: string?, district: string?): boolean
	local height, step = nil, nil
	for x = r[1], r[3] - 1 do
		for z = r[2], r[4] - 1 do
			local i = index(grid, x, z)
			if i == nil or grid.Occupied[i] or grid.Edge[i] then
				return false
			end
			local kind = grid.Kind[i]
			if
				(ground and kind ~= ground) or (ground == nil and (kind == "Road" or kind == "Walk" or kind == "Sea"))
			then
				return false
			end
			if district and grid.District[i] ~= district then
				return false
			end
			height = height or grid.Height[i]
			step = step or grid.Step[i]
			if (ground and grid.Height[i] ~= height) or grid.Step[i] ~= step then
				return false
			end
		end
	end
	return true
end

local function occupy(layout: Layout, rng: Rng, cfg: Config, name: string, r: Rect, rotation: number)
	local grid = layout.Grid
	for x = r[1], r[3] - 1 do
		for z = r[2], r[4] - 1 do
			grid.Occupied[index(grid, x, z) :: number] = true
		end
	end
	local first = index(grid, r[1], r[2]) :: number
	local top = 0
	for x = r[1], r[3] - 1 do
		for z = r[2], r[4] - 1 do
			top = math.max(top, grid.Height[index(grid, x, z) :: number])
		end
	end
	local cx, cz = CityGen.cellToWorld(grid, cfg.CellSize, (r[1] + r[3]) / 2, (r[2] + r[4]) / 2)
	table.insert(layout.Placements, {
		Template = name,
		X = cx,
		Y = top,
		Z = cz,
		Rotation = rotation,
		Variant = rng:int(1, 1000000),
		Zone = grid.Zone[first],
		Step = grid.Step[first],
		Cells = r,
	})
	if layout.Index and layout.Planner then
		Placement.register(layout.Index, layout.Planner.Catalog, name, cx, cz)
	end
end

-- Escolhe um modelo do sorteio entre os tamanhos minTier..cap da etapa.
local function pick(
	rng: Rng,
	templates: { [string]: Template },
	mix: { [string]: number },
	cap: number,
	minTier: number?,
	filter: ((string) -> boolean)?
): string?
	local allowed = {}
	for name, weight in mix do
		local template = templates[name]
		if
			template
			and template.Tier <= cap
			and template.Tier >= (minTier or 1)
			and (filter == nil or filter(name))
		then
			allowed[name] = weight
		end
	end
	if next(allowed) == nil then
		return nil
	end
	return rng:weighted(allowed)
end

-- Maior tamanho de construção permitido numa célula (o da etapa dela).
local function capAt(layout: Layout, i: number): number
	local step = layout.Steps[layout.Grid.Step[i]]
	return if step then step.Cap else 0
end

-- Menor tamanho que ainda aparece na etapa: coisas muito menores que o jogador não aparecem mais
-- (seriam só peças a mais, sem efeito no jogo). Postes ficam em todo lugar.
local function minAt(layout: Layout, i: number, cfg: Config): number
	return math.max(1, capAt(layout, i) - cfg.TierSpan)
end

local function placeSites(layout: Layout, plan: Plan, templates: { [string]: Template }, rng: Rng, cfg: Config)
	local grid = layout.Grid
	for _, site in plan.Sites do
		local template = templates[site.Template]
		local rotation = site.Rotation or 0
		if template == nil then
			table.insert(layout.Problems, `modelo desconhecido: {site.Template}`)
			continue
		end
		local cw, cd = cellsFor(template, rotation, cfg)
		local x0, z0 = math.floor(site.X - cw / 2 + 0.5), math.floor(site.Z - cd / 2 + 0.5)
		local r = { x0, z0, x0 + cw, z0 + cd }
		local i = index(grid, x0, z0)
		local ground: string? = if site.AnyGround then nil elseif i then grid.Kind[i] else "?"
		if ground == "Road" or ground == "Walk" or ground == "Sea" then
			ground = "?" -- marco nunca fica em rua, calçada ou mar
		end
		if i == nil or not fits(grid, r, ground, nil) then
			table.insert(layout.Problems, `{site.Template} não cabe em ({site.X}, {site.Z})`)
			continue
		end
		local cap = capAt(layout, i :: number)
		if template.Tier > cap then
			local zone = plan.Zones[grid.Zone[i :: number]]
			table.insert(layout.Problems, `{site.Template} é grande demais para a etapa (máx {cap}) de {zone.Name}`)
		end
		occupy(layout, rng, cfg, site.Template, r, rotation)
	end
end

-- Centro (studs) de um retângulo de células.
local function centerOf(layout: Layout, cfg: Config, r: Rect): (number, number)
	return CityGen.cellToWorld(layout.Grid, cfg.CellSize, (r[1] + r[3]) / 2, (r[2] + r[4]) / 2)
end

-- Gerador planejado: o modelo respeita o catálogo (chão, bairro, distância do mesmo grupo) em `r`?
local function planOk(layout: Layout, cfg: Config, name: string, r: Rect): boolean
	local planner, idx = layout.Planner, layout.Index
	if planner == nil or idx == nil then
		return true
	end
	local i = index(layout.Grid, r[1], r[2])
	if i == nil then
		return false
	end
	if not Placement.allowed(planner.Catalog, name, layout.Grid.Kind[i], layout.Grid.District[i]) then
		return false
	end
	local cx, cz = centerOf(layout, cfg, r)
	return Placement.spaced(idx, planner.Catalog, name, cx, cz)
end

-- Tenta colocar `name` no retângulo que começa em (x0, z0); devolve o retângulo se colocou.
local function tryPlace(
	layout: Layout,
	templates: { [string]: Template },
	rng: Rng,
	cfg: Config,
	name: string,
	x0: number,
	z0: number,
	rotation: number,
	ground: string?,
	district: string?
): Rect?
	local template = templates[name]
	if template == nil then
		return nil
	end
	local cw, cd = cellsFor(template, rotation, cfg)
	local r = { x0, z0, x0 + cw, z0 + cd }
	if fits(layout.Grid, r, ground, district) and planOk(layout, cfg, name, r) then
		occupy(layout, rng, cfg, name, r, rotation)
		return r
	end
	return nil
end

-- No gerador planejado, frente de rua e miolo só recebem construções e barraquinhas (carro, árvore, banco e
-- guarda-sol têm lugar próprio).
local function buildingFilter(layout: Layout): ((string) -> boolean)?
	local planner = layout.Planner
	if planner == nil then
		return nil
	end
	return function(name: string): boolean
		local category = Placement.category(planner.Catalog, name)
		return category == "Building" or category == "Stall"
	end
end

-- Quintal / pátio de trás: itens na faixa entre o fundo da construção e a cerca (ou `depth` células), cada um
-- num ponto sorteado da faixa (casinha de cachorro, varal, churrasqueira; caixas, barris e caçamba nas lojas).
local function dressBack(
	layout: Layout,
	templates: { [string]: Template },
	rng: Rng,
	cfg: Config,
	spec: BackSpec,
	r: Rect,
	d: { number },
	depth: number,
	rotation: number
)
	local items = spec.Items
	if items == nil or depth <= 0 then
		return
	end
	local grid = layout.Grid
	local i = index(grid, r[1], r[2]) :: number
	local ground, district = grid.Kind[i], grid.District[i]
	local strip: Rect
	if d[1] == 0 then
		strip = if d[2] < 0 then { r[1], r[4], r[3], r[4] + depth } else { r[1], r[2] - depth, r[3], r[2] }
	else
		strip = if d[1] < 0 then { r[3], r[2], r[3] + depth, r[4] } else { r[1] - depth, r[2], r[1], r[4] }
	end
	local sw, sd = strip[3] - strip[1], strip[4] - strip[2]
	local count = spec.Count or { 1, 2 }
	for _ = 1, rng:int(count[1], count[2]) do
		local name = pick(rng, templates, items, capAt(layout, i))
		if name == nil then
			break
		end
		for _ = 1, 8 do
			local rot = (rotation + (if rng:next() < 0.5 then 0 else 90)) % 360
			local cw, cd = cellsFor(templates[name], rot, cfg)
			if cw <= sw and cd <= sd then
				local x0, z0 = strip[1] + rng:int(0, sw - cw), strip[2] + rng:int(0, sd - cd)
				if tryPlace(layout, templates, rng, cfg, name, x0, z0, rot, ground, district) then
					break
				end
			end
		end
	end
end

-- Ao lado da fachada, encostado na calçada: carrinhos no mercado, bombas no posto, bicicletário na loja.
local function dressSides(
	layout: Layout,
	templates: { [string]: Template },
	rng: Rng,
	cfg: Config,
	spec: BackSpec,
	r: Rect,
	d: { number },
	rotation: number
)
	local grid = layout.Grid
	local i = index(grid, r[1], r[2]) :: number
	local ground, district = grid.Kind[i], grid.District[i]
	local offset = { [-1] = 0, [1] = 0 }
	local placed = 0
	for _ = 1, (spec.SideCount or 1) * 2 do
		if placed >= (spec.SideCount or 1) then
			break
		end
		local name = pick(rng, templates, spec.Side :: { [string]: number }, capAt(layout, i))
		if name == nil then
			break
		end
		local side = if rng:next() < 0.5 then -1 else 1
		local cw, cd = cellsFor(templates[name], rotation, cfg)
		local x0, z0
		if d[1] == 0 then
			x0 = if side < 0 then r[1] - cw - offset[side] else r[3] + offset[side]
			z0 = if d[2] < 0 then r[2] else r[4] - cd
		else
			z0 = if side < 0 then r[2] - cd - offset[side] else r[4] + offset[side]
			x0 = if d[1] < 0 then r[1] else r[3] - cw
		end
		if tryPlace(layout, templates, rng, cfg, name, x0, z0, rotation, ground, district) then
			offset[side] += if d[1] == 0 then cw else cd
			placed += 1
		end
	end
end

-- Construção de frente para a calçada na direção `dirIndex`: reserva a calçada na frente da porta (nada em
-- cima), põe carro na entrada (casas) e vasos ao lado da porta (lojas). Só no gerador planejado.
local function dressFront(
	layout: Layout,
	templates: { [string]: Template },
	rng: Rng,
	cfg: Config,
	name: string,
	r: Rect,
	dirIndex: number
)
	local planner, access = layout.Planner, layout.Access
	if planner == nil or access == nil or Placement.category(planner.Catalog, name) ~= "Building" then
		return
	end
	local grid = layout.Grid
	local d = DIRS[dirIndex]
	-- células de calçada logo na frente: o meio da fachada (porta) e as vizinhas
	local mx, mz = (r[1] + r[3] - 1) // 2, (r[2] + r[4] - 1) // 2
	local fx = if d[1] < 0 then r[1] - 1 elseif d[1] > 0 then r[3] else mx
	local fz = if d[2] < 0 then r[2] - 1 elseif d[2] > 0 then r[4] else mz
	local ax, az = math.abs(d[2]), math.abs(d[1]) -- ao longo da fachada
	for k = -1, 1 do
		local j = index(grid, fx + ax * k, fz + az * k)
		if j and grid.Kind[j] == "Walk" then
			access[j] = true
		end
	end
	-- um vaso ao lado da porta (lojas e cafés), na calçada; o lado varia
	if planner.Storefronts[name] and rng:next() < planner.EntrancePots then
		local k = if rng:next() < 0.5 then -2 else 2
		local x, z = fx + ax * k, fz + az * k
		local j = index(grid, x, z)
		if j and not access[j] then
			tryPlace(layout, templates, rng, cfg, "FlowerPot", x, z, 0, "Walk", nil)
		end
	end
	-- quintal completo das casas: caixa de correio na calçada, cerca no fundo do lote e uma planta atrás
	local yard = planner.Yard
	local back = if planner.Backs then planner.Backs[name] else nil
	local backDepth = if back then back.Depth or 0 else 0
	if planner.Houses[name] and yard then
		backDepth = yard.BackGap
		local i = index(grid, r[1], r[2]) :: number
		local ground, district = grid.Kind[i], grid.District[i]
		if rng:next() < yard.Mailbox then
			local k = if rng:next() < 0.5 then -2 else 2
			local x, z = fx + ax * k, fz + az * k
			local j = index(grid, x, z)
			if j and not access[j] then
				tryPlace(layout, templates, rng, cfg, "Mailbox", x, z, 0, "Walk", nil)
			end
		end
		local fenceName = planner.FenceModel or "Fence"
		if rng:next() < yard.Fence and templates[fenceName] then
			-- cerca deitada ao longo do fundo do lote (paralela à fachada), um pedaço atrás do outro; se o fundo
			-- já tem algo, a linha chega mais perto da casa (até encostar). Um pedaço do meio pode ser portão.
			local rotation = if d[1] == 0 then 0 else 90
			local fw, fd = cellsFor(templates[fenceName], rotation, cfg)
			local pieces = if d[1] == 0 then (r[3] - r[1]) // fw else (r[4] - r[2]) // fd
			local gateAt = if back
					and templates.Gate
					and rng:next() < (back.Gate or 0)
				then math.max(1, (pieces + 1) // 2)
				else 0
			for gap = yard.BackGap, 0, -1 do
				local placed = 0
				for k = 1, pieces do
					local model = if k == gateAt then "Gate" else fenceName
					local x0 = if d[1] == 0
						then r[1] + (k - 1) * fw
						else (if d[1] < 0 then r[3] + gap else r[1] - gap - 1)
					local z0 = if d[1] == 0
						then (if d[2] < 0 then r[4] + gap else r[2] - gap - 1)
						else r[2] + (k - 1) * fd
					if tryPlace(layout, templates, rng, cfg, model, x0, z0, rotation, ground, district) then
						placed += 1
					end
				end
				if placed > 0 then
					backDepth = gap
					-- cercas laterais fecham o quintal (quando ele tem a fundura de um pedaço de cerca)
					local sw, sd = cellsFor(templates[fenceName], (rotation + 90) % 180, cfg)
					local long = if d[1] == 0 then sd else sw
					if back and gap >= long and rng:next() < (back.SideFence or 0) then
						for _, side in { -1, 1 } do
							local sx, sz
							if d[1] == 0 then
								sx = if side < 0 then r[1] - sw else r[3]
								sz = if d[2] < 0 then r[4] + gap - sd else r[2] - gap
							else
								sz = if side < 0 then r[2] - sd else r[4]
								sx = if d[1] < 0 then r[3] + gap - sw else r[1] - gap
							end
							tryPlace(
								layout,
								templates,
								rng,
								cfg,
								fenceName,
								sx,
								sz,
								(rotation + 90) % 180,
								ground,
								district
							)
						end
					end
					break
				end
			end
		end
		if rng:next() < yard.Plant then
			local plant = pick(rng, templates, yard.Plants, capAt(layout, i), minAt(layout, i, cfg))
			if plant then
				-- no meio do quintal, logo atrás da casa (entre a casa e a cerca)
				local rotation = rng:int(0, 3) * 90
				local pw, pd = cellsFor(templates[plant], rotation, cfg)
				local px = if d[1] == 0 then mx else (if d[1] < 0 then r[3] else r[1] - pw)
				local pz = if d[2] == 0 then mz else (if d[2] < 0 then r[4] else r[2] - pd)
				tryPlace(layout, templates, rng, cfg, plant, px, pz, rotation, ground, district)
			end
		end
	end
	if back then
		dressBack(layout, templates, rng, cfg, back, r, d, backDepth, ROTATION_FOR[dirIndex])
	end
	-- carro na entrada: ao lado da casa, encostado na calçada, virado para a rua
	local car = templates.Car
	local i0 = index(grid, r[1], r[2]) :: number
	if
		planner.Houses[name]
		and car
		and car.Tier <= capAt(layout, i0)
		and car.Tier >= minAt(layout, i0, cfg)
		and rng:next() < planner.DrivewayCar
	then
		local i = i0
		local rotation = ROTATION_FOR[dirIndex]
		local cw, cd = cellsFor(car, rotation, cfg)
		for _, side in { 1, -1 } do
			local x0, z0
			if d[1] == 0 then
				x0 = if side > 0 then r[3] else r[1] - cw
				z0 = if d[2] < 0 then r[2] else r[4] - cd
			else
				z0 = if side > 0 then r[4] else r[2] - cd
				x0 = if d[1] < 0 then r[1] else r[3] - cw
			end
			-- a frente do carro precisa dar na calçada (na esquina a calçada acaba antes)
			local fx0 = if d[1] < 0 then x0 - 1 elseif d[1] > 0 then x0 + cw else x0
			local fz0 = if d[2] < 0 then z0 - 1 elseif d[2] > 0 then z0 + cd else z0
			local facing = index(grid, fx0, fz0)
			if
				facing
				and grid.Kind[facing] == "Walk"
				and tryPlace(layout, templates, rng, cfg, "Car", x0, z0, rotation, grid.Kind[i], grid.District[i])
			then
				break
			end
		end
	end
	if back and back.Side then
		dressSides(layout, templates, rng, cfg, back, r, d, ROTATION_FOR[dirIndex])
	end
end

-- Terrenos de frente para a rua: cada célula de grama encostada numa calçada recebe uma construção virada
-- para a calçada (se couber).
local function fillFrontage(layout: Layout, fill: Fill, templates: { [string]: Template }, rng: Rng, cfg: Config)
	local grid = layout.Grid
	local filter = buildingFilter(layout)
	local fronts = {}
	for z = 0, grid.Depth - 1 do
		for x = 0, grid.Width - 1 do
			local i = index(grid, x, z) :: number
			if grid.Kind[i] ~= "Walk" then
				for dirIndex, d in DIRS do
					local j = index(grid, x + d[1], z + d[2])
					if j and grid.Kind[j] == "Walk" then
						table.insert(fronts, { x, z, dirIndex })
						break
					end
				end
			end
		end
	end
	-- ordem embaralhada (determinística) para a cidade não ficar repetitiva
	for k = #fronts, 2, -1 do
		local j = rng:int(1, k)
		fronts[k], fronts[j] = fronts[j], fronts[k]
	end
	for _, front in fronts do
		local x, z, dirIndex = front[1], front[2], front[3]
		local i = index(grid, x, z) :: number
		local spec = fill.Districts[grid.District[i]]
		if spec == nil or grid.Occupied[i] or grid.Kind[i] ~= spec.Ground then
			continue
		end
		local cap = capAt(layout, i)
		local rotation = ROTATION_FOR[dirIndex]
		local d = DIRS[dirIndex]
		for _ = 1, cfg.FrontageTries do
			local name = pick(rng, templates, spec.Buildings, cap, minAt(layout, i, cfg), filter)
			if name == nil then
				break
			end
			local cw, cd = cellsFor(templates[name], rotation, cfg)
			-- frente encostada na calçada; centrado na célula ao longo da calçada
			local x0, z0
			if d[1] == 0 then
				x0 = x - (cw - 1) // 2
				z0 = if d[2] < 0 then z else z - cd + 1
			else
				z0 = z - (cd - 1) // 2
				x0 = if d[1] < 0 then x else x - cw + 1
			end
			local r = tryPlace(layout, templates, rng, cfg, name, x0, z0, rotation, spec.Ground, grid.District[i])
			if r then
				dressFront(layout, templates, rng, cfg, name, r, dirIndex)
				break
			end
		end
	end
end

-- Direção (índice em DIRS) da calçada mais perto, olhando em linha reta até `reach` células.
local function nearestWalk(grid: Grid, x: number, z: number, reach: number): number?
	for distance = 1, reach do
		for dirIndex, d in DIRS do
			local j = index(grid, x + d[1] * distance, z + d[2] * distance)
			if j and (grid.Kind[j] == "Walk" or grid.Kind[j] == "Road") then
				return dirIndex
			end
		end
	end
	return nil
end

-- Miolo dos quarteirões: mais construções do bairro, viradas para a calçada mais perto (cidade cheia).
-- Planejado: só até BlockReach células da calçada (mais fundo vira quintal / jardim, sem prédio sem acesso).
local function fillBlocks(layout: Layout, fill: Fill, templates: { [string]: Template }, rng: Rng, cfg: Config)
	local grid = layout.Grid
	local filter = buildingFilter(layout)
	local reach = if layout.Planner then layout.Planner.BlockReach else 20
	for z = 0, grid.Depth - 1 do
		for x = 0, grid.Width - 1 do
			local i = index(grid, x, z) :: number
			local spec = fill.Districts[grid.District[i]]
			if spec and not grid.Occupied[i] and grid.Kind[i] == spec.Ground and rng:next() < spec.BlockFill then
				local dirIndex = nearestWalk(grid, x, z, reach)
				if dirIndex == nil and layout.Planner then
					continue
				end
				local rotation = ROTATION_FOR[dirIndex or rng:int(1, 4)]
				for _ = 1, cfg.FrontageTries do
					local name = pick(rng, templates, spec.Buildings, capAt(layout, i), minAt(layout, i, cfg), filter)
					if name == nil then
						break
					end
					if tryPlace(layout, templates, rng, cfg, name, x, z, rotation, spec.Ground, grid.District[i]) then
						break
					end
				end
			end
		end
	end
end

-- Miolo dos terrenos: natureza (e o que o bairro quiser) espalhada no que sobrou.
local function fillInterior(layout: Layout, fill: Fill, templates: { [string]: Template }, rng: Rng, cfg: Config)
	local grid = layout.Grid
	for z = 0, grid.Depth - 1 do
		for x = 0, grid.Width - 1 do
			local i = index(grid, x, z) :: number
			local spec = fill.Districts[grid.District[i]]
			if spec and not grid.Occupied[i] and grid.Kind[i] == spec.Ground and rng:next() < spec.NatureChance then
				local name = pick(rng, templates, spec.Nature, capAt(layout, i), minAt(layout, i, cfg))
				if name then
					local rotation = rng:int(0, 3) * 90
					local cw, cd = cellsFor(templates[name], rotation, cfg)
					local r = { x, z, x + cw, z + cd }
					if fits(grid, r, spec.Ground, nil) then
						occupy(layout, rng, cfg, name, r, rotation)
					end
				end
			end
		end
	end
end

-- Objetos espalhados num tipo de chão (areia, praça, estacionamento, água do porto).
local function scatter(
	layout: Layout,
	templates: { [string]: Template },
	rng: Rng,
	cfg: Config,
	ground: string,
	mix: { [string]: number },
	chance: number,
	district: string?
)
	local grid = layout.Grid
	for z = 0, grid.Depth - 1 do
		for x = 0, grid.Width - 1 do
			local i = index(grid, x, z) :: number
			if
				grid.Kind[i] == ground
				and not grid.Occupied[i]
				and (district == nil or grid.District[i] == district)
				and rng:next() < chance
			then
				local name = pick(rng, templates, mix, capAt(layout, i), minAt(layout, i, cfg))
				if name then
					-- planejado: estacionamento com todos os carros alinhados (mesma direção)
					local rotation = if layout.Planner and ground == "Asphalt" then 0 else rng:int(0, 1) * 90
					tryPlace(layout, templates, rng, cfg, name, x, z, rotation, ground, nil)
				end
			end
		end
	end
end

-- Calçadas: poste a cada LampEvery células (só nas encostadas na rua) e outros objetos no meio.
local function fillSidewalks(layout: Layout, fill: Fill, templates: { [string]: Template }, rng: Rng, cfg: Config)
	local grid = layout.Grid
	for z = 0, grid.Depth - 1 do
		for x = 0, grid.Width - 1 do
			local i = index(grid, x, z) :: number
			if grid.Kind[i] == "Walk" and not grid.Occupied[i] and not grid.Edge[i] then
				local byRoad = false
				for _, d in DIRS do
					local j = index(grid, x + d[1], z + d[2])
					if j and grid.Kind[j] == "Road" then
						byRoad = true
					end
				end
				local name: string? = nil
				-- postes mais espaçados onde o jogador já é grande
				local every = if capAt(layout, i) >= cfg.FarLampCap then cfg.LampEvery * 2 else cfg.LampEvery
				if byRoad and (x + z) % every == 0 then
					name = "Lamp"
				elseif rng:next() < cfg.PropChance then
					name = pick(rng, templates, fill.Sidewalk, capAt(layout, i), minAt(layout, i, cfg))
				end
				if name and templates[name] then
					local cw, cd = cellsFor(templates[name], 0, cfg)
					local r = { x, z, x + cw, z + cd }
					if fits(grid, r, "Walk", nil) then
						occupy(layout, rng, cfg, name, r, 0)
					end
				end
			end
		end
	end
end

-- ===== Gerador planejado (Fill.Planner) =====

-- Tem calçada/rua a até `n` células (quadrado em volta)?
local function nearWalk(grid: Grid, x: number, z: number, n: number): boolean
	for dx = -n, n do
		for dz = -n, n do
			local j = index(grid, x + dx, z + dz)
			if j and (grid.Kind[j] == "Walk" or grid.Kind[j] == "Road") then
				return true
			end
		end
	end
	return false
end

-- Rotação de um objeto de convivência: de frente para a calçada mais perto (banco olhando o caminho).
local function faceWalk(grid: Grid, rng: Rng, x: number, z: number): number
	local dirIndex = nearestWalk(grid, x, z, 8)
	return if dirIndex then ROTATION_FOR[dirIndex] else rng:int(0, 3) * 90
end

-- Grupos naturais: uma célula livre vira centro (chance `spec.Chance`), recebe o item principal (de
-- preferência uma árvore) e de Min a Max itens em volta, espalhados em ângulos e distâncias diferentes.
-- Cada item respeita o catálogo (distância mínima do mesmo grupo). Nada em fila, sobra espaço vazio.
local function placeGroups(
	layout: Layout,
	templates: { [string]: Template },
	rng: Rng,
	cfg: Config,
	ground: string,
	mixFor: (number) -> { [string]: number }?,
	specFor: (number) -> GroupSpec,
	cellOk: ((number, number, number) -> boolean)?
)
	local planner = layout.Planner :: Planner
	local grid = layout.Grid
	local catalog = planner.Catalog
	local function isTree(name: string): boolean
		return Placement.category(catalog, name) == "Tree"
	end
	local function notTree(name: string): boolean
		return not isTree(name)
	end
	for z = 0, grid.Depth - 1 do
		for x = 0, grid.Width - 1 do
			local i = index(grid, x, z) :: number
			if grid.Kind[i] ~= ground or grid.Occupied[i] or grid.Edge[i] then
				continue
			end
			local mix = mixFor(i)
			if mix == nil or (cellOk and not cellOk(i, x, z)) then
				continue
			end
			local spec = specFor(i)
			if rng:next() >= spec.Chance then
				continue
			end
			local cap, low = capAt(layout, i), minAt(layout, i, cfg)
			-- árvore no centro (não na faixa da fachada); sem árvore possível, qualquer item do grupo
			local anchor = if nearWalk(grid, x, z, planner.FrontClear)
				then nil
				else pick(rng, templates, mix, cap, low, isTree)
			anchor = anchor or pick(rng, templates, mix, cap, low, notTree)
			if anchor == nil then
				continue
			end
			if tryPlace(layout, templates, rng, cfg, anchor, x, z, rng:int(0, 3) * 90, ground, nil) == nil then
				continue
			end
			local count = Placement.groupSize(spec.Min, spec.Max, rng:next())
			for k = 1, count do
				local name = pick(rng, templates, mix, cap, low, notTree)
				if name == nil then
					break
				end
				local dx, dz = Placement.groupOffset(k, spec.Radius, rng:next())
				local px, pz = x + dx, z + dz
				local rotation = if Placement.category(catalog, name) == "Leisure"
					then faceWalk(grid, rng, px, pz)
					else rng:int(0, 3) * 90
				tryPlace(layout, templates, rng, cfg, name, px, pz, rotation, ground, nil)
			end
		end
	end
end

-- Natureza dos bairros em grupos (jardins, quintais, parques).
local function fillGroups(layout: Layout, fill: Fill, templates: { [string]: Template }, rng: Rng, cfg: Config)
	local planner = layout.Planner :: Planner
	local grid = layout.Grid
	local grounds = {}
	for _, spec in fill.Districts do
		grounds[spec.Ground] = true
	end
	-- ordem fixa dos tipos de chão (determinística)
	for _, ground in { "Lot", "Asphalt" } do
		if not grounds[ground] then
			continue
		end
		placeGroups(layout, templates, rng, cfg, ground, function(i)
			local spec = fill.Districts[grid.District[i]]
			return if spec and spec.Ground == ground and spec.NatureChance > 0 then spec.Nature else nil
		end, function(i)
			local district = grid.District[i]
			return planner.DistrictGroups and planner.DistrictGroups[district] or planner.Groups
		end, nil)
	end
end

-- Distância (em células) de cada célula até a água (mar, rio, porto): busca em largura a partir da água.
local function waterDistance(grid: Grid): { number }
	local dist = {}
	local queue = {}
	for i = 1, grid.Width * grid.Depth do
		local kind = grid.Kind[i]
		if kind == "Sea" or kind == "Water" then
			dist[i] = 0
			table.insert(queue, i)
		end
	end
	local head = 1
	while head <= #queue do
		local i = queue[head]
		head += 1
		local x, z = (i - 1) % grid.Width, (i - 1) // grid.Width
		for _, d in DIRS do
			local j = index(grid, x + d[1], z + d[2])
			if j and dist[j] == nil then
				dist[j] = dist[i] + 1
				table.insert(queue, j)
			end
		end
	end
	return dist
end

-- Praia: grupos de guarda-sol (com toalhas, palmeira...) só na areia perto da água; o resto da areia fica livre.
local function fillBeach(layout: Layout, templates: { [string]: Template }, rng: Rng, cfg: Config)
	local planner = layout.Planner :: Planner
	local beach = planner.Beach
	local grid = layout.Grid
	local dist = waterDistance(grid)
	local catalog = planner.Catalog
	for z = 0, grid.Depth - 1 do
		for x = 0, grid.Width - 1 do
			local i = index(grid, x, z) :: number
			if
				grid.Kind[i] ~= "Sand"
				or grid.Occupied[i]
				or grid.Edge[i]
				or (dist[i] or math.huge) > beach.NearWater
				or rng:next() >= beach.Group.Chance
			then
				continue
			end
			local cap, low = capAt(layout, i), minAt(layout, i, cfg)
			local anchor = pick(rng, templates, beach.Anchor, cap, low)
			if anchor == nil or tryPlace(layout, templates, rng, cfg, anchor, x, z, 0, "Sand", nil) == nil then
				continue
			end
			local count = Placement.groupSize(beach.Group.Min, beach.Group.Max, rng:next())
			for k = 1, count do
				local name = pick(rng, templates, beach.Companions, cap, low)
				if name == nil then
					break
				end
				local dx, dz = Placement.groupOffset(k, beach.Group.Radius, rng:next())
				local j = index(grid, x + dx, z + dz)
				-- companheiros também ficam perto da água (não sobem para a rua)
				if j and (dist[j] or math.huge) <= beach.NearWater then
					local rotation = if Placement.category(catalog, name) == "Beach" then rng:int(0, 3) * 90 else 0
					tryPlace(layout, templates, rng, cfg, name, x + dx, z + dz, rotation, "Sand", nil)
				end
			end
		end
	end
end

-- Aeroporto: aviões na pista (alinhados com ela) e no pátio, respeitando a distância entre aviões.
local function fillAirport(layout: Layout, templates: { [string]: Template }, rng: Rng, cfg: Config)
	local planner = layout.Planner :: Planner
	local grid = layout.Grid
	local function runLength(x: number, z: number, dx: number, dz: number): number
		local n = 0
		while true do
			local j = index(grid, x + dx * (n + 1), z + dz * (n + 1))
			if j == nil or grid.Kind[j] ~= "Runway" then
				return n
			end
			n += 1
		end
	end
	for z = 0, grid.Depth - 1 do
		for x = 0, grid.Width - 1 do
			local i = index(grid, x, z) :: number
			local kind = grid.Kind[i]
			if grid.Occupied[i] then
				continue
			end
			if kind == "Runway" and rng:next() < planner.RunwayChance then
				local name = pick(rng, templates, planner.Runway, capAt(layout, i), minAt(layout, i, cfg))
				if name then
					-- frente do avião (-Z) ao longo do lado comprido da pista
					local alongX = runLength(x, z, 1, 0) + runLength(x, z, -1, 0)
					local alongZ = runLength(x, z, 0, 1) + runLength(x, z, 0, -1)
					tryPlace(layout, templates, rng, cfg, name, x, z, if alongX > alongZ then 90 else 0, "Runway", nil)
				end
			elseif kind == "Asphalt" and grid.District[i] == "Airport" and rng:next() < planner.ApronChance then
				local name = pick(rng, templates, planner.Apron, capAt(layout, i), minAt(layout, i, cfg))
				if name then
					tryPlace(layout, templates, rng, cfg, name, x, z, rng:int(0, 3) * 90, "Asphalt", "Airport")
				end
			end
		end
	end
end

-- Calçadas planejadas: postes acompanhando a rua com espaçamento (pulando cruzamentos e portas) e poucos
-- objetos de rua (lixeira, hidrante, correio, ponto de ônibus), cada um longe do outro igual.
local function fillSidewalksPlanned(layout: Layout, templates: { [string]: Template }, rng: Rng, cfg: Config)
	local planner = layout.Planner :: Planner
	local grid = layout.Grid
	local access = layout.Access :: { [number]: boolean }
	local idx = layout.Index :: Placement.Index
	local lampGroup, lampSpacing = Placement.spacing(planner.Catalog, "Lamp")
	-- esquinas: calçada que encosta na rua em dois eixos (dentro da curva) ou só na diagonal (fora da curva)
	local cross = {}
	local function road(x: number, z: number): boolean
		local j = index(grid, x, z)
		return j ~= nil and grid.Kind[j] == "Road"
	end
	for z = 0, grid.Depth - 1 do
		for x = 0, grid.Width - 1 do
			local i = index(grid, x, z) :: number
			if grid.Kind[i] == "Walk" then
				local alongX = road(x + 1, z) or road(x - 1, z)
				local alongZ = road(x, z + 1) or road(x, z - 1)
				local diagonal = road(x + 1, z + 1) or road(x - 1, z + 1) or road(x + 1, z - 1) or road(x - 1, z - 1)
				if (alongX and alongZ) or (diagonal and not alongX and not alongZ) then
					cross[i] = true
				end
			end
		end
	end
	local function nearCross(x: number, z: number): boolean
		for dx = -2, 2 do
			for dz = -2, 2 do
				local j = index(grid, x + dx, z + dz)
				if j and cross[j] then
					return true
				end
			end
		end
		return false
	end
	for z = 0, grid.Depth - 1 do
		for x = 0, grid.Width - 1 do
			local i = index(grid, x, z) :: number
			if grid.Kind[i] ~= "Walk" or grid.Occupied[i] or grid.Edge[i] or access[i] then
				continue
			end
			local byRoad = false
			for _, d in DIRS do
				local j = index(grid, x + d[1], z + d[2])
				if j and grid.Kind[j] == "Road" then
					byRoad = true
				end
			end
			if byRoad and lampGroup and not nearCross(x, z) then
				local cx, cz = CityGen.cellToWorld(grid, cfg.CellSize, x + 0.5, z + 0.5)
				local far = capAt(layout, i) >= cfg.FarLampCap
				if not Placement.near(idx, lampGroup, cx, cz, if far then lampSpacing * 2 else lampSpacing) then
					if tryPlace(layout, templates, rng, cfg, "Lamp", x, z, 0, "Walk", nil) then
						continue
					end
				end
			end
			if rng:next() < planner.SidewalkChance then
				local name = pick(rng, templates, planner.Sidewalk, capAt(layout, i), minAt(layout, i, cfg))
				if name then
					tryPlace(layout, templates, rng, cfg, name, x, z, 0, "Walk", nil)
				end
			end
		end
	end
end

-- Carros estacionados no meio-fio: na faixa da rua encostada na calçada, alinhados com a rua, só em ruas
-- largas (MinRoad células), com a calçada inteira do lado (não em esquina nem em entrada de casa) e espaçados.
local function fillCurbCars(layout: Layout, templates: { [string]: Template }, rng: Rng, cfg: Config)
	local planner = layout.Planner :: Planner
	local curb = planner.CurbCars
	local car = templates.Car
	if curb == nil or car == nil then
		return
	end
	local grid = layout.Grid
	local access = layout.Access :: { [number]: boolean }
	local idx = layout.Index :: Placement.Index
	local function kind(x: number, z: number): string?
		local j = index(grid, x, z)
		return if j then grid.Kind[j] else nil
	end
	for z = 0, grid.Depth - 1 do
		for x = 0, grid.Width - 1 do
			local i = index(grid, x, z) :: number
			if grid.Kind[i] ~= "Road" or grid.Occupied[i] or rng:next() >= curb.Chance then
				continue
			end
			for _, d in DIRS do
				if kind(x + d[1], z + d[2]) ~= "Walk" then
					continue
				end
				-- largura da rua para dentro (direção oposta à calçada)
				local width = 0
				while kind(x - d[1] * width, z - d[2] * width) == "Road" do
					width += 1
				end
				if width < curb.MinRoad or car.Tier > capAt(layout, i) or car.Tier < minAt(layout, i, cfg) then
					break
				end
				-- comprido ao longo da calçada (frente do modelo = -Z)
				local rotation = if d[1] == 0 then 90 else 0
				local cw, cd = cellsFor(car, rotation, cfg)
				local x0 = if d[1] < 0 then x elseif d[1] > 0 then x - cw + 1 else x
				local z0 = if d[2] < 0 then z elseif d[2] > 0 then z - cd + 1 else z
				-- a calçada do lado tem que ser contínua e sem porta
				local ok = true
				for cx = x0, x0 + cw - 1 do
					for cz = z0, z0 + cd - 1 do
						local sx, sz = cx + d[1], cz + d[2]
						local onSide = (d[1] ~= 0 and sx == (if d[1] < 0 then x0 - 1 else x0 + cw))
							or (d[2] ~= 0 and sz == (if d[2] < 0 then z0 - 1 else z0 + cd))
						if onSide then
							local j = index(grid, sx, sz)
							if j == nil or grid.Kind[j] ~= "Walk" or access[j] then
								ok = false
							end
						end
					end
				end
				local cx, cz = CityGen.cellToWorld(grid, cfg.CellSize, x0 + cw / 2, z0 + cd / 2)
				if ok and not Placement.near(idx, "CurbCar", cx, cz, curb.Spacing) then
					if tryPlace(layout, templates, rng, cfg, "Car", x0, z0, rotation, "Road", nil) then
						Placement.add(idx, "CurbCar", cx, cz)
					end
				end
				break
			end
		end
	end
end

-- Retângulo (células) de uma peça do kit depois de girar o kit (R = 0/90/180/270) e pôr o canto em (kx, kz).
-- O kit tem frente em Z = 0 (virada para -Z antes de girar), como os modelos.
local function kitRect(piece: Rect, w: number, d: number, rotation: number, kx: number, kz: number): Rect
	local x0, z0, x1, z1 = piece[1], piece[2], piece[3], piece[4]
	if rotation == 90 then
		-- a frente (-Z) passa a olhar para -X: (u, v) -> (v, W - u)
		x0, z0, x1, z1 = z0, w - x1, z1, w - x0
	elseif rotation == 180 then
		x0, z0, x1, z1 = w - x1, d - z1, w - x0, d - z0
	elseif rotation == 270 then
		x0, z0, x1, z1 = d - z1, x0, d - z0, x1
	end
	return { kx + x0, kz + z0, kx + x1, kz + z1 }
end

-- Microambientes soltos (Planner.Kits): parquinho, cantinho de praça, obra, pátio de carga, fileira de carros.
-- O kit inteiro precisa caber livre num chão só; cada peça vai na posição desenhada (com chance), e as
-- células que sobram ficam reservadas (nada de fora entra no meio do parquinho).
local function fillKits(layout: Layout, templates: { [string]: Template }, rng: Rng, cfg: Config)
	local planner, idx = layout.Planner, layout.Index
	if planner == nil or idx == nil or planner.Kits == nil then
		return
	end
	local grid = layout.Grid
	local serial = 0
	for _, kit in planner.Kits do
		local w, d = kit.Size[1], kit.Size[2]
		for z = 0, grid.Depth - 1 do
			for x = 0, grid.Width - 1 do
				local i = index(grid, x, z) :: number
				local chance = kit.Districts[grid.District[i]]
				if chance == nil or grid.Kind[i] ~= kit.Ground or grid.Occupied[i] or rng:next() >= chance then
					continue
				end
				-- frente virada para a calçada mais perto (a até Front células): a célula (x, z) fica no meio da
				-- frente do kit e o resto vai para dentro do terreno. Sem Front: qualquer lado.
				local rotation = rng:int(0, 3) * 90
				local dirIndex: number? = nil
				if kit.Front then
					dirIndex = nearestWalk(grid, x, z, kit.Front)
					if dirIndex == nil then
						continue
					end
					rotation = ROTATION_FOR[dirIndex :: number]
				end
				local kw, kd = if rotation % 180 == 0 then w else d, if rotation % 180 == 0 then d else w
				local ox, oz = x, z
				if dirIndex == 1 then
					ox = x - kw // 2
				elseif dirIndex == 2 then
					ox, oz = x - kw // 2, z - kd + 1
				elseif dirIndex == 3 then
					oz = z - kd // 2
				elseif dirIndex == 4 then
					ox, oz = x - kw + 1, z - kd // 2
				end
				local area = { ox, oz, ox + kw, oz + kd }
				if not fits(grid, area, kit.Ground, grid.District[i]) then
					continue
				end
				local cx, cz = centerOf(layout, cfg, area)
				local group = "Kit:" .. kit.Name
				if Placement.near(idx, group, cx, cz, kit.Spacing) then
					continue
				end
				serial += 1
				local tag = `{kit.Name}#{serial}`
				local placed = 0
				for _, piece in kit.Pieces do
					local template = templates[piece.Model]
					if
						template == nil
						or template.Tier > capAt(layout, i)
						or (piece.Chance and rng:next() >= piece.Chance)
					then
						continue
					end
					local rot = piece.Rot or 0
					local pw, pd = cellsFor(template, rot, cfg)
					local r = kitRect({ piece.X, piece.Z, piece.X + pw, piece.Z + pd }, w, d, rotation, ox, oz)
					if
						fits(grid, r, kit.Ground, nil)
						and Placement.allowed(planner.Catalog, piece.Model, kit.Ground, grid.District[i])
					then
						occupy(layout, rng, cfg, piece.Model, r, (rot + rotation) % 360)
						layout.Placements[#layout.Placements].Kit = tag
						placed += 1
					end
				end
				if placed > 0 then
					Placement.add(idx, group, cx, cz)
					for ax = area[1], area[3] - 1 do
						for az = area[2], area[4] - 1 do
							grid.Occupied[index(grid, ax, az) :: number] = true
						end
					end
				end
			end
		end
	end
end

-- Paredes nas bordas entre células: barreiras entre zonas (somem quando a zona abre) e paredes invisíveis
-- da costa (terra | mar). Trechos seguidos na mesma linha viram uma parede só. Nos cantos as paredes só
-- encostam: as horizontais vão até o fim e as verticais param meia espessura antes de qualquer horizontal.
local function walls(layout: Layout, cfg: Config)
	local grid = layout.Grid
	local size, t = cfg.CellSize, cfg.BarrierThickness
	local half = t / 2
	local function top(i: number): number
		return if grid.Kind[i] == "Road" then cfg.LineTop else grid.Height[i]
	end
	-- etiqueta da borda entre as células a e b: zona (barreira), -1 (costa) ou nil (sem parede)
	local function tag(a: number, b: number): number?
		local za, zb = grid.Zone[a], grid.Zone[b]
		if za == zb then
			return nil
		end
		if za == 0 or zb == 0 then
			return -1
		end
		return math.max(za, zb)
	end
	type Run = { Line: number, From: number, To: number, Tag: number, Bottom: number }
	local verticals: { Run } = {} -- bordas em X = Line (entre x-1 e x), de Z = From até To
	local horizontals: { Run } = {}
	for x = 0, grid.Width - 2 do
		local z = 0
		while z < grid.Depth do
			local a, b = index(grid, x, z) :: number, index(grid, x + 1, z) :: number
			local k = tag(a, b)
			if k then
				local start, bottom = z, -math.huge
				while z < grid.Depth do
					local c, e = index(grid, x, z) :: number, index(grid, x + 1, z) :: number
					if tag(c, e) ~= k or grid.Zone[c] ~= grid.Zone[a] then
						break
					end
					bottom = math.max(bottom, top(c), top(e))
					z += 1
				end
				table.insert(verticals, { Line = x + 1, From = start, To = z, Tag = k, Bottom = bottom })
			else
				z += 1
			end
		end
	end
	for z = 0, grid.Depth - 2 do
		local x = 0
		while x < grid.Width do
			local a, b = index(grid, x, z) :: number, index(grid, x, z + 1) :: number
			local k = tag(a, b)
			if k then
				local start, bottom = x, -math.huge
				while x < grid.Width do
					local c, e = index(grid, x, z) :: number, index(grid, x, z + 1) :: number
					if tag(c, e) ~= k or grid.Zone[c] ~= grid.Zone[a] then
						break
					end
					bottom = math.max(bottom, top(c), top(e))
					x += 1
				end
				table.insert(horizontals, { Line = z + 1, From = start, To = x, Tag = k, Bottom = bottom })
			else
				x += 1
			end
		end
	end
	-- pontos da grade tocados por paredes horizontais
	local touched: { [number]: boolean } = {}
	local function key(x: number, z: number): number
		return z * (grid.Width + 1) + x
	end
	for _, h in horizontals do
		for x = h.From, h.To do
			touched[key(x, h.Line)] = true
		end
	end
	local function emit(k: number, x0: number, z0: number, x1: number, z1: number, bottom: number)
		local isCoast = k < 0
		local height = if isCoast then cfg.ColliderHeight else cfg.BarrierHeight
		-- na foz do rio rebaixado a parede da costa começa em 0 (acima do mar; o vão de 0.6 ninguém passa)
		if isCoast then
			bottom = math.max(bottom, 0)
		end
		local piece = {
			Size = { x1 - x0, height, z1 - z0 },
			Pos = { (x0 + x1) / 2, bottom + height / 2, (z0 + z1) / 2 },
		}
		if isCoast then
			table.insert(layout.Walls, piece)
		else
			table.insert(layout.Barriers, { Zone = k, Size = piece.Size, Pos = piece.Pos })
		end
	end
	for _, h in horizontals do
		local wx0, wz = CityGen.cellToWorld(grid, size, h.From, h.Line)
		local wx1 = CityGen.cellToWorld(grid, size, h.To, h.Line)
		emit(h.Tag, wx0, wz - half, wx1, wz + half, h.Bottom)
	end
	-- verticais: quebradas em cada ponto tocado por uma horizontal, e recuadas meia espessura ali
	for _, v in verticals do
		local start = v.From
		for z = v.From + 1, v.To do
			if z == v.To or touched[key(v.Line, z)] then
				local wx, wz0 = CityGen.cellToWorld(grid, size, v.Line, start)
				local _, wz1 = CityGen.cellToWorld(grid, size, v.Line, z)
				if touched[key(v.Line, start)] then
					wz0 += half
				end
				if touched[key(v.Line, z)] then
					wz1 -= half
				end
				if wz1 - wz0 > 0.001 then
					emit(v.Tag, wx - half, wz0, wx + half, wz1, v.Bottom)
				end
				start = z
			end
		end
	end
end

-- Pontos de nascer: na primeira etapa de cada zona, de preferência na rua (longe da borda da zona).
local function spawns(layout: Layout, zones: number, rng: Rng, cfg: Config)
	local grid = layout.Grid
	for zone = 1, zones do
		local first = math.huge
		for stepIndex, step in layout.Steps do
			if step.Zone == zone then
				first = math.min(first, stepIndex)
			end
		end
		local roads, others = {}, {}
		for z = 0, grid.Depth - 1 do
			for x = 0, grid.Width - 1 do
				local i = index(grid, x, z) :: number
				if grid.Step[i] == first and not grid.Edge[i] and not grid.Occupied[i] then
					local kind = grid.Kind[i]
					if kind == "Road" then
						table.insert(roads, { x, z })
					elseif kind ~= "Water" and kind ~= "Sea" then
						table.insert(others, { x, z })
					end
				end
			end
		end
		local candidates = if #roads > 0 then roads else others
		local list = {}
		for _ = 1, math.min(cfg.SpawnsPerZone, #candidates) do
			local c = candidates[rng:int(1, #candidates)]
			local i = index(grid, c[1], c[2]) :: number
			local wx, wz = CityGen.cellToWorld(grid, cfg.CellSize, c[1] + 0.5, c[2] + 0.5)
			table.insert(list, { wx, if grid.Kind[i] == "Road" then cfg.LineTop else grid.Height[i], wz })
		end
		layout.Spawns[zone] = list
	end
end

-- Grades de ruas automáticas -> ruas (em unidades da planta). Cada trecho entre dois cruzamentos pode
-- ser pulado (Skip), deixando quarteirões maiores e a cidade menos quadriculada.
local function expandStreets(plan: Plan, rng: Rng): { Line }
	local roads: { Line } = {}
	for _, grid in plan.Streets or {} do
		local r = grid.Rect
		local ox, oz = (grid.Offset or { 0, 0 })[1], (grid.Offset or { 0, 0 })[2]
		local xs, zs = { r[1] }, { r[2] }
		local x = r[1] + ox + grid.Every[1]
		while x < r[3] - 1 do
			table.insert(xs, x)
			x += grid.Every[1]
		end
		table.insert(xs, r[3])
		local z = r[2] + oz + grid.Every[2]
		while z < r[4] - 1 do
			table.insert(zs, z)
			z += grid.Every[2]
		end
		table.insert(zs, r[4])
		local skip = grid.Skip or 0
		local w = grid.Width / 2
		-- a faixa da rua (com a largura) entra no buraco? (só encostar na borda não conta)
		local function blocked(x0: number, z0: number, x1: number, z1: number): boolean
			local ax0, az0, ax1, az1 = x0, z0, x1, z1
			if x0 == x1 then
				ax0, ax1 = x0 - w, x0 + w
			else
				az0, az1 = z0 - w, z0 + w
			end
			for _, hole in grid.Holes or {} do
				if ax0 < hole[3] and ax1 > hole[1] and az0 < hole[4] and az1 > hole[2] then
					return true
				end
			end
			return false
		end
		-- ruas em Z (x fixo), sem as bordas do retângulo (que são avenidas da planta)
		for xi = 2, #xs - 1 do
			for zi = 1, #zs - 1 do
				local lx, z0, z1 = xs[xi], zs[zi], zs[zi + 1]
				if rng:next() >= skip and not blocked(lx, z0, lx, z1) then
					table.insert(roads, { Width = grid.Width, Points = { { lx, z0 }, { lx, z1 } } })
				end
			end
		end
		for zi = 2, #zs - 1 do
			for xi = 1, #xs - 1 do
				local lz, x0, x1 = zs[zi], xs[xi], xs[xi + 1]
				if rng:next() >= skip and not blocked(x0, lz, x1, lz) then
					table.insert(roads, { Width = grid.Width, Points = { { x0, lz }, { x1, lz } } })
				end
			end
		end
	end
	return roads
end

-- A planta é desenhada em "unidades de planta" (cfg.PlanUnit studs); a grade usa células menores
-- (cfg.CellSize). Converte tudo para células.
local function toCells(plan: Plan, cfg: Config): Plan
	local f = cfg.PlanUnit / cfg.CellSize
	-- retângulos sempre em células inteiras (a cidade maior das dificuldades gera frações)
	local function rectCells(r: Rect): Rect
		local function c(v: number): number
			return math.floor(v * f + 0.5)
		end
		return { c(r[1]), c(r[2]), c(r[3]), c(r[4]) }
	end
	local function lineCells(line: Line): Line
		local points = {}
		for _, p in line.Points do
			table.insert(points, { p[1] * f, p[2] * f })
		end
		return { Width = line.Width * f, Points = points }
	end
	local result = table.clone(plan)
	result.Width, result.Depth = plan.Width * f, plan.Depth * f
	local coast = table.clone(plan.Coast)
	coast.Inset *= f
	coast.Radius *= f
	coast.Amplitude *= f
	coast.Wavelength *= f
	coast.Shore = math.floor(coast.Shore * f + 0.5)
	if plan.Coast.Wild then
		local w = plan.Coast.Wild
		coast.Wild = { Min = w.Min * f, Max = w.Max * f, Wavelength = w.Wavelength * f }
	end
	result.Coast = coast
	result.Roads, result.Rivers, result.Areas, result.Districts, result.Zones, result.Sites = {}, {}, {}, {}, {}, {}
	for _, line in plan.Roads do
		table.insert(result.Roads, lineCells(line))
	end
	for _, line in plan.Rivers do
		table.insert(result.Rivers, lineCells(line))
	end
	for _, area in plan.Areas do
		local copy = table.clone(area)
		copy.Rect = rectCells(area.Rect)
		table.insert(result.Areas, copy)
	end
	for _, district in plan.Districts do
		table.insert(result.Districts, { Kind = district.Kind, Rect = rectCells(district.Rect) })
	end
	for _, zone in plan.Zones do
		local copy = table.clone(zone)
		copy.Rects = {}
		for _, r in zone.Rects do
			table.insert(copy.Rects, rectCells(r))
		end
		copy.Steps = {}
		for _, step in zone.Steps do
			local rects: { Rect }? = nil
			if step.Rects then
				local list = {}
				for _, r in step.Rects do
					table.insert(list, rectCells(r))
				end
				rects = list
			end
			table.insert(copy.Steps, { Cap = step.Cap, Rects = rects })
		end
		table.insert(result.Zones, copy)
	end
	for _, site in plan.Sites do
		local copy = table.clone(site)
		copy.X, copy.Z = site.X * f, site.Z * f
		table.insert(result.Sites, copy)
	end
	return result
end

-- Cidade maior (dificuldade): posições e tamanhos de áreas multiplicados por `k`; larguras de ruas e rios,
-- espaçamento das grades de ruas e a orla ficam iguais (mais quarteirões, não ruas mais largas).
local function scalePlan(plan: Plan, k: number): Plan
	if k == 1 then
		return plan
	end
	local function r(rc: Rect): Rect
		return { rc[1] * k, rc[2] * k, rc[3] * k, rc[4] * k }
	end
	local function line(l: Line): Line
		local points = {}
		for _, p in l.Points do
			table.insert(points, { p[1] * k, p[2] * k })
		end
		return { Width = l.Width, Points = points }
	end
	local result = table.clone(plan)
	result.Width, result.Depth = math.floor(plan.Width * k + 0.5), math.floor(plan.Depth * k + 0.5)
	local coast = table.clone(plan.Coast)
	coast.Inset *= k
	coast.Radius *= k
	coast.Amplitude *= k
	coast.Wavelength *= k
	-- a margem natural fica com a mesma largura (só a ondulação acompanha a cidade maior)
	if plan.Coast.Wild then
		local w = plan.Coast.Wild
		coast.Wild = { Min = w.Min, Max = w.Max, Wavelength = w.Wavelength * k }
	end
	result.Coast = coast
	result.Roads, result.Rivers, result.Areas, result.Districts, result.Zones, result.Sites = {}, {}, {}, {}, {}, {}
	for _, l in plan.Roads do
		table.insert(result.Roads, line(l))
	end
	for _, l in plan.Rivers do
		table.insert(result.Rivers, line(l))
	end
	for _, area in plan.Areas do
		local copy = table.clone(area)
		copy.Rect = r(area.Rect)
		table.insert(result.Areas, copy)
	end
	for _, d in plan.Districts do
		table.insert(result.Districts, { Kind = d.Kind, Rect = r(d.Rect) })
	end
	for _, zone in plan.Zones do
		local copy = table.clone(zone)
		copy.Rects = {}
		for _, rc in zone.Rects do
			table.insert(copy.Rects, r(rc))
		end
		copy.Steps = {}
		for _, step in zone.Steps do
			local rects: { Rect }? = nil
			if step.Rects then
				local list = {}
				for _, rc in step.Rects do
					table.insert(list, r(rc))
				end
				rects = list
			end
			table.insert(copy.Steps, { Cap = step.Cap, Rects = rects })
		end
		table.insert(result.Zones, copy)
	end
	for _, site in plan.Sites do
		local copy = table.clone(site)
		copy.X, copy.Z = site.X * k, site.Z * k
		table.insert(result.Sites, copy)
	end
	if plan.Streets then
		local streets = {}
		for _, g in plan.Streets do
			local copy = table.clone(g)
			copy.Rect = r(g.Rect)
			if g.Holes then
				local holes = {}
				for _, h in g.Holes do
					table.insert(holes, r(h))
				end
				copy.Holes = holes
			end
			table.insert(streets, copy)
		end
		result.Streets = streets
	end
	return result
end

-- `mapScale` (opcional): tamanho da cidade da dificuldade (DifficultyConfig.MapScale).
function CityGen.generate(
	sourcePlan: Plan,
	fill: Fill,
	templates: { [string]: Template },
	rng: Rng,
	cfg: Config,
	mapScale: number?
): Layout
	local rawPlan = scalePlan(sourcePlan, mapScale or 1)
	local withStreets = table.clone(rawPlan)
	withStreets.Roads = table.clone(rawPlan.Roads)
	for _, road in expandStreets(rawPlan, rng) do
		table.insert(withStreets.Roads, road)
	end
	local plan = toCells(withStreets, cfg)
	local grid, steps = newGrid(plan, cfg)
	local layout: Layout = {
		Size = { plan.Width * cfg.CellSize, plan.Depth * cfg.CellSize },
		Grid = grid,
		Placements = {},
		Barriers = {},
		Walls = {},
		Spawns = {},
		ZoneNames = {},
		Steps = steps,
		Problems = {},
	}
	for _, zone in plan.Zones do
		table.insert(layout.ZoneNames, zone.Name)
	end
	local planner = fill.Planner
	if planner then
		layout.Planner = planner
		layout.Index = Placement.newIndex(24)
		layout.Access = {}
	end
	placeSites(layout, plan, templates, rng, cfg)
	if planner then
		-- ordem do planejamento: construções e acessos -> infraestrutura -> natureza -> decoração das regiões
		fillFrontage(layout, fill, templates, rng, cfg)
		fillBlocks(layout, fill, templates, rng, cfg)
		fillSidewalksPlanned(layout, templates, rng, cfg)
		fillCurbCars(layout, templates, rng, cfg)
		fillKits(layout, templates, rng, cfg)
		scatter(layout, templates, rng, cfg, "Asphalt", fill.Parking, planner.ParkingChance or 0.35, "Parking")
		fillAirport(layout, templates, rng, cfg)
		fillGroups(layout, fill, templates, rng, cfg)
		fillBeach(layout, templates, rng, cfg)
		scatter(layout, templates, rng, cfg, "Plaza", fill.Plaza, planner.PlazaChance or 0.1, nil)
		scatter(layout, templates, rng, cfg, "Water", fill.Boats, fill.BoatChance, "Harbor")
		placeGroups(layout, templates, rng, cfg, "Wild", function()
			return fill.Wild
		end, function()
			return planner.Wild
		end, nil)
	else
		fillFrontage(layout, fill, templates, rng, cfg)
		fillBlocks(layout, fill, templates, rng, cfg)
		fillInterior(layout, fill, templates, rng, cfg)
		scatter(layout, templates, rng, cfg, "Sand", fill.Beach, 0.12, nil)
		scatter(layout, templates, rng, cfg, "Plaza", fill.Plaza, 0.1, nil)
		scatter(layout, templates, rng, cfg, "Asphalt", fill.Parking, 0.35, "Parking")
		scatter(layout, templates, rng, cfg, "Water", fill.Boats, fill.BoatChance, "Harbor")
		scatter(layout, templates, rng, cfg, "Wild", fill.Wild, cfg.WildChance, nil)
		fillSidewalks(layout, fill, templates, rng, cfg)
	end
	walls(layout, cfg)
	spawns(layout, #plan.Zones, rng, cfg)
	return layout
end

-- Ponto da placa de cada zona: a célula de terra da zona mais perto do centro dela (zonas em "L" ou com
-- outra zona dentro têm o centro fora delas). Devolve {x, y, z} em studs, por zona.
function CityGen.zoneAnchors(layout: Layout, cellSize: number): { { number } }
	local grid = layout.Grid
	local sums: { { number } } = {}
	for zone = 1, #layout.ZoneNames do
		sums[zone] = { 0, 0, 0 }
	end
	for z = 0, grid.Depth - 1 do
		for x = 0, grid.Width - 1 do
			local zone = grid.Zone[z * grid.Width + x + 1]
			if zone > 0 then
				local s = sums[zone]
				s[1] += x
				s[2] += z
				s[3] += 1
			end
		end
	end
	local anchors = {}
	for zone, s in sums do
		local cx, cz = s[1] / math.max(s[3], 1), s[2] / math.max(s[3], 1)
		local best, bestX, bestZ = math.huge, 0, 0
		for z = 0, grid.Depth - 1 do
			for x = 0, grid.Width - 1 do
				local i = z * grid.Width + x + 1
				-- longe da borda da zona (a placa fica bem dentro dela)
				if grid.Zone[i] == zone and not grid.Edge[i] then
					local d = (x - cx) ^ 2 + (z - cz) ^ 2
					if d < best then
						best, bestX, bestZ = d, x, z
					end
				end
			end
		end
		local wx, wz = CityGen.cellToWorld(grid, cellSize, bestX + 0.5, bestZ + 0.5)
		anchors[zone] = { wx, grid.Height[bestZ * grid.Width + bestX + 1], wz }
	end
	return anchors
end

-- Zona de uma posição do mundo (para o servidor saber onde o jogador está).
function CityGen.zoneAt(layout: Layout, cellSize: number, x: number, z: number): number?
	local grid = layout.Grid
	local cx = math.floor(x / cellSize + grid.Width / 2)
	local cz = math.floor(z / cellSize + grid.Depth / 2)
	local i = index(grid, cx, cz)
	return if i then grid.Zone[i] else nil
end

return CityGen
