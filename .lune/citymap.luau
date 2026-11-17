-- Planta vista de cima de uma cidade (dados do CityGen, sem abrir o Studio): antes (gerador antigo) e
-- depois (gerador planejado), lado a lado, com cores por categoria (Config/ModelCatalog).
-- Uso: lune run citymap GardenVillage   ->   previews/GardenVillage.html
local fs = require("@lune/fs")
local process = require("@lune/process")

local Templates = require("../src/shared/Buildings/Templates")
local MapConfig = require("../src/shared/Config/MapConfig")
local CityPlans = require("../src/shared/Config/CityPlans")
local CityConfig = require("../src/shared/Config/CityConfig")
local DistrictConfig = require("../src/shared/Config/DistrictConfig")
local ModelCatalog = require("../src/shared/Config/ModelCatalog")
local CityGen = require("../src/shared/Logic/CityGen")
local Placement = require("../src/shared/Logic/Placement")
local Rng = require("../src/shared/Logic/Rng")

local mapId = process.args[1] or "GardenVillage"
local map
for _, m in MapConfig do
	if m.Id == mapId then
		map = m
	end
end
assert(map, `mapa desconhecido: {mapId}`)

local PX = 3 -- pixels por célula
local GROUND = {
	Lot = "#bfe3a3",
	Wild = "#a9d68c",
	Road = "#8a8f99",
	Walk = "#dcdcd6",
	Water = "#6fb7e6",
	Bank = "#b9b2a3",
	Sand = "#f1dfa6",
	Plaza = "#e9d9c4",
	Asphalt = "#a7a9ad",
	Runway = "#6f737a",
	Sea = "#3f8fd0",
}
local CATEGORY = {
	Building = "#c0504d",
	Stall = "#f08a24",
	Vehicle = "#2b2d42",
	Aircraft = "#ffffff",
	Tree = "#2e7d32",
	Plant = "#66bb6a",
	Leisure = "#8e44ad",
	Street = "#f1c40f",
	Beach = "#e84393",
	Boat = "#1e3799",
	Yard = "#7f8c8d",
}

local function svg(fill): (string, { [string]: number })
	local layout = CityGen.generate(CityPlans[map.Id], fill, Templates, Rng.new(map.Seed), CityConfig, 1)
	local g = layout.Grid
	local out = {}
	table.insert(
		out,
		`<svg xmlns="http://www.w3.org/2000/svg" width="{g.Width * PX}" height="{g.Depth * PX}" viewBox="0 0 {g.Width * PX} {g.Depth * PX}">`
	)
	-- chão: trechos seguidos do mesmo tipo numa linha viram um retângulo só
	for z = 0, g.Depth - 1 do
		local x = 0
		while x < g.Width do
			local kind = g.Kind[z * g.Width + x + 1]
			local x1 = x
			while x1 + 1 < g.Width and g.Kind[z * g.Width + x1 + 2] == kind do
				x1 += 1
			end
			table.insert(
				out,
				`<rect x="{x * PX}" y="{z * PX}" width="{(x1 - x + 1) * PX}" height="{PX}" fill="{GROUND[kind] or "#000"}"/>`
			)
			x = x1 + 1
		end
	end
	local counts = {}
	for _, p in layout.Placements do
		local c = Placement.category(ModelCatalog, p.Template)
		counts[c] = (counts[c] or 0) + 1
		local r = p.Cells
		table.insert(
			out,
			`<rect x="{r[1] * PX}" y="{r[2] * PX}" width="{(r[3] - r[1]) * PX}" height="{(r[4] - r[2]) * PX}" fill="{CATEGORY[c]}" stroke="#00000055" stroke-width="0.5"><title>{p.Template}</title></rect>`
		)
	end
	table.insert(out, "</svg>")
	counts.Total = #layout.Placements
	return table.concat(out, "\n"), counts
end

local plannedFill = DistrictConfig[map.Style]
local oldFill = table.clone(plannedFill)
oldFill.Planner = nil

local before, beforeCounts = svg(oldFill)
local after, afterCounts = svg(plannedFill)

local legend = {}
for name, color in CATEGORY do
	table.insert(
		legend,
		`<span><i style="background:{color}"></i>{name} {beforeCounts[name] or 0} → {afterCounts[name] or 0}</span>`
	)
end
table.sort(legend)

local STYLE = [[
body{font:14px system-ui;background:#1d1f24;color:#eee;margin:16px}
.row{display:flex;gap:16px;flex-wrap:wrap}.row div{flex:1;min-width:300px}
svg{width:100%;height:auto;border-radius:8px}
.legend span{display:inline-flex;align-items:center;margin:4px 12px 4px 0}
.legend i{width:12px;height:12px;border-radius:2px;margin-right:6px;display:inline-block;border:1px solid #0006}
]]

local html = table.concat({
	'<!doctype html><html><head><meta charset="utf-8">',
	`<title>{map.DisplayName} plan</title><style>{STYLE}</style></head><body>`,
	`<h2>{map.DisplayName}: antes × depois</h2>`,
	`<p>Objetos: {beforeCounts.Total} → {afterCounts.Total}. Passe o mouse num objeto para ver o nome.</p>`,
	`<div class="legend">{table.concat(legend, "")}</div>`,
	'<div class="row">',
	`<div><h3>Antes (sorteio por célula)</h3>{before}</div>`,
	`<div><h3>Depois (gerador planejado)</h3>{after}</div>`,
	"</div></body></html>",
}, "\n")

fs.writeDir("previews")
fs.writeFile(`previews/{map.Id}.html`, html)
print(`previews/{map.Id}.html  ({beforeCounts.Total} -> {afterCounts.Total} objetos)`)
