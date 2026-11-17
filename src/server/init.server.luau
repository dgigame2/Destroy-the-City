--!strict
-- Ponto de entrada do servidor do Eat City. O mesmo código roda nos dois lugares do jogo:
--   Lobby: loja, roleta, recompensas, classes e as parties (área START A RUN).
--   Run: a cidade da party (servidor reservado), com o crescimento, os upgrades e o salvamento da run.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Place = require(Shared.Place)
local MovementConfig = require(Shared.Config.MovementConfig)

local PlayerData = require(script.PlayerData)
local StoreService = require(script.StoreService)
local LightingService = require(script.LightingService)
local GrowthService = require(script.GrowthService)
local CosmeticService = require(script.CosmeticService)
local GeometryAudit = require(script.GeometryAudit)

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

-- Animação padrão do Roblox: o jogo antes trocava o Animate por um vazio (animações próprias). Se essa cópia
-- antiga ficou salva no lugar, ela é removida antes de qualquer personagem nascer.
local oldAnimate = StarterPlayer:FindFirstChild("StarterCharacterScripts")
	and StarterPlayer.StarterCharacterScripts:FindFirstChild("Animate")
if oldAnimate then
	oldAnimate:Destroy()
end

-- Loja, roleta, recompensas e classes respondem nos dois lugares (as gemas caem na run também).
StoreService.init()

if Place.isRun() then
	local MapService = require(script.MapService)
	local EatService = require(script.EatService)
	local UpgradeService = require(script.UpgradeService)
	local RunSession = require(script.RunSession)

	UpgradeService.init()
	require(script.StatsService).start() -- placar individual (Score, Damage, Destroyed, Chains)
	EatService.start()
	-- desastres (Fase 3); com GameplayConfig.Mode = "Eat" fica desligado e o comer antigo volta
	if require(ReplicatedStorage.Shared.Config.GameplayConfig).Mode == "Disasters" then
		require(script.DisasterService).start()
		require(script.MasteryService).start() -- nível de cada desastre
	end
	RunSession.init()
	PlayerData.init(function(player)
		player.CharacterAdded:Connect(function(character)
			RunSession.onCharacter(player, character)
		end)
		RunSession.onPlayerReady(player)
	end)
	GeometryAudit.startInStudio(function()
		local city = MapService.buildingsFolder()
		return city ~= nil and ReplicatedStorage:GetAttribute("RunState") ~= "Loading"
	end)
	task.spawn(RunSession.run)
else
	local LobbyService = require(script.LobbyService)
	local PartyService = require(script.PartyService)

	LobbyService.build()
	PartyService.init()
	PlayerData.init(function(player)
		local function onCharacter(character: Model)
			character:WaitForChild("HumanoidRootPart", 5)
			-- o Roblox posiciona o personagem logo depois do CharacterAdded; esperar evita que ele desfaça o teleporte
			task.wait(0.15)
			if character.Parent then
				GrowthService.onCharacter(player)
				CosmeticService.refresh(player)
				LobbyService.teleport(player)
			end
		end
		player.CharacterAdded:Connect(onCharacter)
		if player.Character then
			task.spawn(onCharacter, player.Character)
		end
	end)
	-- quem cair da ilha volta para ela
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root and LobbyService.isBelowLobby(root.Position) then
					LobbyService.teleport(player)
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		GrowthService.forget(player)
	end)
	GeometryAudit.startInStudio(function()
		return Workspace:FindFirstChild("Lobby") ~= nil
	end)
end

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
