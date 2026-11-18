--!strict
-- Moitas de folhas por dentro da cerca do parque do lobby, com cara "natural": em vez de uma fileira de
-- cubos iguais, grupinhos de 1 a 3 cubos de tamanhos diferentes, com falhas entre eles. Sorteio fixo pela
-- posição (sempre igual). Lógica pura: testada no Lune (LobbyPark.spec).

local Hedges = {}

export type Cube = { X: number, Z: number, Size: number, Height: number }
export type Config = {
	Inset: number, -- distância da linha das moitas até a borda do parque
	Pitch: number, -- espaço reservado para cada grupinho
	Density: number, -- 0..1: quantos lugares têm grupinho
	Size: { number }, -- lado mínimo e máximo do cubo
	Height: { number },
	Skip: { { number } }, -- { x0, z0, x1, z1 }: áreas sem moita (estações, árvores, enfeites)
}

local function hash(a: number, b: number): number
	local v = math.sin(a * 12.9898 + b * 78.233) * 43758.5453
	return v - math.floor(v)
end

local function lerp(range: { number }, t: number): number
	return range[1] + (range[2] - range[1]) * t
end

function Hedges.build(width: number, depth: number, cfg: Config): { Cube }
	local cubes: { Cube } = {}
	local function skipped(x: number, z: number, half: number): boolean
		for _, s in cfg.Skip do
			if x + half > s[1] and x - half < s[3] and z + half > s[2] and z - half < s[4] then
				return true
			end
		end
		return false
	end
	-- um lado: linha de (ax, az) a (bx, bz); grupinhos ao longo dela, cubos encostados um no outro
	local function side(id: number, ax: number, az: number, bx: number, bz: number)
		local length = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
		local dx, dz = (bx - ax) / length, (bz - az) / length
		local slots = math.floor(length / cfg.Pitch)
		for k = 0, slots - 1 do
			if hash(id, k) < cfg.Density then
				local count = 1 + math.floor(hash(k, id + 3) * 3) -- 1 a 3 cubos
				local sizes = {}
				local total = 0
				for c = 1, count do
					sizes[c] = lerp(cfg.Size, hash(k + c, id))
					total += sizes[c]
				end
				-- o grupo cabe no espaço do lugar; começa num ponto sorteado dentro dele
				local free = math.max(cfg.Pitch - total, 0)
				local pos = k * cfg.Pitch + free * hash(id + 9, k)
				local group: { Cube } = {}
				local ok = true
				for c = 1, count do
					local s = sizes[c]
					local along = pos + s / 2
					local x, z = ax + dx * along, az + dz * along
					if skipped(x, z, s / 2) then
						ok = false
						break
					end
					table.insert(group, { X = x, Z = z, Size = s, Height = lerp(cfg.Height, hash(c, k + id)) })
					pos += s
				end
				if ok then
					for _, cube in group do
						table.insert(cubes, cube)
					end
				end
			end
		end
	end
	local hx, hz = width / 2 - cfg.Inset, depth / 2 - cfg.Inset
	side(1, -hx, -hz, hx, -hz) -- fundo
	side(2, -hx, hz, hx, hz) -- frente
	side(3, -hx, -hz + cfg.Pitch, -hx, hz - cfg.Pitch) -- esquerda (sem as quinas: os outros lados já usam)
	side(4, hx, -hz + cfg.Pitch, hx, hz - cfg.Pitch) -- direita
	return cubes
end

return Hedges
