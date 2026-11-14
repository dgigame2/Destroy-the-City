--!strict
-- Ponto de entrada do cliente do Eat City.

local EatEffects = require(script.Controllers.EatEffects)
local InterfaceController = require(script.Controllers.InterfaceController)
local ShopController = require(script.Controllers.ShopController)
local WheelController = require(script.Controllers.WheelController)
local RewardsController = require(script.Controllers.RewardsController)
local LobbyController = require(script.Controllers.LobbyController)
local CameraController = require(script.Controllers.CameraController)
local AnimationController = require(script.Controllers.AnimationController)

EatEffects.init()
InterfaceController.init()
ShopController.init()
WheelController.init()
RewardsController.init()
LobbyController.init()
CameraController.init()
AnimationController.init()
