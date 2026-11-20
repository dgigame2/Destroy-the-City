--!strict
-- Skills (Q) do tornado, puras: onde estão as zonas de cada skill a cada instante (servidor e cliente
-- calculam igual a partir do início, da origem e da direção), quanto duram e o tamanho da explosão final.
-- Números em Config/SkillConfig (tudo em raios do tornado de quem usa).

local Skills = {}

export type Zone = { X: number, Z: number, R: number }

-- Skill da forma (cada forma tem a sua; formas além da lista usam a última).
function Skills.forForm(skills: { any }, form: number): (number, any)
	local index = math.clamp(form, 1, #skills)
	return index, skills[index]
end

-- Quanto tempo a skill dura (Line: até chegar no fim do caminho).
function Skills.duration(def: any): number
	if def.Move == "Line" then
		return def.Travel / def.Speed
	end
	return def.Duration or 0
end

-- Zonas no tempo t (segundos desde o início). caster = posição atual do tornado; origin/dir = de quando usou;
-- radius = raio do tornado de quem usou.
function Skills.zones(
	def: any,
	t: number,
	casterX: number,
	casterZ: number,
	originX: number,
	originZ: number,
	dirX: number,
	dirZ: number,
	radius: number
): { Zone }
	local duration = Skills.duration(def)
	local progress = if duration > 0 then math.clamp(t / duration, 0, 1) else 1
	local size = def.Size * radius * (1 + (def.Grow or 0) * progress)
	local move = def.Move
	if move == "Self" then
		return { { X = casterX, Z = casterZ, R = size } }
	elseif move == "Fixed" then
		local ahead = (def.Ahead or 0) * radius
		return { { X = originX + dirX * ahead, Z = originZ + dirZ * ahead, R = size } }
	elseif move == "Line" then
		local along = math.min(def.Speed * t, def.Travel) * radius
		local side = 0
		if def.Wobble then
			side = math.sin(t * def.Wobble) * radius * 0.8 -- zigue-zague
		end
		return {
			{ X = originX + dirX * along - dirZ * side, Z = originZ + dirZ * along + dirX * side, R = size },
		}
	elseif move == "Orbit" then
		local orbit = def.Orbit * radius
		local left = duration - t
		if def.Return and left < def.Return then
			orbit *= math.max(left, 0) / def.Return -- voltando para o tornado
		end
		local zones = {}
		for k = 1, def.Count do
			local a = t * def.Spin + (k - 1) * math.pi * 2 / def.Count
			table.insert(zones, { X = casterX + math.cos(a) * orbit, Z = casterZ + math.sin(a) * orbit, R = size })
		end
		return zones
	end
	return {}
end

-- Onde estoura no fim: Orbit volta para o tornado; o resto estoura na última posição da zona.
function Skills.burstAt(
	def: any,
	casterX: number,
	casterZ: number,
	originX: number,
	originZ: number,
	dirX: number,
	dirZ: number,
	radius: number
): (number, number)
	if def.Move == "Orbit" then
		return casterX, casterZ
	end
	local zone = Skills.zones(def, Skills.duration(def), casterX, casterZ, originX, originZ, dirX, dirZ, radius)[1]
	return zone.X, zone.Z
end

-- Multiplicador da explosão final pelo que a skill destruiu (até o limite).
function Skills.burstMult(def: any, collected: number): number
	local burst = def.Burst
	if burst == nil then
		return 0
	end
	return 1 + math.min(collected, burst.Cap) * burst.PerItem
end

return Skills
