--!strict
-- Progressão por áreas (zonas) da cidade, puro (testável no Lune).
-- A zona atual é a primeira que ainda tem coisa para comer; ela e as anteriores ficam abertas.

local Zones = {}

-- remaining[k] = construções que faltam na zona k. Devolve a zona atual (aberta mais alta).
function Zones.current(remaining: { number }): number
	for zone, left in remaining do
		if left > 0 then
			return zone
		end
	end
	return #remaining
end

export type Reward = { Gems: number, Cash: number, FrenzySeconds: number }

type RewardConfig = { GemsPerZone: number, CashPerZone: number, FrenzySeconds: number }

-- Prêmio por terminar a zona `zone` (cresce a cada zona; gemas multiplicadas pela dificuldade).
function Zones.reward(zone: number, cfg: RewardConfig, rewardMultiplier: number): Reward
	return {
		Gems = math.floor(cfg.GemsPerZone * zone * rewardMultiplier + 0.5),
		Cash = cfg.CashPerZone * zone * zone,
		FrenzySeconds = cfg.FrenzySeconds,
	}
end

-- Frenesi ativo (depois de abrir uma zona, tudo rende em dobro por um tempo)?
function Zones.frenzyActive(untilTime: number?, now: number): boolean
	return untilTime ~= nil and untilTime > now
end

type AutoCollectConfig = { At: number, ShowAs: number }

-- Já comeu o bastante da zona para o resto ser coletado sozinho? (sobrou algo e comeu >= At)
function Zones.shouldAutoCollect(left: number, total: number, cfg: AutoCollectConfig): boolean
	return total > 0 and left > 0 and (total - left) / total >= cfg.At - 1e-9
end

-- Porcentagem mostrada na tela (0-100, inteira): o real em escala para At aparecer como ShowAs.
-- Zona terminada (nada sobrando) mostra 100.
function Zones.displayPercent(left: number, total: number, cfg: AutoCollectConfig): number
	if total <= 0 or left <= 0 then
		return 100
	end
	local fraction = (total - left) / total
	return math.clamp(math.floor(fraction * cfg.ShowAs / cfg.At * 100 + 1e-6), 0, 99)
end

return Zones
