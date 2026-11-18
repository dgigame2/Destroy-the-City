--!strict
-- Ponto de entrada do cliente do Eat City (o mesmo nos dois lugares; cada um liga só o que usa).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Place = require(ReplicatedStorage:WaitForChild("Shared").Place)

local Feedback = require(script.Feedback)
local EatEffects = require(script.Controllers.EatEffects)
local InterfaceController = require(script.Controllers.InterfaceController)
local ShopController = require(script.Controllers.ShopController)
local WheelController = require(script.Controllers.WheelController)
local RewardsController = require(script.Controllers.RewardsController)
local CameraController = require(script.Controllers.CameraController)
local MovementController = require(script.Controllers.MovementController)

Feedback.init()
EatEffects.init()
InterfaceController.init()
ShopController.init()
WheelController.init()
RewardsController.init()
CameraController.init()
MovementController.init()

if Place.isRun() then
	require(script.Controllers.UpgradesController).init()
	-- desastres (Fase 3) ou comer antigo (rollback: GameplayConfig.Mode = "Eat")
	if require(ReplicatedStorage.Shared.Config.GameplayConfig).Mode == "Disasters" then
		require(script.Controllers.DisasterController).init()
		require(script.Controllers.DisasterVfx).init()
		require(script.Controllers.DamageVfx).init() -- barra de vida, blocos caindo e destroços
		require(script.Controllers.LevelsController).init() -- nível de cada desastre
		require(script.Controllers.BurstController).init() -- resumo por golpe ("MASSIVE! 23 DESTROYED")
	else
		require(script.Controllers.EatIndicator).init()
	end
	require(script.Controllers.ZoneController).init()
	require(script.Controllers.AmbienceController).init()
	require(script.Controllers.AreaSignsController).init()
else
	require(script.Controllers.LobbyController).init()
	require(script.Controllers.PartyController).init()
	require(script.Controllers.FountainController).init() -- água animada da fonte
	require(script.Controllers.NoclipController).init() -- /noclip (só admins e Studio)
end
