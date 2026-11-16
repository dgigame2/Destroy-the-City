--!strict
-- Kit de meshes do Blender (assets/blender/build_kit.py -> DioramaKit.fbx) que substitui os blocos das
-- construções pelo visual dos mapas: cantos chanfrados, copas low-poly, cilindros e esferas facetados.
-- Cada mesh do kit tem caixa 1x1x1, então o Builder só escala para o tamanho do bloco (Logic/MeshKit decide).
-- Sem o kit importado em ReplicatedStorage.Assets, o jogo continua com as peças normais.

return table.freeze({
	Folder = "Assets", -- ReplicatedStorage.Assets (o FBX importado pode ficar numa subpasta/modelo)
	Enabled = true,

	-- mesh por forma do bloco
	Block = "Kit_Block",
	Leaf = "Kit_Leaf", -- blocos de folhagem (papéis abaixo) viram copa low-poly
	Cylinder = "Kit_Cylinder",
	Ball = "Kit_Ball",

	LeafRoles = table.freeze({ Leaves = true, Leaves2 = true, Pine = true }),
	-- papéis que continuam peça normal: luz neon e água de vidro (material especial)
	KeepRoles = table.freeze({ Light = true, Water = true }),

	-- o chanfro estica junto com a escala: blocos muito finos ou compridos ficam com a peça normal (lisa)
	MinSide = 0.3, -- studs: lado menor que isso não vale um chanfro
	MaxAspect = 14, -- maior lado / menor lado
	LeafMinSide = 1, -- copa low-poly só em blocos de folhagem com pelo menos isso em todos os lados

	-- desastres (client/Controllers/DisasterVfx)
	Disasters = table.freeze({
		Meteor = "Meteor",
		Tornado = "TornadoFunnel",
		Cloud = "StormCloud",
	}),
})
