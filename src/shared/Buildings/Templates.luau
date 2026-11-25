--!strict
-- Modelos de construções, natureza e props, descritos como blocos (dados puros, sem APIs do Roblox).
-- Estilo voxel das referências de mapa: tudo em blocos com stud, telhados em degraus, árvores em camadas,
-- palmeiras, acácias, cactos, pinheiros com neve, cristais de gelo, barracas listradas e cercas.
-- Convenções: unidades em studs; a frente aponta para -Z; Pos é o centro relativo à base no chão (Y = 0).
-- Size é o tamanho do bloco: todo bloco é alinhado aos eixos (galhos e folhas inclinados são feitos "em escada",
-- no estilo voxel). Assim o teste de "uma peça dentro da outra" é exato.
-- Tilt (opcional, {pitch, yaw, roll} em graus) existe no Builder, mas os testes proíbem usar nos modelos.
-- Min/Max: caixa alinhada aos eixos que envolve o bloco (calculada aqui; usada pelos testes e footprint).
-- Shape "Wedge" (cunha, parte alta em +Z antes da rotação Rot em Y) só é usado em detalhes pequenos.

-- Peças básicas compartilhadas com os modelos novos das cidades (CityBuildings).
local Voxel = if script then require(script.Parent.Voxel) else require("./Voxel")
local CityBuildings = if script then require(script.Parent.CityBuildings) else require("./CityBuildings")
local CityProps = if script then require(script.Parent.CityProps) else require("./CityProps")

export type Box = Voxel.Box

export type Template = {
	Name: string,
	Tier: number,
	Footprint: { number },
	Boxes: { Box },
	Mesh: string?, -- MeshPart do Blender em ReplicatedStorage.Assets (os blocos são a reserva)
}

local box, add, stepRoof = Voxel.box, Voxel.add, Voxel.stepRoof
local frontWindows, wheels, stripes = Voxel.frontWindows, Voxel.wheels, Voxel.stripes
local shaped, gable = Voxel.shaped, Voxel.gable

local function sideWindows(boxes: { Box }, w: number, zs: { number }, y: number, ww: number, wh: number)
	for _, z in zs do
		table.insert(boxes, box(0.4, wh, ww, w / 2 + 0.2, y, z, "Window"))
	end
end

local builders: { [string]: () -> any } = {}

-- Tier 1: props ------------------------------------------------------------

-- Poste com lampião. Poste e braço deslocados para caber em 1 célula (3 studs): mais largo não cabe na calçada.
function builders.Lamp()
	return {
		Name = "Lamp",
		Tier = 1,
		Boxes = {
			box(1.7, 0.6, 1.7, -0.6, 0, 0, "ToyMetal"),
			box(1.4, 1.7, 1.4, -0.6, 0.6, 0, "ToyMetal"),
			box(1, 0.5, 1, -0.6, 2.3, 0, "ToyMetal"),
			box(0.6, 0.6, 0.1, -0.6, 1.1, -0.75, "RockDark"),
			box(0.6, 0.6, 0.1, -0.6, 1.1, 0.75, "RockDark"),
			box(0.7, 5.4, 0.7, -0.6, 2.8, 0, "Bark"),
			box(1, 0.8, 1, -0.6, 8.2, 0, "LampDark"),
			box(0.5, 0.3, 0.5, -0.6, 9, 0, "LampDark"),
			box(0.9, 0.6, 0.9, -0.6, 9.3, 0, "Bark"),
			box(1.5, 0.5, 0.5, 0.65, 8.35, 0, "Bark"),
			box(0.4, 0.45, 0.35, -0.05, 7.5, 0, "LampDark"),
			box(0.4, 0.45, 0.35, 0.35, 7.9, 0, "LampDark"),
			box(0.25, 0.4, 0.25, 0.85, 7.95, 0, "LampDark"),
			box(0.6, 0.3, 0.6, 0.85, 7.65, 0, "LampDark"),
			box(1.1, 0.35, 1.1, 0.85, 7.3, 0, "LampDark"),
			box(0.8, 1.2, 0.8, 0.85, 6.1, 0, "Light"),
			box(1.1, 0.25, 1.1, 0.85, 5.85, 0, "LampDark"),
			box(0.15, 1.2, 0.15, 0.375, 6.1, -0.475, "LampDark"),
			box(0.15, 1.2, 0.15, 0.375, 6.1, 0.475, "LampDark"),
			box(0.15, 1.2, 0.15, 1.325, 6.1, -0.475, "LampDark"),
			box(0.15, 1.2, 0.15, 1.325, 6.1, 0.475, "LampDark"),
		},
	}
end

function builders.Bench()
	return {
		Name = "Bench",
		Tier = 1,
		Boxes = {
			box(0.7, 1.2, 1.6, -1.9, 0, 0, "ToyLeg"),
			box(0.7, 1.2, 1.6, 1.9, 0, 0, "ToyLeg"),
			box(5, 0.5, 1.8, 0, 1.2, 0, "ToyWood"),
			box(0.6, 0.5, 0.4, -1.9, 1.7, 0.65, "ToyLeg"),
			box(0.6, 0.5, 0.4, 1.9, 1.7, 0.65, "ToyLeg"),
			box(4.8, 1.2, 0.5, 0, 2.2, 0.65, "ToyWood"),
		},
	}
end

function builders.Bin()
	return {
		Name = "Bin",
		Tier = 1,
		Boxes = {
			box(1.6, 0.9, 1.6, 0, 0, 0, "Accent"),
			box(1.8, 0.9, 1.8, 0, 0.9, 0, "Accent"),
			box(2.1, 0.5, 2.1, 0, 1.8, 0, "Trim"),
			box(1.8, 0.25, 1.8, 0, 2.3, 0, "Trim"),
		},
	}
end

-- Arbusto: três bolas low-poly encostadas (referência dos packs de natureza).
-- Arbusto redondo em camadas.
function builders.Bush()
	return {
		Name = "Bush",
		Tier = 1,
		Boxes = {
			box(1.3, 0.4, 1.3, 0, 0, 0, "Bark"),
			box(4, 0.3, 3.6, 0, 0.4, 0, "CanopyDark"),
			box(5, 1.1, 4, 0, 0.7, 0, "Canopy"),
			box(2.2, 1.1, 0.8, -1.3, 0.7, -2.4, "Canopy"),
			box(0.5, 1.1, 2, -2.75, 0.9, 0.3, "Canopy"),
			box(0.5, 1.1, 2.2, 2.75, 1, 0.2, "CanopyTop"),
			box(4, 1.1, 3.4, 0.1, 1.8, 0.2, "Canopy"),
			box(1.1, 0.8, 0.5, -1, 1.8, -1.75, "CanopyTop"),
			box(1.4, 0.9, 0.5, 1.2, 0.9, -2.25, "CanopyTop"),
			box(2.4, 0.9, 0.8, 0.4, 0.9, 2.4, "Canopy"),
			box(0.5, 0.8, 1.8, -2.15, 1.8, 0.4, "Canopy"),
			box(2.6, 1.2, 2.4, -0.1, 2.9, 0.1, "CanopyTop"),
			box(0.7, 0.6, 1.6, 1.55, 2.9, 0.3, "Canopy"),
		},
	}
end

-- Arbusto largo e baixo.
function builders.WideBush()
	return {
		Name = "WideBush",
		Tier = 1,
		Boxes = {
			box(2.1, 0.4, 1.3, 0, 0, 0, "Bark"),
			box(3, 0.4, 2.6, 0, 0.4, 0, "CanopyDark"),
			box(5, 1.2, 4, 0, 0.8, 0, "CanopyDark"),
			box(1.4, 0.6, 2.4, -3.2, 0.6, 0, "CanopyDark"),
			box(2, 1.1, 3, -3.5, 1.2, -0.3, "CanopyTop"),
			box(1.3, 0.6, 2, 3.15, 0.7, 0.2, "CanopyDark"),
			box(2, 1, 2.8, 3.5, 1.3, 0.2, "Canopy"),
			box(1.9, 0.9, 1.9, 3.2, 2.3, 0.1, "CanopyTop"),
			box(2.6, 1, 0.9, 1.2, 1, -2.45, "CanopyTop"),
			box(1.6, 0.8, 0.7, -1.4, 0.7, -2.35, "Canopy"),
			box(2.6, 0.9, 0.8, 0.2, 1, 2.4, "Canopy"),
			box(3.8, 1.2, 3, 0, 2, 0, "Canopy"),
			box(1.6, 1.2, 1.6, -2.9, 2.3, 0.6, "Canopy"),
			box(0.7, 0.6, 0.9, -4.05, 2.3, 0.7, "Canopy"),
			box(2.6, 1.1, 2.2, 0, 3.2, -0.1, "CanopyTop"),
			box(0.6, 0.5, 1.4, 1.6, 3.2, 0.3, "Canopy"),
		},
	}
end

function builders.Hydrant()
	return {
		Name = "Hydrant",
		Tier = 1,
		Boxes = {
			box(1.1, 0.9, 1.1, 0, 0, 0, "Accent"),
			box(1.25, 0.9, 1.25, 0, 0.9, 0, "Accent"),
			box(1.5, 0.4, 1.5, 0, 1.8, 0, "Accent"),
			box(0.6, 0.5, 0.3, 0, 1.1, -0.775, "Accent"),
			box(1, 0.5, 1, 0, 2.2, 0, "Trim"),
		},
	}
end

function builders.Cone()
	return {
		Name = "Cone",
		Tier = 1,
		Boxes = {
			box(1.6, 0.3, 1.6, 0, 0, 0, "Cone"),
			box(1.1, 0.6, 1.1, 0, 0.3, 0, "Cone"),
			box(0.8, 0.4, 0.8, 0, 0.9, 0, "Stripe"),
			box(0.5, 0.6, 0.5, 0, 1.3, 0, "Cone"),
		},
	}
end

-- Vaso redondo com borda, moita e duas flores em cima.
function builders.FlowerPot()
	return {
		Name = "FlowerPot",
		Tier = 1,
		Boxes = {
			box(1.4, 0.8, 1.4, 0, 0, 0, "Pot"),
			box(1.7, 0.6, 1.7, 0, 0.8, 0, "Pot"),
			box(2.1, 0.5, 2.1, 0, 1.4, 0, "Pot"),
			box(1.1, 0.2, 1.1, 0, 1.9, 0, "CanopyDark"),
			box(2.1, 1.1, 1.8, 0, 2.1, 0, "Canopy"),
			box(0.3, 0.2, 0.3, -0.5, 3.2, -0.2, "CanopyDark"),
			box(0.3, 0.2, 0.3, 0.5, 3.2, 0.35, "CanopyDark"),
			box(0.65, 0.5, 0.65, -0.5, 3.4, -0.2, "Flower"),
			box(0.65, 0.5, 0.65, 0.5, 3.4, 0.35, "Flower2"),
		},
	}
end

-- Cogumelos (referência da floresta low-poly): um grande e um pequeno, pé redondo e chapéu em domo.
-- Cogumelos de blocos (cor do chapéu sorteada; o marrom tem manchas da mesma cor).
function builders.Mushroom()
	return {
		Name = "Mushroom",
		Tier = 1,
		Boxes = {
			box(1.2, 2.2, 1.2, 0, 0, 0, "Stem"),
			box(3, 0.9, 3, 0, 2.2, 0, "Cap"),
			box(2.5, 0.7, 2.5, 0, 3.1, 0, "Cap"),
			box(0.6, 0.8, 0.6, 1.9, 0, 1.2, "Stem"),
			box(1.4, 0.4, 1.4, 1.9, 0.8, 1.2, "Cap"),
			box(1.1, 0.3, 1.1, 1.9, 1.2, 1.2, "Cap"),
			box(0.9, 0.1, 0.7, 0, 3.8, 0, "CapSpot"),
			box(0.8, 0.5, 0.1, 0.6, 2.4, -1.55, "CapSpot"),
			box(0.5, 0.4, 0.1, -0.7, 3.3, -1.3, "CapSpot"),
			box(0.1, 0.5, 0.8, -1.55, 2.4, 0.3, "CapSpot"),
			box(0.1, 0.5, 0.7, 1.55, 2.4, -0.4, "CapSpot"),
			box(0.4, 0.1, 0.4, 1.9, 1.5, 1.2, "CapSpot"),
			box(0.4, 0.25, 0.1, 1.9, 0.85, 0.45, "CapSpot"),
		},
	}
end

function builders.Mailbox()
	return {
		Name = "Mailbox",
		Tier = 1,
		Boxes = {
			box(0.55, 2, 0.55, 0, 0, 0, "Trunk"),
			box(1.3, 0.9, 1.8, 0, 2, 0, "Accent"),
			box(1.3, 0.5, 1.3, 0, 2.9, 0.25, "Accent"),
		},
	}
end

-- Canteiro de flores (referência da ilha: florzinhas espalhadas na grama).
-- Três flores em cruz direto no chão (a cor das pétalas é sorteada por grupo).
function builders.Flowers()
	local boxes = {
		box(0.35, 0.6, 0.35, -1.5, 0, -0.7, "CanopyDark"),
		box(0.35, 0.4, 0.35, -1, 0, -1, "CanopyDark"),
	}
	-- {x, z, altura do caule, largura da flor}
	for _, f in { { -0.7, 0.7, 1.6, 1.5 }, { 1.1, 0.2, 1.2, 1.3 }, { 0.1, -0.8, 0.7, 1.1 } } do
		local x, z, top, petal = f[1], f[2], f[3], f[4] / 3
		add(
			boxes,
			box(0.4, f[3], 0.4, x, 0, z, "CanopyDark"),
			box(petal * 3, 0.35, petal, x, top, z, "Petal"),
			box(petal, 0.35, petal, x, top, z - petal, "Petal"),
			box(petal, 0.35, petal, x, top, z + petal, "Petal"),
			box(petal, 0.1, petal, x, top + 0.35, z, "PetalCore")
		)
	end
	return { Name = "Flowers", Tier = 1, Boxes = boxes }
end

-- Cerca de madeira com dois trilhos (referência do cercado).
function builders.Fence()
	-- postes e trilhos encostados (os trilhos ficam entre os postes, sem atravessar)
	local boxes = {}
	for _, x in { -4, 0, 4 } do
		table.insert(boxes, box(0.8, 3.2, 0.8, x, 0, 0, "Beam"))
	end
	for _, x in { -2, 2 } do
		add(boxes, box(3.2, 0.6, 0.4, x, 1, 0, "Plank"), box(3.2, 0.6, 0.4, x, 2.2, 0, "Plank"))
	end
	return { Name = "Fence", Tier = 1, Boxes = boxes }
end

-- Tier 2: árvores, natureza dos biomas e veículos ----------------------------------

-- Árvore de copas em camadas, com três galhos.
function builders.Tree()
	return {
		Name = "Tree",
		Tier = 2,
		Boxes = {
			-- base e tronco
			box(4.6, 0.9, 4.6, 0, 0, 0, "Bark"),
			box(3, 0.8, 3, 0, 0.9, 0, "Bark"),
			box(1.7, 10.3, 1.7, 0, 1.7, 0, "Bark"),
			-- copa do topo
			box(5, 0.6, 5, 0, 12, 0, "CanopyDark"),
			box(8, 2.2, 7, 0, 12.6, 0, "Canopy"),
			box(0.8, 1.8, 3, -4.4, 13.4, 0.5, "Canopy"),
			box(6.2, 1.9, 5.2, -0.2, 14.8, 0.2, "CanopyTop"),
			-- galho e copa da esquerda
			box(2.2, 1, 1, -1.95, 6.4, 0, "Bark"),
			box(1, 1.8, 1, -3.55, 6.4, 0, "Bark"),
			box(3, 0.6, 3, -3.9, 8.2, -0.4, "CanopyDark"),
			box(5.4, 1.7, 5.6, -3.8, 8.8, -0.6, "Canopy"),
			box(3.8, 1.4, 4, -4, 10.5, -0.4, "CanopyTop"),
			-- galho e copa da direita
			box(2.4, 1, 1, 2.05, 7.6, 0, "Bark"),
			box(1, 1.6, 1, 3.75, 7.6, 0, "Bark"),
			box(4, 0.6, 3.4, 4.2, 9.2, 0.3, "CanopyDark"),
			box(5.8, 1.7, 5.4, 4, 9.8, 0.4, "Canopy"),
			box(3.8, 0.9, 3.8, 4.5, 11.5, 0.4, "CanopyTop"),
			-- galhinho baixo
			box(1.6, 0.8, 0.8, 1.65, 3.9, 0, "Bark"),
			box(0.8, 0.9, 0.8, 2.85, 3.9, 0, "Bark"),
			box(2.8, 1.4, 2.6, 2.9, 4.8, 0, "Canopy"),
			box(1.9, 0.7, 1.8, 2.9, 6.2, 0, "CanopyTop"),
		},
	}
end

-- Árvore larga de tronco grosso.
function builders.Oak()
	return {
		Name = "Oak",
		Tier = 2,
		Boxes = {
			-- base e tronco
			box(5.4, 0.9, 5, 0, 0, 0, "Bark"),
			box(3.8, 0.8, 3.6, 0, 0.9, 0, "Bark"),
			box(2.6, 5.4, 2.4, 0, 1.7, 0, "Bark"),
			box(1.2, 2.6, 0.4, 0.6, 1.7, -1.4, "Bark"),
			-- copa do topo
			box(7, 1, 5, 0.6, 7.1, 0.4, "CanopyDark"),
			box(8, 2.9, 5.7, 0.6, 8.1, 0.75, "Canopy"),
			box(3.8, 1.9, 1.8, 1.2, 7, -3, "CanopyTop"),
			box(1.2, 0.7, 1.2, 1, 6.3, -2.9, "Canopy"),
			box(1.2, 1.8, 2.4, -4, 8.6, 1, "Canopy"),
			box(1, 1.7, 2.4, 5.1, 8.5, 0.8, "CanopyTop"),
			box(4.2, 1.2, 3.8, 0.2, 11, 0.6, "CanopyTop"),
			-- galho e copa da esquerda
			box(2.4, 1.2, 1.2, -2.5, 3.9, 0, "Bark"),
			box(1.2, 1.5, 1.2, -4.3, 3.9, 0, "Bark"),
			box(1.4, 0.6, 1.4, -5.9, 4.8, 0, "CanopyDark"),
			box(4.6, 1.7, 4.4, -4.7, 5.4, -0.4, "Canopy"),
			box(3.4, 1.2, 3, -5.1, 7.1, -0.6, "CanopyTop"),
			-- galhinho baixo
			box(1.2, 0.7, 0.8, -1.9, 2.6, -0.2, "Bark"),
			box(2.2, 1.1, 2, -3.6, 2.4, -0.2, "Canopy"),
			box(1, 0.5, 1, -3.4, 1.9, -0.2, "CanopyDark"),
			-- galho e copa da direita
			box(3.2, 1.1, 1.2, 2.9, 3, 0, "Bark"),
			box(1, 1.3, 1.2, 5, 3, 0, "Bark"),
			box(1.2, 1.1, 1.2, 2, 4.1, -0.1, "Canopy"),
			box(4.3, 2, 4.2, 4.85, 4.3, 0, "Canopy"),
			box(1.1, 0.7, 1.1, 6.3, 3.6, -0.4, "CanopyTop"),
			box(3, 0.8, 2.8, 5.1, 6.3, 0.2, "CanopyTop"),
		},
	}
end

-- Árvore de tronco torto.
function builders.BentTree()
	return {
		Name = "BentTree",
		Tier = 2,
		Boxes = {
			-- base e tronco torto (em degraus)
			box(5, 0.9, 4.6, 0, 0, 0, "Bark"),
			box(3.6, 0.8, 3.2, 0, 0.9, 0, "Bark"),
			box(2, 4, 1.8, -0.3, 1.7, 0, "Bark"),
			box(1, 1.3, 0.4, 0.2, 1.7, -1.1, "Bark"),
			-- cada trecho passa do QualityConfig.DetailVolume: menor que isso some de longe e a copa flutua
			box(1.9, 2, 1.8, 0.2, 5.7, 0, "Bark"),
			box(1.7, 2.2, 1.7, 1.05, 7.7, 0, "Bark"),
			box(1.65, 2.3, 1.65, 1.625, 9.9, 0, "Bark"),
			-- copa do topo e galho que a segura
			box(1.6, 0.8, 0.9, 3.25, 10.4, 0, "Bark"),
			box(0.9, 1.8, 0.9, 4.5, 10.4, 0, "Bark"),
			box(6, 0.7, 4.6, 2.6, 12.2, 0, "CanopyDark"),
			box(7.6, 2.4, 6.4, 2.9, 12.9, 0, "Canopy"),
			box(5, 1.6, 0.6, 1.4, 13.2, -3.5, "Canopy"),
			box(5.4, 1, 5, 2.7, 15.3, 0.2, "Canopy"),
			box(3.6, 1.3, 3.4, 3, 16.3, 0.2, "CanopyTop"),
			-- galho e copa da esquerda
			box(1.85, 1, 1, -1.675, 6.7, 0, "Bark"),
			box(1.1, 1.8, 1, -3.15, 6.7, 0, "Bark"),
			box(2.2, 0.5, 2.2, -4.1, 8.5, 0, "CanopyDark"),
			box(4.6, 1.7, 4.2, -3.7, 9, -0.2, "Canopy"),
			box(1.6, 1.5, 2.6, -0.6, 9.2, -0.9, "Canopy"),
			box(3.6, 1.2, 3.2, -3.6, 10.7, 0, "CanopyTop"),
			-- galho e copa da direita
			box(2.2, 0.8, 0.9, 2.25, 5.8, 0, "Bark"),
			box(0.8, 1.5, 0.8, 3.75, 5.8, 0, "Bark"),
			box(0.9, 0.7, 0.9, 2.7, 6.6, 0, "CanopyTop"),
			box(1, 0.5, 1, 4.8, 6.8, 0, "CanopyDark"),
			box(3, 1.3, 2.6, 4.2, 7.3, 0, "Canopy"),
			box(1.8, 0.8, 1.6, 4.1, 8.6, 0, "CanopyTop"),
			-- galhinho alto
			box(1.3, 0.6, 0.7, -1.55, 13, 0, "Bark"),
			box(0.7, 1.2, 0.7, -2.55, 13, 0, "Bark"),
			box(1.2, 1, 1.2, -3.5, 13.1, -0.3, "Canopy"),
			box(1.4, 1.1, 1.3, -2.4, 14.2, 0, "CanopyTop"),
		},
	}
end

-- Pinheiro alto em camadas.
function builders.Pine()
	return {
		Name = "Pine",
		Tier = 2,
		Boxes = {
			-- base e tronco
			box(3.6, 0.9, 3.6, 0, 0, 0, "Bark"),
			box(2.4, 0.6, 2.4, 0, 0.9, 0, "Bark"),
			box(1.4, 3.9, 1.4, 0, 1.5, 0, "Bark"),
			-- camadas
			box(4.2, 0.4, 4.2, 0, 5.4, 0, "CanopyDark"),
			box(6, 1.9, 6, 0, 5.8, 0, "Canopy"),
			box(4.2, 0.3, 4.2, 0, 7.7, 0, "CanopyDark"),
			box(5.1, 1.8, 5.1, 0, 8, 0, "Canopy"),
			box(4.3, 2.1, 4.3, 0, 9.8, 0, "CanopyTop"),
			box(2.8, 0.3, 2.8, 0, 11.9, 0, "CanopyDark"),
			box(3.3, 1.7, 3.3, 0, 12.2, 0, "Canopy"),
			box(2.5, 1.7, 2.5, 0, 13.9, 0, "CanopyTop"),
			box(1.5, 1.7, 1.5, 0, 15.6, 0, "Canopy"),
		},
	}
end

-- Pinheiro com neve nas camadas (referência da neve).
function builders.SnowPine()
	local boxes = { box(1.4, 2.6, 1.4, 0, 0, 0, "Trunk") }
	local widths = { 7, 5.6, 4.2, 2.8 }
	for i, wdt in widths do
		local y = 2.6 + (i - 1) * 2.4
		add(boxes, box(wdt, 2, wdt, 0, y, 0, "Pine"), box(wdt - 0.8, 0.4, wdt - 0.8, 0, y + 2, 0, "Snow"))
	end
	add(boxes, box(1.4, 1.2, 1.4, 0, 12.2, 0, "Pine"), box(1, 0.6, 1, 0, 13.4, 0, "Snow"))
	return { Name = "SnowPine", Tier = 2, Boxes = boxes }
end

-- Pedra alta com pedras menores em volta.
function builders.Rock()
	return {
		Name = "Rock",
		Tier = 2,
		Boxes = {
			box(4.6, 2.2, 3.6, 0.3, 0, 0.4, "Rock"),
			box(3.8, 2.2, 3, 0.3, 2.2, 0.4, "Rock"),
			box(2.1, 1.1, 2.4, -3.05, 0, -0.3, "Rock"),
			box(1.8, 0.7, 2, -2.9, 1.1, -0.3, "Rock"),
			box(1.3, 1, 1, 0.1, 0, -1.9, "Rock"),
			box(1.4, 2, 2, 3.3, 0, 0.9, "Rock"),
			box(0.7, 0.5, 0.1, -0.8, 3.3, -1.15, "RockDark"),
			box(0.8, 0.6, 0.1, 1.2, 3.5, -1.15, "RockDark"),
			box(0.9, 0.5, 0.1, 1.8, 0.7, -1.45, "RockDark"),
			box(0.6, 0.5, 0.1, -3.2, 0.3, -1.55, "RockDark"),
			box(0.1, 0.6, 0.8, 2.25, 3, 0.6, "RockDark"),
		},
	}
end

-- Pedra baixa e larga.
function builders.FlatRock()
	return {
		Name = "FlatRock",
		Tier = 2,
		Boxes = {
			box(4.6, 1.4, 3, 0.2, 0, 0.5, "Rock"),
			box(4, 1.1, 2.4, 0.2, 1.4, 0.5, "Rock"),
			box(2.2, 1.5, 2.2, -3.2, 0, -0.2, "Rock"),
			box(3, 1.3, 1.4, 1.6, 0, -1.7, "Rock"),
			box(1.4, 1.8, 2.2, 3.2, 0, 0.6, "Rock"),
			box(0.8, 0.5, 0.1, 2.2, 0.3, -2.45, "RockDark"),
			box(0.6, 0.4, 0.1, -3, 0.7, -1.35, "RockDark"),
			box(0.7, 0.4, 0.1, 0.9, 1.8, -0.75, "RockDark"),
			box(0.6, 0.5, 0.1, -0.9, 0.2, -1.05, "RockDark"),
		},
	}
end

-- Pedra em torre.
function builders.TallRock()
	return {
		Name = "TallRock",
		Tier = 2,
		Boxes = {
			box(3, 3.4, 3, -0.3, 0, 0.3, "Rock"),
			box(2.6, 3, 2.6, -0.3, 3.4, 0.3, "Rock"),
			box(1.8, 2.6, 2.4, 2.1, 0, 0.2, "Rock"),
			box(1.5, 1.8, 2, 1.95, 2.6, 0.2, "Rock"),
			box(1.9, 2.4, 2.2, -2.75, 0, -0.5, "Rock"),
			box(1.5, 0.6, 1.8, -2.65, 2.4, -0.5, "Rock"),
			box(1.1, 0.9, 0.8, -0.6, 0, -1.6, "Rock"),
			box(1.1, 1.4, 1.4, 3.55, 0, 0.2, "Rock"),
			box(0.5, 0.5, 0.1, -1.1, 5.4, -1.05, "RockDark"),
			box(0.5, 0.6, 0.1, -1, 4.2, -1.05, "RockDark"),
			box(0.6, 0.5, 0.1, 2, 3.3, -0.85, "RockDark"),
			box(0.6, 0.6, 0.1, -2.9, 1.2, -1.65, "RockDark"),
		},
	}
end

-- Palmeira: tronco em gomos levemente curvado e folhas compridas caindo para os lados (referência da ilha).
-- Palmeira: tronco em gomos levemente curvado e quatro folhas em escada caindo para os lados
-- (estilo voxel da referência da ilha; cada degrau só encosta no anterior pela quina).
function builders.Palm()
	local boxes = {}
	local segments, segH = 6, 1.6
	for i = 0, segments - 1 do
		table.insert(boxes, box(1.2, segH, 1.2, i * 0.25, i * segH, 0, if i % 2 == 0 then "Trunk" else "Beam"))
	end
	local topX, topY = (segments - 1) * 0.25, segments * segH
	local crown = 2.4
	table.insert(boxes, box(crown, 1, crown, topX, topY, 0, "Leaves"))
	table.insert(boxes, box(1.2, 0.8, 1.2, topX, topY + 1, 0, "Leaves2"))
	local step, width, drop = 1.8, 1.4, 0.5
	for k, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
		local role = if k % 2 == 0 then "Leaves2" else "Leaves"
		for n = 0, 2 do
			local reach = crown / 2 + step / 2 + n * step
			local sx = if d[1] ~= 0 then step else width
			local sz = if d[2] ~= 0 then step else width
			local y = topY + 0.5 - n * drop
			table.insert(boxes, box(sx, drop, sz, topX + d[1] * reach, y, d[2] * reach, role))
		end
	end
	return { Name = "Palm", Tier = 2, Boxes = boxes }
end

-- Acácia: tronco fino, dois galhos abertos e copa achatada em camadas (referências savana/floresta).
-- Acácia: tronco fino, dois galhos em escada (voxel) e copa achatada em camadas (referências savana/floresta).
function builders.Acacia()
	local boxes = { box(1, 4.6, 1, 0, 0, 0, "Trunk") }
	-- galhos: blocos em diagonal, cada um encostado no anterior pela quina
	for _, side in { -1, 1 } do
		for n = 0, 1 do
			table.insert(boxes, box(0.8, 1.4, 0.8, side * (0.9 + n * 0.8), 4.6 + n * 1.4, 0, "Trunk"))
		end
	end
	add(
		boxes,
		box(10, 1.2, 8, 0, 7.4, 0, "Leaves"),
		box(7, 1, 5.6, 0.6, 8.6, -0.4, "Leaves2"),
		box(3.4, 0.8, 3, -2.6, 6.6, 2, "Leaves2")
	)
	return { Name = "Acacia", Tier = 2, Boxes = boxes }
end

-- Cacto com dois braços e uma florzinha em cima.
function builders.Cactus()
	return {
		Name = "Cactus",
		Tier = 2,
		Boxes = {
			box(1.8, 7, 1.8, 0, 0, 0, "Cactus"),
			box(1.6, 1.2, 1.2, -1.7, 2.6, 0, "Cactus"),
			box(1.2, 2.6, 1.2, -2.3, 3.8, 0, "Cactus"),
			box(1.6, 1.2, 1.2, 1.7, 3.6, 0, "Cactus"),
			box(1.2, 2, 1.2, 2.3, 4.8, 0, "Cactus"),
			box(0.8, 0.6, 0.8, 0, 7, 0, "Flower"),
		},
	}
end

-- Árvore seca escura com galhos tortos (referência da savana).
-- Árvore seca escura com galhos em escada (referência da savana).
function builders.DeadTree()
	local boxes = {
		box(1.6, 0.8, 1.6, 0, 0, 0, "DeadWood"),
		box(1.1, 5.4, 1.1, 0, 0.8, 0, "DeadWood"),
	}
	-- galho da direita (3 degraus), da esquerda (2) e um para trás (2), todos saindo do topo do tronco
	for n = 0, 2 do
		table.insert(boxes, box(0.7, 1.2, 0.7, 0.9 + n * 0.7, 6.2 + n * 1.2, 0, "DeadWood"))
	end
	for n = 0, 1 do
		table.insert(boxes, box(0.7, 1.2, 0.7, -(0.9 + n * 0.7), 5.6 + n * 1.2, 0, "DeadWood"))
		table.insert(boxes, box(0.6, 1, 0.6, 0, 6.2 + n * 1, -(0.85 + n * 0.6), "DeadWood"))
	end
	return { Name = "DeadTree", Tier = 2, Boxes = boxes }
end

-- Cristais de gelo em blocos inclinados (referência da neve).
-- Cristais de gelo em blocos de alturas diferentes, lado a lado (referência da neve).
function builders.IceCrystal()
	return {
		Name = "IceCrystal",
		Tier = 2,
		Boxes = {
			box(4.6, 0.8, 3.6, 0, 0, 0, "Snow"),
			box(1.8, 6.4, 1.8, 0, 0.8, 0, "Ice"),
			box(1.3, 4.6, 1.3, 1.55, 0.8, 0.3, "Ice"),
			box(1.2, 3.6, 1.2, -1.5, 0.8, -0.4, "Ice"),
			box(1, 0.8, 1, 0, 7.2, 0, "Ice"),
		},
	}
end

-- Guarda-sol listrado com toalha (referência da ilha).
-- Guarda-sol listrado em degraus: cantos coloridos e uma cruz branca em cada camada.
function builders.Umbrella()
	local boxes = {
		box(2, 0.3, 2, 0, 0, 0, "Trunk"),
		box(0.6, 4.9, 0.6, 0, 0.3, 0, "Trunk"),
	}
	local y = 5.2
	for _, layer in { { 6.4, 0.6 }, { 4.8, 0.5 }, { 3.2, 0.5 } } do
		local w, h = layer[1], layer[2]
		local mid = w * 0.36
		local corner = (w - mid) / 2
		local off = (mid + corner) / 2
		table.insert(boxes, box(w, h, mid, 0, y, 0, "Stripe"))
		for _, sz in { -1, 1 } do
			table.insert(boxes, box(mid, h, corner, 0, y, sz * off, "Stripe"))
			for _, sx in { -1, 1 } do
				table.insert(boxes, box(corner, h, corner, sx * off, y, sz * off, "Parasol"))
			end
		end
		y += h
	end
	add(boxes, box(1.8, 0.5, 1.8, 0, y, 0, "Parasol"), box(1, 0.1, 1, 0, y + 0.5, 0, "Stripe"))
	return { Name = "Umbrella", Tier = 2, Boxes = boxes }
end

-- Pilar de rocha em camadas tortas (referência da savana).
function builders.RockPillar()
	return {
		Name = "RockPillar",
		Tier = 2,
		Boxes = {
			box(4.2, 2.4, 4, 0, 0, 0, "Sandstone"),
			box(3.4, 2.4, 3.2, 0.3, 2.4, -0.2, "Rock"),
			box(3.8, 2, 3.6, -0.2, 4.8, 0.1, "Sandstone"),
			box(2.6, 1.6, 2.4, 0.2, 6.8, 0, "Rock"),
		},
	}
end

-- Carro de blocos da referência: capô e teto em degraus, para-brisa inclinado e para-lamas sobre rodas quadradas.
function builders.Car()
	local boxes = {
		box(4.6, 1.5, 10, 0, 0.7, 0, "Body"),
		box(4.6, 0.6, 9.2, 0, 2.2, 0.1, "Body"),
		box(3.4, 0.4, 2.6, 0, 2.8, -2.9, "Body"),
		-- cabine
		shaped(box(4, 1.8, 0.8, 0, 2.8, -1.1, "Glass"), "Wedge", 0),
		box(3.6, 1.8, 4.2, 0, 2.8, 1.4, "Glass"),
		box(4.6, 0.6, 5, 0, 4.6, 1.1, "Body"),
		box(4, 0.4, 4.2, 0, 5.2, 1.1, "Body"),
		-- frente
		box(1.5, 0.3, 0.2, 0, 1.25, -5.1, "Metal"),
		box(1.5, 0.3, 0.2, 0, 1.75, -5.1, "Metal"),
		box(2.6, 0.6, 0.4, 0, 0.55, -5.2, "Metal"),
		-- traseira
		box(4.6, 0.6, 0.4, 0, 0.55, 5.2, "Metal"),
	}
	for _, sx in { -1, 1 } do
		add(
			boxes,
			box(1.1, 0.8, 0.2, 1.5 * sx, 1.25, -5.1, "Light"),
			box(1.2, 0.8, 0.6, 1.9 * sx, 0.45, -5.3, "Metal"),
			box(0.9, 0.5, 0.2, 1.6 * sx, 1.4, 5.1, "ToyRed"),
			box(0.2, 1.8, 0.8, 1.9 * sx, 2.8, -0.3, "Trim"),
			box(0.2, 0.3, 2, 1.9 * sx, 2.8, 1.1, "Trim"),
			box(0.2, 1.8, 1.4, 1.9 * sx, 2.8, 2.8, "Trim"),
			box(0.6, 0.6, 3.2, 2.6 * sx, 0.9, 0, "Body")
		)
		for _, z in { -3.1, 3.1 } do
			add(
				boxes,
				box(1, 2.2, 2.2, 2.8 * sx, 0, z, "Tire"),
				box(0.15, 0.9, 0.9, 3.375 * sx, 0.65, z, "Metal"),
				box(0.8, 0.5, 2.8, 2.7 * sx, 2.2, z, "Body"),
				box(0.8, 1.2, 0.4, 2.7 * sx, 1, z - 1.3, "Body")
			)
		end
	end
	return { Name = "Car", Tier = 2, Boxes = boxes }
end

-- Barraca de feira com toldo listrado (referência do "SELL").
-- Barraca de feira com toldo listrado (referência do "SELL"): postes por fora do balcão.
function builders.FoodCart()
	local boxes = {
		box(5, 2.6, 2.4, 0, 0, 0.4, "Plank"),
		box(5, 0.4, 2.8, 0, 2.6, 0.4, "Beam"),
	}
	for _, x in { -2.8, 2.8 } do
		for _, z in { -1.2, 1.6 } do
			table.insert(boxes, box(0.6, 5.4, 0.6, x, 0, z, "Beam"))
		end
	end
	stripes(boxes, -3.2, 6, 6.4 / 6, 5.4, 0.2, 4.4)
	return { Name = "FoodCart", Tier = 2, Boxes = boxes }
end

-- Tier 3: casas e fonte -----------------------------------------------------------

-- Casa (referência da casinha de telhado laranja): base de pedra, paredes claras, telhado de duas águas com
-- beiral, varanda com colunas e telhadinho, toldos nas janelas e chaminé de tijolo encostada na lateral.
function builders.House()
	local w, d, h = 12, 10, 7
	local boxes = {
		box(w + 0.6, 0.8, d + 0.6, 0, 0, 0, "Stone"),
		box(w, h, d, 0, 0.8, 0, "Wall"),
		box(2.2, 4, 0.3, 0, 0.8, -d / 2 - 0.15, "Door"),
		-- varanda: degrau, duas colunas e telhadinho em cunha encostado na parede
		box(5, 0.5, 2, 0, 0, -d / 2 - 1.3, "Stone"),
		box(0.5, 4.5, 0.5, -2.1, 0.5, -d / 2 - 2, "Trim"),
		box(0.5, 4.5, 0.5, 2.1, 0.5, -d / 2 - 2, "Trim"),
		shaped(box(5.4, 1.2, 2.7, 0, 5, -d / 2 - 1.35, "Roof"), "Wedge", 0),
		-- toldos sobre as janelas da frente
		box(2.8, 0.5, 1, -4.1, 5.3, -d / 2 - 0.5, "Awning"),
		box(2.8, 0.5, 1, 4.1, 5.3, -d / 2 - 0.5, "Awning"),
		-- chaminé de tijolo do chão até acima da cumeeira
		box(1.4, 14.2, 1.6, w / 2 + 1, 0, 2, "Chimney"),
		box(1.8, 0.4, 2, w / 2 + 1, 14.2, 2, "Trim"),
	}
	frontWindows(boxes, d, { -4.1, 4.1 }, 3, 2.2, 2)
	sideWindows(boxes, w, { -2.5 }, 3, 2.2, 2)
	gable(boxes, w, d, 0, 0, h + 0.8, 4.6, 0.3, 0.9, "Roof")
	return { Name = "House", Tier = 3, Boxes = boxes }
end

-- Chalé enxaimel (referência da casa com vigas de madeira): base de pedra, parede branca com vigas,
-- janela com venezianas, porta com cobertura, telhado de duas águas e chaminé de tijolo por fora.
function builders.Cottage()
	local w, d, h = 11, 9, 7
	local boxes = {
		box(w + 0.4, 1, d + 0.4, 0, 0, 0, "Stone"),
		box(w, h, d, 0, 1, 0, "WallWhite"),
		box(2.2, 4.2, 0.4, -2.5, 1, -d / 2 - 0.2, "Door"),
		shaped(box(2.8, 0.8, 1.4, -2.5, 5.4, -d / 2 - 0.7, "Roof"), "Wedge", 0),
		-- venezianas dos dois lados da janela
		box(0.7, 2.2, 0.3, 1.85, 3.4, -d / 2 - 0.15, "Plank"),
		box(0.7, 2.2, 0.3, 4.55, 3.4, -d / 2 - 0.15, "Plank"),
		box(1.4, 14, 1.6, -w / 2 - 1.1, 0, 1.5, "Chimney"),
	}
	-- vigas aparentes (enxaimel), sem cruzar porta, janela nem venezianas
	for _, x in { -w / 2 + 0.3, -0.6, 0.9, w / 2 - 0.3 } do
		table.insert(boxes, box(0.6, h, 0.4, x, 1, -d / 2 - 0.2, "Beam"))
	end
	frontWindows(boxes, d, { 3.2 }, 3.4, 2, 2.2)
	gable(boxes, w, d, 0, 0, h + 1, 5, 0.4, 0.8, "Roof")
	return { Name = "Cottage", Tier = 3, Boxes = boxes }
end

function builders.Fountain()
	return {
		Name = "Fountain",
		Tier = 3,
		Boxes = {
			box(14, 1.4, 14, 0, 0, 0, "Stone"),
			box(12, 0.3, 12, 0, 1.4, 0, "Water"),
			box(2.4, 3.7, 2.4, 0, 1.7, 0, "Stone"),
			box(6, 0.8, 6, 0, 5.4, 0, "Stone"),
			box(5, 0.3, 5, 0, 6.2, 0, "Water"),
			box(1.2, 1.7, 1.2, 0, 6.5, 0, "Stone"),
			box(1.6, 1.6, 1.6, 0, 8.2, 0, "Water"),
		},
	}
end

-- Tier 4: sobrado, loja, ônibus, posto ----------------------------------------------

function builders.BigHouse()
	-- sobrado moderno (referência da casa branca de telhado cinza): base, faixa entre os andares, varanda de
	-- vidro em cima, garagem, telhado de duas águas com beiral e chaminé encostada na lateral
	local w, d = 16, 12
	local boxes = {
		box(w + 0.6, 0.8, d + 0.6, 0, 0, 0, "Stone"),
		box(w, 6.4, d, 0, 0.8, 0, "Wall"),
		box(w + 0.4, 0.5, d + 0.4, 0, 7.2, 0, "Trim"),
		box(w, 5.6, d, 0, 7.7, 0, "Wall"),
		box(2.4, 4.4, 0.4, -4.5, 0.8, -d / 2 - 0.2, "Door"),
		box(4, 0.4, 1.6, -4.5, 5.6, -d / 2 - 0.8, "Trim"),
		box(6, 4.6, 0.4, 3.5, 0.8, -d / 2 - 0.2, "Garage"),
		-- varanda do 2º andar: piso e guarda-corpo de vidro
		box(6, 0.4, 1.4, -4, 7.7, -d / 2 - 0.9, "Trim"),
		box(6, 1.2, 0.2, -4, 8.1, -d / 2 - 1.5, "Glass"),
		box(5, 3.2, 0.4, -4, 9, -d / 2 - 0.2, "Glass"),
		box(3, 2.6, 0.4, 4, 9.4, -d / 2 - 0.2, "Window"),
		box(1.4, 20.5, 1.6, w / 2 + 1.1, 0, 2.5, "Chimney"),
	}
	frontWindows(boxes, d, { -1.2 }, 2.8, 2, 2.2)
	sideWindows(boxes, w, { -3, 3 }, 3, 2.4, 2.4)
	sideWindows(boxes, w, { -3, 3 }, 9.4, 2.4, 2.4)
	gable(boxes, w, d, 0, 0, 13.3, 5.5, 0.4, 0.8, "Roof")
	return { Name = "BigHouse", Tier = 4, Boxes = boxes }
end

function builders.Shop()
	local w, d, h = 18, 12, 10
	local boxes = {
		box(w, h, d, 0, 0, 0, "Wall"),
		box(13, 5, 0.4, -1.5, 0.8, -d / 2 - 0.2, "Glass"),
		box(2.6, 5, 0.4, 7, 0, -d / 2 - 0.2, "Door"),
		box(10, 2, 0.6, 0, 7.4, -d / 2 - 0.3, "Sign"),
		box(w + 0.8, 1, d + 0.8, 0, h, 0, "Trim"),
		box(4, 1.6, 3, 4, h + 1, 2, "Metal"),
	}
	-- toldo listrado reto sobre a vitrine
	stripes(boxes, -9, 9, 2, 6, -d / 2 - 1.4, 2.8)
	return { Name = "Shop", Tier = 4, Boxes = boxes }
end

function builders.Bus()
	local boxes = {
		box(6, 4.4, 20, 0, 1, 0, "Bus"),
		box(0.4, 1.8, 16, -3.2, 3, 0, "Glass"),
		box(0.4, 1.8, 16, 3.2, 3, 0, "Glass"),
		box(6.2, 0.6, 20.2, 0, 5.4, 0, "Trim"),
		box(4.6, 1.2, 0.4, 0, 2.4, -10.2, "Glass"),
		box(1.2, 0.6, 0.3, -2, 1.4, -10.15, "Light"),
		box(1.2, 0.6, 0.3, 2, 1.4, -10.15, "Light"),
	}
	wheels(boxes, { -3.4, 3.4 }, { -6.5, 6.5 }, 2.2)
	return { Name = "Bus", Tier = 4, Boxes = boxes }
end

function builders.GasStation()
	local boxes = {
		box(22, 0.4, 16, 0, 0, 0, "Sidewalk"),
		box(10, 7, 7, 4, 0.4, 4, "Wall"),
		box(6, 3.6, 0.4, 4, 0.8, 0.3, "Glass"),
		box(10.6, 0.8, 7.6, 4, 7.4, 4, "Awning"),
		box(20, 1.2, 8, 0, 9.2, -3, "Awning"),
		box(20.4, 0.5, 8.4, 0, 10.4, -3, "Stripe"),
	}
	for _, x in { -8, 8 } do
		table.insert(boxes, box(0.9, 8.8, 0.9, x, 0.4, -3, "Metal"))
	end
	for _, x in { -4, 0 } do
		Voxel.fuelPump(boxes, x, 0.4, -3)
	end
	return { Name = "GasStation", Tier = 4, Boxes = boxes }
end

-- Tier 5: prédio, galpão, caixa d'água ------------------------------------------------

function builders.Apartment()
	local w, d, floors, floorH = 18, 16, 6, 6
	local h = floors * floorH
	local boxes = {
		box(w + 1, 1, d + 1, 0, 0, 0, "Trim"),
		box(w, h, d, 0, 1, 0, "Wall"),
		box(3, 4.6, 0.4, 0, 1, -d / 2 - 0.2, "Door"),
		box(6, 0.5, 2, 0, 5.8, -d / 2 - 1, "Awning"),
		box(w + 1, 1, d + 1, 0, h + 1, 0, "Trim"),
		box(4, 3, 4, -4, h + 2, 3, "Metal"),
		box(3, 3, 3, 5, h + 2, -3, "Roof"),
	}
	for floor = 1, floors - 1 do
		local y = 1 + floor * floorH + 1.6
		frontWindows(boxes, d, { -5.5, 0, 5.5 }, y, 3, 2.8)
		sideWindows(boxes, w, { -4.5, 0, 4.5 }, y, 3, 2.8)
	end
	return { Name = "Apartment", Tier = 5, Boxes = boxes }
end

function builders.Warehouse()
	local w, d, h = 30, 22, 14
	local boxes = {
		box(w, h, d, 0, 0, 0, "Wall"),
		box(10, 9, 0.4, -6, 0, -d / 2 - 0.2, "Garage"),
		box(2.6, 4.6, 0.4, 8, 0, -d / 2 - 0.2, "Door"),
		box(16, 1.2, 0.4, 0, 11, -d / 2 - 0.2, "Sign"),
	}
	stepRoof(boxes, w, d, h, 5, 1.2, "Roof")
	return { Name = "Warehouse", Tier = 5, Boxes = boxes }
end

function builders.WaterTower()
	local boxes = {
		box(15, 1, 15, 0, 21.4, 0, "Trim"),
		box(14, 12, 14, 0, 22.4, 0, "Tank"),
		-- faixa em volta do tanque: 4 tiras coladas nas faces (sem entrar no tanque)
		box(14, 1, 0.3, 0, 27, -7.15, "Stripe"),
		box(14, 1, 0.3, 0, 27, 7.15, "Stripe"),
		box(0.3, 1, 14.6, -7.15, 27, 0, "Stripe"),
		box(0.3, 1, 14.6, 7.15, 27, 0, "Stripe"),
		box(15, 1, 15, 0, 34.4, 0, "Trim"),
		box(11, 2, 11, 0, 35.4, 0, "Roof"),
		box(6, 2, 6, 0, 37.4, 0, "RoofTop"),
		box(10, 2.4, 0.4, 0, 29, -7.2, "Sign"),
	}
	for _, x in { -5, 5 } do
		for _, z in { -5, 5 } do
			table.insert(boxes, box(1.2, 21.4, 1.2, x, 0, z, "Metal"))
		end
	end
	-- travessas entre as pernas (encostadas, sem atravessar)
	table.insert(boxes, box(8.8, 0.8, 0.8, 0, 10, -5, "Metal"))
	table.insert(boxes, box(8.8, 0.8, 0.8, 0, 10, 5, "Metal"))
	return { Name = "WaterTower", Tier = 5, Boxes = boxes }
end

-- Tier 6: torre, museu, torre do relógio ------------------------------------------------

function builders.Tower()
	local boxes = {
		box(26, 2, 26, 0, 0, 0, "Trim"),
		box(24, 44, 24, 0, 2, 0, "Wall"),
		box(25, 1.2, 25, 0, 46, 0, "Trim"),
		box(19, 26, 19, 0, 47.2, 0, "Wall"),
		box(20, 1.2, 20, 0, 73.2, 0, "Trim"),
		box(13, 4, 13, 0, 74.4, 0, "Roof"),
		box(8, 4, 8, 0, 78.4, 0, "RoofTop"),
		box(1, 12, 1, 0, 82.4, 0, "Metal"),
		box(1.6, 1.6, 1.6, 0, 94.4, 0, "Light"),
		box(4, 6, 0.4, 0, 2, -12.2, "Door"),
	}
	for y = 8, 40, 8 do
		table.insert(boxes, box(22, 3, 0.4, 0, y, -12.2, "Window"))
		table.insert(boxes, box(0.4, 3, 22, 12.2, y, 0, "Window"))
	end
	for y = 52, 68, 8 do
		table.insert(boxes, box(17, 3, 0.4, 0, y, -9.7, "Window"))
		table.insert(boxes, box(0.4, 3, 17, 9.7, y, 0, "Window"))
	end
	return { Name = "Tower", Tier = 6, Boxes = boxes }
end

function builders.Museum()
	local boxes = {
		box(46, 3, 38, 0, 0, 2, "Stone"),
		box(30, 1, 3, 0, 0, -18.5, "Stone"),
		box(26, 1, 2, 0, 1, -18, "Stone"),
		box(22, 1, 1, 0, 2, -17.5, "Stone"),
		box(40, 20, 26, 0, 3, 5, "WallWhite"),
		box(42, 1.2, 34, 0, 23, 1, "Trim"),
		box(10, 3, 0.6, 0, 19, -8.3, "Sign"),
	}
	-- frontão em degraus
	for i = 0, 3 do
		table.insert(boxes, box(40 - i * 10, 1.4, 6, 0, 24.2 + i * 1.4, -13, "WallWhite"))
	end
	for _, x in { -15, -9, -3, 3, 9, 15 } do
		table.insert(boxes, box(2.4, 20, 2.4, x, 3, -12, "Trim"))
	end
	-- cúpula em degraus
	for i, width in { 20, 16, 12, 8 } do
		table.insert(boxes, box(width, 2, width, 0, 24.2 + (i - 1) * 2, 5, if i == 4 then "RoofTop" else "Dome"))
	end
	table.insert(boxes, box(3, 3, 3, 0, 32.2, 5, "Light"))
	for _, z in { -2, 5, 12 } do
		table.insert(boxes, box(0.4, 10, 3, 20.2, 7, z, "Accent"))
	end
	return { Name = "Museum", Tier = 6, Boxes = boxes }
end

function builders.ClockTower()
	local boxes = {
		box(20, 3, 20, 0, 0, 0, "Stone"),
		box(16, 40, 16, 0, 3, 0, "Brick"),
		box(17, 1.2, 17, 0, 43, 0, "Trim"),
		box(12, 12, 12, 0, 44.2, 0, "WallWhite"),
		box(13, 1, 13, 0, 56.2, 0, "Trim"),
		box(4, 7, 0.4, 0, 3, -8.2, "Door"),
	}
	-- relógios quadrados com ponteiros (frente e trás); os ponteiros só se encostam
	for _, side in { -1, 1 } do
		local z = side * 6.3
		add(
			boxes,
			box(8, 8, 0.6, 0, 46.2, z, "Clock"),
			box(0.6, 3, 0.3, 0, 50.2, z + side * 0.45, "Metal"),
			box(2.4, 0.6, 0.3, 1.5, 50, z + side * 0.45, "Metal")
		)
	end
	for i, width in { 12, 9, 6, 3 } do
		table.insert(boxes, box(width, 2.4, width, 0, 57.2 + (i - 1) * 2.4, 0, if i == 4 then "RoofTop" else "Roof"))
	end
	for y = 10, 34, 8 do
		table.insert(boxes, box(3, 4, 0.4, 0, y, -8.2, "Window"))
		table.insert(boxes, box(0.4, 4, 3, 8.2, y, 0, "Window"))
	end
	return { Name = "ClockTower", Tier = 6, Boxes = boxes }
end

-- Tier 7: marcos do mapa ---------------------------------------------------------

function builders.Skyscraper()
	local boxes = {
		box(42, 3, 42, 0, 0, 0, "Trim"),
		box(38, 60, 38, 0, 3, 0, "Wall"),
		box(40, 2, 40, 0, 63, 0, "Trim"),
		box(30, 50, 30, 0, 65, 0, "Wall"),
		box(32, 2, 32, 0, 115, 0, "Trim"),
		box(20, 30, 20, 0, 117, 0, "Wall"),
		box(22, 2, 22, 0, 147, 0, "Roof"),
		box(10, 8, 10, 0, 149, 0, "RoofTop"),
		box(1.4, 26, 1.4, 0, 157, 0, "Light"),
		box(8, 8, 0.4, 0, 3, -19.2, "Door"),
	}
	for y = 12, 56, 9 do
		table.insert(boxes, box(36, 4, 0.4, 0, y, -19.2, "Window"))
		table.insert(boxes, box(0.4, 4, 36, 19.2, y, 0, "Window"))
	end
	for y = 72, 108, 9 do
		table.insert(boxes, box(28, 4, 0.4, 0, y, -15.2, "Window"))
		table.insert(boxes, box(0.4, 4, 28, 15.2, y, 0, "Window"))
	end
	for y = 122, 140, 9 do
		table.insert(boxes, box(18, 4, 0.4, 0, y, -10.2, "Window"))
		table.insert(boxes, box(0.4, 4, 18, 10.2, y, 0, "Window"))
	end
	return { Name = "Skyscraper", Tier = 7, Boxes = boxes }
end

function builders.Stadium()
	local boxes = {
		box(70, 1, 54, 0, 0, 0, "Trim"),
		box(50, 0.4, 34, 0, 1, 0, "Leaves"),
	}
	for i = 0, 4 do
		local y = 1 + i * 3
		local inset = i * 2
		table.insert(boxes, box(70, 3, 4, 0, y, -25 + inset, "Wall"))
		table.insert(boxes, box(70, 3, 4, 0, y, 25 - inset, "Wall"))
		table.insert(boxes, box(4, 3, 46 - inset * 2, -33 + inset, y, 0, "Wall"))
		table.insert(boxes, box(4, 3, 46 - inset * 2, 33 - inset, y, 0, "Wall"))
	end
	-- torres de luz do lado de fora das arquibancadas
	for _, x in { -36, 36 } do
		for _, z in { -25, 25 } do
			table.insert(boxes, box(2, 31, 2, x, 0, z, "Metal"))
			table.insert(boxes, box(6, 3, 2, x, 31, z, "Light"))
		end
	end
	return { Name = "Stadium", Tier = 7, Boxes = boxes }
end

-- Caixa alinhada aos eixos que envolve o bloco, já considerando o Tilt (rotação Y * X * Z).
local function computeBounds(b: Box)
	local hx, hy, hz = b.Size[1] / 2, b.Size[2] / 2, b.Size[3] / 2
	local ex, ey, ez = hx, hy, hz
	local tilt = b.Tilt
	if tilt then
		local p, y, r = math.rad(tilt[1]), math.rad(tilt[2]), math.rad(tilt[3])
		local cp, sp, cy, sy, cr, sr = math.cos(p), math.sin(p), math.cos(y), math.sin(y), math.cos(r), math.sin(r)
		-- R = Ry * Rx * Rz
		local m = {
			{ cy * cr + sy * sp * sr, -cy * sr + sy * sp * cr, sy * cp },
			{ cp * sr, cp * cr, -sp },
			{ -sy * cr + cy * sp * sr, sy * sr + cy * sp * cr, cy * cp },
		}
		local half = { hx, hy, hz }
		local extents = {}
		for row = 1, 3 do
			local e = 0
			for col = 1, 3 do
				e += math.abs(m[row][col]) * half[col]
			end
			extents[row] = e
		end
		ex, ey, ez = extents[1], extents[2], extents[3]
	end
	b.Min = { b.Pos[1] - ex, b.Pos[2] - ey, b.Pos[3] - ez }
	b.Max = { b.Pos[1] + ex, b.Pos[2] + ey, b.Pos[3] + ez }
end

-- Footprint calculado a partir dos blocos (simétrico em torno do centro, arredondado para cima).
local function computeFootprint(boxes: { Box }): { number }
	local halfX, halfZ = 0, 0
	for _, b in boxes do
		local min, max = b.Min :: { number }, b.Max :: { number }
		halfX = math.max(halfX, math.abs(min[1]), math.abs(max[1]))
		halfZ = math.max(halfZ, math.abs(min[3]), math.abs(max[3]))
	end
	return { math.ceil(halfX * 2), math.ceil(halfZ * 2) }
end

for name, build in CityBuildings do
	builders[name] = function()
		return build(Voxel)
	end
end
for name, build in CityProps do
	assert(builders[name] == nil, `modelo repetido: {name}`)
	builders[name] = function()
		return build(Voxel)
	end
end

local Templates: { [string]: Template } = {}
for name, build in builders do
	local template = build()
	for _, b in template.Boxes do
		computeBounds(b)
	end
	template.Footprint = computeFootprint(template.Boxes)
	assert(template.Name == name, `nome inconsistente: {name}`)
	Templates[name] = template
end

return Templates
