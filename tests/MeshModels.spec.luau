-- Modelos feitos no Blender (Config/MeshModelsConfig, gerado por assets/blender/build_city_models.py):
-- cada um substitui os blocos de um Template, então precisa caber no mesmo lugar e usar cores que existem.
local MeshModelsConfig = require("../src/shared/Config/MeshModelsConfig")
local Templates = require("../src/shared/Buildings/Templates")
local MapConfig = require("../src/shared/Config/MapConfig")

local SLACK = 0.6 -- studs: beiral e chanfros podem passar um pouco da caixa dos blocos

return function(t)
	for name, pieces in MeshModelsConfig.Models do
		t.test(`{name}: modelo do Blender existe nos Templates e cabe no footprint dele`, function()
			local template = Templates[name]
			t.truthy(template ~= nil)
			local fx, fz = template.Footprint[1] / 2 + SLACK, template.Footprint[2] / 2 + SLACK
			for _, p in pieces do
				local x0, x1 = p.Center[1] - p.Size[1] / 2, p.Center[1] + p.Size[1] / 2
				local z0, z1 = p.Center[3] - p.Size[3] / 2, p.Center[3] + p.Size[3] / 2
				if x0 < -fx or x1 > fx or z0 < -fz or z1 > fz then
					error(`{p.Mesh} sai do footprint ({x0}..{x1}, {z0}..{z1}) x ({fx}, {fz})`)
				end
				-- apoiado no chão: nada abaixo de 0
				t.truthy(p.Center[2] - p.Size[2] / 2 >= -0.01)
			end
		end)

		t.test(`{name}: todo papel de cor existe na paleta de todos os mapas`, function()
			for _, map in MapConfig do
				for _, p in pieces do
					if map.Palette[p.Role] == nil then
						error(`{map.Id} não tem cor para {p.Role} ({p.Mesh})`)
					end
				end
			end
		end)
	end
end
