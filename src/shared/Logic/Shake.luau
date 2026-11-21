--!strict
-- Matemática do tremor (pura, testável no Lune): força acumulada com teto e decaimento linear.

local Shake = {}

-- Soma um tremor novo ao atual, sem passar do teto.
function Shake.add(current: number, amount: number, max: number): number
	return math.min(current + amount, max)
end

-- Força depois de `dt` segundos, caindo até zero em `seconds` a partir de `start`.
function Shake.decay(intensity: number, start: number, seconds: number, dt: number): number
	if seconds <= 0 then
		return 0
	end
	return math.max(intensity - start / seconds * dt, 0)
end

-- Ângulo do balanço da UI no instante t (0..1 da duração): vai e volta 3 vezes, diminuindo.
function Shake.uiAngle(degrees: number, t: number): number
	if t >= 1 or t < 0 then
		return 0
	end
	return degrees * (1 - t) * math.sin(t * math.pi * 6)
end

-- Número somado: dentro da janela de junção, soma ao anterior; fora dela começa de novo.
function Shake.merge(previous: number, previousAt: number, amount: number, now: number, window: number): number
	if window > 0 and now - previousAt <= window then
		return previous + amount
	end
	return amount
end

-- Sequência de golpes (tom que sobe, tipo moedas do Mario): conta se o golpe veio dentro da janela.
function Shake.streak(count: number, lastAt: number, now: number, window: number): number
	if now - lastAt <= window then
		return count + 1
	end
	return 1
end

-- Tom do golpe n da sequência: sobe `step` por golpe até `cap` golpes, depois fica no topo.
function Shake.streakPitch(count: number, step: number, cap: number): number
	return 1 + math.clamp(count - 1, 0, cap) * step
end

return Shake
