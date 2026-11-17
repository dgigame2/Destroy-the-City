--!strict
-- GERADO por assets/blender/build_city_models.py (não editar à mão: rode o script de novo).
-- Modelos da cidade feitos no Blender: uma mesh por papel de cor (o Builder pinta com a paleta do mapa).
-- Size/Center em studs, no espaço do modelo (origem no centro da base, frente -Z). As meshes ficam em
-- ReplicatedStorage.Assets (importe assets/blender/CityModels.fbx no Studio do Run). Sem elas, o
-- Builder usa os blocos do Templates.

export type MeshPiece = { Role: string, Mesh: string, Size: { number }, Center: { number } }

local models: { [string]: { MeshPiece } } = {
	BigHouse = {
		{
			Role = "Chimney",
			Mesh = "M_BigHouse_Chimney",
			Size = { 1.400, 5.400, 1.400 },
			Center = { 4.500, 17.700, 3.000 },
		},
		{ Role = "Door", Mesh = "M_BigHouse_Door", Size = { 2.200, 4.200, 0.160 }, Center = { -4.500, 2.900, -6.080 } },
		{
			Role = "Garage",
			Mesh = "M_BigHouse_Garage",
			Size = { 6.000, 4.600, 0.120 },
			Center = { 3.500, 3.100, -6.060 },
		},
		{
			Role = "Glass",
			Mesh = "M_BigHouse_Glass",
			Size = { 6.400, 4.150, 1.570 },
			Center = { 0.000, 10.125, -6.815 },
		},
		{
			Role = "Metal",
			Mesh = "M_BigHouse_Metal",
			Size = { 0.260, 12.400, 0.300 },
			Center = { 7.850, 7.000, -6.050 },
		},
		{
			Role = "Roof",
			Mesh = "M_BigHouse_Roof",
			Size = { 17.000, 6.117, 13.600 },
			Center = { 0.000, 15.692, 0.000 },
		},
		{
			Role = "RoofTop",
			Mesh = "M_BigHouse_RoofTop",
			Size = { 17.200, 0.968, 6.800 },
			Center = { 0.000, 18.436, -3.000 },
		},
		{
			Role = "Stone",
			Mesh = "M_BigHouse_Stone",
			Size = { 16.600, 0.800, 12.600 },
			Center = { 0.000, 0.400, 0.000 },
		},
		{
			Role = "Trim",
			Mesh = "M_BigHouse_Trim",
			Size = { 17.100, 18.750, 13.800 },
			Center = { 0.000, 11.325, -0.700 },
		},
		{
			Role = "Wall",
			Mesh = "M_BigHouse_Wall",
			Size = { 16.000, 17.500, 12.000 },
			Center = { 0.000, 9.550, 0.000 },
		},
		{
			Role = "Window",
			Mesh = "M_BigHouse_Window",
			Size = { 16.340, 9.200, 10.370 },
			Center = { 0.000, 7.200, -0.985 },
		},
	},
	Bungalow = {
		{
			Role = "Accent",
			Mesh = "M_Bungalow_Accent",
			Size = { 11.200, 1.800, 0.120 },
			Center = { 0.000, 3.100, -5.120 },
		},
		{
			Role = "Awning",
			Mesh = "M_Bungalow_Awning",
			Size = { 3.800, 0.650, 1.300 },
			Center = { 0.000, 4.725, -5.650 },
		},
		{ Role = "Door", Mesh = "M_Bungalow_Door", Size = { 2.200, 3.600, 0.160 }, Center = { 0.000, 2.400, -5.080 } },
		{ Role = "Roof", Mesh = "M_Bungalow_Roof", Size = { 13.000, 4.576, 11.600 }, Center = { 0.000, 7.312, 0.000 } },
		{
			Role = "RoofTop",
			Mesh = "M_Bungalow_RoofTop",
			Size = { 13.200, 0.350, 0.700 },
			Center = { 0.000, 9.615, 0.000 },
		},
		{
			Role = "Stone",
			Mesh = "M_Bungalow_Stone",
			Size = { 12.600, 0.600, 10.600 },
			Center = { 0.000, 0.300, 0.000 },
		},
		{ Role = "Trim", Mesh = "M_Bungalow_Trim", Size = { 13.100, 2.350, 7.100 }, Center = { 0.000, 3.025, -2.000 } },
		{ Role = "Wall", Mesh = "M_Bungalow_Wall", Size = { 12.000, 8.600, 10.000 }, Center = { 0.000, 4.900, 0.000 } },
		{
			Role = "Window",
			Mesh = "M_Bungalow_Window",
			Size = { 12.340, 1.800, 6.370 },
			Center = { 0.000, 3.100, -1.985 },
		},
	},
	Bush = {
		{ Role = "Leaves", Mesh = "M_Bush_Leaves", Size = { 3.565, 3.303, 3.244 }, Center = { -0.716, 1.652, 0.354 } },
		{
			Role = "Leaves2",
			Mesh = "M_Bush_Leaves2",
			Size = { 3.340, 2.109, 3.514 },
			Center = { 0.741, 1.132, -0.271 },
		},
	},
	ContainerStack = {
		{
			Role = "Accent",
			Mesh = "M_ContainerStack_Accent",
			Size = { 2.990, 3.000, 7.570 },
			Center = { 1.545, 1.500, 0.035 },
		},
		{
			Role = "Body",
			Mesh = "M_ContainerStack_Body",
			Size = { 2.990, 3.000, 7.570 },
			Center = { -1.545, 4.500, 0.035 },
		},
		{
			Role = "Bus",
			Mesh = "M_ContainerStack_Bus",
			Size = { 2.990, 3.000, 7.570 },
			Center = { 1.545, 4.500, 0.035 },
		},
		{
			Role = "Container",
			Mesh = "M_ContainerStack_Container",
			Size = { 2.990, 3.000, 7.570 },
			Center = { -1.545, 1.500, 0.035 },
		},
		{
			Role = "Metal",
			Mesh = "M_ContainerStack_Metal",
			Size = { 5.980, 5.950, 7.730 },
			Center = { 0.000, 2.975, 0.055 },
		},
		{
			Role = "Trim",
			Mesh = "M_ContainerStack_Trim",
			Size = { 5.400, 3.120, 0.050 },
			Center = { 0.000, 2.860, 3.900 },
		},
	},
	Cottage = {
		{ Role = "Beam", Mesh = "M_Cottage_Beam", Size = { 11.200, 11.900, 1.485 }, Center = { 0.000, 6.950, -5.232 } },
		{
			Role = "Chimney",
			Mesh = "M_Cottage_Chimney",
			Size = { 1.400, 14.000, 1.600 },
			Center = { -6.600, 7.000, 1.500 },
		},
		{ Role = "Door", Mesh = "M_Cottage_Door", Size = { 2.000, 4.000, 0.160 }, Center = { -2.500, 3.000, -4.600 } },
		{
			Role = "Flower",
			Mesh = "M_Cottage_Flower",
			Size = { 2.158, 0.400, 0.340 },
			Center = { 3.200, 3.450, -5.550 },
		},
		{
			Role = "Flower2",
			Mesh = "M_Cottage_Flower2",
			Size = { 1.258, 0.400, 0.340 },
			Center = { 3.200, 3.450, -5.550 },
		},
		{ Role = "Plank", Mesh = "M_Cottage_Plank", Size = { 6.600, 7.600, 0.120 }, Center = { 1.700, 7.200, -4.720 } },
		{ Role = "Pot", Mesh = "M_Cottage_Pot", Size = { 2.200, 0.450, 0.500 }, Center = { 3.200, 3.075, -5.550 } },
		{ Role = "Roof", Mesh = "M_Cottage_Roof", Size = { 12.200, 8.350, 11.000 }, Center = { 0.000, 9.475, -0.500 } },
		{
			Role = "RoofTop",
			Mesh = "M_Cottage_RoofTop",
			Size = { 0.700, 0.350, 10.200 },
			Center = { 0.000, 13.645, 0.000 },
		},
		{ Role = "Stone", Mesh = "M_Cottage_Stone", Size = { 11.400, 1.000, 9.400 }, Center = { 0.000, 0.500, 0.000 } },
		{
			Role = "Trim",
			Mesh = "M_Cottage_Trim",
			Size = { 13.350, 11.250, 7.350 },
			Center = { -0.625, 8.675, -1.475 },
		},
		{
			Role = "WallWhite",
			Mesh = "M_Cottage_WallWhite",
			Size = { 11.000, 12.200, 9.000 },
			Center = { 0.000, 7.100, 0.000 },
		},
		{
			Role = "Window",
			Mesh = "M_Cottage_Window",
			Size = { 11.340, 7.600, 5.770 },
			Center = { 0.000, 7.200, -1.885 },
		},
	},
	FlowerPot = {
		{
			Role = "Flower",
			Mesh = "M_FlowerPot_Flower",
			Size = { 1.560, 0.268, 1.191 },
			Center = { -0.169, 2.778, 0.000 },
		},
		{
			Role = "Flower2",
			Mesh = "M_FlowerPot_Flower2",
			Size = { 1.588, 0.407, 1.059 },
			Center = { 0.213, 2.803, 0.350 },
		},
		{
			Role = "Leaves",
			Mesh = "M_FlowerPot_Leaves",
			Size = { 1.757, 1.310, 1.725 },
			Center = { -0.053, 1.979, 0.003 },
		},
		{ Role = "Pot", Mesh = "M_FlowerPot_Pot", Size = { 2.100, 1.500, 2.100 }, Center = { 0.000, 0.750, 0.000 } },
	},
	Flowers = {
		{
			Role = "Flower",
			Mesh = "M_Flowers_Flower",
			Size = { 3.449, 0.784, 2.283 },
			Center = { -0.164, 1.592, 0.188 },
		},
		{
			Role = "Flower2",
			Mesh = "M_Flowers_Flower2",
			Size = { 3.745, 0.784, 2.759 },
			Center = { 0.084, 1.592, 0.050 },
		},
		{
			Role = "Leaves",
			Mesh = "M_Flowers_Leaves",
			Size = { 4.000, 0.300, 3.000 },
			Center = { 0.000, 0.150, 0.000 },
		},
		{
			Role = "Leaves2",
			Mesh = "M_Flowers_Leaves2",
			Size = { 3.343, 1.500, 1.955 },
			Center = { 0.202, 1.050, 0.050 },
		},
	},
	House = {
		{
			Role = "Awning",
			Mesh = "M_House_Awning",
			Size = { 11.000, 0.720, 1.100 },
			Center = { 0.000, 5.560, -5.550 },
		},
		{
			Role = "Chimney",
			Mesh = "M_House_Chimney",
			Size = { 1.400, 5.200, 1.400 },
			Center = { 3.200, 12.100, 2.200 },
		},
		{ Role = "Door", Mesh = "M_House_Door", Size = { 2.000, 3.800, 0.160 }, Center = { 0.000, 2.700, -5.080 } },
		{ Role = "Metal", Mesh = "M_House_Metal", Size = { 0.180, 0.180, 0.120 }, Center = { 0.600, 2.790, -5.200 } },
		{ Role = "Roof", Mesh = "M_House_Roof", Size = { 12.900, 7.850, 13.800 }, Center = { 0.000, 8.925, -1.000 } },
		{
			Role = "RoofTop",
			Mesh = "M_House_RoofTop",
			Size = { 13.100, 0.350, 0.700 },
			Center = { 0.000, 12.845, 0.000 },
		},
		{ Role = "Stone", Mesh = "M_House_Stone", Size = { 12.600, 0.800, 12.600 }, Center = { 0.000, 0.400, -1.000 } },
		{ Role = "Trim", Mesh = "M_House_Trim", Size = { 13.100, 14.550, 11.190 }, Center = { 0.000, 7.775, -1.645 } },
		{ Role = "Wall", Mesh = "M_House_Wall", Size = { 12.000, 11.600, 10.000 }, Center = { 0.000, 6.600, 0.000 } },
		{
			Role = "Window",
			Mesh = "M_House_Window",
			Size = { 12.340, 2.000, 8.770 },
			Center = { 0.000, 4.000, -0.785 },
		},
	},
	Mushroom = {
		{ Role = "Cap", Mesh = "M_Mushroom_Cap", Size = { 4.830, 2.300, 3.580 }, Center = { 0.335, 1.850, 0.260 } },
		{ Role = "Stem", Mesh = "M_Mushroom_Stem", Size = { 3.728, 1.800, 1.900 }, Center = { 0.274, 0.900, 0.500 } },
		{ Role = "Trim", Mesh = "M_Mushroom_Trim", Size = { 4.221, 1.953, 2.481 }, Center = { 0.329, 2.091, 0.336 } },
	},
	Plane = {
		{
			Role = "Accent",
			Mesh = "M_Plane_Accent",
			Size = { 28.800, 10.200, 29.000 },
			Center = { 0.000, 6.100, 0.100 },
		},
		{ Role = "Metal", Mesh = "M_Plane_Metal", Size = { 13.462, 2.700, 10.800 }, Center = { 0.000, 2.150, -4.250 } },
		{ Role = "Tire", Mesh = "M_Plane_Tire", Size = { 5.961, 0.800, 10.900 }, Center = { -0.200, 0.400, -4.050 } },
		{
			Role = "WallWhite",
			Mesh = "M_Plane_WallWhite",
			Size = { 28.000, 4.100, 30.000 },
			Center = { 0.000, 4.250, 0.000 },
		},
		{
			Role = "Window",
			Mesh = "M_Plane_Window",
			Size = { 4.040, 0.850, 19.575 },
			Center = { 0.000, 4.775, -3.412 },
		},
	},
	Rock = {
		{ Role = "Rock", Mesh = "M_Rock_Rock", Size = { 6.339, 3.887, 3.374 }, Center = { 0.937, 1.943, 0.292 } },
	},
	SnowCabin = {
		{
			Role = "Accent",
			Mesh = "M_SnowCabin_Accent",
			Size = { 9.400, 1.600, 0.120 },
			Center = { 0.000, 2.800, -5.120 },
		},
		{ Role = "Door", Mesh = "M_SnowCabin_Door", Size = { 2.000, 3.200, 0.160 }, Center = { 0.000, 2.200, -5.080 } },
		{
			Role = "Plank",
			Mesh = "M_SnowCabin_Plank",
			Size = { 10.629, 9.000, 10.629 },
			Center = { 0.000, 5.100, 0.000 },
		},
		{
			Role = "Roof",
			Mesh = "M_SnowCabin_Roof",
			Size = { 11.200, 5.736, 11.600 },
			Center = { 0.000, 7.132, 0.000 },
		},
		{
			Role = "Snow",
			Mesh = "M_SnowCabin_Snow",
			Size = { 11.400, 6.836, 11.400 },
			Center = { 0.000, 8.082, 0.000 },
		},
		{
			Role = "Stone",
			Mesh = "M_SnowCabin_Stone",
			Size = { 10.400, 11.200, 10.400 },
			Center = { 0.000, 5.600, 0.000 },
		},
		{ Role = "Trim", Mesh = "M_SnowCabin_Trim", Size = { 8.500, 2.150, 0.550 }, Center = { 0.000, 2.725, -5.275 } },
		{
			Role = "Window",
			Mesh = "M_SnowCabin_Window",
			Size = { 7.800, 1.600, 0.060 },
			Center = { 0.000, 2.800, -5.140 },
		},
	},
	Tree = {
		{ Role = "Leaves", Mesh = "M_Tree_Leaves", Size = { 5.498, 7.490, 7.072 }, Center = { -0.001, 8.859, -0.713 } },
		{ Role = "Leaves2", Mesh = "M_Tree_Leaves2", Size = { 9.754, 4.428, 6.597 }, Center = { 0.004, 7.258, 0.873 } },
		{ Role = "Trunk", Mesh = "M_Tree_Trunk", Size = { 4.600, 6.000, 1.650 }, Center = { 0.100, 3.000, 0.075 } },
	},
}

return table.freeze({ Folder = "Assets", Models = models })
