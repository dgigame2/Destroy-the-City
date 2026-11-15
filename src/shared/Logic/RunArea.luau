--!strict
-- Geometria da área "START A RUN" do lobby (pura: o servidor monta exatamente estas caixas e o Lune testa
-- que nenhuma entra na outra). Coordenadas locais do lobby: centro do gramado = origem, chão em y = 0.

local RunArea = {}

export type Box = { Name: string, Kind: string, Size: { number }, Pos: { number }, Pad: number? }
export type Pad = { Index: number, X: number, Z: number, Half: number }

type Config = {
	PadSize: number,
	Border: number,
	PadSpacing: number,
	PadZ: number,
	PadHeight: number,
	DetectHeight: number,
	BoardWidth: number,
	BoardHeight: number,
	BoardBottom: number,
	BoardZ: number,
	Post: number,
	SignWidth: number,
	SignHeight: number,
	SignBottom: number,
	SignZ: number,
	ExitBack: number,
}

function RunArea.pads(cfg: Config, count: number): { Pad }
	local list = {}
	for index = 1, count do
		local x = (index - (count + 1) / 2) * cfg.PadSpacing
		table.insert(list, { Index = index, X = x, Z = cfg.PadZ, Half = cfg.PadSize / 2 })
	end
	return list
end

local function box(list: { Box }, name: string, kind: string, size: { number }, pos: { number }, pad: number?)
	table.insert(list, { Name = name, Kind = kind, Size = size, Pos = pos, Pad = pad })
end

-- Kind: "Floor" (piso de madeira), "Border" (neon), "Board" (placa de status), "Wood" (postes e vigas),
-- "Sign" (placa grande).
function RunArea.boxes(cfg: Config, count: number): { Box }
	local list: { Box } = {}
	local h, b, s = cfg.PadHeight, cfg.Border, cfg.PadSize
	local inner = s - b * 2
	for _, pad in RunArea.pads(cfg, count) do
		local x, z, i = pad.X, pad.Z, pad.Index
		box(list, "PadFloor", "Floor", { inner, h, inner }, { x, h / 2, z }, i)
		-- borda: faixas inteiras em X, faixas entre elas em Z (nenhuma entra na outra)
		for _, side in { -1, 1 } do
			box(list, "PadBorder", "Border", { s, h, b }, { x, h / 2, z + side * (s / 2 - b / 2) }, i)
			box(list, "PadBorder", "Border", { b, h, inner }, { x + side * (s / 2 - b / 2), h / 2, z }, i)
		end
		-- placa de status entre dois postes, viga em cima
		local bw, bh, bottom, post = cfg.BoardWidth, cfg.BoardHeight, cfg.BoardBottom, cfg.Post
		box(list, "PadBoard", "Board", { bw, bh, 1 }, { x, bottom + bh / 2, cfg.BoardZ }, i)
		local postH = bottom + bh + 1
		for _, side in { -1, 1 } do
			box(
				list,
				"PadPost",
				"Wood",
				{ post, postH, post },
				{ x + side * (bw / 2 + post / 2), postH / 2, cfg.BoardZ },
				i
			)
		end
		box(list, "PadBeam", "Wood", { bw + post * 2 + 1, 1.2, post + 1 }, { x, postH + 0.6, cfg.BoardZ }, i)
	end
	-- placa grande "START A RUN"
	local sw, sh, sb, post = cfg.SignWidth, cfg.SignHeight, cfg.SignBottom, 1.5
	box(list, "RunSign", "Sign", { sw, sh, 1 }, { 0, sb + sh / 2, cfg.SignZ })
	local postH = sb + sh + 1
	for _, side in { -1, 1 } do
		box(list, "RunSignPost", "Wood", { post, postH, post }, { side * (sw / 2 + post / 2), postH / 2, cfg.SignZ })
	end
	box(list, "RunSignBeam", "Wood", { sw + post * 2 + 1, 1.2, post + 1 }, { 0, postH + 0.6, cfg.SignZ })
	return list
end

-- O jogador (posição do HumanoidRootPart em coordenadas locais do lobby) está em cima do quadrado?
function RunArea.isOnPad(pad: Pad, x: number, y: number, z: number, detectHeight: number): boolean
	return math.abs(x - pad.X) <= pad.Half and math.abs(z - pad.Z) <= pad.Half and y >= 0 and y <= detectHeight
end

-- Duas caixas alinhadas aos eixos se interpenetram (encostar não conta)?
function RunArea.overlaps(a: Box, b: Box, tolerance: number): boolean
	for axis = 1, 3 do
		local gap = math.abs(a.Pos[axis] - b.Pos[axis]) - (a.Size[axis] + b.Size[axis]) / 2
		if gap >= -tolerance then
			return false
		end
	end
	return true
end

return RunArea
