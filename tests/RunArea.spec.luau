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
	{ Name = "PathToPads", Kind = "Path", Size = { 10, 0.3, 38 }, Pos = { 0, 0.15, 37 } },
	{ Name = "PathLeft", Kind = "Path", Size = { 50, 0.3, 9 }, Pos = { -40, 0.15, 39.5 } },
	{ Name = "PathRight", Kind = "Path", Size = { 50, 0.3, 9 }, Pos = { 40, 0.15, 39.5 } },
	{ Name = "RewardsBoard", Kind = "Board", Size = { 22.8, 17.2, 2.4 }, Pos = { -45, 8.6, 45 } },
	{ Name = "ClassesBoard", Kind = "Board", Size = { 22.8, 17.2, 2.4 }, Pos = { 45, 8.6, 45 } },
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
	{ Name = "Rock", Kind = "Decor", Size = { 12, 8, 12 }, Pos = { -62, 4, 75 } },
	{ Name = "Rock", Kind = "Decor", Size = { 12, 8, 12 }, Pos = { 62, 4, 75 } },
}

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

	t.test("área START A RUN: não encosta para dentro do caminho, das placas, do vidro nem das pedras", function()
		for _, a in boxes do
			for _, b in NEIGHBORS do
				if RunArea.overlaps(a, b, TOL) then
					error(`{a.Name} (pad {a.Pad or "-"}) entra em {b.Name}`)
				end
			end
		end
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
end
