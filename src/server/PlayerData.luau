--!strict
-- Estado de cada jogador.
-- Salvos na conta (DataStore): tornado (nível, XP, rebirths), gemas, vitórias, cosméticos, equipados e recompensas.
-- Segurança do save (fwjelaa-datastore-safety): UpdateAsync com trava de sessão (Logic/Lease), save só de quem
-- carregou com sucesso (load que falhou NUNCA grava por cima do save real), schema versionado, Studio em store separado.
-- Dinheiro (Coins) é DA PARTIDA: zera em toda partida e nunca vai para a conta.
-- Campos de saves antigos (roleta, boosts, runs salvas, classes) são ignorados ao carregar e somem no próximo save.
-- O cliente recebe tudo o que precisa mostrar por atributos do Player.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EconomyConfig = require(Shared.Config.EconomyConfig)
local TornadoConfig = require(Shared.Config.TornadoConfig)
local Lease = require(Shared.Logic.Lease)
local Tornado = require(Shared.Logic.Tornado)

local IS_STUDIO = RunService:IsStudio()
-- Studio grava em outro store: teste nunca mexe no save dos jogadores de verdade.
local STORE_NAME = if IS_STUDIO then "DisasterEvolution_PlayerData_Studio" else "DisasterEvolution_PlayerData_v1"
local SCHEMA = 2 -- 1 = saves sem Schema (base antiga); 2 = + tornado. Save com Schema maior é recusado.
local MAX_RECEIPTS = 50
local LEASE_SECONDS = 90 -- menos de ~30 s é inseguro (relógio dos servidores)
local AUTOSAVE_SECONDS = 30 -- no máximo LEASE / 3 (o autosave também renova a trava)
local CLAIM_ATTEMPTS = 6 -- 6 x 1,5 s = ~7,5 s esperando outro servidor soltar o save
local CLAIM_RETRY_SECONDS = 1.5
local SAVE_ATTEMPTS = 3
local SHUTDOWN_DEADLINE = 25 -- o servidor espera no máximo 30 s no BindToClose

export type Data = {
	Coins: number,
	Gems: number,
	Owned: { [string]: boolean }, -- itens e classes comprados/ganhos
	Equipped: { [string]: string }, -- Trail, Aura -> id
	Daily: { LastDay: number, Streak: number },
	Weekly: { LastWeek: number },
	Receipts: { string }, -- compras com Robux já entregues (evita entregar duas vezes)
	Wins: number, -- cidades comidas inteiras (liberam capítulos e dificuldades)
	Points: number, -- da run, não vai para a conta
	Level: number, -- tornado
	Xp: number, -- XP na barra do nível atual
	Rebirths: number,
}

local PlayerData = {}

local data: { [Player]: Data } = {}
-- Token da trava de quem carregou com sucesso. Sem token = sem save (load falhou ou trava perdida).
local tokens: { [Player]: string } = {}
local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[PlayerData] DataStore unavailable (publish the place and enable Studio API access to save):", result)
	end
end

local function fresh(): Data
	return {
		Coins = EconomyConfig.StartingCoins,
		Gems = 0,
		Owned = {},
		Equipped = {},
		Daily = { LastDay = -1, Streak = 0 },
		Weekly = { LastWeek = -1 },
		Receipts = {},
		Wins = 0,
		Points = 0,
		Level = 1,
		Xp = 0,
		Rebirths = 0,
	}
end

-- Copia só campos conhecidos do que veio salvo (dados antigos ou corrompidos não quebram o jogo).
local function merge(entry: Data, saved: any)
	if type(saved) ~= "table" then
		return
	end
	entry.Gems = tonumber(saved.Gems) or entry.Gems
	entry.Level, entry.Xp, entry.Rebirths =
		Tornado.sanitize(TornadoConfig :: Tornado.Config, saved.Level, saved.Xp, saved.Rebirths)
	entry.Wins = math.max(0, math.floor(tonumber(saved.Wins) or 0))
	if type(saved.Owned) == "table" then
		for id, owned in saved.Owned do
			if type(id) == "string" and owned == true then
				entry.Owned[id] = true
			end
		end
	end
	if type(saved.Equipped) == "table" then
		for slot, id in saved.Equipped do
			if (slot == "Trail" or slot == "Aura") and type(id) == "string" then
				entry.Equipped[slot] = id
			end
		end
	end
	if type(saved.Daily) == "table" then
		entry.Daily.LastDay = tonumber(saved.Daily.LastDay) or -1
		entry.Daily.Streak = tonumber(saved.Daily.Streak) or 0
	end
	if type(saved.Weekly) == "table" then
		entry.Weekly.LastWeek = tonumber(saved.Weekly.LastWeek) or -1
	end
	if type(saved.Receipts) == "table" then
		for _, receipt in saved.Receipts do
			if type(receipt) == "string" then
				table.insert(entry.Receipts, receipt)
			end
		end
	end
end

-- Publica para o cliente (atributos). Tabelas viram JSON.
function PlayerData.publish(player: Player)
	local entry = data[player]
	if entry == nil then
		return
	end
	player:SetAttribute("Coins", entry.Coins)
	player:SetAttribute("Gems", entry.Gems)
	player:SetAttribute("Owned", HttpService:JSONEncode(entry.Owned))
	player:SetAttribute("EquippedTrail", entry.Equipped.Trail or "")
	player:SetAttribute("EquippedAura", entry.Equipped.Aura or "")
	player:SetAttribute("DailyLastDay", entry.Daily.LastDay)
	player:SetAttribute("DailyStreak", entry.Daily.Streak)
	player:SetAttribute("WeeklyLastWeek", entry.Weekly.LastWeek)
	player:SetAttribute("Wins", entry.Wins)
	player:SetAttribute("TornadoLevel", entry.Level)
	player:SetAttribute("TornadoXp", entry.Xp)
	player:SetAttribute("Rebirths", entry.Rebirths)
end

local function keyOf(player: Player): string
	return tostring(player.UserId)
end

-- Erro que não adianta repetir (Studio sem acesso à API, sem permissão).
local function permanent(err: any): boolean
	local text = tostring(err)
	return text:find("NotAllowed") ~= nil or text:find("403") ~= nil
end

type LoadStatus = "ready" | "locked" | "newer" | "failed"

-- Lê o save e trava a sessão no MESMO UpdateAsync. "ready" com saved == nil = jogador novo de verdade.
local function claim(player: Player, token: string): (LoadStatus, any)
	local status: LoadStatus, saved: any = "failed", nil
	for attempt = 1, CLAIM_ATTEMPTS do
		local now = os.time()
		local ok, err = pcall(function()
			(store :: DataStore):UpdateAsync(keyOf(player), function(old: any, keyInfo: DataStoreKeyInfo?)
				-- sem yield aqui dentro
				if type(old) == "table" and (tonumber(old.Schema) or 1) > SCHEMA then
					status = "newer"
					return nil
				end
				if type(old) == "table" and not Lease.canClaim(old.Session, token, now) then
					status = "locked"
					return nil
				end
				status, saved = "ready", old
				local new = if type(old) == "table" then table.clone(old) else {}
				new.Session = Lease.new(token, game.JobId, now, LEASE_SECONDS)
				return new, { player.UserId }, keyInfo and keyInfo:GetMetadata()
			end)
		end)
		if not ok then
			status = "failed"
			warn("[PlayerData] failed to load", player.Name, err)
			if permanent(err) then
				break
			end
		elseif status ~= "locked" then
			break
		end
		if attempt < CLAIM_ATTEMPTS and player.Parent then
			task.wait(CLAIM_RETRY_SECONDS)
		end
	end
	return status, saved
end

-- Grava o save (e renova ou solta a trava). Só grava se a trava ainda é deste servidor.
local function write(player: Player, release: boolean): boolean
	local entry, token = data[player], tokens[player]
	if entry == nil or token == nil or store == nil then
		return false
	end
	local snapshot = table.clone(entry) :: any
	-- dinheiro é da partida (zera em toda partida); campos antigos de saves velhos saem
	snapshot.Points = nil
	snapshot.Coins = nil
	snapshot.Upgrades = nil -- saves antigos
	snapshot.Schema = SCHEMA
	snapshot.Session = if release then nil else Lease.new(token, game.JobId, os.time(), LEASE_SECONDS)
	for attempt = 1, SAVE_ATTEMPTS do
		local lost = false
		local ok, err = pcall(function()
			(store :: DataStore):UpdateAsync(keyOf(player), function(old: any, keyInfo: DataStoreKeyInfo?)
				if type(old) ~= "table" or not Lease.owns(old.Session, token) then
					lost = true
					return nil
				end
				return snapshot, { player.UserId }, keyInfo and keyInfo:GetMetadata()
			end)
		end)
		if ok and lost then
			-- outro servidor pegou o save: este para de gravar para sempre
			tokens[player] = nil
			warn("[PlayerData] lost the session lock for", player.Name)
			player:Kick("Your progress was opened on another server. Please rejoin.")
			return false
		end
		if ok then
			if release then
				tokens[player] = nil
			end
			return true
		end
		warn("[PlayerData] failed to save", player.Name, err)
		if permanent(err) then
			break
		end
		if attempt < SAVE_ATTEMPTS then
			task.wait(0.5 * 2 ^ attempt + math.random())
		end
	end
	return false
end

function PlayerData.save(player: Player): boolean
	return write(player, false)
end

function PlayerData.get(player: Player): Data?
	return data[player]
end

function PlayerData.addCoins(player: Player, amount: number)
	local entry = data[player]
	if entry then
		entry.Coins += amount
		player:SetAttribute("Coins", entry.Coins)
	end
end

function PlayerData.spend(player: Player, amount: number): boolean
	local entry = data[player]
	if entry == nil or entry.Coins < amount then
		return false
	end
	entry.Coins -= amount
	player:SetAttribute("Coins", entry.Coins)
	return true
end

function PlayerData.addGems(player: Player, amount: number)
	local entry = data[player]
	if entry then
		entry.Gems += amount
		player:SetAttribute("Gems", entry.Gems)
	end
end

function PlayerData.spendGems(player: Player, amount: number): boolean
	local entry = data[player]
	if entry == nil or entry.Gems < amount then
		return false
	end
	entry.Gems -= amount
	player:SetAttribute("Gems", entry.Gems)
	return true
end

-- Dinheiro da partida deste jogador (zera em toda partida nova: slots e poderes não são permanentes).
function PlayerData.setRunState(player: Player, coins: number)
	local entry = data[player]
	if entry == nil then
		return
	end
	entry.Coins = coins
	PlayerData.publish(player)
end

-- Progresso do tornado (só o TornadoService chama). Atualiza o save e os atributos que o cliente lê.
function PlayerData.setTornado(player: Player, level: number, xp: number, rebirths: number)
	local entry = data[player]
	if entry == nil then
		return
	end
	entry.Level, entry.Xp, entry.Rebirths = level, xp, rebirths
	player:SetAttribute("TornadoLevel", level)
	player:SetAttribute("TornadoXp", xp)
	player:SetAttribute("Rebirths", rebirths)
end

function PlayerData.addWin(player: Player)
	local entry = data[player]
	if entry then
		entry.Wins += 1
		player:SetAttribute("Wins", entry.Wins)
	end
end

-- Marca uma compra com Robux como entregue. Retorna false se já tinha sido entregue.
function PlayerData.markReceipt(player: Player, receiptId: string): boolean
	local entry = data[player]
	if entry == nil or table.find(entry.Receipts, receiptId) then
		return false
	end
	table.insert(entry.Receipts, receiptId)
	while #entry.Receipts > MAX_RECEIPTS do
		table.remove(entry.Receipts, 1)
	end
	return true
end

-- Chamado antes de salvar quem está saindo (ou todo mundo, quando o servidor fecha).
-- A run usa para guardar o próprio estado e atualizar a lista de runs salvas antes da conta ser salva.
local beforeSave: (({ Player }) -> ())? = nil

function PlayerData.beforeSave(callback: ({ Player }) -> ())
	beforeSave = callback
end

local function runBeforeSave(players: { Player })
	if beforeSave then
		local ok, err = pcall(beforeSave, players)
		if not ok then
			warn("[PlayerData] beforeSave failed:", err)
		end
	end
end

local function autosave(player: Player)
	task.wait(math.random() * AUTOSAVE_SECONDS) -- espalha: os jogadores não salvam no mesmo segundo
	while tokens[player] and player.Parent do
		write(player, false)
		task.wait(AUTOSAVE_SECONDS)
	end
end

local FAIL_MESSAGE = {
	locked = "Your progress is still saving on another server. Please rejoin in a minute.",
	newer = "This server is out of date. Please rejoin to get a newer server.",
	failed = "We could not load your progress. Nothing was changed. Please rejoin.",
}

function PlayerData.init(onReady: (Player) -> ())
	local function added(player: Player)
		local entry = fresh()
		local token: string? = nil
		if store then
			local candidate = HttpService:GenerateGUID(false)
			local status, saved = claim(player, candidate)
			if status == "ready" then
				merge(entry, saved)
				token = candidate
			elseif IS_STUDIO then
				-- Studio sem acesso à API: joga com o padrão, sem salvar nada
				warn("[PlayerData] Studio: playing without saving (" .. status .. ")")
			else
				player:Kick(FAIL_MESSAGE[status])
				return
			end
		end
		if player.Parent == nil then
			if token then
				-- saiu enquanto carregava: devolve a trava sem mudar os dados
				data[player], tokens[player] = entry, token
				write(player, true)
				data[player] = nil
			end
			return
		end
		data[player] = entry
		if token then
			tokens[player] = token
			task.spawn(autosave, player)
		end
		PlayerData.publish(player)
		onReady(player)
	end
	Players.PlayerAdded:Connect(added)
	for _, player in Players:GetPlayers() do
		task.spawn(added, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		if data[player] == nil then
			return -- ainda carregando: `added` devolve a trava
		end
		runBeforeSave({ player })
		write(player, true)
		data[player] = nil
		tokens[player] = nil
	end)
	game:BindToClose(function()
		runBeforeSave(Players:GetPlayers())
		local pending = 0
		for _, player in Players:GetPlayers() do
			if tokens[player] then
				pending += 1
				task.spawn(function()
					write(player, true)
					pending -= 1
				end)
			end
		end
		local deadline = os.clock() + SHUTDOWN_DEADLINE
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return PlayerData
