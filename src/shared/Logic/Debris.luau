--!strict
-- Matemática dos objetos que voam (pura, testável no Lune): puxar para o tornado, girar, arremessar,
-- tempo de voo e dano da batida. O servidor (DebrisService) só move as peças com estes números.

local Debris = {}

type Config = {
	MaxActive: number,
	Gravity: number,
	Lift: {
		Radius: number,
		Tiers: { [string]: boolean },
		Swirl: number,
		Pull: number,
		OrbitRadius: number,
		Rise: number,
	},
	ThrowChance: number,
	ThrowSpeed: number,
	ThrowLift: number,
	ImpactRadius: number,
	ImpactDamage: number,
	ImpactEdge: number,
	Blast: { Pieces: number, Speed: number, Lift: number, DamageFactor: number },
}

-- Cabe mais um voando agora?
function Debris.canSpawn(active: number, cfg: Config): boolean
	return active < cfg.MaxActive
end

-- O funil arranca esse tier? (só os leves e só se o seu poder já alcança)
function Debris.lifts(tierName: string, required: number, power: number, cfg: Config): boolean
	return cfg.Lift.Tiers[tierName] == true and power + 1e-9 >= required
end

-- Velocidade de um objeto preso no funil (centro cx, cz; raio do funil r): puxa até o anel de giro,
-- gira em volta (sentido anti-horário visto de cima) e sobe. Devolve vx, vy, vz.
function Debris.orbitVelocity(
	px: number,
	pz: number,
	cx: number,
	cz: number,
	r: number,
	cfg: Config
): (number, number, number)
	local dx, dz = px - cx, pz - cz
	local d = math.sqrt(dx * dx + dz * dz)
	if d < 1e-6 then
		dx, dz, d = 1, 0, 1
	end
	local ux, uz = dx / d, dz / d
	local ring = r * cfg.Lift.OrbitRadius
	-- para dentro quando está longe do anel, para fora quando está perto demais do centro
	local radial = math.clamp((ring - d) / math.max(ring, 1e-6), -1, 1) * cfg.Lift.Pull
	-- tangente (gira)
	local tx, tz = -uz, ux
	return ux * radial + tx * cfg.Lift.Swirl, cfg.Lift.Rise, uz * radial + tz * cfg.Lift.Swirl
end

-- Velocidade de saída: para fora do centro (na direção do objeto) com força `speed` e subida `lift`.
function Debris.throwVelocity(
	px: number,
	pz: number,
	cx: number,
	cz: number,
	speed: number,
	lift: number
): (number, number, number)
	local dx, dz = px - cx, pz - cz
	local d = math.sqrt(dx * dx + dz * dz)
	if d < 1e-6 then
		return speed, lift, 0
	end
	return dx / d * speed, lift, dz / d * speed
end

-- Sai arremessado (true) ou cai perto (false)? `roll` em [0, 1).
function Debris.thrown(roll: number, cfg: Config): boolean
	return roll < cfg.ThrowChance
end

-- Tempo até voltar ao chão saindo `height` studs acima dele com velocidade vertical `vy` (física simples).
function Debris.flightTime(vy: number, height: number, gravity: number): number
	-- height + vy t - g t^2 / 2 = 0
	local disc = vy * vy + 2 * gravity * math.max(height, 0)
	return (vy + math.sqrt(disc)) / gravity
end

-- Dano da batida a `distance` do ponto: HP do objeto x ImpactDamage, cai até ImpactEdge na borda.
function Debris.impactDamage(sourceHp: number, distance: number, cfg: Config): number
	if distance > cfg.ImpactRadius then
		return 0
	end
	local t = distance / math.max(cfg.ImpactRadius, 1e-6)
	return sourceHp * cfg.ImpactDamage * (1 + (cfg.ImpactEdge - 1) * t)
end

-- HP "de arremesso" de cada pedaço solto por uma explosão/desabamento (divide o total entre eles).
function Debris.blastPieceHp(sourceHp: number, cfg: Config): number
	return sourceHp * cfg.Blast.DamageFactor / math.max(cfg.Blast.Pieces, 1) / cfg.ImpactDamage
end

-- Quantos pedaços uma explosão/desabamento solta agora (respeita o limite de voando).
function Debris.blastPieces(active: number, cfg: Config): number
	return math.max(0, math.min(cfg.Blast.Pieces, cfg.MaxActive - active))
end

return Debris
