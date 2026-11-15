--!strict
-- Varredura de "peça dentro de peça" no jogo de verdade (só no Studio, ao dar Play).
-- Mede as peças já montadas do lobby e do mapa atual: para cada peça visível, cria uma cópia
-- um pouco menor (encolhida em Margin de cada lado) e pergunta ao Roblox quem ela toca.
-- Quem só encosta não aparece; quem entra mais que Margin aparece no Output.
-- Complementa os testes do Lune (Templates.spec e Terrain.spec), que conferem os dados antes do jogo.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local GeometryAudit = {}

local MARGIN = 0.05 -- studs: menos que isso é considerado "encostar"
local YIELD_EVERY = 250 -- peças por frame (não trava o Studio)
local MAX_REPORT = 40 -- quantos problemas listar no Output

-- Efeitos de luz (ex.: brilho das barreiras) não são geometria do mapa: ficam fora da varredura.
local function visible(part: BasePart): boolean
	return part.Transparency < 1 and part:GetAttribute("NoAudit") ~= true
end

local function probeFor(part: BasePart): BasePart?
	local size = part.Size - Vector3.new(MARGIN, MARGIN, MARGIN) * 2
	if size.X <= 0 or size.Y <= 0 or size.Z <= 0 then
		return nil
	end
	local probe: BasePart
	if part:IsA("WedgePart") then
		probe = Instance.new("WedgePart")
	elseif part:IsA("Part") then
		local p = Instance.new("Part")
		p.Shape = part.Shape
		probe = p
	else
		return nil -- MeshParts e outros: não usados no jogo
	end
	probe.Size = size
	probe.CFrame = part.CFrame
	probe.Anchored = true
	probe.CanCollide = false
	probe.CanQuery = false
	probe.CanTouch = false
	probe.Transparency = 1
	return probe
end

local function label(part: Instance, root: Instance): string
	local model = part:FindFirstAncestorOfClass("Model")
	local owner = if model and model ~= root then model.Name .. "." else ""
	return owner .. part.Name
end

-- Varre as pastas e devolve a lista de pares que se atravessam.
function GeometryAudit.scan(roots: { Instance }): { string }
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = roots
	params.RespectCanCollide = false
	local seen: { [string]: boolean } = {}
	local problems: { string } = {}
	local checked = 0
	local holder = Instance.new("Folder")
	holder.Name = "GeometryAuditProbe"
	holder.Parent = Workspace
	for _, root in roots do
		for _, item in root:GetDescendants() do
			if not item:IsA("BasePart") or not visible(item) then
				continue
			end
			local probe = probeFor(item)
			if probe == nil then
				continue
			end
			probe.Parent = holder
			for _, other in Workspace:GetPartsInPart(probe, params) do
				-- cunhas finas do mesmo objeto (fatias da roleta, listras de toldo) são feitas para encostar
				-- pelas bordas; a cópia encolhida de uma cunha fina "sai" pela ponta e dá falso positivo.
				local wedgePair = item:IsA("WedgePart") and other:IsA("WedgePart") and item.Parent == other.Parent
				if other ~= item and visible(other) and not wedgePair then
					local a, b = item:GetFullName(), other:GetFullName()
					local key = if a < b then a .. "|" .. b else b .. "|" .. a
					if not seen[key] then
						seen[key] = true
						table.insert(problems, `{label(item, root)}  x  {label(other, root)}  ({root.Name})`)
					end
				end
			end
			probe:Destroy()
			checked += 1
			if checked % YIELD_EVERY == 0 then
				task.wait()
			end
		end
	end
	holder:Destroy()
	return problems
end

-- No Studio: espera o lobby e o primeiro mapa ficarem prontos e escreve o resultado no Output.
function GeometryAudit.startInStudio(isMapReady: () -> boolean)
	if not RunService:IsStudio() then
		return
	end
	task.spawn(function()
		while not isMapReady() do
			task.wait(1)
		end
		local roots: { Instance } = {}
		for _, name in { "Lobby", "City" } do
			local root = Workspace:FindFirstChild(name)
			if root then
				table.insert(roots, root)
			end
		end
		local started = os.clock()
		local problems = GeometryAudit.scan(roots)
		local seconds = string.format("%.1f", os.clock() - started)
		if #problems == 0 then
			print(`[GeometryAudit] OK: nenhuma peça dentro de outra (lobby + mapa, {seconds}s)`)
			return
		end
		warn(`[GeometryAudit] {#problems} pares de peças se atravessando ({seconds}s):`)
		for index = 1, math.min(#problems, MAX_REPORT) do
			warn("  " .. problems[index])
		end
		if #problems > MAX_REPORT then
			warn(`  ... e mais {#problems - MAX_REPORT}`)
		end
	end)
end

return GeometryAudit
