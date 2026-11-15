--!strict
-- Busca das construções no alcance da "boca" (usada pelo servidor para comer e pelo cliente para os avisos).
-- Uma caixa alta cobre o círculo inteiro; depois cada peça é medida na horizontal (Logic/EatReach),
-- igual ao círculo desenhado no chão. Volta as construções da mais perto para a mais longe.

local Workspace = game:GetService("Workspace")

local EatReach = require(script.Parent.Logic.EatReach)

local EatQuery = {}

local QUERY_HEIGHT = 4000 -- cobre do fundo do mapa até o topo das torres

export type Hit = { Model: Model, Distance: number }

local function boxOf(part: BasePart): EatReach.Box
	local cf = part.CFrame
	local right, up, back = cf.XVector, cf.YVector, cf.ZVector
	local half = part.Size / 2
	return {
		X = cf.X,
		Y = cf.Y,
		Z = cf.Z,
		RX = right.X,
		RY = right.Y,
		RZ = right.Z,
		UX = up.X,
		UY = up.Y,
		UZ = up.Z,
		BX = back.X,
		BY = back.Y,
		BZ = back.Z,
		HX = half.X,
		HY = half.Y,
		HZ = half.Z,
	}
end

-- Construção (Model direto dentro de `buildings`) dona da peça.
function EatQuery.buildingOf(part: Instance, buildings: Instance): Model?
	local current: Instance? = part
	while current and current.Parent ~= buildings do
		current = current.Parent
	end
	if current and current:IsA("Model") then
		return current
	end
	return nil
end

-- `params` precisa filtrar só a pasta `buildings` (FilterType Include).
function EatQuery.inReach(position: Vector3, radius: number, buildings: Instance, params: OverlapParams): { Hit }
	local best: { [Model]: number } = {}
	local box = CFrame.new(position.X, 0, position.Z)
	local size = Vector3.new(radius * 2, QUERY_HEIGHT, radius * 2)
	for _, part in Workspace:GetPartBoundsInBox(box, size, params) do
		local model = EatQuery.buildingOf(part, buildings)
		if model == nil then
			continue
		end
		local distance = EatReach.horizontalDistance(position.X, position.Z, boxOf(part))
		if distance <= radius and distance < (best[model] or math.huge) then
			best[model] = distance
		end
	end
	local hits: { Hit } = {}
	for model, distance in best do
		table.insert(hits, { Model = model, Distance = distance })
	end
	table.sort(hits, function(a, b)
		return a.Distance < b.Distance
	end)
	return hits
end

return EatQuery
