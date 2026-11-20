--!strict
-- Teleporte entre os dois lugares do jogo. No Studio o Roblox não teleporta: devolve false + motivo.

local AssetService = game:GetService("AssetService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local PlaceConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.PlaceConfig)

local Teleporter = {}

-- Ids dos lugares: os do PlaceConfig ou, com 0, descobertos pela lista de lugares da experiência
-- (o lugar chamado PlaceConfig.RunPlaceName é a run; o outro é o lobby).
local resolved: { Lobby: number, Run: number }? = nil

local function placeIds(): { Lobby: number, Run: number }
	if resolved then
		return resolved
	end
	local ids = { Lobby = PlaceConfig.LobbyPlaceId, Run = PlaceConfig.RunPlaceId }
	if ids.Lobby == 0 or ids.Run == 0 then
		local ok, err = pcall(function()
			local pages = AssetService:GetGamePlacesAsync()
			while true do
				for _, place in pages:GetCurrentPage() do
					if place.Name == PlaceConfig.RunPlaceName then
						ids.Run = if ids.Run == 0 then place.PlaceId else ids.Run
					elseif ids.Lobby == 0 then
						ids.Lobby = place.PlaceId
					end
				end
				if pages.IsFinished then
					break
				end
				pages:AdvanceToNextPageAsync()
			end
		end)
		if not ok then
			warn("[Teleporter] could not list the experience places:", err)
			return ids -- tenta de novo na próxima vez
		end
	end
	if ids.Lobby ~= 0 and ids.Run ~= 0 then
		resolved = ids
	end
	return ids
end

local function available(placeId: number): (boolean, string?)
	if RunService:IsStudio() then
		return false, "Teleport only works in the published game"
	end
	if placeId == 0 then
		return false, "The Run place was not found in this experience"
	end
	return true, nil
end

-- Dá para teleportar para a run agora? (false no Studio ou sem o lugar Run.)
function Teleporter.available(): (boolean, string?)
	return available(placeIds().Run)
end

-- Leva a party para um servidor novo e reservado do lugar Run, carregando a run `runId`.
function Teleporter.toRun(players: { Player }, runId: string): (boolean, string?)
	local runPlace = placeIds().Run
	local ok, why = available(runPlace)
	if not ok then
		return false, why
	end
	local reserved, code = pcall(function()
		return TeleportService:ReserveServer(runPlace)
	end)
	if not reserved then
		warn("[Teleporter] ReserveServer failed:", code)
		return false, "Could not reserve a server"
	end
	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = code :: string
	options:SetTeleportData({ RunId = runId })
	local sent, err = pcall(function()
		TeleportService:TeleportAsync(runPlace, players, options)
	end)
	if not sent then
		warn("[Teleporter] TeleportAsync failed:", err)
		return false, "Teleport failed"
	end
	return true, nil
end

function Teleporter.toLobby(players: { Player }): (boolean, string?)
	local lobbyPlace = placeIds().Lobby
	local ok, why = available(lobbyPlace)
	if not ok then
		return false, why
	end
	local sent, err = pcall(function()
		TeleportService:TeleportAsync(lobbyPlace, players)
	end)
	if not sent then
		warn("[Teleporter] TeleportAsync failed:", err)
		return false, "Teleport failed"
	end
	return true, nil
end

-- Qual run este servidor deve carregar (vem no teleporte do lobby).
function Teleporter.runIdOf(player: Player): string?
	local ok, data = pcall(function()
		return player:GetJoinData().TeleportData
	end)
	if ok and type(data) == "table" and type(data.RunId) == "string" then
		return data.RunId
	end
	return nil
end

return Teleporter
