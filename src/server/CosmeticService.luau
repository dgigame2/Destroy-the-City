--!strict
-- Coloca no personagem o rastro (Trail) e a aura equipados.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ShopConfig = require(Shared.Config.ShopConfig)

local PlayerData = require(script.Parent.PlayerData)

local COSMETIC_TAG = "EatCityCosmetic"

local CosmeticService = {}

local function findItem(id: string?): ShopConfig.Item?
	for _, item in ShopConfig do
		if item.Id == id then
			return item
		end
	end
	return nil
end

local function sequence(colors: { { number } }): ColorSequence
	if #colors == 1 then
		local c = Color3.fromRGB(colors[1][1], colors[1][2], colors[1][3])
		return ColorSequence.new(c)
	end
	local keypoints = {}
	for index, rgb in colors do
		table.insert(
			keypoints,
			ColorSequenceKeypoint.new((index - 1) / (#colors - 1), Color3.fromRGB(rgb[1], rgb[2], rgb[3]))
		)
	end
	return ColorSequence.new(keypoints)
end

local function clear(root: BasePart)
	for _, child in root:GetChildren() do
		if child:GetAttribute(COSMETIC_TAG) then
			child:Destroy()
		end
	end
end

local function addTrail(root: BasePart, item: ShopConfig.Item)
	local top = Instance.new("Attachment")
	top.Position = Vector3.new(0, 1, 0)
	top:SetAttribute(COSMETIC_TAG, true)
	top.Parent = root
	local bottom = Instance.new("Attachment")
	bottom.Position = Vector3.new(0, -2, 0)
	bottom:SetAttribute(COSMETIC_TAG, true)
	bottom.Parent = root
	local trail = Instance.new("Trail")
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Color = sequence(item.Colors or { { 255, 255, 255 } })
	trail.Transparency = NumberSequence.new(0.15, 1)
	trail.Lifetime = 0.6
	trail.LightEmission = 0.6
	trail.FaceCamera = true
	trail:SetAttribute(COSMETIC_TAG, true)
	trail.Parent = root
end

local function addAura(root: BasePart, item: ShopConfig.Item)
	local attachment = Instance.new("Attachment")
	attachment:SetAttribute(COSMETIC_TAG, true)
	attachment.Parent = root
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = sequence(item.Colors or { { 255, 255, 255 } })
	emitter.Rate = 14
	emitter.Lifetime = NumberRange.new(0.8, 1.4)
	emitter.Speed = NumberRange.new(1, 3)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) })
	emitter.LightEmission = 0.9
	emitter.Shape = Enum.ParticleEmitterShape.Sphere
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	emitter.Parent = attachment
end

function CosmeticService.refresh(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local entry = PlayerData.get(player)
	if root == nil or entry == nil then
		return
	end
	clear(root)
	local trail = findItem(entry.Equipped.Trail)
	if trail and entry.Owned[trail.Id] then
		addTrail(root, trail)
	end
	local aura = findItem(entry.Equipped.Aura)
	if aura and entry.Owned[aura.Id] then
		addAura(root, aura)
	end
end

return CosmeticService
