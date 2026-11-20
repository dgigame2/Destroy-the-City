--!strict
-- Peças básicas para montar modelos em blocos (dados puros). Convenções iguais às do Templates:
-- frente para -Z, Y = 0 no chão, todo bloco alinhado aos eixos, blocos só se encostam (nunca um dentro do outro).

local Voxel = {}

export type Box = {
	Size: { number },
	Pos: { number },
	Role: string,
	Shape: string?,
	Rot: number?,
	Tilt: { number }?,
	Min: { number }?,
	Max: { number }?,
}

-- Bloco: (sx, sy, sz) tamanho; (x, y, z) com y = base do bloco.
function Voxel.box(sx: number, sy: number, sz: number, x: number, y: number, z: number, role: string): Box
	return { Size = { sx, sy, sz }, Pos = { x, y + sy / 2, z }, Role = role }
end

local box = Voxel.box

function Voxel.add(boxes: { Box }, ...: Box)
	for _, b in { ... } do
		table.insert(boxes, b)
	end
end

-- Torre de vidro em faixas: segmentos de parede ("Glass"/"Wall") separados por faixas mais largas ("Trim").
-- Cada faixa sobressai `lip` dos lados. Retorna a altura do topo.
function Voxel.banded(
	boxes: { Box },
	w: number,
	d: number,
	x: number,
	z: number,
	y: number,
	segments: number,
	segH: number,
	wallRole: string,
	bandRole: string,
	lip: number
): number
	for _ = 1, segments do
		table.insert(boxes, box(w, segH, d, x, y, z, wallRole))
		y += segH
		table.insert(boxes, box(w + lip * 2, 0.6, d + lip * 2, x, y, z, bandRole))
		y += 0.6
	end
	return y
end

-- Pilha de blocos cada vez mais estreitos (cilindros e cones em degraus). Retorna o topo.
function Voxel.stack(
	boxes: { Box },
	x: number,
	z: number,
	y: number,
	layers: { { number } }, -- {largura, altura, profundidade?}
	roles: { string }
): number
	for i, layer in layers do
		local depth = layer[3] or layer[1]
		table.insert(boxes, box(layer[1], layer[2], depth, x, y, z, roles[(i - 1) % #roles + 1]))
		y += layer[2]
	end
	return y
end

-- Janelas (ou vitrines) encostadas nas 4 fachadas de um bloco w x d com base em y.
-- Cada fachada recebe `count` janelas; ficam longe das quinas (as janelas de fachadas vizinhas não se tocam).
function Voxel.windowsAround(
	boxes: { Box },
	w: number,
	d: number,
	x: number,
	z: number,
	y: number,
	count: number,
	ww: number,
	wh: number,
	role: string?
)
	local r = role or "Window"
	for k = 1, count do
		local offX = (k - (count + 1) / 2) * (w / count)
		local offZ = (k - (count + 1) / 2) * (d / count)
		table.insert(boxes, box(math.min(ww, w / count - 0.6), wh, 0.4, x + offX, y, z - d / 2 - 0.2, r))
		table.insert(boxes, box(math.min(ww, w / count - 0.6), wh, 0.4, x + offX, y, z + d / 2 + 0.2, r))
		table.insert(boxes, box(0.4, wh, math.min(ww, d / count - 0.6), x - w / 2 - 0.2, y, z + offZ, r))
		table.insert(boxes, box(0.4, wh, math.min(ww, d / count - 0.6), x + w / 2 + 0.2, y, z + offZ, r))
	end
end

-- Janelas só na fachada da frente (-Z), com peitoril.
function Voxel.frontWindows(boxes: { Box }, d: number, xs: { number }, y: number, ww: number, wh: number)
	for _, x in xs do
		table.insert(boxes, box(ww, wh, 0.4, x, y, -d / 2 - 0.2, "Window"))
		table.insert(boxes, box(ww + 0.6, 0.4, 0.8, x, y - 0.4, -d / 2 - 0.4, "Trim"))
	end
end

-- Telhado em degraus ao longo de X; o degrau de cima é "RoofTop" (no mapa de neve vira branco).
function Voxel.stepRoof(boxes: { Box }, w: number, d: number, baseY: number, steps: number, stepH: number, role: string)
	table.insert(boxes, box(w + 1.2, 0.6, d + 1.6, 0, baseY, 0, "Trim"))
	local full = d + 1.2
	for i = 0, steps - 1 do
		local depth = full * (1 - i / steps)
		local r = if i == steps - 1 then "RoofTop" else role
		table.insert(boxes, box(w + 0.8, stepH, depth, 0, baseY + 0.6 + i * stepH, 0, r))
	end
end

-- Bloco com forma: "Wedge" (cunha, alta em +Z antes de Rot), "Cylinder" (em pé), "CylinderZ" (deitado ao
-- longo de Z: fuselagem, turbina) ou "Ball". A caixa (Size) continua sendo a do mundo.
function Voxel.shaped(b: Box, shape: string, rot: number?): Box
	b.Shape = shape
	b.Rot = rot
	return b
end

-- Telhado de duas águas (referências de casa): duas cunhas encostadas na cumeeira (ao longo de X) e uma
-- capa fina em cima. ox/oz = beiral para os lados/frente e trás. Retorna o topo da cumeeira.
function Voxel.gable(
	boxes: { Box },
	w: number,
	d: number,
	x: number,
	z: number,
	baseY: number,
	h: number,
	ox: number,
	oz: number,
	role: string
): number
	local W, D = w + ox * 2, d + oz * 2
	table.insert(boxes, Voxel.shaped(box(W, h, D / 2, x, baseY, z - D / 4, role), "Wedge", 0))
	table.insert(boxes, Voxel.shaped(box(W, h, D / 2, x, baseY, z + D / 4, role), "Wedge", 180))
	table.insert(boxes, box(W + 0.2, 0.4, 0.8, x, baseY + h, z, "RoofTop"))
	return baseY + h + 0.4
end

-- Rodas quadradas coladas na lateral do veículo.
function Voxel.wheels(boxes: { Box }, xs: { number }, zs: { number }, size: number)
	for _, x in xs do
		for _, z in zs do
			table.insert(boxes, box(0.8, size, size, x, 0, z, "Tire"))
		end
	end
end

-- Toldo listrado: faixas ao longo de X alternando Awning e Stripe.
function Voxel.stripes(boxes: { Box }, x0: number, count: number, width: number, y: number, z: number, depth: number)
	for i = 0, count - 1 do
		local role = if i % 2 == 0 then "Awning" else "Stripe"
		table.insert(boxes, box(width, 0.7, depth, x0 + width / 2 + i * width, y, z, role))
	end
end

return Voxel
