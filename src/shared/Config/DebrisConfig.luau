--!strict
-- Objetos físicos voando (Logic/Debris + server/DebrisService).
--   Tornado: objetos leves (Lift.Tiers) dentro de Lift.Radius x raio do funil são arrancados, PUXADOS para o
--            funil, giram em volta dele e depois são ARREMESSADOS para fora (ThrowChance) ou caem perto.
--   Explosões e desabamentos: soltam Blast.Pieces pedaços que voam em volta.
-- O que voa acerta construções no caminho e onde cai: dano = HP do objeto x ImpactDamage (cai até
-- ImpactEdge na borda de ImpactRadius). Conta como reação em cadeia (respeita ChainConfig.MaxDepth).
-- Física no servidor (dono da rede = servidor): todos os jogadores veem o mesmo voo.
-- Celular/servidor: no máximo MaxActive objetos voando ao mesmo tempo; cada um some em até Lifetime s.

return table.freeze({
	MaxActive = 14,
	MaxParts = 8, -- peças copiadas do modelo; acima disso voa uma caixa da cor dele
	Lifetime = 4,
	CheckEvery = 0.1, -- segundos entre as checagens de batida
	Gravity = 196.2, -- gravidade padrão do Roblox (Workspace.Gravity)
	Lift = table.freeze({
		Radius = 2.2, -- x raio do funil
		Tiers = table.freeze({ Prop = true, Small = true }),
		OrbitTime = 0.9, -- segundos girando no funil antes de sair
		Swirl = 26, -- studs/s em volta do funil
		Pull = 30, -- studs/s para dentro (até o anel de giro)
		OrbitRadius = 0.8, -- x raio do funil: anel onde giram
		Rise = 12, -- studs/s subindo enquanto giram
	}),
	ThrowChance = 0.65, -- o resto cai perto do funil
	ThrowSpeed = 55, -- studs/s para fora
	ThrowLift = 28, -- studs/s para cima na saída
	ImpactRadius = 7,
	ImpactDamage = 1.3, -- x HP do objeto que voou
	ImpactEdge = 0.4,
	Blast = table.freeze({
		Pieces = 2, -- por explosão/desabamento
		Speed = 38,
		Lift = 34,
		Size = 0.18, -- x maior lado da construção (pedaço)
		DamageFactor = 0.25, -- x HP da construção que caiu, dividido entre os pedaços
	}),
})
