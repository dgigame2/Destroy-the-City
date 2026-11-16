--!strict
-- Estágios de dano das construções (puro, testável no Lune). Recebe os blocos do modelo (Templates) e decide
-- QUAIS blocos caem em cada estágio. Regras:
--   * caem primeiro os blocos mais altos (a construção desmorona de cima para baixo), com uma pequena variação
--     por construção (seed) para construções iguais não quebrarem igual;
--   * depois de cada bloco que cai, todos os que sobraram continuam ligados ao chão por blocos que se tocam
--     (nunca sobra bloco flutuando: mesma regra do teste FLOATING dos modelos);
--   * a ordem é única: o estágio 2 sempre inclui o que caiu no estágio 1 (nada "volta").

local DamageStages = {}

local EPS = 0.01

type Box = { Size: { number }, Pos: { number }, Min: { number }?, Max: { number }? }

local function bounds(b: Box): ({ number }, { number })
	if b.Min and b.Max then
		return b.Min, b.Max
	end
	local ex, ey, ez = b.Size[1] / 2, b.Size[2] / 2, b.Size[3] / 2
	return { b.Pos[1] - ex, b.Pos[2] - ey, b.Pos[3] - ez }, { b.Pos[1] + ex, b.Pos[2] + ey, b.Pos[3] + ez }
end

-- Dois blocos se tocam ou se sobrepõem (com tolerância). Igual ao teste dos modelos.
function DamageStages.touching(a: Box, b: Box): boolean
	local amin, amax = bounds(a)
	local bmin, bmax = bounds(b)
	for axis = 1, 3 do
		if amin[axis] > bmax[axis] + EPS or bmin[axis] > amax[axis] + EPS then
			return false
		end
	end
	return true
end

-- Vizinhos de cada bloco (quem encosta em quem).
function DamageStages.adjacency(boxes: { Box }): { { number } }
	local adj: { { number } } = {}
	for i = 1, #boxes do
		adj[i] = {}
	end
	for i = 1, #boxes do
		for j = i + 1, #boxes do
			if DamageStages.touching(boxes[i], boxes[j]) then
				table.insert(adj[i], j)
				table.insert(adj[j], i)
			end
		end
	end
	return adj
end

local function onGround(b: Box): boolean
	local min = bounds(b)
	return math.abs(min[2]) <= EPS
end

-- Todos os blocos vivos estão ligados ao chão?
function DamageStages.connected(boxes: { Box }, adj: { { number } }, alive: { [number]: boolean }): boolean
	local seen: { [number]: boolean } = {}
	local queue = {}
	local count, total = 0, 0
	for i, b in boxes do
		if alive[i] then
			total += 1
			if onGround(b) then
				seen[i] = true
				count += 1
				table.insert(queue, i)
			end
		end
	end
	while #queue > 0 do
		local current = table.remove(queue) :: number
		for _, j in adj[current] do
			if alive[j] and not seen[j] then
				seen[j] = true
				count += 1
				table.insert(queue, j)
			end
		end
	end
	return count == total
end

-- Número "sorteado" entre 0 e 1, sempre o mesmo para (seed, i).
function DamageStages.noise(seed: number, i: number): number
	local h = bit32.bxor(bit32.band(seed * 73856093, 0xFFFFFFFF), bit32.band(i * 19349663, 0xFFFFFFFF))
	h = bit32.band(h * 83492791 + 12345, 0xFFFFFFFF)
	return (h % 10007) / 10007
end

-- Ordem em que os blocos caem (até `limit` blocos). Cada prefixo da lista mantém o resto ligado ao chão.
function DamageStages.order(boxes: { Box }, seed: number, jitter: number, limit: number): { number }
	local n = #boxes
	local adj = DamageStages.adjacency(boxes)
	local alive: { [number]: boolean } = {}
	local priority: { [number]: number } = {}
	local candidates = {}
	for i, b in boxes do
		alive[i] = true
		local _, max = bounds(b)
		local volume = b.Size[1] * b.Size[2] * b.Size[3]
		-- mais alto primeiro; empate: o menor primeiro (janelas e acabamentos antes das paredes)
		priority[i] = max[2] + DamageStages.noise(seed, i) * jitter - volume * 1e-4
		table.insert(candidates, i)
	end
	table.sort(candidates, function(a, b)
		if priority[a] ~= priority[b] then
			return priority[a] > priority[b]
		end
		return a < b
	end)
	local result = {}
	local wanted = math.min(limit, n - 1) -- sempre sobra pelo menos um bloco
	while #result < wanted do
		local removed = false
		for _, i in candidates do
			if alive[i] then
				alive[i] = false
				if DamageStages.connected(boxes, adj, alive) then
					table.insert(result, i)
					removed = true
					break
				end
				alive[i] = true
			end
		end
		if not removed then
			break -- nada mais pode cair sem deixar bloco flutuando
		end
	end
	return result
end

-- Estágio para a fração de vida (0 = inteira, #thresholds = quase caindo).
function DamageStages.stage(fraction: number, thresholds: { number }): number
	local stage = 0
	for index, threshold in thresholds do
		if fraction < threshold - 1e-9 then
			stage = index
		end
	end
	return stage
end

-- Quantos blocos já caíram no estágio (de `total` blocos do modelo).
function DamageStages.count(total: number, stage: number, removed: { number }): number
	if stage <= 0 then
		return 0
	end
	return math.floor(total * removed[math.min(stage, #removed)] + 0.5)
end

-- Fração de vida arredondada para baixo no degrau `step` (o servidor só publica quando muda).
function DamageStages.quantize(fraction: number, step: number): number
	return math.clamp(math.ceil(fraction / step - 1e-9) * step, 0, 1)
end

return DamageStages
