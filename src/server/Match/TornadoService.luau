--!strict
-- O jogador é um tornado: o servidor confere a cada TornadoConfig.Tick o que está dentro do raio dele,
-- dá dano (autoridade do servidor, via CityService) e paga XP por objeto destruído. O XP sobe o nível,
-- e o nível dá tamanho, dano e velocidade (Logic/Tornado).
-- Progresso salvo no PlayerData (que publica os atributos TornadoLevel, TornadoXp, Rebirths para o cliente).
-- Rebirth: o cliente pede (remote Rebirth), o servidor confere o nível máximo e aplica.
-- O visual (corpo escondido + tornado) é do cliente (client/City/TornadoClient).

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Tornado = require(Shared.Logic.Tornado)
local TornadoConfig = require(Shared.Config.TornadoConfig)
local Remotes = require(Shared.Remotes)

local CityService = require(script.Parent.CityService)
local PlayerData = require(script.Parent.Parent.PlayerData)
local MatchService = require(script.Parent.MatchService)

local TornadoService = {}

local cfg = TornadoConfig :: Tornado.Config

-- Grupos de colisão: o tornado atravessa construções e destroços, mas pisa no chão.
-- O cliente põe as próprias peças nos grupos (a cidade só existe no cliente).
local function registerCollisionGroups()
	for _, name in { "Tornado", "CityBuildings" } do
		if not PhysicsService:IsCollisionGroupRegistered(name) then
			PhysicsService:RegisterCollisionGroup(name)
		end
	end
	PhysicsService:CollisionGroupSetCollidable("Tornado", "CityBuildings", false)
end

local function levelOf(player: Player): number
	return (player:GetAttribute("TornadoLevel") :: number?) or 1
end

local function applySpeed(player: Player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = Tornado.walkSpeed(cfg, levelOf(player))
	end
end

function TornadoService.give(player: Player, gain: number)
	local entry = PlayerData.get(player)
	if entry == nil then
		return -- save ainda não carregou
	end
	local bonus = 1 + cfg.Rebirth.XpBonus * entry.Rebirths
	local xp = Tornado.addXp(cfg, entry.Level, entry.Xp, gain * bonus, entry.Rebirths)
	PlayerData.setTornado(player, entry.Level, xp, entry.Rebirths)
end

-- EVOLVE: sobe 1 nível gastando a barra cheia (o cliente só pede; o servidor confere).
local function evolve(player: Player): boolean
	local entry = PlayerData.get(player)
	if entry == nil then
		return false
	end
	local level, xp = Tornado.evolve(cfg, entry.Level, entry.Xp, entry.Rebirths)
	if level == nil or xp == nil then
		return false
	end
	PlayerData.setTornado(player, level, xp, entry.Rebirths)
	applySpeed(player)
	return true
end

-- Volta ao nível 1 com +1 rebirth (+1 no nível máximo). Só no máximo com a barra cheia.
local function rebirth(player: Player): boolean
	local entry = PlayerData.get(player)
	if entry == nil or not Tornado.canRebirth(cfg, entry.Level, entry.Xp, entry.Rebirths) then
		return false
	end
	PlayerData.setTornado(player, 1, 0, entry.Rebirths + 1)
	applySpeed(player)
	MatchService.toSpawn(player) -- recomeça do ponto de nascimento
	task.spawn(PlayerData.save, player) -- rebirth é marco importante: salva já
	return true
end

-- Dano na cidade num círculo; paga ao jogador o XP do que cair (também usado pela rajada do PvP).
-- Devolve quantas construções caíram (as skills usam para a explosão final).
function TornadoService.hitCity(player: Player, x: number, z: number, radius: number, damage: number): number
	local state = CityService.state()
	if state == nil then
		return 0
	end
	local gain, count = 0, 0
	for _, id in CityService.query(x, z, radius, cfg.MaxTargets) do
		local _, killed = CityService.hit(id, damage)
		if killed then
			gain += state.Value[id] + cfg.PropXp
			count += 1
		end
	end
	if gain > 0 then
		TornadoService.give(player, gain)
	end
	return count
end

local function step()
	for _, player in Players:GetPlayers() do
		if not player:GetAttribute("InMatch") or player:GetAttribute("Hp") == 0 then
			continue -- morto (PvP) não destrói nada até renascer
		end
		-- fwjelaa-ignore: findfirstchild-chain (resultado guardado e conferido logo abaixo)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root == nil then
			continue
		end
		local level = levelOf(player)
		local rebirths = (player:GetAttribute("Rebirths") :: number?) or 0
		local pos = root.Position
		TornadoService.hitCity(
			player,
			pos.X,
			pos.Z,
			Tornado.radius(cfg, level),
			Tornado.dps(cfg, level, rebirths) * cfg.Tick
		)
	end
end

-- Corpo invisível para todos (no servidor replica; no cliente o Roblox reseta a transparência local).
local function hide(d: Instance)
	if d:IsA("BasePart") or d:IsA("Decal") then
		(d :: any).Transparency = 1
	end
end

local function onPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		for _, d in character:GetDescendants() do
			hide(d)
		end
		character.DescendantAdded:Connect(hide)
		task.defer(applySpeed, player)
	end)
end

function TornadoService.start()
	registerCollisionGroups()
	Remotes.func(Remotes.Names.Functions.Rebirth).OnServerInvoke = rebirth
	Remotes.func(Remotes.Names.Functions.Evolve).OnServerInvoke = evolve
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	task.spawn(function()
		while true do
			task.wait(cfg.Tick)
			step()
		end
	end)
end

return TornadoService
