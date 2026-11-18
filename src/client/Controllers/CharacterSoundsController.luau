--!strict
-- Sem som de passos, pulo, queda e afins: o Roblox cria esses sons no HumanoidRootPart (e no Play troca o
-- RbxCharacterSounds pelo dele, então não basta substituir o script). Aqui eles ficam com volume 0 em todos
-- os personagens, e voltam a 0 se o script do Roblox mexer no volume (AudioConfig.MutedCharacterSounds).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AudioConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.AudioConfig)

local CharacterSoundsController = {}

local MUTED: { [string]: boolean } = {}
for _, name in AudioConfig.MutedCharacterSounds do
	MUTED[name] = true
end

local function mute(sound: Instance)
	if sound:IsA("Sound") and MUTED[sound.Name] then
		sound.Volume = 0
		sound:GetPropertyChangedSignal("Volume"):Connect(function()
			if sound.Volume ~= 0 then
				sound.Volume = 0
			end
		end)
	end
end

local function watch(character: Model)
	for _, d in character:GetDescendants() do
		mute(d)
	end
	character.DescendantAdded:Connect(mute)
end

local function onPlayer(player: Player)
	if player.Character then
		watch(player.Character)
	end
	player.CharacterAdded:Connect(watch)
end

function CharacterSoundsController.init()
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerAdded:Connect(onPlayer)
end

return CharacterSoundsController
