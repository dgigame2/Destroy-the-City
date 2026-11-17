--!strict
-- Placar individual da run (Logic/RunStats). Cada jogador tem as próprias estatísticas, mostradas na lista
-- de jogadores do Roblox (leaderstats): Score, Damage, Destroyed, Chains. Também ficam como atributos
-- "Stat_<coluna>" no jogador (UI e fim da run).
-- Sem duplicação: o dano vem de StructureHealth.hitDealt (nunca passa da vida que sobrava) e cada construção
-- só conta "Destroyed"/Score para quem deu o golpe final (MapService.consume / StructureHealth).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RunStats = require(Shared.Logic.RunStats)

local StatsService = {}

local stats: { [Player]: RunStats.Stats } = {}
local dirty: { [Player]: boolean } = {}

local function folderOf(player: Player): Folder
	local folder = player:FindFirstChild("leaderstats") :: Folder?
	if folder == nil then
		local created = Instance.new("Folder")
		created.Name = "leaderstats"
		-- a ordem de criação é a ordem das colunas (a primeira ordena a lista)
		for _, column in RunStats.Columns do
			local value = Instance.new("IntValue")
			value.Name = column
			value.Parent = created
		end
		created.Parent = player
		folder = created
	end
	return folder :: Folder
end

local function of(player: Player): RunStats.Stats
	local entry = stats[player]
	if entry == nil then
		entry = RunStats.new()
		stats[player] = entry
		folderOf(player)
	end
	return entry
end

-- Escreve no placar no máximo ~5x por segundo (dano chega a cada tique de desastre).
local function flush(player: Player)
	local entry = stats[player]
	if entry == nil or player.Parent == nil then
		return
	end
	local folder = folderOf(player)
	for _, column in RunStats.Columns do
		local value = folder:FindFirstChild(column) :: IntValue?
		local shown = RunStats.display(entry, column)
		if value and value.Value ~= shown then
			value.Value = shown
		end
		player:SetAttribute("Stat_" .. column, shown)
	end
end

local function touch(player: Player)
	if dirty[player] then
		return
	end
	dirty[player] = true
	task.delay(0.2, function()
		dirty[player] = nil
		flush(player)
	end)
end

function StatsService.addDamage(player: Player, dealt: number)
	RunStats.addDamage(of(player), dealt)
	touch(player)
end

function StatsService.addDestroy(player: Player, points: number)
	RunStats.addDestroy(of(player), points)
	touch(player)
end

function StatsService.addChain(player: Player)
	RunStats.addChain(of(player))
	touch(player)
end

function StatsService.get(player: Player): RunStats.Stats
	return table.clone(of(player))
end

function StatsService.start()
	Players.PlayerAdded:Connect(of)
	for _, player in Players:GetPlayers() do
		of(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		stats[player] = nil
		dirty[player] = nil
	end)
end

return StatsService
