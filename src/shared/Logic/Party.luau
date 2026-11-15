--!strict
-- Regras das parties do lobby (puras, testáveis no Lune).
-- Um quadrado ("pad") passa por: Empty -> Creating (dono escolhendo) -> Open (outros entram) -> sai para a run.
-- Para run salva: Empty -> Creating -> Loading (esperando todos os membros da run) -> sai para a run.

local Party = {}

export type Settings = { Map: string, Difficulty: string, Size: number }

type MapLike = { Id: string, RequiredWins: number }
type DifficultyLike = { Id: string, RequiredWins: number }

-- Confere as opções escolhidas na tela CREATE PARTY. Devolve as opções limpas ou nil + motivo.
function Party.validate(
	settings: any,
	wins: number,
	maps: { MapLike },
	difficulties: { DifficultyLike },
	maxSize: number
): (Settings?, string?)
	if type(settings) ~= "table" then
		return nil, "invalid"
	end
	local mapId, difficultyId, size = settings.Map, settings.Difficulty, settings.Size
	if type(mapId) ~= "string" or type(difficultyId) ~= "string" or type(size) ~= "number" then
		return nil, "invalid"
	end
	local map: MapLike? = nil
	for _, m in maps do
		if m.Id == mapId then
			map = m
		end
	end
	if map == nil then
		return nil, "unknown map"
	end
	if wins < map.RequiredWins then
		return nil, "map locked"
	end
	local difficulty: DifficultyLike? = nil
	for _, d in difficulties do
		if d.Id == difficultyId then
			difficulty = d
		end
	end
	if difficulty == nil then
		return nil, "unknown difficulty"
	end
	if wins < difficulty.RequiredWins then
		return nil, "difficulty locked"
	end
	if size ~= math.floor(size) or size < 1 or size > maxSize then
		return nil, "invalid size"
	end
	return { Map = mapId, Difficulty = difficultyId, Size = size }, nil
end

-- Quem faz parte da party: o dono primeiro, depois quem está no quadrado (na ordem em que chegou),
-- até o tamanho escolhido. `onPad` vem na ordem de chegada; ids são números (UserId).
function Party.members(owner: number, onPad: { number }, size: number): { number }
	local list = { owner }
	for _, id in onPad do
		if #list >= size then
			break
		end
		if id ~= owner then
			table.insert(list, id)
		end
	end
	return list
end

-- Quando a party sai: OpenSeconds depois de criada, ou FullSeconds depois de lotar (o que vier antes).
function Party.departAt(createdAt: number, fullSince: number?, openSeconds: number, fullSeconds: number): number
	local departure = createdAt + openSeconds
	if fullSince then
		departure = math.min(departure, fullSince + fullSeconds)
	end
	return departure
end

-- Texto da placa em cima do quadrado.
function Party.statusText(
	status: string,
	ownerName: string?,
	count: number,
	size: number,
	secondsLeft: number?
): (string, string)
	if status == "Creating" then
		return `{ownerName or "Someone"} is creating a party`, "- / -"
	elseif status == "Open" then
		local line = `{count}/{size}`
		if secondsLeft then
			line ..= `  •  {math.max(0, math.ceil(secondsLeft))}s`
		end
		return `{ownerName or "Someone"}'s party`, line
	elseif status == "Loading" then
		local line = `{count}/{size} here`
		if secondsLeft then
			line ..= `  •  {math.max(0, math.ceil(secondsLeft))}s`
		end
		return `{ownerName or "Someone"} is loading a run`, line
	elseif status == "Departing" then
		return "Starting the run!", "Teleporting..."
	end
	return "Touch to create a party", `0/{size}`
end

return Party
