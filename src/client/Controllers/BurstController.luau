--!strict
-- Resumo por golpe: soma tudo que VOCÊ derrubou numa leva (desastre + cadeia + destroços) e, quando a leva
-- acaba, mostra um aviso só no lugar do combo ("MASSIVE! 23 DESTROYED") com o dinheiro somado e o feedback
-- triplo "Burst" (som + tremor + número). Golpe pequeno não mostra nada (o combo já basta).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Burst = require(Shared.Logic.Burst)
local BurstConfig = require(Shared.Config.BurstConfig)
local Remotes = require(Shared.Remotes)

local Feedback = require(script.Parent.Parent.Feedback)
local InterfaceController = require(script.Parent.InterfaceController)

local localPlayer = Players.LocalPlayer

local BurstController = {}

local state = Burst.new()

local function show(count: number, coins: number)
	local tier = Burst.tier(count, BurstConfig)
	if tier == nil then
		return
	end
	local c = tier.Color
	InterfaceController.bigCombo(`{tier.Text} {count} DESTROYED`, Color3.fromRGB(c[1], c[2], c[3]))
	Feedback.play("Burst", { Gui = InterfaceController.refs().Combo, Amount = coins })
end

function BurstController.init()
	Remotes.event(Remotes.Names.Events.BuildingDestroyed).OnClientEvent
		:Connect(function(_model: Model?, destroyer: Player, coins: number)
			if destroyer == localPlayer then
				Burst.add(state, coins or 0, os.clock())
			end
		end)
	RunService.Heartbeat:Connect(function()
		local count, coins = Burst.flush(state, os.clock(), BurstConfig)
		if count > 0 then
			show(count, coins)
		end
	end)
end

return BurstController
