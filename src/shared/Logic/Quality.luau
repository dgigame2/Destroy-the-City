--!strict
-- Tier de qualidade e LOD por chunk (puro, testável no Lune). O cliente (client/City/Quality, LodManager)
-- só aplica o resultado.

local Quality = {}

type Config = {
	Tiers: { [string]: any },
	Order: { string },
	Default: string,
	LowFps: number,
	ChunkSize: number,
	Hysteresis: number,
}

-- Tier automático: toque sem teclado = Low; com FPS medido abaixo de LowFps = Low; senão o padrão.
-- `chosen` (escolha do jogador no menu) vence tudo.
function Quality.pick(touch: boolean, keyboard: boolean, avgFps: number?, chosen: string?, cfg: Config): string
	if chosen and cfg.Tiers[chosen] then
		return chosen
	end
	if touch and not keyboard then
		return "Low"
	end
	if avgFps and avgFps < cfg.LowFps then
		return "Low"
	end
	return cfg.Default
end

-- Chunk (inteiros) de uma posição XZ.
function Quality.chunkOf(x: number, z: number, size: number): (number, number)
	return math.floor(x / size), math.floor(z / size)
end

-- Chave única do chunk (para tabela).
function Quality.chunkKey(cx: number, cz: number): number
	return (cx + 32768) * 65536 + (cz + 32768)
end

-- Distância (no plano) do ponto até o centro do chunk.
function Quality.chunkDistance(cx: number, cz: number, x: number, z: number, size: number): number
	local dx, dz = (cx + 0.5) * size - x, (cz + 0.5) * size - z
	return math.sqrt(dx * dx + dz * dz)
end

export type Band = "Near" | "Mid" | "Far"
local RANK = { Near = 1, Mid = 2, Far = 3 }

-- Faixa de LOD com histerese: para AFASTAR (Near -> Mid, Mid -> Far) a distância tem que passar o limite
-- x (1 + h); para APROXIMAR basta ficar abaixo do limite. Assim não fica trocando na borda.
-- `half` = metade da diagonal do chunk: a distância conta do ponto do chunk mais perto (nada some de perto).
function Quality.band(distance: number, current: Band?, near: number, mid: number, h: number, half: number): Band
	local d = math.max(distance - half, 0)
	local plain: Band = if d <= near then "Near" elseif d <= mid then "Mid" else "Far"
	if current == nil or RANK[plain] <= RANK[current] then
		return plain -- aproximando (ou primeira vez): troca já
	end
	-- afastando: só sai da faixa atual depois da folga
	local limit = if current == "Near" then near else mid
	if d <= limit * (1 + h) then
		return current
	end
	return if current == "Near" and d <= mid then "Mid" else plain
end

-- Peça é "detalhe" (some na faixa Mid)?
function Quality.isDetail(sx: number, sy: number, sz: number, maxVolume: number): boolean
	return sx * sy * sz <= maxVolume
end

return Quality
