--!strict
-- "Juice" do tornado do jogador local (só som e tremida; números e sons em Config/FeedbackConfig):
--   * quebrar perto de você: pop com o tom subindo na sequência; construção grande = estrondo grave
--   * XP saindo do tornado (somado), EVOLVE, REBIRTH, levar dano de outro tornado
--   * vento em loop que fica mais alto e mais grave com o nível

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FeedbackConfig = require(Shared.Config.FeedbackConfig)
local Shake = require(Shared.Logic.Shake)
local Tornado = require(Shared.Logic.Tornado)
local TornadoConfig = require(Shared.Config.TornadoConfig)

local Feedback = require(script.Parent.Parent.Feedback)
local CityClient = require(script.Parent.CityClient)

local TornadoJuice = {}

local cfg = TornadoConfig :: Tornado.Config
local J = FeedbackConfig.Tornado
local localPlayer = Players.LocalPlayer

local function level(): number
	return (localPlayer:GetAttribute("TornadoLevel") :: number?) or 1
end

local function root(): BasePart?
	local character = localPlayer.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- tornado maior treme mais (raiz: no nível 30 fica ~3x, não 8x)
local function strength(): number
	return math.sqrt(Tornado.radius(cfg, level()) / Tornado.radius(cfg, 1))
end

local function above(part: BasePart): Vector3
	local lv = level()
	local form = cfg.Forms[Tornado.form(cfg, lv)]
	return part.Position + Vector3.new(0, Tornado.radius(cfg, lv) * form.Height * 0.6, 0)
end

local streak, streakAt = 0, -math.huge

local function onDestroyed(id: number, position: Vector3)
	local me = root()
	if me == nil then
		return
	end
	local reach = Tornado.radius(cfg, level()) * J.HearReach + J.HearMargin
	local flat = Vector3.new(position.X - me.Position.X, 0, position.Z - me.Position.Z)
	if flat.Magnitude > reach then
		return
	end
	local now = os.clock()
	streak = Shake.streak(streak, streakAt, now, J.StreakWindow)
	streakAt = now
	local _, height = CityClient.site(id)
	local kind = if height >= J.BigHeight then "Crash" else "Smash"
	Feedback.play(kind, {
		World = position,
		NoNumber = true,
		Pitch = Shake.streakPitch(streak, J.StreakStep, J.StreakCap),
		Strength = strength(),
	})
end

local function startWind()
	local wind = Instance.new("Sound")
	wind.Name = "TornadoWind"
	wind.SoundId = J.WindId
	wind.Looped = true
	wind.Parent = SoundService
	local function tune()
		local l = level()
		wind.Volume = math.min(J.WindVolume.Base + J.WindVolume.Step * (l - 1), J.WindVolume.Max)
		wind.PlaybackSpeed = math.max(J.WindPitch.Base + J.WindPitch.Step * (l - 1), J.WindPitch.Min)
	end
	tune()
	wind:Play()
	localPlayer:GetAttributeChangedSignal("TornadoLevel"):Connect(tune)
end

function TornadoJuice.init()
	CityClient.onDestroyed(onDestroyed)
	startWind()

	local lastXp = (localPlayer:GetAttribute("TornadoXp") :: number?) or 0
	localPlayer:GetAttributeChangedSignal("TornadoXp"):Connect(function()
		local xp = (localPlayer:GetAttribute("TornadoXp") :: number?) or 0
		local gain = xp - lastXp
		lastXp = xp
		local me = root()
		if gain > 0 and me then -- caiu = evoluiu ou morreu: sem número
			Feedback.play("Xp", { World = above(me), Amount = gain })
		end
	end)

	local lastLevel = level()
	localPlayer:GetAttributeChangedSignal("TornadoLevel"):Connect(function()
		local now = level()
		local me = root()
		if now > lastLevel and me then
			Feedback.play("Evolve", { World = above(me), Amount = now, Strength = strength() })
		end
		lastLevel = now
	end)

	local lastRebirths = (localPlayer:GetAttribute("Rebirths") :: number?) or 0
	localPlayer:GetAttributeChangedSignal("Rebirths"):Connect(function()
		local now = (localPlayer:GetAttribute("Rebirths") :: number?) or 0
		local me = root()
		if now > lastRebirths and me then
			Feedback.play("Rebirth", { World = above(me), Amount = now, Strength = 1.5 })
		end
		lastRebirths = now
	end)

	-- dano = Hp caiu com o MaxHp igual (mudar de nível mexe nos dois e não é dano)
	local lastHp = (localPlayer:GetAttribute("Hp") :: number?) or 0
	local lastMax = (localPlayer:GetAttribute("MaxHp") :: number?) or 0
	localPlayer:GetAttributeChangedSignal("Hp"):Connect(function()
		local hp = (localPlayer:GetAttribute("Hp") :: number?) or 0
		local max = (localPlayer:GetAttribute("MaxHp") :: number?) or 0
		local me = root()
		if hp < lastHp and max == lastMax and me then
			Feedback.play("Hurt", { World = above(me), Amount = lastHp - hp })
		end
		lastHp, lastMax = hp, max
	end)
end

return TornadoJuice
