-- Exporta alguns modelos do jogo com a mesh do kit que cada bloco usa (Logic/MeshKit) e a cor da paleta
-- do mapa, para o Blender renderizar a prévia de como fica no jogo.
-- Uso: lune run kitpreview [Id do mapa]  ->  assets/preview/kit_<Id>.json
-- Depois: blender -b --factory-startup --python assets/blender/render_kit_preview.py -- <Id>
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")

local Templates = require("../src/shared/Buildings/Templates")
local MapConfig = require("../src/shared/Config/MapConfig")
local MeshKitConfig = require("../src/shared/Config/MeshKitConfig")
local MeshKit = require("../src/shared/Logic/MeshKit")

local VARIANT_GROUP = { RoofTop = "Roof", Leaves2 = "Leaves", Stripe = "Awning" }
local SHOW = {
	"House",
	"Cottage",
	"Apartment",
	"Shop",
	"Cafe",
	"Tree",
	"Palm",
	"Pine",
	"Bush",
	"OfficeTower",
	"Hotel",
	"Lighthouse",
}

local id = process.args[1] or "GardenVillage"
local map
for _, m in MapConfig do
	if m.Id == id then
		map = m
	end
end
assert(map, "mapa não encontrado: " .. id)

local items = {}
local x = 0
for i, name in SHOW do
	local template = Templates[name]
	if template == nil then
		continue
	end
	local minX, maxX = math.huge, -math.huge
	for _, b in template.Boxes do
		minX = math.min(minX, b.Pos[1] - b.Size[1] / 2)
		maxX = math.max(maxX, b.Pos[1] + b.Size[1] / 2)
	end
	x += -minX + 4
	local roleVariant, salt = {}, 0
	for _, b in template.Boxes do
		local key = VARIANT_GROUP[b.Role] or b.Role
		if roleVariant[key] == nil then
			salt += 7
			roleVariant[key] = i + salt
		end
		local options = map.Palette[b.Role]
		local color = options[(roleVariant[key] % #options) + 1]
		table.insert(items, {
			Kit = MeshKit.choose(b, MeshKitConfig) or "",
			Shape = b.Shape or "Block",
			Rot = b.Rot or 0,
			Pos = { b.Pos[1] + x, b.Pos[2], b.Pos[3] },
			Size = b.Size,
			Color = color,
			Role = b.Role,
		})
	end
	x += maxX + 4
end

fs.writeDir("assets/preview")
fs.writeFile(`assets/preview/kit_{id}.json`, serde.encode("json", { Map = id, Width = x, Items = items }))
print(`{id}: {#items} blocos em {#SHOW} modelos`)
