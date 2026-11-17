--!strict
-- Matemática dos desastres (pura, testável no Lune). O servidor (DisasterService) só busca as construções
-- perto e aplica o que estas funções decidem. Tudo no plano X/Z.

local Disasters = {}

type Tier = { RequiredScale: number }
type Disaster = { [string]: any }
type Config = { RadiusExponent: number, RangeExponent: number, SpeedExponent: number }

-- Raio / alcance / velocidade no poder atual.
function Disasters.radius(disaster: Disaster, power: number, cfg: Config): number
	return disaster.Radius * power ^ cfg.RadiusExponent
end

function Disasters.range(disaster: Disaster, power: number, cfg: Config): number
	return disaster.Range * power ^ cfg.RangeExponent
end

function Disasters.speed(disaster: Disaster, power: number, cfg: Config): number
	return disaster.Speed * power ^ cfg.SpeedExponent
end

-- HP de uma construção do tier.
function Disasters.structureHp(tier: Tier, hpPerScale: number): number
	return hpPerScale * tier.RequiredScale
end

-- Construção mais forte que o seu poder: o dano cai para `under` x (poder / exigido). Nada fica travado, mas
-- as fortes (avião, hangar...) levam MUITO mais acertos até você ficar mais forte. 1 = poder suficiente.
function Disasters.underPower(power: number, tier: Tier, under: number): number
	if power + 1e-9 >= tier.RequiredScale then
		return 1
	end
	return under * power / tier.RequiredScale
end

-- Papel do desastre: multiplicador de dano contra o tier (DisasterConfig Vs por nome do tier; 1 se não tem).
function Disasters.vs(disaster: Disaster, tier: Tier): number
	local list = disaster.Vs
	local name = (tier :: any).Name
	return if list and name and list[name] then list[name] else 1
end

-- Dano de um acerto antes da distância. Coisas menores que o seu poder levam mais (TierExponent alto =
-- ótimo contra pequenos); as maiores levam pouco (underPower). `under` = StructureConfig.UnderPower.
-- `cap` = DisasterConfig.OverkillCap: a vantagem (poder / exigido) conta no máximo até ele (end game).
function Disasters.hitDamage(
	disaster: Disaster,
	power: number,
	tier: Tier,
	bonus: number?,
	under: number?,
	cap: number?
): number
	local size = math.min(power / tier.RequiredScale, cap or math.huge) ^ disaster.TierExponent
		* Disasters.vs(disaster, tier)
	-- desastre com UnderPower próprio (meteoro) sofre menos contra o que é maior que você
	local weak = Disasters.underPower(power, tier, disaster.UnderPower or under or 0)
	return disaster.Damage * power * size * weak * (bonus or 1)
end

-- Fração do dano do meteoro a `distance` do centro (dano cheio no miolo, cai até EdgeDamage na borda).
function Disasters.meteorFalloff(distance: number, radius: number, core: number, edge: number): number
	if distance > radius then
		return 0
	end
	local inner = radius * core
	if distance <= inner then
		return 1
	end
	local t = (distance - inner) / math.max(radius - inner, 1e-6)
	return 1 + (edge - 1) * t
end

-- Mira trazida para dentro do alcance (o cliente pode pedir longe demais; o servidor nunca confia).
function Disasters.clampTarget(ox: number, oz: number, tx: number, tz: number, range: number): (number, number)
	local dx, dz = tx - ox, tz - oz
	local d = math.sqrt(dx * dx + dz * dz)
	if d <= range or d == 0 then
		return tx, tz
	end
	return ox + dx / d * range, oz + dz / d * range
end

-- Mira só no chão das áreas liberadas: se o ponto pedido não vale (mar, área fechada, fora do mapa), volta pela
-- linha jogador -> mira, de `step` em `step` studs, até o último ponto que vale. `valid(x, z)` diz se vale.
-- Devolve o ponto e se achou algum (false = nem o ponto do jogador vale: o desastre não sai).
function Disasters.pullInside(
	ox: number,
	oz: number,
	tx: number,
	tz: number,
	step: number,
	valid: (number, number) -> boolean
): (number, number, boolean)
	if valid(tx, tz) then
		return tx, tz, true
	end
	local dx, dz = tx - ox, tz - oz
	local n = math.max(1, math.ceil(math.sqrt(dx * dx + dz * dz) / step))
	for k = n - 1, 0, -1 do
		local x, z = ox + dx * k / n, oz + dz * k / n
		if valid(x, z) then
			return x, z, true
		end
	end
	return ox, oz, false
end

-- Por quantos segundos o tornado anda sem sair do chão liberado (no máximo `duration`).
function Disasters.travelTime(
	sx: number,
	sz: number,
	dirX: number,
	dirZ: number,
	speed: number,
	duration: number,
	step: number,
	valid: (number, number) -> boolean
): number
	local dt = step / math.max(speed, 1e-6)
	local t = 0
	while t + dt <= duration + 1e-9 do
		local x, z = sx + dirX * speed * (t + dt), sz + dirZ * speed * (t + dt)
		if not valid(x, z) then
			return t
		end
		t += dt
	end
	return duration
end

-- Posição do tornado no tempo t (anda em linha reta a partir de start na direção dir, unitária).
function Disasters.tornadoAt(
	sx: number,
	sz: number,
	dirX: number,
	dirZ: number,
	speed: number,
	t: number
): (number, number)
	return sx + dirX * speed * t, sz + dirZ * speed * t
end

-- O desastre arrasta e derruba na hora esse tier (objetos leves no caminho do tornado)? Só se o seu poder
-- já alcança o tier (o leve demais para você).
function Disasters.sweeps(disaster: Disaster, power: number, tier: Tier & { Name: string }): boolean
	local list = disaster.Sweeps
	return list ~= nil and list[tier.Name] == true and power + 1e-9 >= tier.RequiredScale
end

-- Quantos tiques, no pior caso, um ponto bem no caminho do tornado fica dentro do funil numa passada.
function Disasters.contactTicks(radius: number, speed: number, tick: number): number
	return math.max(1, math.floor(2 * radius / math.max(speed * tick, 1e-6)))
end

-- Direção unitária de (ox, oz) para (tx, tz); se forem o mesmo ponto, usa a direção padrão.
function Disasters.direction(ox: number, oz: number, tx: number, tz: number, fx: number, fz: number): (number, number)
	local dx, dz = tx - ox, tz - oz
	local d = math.sqrt(dx * dx + dz * dz)
	if d < 1e-6 then
		local fd = math.sqrt(fx * fx + fz * fz)
		if fd < 1e-6 then
			return 0, -1
		end
		return fx / fd, fz / fd
	end
	return dx / d, dz / d
end

export type Node = { Id: number, X: number, Z: number, Conductor: boolean }
export type Hop = { Id: number, Strength: number, From: number? }

-- Cadeia do raio: começa no nó mais perto da mira (até `snap`) e pula para o vizinho mais perto ainda não
-- atingido. Cada pulo multiplica a força por `decay`, a não ser que saia de um condutor (aí não perde força e
-- o alcance do pulo é hopRange x conductorRange). Para quando não há vizinho ou acabam os pulos.
-- Cada nó é atingido no máximo uma vez. Devolve a lista de acertos na ordem.
function Disasters.lightningChain(
	nodes: { Node },
	tx: number,
	tz: number,
	snap: number,
	hops: number,
	hopRange: number,
	decay: number,
	conductorRange: number
): { Hop }
	local result: { Hop } = {}
	local used: { [number]: boolean } = {}
	local current: Node? = nil
	local best = snap * snap
	for _, node in nodes do
		local d = (node.X - tx) ^ 2 + (node.Z - tz) ^ 2
		if d <= best then
			best, current = d, node
		end
	end
	if current == nil then
		return result
	end
	local strength = 1
	table.insert(result, { Id = current.Id, Strength = strength, From = nil })
	used[current.Id] = true
	for _ = 1, hops do
		local from = current :: Node
		local reach = if from.Conductor then hopRange * conductorRange else hopRange
		local nextNode: Node? = nil
		local nearest = reach * reach
		for _, node in nodes do
			if not used[node.Id] then
				local d = (node.X - from.X) ^ 2 + (node.Z - from.Z) ^ 2
				if d <= nearest then
					nearest, nextNode = d, node
				end
			end
		end
		if nextNode == nil then
			break
		end
		if not from.Conductor then
			strength *= decay
		end
		used[nextNode.Id] = true
		table.insert(result, { Id = nextNode.Id, Strength = strength, From = from.Id })
		current = nextNode
	end
	return result
end

-- Bônus de upgrades + classe de um jogador para os desastres (todos multiplicadores, 1 = nada).
-- `multiplier(stat)` = GrowthService.multiplier (1 + upgrade + classe). Cooldown vira divisor.
export type Mods = { Damage: number, Size: number, Range: number, Cooldown: number, Duration: number, Chain: number }
function Disasters.mods(multiplier: (string) -> number): Mods
	return {
		Damage = multiplier("Damage"),
		Size = multiplier("Magnet"),
		Range = multiplier("Range"),
		Cooldown = multiplier("Cooldown"),
		Duration = multiplier("Duration"),
		Chain = multiplier("Chain"),
	}
end

-- Cooldown real com o bônus de recarga (`recharge` = multiplicador; 1.3 = 30% mais rápido).
function Disasters.cooldown(disaster: Disaster, recharge: number?): number
	return disaster.Cooldown / math.max(recharge or 1, 1e-6)
end

-- Cooldown: pode usar de novo? (`last` = quando usou pela última vez; nil = nunca)
function Disasters.ready(last: number?, cooldown: number, now: number): boolean
	return last == nil or now - last >= cooldown - 1e-6
end

return Disasters
