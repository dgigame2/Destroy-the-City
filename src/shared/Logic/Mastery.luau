--!strict
-- Nível de cada desastre (puro, testável no Lune). Quanto mais um desastre derruba, mais ele sobe de nível,
-- e cada nível o deixa mais forte e maior. O servidor (MasteryService) guarda o estado e chama estas funções.

local Mastery = {}

type Config = {
	MaxLevel: number,
	BaseXp: number,
	Growth: number,
	XpByTier: { number },
	ChainXp: number,
	PerLevel: { Damage: number, Size: number },
	Extras: { [string]: { [string]: number } },
}

export type Entry = { Level: number, Xp: number }

function Mastery.new(): Entry
	return { Level = 1, Xp = 0 }
end

-- XP para passar do nível `level` para o próximo (0 no nível máximo).
function Mastery.need(level: number, cfg: Config): number
	if level >= cfg.MaxLevel then
		return 0
	end
	return math.floor(cfg.BaseXp * cfg.Growth ^ (level - 1) + 0.5)
end

-- XP de uma construção derrubada (tier = índice do TierConfig; chain = caiu na reação em cadeia).
function Mastery.xp(tier: number, chain: boolean, cfg: Config): number
	local base = cfg.XpByTier[math.clamp(tier, 1, #cfg.XpByTier)] or 0
	return if chain then base * cfg.ChainXp else base
end

-- Soma XP; pode subir vários níveis de uma vez. Devolve quantos níveis subiu.
function Mastery.add(entry: Entry, xp: number, cfg: Config): number
	if xp <= 0 or entry.Level >= cfg.MaxLevel then
		return 0
	end
	local gained = 0
	entry.Xp += xp
	while entry.Level < cfg.MaxLevel do
		local need = Mastery.need(entry.Level, cfg)
		if entry.Xp < need then
			break
		end
		entry.Xp -= need
		entry.Level += 1
		gained += 1
	end
	if entry.Level >= cfg.MaxLevel then
		entry.Xp = 0
	end
	return gained
end

-- Multiplicador de dano no nível (1 no nível 1).
function Mastery.damage(level: number, cfg: Config): number
	return 1 + (math.max(level, 1) - 1) * cfg.PerLevel.Damage
end

-- Multiplicador de tamanho (raio da onda, do tornado, alcance dos pulos do raio).
function Mastery.size(level: number, cfg: Config): number
	return 1 + (math.max(level, 1) - 1) * cfg.PerLevel.Size
end

-- Pulos a mais do raio no nível.
function Mastery.extraHops(id: string, level: number, cfg: Config): number
	local extra = cfg.Extras[id]
	local every = extra and extra.HopsEvery
	if every == nil or every <= 0 then
		return 0
	end
	return math.floor((math.max(level, 1) - 1) / every)
end

-- Segundos a mais do tornado no nível.
function Mastery.extraDuration(id: string, level: number, cfg: Config): number
	local extra = cfg.Extras[id]
	local per = extra and extra.DurationPerLevel
	if per == nil then
		return 0
	end
	return (math.max(level, 1) - 1) * per
end

-- Fração da barra de XP (0..1; 1 no nível máximo).
function Mastery.progress(entry: Entry, cfg: Config): number
	local need = Mastery.need(entry.Level, cfg)
	if need <= 0 then
		return 1
	end
	return math.clamp(entry.Xp / need, 0, 1)
end

return Mastery
