--!strict
-- PvP entre tornados (o servidor decide tudo). Números em Config/PvpConfig, fórmulas em Logic/Pvp.
--   * Vida própria (atributos Hp/MaxHp; não usa a vida do Humanoid) que regenera fora de combate.
--   * Encostar: tornado PvpConfig.LevelGap+ níveis maior engole o menor (dano contínuo).
--   * Rajada (remote Burst, clique): cone à frente, acerta tornados e construções. Recarga no servidor.
--   * Skills (Q) ficam no SkillService, que usa PvpService.damage / PvpService.knock.
--   * Morte: zera só a barra de XP (o nível fica) e quem matou ganha XP. O MatchService renasce o
--     jogador no ponto de nascimento; ao nascer ganha escudo (ShieldUntil, hora do servidor).
--   * Escudo de 2 s ao subir de nível. Sem área segura (decisão do usuário: o mapa separa pequenos e grandes).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Pvp = require(Shared.Logic.Pvp)
local PvpConfig = require(Shared.Config.PvpConfig)
local Tornado = require(Shared.Logic.Tornado)
local TornadoConfig = require(Shared.Config.TornadoConfig)
local Remotes = require(Shared.Remotes)

local TornadoService = require(script.Parent.TornadoService)
local PlayerData = require(script.Parent.Parent.PlayerData)

local PvpService = {}

local pcfg = PvpConfig :: Pvp.Config
local tcfg = TornadoConfig :: Tornado.Config

type State = { LastHit: number, NextBurst: number }

local states: { [Player]: State } = {}

local function now(): number
	return Workspace:GetServerTimeNow()
end

function PvpService.rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end
local rootOf = PvpService.rootOf

function PvpService.levelOf(player: Player): number
	return (player:GetAttribute("TornadoLevel") :: number?) or 1
end
local levelOf = PvpService.levelOf

function PvpService.alive(player: Player): boolean
	return states[player] ~= nil
		and player:GetAttribute("InMatch") == true
		and ((player:GetAttribute("Hp") :: number?) or 0) > 0
		and rootOf(player) ~= nil
end
local alive = PvpService.alive

local function shielded(player: Player): boolean
	return ((player:GetAttribute("ShieldUntil") :: number?) or 0) > now()
end

local function shield(player: Player, seconds: number)
	local current = (player:GetAttribute("ShieldUntil") :: number?) or 0
	player:SetAttribute("ShieldUntil", math.max(current, now() + seconds))
end

local function kill(victim: Player, killer: Player)
	victim:SetAttribute("Hp", 0)
	local entry = PlayerData.get(victim)
	if entry then
		local lost, gain = entry.Xp, Pvp.killXp(pcfg, tcfg, entry.Level)
		PlayerData.setTornado(victim, entry.Level, 0, entry.Rebirths) -- só a barra zera; o nível fica
		local killerLevel = levelOf(killer)
		TornadoService.give(killer, gain)
		Remotes.event(Remotes.Names.Events.Died):FireClient(victim, killer.DisplayName, entry.Level, lost, killerLevel)
		Remotes.event(Remotes.Names.Events.Killed):FireClient(killer, victim.DisplayName, gain)
	end
	local humanoid = victim.Character and victim.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Health = 0 -- o MatchService renasce no ponto de nascimento
	end
end

-- Dano de PvP. Recusa se alguém está morto ou se a vítima tem escudo.
function PvpService.damage(victim: Player, attacker: Player, amount: number): boolean
	if victim == attacker or not alive(victim) or not alive(attacker) or shielded(victim) then
		return false
	end
	attacker:SetAttribute("ShieldUntil", 0) -- atacar tira o próprio escudo
	states[victim].LastHit = now()
	local hp = (victim:GetAttribute("Hp") :: number) - amount
	if hp <= 0 then
		kill(victim, attacker)
	else
		victim:SetAttribute("Hp", hp)
	end
	return true
end
local damage = PvpService.damage

-- Empurra/puxa a vítima: o cliente dela move o próprio tornado (dono da física). Escudo protege.
function PvpService.knock(victim: Player, vx: number, vz: number, seconds: number)
	if alive(victim) and not shielded(victim) then
		Remotes.event(Remotes.Names.Events.Knock):FireClient(victim, vx, vz, seconds)
	end
end

local function step(dt: number)
	local t = now()
	local players = Players:GetPlayers()
	for _, a in players do
		if not alive(a) then
			continue
		end
		local state = states[a]
		local la = levelOf(a)
		local pa = (rootOf(a) :: BasePart).Position
		local reach = Tornado.radius(tcfg, la)
		for _, b in players do
			if b == a or not alive(b) then
				continue
			end
			local pb = (rootOf(b) :: BasePart).Position
			local lb = levelOf(b)
			if Vector2.new(pb.X - pa.X, pb.Z - pa.Z).Magnitude <= reach and Pvp.canEat(pcfg, la, lb) then
				damage(b, a, pcfg.Touch.HpShare * Pvp.maxHp(pcfg, lb) * dt)
			end
		end
		if alive(a) then
			local hp = a:GetAttribute("Hp") :: number
			local healed = Pvp.regen(pcfg, hp, Pvp.maxHp(pcfg, la), t - state.LastHit, dt)
			if healed ~= hp then
				a:SetAttribute("Hp", healed)
			end
		end
	end
end

local function onBurst(player: Player, dx: any, dz: any)
	local state = states[player]
	if state == nil or not alive(player) then
		return
	end
	local t = now()
	if t < state.NextBurst then
		return
	end
	state.NextBurst = t + pcfg.Burst.Cooldown
	local root = rootOf(player) :: BasePart
	local x, z = Pvp.direction(dx, dz)
	if x == nil or z == nil then
		local look = root.CFrame.LookVector
		x, z = Pvp.direction(look.X, look.Z)
		if x == nil or z == nil then
			return
		end
	end
	local level = levelOf(player)
	local rebirths = (player:GetAttribute("Rebirths") :: number?) or 0
	local reach = Tornado.radius(tcfg, level) * pcfg.Burst.Reach + pcfg.Burst.ReachExtra
	local pos = root.Position
	local hit = pcfg.Burst.HpShare * Pvp.maxHp(pcfg, level)
	for _, other in Players:GetPlayers() do
		local r = if other ~= player then rootOf(other) else nil
		if r and Pvp.inFront(pos.X, pos.Z, x, z, r.Position.X, r.Position.Z, reach, pcfg.Burst.MinDot) then
			damage(other, player, hit)
		end
	end
	local half = reach * 0.5
	TornadoService.hitCity(
		player,
		pos.X + x * half,
		pos.Z + z * half,
		half,
		Tornado.dps(tcfg, level, rebirths) * pcfg.Burst.CitySeconds
	)
	Remotes.unreliable(Remotes.Names.Unreliable.BurstFx):FireAllClients(pos, x, z, reach)
end

local function onPlayer(player: Player)
	states[player] = { LastHit = -math.huge, NextBurst = 0 }
	local lastLevel = levelOf(player)
	player.CharacterAdded:Connect(function()
		local maxHp = Pvp.maxHp(pcfg, levelOf(player))
		player:SetAttribute("MaxHp", maxHp)
		player:SetAttribute("Hp", maxHp)
		player:SetAttribute("ShieldUntil", now() + pcfg.Shield.Spawn)
		states[player].LastHit = -math.huge
	end)
	player:GetAttributeChangedSignal("TornadoLevel"):Connect(function()
		local level = levelOf(player)
		local newMax = Pvp.maxHp(pcfg, level)
		local oldMax = (player:GetAttribute("MaxHp") :: number?) or newMax
		local hp = (player:GetAttribute("Hp") :: number?) or newMax
		player:SetAttribute("MaxHp", newMax)
		if hp > 0 then
			player:SetAttribute("Hp", Pvp.rescale(hp, oldMax, newMax))
		end
		if level > lastLevel then
			shield(player, pcfg.Shield.LevelUp)
		end
		lastLevel = level
	end)
end

-- Comando de teste (/cd): zera a recarga da rajada (a do Q é do SkillService).
function PvpService.resetCooldowns(player: Player)
	local state = states[player]
	if state then
		state.NextBurst = 0
	end
end

function PvpService.start()
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
	Remotes.event(Remotes.Names.Events.Burst).OnServerEvent:Connect(onBurst)
	task.spawn(function()
		while true do
			step(task.wait(TornadoConfig.Tick))
		end
	end)
end

return PvpService
