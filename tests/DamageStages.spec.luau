-- Vida visível: estágios de dano (blocos caindo sem deixar nada flutuando) e escombros.
local DamageStages = require("../src/shared/Logic/DamageStages")
local Ruins = require("../src/shared/Logic/Ruins")
local DamageConfig = require("../src/shared/Config/DamageConfig")
local Templates = require("../src/shared/Buildings/Templates")
local TierConfig = require("../src/shared/Config/TierConfig")

local EPS = 0.01

local function limitFor(n: number): number
	return DamageStages.count(n, #DamageConfig.Removed, DamageConfig.Removed)
end

-- Dois blocos com volume em comum (encostar não conta).
local function overlapping(a, b)
	for axis = 1, 3 do
		local amin = a.Pos[axis] - a.Size[axis] / 2
		local amax = a.Pos[axis] + a.Size[axis] / 2
		local bmin = b.Pos[axis] - b.Size[axis] / 2
		local bmax = b.Pos[axis] + b.Size[axis] / 2
		if amin >= bmax - EPS or bmin >= amax - EPS then
			return false
		end
	end
	return true
end

return function(t)
	local cfg = DamageConfig

	t.test("estágios: inteira = 0, cada degrau de vida abre um estágio", function()
		t.equal(DamageStages.stage(1, cfg.Thresholds), 0)
		t.equal(DamageStages.stage(0.8, cfg.Thresholds), 0)
		t.equal(DamageStages.stage(0.74, cfg.Thresholds), 1)
		t.equal(DamageStages.stage(0.5, cfg.Thresholds), 1)
		t.equal(DamageStages.stage(0.49, cfg.Thresholds), 2)
		t.equal(DamageStages.stage(0.1, cfg.Thresholds), 3)
	end)

	t.test("config: degraus de vida decrescentes e blocos caídos crescentes", function()
		t.equal(#cfg.Thresholds, #cfg.Removed)
		for i = 2, #cfg.Thresholds do
			t.truthy(cfg.Thresholds[i] < cfg.Thresholds[i - 1])
			t.truthy(cfg.Removed[i] > cfg.Removed[i - 1])
		end
		t.truthy(cfg.Removed[#cfg.Removed] < 1)
	end)

	t.test("quantos blocos caem: zero inteira, cresce com o estágio", function()
		t.equal(DamageStages.count(20, 0, cfg.Removed), 0)
		t.equal(DamageStages.count(20, 1, cfg.Removed), 3)
		t.equal(DamageStages.count(20, 2, cfg.Removed), 6)
		t.equal(DamageStages.count(20, 3, cfg.Removed), 9)
	end)

	t.test("barra de vida publicada em degraus de 5%", function()
		t.near(DamageStages.quantize(0.93, 0.05), 0.95)
		t.near(DamageStages.quantize(0.95, 0.05), 0.95)
		t.near(DamageStages.quantize(0.01, 0.05), 0.05)
		t.near(DamageStages.quantize(1, 0.05), 1)
	end)

	t.test("mesma construção quebra sempre igual; outra semente quebra diferente", function()
		local house = Templates.House or select(2, next(Templates))
		local n = #house.Boxes
		local a = DamageStages.order(house.Boxes, 7, cfg.Jitter, limitFor(n))
		local b = DamageStages.order(house.Boxes, 7, cfg.Jitter, limitFor(n))
		t.equal(table.concat(a, ","), table.concat(b, ","))
	end)

	-- Para todos os modelos: em todo estágio, nada que sobrou fica flutuando (FLOATING / NO FOOTING).
	for name, template in Templates do
		local n = #template.Boxes
		if n >= cfg.MinBoxes and template.Mesh == nil then
			t.test(`{name}: blocos caem sem deixar nada flutuando`, function()
				local adj = DamageStages.adjacency(template.Boxes)
				for variant = 0, cfg.Variants - 1 do
					local order = DamageStages.order(template.Boxes, variant, cfg.Jitter, limitFor(n))
					for stage = 1, #cfg.Removed do
						local alive = {}
						for i = 1, n do
							alive[i] = true
						end
						local wanted = math.min(DamageStages.count(n, stage, cfg.Removed), #order)
						for k = 1, wanted do
							alive[order[k]] = false
						end
						if not DamageStages.connected(template.Boxes, adj, alive) then
							error(`variação {variant}, estágio {stage}: sobrou bloco flutuando`)
						end
					end
				end
			end)
		end
	end

	t.test("desabar e sumir: animações < 1 s e desaba no último estágio", function()
		t.truthy(cfg.Collapse.Seconds + 0.15 < 1)
		t.truthy(cfg.Collapse.RubbleSeconds < 1)
		t.truthy(cfg.Vanish.Seconds < 1)
		t.truthy(cfg.Dust.Seconds < 1)
		t.truthy(cfg.Collapse.MaxParts > 0 and cfg.Dust.Puffs > 0)
		-- casas para cima desabam (o último estágio é quando a vida passa do último degrau)
		t.equal(DamageStages.stage(cfg.Thresholds[#cfg.Thresholds] - 0.01, cfg.Thresholds), #cfg.Thresholds)
		t.truthy(#Ruins.pile(10, 10, cfg.Ruins.FromTier, 1, cfg.Ruins) > 0)
	end)

	t.test("escombros: tiers pequenos não deixam pilha", function()
		t.equal(#Ruins.pile(10, 10, 1, 1, cfg.Ruins), 0)
		t.equal(#Ruins.pile(10, 10, 2, 1, cfg.Ruins), 0)
	end)

	for tier = cfg.Ruins.FromTier, #TierConfig do
		for _, size in { { 8, 8 }, { 14, 10 }, { 30, 22 }, { 3, 40 } } do
			t.test(`escombros tier {tier} em {size[1]}x{size[2]}: dentro do terreno, baixos, sem sobrepor`, function()
				for seed = 1, 5 do
					local boxes = Ruins.pile(size[1], size[2], tier, seed, cfg.Ruins)
					t.truthy(#boxes > 0 and #boxes <= cfg.Ruins.MaxParts)
					local hmax = Ruins.height(tier, cfg.Ruins)
					for i, b in boxes do
						local halfW, halfD = size[1] * cfg.Ruins.Margin / 2, size[2] * cfg.Ruins.Margin / 2
						t.truthy(math.abs(b.Pos[1]) + b.Size[1] / 2 <= halfW + EPS)
						t.truthy(math.abs(b.Pos[3]) + b.Size[3] / 2 <= halfD + EPS)
						t.truthy(b.Pos[2] - b.Size[2] / 2 >= -EPS) -- nada abaixo do chão
						t.truthy(b.Pos[2] + b.Size[2] / 2 <= hmax * 1.25 + EPS) -- pilha baixa
						for j = i + 1, #boxes do
							if overlapping(b, boxes[j]) then
								error(`blocos {i} e {j} um dentro do outro (semente {seed})`)
							end
						end
					end
				end
			end)
		end
	end
end
