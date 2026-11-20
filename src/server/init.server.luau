--!strict
-- Ponto de entrada do servidor do Disaster Evolution. Um place só: todo servidor é a cidade.
-- A cidade é só DADO no servidor (Match/CityService); cada cliente monta a própria.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local MovementConfig = require(Shared.Config.MovementConfig)

local PlayerData = require(script.PlayerData)
local StoreService = require(script.StoreService)
local LightingService = require(script.LightingService)
local MatchService = require(script.Match.MatchService)
local TornadoService = require(script.Match.TornadoService)
local PvpService = require(script.Match.PvpService)

Remotes.init()
LightingService.apply()
Workspace.Gravity = MovementConfig.Gravity
Players.RespawnTime = MovementConfig.RespawnSeconds

-- Remove o chão padrão do place (o mapa traz o próprio chão).
for _, name in { "Baseplate", "SpawnLocation" } do
	local existing = Workspace:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
end

-- Animação padrão do Roblox: remove uma cópia antiga vazia do Animate se ela tiver ficado salva no place.
local oldAnimate = StarterPlayer:FindFirstChild("StarterCharacterScripts")
	and StarterPlayer.StarterCharacterScripts:FindFirstChild("Animate")
if oldAnimate then
	oldAnimate:Destroy()
end

StoreService.init()

MatchService.init()
task.spawn(MatchService.run)
TornadoService.start()
PvpService.start()
require(script.Match.SkillService).start() -- Q: uma skill por forma
require(script.Match.DevCommands).start() -- comandos de chat de teste (só Studio ou dono do jogo)

-- Só no Studio: atalhos de teste (não existem no jogo publicado).
if RunService:IsStudio() then
	require(script.Match.DevBench).start() -- benchmark de casters simulados
	local gems = Instance.new("BindableFunction")
	gems.Name = "DevAddGems"
	gems.OnInvoke = function(player: Player, amount: number)
		PlayerData.addGems(player, amount)
		return player:GetAttribute("Gems")
	end
	gems.Parent = ServerStorage
end
