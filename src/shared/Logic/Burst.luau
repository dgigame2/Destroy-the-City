--!strict
-- Soma de uma leva de destruição (puro, testável no Lune). Cada objeto que você derruba entra na leva; a
-- leva acaba depois de `Quiet` segundos sem nada cair e vira um resumo só (Config/BurstConfig).

export type Tier = { Min: number, Text: string, Color: { number } }
export type Config = { Quiet: number, Tiers: { Tier } }
export type State = { Count: number, Coins: number, Last: number }

local Burst = {}

function Burst.new(): State
	return { Count = 0, Coins = 0, Last = -math.huge }
end

-- Mais um objeto derrubado agora (`coins` = dinheiro dele).
function Burst.add(state: State, coins: number, now: number)
	state.Count += 1
	state.Coins += math.max(coins, 0)
	state.Last = now
end

-- Maior faixa que a contagem alcança (nil = golpe pequeno, sem aviso).
function Burst.tier(count: number, cfg: Config): Tier?
	local best = nil
	for _, tier in cfg.Tiers do
		if count >= tier.Min then
			best = tier
		end
	end
	return best
end

-- A leva acabou? Devolve (contagem, dinheiro) e zera; (0, 0) se ainda está caindo coisa ou está vazia.
function Burst.flush(state: State, now: number, cfg: Config): (number, number)
	if state.Count == 0 or now - state.Last < cfg.Quiet then
		return 0, 0
	end
	local count, coins = state.Count, state.Coins
	state.Count, state.Coins = 0, 0
	return count, coins
end

return Burst
