--!strict
-- Destroços (puro, testável no Lune). AUDITORIA §8.3.
--   * pick: QUAL destroço (tamanho P/M/G/GG pelo footprint, família, variante 1..3, giro de 90° e espelho),
--     sorteado pela semente = BuildingId. Todo cliente escolhe o MESMO, sem rede.
--   * collapse: o desabamento (afunda e inclina) em t 0..1, sem física.
--   * pieces / piece: pedaços que voam no desabamento (arco balístico), quantidade pelo teto do Tier.

local Wreck = {}

export type Pick = { Size: string, Family: string, Variant: number, Rotation: number, Mirror: boolean }

type Config = {
	Sizes: { { Name: string, MaxArea: number } },
	Families: { [string]: { string } }, -- família -> padrões no nome do template
	DefaultFamily: string,
	Variants: number,
}

local function hash(seed: number, salt: number): number
	local h = bit32.bxor(bit32.band(seed * 2654435761, 0xFFFFFFFF), bit32.band(salt * 2246822519, 0xFFFFFFFF))
	h = bit32.band(bit32.bxor(h, bit32.rshift(h, 15)) * 2246822519, 0xFFFFFFFF)
	h = bit32.bxor(h, bit32.rshift(h, 13))
	return h
end

-- 0..1 determinístico para (semente, sal).
function Wreck.noise(seed: number, salt: number): number
	return (hash(seed, salt) % 100003) / 100003
end

-- Tamanho pelo footprint (área em studs²).
function Wreck.size(w: number, d: number, cfg: Config): string
	local area = w * d
	for _, s in cfg.Sizes do
		if area <= s.MaxArea then
			return s.Name
		end
	end
	return cfg.Sizes[#cfg.Sizes].Name
end

-- Família pelo nome do template (padrões do WreckConfig); sem padrão = DefaultFamily.
function Wreck.family(template: string, cfg: Config): string
	local lower = string.lower(template)
	-- ordem fixa (pairs não tem ordem): famílias em ordem alfabética
	local names = {}
	for name in cfg.Families do
		table.insert(names, name)
	end
	table.sort(names)
	for _, name in names do
		for _, pattern in cfg.Families[name] do
			if string.find(lower, string.lower(pattern), 1, true) then
				return name
			end
		end
	end
	return cfg.DefaultFamily
end

function Wreck.pick(id: number, template: string, w: number, d: number, cfg: Config): Pick
	return {
		Size = Wreck.size(w, d, cfg),
		Family = Wreck.family(template, cfg),
		Variant = 1 + hash(id, 1) % cfg.Variants,
		Rotation = (hash(id, 2) % 4) * 90,
		Mirror = hash(id, 3) % 2 == 1,
	}
end

-- Desabamento em t (0..1): quanto afundou (x altura) e quanto inclinou (graus) em volta de um eixo sorteado.
-- Começa devagar (o prédio "segura") e acelera (ease-in).
function Wreck.collapse(t: number, height: number, maxTilt: number, sink: number): (number, number)
	local k = math.clamp(t, 0, 1) ^ 2
	return height * sink * k, maxTilt * k
end

export type Piece = { Vx: number, Vy: number, Vz: number, Size: number, Spin: number, Ox: number, Oz: number }

-- Pedaços que voam: quantidade = min(base pelo tamanho, vaga do teto). Velocidade e tamanho pela semente.
function Wreck.pieces(id: number, count: number, w: number, d: number, speed: number, maxSize: number): { Piece }
	local list = {}
	for i = 1, count do
		local a = Wreck.noise(id, 10 + i) * math.pi * 2
		local up = 0.6 + 0.6 * Wreck.noise(id, 40 + i)
		local s = speed * (0.5 + 0.5 * Wreck.noise(id, 70 + i))
		table.insert(list, {
			Vx = math.cos(a) * s,
			Vy = speed * up,
			Vz = math.sin(a) * s,
			Size = maxSize * (0.35 + 0.65 * Wreck.noise(id, 100 + i)),
			Spin = (Wreck.noise(id, 130 + i) - 0.5) * 720,
			Ox = (Wreck.noise(id, 160 + i) - 0.5) * w * 0.6,
			Oz = (Wreck.noise(id, 190 + i) - 0.5) * d * 0.6,
		})
	end
	return list
end

-- Posição do pedaço em t segundos (arco balístico); para no chão (y = 0).
function Wreck.piece(p: Piece, t: number, gravity: number, startY: number): (number, number, number, boolean)
	local y = startY + p.Vy * t - 0.5 * gravity * t * t
	if y <= 0 then
		-- tempo do impacto (raiz positiva) -> fica parado ali
		local disc = p.Vy * p.Vy + 2 * gravity * startY
		local tHit = (p.Vy + math.sqrt(math.max(disc, 0))) / gravity
		return p.Ox + p.Vx * tHit, 0, p.Oz + p.Vz * tHit, true
	end
	return p.Ox + p.Vx * t, y, p.Oz + p.Vz * t, false
end

-- Quantos pedaços este desabamento pode lançar: pelo tamanho, sem passar o que sobra do teto do Tier.
function Wreck.budget(sizeName: string, perSize: { [string]: number }, inFlight: number, cap: number): number
	return math.max(0, math.min(perSize[sizeName] or 0, cap - inFlight))
end

return Wreck
