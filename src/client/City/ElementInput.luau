--!strict
-- Lançar elementos. A escolha fica na hotbar do canto direito (client/City/ElementBar).
--   PC: 1 = Fogo, 2 = Raio, 3 = Vento (ou clique no botão); clique esquerdo na cidade lança na mira.
--   Toque: toque no botão escolhe; toque na cidade lança o elemento escolhido.
-- O cliente só PEDE (Cast); o servidor (ElementService) confere tudo. O cooldown daqui só evita pedido inútil
-- e desenha a recarga na hotbar.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ElementConfig = require(Shared.Config.ElementConfig)
local ElementPlan = require(Shared.Logic.ElementPlan)
local Remotes = require(Shared.Remotes)

local CityClient = require(script.Parent.CityClient)
local ElementBar = require(script.Parent.ElementBar)
local Feedback = require(script.Parent.Parent.Feedback)

local ElementInput = {}

local selected = 1
local lastCast: { [string]: number } = {}
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include

local KEYS: { [Enum.KeyCode]: number } = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
}

local function pick(index: number)
	if ElementConfig.List[index] == nil then
		return
	end
	selected = index
	ElementBar.select(index)
end

-- Cooldown do nível atual (o servidor confere o mesmo).
local function cooldownOf(element: ElementConfig.Element): number
	local level = Players.LocalPlayer:GetAttribute("Level" .. element.Id)
	return ElementPlan.cooldown(element, if type(level) == "number" then level else 1, ElementConfig.MaxLevel)
end

local function cast(point: Vector2, viewport: boolean)
	local city = Workspace:FindFirstChild("City")
	local camera = Workspace.CurrentCamera
	if city == nil or camera == nil or not CityClient.isReady() then
		return
	end
	local element = ElementConfig.List[selected]
	local now = os.clock()
	local cooldown = cooldownOf(element)
	if lastCast[element.Id] and now - lastCast[element.Id] < cooldown then
		return
	end
	params.FilterDescendantsInstances = { city }
	-- mouse vem em coordenada de viewport; toque vem em coordenada de tela (sem a barra do Roblox)
	local ray = if viewport
		then camera:ViewportPointToRay(point.X, point.Y)
		else camera:ScreenPointToRay(point.X, point.Y)
	local hit = Workspace:Raycast(ray.Origin, ray.Direction * 2000, params)
	if hit == nil then
		return
	end
	lastCast[element.Id] = now
	Remotes.event(Remotes.Names.Events.Cast):FireServer(element.Id, hit.Position)
	ElementBar.cooldown(selected, cooldown)
	Feedback.play("Cast", { World = hit.Position, NoNumber = true })
end

function ElementInput.init()
	ElementBar.init(pick) -- toque/clique no botão (o Feedback já toca o som e balança o botão)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local key = KEYS[input.KeyCode]
		if key then
			pick(key)
			Feedback.play("Click", { Gui = ElementBar.button(key), NoNumber = true })
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			cast(UserInputService:GetMouseLocation(), true)
		end
	end)
	UserInputService.TouchTap:Connect(function(positions, processed)
		if not processed and positions[1] then
			cast(positions[1], false)
		end
	end)
end

return ElementInput
