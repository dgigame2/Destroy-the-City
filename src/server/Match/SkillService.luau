--!strict
-- Skills (Q) dos tornados: uma por forma (Config/SkillConfig, zonas em Logic/Skills). O servidor decide tudo:
--   * Q (remote Special, com a direção): confere vida, forma e recarga; cria a skill ativa.
--   * A cada Tick: cada zona dá dano na cidade (paga XP) e nos tornados dentro dela, e puxa/empurra/arrasta
--     (PvpService.knock: o cliente da vítima move o próprio tornado). Rastro de fogo dura TrailSeconds.
--   * No fim: explosão que cresce com o que a skill destruiu (até o limite).
--   * Efeito para todos: SkillFx (início; cada cliente calcula as zonas igual) e SkillEndFx (explosão).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Pvp = require(Shared.Logic.Pvp)
local PvpConfig = require(Shared.Config.PvpConfig)
local Skills = require(Shared.Logic.Skills)
local SkillConfig = require(Shared.Config.SkillConfig)
local Tornado = require(Shared.Logic.Tornado)
local TornadoConfig = require(Shared.Config.TornadoConfig)
local Remotes = require(Shared.Remotes)

local PvpService = require(script.Parent.PvpService)
local TornadoService = require(script.Parent.TornadoService)

local SkillService = {}

local pcfg = PvpConfig :: Pvp.Config
local tcfg = TornadoConfig :: Tornado.Config
local KNOCK_SECONDS = TornadoConfig.Tick * 1.5 -- cada empurrão dura até o próximo tick

type Active = {
	Player: Player,
	Def: any,
	Start: number,
	OX: number,
	OZ: number,
	DX: number,
	DZ: number,
	Radius: number,
	Level: number,
	Rebirths: number,
	CX: number, -- última posição conhecida do tornado (se ele morrer ou sair, a skill termina ali)
	CZ: number,
	Collected: number,
	Hit: { [Player]: boolean },
	Trail: { { X: number, Z: number, R: number, Until: number } },
	NextTrail: number,
	Done: boolean, -- já explodiu (o rastro de fogo ainda pode estar queimando)
}

local actives: { Active } = {}
local nextSkill: { [Player]: number } = {}

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function cityDps(a: Active): number
	return Tornado.dps(tcfg, a.Level, a.Rebirths)
end

local function maxHp(a: Active): number
	return Pvp.maxHp(pcfg, a.Level)
end

-- Tornados (menos quem usou) dentro do círculo.
local function victims(a: Active, x: number, z: number, r: number): { { Player: Player, X: number, Z: number } }
	local list = {}
	for _, other in Players:GetPlayers() do
		if other ~= a.Player and PvpService.alive(other) then
			local p = (PvpService.rootOf(other) :: BasePart).Position
			if Vector2.new(p.X - x, p.Z - z).Magnitude <= r then
				table.insert(list, { Player = other, X = p.X, Z = p.Z })
			end
		end
	end
	return list
end

local function zoneTick(a: Active, zone: Skills.Zone, dt: number)
	local def = a.Def
	a.Collected += TornadoService.hitCity(a.Player, zone.X, zone.Z, zone.R, cityDps(a) * def.CityRate * dt)
	for _, v in victims(a, zone.X, zone.Z, zone.R) do
		if def.Once then
			if not a.Hit[v.Player] and PvpService.damage(v.Player, a.Player, def.ImpactHp * maxHp(a)) then
				a.Hit[v.Player] = true
			end
		else
			PvpService.damage(v.Player, a.Player, def.HpRate * maxHp(a) * dt)
		end
		if def.Pull then
			-- positivo puxa para o centro; negativo empurra para fora (Wind Burst)
			local x, z = Pvp.direction(zone.X - v.X, zone.Z - v.Z)
			if x == nil or z == nil then
				x, z = a.DX, a.DZ
			end
			PvpService.knock(v.Player, (x :: number) * def.Pull, (z :: number) * def.Pull, KNOCK_SECONDS)
		end
		if def.Drag then
			PvpService.knock(v.Player, a.DX * def.Drag, a.DZ * def.Drag, KNOCK_SECONDS)
		end
	end
end

local function finish(a: Active)
	local def = a.Def
	local burst = def.Burst
	if burst == nil then
		return
	end
	local x, z = Skills.burstAt(def, a.CX, a.CZ, a.OX, a.OZ, a.DX, a.DZ, a.Radius)
	local mult = Skills.burstMult(def, a.Collected)
	local r = burst.Size * a.Radius
	TornadoService.hitCity(a.Player, x, z, r, cityDps(a) * burst.City * mult)
	for _, v in victims(a, x, z, r) do
		PvpService.damage(v.Player, a.Player, burst.Hp * mult * maxHp(a))
	end
	Remotes.unreliable(Remotes.Names.Unreliable.SkillEndFx):FireAllClients(a.Player.UserId, x, z, r, mult)
end

local function step(dt: number)
	local t = now()
	for i = #actives, 1, -1 do
		local a = actives[i]
		local def = a.Def
		local root = if a.Player.Parent then PvpService.rootOf(a.Player) else nil
		if root then
			a.CX, a.CZ = root.Position.X, root.Position.Z
		end
		local elapsed = t - a.Start
		local zones = Skills.zones(def, elapsed, a.CX, a.CZ, a.OX, a.OZ, a.DX, a.DZ, a.Radius)
		for _, zone in zones do
			zoneTick(a, zone, dt)
		end
		if def.Trail then
			if t >= a.NextTrail then
				a.NextTrail = t + 0.4
				local zone = zones[1]
				table.insert(a.Trail, { X = zone.X, Z = zone.Z, R = zone.R * 0.7, Until = t + def.TrailSeconds })
			end
			for _, fire in a.Trail do
				if fire.Until > t then
					a.Collected += TornadoService.hitCity(
						a.Player,
						fire.X,
						fire.Z,
						fire.R,
						cityDps(a) * def.TrailRate * dt
					)
					for _, v in victims(a, fire.X, fire.Z, fire.R) do
						PvpService.damage(v.Player, a.Player, def.HpRate * 0.5 * maxHp(a) * dt)
					end
				end
			end
		end
		local trailLeft = def.Trail and a.Trail[#a.Trail] and a.Trail[#a.Trail].Until > t
		if elapsed >= Skills.duration(def) and not a.Done then
			a.Done = true
			finish(a)
		end
		if a.Done and not trailLeft then
			table.remove(actives, i)
		end
	end
end

local function onSkill(player: Player, dx: any, dz: any): string?
	if not PvpService.alive(player) then
		return nil
	end
	local t = now()
	if t < (nextSkill[player] or 0) then
		return nil
	end
	local level = PvpService.levelOf(player)
	local index, def = Skills.forForm(SkillConfig, Tornado.form(tcfg, level))
	local root = PvpService.rootOf(player) :: BasePart
	local x, z = Pvp.direction(dx, dz)
	if x == nil or z == nil then
		local look = root.CFrame.LookVector
		x, z = Pvp.direction(look.X, look.Z)
		if x == nil or z == nil then
			x, z = 0, 1
		end
	end
	nextSkill[player] = t + def.Cooldown
	local pos = root.Position
	local radius = Tornado.radius(tcfg, level)
	table.insert(actives, {
		Player = player,
		Def = def,
		Start = t,
		OX = pos.X,
		OZ = pos.Z,
		DX = x :: number,
		DZ = z :: number,
		Radius = radius,
		Level = level,
		Rebirths = (player:GetAttribute("Rebirths") :: number?) or 0,
		CX = pos.X,
		CZ = pos.Z,
		Collected = 0,
		Hit = {},
		Trail = {},
		NextTrail = 0,
		Done = false,
	})
	Remotes.unreliable(Remotes.Names.Unreliable.SkillFx)
		:FireAllClients(index, player.UserId, t, pos.X, pos.Y, pos.Z, x, z, radius)
	return def.Name
end

-- Comando de teste (/cd).
function SkillService.resetCooldown(player: Player)
	nextSkill[player] = nil
end

function SkillService.start()
	Players.PlayerRemoving:Connect(function(player)
		nextSkill[player] = nil
	end)
	Remotes.func(Remotes.Names.Functions.Special).OnServerInvoke = onSkill
	task.spawn(function()
		while true do
			step(task.wait(TornadoConfig.Tick))
		end
	end)
end

return SkillService
