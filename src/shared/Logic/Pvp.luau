--!strict
-- Matemática do PvP entre tornados (pura). Números em Config/PvpConfig.

local Tornado = if script then require(script.Parent.Tornado) else require("./Tornado")

local Pvp = {}

export type Config = {
	Hp: { Base: number, Growth: number },
	Burst: {
		Cooldown: number,
		Reach: number,
		ReachExtra: number,
		MinDot: number,
		HpShare: number,
		CitySeconds: number,
	},
	Shield: { Spawn: number },
	Regen: { Delay: number, Share: number },
	KillXpShare: number,
}

function Pvp.maxHp(cfg: Config, level: number): number
	return cfg.Hp.Base * cfg.Hp.Growth ^ (level - 1)
end

function Pvp.levelAfterDeath(level: number, xp: number): number
	return if xp <= 0 then math.max(1, level - 1) else level
end

-- XP de quem mata: parte da barra do nível da vítima (caçar compensa, sem roubar o nível).
function Pvp.killXp(cfg: Config, tornado: Tornado.Config, victimLevel: number): number
	return cfg.KillXpShare * Tornado.xpToNext(tornado, victimLevel)
end

function Pvp.regen(cfg: Config, hp: number, maxHp: number, sinceHit: number, dt: number): number
	if sinceHit < cfg.Regen.Delay or hp <= 0 then
		return hp
	end
	return math.min(maxHp, hp + maxHp * cfg.Regen.Share * dt)
end

-- Mantém a mesma porcentagem de vida quando a vida máxima muda (subir de nível / rebirth).
function Pvp.rescale(hp: number, oldMax: number, newMax: number): number
	if oldMax <= 0 then
		return newMax
	end
	return math.clamp(hp / oldMax * newMax, 0, newMax)
end

-- Direção (x, z) vinda do cliente: números finitos e não nulos, normalizada. nil = inválida.
function Pvp.direction(x: any, z: any): (number?, number?)
	if type(x) ~= "number" or type(z) ~= "number" then
		return nil, nil
	end
	local length = math.sqrt(x * x + z * z)
	if length ~= length or length < 1e-6 or length == math.huge then
		return nil, nil
	end
	return x / length, z / length
end

-- O alvo (tx, tz) está no cone à frente de (ox, oz) na direção unitária (dx, dz)?
function Pvp.inFront(
	ox: number,
	oz: number,
	dx: number,
	dz: number,
	tx: number,
	tz: number,
	reach: number,
	minDot: number
): boolean
	local vx, vz = tx - ox, tz - oz
	local distance = math.sqrt(vx * vx + vz * vz)
	if distance > reach then
		return false
	end
	if distance < 1e-3 then
		return true
	end
	return (vx * dx + vz * dz) / distance >= minDot
end

-- Tela de morte: quanto da barra já tinha (0..100, inteiro) e se já dava para EVOLVE (XP junta além da barra).
function Pvp.deathProgress(tornado: Tornado.Config, level: number, xp: number): (number, boolean)
	local need = Tornado.xpToNext(tornado, level)
	return math.floor(math.clamp(xp / need, 0, 1) * 100), xp >= need
end

return Pvp
