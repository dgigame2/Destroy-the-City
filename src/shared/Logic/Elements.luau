--!strict
-- Matemática dos elementos (pura). O servidor usa para o dano; o cliente só para mostrar.

local Elements = {}

-- Dano do golpe no nível L: Damage × Power[L] (calibrado; ver Config/ElementConfig). Nível fora de
-- 1..MaxLevel é cortado.
function Elements.damage(element: any, level: number, maxLevel: number): number
	local l = math.clamp(math.floor(tonumber(level) or 1), 1, maxLevel)
	return element.Damage * element.Power[l]
end

-- Multiplicador contra uma construção (identidade do elemento).
function Elements.against(element: any, category: string, height: number, tallBonus: number): number
	local m = element.Strong[category] or 1
	if element.TallFrom and height >= element.TallFrom then
		m *= tallBonus
	end
	return m
end

-- Pode lançar? (cooldown e alcance, conferidos no servidor). cooldown = o do nível (padrão: o base).
function Elements.canCast(
	element: any,
	lastAt: number?,
	now: number,
	distance: number,
	cooldown: number?
): (boolean, string?)
	if lastAt and now - lastAt < (cooldown or element.Cooldown) - 1e-3 then
		return false, "Cooldown"
	end
	if not (distance <= element.Range) then
		return false, "Range"
	end
	return true, nil
end

return Elements
