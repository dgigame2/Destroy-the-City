-- Exporta o tamanho do buraco (gramado retangular da cidade) e o formato do terreno redondo do lobby
-- para o Blender (assets/blender/build_land.py).
-- Uso: lune run land  ->  assets/blender/land_layout.json
local fs = require("@lune/fs")
local serde = require("@lune/serde")

local LobbyTown = require("../src/shared/Logic/LobbyTown")
local LobbyConfig = require("../src/shared/Config/LobbyConfig")

local town = LobbyTown.build(LobbyConfig.Width, LobbyConfig.Depth, LobbyConfig.Town)
local g = town.Ground
local land = LobbyConfig.Land
fs.writeFile(
	"assets/blender/land_layout.json",
	serde.encode("json", {
		HoleX = g[2].X1,
		HoleZ = g[2].Z1,
		Radius = land.Radius,
		Wobble = land.Wobble,
		Skirt = land.Skirt,
		Drop = land.Drop,
	}, true)
)
print("assets/blender/land_layout.json pronto")
