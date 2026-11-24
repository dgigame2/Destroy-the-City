--!strict
-- Matemática do tornado (pura): XP por nível, evoluir, tamanho, dano, velocidade, forma e rebirth.
-- Números em Config/TornadoConfig.
-- Subir de nível é na mão (EVOLVE): o XP junta além da barra e o jogador evolui um nível por vez.
-- Nível máximo = BaseMaxLevel + rebirths, até MaxLevel. No máximo, com a barra cheia, libera o rebirth.

local Tornado = {}

export type Form = {
	From: number,
	Name: string,
	Color: { number },
	Height: number,
	Base: number,
	Top: number,
	Bend: number,
	Crown: number,
	Density: number,
	Spin: number,
	Twist: number,
	Bands: number,
}

export type Config = {
	BaseMaxLevel: number,
	MaxLevel: number,
	XpBase: number,
	XpGrowth: number,
	PropXp: number,
	Radius: { Base: number, Step: number },
	Dps: { Base: number, Growth: number },
	WalkSpeed: { Base: number, Step: number },
	Rebirth: { XpBonus: number, DamageBonus: number },
	Forms: { Form },
}

-- XP para sair do nível `level` (no nível máximo a barra não enche mais).
function Tornado.xpToNext(cfg: Config, level: number): number
	return cfg.XpBase * cfg.XpGrowth ^ (level - 1)
end

-- Nível máximo com estes rebirths.
function Tornado.maxLevel(cfg: Config, rebirths: number): number
	return math.min(cfg.BaseMaxLevel + rebirths, cfg.MaxLevel)
end

-- Quantos rebirths existem (depois disso o nível máximo não sobe mais).
function Tornado.maxRebirths(cfg: Config): number
	return cfg.MaxLevel - cfg.BaseMaxLevel
end

-- Soma o XP (o nível não muda sozinho). Só no fim de tudo (teto e sem rebirth) a barra para cheia.
function Tornado.addXp(cfg: Config, level: number, xp: number, gain: number, rebirths: number): number
	xp += gain
	if level >= cfg.MaxLevel and rebirths >= Tornado.maxRebirths(cfg) then
		xp = math.min(xp, Tornado.xpToNext(cfg, level))
	end
	return xp
end

-- Barra cheia e ainda abaixo do máximo: pode evoluir (subir 1 nível).
function Tornado.canEvolve(cfg: Config, level: number, xp: number, rebirths: number): boolean
	return level < Tornado.maxLevel(cfg, rebirths) and xp >= Tornado.xpToNext(cfg, level)
end

-- Sobe 1 nível gastando a barra (o que sobra continua). nil = não dá.
function Tornado.evolve(cfg: Config, level: number, xp: number, rebirths: number): (number?, number?)
	if not Tornado.canEvolve(cfg, level, xp, rebirths) then
		return nil, nil
	end
	return level + 1, xp - Tornado.xpToNext(cfg, level)
end

-- XP de um objeto destruído (props têm valor 0 e dão só PropXp), com o bônus dos rebirths.
function Tornado.xpFor(cfg: Config, value: number, rebirths: number): number
	return (value + cfg.PropXp) * (1 + cfg.Rebirth.XpBonus * rebirths)
end

function Tornado.radius(cfg: Config, level: number): number
	return cfg.Radius.Base + cfg.Radius.Step * (level - 1)
end

-- A esfera cobre o funil mesmo quando a câmera gira ou inclina.
function Tornado.cameraDistance(halfHeight: number, outerRadius: number, verticalFov: number, aspect: number): number
	local verticalSlope = math.tan(math.rad(verticalFov) / 2)
	local narrowHalfAngle = math.atan(verticalSlope * math.min(1, aspect))
	local sphereRadius = math.sqrt(halfHeight ^ 2 + outerRadius ^ 2)
	return sphereRadius / math.sin(narrowHalfAngle)
end

function Tornado.dps(cfg: Config, level: number, rebirths: number): number
	return cfg.Dps.Base * cfg.Dps.Growth ^ (level - 1) * (1 + cfg.Rebirth.DamageBonus * rebirths)
end

function Tornado.walkSpeed(cfg: Config, level: number): number
	return cfg.WalkSpeed.Base + cfg.WalkSpeed.Step * (level - 1)
end

-- Índice da forma do nível (1 = a primeira).
function Tornado.form(cfg: Config, level: number): number
	local index = 1
	for i, form in cfg.Forms do
		if level >= form.From then
			index = i
		end
	end
	return index
end

function Tornado.visualRadius(form: Form, heightFraction: number): number
	return form.Base + (form.Top - form.Base) * heightFraction
end

function Tornado.rebirthColor(colors: { { From: number, Color: { number } } }, rebirths: number): { number }?
	local color = nil
	for _, tier in colors do
		if rebirths < tier.From then
			break
		end
		color = tier.Color
	end
	return color
end

-- Quem é o maior tornado do servidor (coroa): maior nível, desempate por rebirths.
-- nil com menos de 2 jogadores ou empate no topo (no começo todos são nível 1: ninguém tem coroa).
function Tornado.biggest(entries: { { Id: number, Level: number, Rebirths: number } }): number?
	if #entries < 2 then
		return nil
	end
	local best, tied = nil, false
	for _, e in entries do
		if best == nil or e.Level > best.Level or (e.Level == best.Level and e.Rebirths > best.Rebirths) then
			best, tied = e, false
		elseif e.Level == best.Level and e.Rebirths == best.Rebirths then
			tied = true
		end
	end
	return if best and not tied then best.Id else nil
end

-- No nível máximo, com a barra cheia e ainda com rebirth sobrando.
function Tornado.canRebirth(cfg: Config, level: number, xp: number, rebirths: number): boolean
	return rebirths < Tornado.maxRebirths(cfg)
		and level >= Tornado.maxLevel(cfg, rebirths)
		and xp >= Tornado.xpToNext(cfg, level)
end

-- Número finito ou o padrão (save corrompido/antigo nunca vira NaN ou infinito no jogo).
local function finite(value: any, default: number): number
	local n = tonumber(value)
	if n == nil or n ~= n or n == math.huge or n == -math.huge then
		return default
	end
	return n
end

-- Limpa nível, XP e rebirths vindos do save: inteiros dentro dos limites, XP nunca negativo.
function Tornado.sanitize(cfg: Config, level: any, xp: any, rebirths: any): (number, number, number)
	local r = math.clamp(math.floor(finite(rebirths, 0)), 0, Tornado.maxRebirths(cfg))
	local l = math.clamp(math.floor(finite(level, 1)), 1, Tornado.maxLevel(cfg, r))
	local x = math.max(0, finite(xp, 0))
	return l, x, r
end

return Tornado
