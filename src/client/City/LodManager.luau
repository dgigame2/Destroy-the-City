--!strict
-- LOD por chunk da cidade no CLIENTE (AUDITORIA §8.4). A cidade é dividida em chunks de ChunkSize studs;
-- a cada LodInterval s calcula a faixa de cada chunk em volta do jogador (Logic/Quality.band, com histerese)
-- e troca só os chunks que mudaram de faixa, os mais perto primeiro e no máximo ChunksPerStep por vez:
--   Near: construção inteira;
--   Mid:  sem os detalhes pequenos (peças com volume <= DetailVolume);
--   Far:  1 caixa (impostor) da cor da parede no lugar da construção; props pequenos somem.
-- Destroços seguem a mesma regra: pilha perto/médio, 1 caixa baixa longe (nunca somem de vez).
-- Peça escondida = Parent nil (sai do render e da física). Distâncias vêm do Tier (client/City/QualityTier).
-- Os modelos do Blender (Etapa 3) trazem LOD1 próprio; aqui o "Mid" é provisório (tira os detalhes).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local QualityConfig = require(Shared.Config.QualityConfig)
local Quality = require(Shared.Logic.Quality)

local QualityTier = require(script.Parent.QualityTier)

local LodManager = {}

type Detail = { Part: BasePart, Parent: Instance }

export type Record = {
	Id: number,
	Model: Model?,
	Details: { Detail },
	DetailsOn: boolean,
	Impostor: BasePart?,
	MakeImpostor: (() -> BasePart?)?,
	Wreck: Instance?,
	WreckBox: BasePart?,
	Dead: boolean,
	Chunk: number,
}

type Chunk = { Key: number, Cx: number, Cz: number, Band: Quality.Band?, Ids: { number } }

local localPlayer = Players.LocalPlayer
local records: { [number]: Record } = {}
local chunks: { [number]: Chunk } = {}
local chunkList: { Chunk } = {}
local buildingsFolder: Instance? = nil
local wreckFolder: Instance? = nil
local farFolder: Instance? = nil
local running = false
local SIZE = QualityConfig.ChunkSize
local HALF = SIZE * math.sqrt(2) / 2

local function focus(): Vector3?
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.Position
	end
	local camera = Workspace.CurrentCamera
	return if camera then camera.Focus.Position else nil
end

local function chunkBand(chunk: Chunk, at: Vector3, current: Quality.Band?): Quality.Band
	local tier = QualityTier.current()
	local d = Quality.chunkDistance(chunk.Cx, chunk.Cz, at.X, at.Z, SIZE)
	return Quality.band(d, current, tier.Near, tier.Mid, QualityConfig.Hysteresis, HALF)
end

-- Mostra um registro na faixa dada.
local function apply(rec: Record, band: Quality.Band)
	if rec.Dead then
		if rec.Wreck then
			rec.Wreck.Parent = if band ~= "Far" then wreckFolder else nil
		end
		if rec.WreckBox then
			rec.WreckBox.Parent = if band == "Far" then farFolder else nil
		end
		return
	end
	local model = rec.Model
	if model == nil then
		return
	end
	local wantDetails = band == "Near"
	if rec.DetailsOn ~= wantDetails then
		rec.DetailsOn = wantDetails
		for _, d in rec.Details do
			d.Part.Parent = if wantDetails then d.Parent else nil
		end
	end
	model.Parent = if band ~= "Far" then buildingsFolder else nil
	if band == "Far" and rec.Impostor == nil and rec.MakeImpostor then
		rec.Impostor = rec.MakeImpostor()
		rec.MakeImpostor = nil
	end
	if rec.Impostor then
		rec.Impostor.Parent = if band == "Far" then farFolder else nil
	end
end

local function chunkFor(x: number, z: number): Chunk
	local cx, cz = Quality.chunkOf(x, z, SIZE)
	local key = Quality.chunkKey(cx, cz)
	local chunk = chunks[key]
	if chunk == nil then
		chunk = { Key = key, Cx = cx, Cz = cz, Band = nil, Ids = {} }
		chunks[key] = chunk
		table.insert(chunkList, chunk)
	end
	return chunk
end

-- Registra uma construção (modelo ainda SEM pai). Já entra na faixa do chunk dela.
-- makeImpostor: cria a caixa de longe só quando precisar (nil = some de longe).
function LodManager.add(id: number, model: Model, x: number, z: number, makeImpostor: (() -> BasePart?)?)
	local details = {}
	for _, part in model:GetDescendants() do
		if
			part:IsA("BasePart") and Quality.isDetail(part.Size.X, part.Size.Y, part.Size.Z, QualityConfig.DetailVolume)
		then
			table.insert(details, { Part = part, Parent = part.Parent :: Instance })
		end
	end
	local chunk = chunkFor(x, z)
	local rec: Record = {
		Id = id,
		Model = model,
		Details = details,
		DetailsOn = true,
		Impostor = nil,
		MakeImpostor = makeImpostor,
		Wreck = nil,
		WreckBox = nil,
		Dead = false,
		Chunk = chunk.Key,
	}
	records[id] = rec
	table.insert(chunk.Ids, id)
	local at = focus()
	if chunk.Band == nil then
		chunk.Band = if at then chunkBand(chunk, at, nil) else "Near"
	end
	apply(rec, chunk.Band :: Quality.Band)
end

-- Faixa atual da construção (para decidir se anima o desabamento).
function LodManager.band(id: number): Quality.Band
	local rec = records[id]
	local chunk = rec and chunks[rec.Chunk]
	return if chunk and chunk.Band then chunk.Band else "Near"
end

-- A construção caiu: o modelo sai do LOD (quem chamou cuida dele), entram a pilha e a caixa de longe.
-- reveal = false: guarda escondido até LodManager.reveal (depois da animação do desabamento).
function LodManager.markDead(id: number, wreck: Instance?, wreckBox: BasePart?, reveal: boolean)
	local rec = records[id]
	if rec == nil then
		return
	end
	rec.Dead = true
	if rec.Impostor then
		rec.Impostor:Destroy()
		rec.Impostor = nil
	end
	rec.MakeImpostor = nil
	rec.Model = nil
	if not rec.DetailsOn then
		-- detalhes soltos (faixa Mid) não são filhos do modelo: destruir junto, senão vazam
		for _, d in rec.Details do
			d.Part:Destroy()
		end
	end
	table.clear(rec.Details)
	rec.Wreck = wreck
	rec.WreckBox = wreckBox
	if reveal then
		apply(rec, LodManager.band(id))
	end
end

function LodManager.reveal(id: number)
	local rec = records[id]
	if rec then
		apply(rec, LodManager.band(id))
	end
end

-- Modelo vivo da construção (nil depois de cair).
function LodManager.model(id: number): Model?
	local rec = records[id]
	return if rec then rec.Model else nil
end

local function step()
	local at = focus()
	if at == nil then
		return
	end
	-- chunks que mudaram de faixa, mais perto primeiro
	local changed: { { Chunk: Chunk, Band: Quality.Band, D: number } } = {}
	for _, chunk in chunkList do
		local band = chunkBand(chunk, at, chunk.Band)
		if band ~= chunk.Band then
			table.insert(changed, {
				Chunk = chunk,
				Band = band,
				D = Quality.chunkDistance(chunk.Cx, chunk.Cz, at.X, at.Z, SIZE),
			})
		end
	end
	table.sort(changed, function(a, b)
		return a.D < b.D
	end)
	for i = 1, math.min(#changed, QualityConfig.ChunksPerStep) do
		local c = changed[i]
		c.Chunk.Band = c.Band
		for _, id in c.Chunk.Ids do
			apply(records[id], c.Band)
		end
	end
end

-- Quantas peças cada faixa está mostrando agora (DevBench / medição).
function LodManager.stats(): { [string]: number }
	local out = { Near = 0, Mid = 0, Far = 0, Chunks = #chunkList }
	for _, chunk in chunkList do
		local band = chunk.Band or "Near"
		out[band] += #chunk.Ids
	end
	return out
end

function LodManager.init(buildings: Instance, wrecks: Instance, city: Instance)
	buildingsFolder = buildings
	wreckFolder = wrecks
	local far = Instance.new("Folder")
	far.Name = "Far"
	far.Parent = city
	farFolder = far
	if running then
		return
	end
	running = true
	QualityTier.onChanged(function()
		step()
	end)
	task.spawn(function()
		while true do
			task.wait(QualityConfig.LodInterval)
			step()
		end
	end)
end

return LodManager
