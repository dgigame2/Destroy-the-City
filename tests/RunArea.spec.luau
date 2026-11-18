-- Área "START A RUN" do lobby: nenhuma peça dentro da outra, tudo dentro da ilha, quadrados bem separados
-- e a checagem de "em cima do quadrado".
local RunArea = require("../src/shared/Logic/RunArea")
local LobbyConfig = require("../src/shared/Config/LobbyConfig")
local PartyConfig = require("../src/shared/Config/PartyConfig")
local MovementConfig = require("../src/shared/Config/MovementConfig")

local cfg = LobbyConfig.RunArea
local TOL = 0.001

-- Peças vizinhas montadas pelo LobbyService (MEDIDAS do código: buildPlaza, buildIsland, buildStation).
local NEIGHBORS = {
	{
		Name = "ViewGlass",
		Kind = "Glass",
		Size = { LobbyConfig.Width - 8, 4, 0.6 },
		Pos = { 0, 2, LobbyConfig.Depth / 2 - 1.5 },
	},
	{
		Name = "ViewRail",
		Kind = "Rail",
		Size = { LobbyConfig.Width - 8, 0.8, 1.2 },
		Pos = { 0, 4.4, LobbyConfig.Depth / 2 - 1.5 },
	},
}
-- placas DAILY REWARDS e CLASSES (LobbyConfig.Stations + caixa das meshes)
for _, name in { "Rewards", "Classes" } do
	local at = LobbyConfig.Stations[name]
	local spec = LobbyConfig.Props["Sign" .. name]
	table.insert(NEIGHBORS, {
		Name = "Sign" .. name,
		Kind = "Board",
		Size = spec.Size,
		Pos = { at[1] + spec.Center[1], spec.Center[2], at[2] + spec.Center[3] },
	})
end
-- caminhos de pedra (LobbyConfig.Paths) com a borda de lajota (mais alta que o caminho)
do
	local b, h = LobbyConfig.PathBorder.Width, LobbyConfig.PathBorder.Height
	for i, p in LobbyConfig.Paths do
		local sx, sz = p[3] - p[1] + b * 2, p[4] - p[2] + b * 2
		table.insert(NEIGHBORS, {
			Name = "Path" .. i,
			Kind = "Path",
			Size = { sx, h, sz },
			Pos = { (p[1] + p[3]) / 2, h / 2, (p[2] + p[4]) / 2 },
		})
	end
end

return function(t)
	local boxes = RunArea.boxes(cfg, PartyConfig.Pads)
	local pads = RunArea.pads(cfg, PartyConfig.Pads)

	t.test("área START A RUN: nenhuma peça entra em outra", function()
		for i = 1, #boxes do
			for j = i + 1, #boxes do
				local a, b = boxes[i], boxes[j]
				t.falsy(RunArea.overlaps(a, b, TOL))
			end
		end
	end)

	t.test("área START A RUN: não encosta para dentro do caminho, das placas nem do vidro", function()
		for _, a in boxes do
			for _, b in NEIGHBORS do
				if RunArea.overlaps(a, b, TOL) then
					error(`{a.Name} (pad {a.Pad or "-"}) entra em {b.Name}`)
				end
			end
		end
	end)

	t.test("portal do Blender: atrás dos quadrados, dentro da ilha e com as placas no lugar dos quadrados", function()
		local gate = LobbyConfig.Props.RunGate
		local box = {
			Name = "RunGate",
			Kind = "Mesh",
			Size = gate.Size,
			Pos = { gate.Center[1], gate.Center[2], cfg.BoardZ + gate.Center[3] },
		}
		for _, b in boxes do
			if b.Kind == "Floor" or b.Kind == "Border" then
				t.falsy(RunArea.overlaps(box, b, TOL))
			end
		end
		for _, b in NEIGHBORS do
			t.falsy(RunArea.overlaps(box, b, TOL))
		end
		t.truthy(math.abs(box.Pos[1]) + box.Size[1] / 2 <= LobbyConfig.Width / 2)
		t.truthy(box.Pos[3] + box.Size[3] / 2 <= LobbyConfig.Depth / 2)
		-- o portal tem uma placa azul por quadrado (mesma distância entre elas)
		t.near(gate.Size[1], cfg.PadSpacing * PartyConfig.Pads + 2.6, 0.01)
	end)

	t.test("tudo fica dentro da grama da ilha", function()
		for _, b in boxes do
			t.truthy(math.abs(b.Pos[1]) + b.Size[1] / 2 <= LobbyConfig.Width / 2)
			t.truthy(math.abs(b.Pos[3]) + b.Size[3] / 2 <= LobbyConfig.Depth / 2)
			t.truthy(b.Pos[2] - b.Size[2] / 2 >= -TOL) -- nada afunda no chão
		end
	end)

	t.test("quadrados simétricos e separados por grama (ninguém fica em dois ao mesmo tempo)", function()
		t.equal(#pads, PartyConfig.Pads)
		for i, pad in pads do
			t.near(pad.X, -pads[#pads + 1 - i].X)
			if i > 1 then
				t.truthy(pad.X - pads[i - 1].X - cfg.PadSize >= 4)
			end
		end
	end)

	t.test("sem pulo: o piso do quadrado é um degrau que dá para subir andando", function()
		t.truthy(cfg.PadHeight < MovementConfig.MaxStepHeight)
	end)

	t.test("em cima do quadrado: dentro da área e até a altura de detecção", function()
		local pad = pads[1]
		t.truthy(RunArea.isOnPad(pad, pad.X, 3, pad.Z, cfg.DetectHeight))
		t.truthy(RunArea.isOnPad(pad, pad.X + pad.Half, 3, pad.Z - pad.Half, cfg.DetectHeight))
		t.falsy(RunArea.isOnPad(pad, pad.X + pad.Half + 0.1, 3, pad.Z, cfg.DetectHeight))
		t.falsy(RunArea.isOnPad(pad, pad.X, cfg.DetectHeight + 1, pad.Z, cfg.DetectHeight))
		t.falsy(RunArea.isOnPad(pad, pad.X, -1, pad.Z, cfg.DetectHeight))
	end)

	t.test("quem é tirado do quadrado cai na grama, fora de todos os quadrados", function()
		for _, pad in pads do
			local z = pad.Z - cfg.ExitBack
			for _, other in pads do
				t.falsy(RunArea.isOnPad(other, pad.X, 3, z, cfg.DetectHeight))
			end
			t.truthy(z > 18) -- na frente da praça, no caminho/grama
		end
	end)

	t.test("quadrado da loja: em volta da escada, sem pisar nos degraus nem nos postes do portão", function()
		local pad = LobbyConfig.ShopPad
		t.truthy(pad.X - pad.Strip >= 3.6) -- degraus: x ±3.6 (assets/blender/build_shop_signs.py)
		t.truthy(pad.Z1 <= -8.8 + TOL) -- encosta na base da casa (z -8.8)
		t.truthy(pad.Z0 >= -13 - TOL) -- postes do portão: x ±(4.1..5.1), z -14..-13
		t.truthy(pad.Height < MovementConfig.MaxStepHeight)
	end)

	t.test("quadrado da loja: dentro abre, fora não", function()
		local pad = LobbyConfig.ShopPad
		local midZ = (pad.Z0 + pad.Z1) / 2
		t.truthy(RunArea.isOnFloorPad(pad, 0, 3, midZ))
		t.truthy(RunArea.isOnFloorPad(pad, pad.X, 3, pad.Z0))
		t.falsy(RunArea.isOnFloorPad(pad, pad.X + 0.1, 3, midZ))
		t.falsy(RunArea.isOnFloorPad(pad, 0, 3, pad.Z0 - 0.1))
		t.falsy(RunArea.isOnFloorPad(pad, 0, 3, pad.Z1 + 0.1))
		t.falsy(RunArea.isOnFloorPad(pad, 0, pad.DetectHeight + 1, midZ))
	end)

	t.test("quadrados das placas: na frente delas, sem pisar em caminho, quadrado da run nem no portal", function()
		local pad = LobbyConfig.StationPad
		t.truthy(pad.Z1 <= -1.4 + TOL) -- a floreira da placa vai até z -1.4
		t.truthy(pad.Height < MovementConfig.MaxStepHeight)
		local b, gate = LobbyConfig.PathBorder.Width, LobbyConfig.Props.RunGate
		for _, name in { "Rewards", "Classes" } do
			local at = LobbyConfig.Stations[name]
			local box = {
				Name = name .. "Pad",
				Kind = "Pad",
				Size = { pad.X * 2, pad.Height, pad.Z1 - pad.Z0 },
				Pos = { at[1], pad.Height / 2, at[2] + (pad.Z0 + pad.Z1) / 2 },
			}
			for _, other in boxes do
				t.falsy(RunArea.overlaps(box, other, TOL))
			end
			for _, p in LobbyConfig.Paths do
				local path = {
					Name = "Path",
					Kind = "Path",
					Size = { p[3] - p[1] + b * 2, 1, p[4] - p[2] + b * 2 },
					Pos = { (p[1] + p[3]) / 2, 0, (p[2] + p[4]) / 2 },
				}
				t.falsy(RunArea.overlaps(box, path, TOL))
			end
			local gateBox = {
				Name = "RunGate",
				Kind = "Mesh",
				Size = gate.Size,
				Pos = { gate.Center[1], gate.Center[2], cfg.BoardZ + gate.Center[3] },
			}
			t.falsy(RunArea.overlaps(box, gateBox, TOL))
			t.truthy(math.abs(at[1]) + pad.X <= LobbyConfig.Width / 2)
		end
	end)
end
