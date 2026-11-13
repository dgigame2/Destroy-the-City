--!strict
-- Ponto de entrada do servidor do Eat City.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local MovementConfig = require(Shared.Config.MovementConfig)

local PlayerData = require(script.PlayerData)
local EatService = require(script.EatService)
local RoundService = require(script.RoundService)
local UpgradeService = require(script.UpgradeService)
local StoreService = require(script.StoreService)
local LightingService = require(script.LightingService)
local LobbyService = require(script.LobbyService)
local GrowthService = require(script.GrowthService)

Remotes.init()
LightingService.apply()
Workspace.Gravity = MovementConfig.Gravity
Players.RespawnTime = MovementConfig.RespawnSeconds

-- Remove o chão padrão do place (o mapa e o lobby trazem o próprio chão).
for _, name in { "Baseplate", "SpawnLocation" } do
	local existing = Workspace:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
end

LobbyService.build()
UpgradeService.init()
StoreService.init()
RoundService.init()
EatService.start()

PlayerData.init(function(player)
	player.CharacterAdded:Connect(function(character)
		RoundService.onCharacter(player, character)
	end)
	if player.Character then
		RoundService.onCharacter(player, player.Character)
	end
end)

-- Só no Studio: atalhos de teste (não existem no jogo publicado).
if RunService:IsStudio() then
	local dev = Instance.new("BindableFunction")
	dev.Name = "DevSetPoints"
	dev.OnInvoke = function(player: Player, points: number)
		GrowthService.setPoints(player, points)
		GrowthService.apply(player, true)
		return GrowthService.scale(player)
	end
	dev.Parent = ServerStorage
	local gems = Instance.new("BindableFunction")
	gems.Name = "DevAddGems"
	gems.OnInvoke = function(player: Player, amount: number)
		PlayerData.addGems(player, amount)
		return player:GetAttribute("Gems")
	end
	gems.Parent = ServerStorage
end

RoundService.run()
