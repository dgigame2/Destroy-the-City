--!strict
-- Física ideal de salto (sem arrasto, sem atrito). Função pura: não depende de APIs do Roblox.
-- Os resultados são VALORES CALCULADOS; o comportamento real do Humanoid deve ser medido no Studio.

local Physics = {}

-- Velocidade vertical inicial para atingir `jumpHeight` com a gravidade dada.
function Physics.takeoffVelocity(jumpHeight: number, gravity: number): number
	assert(jumpHeight >= 0 and gravity > 0, "jumpHeight >= 0 e gravity > 0")
	return math.sqrt(2 * gravity * jumpHeight)
end

-- Tempo para cair `height` studs a partir do repouso.
function Physics.fallTime(height: number, gravity: number): number
	assert(height >= 0 and gravity > 0, "height >= 0 e gravity > 0")
	return math.sqrt(2 * height / gravity)
end

-- Tempo no ar ao pular e pousar `heightDelta` studs acima (positivo) ou abaixo (negativo) do ponto de partida.
-- Retorna nil se o desnível for maior que a altura do pulo.
function Physics.airTime(jumpHeight: number, gravity: number, heightDelta: number): number?
	if heightDelta > jumpHeight then
		return nil
	end
	local v = Physics.takeoffVelocity(jumpHeight, gravity)
	-- raiz positiva de: heightDelta = v*t - g*t²/2
	local discriminant = v * v - 2 * gravity * heightDelta
	return (v + math.sqrt(discriminant)) / gravity
end

-- Maior vão horizontal (studs) alcançável correndo e pulando até uma plataforma com desnível `heightDelta`.
function Physics.maxGap(walkSpeed: number, jumpHeight: number, gravity: number, heightDelta: number): number?
	local t = Physics.airTime(jumpHeight, gravity, heightDelta)
	if t == nil then
		return nil
	end
	return walkSpeed * t
end

return Physics
