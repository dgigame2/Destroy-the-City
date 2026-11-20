-- Exporta as medidas da fonte do lobby (LobbyConfig.Fountain via Logic/Fountain) e as cores da paleta para
-- o Blender modelar a mesma fonte com curvas (assets/blender/build_fountain.py). Fonte única das medidas:
-- a água (peças do Roblox) e a mesh do Blender ficam sempre encaixadas.
-- Uso: lune run fountain  ->  assets/blender/fountain_layout.json
-- Depois: blender -b --factory-startup --python assets/blender/build_fountain.py
local fs = require("@lune/fs")
local serde = require("@lune/serde")

local Fountain = require("../src/shared/Logic/Fountain")
local LobbyConfig = require("../src/shared/Config/LobbyConfig")
local PaletteConfig = require("../src/shared/Config/PaletteConfig")

local cfg = LobbyConfig.Fountain
local pieces = Fountain.pieces(cfg)

-- altura (base) de cada peça pelo nome
local function bottom(name: string): number
	for _, p in pieces do
		if p.Name == name then
			return p.Pos[2] - p.Size[2] / 2
		end
	end
	error("peça não encontrada: " .. name)
end

local basins = {}
for i, b in cfg.Basins do
	local tag = "Basin" .. i
	table.insert(basins, {
		Base = bottom(tag .. "Bowl"),
		FloorTop = bottom(tag .. "Water"),
		WallTop = bottom(tag .. "Rim"),
		Radius = b.Radius,
		BowlRadius = b.Bowl.Radius,
		Inner = b.Radius - b.Wall.Thickness,
		RimOuter = b.Radius + b.Rim.Overhang,
		RimHeight = b.Rim.Height,
		WaterTop = bottom(tag .. "Water") + b.Water,
	})
end

local columns = {}
for i, column in cfg.Columns do
	local discs = {}
	for j, d in column do
		table.insert(discs, { Radius = d.Radius, Base = bottom("Column" .. i .. "_" .. j), Height = d.Height })
	end
	table.insert(columns, discs)
end

local finial = {}
for j, d in cfg.Finial do
	table.insert(finial, { Radius = d.Radius, Base = bottom("Finial" .. j), Height = d.Height })
end

-- água: de onde cada cortina cai e até onde vai (build_fountain_water.py)
local spills = {}
for _, s in Fountain.spills(pieces, cfg) do
	table.insert(spills, {
		Basin = s.Basin,
		Radius = s.Radius,
		Top = s.Top,
		WaterTop = s.Top - s.Fall,
		Land = s.Radius + LobbyConfig.FountainWater.SpillOut,
		Curve = LobbyConfig.FountainWater.Curtain.Curve,
	})
end

local data = {
	Segments = 64,
	Spills = spills,
	Basins = basins,
	Columns = columns,
	Finial = finial,
	Crown = { Base = bottom("Crown"), Size = cfg.Crown },
	Colors = {
		Stone = PaletteConfig.Lobby.FountainStone,
		Trim = PaletteConfig.Lobby.FountainTrim,
	},
}

fs.writeFile("assets/blender/fountain_layout.json", serde.encode("json", data, true))
print("assets/blender/fountain_layout.json pronto")
