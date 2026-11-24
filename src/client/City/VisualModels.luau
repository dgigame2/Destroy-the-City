--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local assets = ReplicatedStorage:WaitForChild("SkillAssets")
local VisualModels = {}

function VisualModels.clone(name: string): Model?
	-- O Rojo pode sincronizar uma cópia vazia ao lado da importação válida.
	for _, template in assets:GetChildren() do
		if template.Name == name and template:IsA("Model") then
			local ready = false
			for _, part in template:GetChildren() do
				if part:IsA("MeshPart") then
					ready = part.MeshId ~= ""
					if not ready then
						break
					end
				end
			end
			if ready then
				return template:Clone()
			end
		end
	end
	return nil
end

function VisualModels.fitWidth(model: Model, width: number)
	local size = model:GetExtentsSize()
	model:ScaleTo(model:GetScale() * width / math.max(size.X, size.Z))
end

return VisualModels
