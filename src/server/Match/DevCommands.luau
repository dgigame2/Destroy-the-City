--!strict
-- Comandos de chat para TESTE. Só funcionam no Studio ou para o dono do jogo (game.CreatorId).
-- Digite /help no chat para ver a lista. A resposta aparece como aviso na tela (remote Notice).
--   /lvl N        nível N (barra zerada)          /max       nível máximo dos rebirths, barra cheia
--   /xp N         ganha N de XP (com o bônus dos rebirths)
--   /rebirths N   quantidade de rebirths          /heal      vida cheia
--   /kill         morre (testa a morte)           /shield N  escudo por N segundos (padrão 5)
--   /cd           zera as recargas (rajada e Q)   /spawn     volta ao ponto de nascimento
--   /regen        a cidade inteira volta agora

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Tornado = require(Shared.Logic.Tornado)
local TornadoConfig = require(Shared.Config.TornadoConfig)
local Remotes = require(Shared.Remotes)

local CityService = require(script.Parent.CityService)
local MatchService = require(script.Parent.MatchService)
local PvpService = require(script.Parent.PvpService)
local SkillService = require(script.Parent.SkillService)
local TornadoService = require(script.Parent.TornadoService)
local PlayerData = require(script.Parent.Parent.PlayerData)

local DevCommands = {}

local cfg = TornadoConfig :: Tornado.Config

local function allowed(player: Player): boolean
	return RunService:IsStudio() or (game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId)
end

local function say(player: Player, text: string)
	Remotes.event(Remotes.Names.Events.Notice):FireClient(player, text)
end

local function number(text: string?, default: number?): number?
	local n = tonumber(text)
	if n == nil or n ~= n or math.abs(n) == math.huge then
		return default
	end
	return n
end

type Handler = (player: Player, arg: string?) -> string

local commands: { [string]: Handler } = {}
local order: { string } = {}

local function add(name: string, handler: Handler)
	commands[name] = handler
	table.insert(order, "/" .. name)
end

local function setProgress(player: Player, level: number?, xp: number?, rebirths: number?): string
	local entry = PlayerData.get(player)
	if entry == nil then
		return "Save not loaded yet"
	end
	local l, x, r = Tornado.sanitize(cfg, level or entry.Level, xp or entry.Xp, rebirths or entry.Rebirths)
	PlayerData.setTornado(player, l, x, r)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = Tornado.walkSpeed(cfg, l)
	end
	return `LV {l} · XP {math.floor(x)} · R{r}`
end

add("lvl", function(player, arg)
	local level = number(arg)
	if level == nil then
		return "Use: /lvl 8"
	end
	return setProgress(player, level, 0, nil)
end)

add("max", function(player)
	local entry = PlayerData.get(player)
	local level = Tornado.maxLevel(cfg, if entry then entry.Rebirths else 0)
	return setProgress(player, level, Tornado.xpToNext(cfg, level), nil)
end)

add("xp", function(player, arg)
	local amount = number(arg)
	if amount == nil or amount <= 0 then
		return "Use: /xp 100"
	end
	TornadoService.give(player, amount)
	return setProgress(player, nil, nil, nil)
end)

add("rebirths", function(player, arg)
	local count = number(arg)
	if count == nil then
		return "Use: /rebirths 2"
	end
	return setProgress(player, nil, nil, count)
end)

add("heal", function(player)
	player:SetAttribute("Hp", player:GetAttribute("MaxHp"))
	return "HP full"
end)

add("kill", function(player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		return "No character"
	end
	humanoid.Health = 0
	return "Dead"
end)

add("shield", function(player, arg)
	local seconds = math.clamp(number(arg, 5) :: number, 0, 600)
	player:SetAttribute("ShieldUntil", Workspace:GetServerTimeNow() + seconds)
	return `Shield {seconds}s`
end)

add("cd", function(player)
	PvpService.resetCooldowns(player)
	SkillService.resetCooldown(player)
	return "Cooldowns reset"
end)

add("spawn", function(player)
	MatchService.toSpawn(player)
	return "Back to spawn"
end)

add("regen", function()
	return `City restored ({CityService.reviveAll()} buildings)`
end)

add("help", function()
	return table.concat(order, "  ")
end)

function DevCommands.start()
	local folder = Instance.new("Folder")
	folder.Name = "DevCommands"
	folder.Parent = TextChatService
	for name, handler in commands do
		local command = Instance.new("TextChatCommand")
		command.Name = "Dev_" .. name
		command.PrimaryAlias = "/" .. name
		command.Parent = folder
		command.Triggered:Connect(function(source: TextSource, message: string)
			local player = Players:GetPlayerByUserId(source.UserId)
			if player == nil or not allowed(player) then
				return
			end
			local arg = string.match(message, "^%S+%s+(%S+)")
			local ok, result = pcall(handler, player, arg)
			say(player, if ok then result else "Error: " .. tostring(result))
		end)
	end
end

return DevCommands
