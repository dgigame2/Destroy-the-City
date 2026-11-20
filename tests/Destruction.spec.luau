-- Etapa 2 (destruição): tiers de qualidade, LOD por chunk com histerese e destroços pela semente.
local Quality = require("../src/shared/Logic/Quality")
local QualityConfig = require("../src/shared/Config/QualityConfig")
local Wreck = require("../src/shared/Logic/Wreck")
local WreckConfig = require("../src/shared/Config/WreckConfig")
local Templates = require("../src/shared/Buildings/Templates")

return function(t)
	local q = QualityConfig

	t.test("tier: celular (toque sem teclado) = Low; PC = padrão; FPS baixo = Low; escolha do menu vence", function()
		t.equal(Quality.pick(true, false, nil, nil, q), "Low")
		t.equal(Quality.pick(false, true, nil, nil, q), q.Default)
		t.equal(Quality.pick(true, true, 60, nil, q), q.Default) -- tablet com teclado
		t.equal(Quality.pick(false, true, 30, nil, q), "Low")
		t.equal(Quality.pick(true, false, 20, "High", q), "High")
		t.equal(Quality.pick(false, true, nil, "Inexistente", q), q.Default)
	end)

	t.test("tiers: orçamentos crescem de Low para High (AUDITORIA §8.4)", function()
		local prev = nil
		for _, name in q.Order do
			local tier = q.Tiers[name]
			t.truthy(tier ~= nil, name)
			t.truthy(tier.Near < tier.Mid)
			t.truthy(tier.Particles > 0 and tier.Particles <= 1)
			if prev then
				t.truthy(tier.FlyingPieces >= prev.FlyingPieces)
				t.truthy(tier.Near >= prev.Near)
				t.truthy(tier.Collapses >= prev.Collapses)
				t.truthy(tier.MaxOthers >= prev.MaxOthers)
			end
			prev = tier
		end
		-- teto do Low da auditoria: <= 20 pedaços voando
		t.truthy(q.Tiers.Low.FlyingPieces <= 20)
	end)

	t.test("chunk: posição -> chunk e chave únicas, inclusive negativas", function()
		local cx, cz = Quality.chunkOf(-1, 130, 128)
		t.equal(cx, -1)
		t.equal(cz, 1)
		local seen = {}
		for x = -3, 3 do
			for z = -3, 3 do
				local k = Quality.chunkKey(x, z)
				t.falsy(seen[k])
				seen[k] = true
			end
		end
		t.near(Quality.chunkDistance(0, 0, 64, 64, 128), 0)
	end)

	t.test("LOD: perto = Near, médio = Mid, longe = Far", function()
		t.equal(Quality.band(100, nil, 140, 280, 0.12, 0), "Near")
		t.equal(Quality.band(200, nil, 140, 280, 0.12, 0), "Mid")
		t.equal(Quality.band(400, nil, 140, 280, 0.12, 0), "Far")
		-- o chunk conta pela borda: centro a 180 com meia diagonal de 90 ainda é Near
		t.equal(Quality.band(180, nil, 140, 280, 0.12, 90), "Near")
	end)

	t.test("LOD: histerese — afastar um pouco da borda não troca; aproximar troca na hora", function()
		t.equal(Quality.band(145, "Near", 140, 280, 0.12, 0), "Near") -- 145 < 140 x 1.12
		t.equal(Quality.band(160, "Near", 140, 280, 0.12, 0), "Mid")
		t.equal(Quality.band(300, "Mid", 140, 280, 0.12, 0), "Mid") -- 300 < 280 x 1.12
		t.equal(Quality.band(330, "Mid", 140, 280, 0.12, 0), "Far")
		t.equal(Quality.band(139, "Mid", 140, 280, 0.12, 0), "Near")
		t.equal(Quality.band(279, "Far", 140, 280, 0.12, 0), "Mid")
		-- pulo grande (teleporte): de Near direto para Far
		t.equal(Quality.band(900, "Near", 140, 280, 0.12, 0), "Far")
	end)

	t.test("detalhe: peça pequena some no Mid, grande fica", function()
		t.truthy(Quality.isDetail(1, 1, 1, q.DetailVolume))
		t.falsy(Quality.isDetail(4, 4, 4, q.DetailVolume))
	end)

	t.test(
		"destroço: mesma construção = mesmo destroço (todo cliente igual), variantes 1..3, giro de 90°",
		function()
			for id = 1, 200 do
				local a = Wreck.pick(id, "House", 12, 12, WreckConfig)
				local b = Wreck.pick(id, "House", 12, 12, WreckConfig)
				t.equal(a.Variant, b.Variant)
				t.equal(a.Rotation, b.Rotation)
				t.equal(a.Mirror, b.Mirror)
				t.truthy(a.Variant >= 1 and a.Variant <= WreckConfig.Variants)
				t.truthy(a.Rotation % 90 == 0 and a.Rotation < 360)
			end
		end
	)

	t.test("destroço: as variantes, giros e espelhos aparecem todos (sorteio espalhado)", function()
		local variants, rotations, mirrors = {}, {}, {}
		for id = 1, 300 do
			local p = Wreck.pick(id, "House", 12, 12, WreckConfig)
			variants[p.Variant] = true
			rotations[p.Rotation] = true
			mirrors[p.Mirror] = true
		end
		for v = 1, WreckConfig.Variants do
			t.truthy(variants[v], `variante {v}`)
		end
		for _, r in { 0, 90, 180, 270 } do
			t.truthy(rotations[r], `giro {r}`)
		end
		t.truthy(mirrors[true] and mirrors[false])
	end)

	t.test("destroço: tamanho pelo footprint e família pelo nome", function()
		t.equal(Wreck.size(10, 10, WreckConfig), "P")
		t.equal(Wreck.size(20, 20, WreckConfig), "M")
		t.equal(Wreck.size(30, 40, WreckConfig), "G")
		t.equal(Wreck.size(60, 60, WreckConfig), "GG")
		t.equal(Wreck.family("Office", WreckConfig), "Commercial")
		t.equal(Wreck.family("FactoryHall", WreckConfig), "Industrial")
		t.equal(Wreck.family("ControlTower", WreckConfig), "Industrial")
		t.equal(Wreck.family("House", WreckConfig), "Residential")
	end)

	t.test("destroço: as 3 famílias e os 4 tamanhos aparecem nas construções do jogo", function()
		local families, sizes = {}, {}
		for name, template in Templates do
			if template.Footprint and template.Tier >= 3 then
				families[Wreck.family(name, WreckConfig)] = true
				sizes[Wreck.size(template.Footprint[1], template.Footprint[2], WreckConfig)] = true
			end
		end
		for _, f in { "Residential", "Commercial", "Industrial" } do
			t.truthy(families[f], f)
		end
		for _, s in WreckConfig.Sizes do
			t.truthy(sizes[s.Name], s.Name)
		end
	end)

	t.test("desabamento: começa parado, termina afundado e inclinado, nunca passa do fim", function()
		local c = WreckConfig.Collapse
		local s0, a0 = Wreck.collapse(0, 30, c.MaxTilt, c.Sink)
		t.equal(s0, 0)
		t.equal(a0, 0)
		local s1, a1 = Wreck.collapse(1, 30, c.MaxTilt, c.Sink)
		t.near(s1, 30 * c.Sink)
		t.near(a1, c.MaxTilt)
		local s2 = Wreck.collapse(5, 30, c.MaxTilt, c.Sink)
		t.near(s2, s1)
		t.truthy(c.Seconds < 1) -- goat: explosão/efeito < 1 s
	end)

	t.test("pedaços: sobem, caem e param no chão; teto do Tier respeitado", function()
		local p = WreckConfig.Pieces
		local list = Wreck.pieces(42, 6, 12, 12, p.Speed, p.MaxSize)
		t.equal(#list, 6)
		for _, piece in list do
			t.truthy(piece.Vy > 0)
			t.truthy(piece.Size <= p.MaxSize)
			local _, y1 = Wreck.piece(piece, 0.1, p.Gravity, 4)
			t.truthy(y1 > 4)
			local _, y2, _, landed = Wreck.piece(piece, 10, p.Gravity, 4)
			t.equal(y2, 0)
			t.truthy(landed)
		end
		t.equal(Wreck.budget("GG", p.PerSize, 0, 20), p.PerSize.GG)
		t.equal(Wreck.budget("GG", p.PerSize, 17, 20), 3)
		t.equal(Wreck.budget("GG", p.PerSize, 25, 20), 0)
	end)
end
