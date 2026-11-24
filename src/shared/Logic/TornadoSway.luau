--!strict
-- Movimento do corpo dos tornados em peças (puro, sem Instances). t = altura: 0 no pé, 1 no topo.
--   Onda: uma volta completa em espiral do pé ao topo. Um lado compensa o outro, então o meio do corpo não sai do eixo.
--   Inércia: ao andar, o topo fica para trás (mola); ao parar, passa um pouco do ponto e volta.

local TornadoSway = {}

export type Config = {
	Wave: number, -- tamanho da onda (unidades do modelo)
	WaveSpeed: number, -- rad/s
	MoveWave: number, -- quanto a onda acelera andando (0.6 = +60%)
	Lean: number, -- atraso do topo na velocidade máxima
	Stiffness: number,
	Damping: number,
}
export type State = { X: number, Z: number, VX: number, VZ: number, Phase: number }

function TornadoSway.new(): State
	return { X = 0, Z = 0, VX = 0, VZ = 0, Phase = 0 }
end

-- mx, mz: velocidade / velocidade de andar.
function TornadoSway.step(cfg: Config, s: State, dt: number, mx: number, mz: number)
	local step = math.min(dt, 1 / 20) -- travada não explode a mola
	local length = math.sqrt(mx * mx + mz * mz)
	if length > 1 then
		mx, mz, length = mx / length, mz / length, 1
	end
	s.VX += ((-mx * cfg.Lean - s.X) * cfg.Stiffness - s.VX * cfg.Damping) * step
	s.VZ += ((-mz * cfg.Lean - s.Z) * cfg.Stiffness - s.VZ * cfg.Damping) * step
	s.X += s.VX * step
	s.Z += s.VZ * step
	s.Phase = (s.Phase + cfg.WaveSpeed * (1 + cfg.MoveWave * length) * step) % (2 * math.pi)
end

-- Deslocamento do corpo na altura t (o pé nunca sai do lugar).
function TornadoSway.offset(cfg: Config, s: State, t: number): (number, number)
	local wave = cfg.Wave * (1 - (1 - math.min(t, 1)) ^ 4)
	local angle = 2 * math.pi * t - s.Phase
	local lean = t ^ 1.6
	return math.cos(angle) * wave + s.X * lean, math.sin(angle) * wave + s.Z * lean
end

return TornadoSway
