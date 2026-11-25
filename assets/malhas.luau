-- Remonta as malhas que ficam no PLACE (o Rojo ao vivo não grava MeshId).
-- Uso: no Studio, modo Edit e Rojo conectado, colar tudo na Command Bar, dar Enter e salvar o place (Ctrl+S).
-- Pode rodar de novo: só cria o que falta.
local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- cidade (ReplicatedStorage.Assets): modelos Plane, FoodCart, FruitStand, StopSign, SpeedSign, BumpSign
local CITY = {
	M_BumpSign_Metal = 96867085144127,
	M_BumpSign_Steel = 104465589338823,
	M_BumpSign_Tire = 91560780646609,
	M_BumpSign_ToyYellow = 131295187227240,
	M_FoodCart_Awning = 124334069307458,
	M_FoodCart_Beam = 127993901702638,
	M_FoodCart_Plank = 125921598397829,
	M_FoodCart_Stripe = 127140715069357,
	M_FruitStand_Awning = 102187500468820,
	M_FruitStand_Beam = 101391494309716,
	M_FruitStand_Metal = 72567699403636,
	M_FruitStand_PlaneBody = 105172486518563,
	M_FruitStand_Stripe = 128802155009115,
	M_FruitStand_ToyRed = 120678264705823,
	M_FruitStand_ToyYellow = 76737273609342,
	M_FruitStand_TruckGreen = 90814545628116,
	M_Plane_Accent = 101811346575192,
	M_Plane_Concrete = 75721498333183,
	M_Plane_PlaneBand = 101660726036055,
	M_Plane_PlaneWindow = 127215648204394,
	M_Plane_Steel = 132031281506352,
	M_Plane_Tire = 113807788506648,
	M_Plane_ToyDark = 84476029028352,
	M_Plane_WallWhite = 72999512211912,
	M_SpeedSign_Metal = 96867085144127,
	M_SpeedSign_PlaneBody = 122673434624464,
	M_SpeedSign_Steel = 104465589338823,
	M_SpeedSign_Tire = 94370521830375,
	M_SpeedSign_ToyRed = 106116492574588,
	M_StopSign_Metal = 96867085144127,
	M_StopSign_PlaneBody = 126219330354307,
	M_StopSign_Steel = 104465589338823,
	M_StopSign_ToyRed = 107371774685569,
}
-- tornado Breeze (ReplicatedStorage.SkillAssets.Breeze)
local BREEZE = {
	Seg1 = 122720426000887,
	Seg2 = 102369528115954,
	Seg3 = 107542949285861,
	Seg4 = 80550842341188,
	Seg5 = 113631243584014,
	Seg6 = 100823271327224,
	Wind1 = 71957523133858,
	Wind2 = 88129848999477,
	Wind3 = 132975455448789,
}
local BREEZE_PALETTE = "rbxassetid://72546102315692"

local function load(id: number): MeshPart?
	local ok, part = pcall(function()
		return AssetService:CreateMeshPartAsync(Content.fromUri("rbxassetid://" .. id))
	end)
	if ok then
		return part
	end
	warn("malha", id, part)
	return nil
end

local made, failed = 0, 0
local folder = ReplicatedStorage:FindFirstChild("Assets")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "Assets"
	folder.Parent = ReplicatedStorage
end
for name, id in CITY do
	if not folder:FindFirstChild(name) then
		local part = load(id)
		if part then
			part.Name = name
			part.Anchored = true
			part.Parent = folder
			made += 1
		else
			failed += 1
		end
	end
end
for _, model in ReplicatedStorage.SkillAssets:GetChildren() do
	if model.Name == "Breeze" then
		for _, part in model:GetChildren() do
			local id = BREEZE[part.Name]
			if id and part:IsA("MeshPart") then
				if part.MeshId == "" then
					local size = part.Size
					local mesh = load(id)
					if mesh then
						part:ApplyMesh(mesh)
						part.Size = size
						made += 1
					else
						failed += 1
					end
				end
				part.TextureID = BREEZE_PALETTE
			end
		end
	end
end
print(`malhas: {made} criadas, {failed} falharam. Agora salve o place (Ctrl+S).`)
