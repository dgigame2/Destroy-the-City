--!strict
-- Lobby: estações (ProximityPrompts) abrem as janelas e o indicador da loja se mexe.

local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LobbyConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.LobbyConfig)

local InterfaceController = require(script.Parent.InterfaceController)
local ShopController = require(script.Parent.ShopController)

local LobbyController = {}

-- Indicador da loja: o anel de traços gira devagar e o "BUY HERE" sobe e desce (só visual, no cliente).
local function animateShopIndicator()
	local lobby = Workspace:WaitForChild("Lobby", 30)
	local ring = lobby and lobby:WaitForChild("ShopRing", 30) :: Model?
	if lobby == nil or ring == nil then
		return
	end
	local rest = ring:GetPivot()
	local billboard = lobby:FindFirstChild("ShopIndicator", true) :: BillboardGui?
	local clock = 0
	RunService.RenderStepped:Connect(function(dt)
		clock += dt
		ring:PivotTo(rest * CFrame.Angles(0, math.rad(clock * LobbyConfig.ShopRingSpin), 0))
		if billboard then
			billboard.StudsOffset = Vector3.new(0, math.sin(clock * 2.5) * 0.6, 0)
		end
	end)
end

function LobbyController.init()
	task.spawn(animateShopIndicator)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt.Name == "OpenShop" then
			ShopController.openTab("ITEMS")
		elseif prompt.Name == "OpenClasses" then
			ShopController.openTab("CLASSES")
		elseif prompt.Name == "OpenWheel" then
			InterfaceController.open("Wheel")
		elseif prompt.Name == "OpenRewards" then
			InterfaceController.open("Rewards")
		end
	end)
end

return LobbyController
