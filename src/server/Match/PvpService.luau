--!strict
-- PvP entre tornados (o servidor decide tudo). Números em Config/PvpConfig, fórmulas em Logic/Pvp.
--   * Vida própria (atributos Hp/MaxHp; não usa a vida do Humanoid) que regenera fora de combate.
--   * Rajada (remote Burst, clique): cone à frente, acerta tornados e construções. Recarga no servidor.
--   * Skills (Q) ficam no SkillService, que usa PvpService.knock para mover outros jogadores.
--   * Morte: perde a barra de XP, ou um nível se já estava vazia. Quem matou ganha XP. O MatchService renasce o
--     jogador no ponto de nascimento; ao nascer ganha escudo (ShieldUntil, hora do servidor).
--   * Só luta quem tem até LevelGap níveis de diferença (aviso para quem tenta); briga em andamento continua.
--   * Escudo na animação do EVOLVE: não leva nem dá dano/empurrão em jogadores, não cura. Sem área segura (decisão do usuário: o mapa separa pequenos e grandes).

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

type State = { LastHit: number, NextBurst: number, EvolveUntil: number, NextNotice: number }

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

-- Na animação do EVOLVE: protegido, mas sem atacar jogadores.
local function evolving(player: Player): boolean
	local state = states[player]
	return state ~= nil and state.EvolveUntil > now()
end

-- Diferença de nível permite? Se não, avisa quem tentou (no máximo um aviso a cada NoticeEvery).
local function canFight(victim: Player, attacker: Player): boolean
	local fightUntil = (attacker:GetAttribute(Pvp.fightKey(victim.UserId)) :: number?) or 0
	if Pvp.canFight(pcfg, levelOf(attacker), levelOf(victim), fightUntil - now()) then
		return true
	end
	local state = states[attacker]
	if state and now() >= state.NextNotice then
		state.NextNotice = now() + pcfg.NoticeEvery
		Remotes.event(Remotes.Names.Events.Notice)
			:FireClient(attacker, `You can't attack players more than {pcfg.LevelGap} levels above or below you!`)
	end
	return false
end

local function endFight(a: Player, b: Player)
	a:SetAttribute(Pvp.fightKey(b.UserId), nil)
	b:SetAttribute(Pvp.fightKey(a.UserId), nil)
end

local function applyDeath(player: Player): (number?, number?)
	player:SetAttribute("Hp", 0)
	local entry = PlayerData.get(player)
	if entry then
		local level, xp = entry.Level, entry.Xp
		PlayerData.setTornado(player, Pvp.levelAfterDeath(level, xp), 0, entry.Rebirths)
		return level, xp
	end
	return nil, nil
end

local function kill(victim: Player, killer: Player)
	endFight(victim, killer) -- morreu: a briga acabou
	local level, lost = applyDeath(victim)
	if level and lost then
		local gain = Pvp.killXp(pcfg, tcfg, level)
		local killerLevel = levelOf(killer)
		TornadoService.give(killer, gain)
		Remotes.event(Remotes.Names.Events.Died):FireClient(victim, killer.DisplayName, level, lost, killerLevel)
		Remotes.event(Remotes.Names.Events.Killed):FireClient(killer, victim.DisplayName, gain)
	end
	local humanoid = victim.Character and victim.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Health = 0 -- o MatchService renasce no ponto de nascimento
	end
end

-- Dano de PvP. Recusa se alguém está morto, se a vítima tem escudo ou se quem ataca está evoluindo.
local function damage(victim: Player, attacker: Player, amount: number)
	if victim == attacker or not alive(victim) or not alive(attacker) or shielded(victim) or evolving(attacker) then
		return
	end
	if not canFight(victim, attacker) then
		return
	end
	local fightUntil = now() + pcfg.FightSeconds
	attacker:SetAttribute(Pvp.fightKey(victim.UserId), fightUntil)
	victim:SetAttribute(Pvp.fightKey(attacker.UserId), fightUntil)
	attacker:SetAttribute("ShieldUntil", 0) -- atacar tira o próprio escudo
	states[victim].LastHit = now()
	local hp = (victim:GetAttribute("Hp") :: number) - amount
	if hp <= 0 then
		kill(victim, attacker)
	else
		victim:SetAttribute("Hp", hp)
	end
end

-- Empurra/puxa a vítima: o cliente dela move o próprio tornado (dono da física). Escudo protege.
function PvpService.knock(victim: Player, attacker: Player, vx: number, vz: number, seconds: number)
	if alive(victim) and not shielded(victim) and not evolving(attacker) and canFight(victim, attacker) then
		Remotes.event(Remotes.Names.Events.Knock):FireClient(victim, vx, vz, seconds)
	end
end

local function step(dt: number)
	local t = now()
	for _, player in Players:GetPlayers() do
		if not alive(player) then
			continue
		end
		local hp = player:GetAttribute("Hp") :: number
		local elapsed = t - states[player].LastHit
		local healed = Pvp.regen(pcfg, hp, Pvp.maxHp(pcfg, levelOf(player)), elapsed, dt)
		if healed ~= hp then
			player:SetAttribute("Hp", healed)
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
	Remotes.unreliable(Remotes.Names.Unreliable.BurstFx):FireAllClients(player.UserId, x, z)
end

local function onPlayer(player: Player)
	states[player] = { LastHit = -math.huge, NextBurst = 0, EvolveUntil = 0, NextNotice = 0 }
	local lastLevel = levelOf(player)
	local function onCharacter(character: Model)
		local maxHp = Pvp.maxHp(pcfg, levelOf(player))
		player:SetAttribute("MaxHp", maxHp)
		player:SetAttribute("Hp", maxHp)
		player:SetAttribute("ShieldUntil", now() + pcfg.Shield.Spawn)
		states[player].LastHit = -math.huge
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		humanoid.Died:Once(function()
			-- Mortes sem atacante (por exemplo /kill). PvP já aplicou a regra e marcou Hp = 0.
			if character == player.Character and ((player:GetAttribute("Hp") :: number?) or 0) > 0 then
				applyDeath(player)
			end
		end)
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
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
			local seconds = Tornado.evolveSeconds(tcfg, lastLevel, level)
			states[player].EvolveUntil = now() + seconds
			shield(player, seconds)
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
		for _, other in Players:GetPlayers() do
			other:SetAttribute(Pvp.fightKey(player.UserId), nil)
		end
	end)
	Remotes.event(Remotes.Names.Events.Burst).OnServerEvent:Connect(onBurst)
	task.spawn(function()
		while true do
			step(task.wait(TornadoConfig.Tick))
		end
	end)
end

return PvpService
