--!strict
-- Qual lugar do jogo está rodando: "Lobby" (parties, loja) ou "Run" (a cidade).
-- Vem do Rojo (ReplicatedStorage.PlaceRole): default.project.json = Lobby, run.project.json = Run.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Place = {}

function Place.role(): string
	local value = ReplicatedStorage:FindFirstChild("PlaceRole")
	if value and value:IsA("StringValue") and value.Value == "Run" then
		return "Run"
	end
	return "Lobby"
end

function Place.isRun(): boolean
	return Place.role() == "Run"
end

return Place
