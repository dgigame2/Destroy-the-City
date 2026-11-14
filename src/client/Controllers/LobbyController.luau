--!strict
-- Lobby: estações (ProximityPrompts) abrem as janelas e o botão SPECTATE acompanha quem está jogando.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Workspace = game:GetService("Workspace")

local InterfaceController = require(script.Parent.InterfaceController)
local ShopController = require(script.Parent.ShopController)

local localPlayer = Players.LocalPlayer

local LobbyController = {}

local spectatingIndex = 0

local function matchPlayers(): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		if player ~= localPlayer and player:GetAttribute("InMatch") and player.Character then
			table.insert(list, player)
		end
	end
	return list
end

local function stopSpectating()
	spectatingIndex = 0
	local refs = InterfaceController.refs()
	refs.SpectatingLabel.Visible = false
	refs.SpectateText.Text = "👁 SPECTATE"
	local humanoid = localPlayer.Character and localPlayer.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		Workspace.CurrentCamera.CameraSubject = humanoid
	end
end

-- Cada clique vai para o próximo jogador da partida; depois do último, volta para você.
local function nextTarget()
	local refs = InterfaceController.refs()
	local list = matchPlayers()
	if #list == 0 then
		stopSpectating()
		InterfaceController.toast("NOBODY IS PLAYING RIGHT NOW", Color3.fromRGB(255, 227, 107))
		return
	end
	spectatingIndex += 1
	if spectatingIndex > #list then
		stopSpectating()
		return
	end
	local target = list[spectatingIndex]
	local humanoid = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		Workspace.CurrentCamera.CameraSubject = humanoid
		refs.SpectatingLabel.Text = "SPECTATING " .. target.DisplayName:upper()
		refs.SpectatingLabel.Visible = true
		refs.SpectateText.Text = "NEXT ▶"
	end
end

function LobbyController.init()
	local refs = InterfaceController.refs()
	refs.Spectate.Activated:Connect(nextTarget)
	refs.Play.Activated:Connect(stopSpectating)
	-- ao entrar na partida, a câmera volta para o próprio personagem
	localPlayer:GetAttributeChangedSignal("InMatch"):Connect(function()
		if localPlayer:GetAttribute("InMatch") then
			stopSpectating()
		end
	end)
	localPlayer.CharacterAdded:Connect(function()
		spectatingIndex = 0
		refs.SpectatingLabel.Visible = false
		refs.SpectateText.Text = "👁 SPECTATE"
	end)

	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt.Name == "OpenShop" then
			ShopController.openTab("ITEMS")
		elseif prompt.Name == "OpenClasses" then
			ShopController.openTab("CLASSES")
		elseif prompt.Name == "OpenWheel" then
			InterfaceController.open("Wheel")
		elseif prompt.Name == "OpenRewards" then
			InterfaceController.open("Rewards")
		end
	end)
end

return LobbyController
