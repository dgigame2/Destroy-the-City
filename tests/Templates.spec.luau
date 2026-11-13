-- Verificações de construções: FLOATING / NO FOOTING (todo bloco apoiado), limites do footprint, tiers e cores.
local Templates = require("../src/shared/Buildings/Templates")
local TierConfig = require("../src/shared/Config/TierConfig")
local MapConfig = require("../src/shared/Config/MapConfig")

local EPS = 0.01

local function bounds(b)
	local min, max = {}, {}
	for axis = 1, 3 do
		min[axis] = b.Pos[axis] - b.Size[axis] / 2
		max[axis] = b.Pos[axis] + b.Size[axis] / 2
	end
	return min, max
end

-- Dois blocos se tocam ou se sobrepõem (com tolerância).
local function touching(a, b)
	local amin, amax = bounds(a)
	local bmin, bmax = bounds(b)
	for axis = 1, 3 do
		if amin[axis] > bmax[axis] + EPS or bmin[axis] > amax[axis] + EPS then
			return false
		end
	end
	return true
end

-- Retorna os blocos que não estão ligados ao chão por uma cadeia de blocos que se tocam.
local function unsupported(template)
	local supported = {}
	local queue = {}
	for i, b in template.Boxes do
		local min = bounds(b)
		if math.abs(min[2]) <= EPS then
			supported[i] = true
			table.insert(queue, i)
		end
	end
	while #queue > 0 do
		local current = table.remove(queue) :: number
		for i, b in template.Boxes do
			if not supported[i] and touching(template.Boxes[current], b) then
				supported[i] = true
				table.insert(queue, i)
			end
		end
	end
	local missing = {}
	for i in template.Boxes do
		if not supported[i] then
			table.insert(missing, i)
		end
	end
	return missing
end

return function(t)
	for name, template in Templates do
		t.test(`{name}: nenhum bloco flutuando`, function()
			local missing = unsupported(template)
			if #missing > 0 then
				error(`blocos soltos: {table.concat(missing, ", ")}`)
			end
		end)

		t.test(`{name}: nada abaixo do chão e tudo dentro do footprint`, function()
			local halfW, halfD = template.Footprint[1] / 2, template.Footprint[2] / 2
			for i, b in template.Boxes do
				local min, max = bounds(b)
				if min[2] < -EPS then
					error(`bloco {i} abaixo do chão`)
				end
				if min[1] < -halfW - EPS or max[1] > halfW + EPS or min[3] < -halfD - EPS or max[3] > halfD + EPS then
					error(`bloco {i} sai do footprint {template.Footprint[1]}x{template.Footprint[2]}`)
				end
			end
		end)

		t.test(`{name}: tier válido e cores existentes em todas as paletas`, function()
			t.truthy(TierConfig[template.Tier] ~= nil)
			for _, map in MapConfig do
				for _, b in template.Boxes do
					if map.Palette[b.Role] == nil then
						error(`papel de cor '{b.Role}' não existe na paleta de {map.Id}`)
					end
				end
			end
		end)
	end

	t.test("todo tier tem pelo menos um modelo", function()
		local seen = {}
		for _, template in Templates do
			seen[template.Tier] = true
		end
		for tier in TierConfig do
			t.truthy(seen[tier])
		end
	end)

	t.test("modelo maior = tier maior (pela área do footprint, em média)", function()
		local area = {}
		local count = {}
		for _, template in Templates do
			area[template.Tier] = (area[template.Tier] or 0) + template.Footprint[1] * template.Footprint[2]
			count[template.Tier] = (count[template.Tier] or 0) + 1
		end
		for tier = 2, #TierConfig do
			t.truthy(area[tier] / count[tier] > area[tier - 1] / count[tier - 1])
		end
	end)
end
