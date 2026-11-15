-- Exporta uma cidade inteira (chão, construções e decoração) como caixas coloridas em JSON, para a prévia
-- renderizada no Blender antes de ir pro Studio.
-- Uso: lune run export [Id do mapa]   ->   assets/preview/<Id>.json
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")

local Templates = require("../src/shared/Buildings/Templates")
local MapConfig = require("../src/shared/Config/MapConfig")
local CityPlans = require("../src/shared/Config/CityPlans")
local CityConfig = require("../src/shared/Config/CityConfig")
local DistrictConfig = require("../src/shared/Config/DistrictConfig")
local CityGen = require("../src/shared/Logic/CityGen")
local CityTerrain = require("../src/shared/Logic/CityTerrain")
local Rng = require("../src/shared/Logic/Rng")
local CityBoxes = require("../src/shared/Logic/CityBoxes")

local VARIANT_GROUP = { RoofTop = "Roof", Leaves2 = "Leaves", Stripe = "Awning" }

local id = process.args[1] or "GardenVillage"
local map
for _, m in MapConfig do
	if m.Id == id then
		map = m
	end
end
assert(map, "mapa não encontrado: " .. id)

local layout = CityGen.generate(CityPlans[id], DistrictConfig[map.Style], Templates, Rng.new(map.Seed), CityConfig)
local terrain = CityTerrain.generate(layout.Grid, map.Biome, Rng.new(map.Seed + 77), CityConfig, Templates)

local boxes = {}
local function push(cx, cy, cz, sx, sy, sz, color, kind)
	table.insert(boxes, { cx, cy, cz, sx, sy, sz, color[1], color[2], color[3], kind or "" })
end

for _, s in terrain.Slabs do
	if not s.Invisible then
		push(s.Pos[1], s.Pos[2], s.Pos[3], s.Size[1], s.Size[2], s.Size[3], s.Color, s.Material)
	end
end

local function build(template, x, y, z, rotation, variant)
	local roleVariant, salt = {}, 0
	local world = CityBoxes.place(template.Boxes, x, y, z, rotation)
	for index, b in template.Boxes do
		local key = VARIANT_GROUP[b.Role] or b.Role
		if roleVariant[key] == nil then
			salt += 7
			roleVariant[key] = variant + salt
		end
		local options = map.Palette[b.Role]
		local color = options[(roleVariant[key] % #options) + 1]
		local w = world[index]
		local kind = if b.Role == "Light" then "Light" elseif b.Role == "Water" or b.Role == "Pool" then "Water" else ""
		push(
			(w.Min[1] + w.Max[1]) / 2,
			(w.Min[2] + w.Max[2]) / 2,
			(w.Min[3] + w.Max[3]) / 2,
			w.Max[1] - w.Min[1],
			w.Max[2] - w.Min[2],
			w.Max[3] - w.Min[3],
			color,
			kind
		)
	end
end

for _, p in layout.Placements do
	build(Templates[p.Template], p.X, p.Y, p.Z, p.Rotation, p.Variant)
end
for _, d in terrain.Decor do
	build(Templates[d.Template], d.X, d.Y, d.Z, d.Rotation, d.Variant)
end
-- barreiras entre zonas (campo de força)
for _, b in layout.Barriers do
	push(b.Pos[1], b.Pos[2], b.Pos[3], b.Size[1], b.Size[2], b.Size[3], { 255, 90, 120 }, "Barrier")
end

fs.writeDir("assets/preview")
fs.writeFile(`assets/preview/{id}.json`, serde.encode("json", { Map = id, Half = terrain.Half, Boxes = boxes }))
print(`{id}: {#boxes} caixas ({#layout.Placements} construções, {#terrain.Slabs} peças de chão)`)
