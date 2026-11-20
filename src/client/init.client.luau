--!strict
-- Ponto de entrada do cliente do Eat City (o mesmo nos dois lugares; cada um liga só o que usa).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Place = require(ReplicatedStorage:WaitForChild("Shared").Place)

local Feedback = require(script.Feedback)

local InterfaceController = require(script.Controllers.InterfaceController)
local ShopController = require(script.Controllers.ShopController)
local RewardsController = require(script.Controllers.RewardsController)
local CameraController = require(script.Controllers.CameraController)
local MovementController = require(script.Controllers.MovementController)

Feedback.init()

InterfaceController.init()
ShopController.init()
RewardsController.init()
CameraController.init()
MovementController.init()

if Place.isRun() then
	-- partida: a cidade é montada AQUI pela semente; do servidor só chegam dados (ids + vida)
	require(script.City.CityClient).init()
	require(script.City.ElementInput).init()
	require(script.City.ElementFx).init()
	require(script.City.ElementCasts).init() -- golpes por nível (plano igual ao do servidor)
	require(script.Controllers.AmbienceController).init()
else
	require(script.Controllers.LobbyController).init()
	require(script.Controllers.PartyController).init()
	require(script.Controllers.FountainController).init() -- água animada da fonte
end
