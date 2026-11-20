--!strict
-- Tier de qualidade DESTE cliente (Low / Medium / High; Config/QualityConfig, Logic/Quality.pick).
-- Começa pelo aparelho (toque sem teclado = Low) e, no PC, mede o FPS nos primeiros SampleSeconds: abaixo de
-- LowFps cai para Low. A escolha do jogador (atributo "QualityChoice" no Player, menu da Etapa 9) vence.
-- Quem usa: LodManager (distâncias), WreckPresenter (desabamentos e pedaços), ElementFx (partículas e tetos).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local QualityConfig = require(Shared.Config.QualityConfig)
local Quality = require(Shared.Logic.Quality)

local QualityTier = {}

local localPlayer = Players.LocalPlayer
local currentName = QualityConfig.Default
local avgFps: number? = nil
local listeners: { (QualityConfig.Tier) -> () } = {}
local started = false

local function choose()
	local chosen = localPlayer:GetAttribute("QualityChoice")
	local name = Quality.pick(
		UserInputService.TouchEnabled,
		UserInputService.KeyboardEnabled,
		avgFps,
		if type(chosen) == "string" then chosen else nil,
		QualityConfig
	)
	if name ~= currentName then
		currentName = name
		local tier = QualityConfig.Tiers[name]
		for _, callback in listeners do
			task.spawn(callback, tier)
		end
	end
end

function QualityTier.current(): QualityConfig.Tier
	return QualityConfig.Tiers[currentName]
end

function QualityTier.onChanged(callback: (QualityConfig.Tier) -> ())
	table.insert(listeners, callback)
end

function QualityTier.init()
	if started then
		return
	end
	started = true
	choose()
	localPlayer:GetAttributeChangedSignal("QualityChoice"):Connect(choose)
	-- mede o FPS médio nos primeiros segundos (só conta frames, sem custo)
	local frames, elapsed = 0, 0
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function(dt)
		frames += 1
		elapsed += dt
		if elapsed >= QualityConfig.SampleSeconds then
			connection:Disconnect()
			avgFps = frames / elapsed
			choose()
		end
	end)
end

return QualityTier
