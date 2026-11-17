--!strict
-- Nível de cada desastre na run (Logic/Mastery, Config/MasteryConfig). Substitui os contratos.
-- O DisasterService avisa cada construção derrubada (record) e pergunta o nível na hora de lançar (level).
-- Estado para o cliente: atributo JSON "Mastery" no jogador = [{Id, Level, Progress}] na ordem do DisasterConfig.
-- Subiu de nível: DisasterLevelUp (servidor -> dono) com (id, nível).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Mastery = require(Shared.Logic.Mastery)
local MasteryConfig = require(Shared.Config.MasteryConfig)
local DisasterConfig = require(Shared.Config.DisasterConfig)
local Remotes = require(Shared.Remotes)

local MasteryService = {}

local states: { [Player]: { [string]: Mastery.Entry } } = {}
local dirty: { [Player]: boolean } = {}
local PUBLISH_EVERY = 0.25 -- a barra de XP atualiza no máximo 4x por segundo (o tornado derruba muito por tique)

local function stateOf(player: Player): { [string]: Mastery.Entry }
	local state = states[player]
	if state == nil then
		local created = {}
		for _, d in DisasterConfig.List do
			created[d.Id] = Mastery.new()
		end
		states[player] = created
		state = created
	end
	return state :: { [string]: Mastery.Entry }
end

local function publish(player: Player)
	local state = stateOf(player)
	local list = {}
	for _, d in DisasterConfig.List do
		local entry = state[d.Id]
		table.insert(list, { Id = d.Id, Level = entry.Level, Progress = Mastery.progress(entry, MasteryConfig) })
	end
	player:SetAttribute("Mastery", HttpService:JSONEncode(list))
end

-- Nível atual do desastre para o jogador (1 se nunca usou).
function MasteryService.level(player: Player, id: string): number
	local entry = stateOf(player)[id]
	return if entry then entry.Level else 1
end

-- Construção derrubada por `id` (chain = caiu na reação em cadeia que esse desastre começou).
-- `xpMultiplier` = upgrade XP (GrowthService.multiplier "Xp").
function MasteryService.record(player: Player, id: string, tier: number, chain: boolean, xpMultiplier: number)
	local entry = stateOf(player)[id]
	if entry == nil or player.Parent == nil then
		return
	end
	local gained = Mastery.add(entry, Mastery.xp(tier, chain, MasteryConfig) * xpMultiplier, MasteryConfig)
	if gained > 0 then
		dirty[player] = nil
		publish(player)
		Remotes.event(Remotes.Names.Events.DisasterLevelUp):FireClient(player, id, entry.Level)
	else
		dirty[player] = true
	end
end

function MasteryService.start()
	Players.PlayerAdded:Connect(publish)
	for _, player in Players:GetPlayers() do
		publish(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
		dirty[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(PUBLISH_EVERY)
			for player in dirty do
				dirty[player] = nil
				if player.Parent then
					publish(player)
				end
			end
		end
	end)
end

return MasteryService
