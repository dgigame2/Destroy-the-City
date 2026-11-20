--!strict
-- Matemática dos efeitos dos elementos (pura, testável no Lune). O client/City/ElementFx só desenha.
-- Pontos são tabelas { X, Y, Z } em studs, relativos ao ponto do impacto (Y para cima).

local ElementFxMath = {}

export type Point = { X: number, Y: number, Z: number }

-- Qualidade gráfica do Roblox (0 = automática, 1..10) -> fator 0..1 dos efeitos.
-- Automática vira o meio (o Roblox já baixa em aparelho fraco); 1 = mínimo, 10 = tudo.
function ElementFxMath.quality(savedLevel: number, minFactor: number, autoFactor: number): number
	if savedLevel <= 0 then
		return autoFactor
	end
	local t = (math.clamp(savedLevel, 1, 10) - 1) / 9
	return minFactor + (1 - minFactor) * t
end

-- Quantas partículas emitir: base x qualidade x (1 ou escala dos outros jogadores). Nunca 0 se base > 0.
function ElementFxMath.count(base: number, quality: number, own: boolean, othersScale: number): number
	if base <= 0 then
		return 0
	end
	return math.max(1, math.floor(base * quality * (if own then 1 else othersScale) + 0.5))
end

-- Raio em zigue-zague do céu (altura h) até o chão (0, 0, 0). As pontas ficam no eixo; o meio desvia até
-- `jitter` para os lados (mais no meio, menos nas pontas). rand() devolve [0, 1).
function ElementFxMath.bolt(height: number, segments: number, jitter: number, rand: () -> number): { Point }
	local points = {}
	for i = 0, segments do
		local t = i / segments
		local amount = if i == 0 or i == segments then 0 else jitter * math.sin(t * math.pi) ^ 0.5
		table.insert(points, {
			X = (rand() * 2 - 1) * amount,
			Y = height * (1 - t),
			Z = (rand() * 2 - 1) * amount,
		})
	end
	return points
end

-- Arco do raio entre dois pontos (cadeia): zigue-zague de a até b, pontas exatas, desvio para os lados e
-- um pouco para cima no meio (o arco "pula" por cima).
function ElementFxMath.between(a: Point, b: Point, segments: number, jitter: number, rand: () -> number): { Point }
	local points = {}
	for i = 0, segments do
		local t = i / segments
		local amount = if i == 0 or i == segments then 0 else jitter
		local lift = math.sin(t * math.pi) * jitter
		table.insert(points, {
			X = a.X + (b.X - a.X) * t + (rand() * 2 - 1) * amount,
			Y = a.Y + (b.Y - a.Y) * t + lift + (rand() * 2 - 1) * amount * 0.5,
			Z = a.Z + (b.Z - a.Z) * t + (rand() * 2 - 1) * amount,
		})
	end
	return points
end

-- Galho do raio: sai do ponto `from` e desce `length` na direção de um lado sorteado.
function ElementFxMath.branch(
	from: Point,
	length: number,
	segments: number,
	jitter: number,
	rand: () -> number
): { Point }
	local angle = rand() * math.pi * 2
	local dx, dz = math.cos(angle), math.sin(angle)
	local points = {}
	for i = 0, segments do
		local t = i / segments
		local amount = if i == 0 then 0 else jitter
		table.insert(points, {
			X = from.X + dx * length * 0.6 * t + (rand() * 2 - 1) * amount,
			Y = from.Y - length * t,
			Z = from.Z + dz * length * 0.6 * t + (rand() * 2 - 1) * amount,
		})
	end
	return points
end

-- Bola de fogo caindo: posição em t (0..1) de `start` até o impacto (0, 0, 0), acelerando (ease-in).
function ElementFxMath.fall(start: Point, t: number): Point
	local k = 1 - math.clamp(t, 0, 1) ^ 2
	return { X = start.X * k, Y = start.Y * k, Z = start.Z * k }
end

-- De onde a bola de fogo vem: do lado de quem lançou (dx, dz = direção do impacto até ele), lá do alto.
function ElementFxMath.fallStart(dx: number, dz: number, back: number, height: number): Point
	local len = math.sqrt(dx * dx + dz * dz)
	if len < 1e-3 then
		return { X = 0, Y = height, Z = 0 }
	end
	return { X = dx / len * back, Y = height, Z = dz / len * back }
end

-- Redemoinho do vento: fio k de n, na idade t (0..1). Ângulo gira, raio abre e o fio sobe.
-- Devolve as duas pontas do fio (o Beam curva entre elas).
function ElementFxMath.swirl(
	k: number,
	n: number,
	t: number,
	turns: number,
	radius0: number,
	radius1: number,
	rise: number,
	arc: number
): (Point, Point)
	local angle = (k - 1) / n * math.pi * 2 + t * turns * math.pi * 2
	local ease = 1 - (1 - t) ^ 2
	local r = radius0 + (radius1 - radius0) * ease
	local y = rise * ease
	local a: Point = { X = math.cos(angle) * r, Y = y, Z = math.sin(angle) * r }
	local b: Point = { X = math.cos(angle + arc) * r, Y = y + rise * 0.35, Z = math.sin(angle + arc) * r }
	return a, b
end

-- Curva de 0..1 que sobe rápido e some devagar (brilho de luz, transparência de anel).
function ElementFxMath.fade(t: number, peak: number): number
	if t <= 0 or t >= 1 then
		return 0
	end
	if t < peak then
		return t / peak
	end
	return 1 - (t - peak) / (1 - peak)
end

return ElementFxMath
