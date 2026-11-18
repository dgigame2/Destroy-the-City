--!strict
-- Lobby: pisar no quadrado neon da escada da loja ou da frente das placas DAILY REWARDS / CLASSES abre a janela.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LobbyConfig = require(Shared.Config.LobbyConfig)
local RunArea = require(Shared.Logic.RunArea)

local InterfaceController = require(script.Parent.InterfaceController)
local ShopController = require(script.Parent.ShopController)

local LobbyController = {}

-- Mesma conta do LobbyService: origem do lobby * posição (e giro) da loja / da placa.
local ORIGIN = CFrame.new(0, LobbyConfig.FloorHeight, LobbyConfig.CenterZ)

type Watched = { Base: CFrame, Pad: RunArea.FloorPad, Open: () -> (), Inside: boolean }

local function pads(): { Watched }
	local shop = LobbyConfig.Shop
	local rewards, classes = LobbyConfig.Stations.Rewards, LobbyConfig.Stations.Classes
	return {
		{
			Base = ORIGIN * CFrame.new(shop.X, 0, shop.Z) * CFrame.Angles(0, math.rad(shop.Yaw), 0),
			Pad = LobbyConfig.ShopPad,
			Open = function()
				ShopController.openTab("ITEMS")
			end,
			Inside = false,
		},
		{
			Base = ORIGIN * CFrame.new(rewards[1], 0, rewards[2]),
			Pad = LobbyConfig.StationPad,
			Open = function()
				InterfaceController.open("Rewards")
			end,
			Inside = false,
		},
		{
			Base = ORIGIN * CFrame.new(classes[1], 0, classes[2]),
			Pad = LobbyConfig.StationPad,
			Open = function()
				ShopController.openTab("CLASSES")
			end,
			Inside = false,
		},
	}
end

-- Abre a janela uma vez a cada entrada no quadrado (sair e entrar de novo abre outra vez).
local function watchPads()
	local list = pads()
	RunService.Heartbeat:Connect(function()
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		for _, w in list do
			local now = false
			if root then
				local p = w.Base:PointToObjectSpace(root.Position)
				now = RunArea.isOnFloorPad(w.Pad, p.X, p.Y, p.Z)
			end
			if now and not w.Inside then
				w.Open()
			end
			w.Inside = now
		end
	end)
end

function LobbyController.init()
	watchPads()
end

return LobbyController
