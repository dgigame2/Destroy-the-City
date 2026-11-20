--!strict
-- Plano de um golpe de elemento (puro, testável no Lune). Etapa 4, AUDITORIA §10.
-- O servidor e TODOS os clientes montam o MESMO plano a partir de (elemento, nível, quem lançou, alvo, semente):
-- o servidor aplica o dano de cada pulso na hora certa; o cliente desenha o efeito de cada pulso. Pela rede só
-- passam esses poucos números (CastFx), nunca a lista de pulsos.
-- Pulso = um círculo de dano num instante: { At (s depois do golpe), X, Z, Radius (studs), Mult (x dano do
-- nível), MaxTargets, Chain? }. A config de cada nível está em Config/ElementConfig (Levels).

local ElementPlan = {}

export type Pulse = {
	At: number,
	X: number,
	Z: number,
	Radius: number,
	Mult: number,
	MaxTargets: number,
	Shape: string,
	Chain: { Hops: number, Range: number, Falloff: number }?,
}

export type Plan = {
	Visual: string,
	Cooldown: number,
	Duration: number, -- quando o último pulso acontece
	Pulses: { Pulse },
	Burn: { Seconds: number, Dps: number, Foci: number, SpreadRange: number }?,
	DirX: number,
	DirZ: number,
}

local MAX_TARGETS = 40

local function noise(seed: number, salt: number): number
	local h = bit32.bxor(bit32.band(seed * 2654435761, 0xFFFFFFFF), bit32.band(salt * 2246822519, 0xFFFFFFFF))
	h = bit32.band(bit32.bxor(h, bit32.rshift(h, 15)) * 2246822519, 0xFFFFFFFF)
	h = bit32.bxor(h, bit32.rshift(h, 13))
	return (h % 100003) / 100003
end
ElementPlan.noise = noise

-- Nível dentro de 1..maxLevel (inteiro).
function ElementPlan.clampLevel(level: number, maxLevel: number): number
	return math.clamp(math.floor(tonumber(level) or 1), 1, maxLevel)
end

-- Quantas construções um pulso pode acertar: cresce com a área (raio²), com teto.
function ElementPlan.targets(element: any, radiusMult: number): number
	return math.clamp(math.ceil(element.MaxTargets * radiusMult * radiusMult), 1, MAX_TARGETS)
end

-- Direção do golpe no plano (de quem lançou para o alvo). Lançou no próprio pé: (1, 0).
function ElementPlan.direction(ox: number, oz: number, tx: number, tz: number): (number, number)
	local dx, dz = tx - ox, tz - oz
	local len = math.sqrt(dx * dx + dz * dz)
	if len < 1e-3 then
		return 1, 0
	end
	return dx / len, dz / len
end

function ElementPlan.level(element: any, level: number, maxLevel: number): any
	return element.Levels[ElementPlan.clampLevel(level, maxLevel)]
end

function ElementPlan.cooldown(element: any, level: number, maxLevel: number): number
	local spec = ElementPlan.level(element, level, maxLevel)
	return spec.Cooldown or element.Cooldown
end

function ElementPlan.build(
	element: any,
	level: number,
	maxLevel: number,
	ox: number,
	oz: number,
	tx: number,
	tz: number,
	seed: number
): Plan
	local spec = ElementPlan.level(element, level, maxLevel)
	local R = element.Radius
	local dx, dz = ElementPlan.direction(ox, oz, tx, tz)
	local pulses: { Pulse } = {}
	local salt = 0
	local function add(at: number, x: number, z: number, radiusMult: number, mult: number, shape: string, chain: any?)
		table.insert(pulses, {
			At = at,
			X = x,
			Z = z,
			Radius = R * radiusMult,
			Mult = mult,
			MaxTargets = ElementPlan.targets(element, radiusMult),
			Shape = shape,
			Chain = chain,
		})
	end
	for _, part in spec.Parts do
		local shape = part.Shape
		if shape == "Impact" then
			local count = part.Count or 1
			for i = 1, count do
				local x, z = tx, tz
				if count > 1 then
					salt += 1
					local a = noise(seed, salt) * math.pi * 2
					local d = (part.Spread or 0) * R * (0.5 + 0.5 * noise(seed, salt + 500))
					x, z = tx + math.cos(a) * d, tz + math.sin(a) * d
				end
				add((i - 1) * (part.Stagger or 0), x, z, part.Radius, part.Mult, shape, part.Chain)
			end
		elseif shape == "Cone" then
			for i = 0, part.Steps - 1 do
				local k = if part.Steps > 1 then i / (part.Steps - 1) else 0
				local r = part.RadiusFrom + (part.RadiusTo - part.RadiusFrom) * k
				-- os círculos seguem a direção, cada um encostado no anterior
				local along = i * R * (part.RadiusFrom + r) * 0.8
				add(i * part.Interval, tx + dx * along, tz + dz * along, r, part.Mult, shape)
			end
		elseif shape == "Ring" then
			for i = 1, part.Steps do
				local k = i / part.Steps
				local r = part.RadiusFrom + (part.RadiusTo - part.RadiusFrom) * k
				add(i * part.Interval, tx, tz, r, part.Mult, shape)
			end
		elseif shape == "Storm" then
			for i = 1, part.Count do
				salt += 1
				local a = noise(seed, salt) * math.pi * 2
				local d = part.Area * R * math.sqrt(noise(seed, salt + 700))
				local at = part.Duration * (i - 1) / math.max(part.Count - 1, 1)
				add(at, tx + math.cos(a) * d, tz + math.sin(a) * d, part.Radius, part.Mult, shape)
			end
		elseif shape == "Path" then
			local steps = math.max(1, math.floor(part.Duration / part.Interval + 0.5))
			-- o caminho balança um pouco para os lados (semente), não é uma linha reta perfeita
			local wobble = (noise(seed, 900) - 0.5) * 0.6
			for i = 0, steps - 1 do
				local t = i * part.Interval
				local along = part.Speed * t
				local side = math.sin(t * 1.7 + wobble * 10) * R * 0.6 * math.min(part.Speed, 1)
				add(t, tx + dx * along - dz * side, tz + dz * along + dx * side, part.Radius, part.Mult, shape)
			end
		else
			error("ElementPlan: forma desconhecida " .. tostring(shape))
		end
	end
	table.sort(pulses, function(a, b)
		return a.At < b.At
	end)
	local duration = 0
	for _, p in pulses do
		duration = math.max(duration, p.At)
	end
	return {
		Visual = spec.Visual,
		Cooldown = spec.Cooldown or element.Cooldown,
		Duration = duration,
		Pulses = pulses,
		Burn = spec.Burn,
		DirX = dx,
		DirZ = dz,
	}
end

export type Candidate = { Id: number, X: number, Z: number }

-- Cadeia (raio) / espalhar fogo: a partir de (x, z), salta para o vizinho mais perto ainda não usado, até
-- `hops` vezes, cada salto até `range` studs do ponto anterior. `used` = ids que não podem ser escolhidos.
-- Devolve os candidatos na ordem dos saltos (determinístico: empate vai para o menor id).
function ElementPlan.chain(
	x: number,
	z: number,
	candidates: { Candidate },
	hops: number,
	range: number,
	used: { [number]: boolean }
): { Candidate }
	local out = {}
	local cx, cz = x, z
	local r2 = range * range
	for _ = 1, hops do
		local best: Candidate? = nil
		local bestD = math.huge
		for _, c in candidates do
			if not used[c.Id] then
				local d = (c.X - cx) ^ 2 + (c.Z - cz) ^ 2
				if d <= r2 and (d < bestD or (d == bestD and best ~= nil and c.Id < best.Id)) then
					best, bestD = c, d
				end
			end
		end
		if best == nil then
			break
		end
		used[best.Id] = true
		table.insert(out, best)
		cx, cz = best.X, best.Z
	end
	return out
end

-- Dano útil esperado por segundo de UM jogador (para o simulador): soma dos pulsos x alvos que cada um acerta
-- numa cidade com `density` construções por stud², mais a cadeia e a queima, dividido pelo cooldown.
-- Path conta só a área NOVA que o caminho varre (o mesmo prédio não é contado de novo a cada pulso parado).
function ElementPlan.expectedDps(element: any, level: number, maxLevel: number, density: number): number
	local plan = ElementPlan.build(element, level, maxLevel, 0, 0, 0, 1, 1)
	local base = element.Damage * element.Power[ElementPlan.clampLevel(level, maxLevel)]
	local total, firstTargets = 0, nil
	for _, p in plan.Pulses do
		local area = math.pi * p.Radius * p.Radius
		local targets = math.clamp(density * area, 1, p.MaxTargets)
		firstTargets = firstTargets or targets
		total += base * p.Mult * targets
		if p.Chain then
			local k = 1
			for _ = 1, p.Chain.Hops do
				k *= p.Chain.Falloff
				total += base * p.Mult * k
			end
		end
	end
	local burn = plan.Burn
	if burn then
		local burning = (firstTargets or 1) + burn.Foci
		total += base * burn.Dps * burn.Seconds * burning
	end
	return total / plan.Cooldown
end

return ElementPlan
