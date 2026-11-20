--!strict
-- Árvores "de blocos" do lobby (estilo Minecraft): tronco + camadas de folhas empilhadas, cada camada um
-- bloco (folhas com a textura BlockLeaves). Lógica pura (testada no Lune, BlockTrees.spec): só encostam,
-- nada atravessa nada. Medidas em studs, y a partir do chão; o LobbyService escala e gira.

local BlockTrees = {}

export type Box = { Size: { number }, Pos: { number }, Role: string } -- Pos = centro
export type Shape = { Name: string, Boxes: { Box } }

local function stack(trunk: { number }, layers: { { number } }, bumps: { { number } }?): { Box }
	local boxes: { Box } = {}
	table.insert(boxes, { Size = { trunk[1], trunk[2], trunk[1] }, Pos = { 0, trunk[2] / 2, 0 }, Role = "Trunk" })
	local y = trunk[2]
	local tops: { number } = {}
	for i, l in layers do
		local w, h = l[1], l[2]
		table.insert(boxes, { Size = { w, h, l[3] or w }, Pos = { 0, y + h / 2, 0 }, Role = "Leaves" })
		tops[i] = y
		y += h
	end
	-- bumps { camada, lado (1..4), largura, altura, profundidade }: bloco encostado na lateral da camada
	for _, b in bumps or {} do
		local layer = layers[b[1]]
		local w, d = layer[1], layer[3] or layer[1]
		local bw, bh, bd = b[3], b[4], b[5]
		local base = tops[b[1]]
		local side = b[2]
		local x, z = 0, 0
		if side == 1 then
			x = w / 2 + bd / 2
		elseif side == 2 then
			x = -(w / 2 + bd / 2)
		elseif side == 3 then
			z = d / 2 + bd / 2
		else
			z = -(d / 2 + bd / 2)
		end
		local sx, sz = if side <= 2 then bd else bw, if side <= 2 then bw else bd
		table.insert(boxes, { Size = { sx, bh, sz }, Pos = { x, base + bh / 2, z }, Role = "Leaves" })
	end
	return boxes
end

BlockTrees.Shapes = table.freeze({
	-- redonda: larga no meio, com "calombos" dos lados (cara de copa)
	{
		Name = "Round",
		Boxes = stack({ 1.6, 4 }, { { 7, 2.4 }, { 8.6, 2.6 }, { 6.6, 2.2 }, { 3.8, 1.8 } }, {
			{ 1, 1, 3, 1.8, 1.4 },
			{ 2, 3, 3.4, 2, 1.4 },
			{ 3, 2, 2.6, 1.6, 1.2 },
		}),
	},
	-- alta: copa comprida
	{
		Name = "Tall",
		Boxes = stack({ 1.4, 5 }, { { 5, 3 }, { 6, 3.2 }, { 4.6, 2.8 }, { 2.6, 1.8 } }, {
			{ 2, 1, 2.6, 2.2, 1.2 },
			{ 3, 4, 2.2, 1.8, 1 },
		}),
	},
	-- pinheiro: degraus cada vez menores
	{
		Name = "Pine",
		Boxes = stack({ 1.4, 3 }, { { 7, 1.7 }, { 5.6, 1.7 }, { 4.2, 1.7 }, { 2.8, 1.7 }, { 1.4, 1.4 } }),
	},
})

-- Meia largura (X) e meia profundidade (Z) que a árvore ocupa no chão, já com a escala.
function BlockTrees.half(shape: Shape, scale: number): (number, number)
	local hx, hz = 0, 0
	for _, b in shape.Boxes do
		hx = math.max(hx, math.abs(b.Pos[1]) + b.Size[1] / 2)
		hz = math.max(hz, math.abs(b.Pos[3]) + b.Size[3] / 2)
	end
	return hx * scale, hz * scale
end

-- Forma por índice (gira entre as 3).
function BlockTrees.pick(index: number): Shape
	local shapes = BlockTrees.Shapes
	return shapes[(index - 1) % #shapes + 1]
end

return BlockTrees
