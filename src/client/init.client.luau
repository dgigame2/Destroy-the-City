--!strict
-- Ponto de entrada do cliente do Disaster Evolution (um place só: a cidade).

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

-- a cidade é montada AQUI pela semente; do servidor só chegam dados (ids + vida)
require(script.City.CityClient).init()
require(script.City.TornadoClient).init() -- o jogador é o tornado (visual, colisão e barra de XP)
require(script.City.PvpClient).init() -- rajada, Q, vida e escudo (o servidor decide)
require(script.City.SkillFx).init() -- efeitos das skills (Q) de todos
require(script.City.TornadoJuice).init() -- som e tremida do seu tornado (quebrar, XP, evoluir, dano)
require(script.City.DeathScreen).init() -- "você estava a X% do próximo nível" e comemoração de quem matou
require(script.City.ElementFx).init()
require(script.City.ElementCasts).init() -- golpes por nível (plano igual ao do servidor)
require(script.Controllers.AmbienceController).init()
