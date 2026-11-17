--!strict
-- Peças da fonte do lobby (LobbyConfig.Fountain), de baixo para cima. Lógica pura: testada no Lune.
-- Cada bacia: bojo (disco menor embaixo), fundo, parede em anel de blocos, borda mais larga e a água.
-- A bacia de baixo é o próprio pé da fonte. Entre as bacias, colunas de discos empilhados; no topo,
-- o remate (discos e uma bola "abacaxi"). Nada atravessa nada: discos empilham, a água fica dentro do anel
-- e os blocos do anel têm a largura da face de dentro (sobra um vinco fino por fora, como pedra lavrada).

local Fountain = {}

export type Disc = { Radius: number, Height: number }
export type Basin = {
	Radius: number,
	Bowl: Disc,
	Floor: number,
	Wall: { Thickness: number, Height: number },
	Rim: { Height: number, Overhang: number },
	Water: number,
}
export type Config = {
	Segments: number,
	Basins: { Basin },
	Columns: { { Disc } },
	Finial: { Disc },
	Crown: number, -- diâmetro da bola do topo
}

-- Shape: "Cylinder" (Size = {diâmetro, altura, diâmetro}), "Block" (Size = {largura, altura, espessura},
-- Yaw = giro em Y), "Ball" (Size = diâmetro nos 3). Pos = centro (y a partir da base da fonte).
export type Piece = {
	Name: string,
	Role: string, -- "Stone", "Trim" ou "Water" (cor da paleta)
	Shape: string,
	Size: { number },
	Pos: { number },
	Yaw: number,
	Inner: number?, -- anel: raio da face de dentro
	Outer: number?, -- anel: raio de fora
}

local function disc(list: { Piece }, name: string, role: string, r: number, h: number, y: number): number
	table.insert(list, {
		Name = name,
		Role = role,
		Shape = "Cylinder",
		Size = { r * 2, h, r * 2 },
		Pos = { 0, y + h / 2, 0 },
		Yaw = 0,
	})
	return y + h
end

local function ring(
	list: { Piece },
	name: string,
	role: string,
	inner: number,
	outer: number,
	h: number,
	y: number,
	n: number
): number
	local thick = outer - inner
	local width = 2 * inner * math.tan(math.pi / n)
	local mid = inner + thick / 2
	for i = 0, n - 1 do
		local a = (i / n) * math.pi * 2
		table.insert(list, {
			Name = name,
			Role = role,
			Shape = "Block",
			Size = { width, h, thick },
			Pos = { math.sin(a) * mid, y + h / 2, math.cos(a) * mid },
			Yaw = a,
			Inner = inner,
			Outer = outer,
		})
	end
	return y + h
end

function Fountain.pieces(cfg: Config): { Piece }
	local list: { Piece } = {}
	local y = 0
	for i, b in cfg.Basins do
		local tag = "Basin" .. i
		y = disc(list, tag .. "Bowl", "Trim", b.Bowl.Radius, b.Bowl.Height, y)
		y = disc(list, tag .. "Floor", "Stone", b.Radius, b.Floor, y)
		local inner = b.Radius - b.Wall.Thickness
		local wallTop = ring(list, tag .. "Wall", "Stone", inner, b.Radius, b.Wall.Height, y, cfg.Segments)
		ring(list, tag .. "Rim", "Trim", inner, b.Radius + b.Rim.Overhang, b.Rim.Height, wallTop, cfg.Segments)
		y = disc(list, tag .. "Water", "Water", inner, b.Water, y)
		local column = cfg.Columns[i]
		if column then
			for j, d in column do
				y = disc(list, "Column" .. i .. "_" .. j, if j % 2 == 0 then "Stone" else "Trim", d.Radius, d.Height, y)
			end
		end
	end
	for j, d in cfg.Finial do
		y = disc(list, "Finial" .. j, "Stone", d.Radius, d.Height, y)
	end
	table.insert(list, {
		Name = "Crown",
		Role = "Trim",
		Shape = "Ball",
		Size = { cfg.Crown, cfg.Crown, cfg.Crown },
		Pos = { 0, y + cfg.Crown / 2, 0 },
		Yaw = 0,
	})
	return list
end

export type Spill = {
	Basin: number, -- bacia de onde a água transborda (2 = do meio, 3 = do topo)
	Radius: number, -- raio da borda de onde a água cai
	Top: number, -- altura do topo da borda
	Fall: number, -- altura da queda até a água da bacia de baixo
	Land: number, -- raio da água da bacia de baixo (a queda tem que cair dentro dela)
}

local function find(pieces: { Piece }, name: string): Piece?
	for _, p in pieces do
		if p.Name == name then
			return p
		end
	end
	return nil
end

-- Cortinas de água: cada bacia de cima transborda pela borda e cai na água da bacia de baixo.
function Fountain.spills(pieces: { Piece }, cfg: Config): { Spill }
	local list: { Spill } = {}
	for i = 2, #cfg.Basins do
		local rim = find(pieces, "Basin" .. i .. "Rim")
		local water = find(pieces, "Basin" .. (i - 1) .. "Water")
		if rim and water then
			local top = rim.Pos[2] + rim.Size[2] / 2
			local waterTop = water.Pos[2] + water.Size[2] / 2
			table.insert(list, {
				Basin = i,
				Radius = rim.Outer :: number,
				Top = top,
				Fall = top - waterTop,
				Land = water.Size[1] / 2,
			})
		end
	end
	return list
end

-- Raio total (borda mais larga) e altura total da fonte.
function Fountain.extent(pieces: { Piece }): (number, number)
	local r, top = 0, 0
	for _, p in pieces do
		local outer = p.Outer or (if p.Shape == "Block" then 0 else p.Size[1] / 2)
		r = math.max(r, outer)
		top = math.max(top, p.Pos[2] + p.Size[2] / 2)
	end
	return r, top
end

return Fountain
