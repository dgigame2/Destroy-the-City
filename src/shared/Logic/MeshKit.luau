--!strict
-- Decide qual mesh do kit do Blender (Config/MeshKitConfig) cada bloco de um Template usa.
-- Lógica pura (sem APIs do Roblox): testada no Lune em tests/MeshKit.spec.luau.
-- Retorna nil quando o bloco deve continuar uma peça normal (cunha, inclinado, luz/água, fino ou comprido demais).

local MeshKit = {}

export type Box = {
	Size: { number },
	Role: string,
	Shape: string?,
	Tilt: { number }?,
}

export type Config = {
	Enabled: boolean,
	Block: string,
	Leaf: string,
	Cylinder: string,
	Ball: string,
	LeafRoles: { [string]: boolean },
	KeepRoles: { [string]: boolean },
	MinSide: number,
	MaxAspect: number,
	LeafMinSide: number,
}

function MeshKit.choose(b: Box, config: Config): string?
	if not config.Enabled or b.Tilt ~= nil or config.KeepRoles[b.Role] then
		return nil
	end
	local sx, sy, sz = b.Size[1], b.Size[2], b.Size[3]
	local smallest = math.min(sx, sy, sz)
	local largest = math.max(sx, sy, sz)
	if smallest < config.MinSide or largest / smallest > config.MaxAspect then
		return nil
	end
	local shape = b.Shape or "Block"
	if shape == "Block" then
		if config.LeafRoles[b.Role] and smallest >= config.LeafMinSide then
			return config.Leaf
		end
		return config.Block
	elseif shape == "Cylinder" or shape == "CylinderZ" then
		return config.Cylinder
	elseif shape == "Ball" then
		return config.Ball
	end
	return nil -- Wedge e formas futuras: peça normal
end

return MeshKit
