--!strict
-- Trava de sessão do save (pura): só um servidor por vez é dono do save de cada jogador.
-- O dono grava um Session { Token, JobId, ExpiresAt } junto com os dados e renova a cada save.
-- Outro servidor só pega o save quando não há trava, a trava venceu ou o token é o dele.
-- Um save só grava se a trava ainda é do mesmo token (quem perdeu a trava nunca sobrescreve).

local Lease = {}

export type Session = { Token: string, JobId: string, ExpiresAt: number }

function Lease.new(token: string, jobId: string, now: number, seconds: number): Session
	return { Token = token, JobId = jobId, ExpiresAt = now + seconds }
end

-- Pode carregar (e travar) o save?
function Lease.canClaim(session: any, token: string, now: number): boolean
	if type(session) ~= "table" then
		return true
	end
	return session.Token == token or (tonumber(session.ExpiresAt) or 0) <= now
end

-- A trava ainda é minha? (condição para gravar)
function Lease.owns(session: any, token: string): boolean
	return type(session) == "table" and session.Token == token
end

return Lease
