--!strict
-- Único lugar onde os nomes de RemoteEvents/RemoteFunctions existem.

return table.freeze({
	Events = table.freeze({
		-- partida nova (AUDITORIA §8.2): só ids e buffers, nunca Instance
		CityDelta = "CityDelta", -- servidor -> todos: (buffer Protocol.Delta) vida/destruição em lote
		Cast = "Cast", -- cliente -> servidor: (elementId, alvo: Vector3) o servidor valida tudo
		Milestone = "Milestone", -- servidor -> todos: (índice, fração) marco 25/50/75/100% alcançado
		RewardGranted = "RewardGranted", -- servidor -> cliente: (text, icon)
		LeaveMatch = "LeaveMatch", -- cliente -> servidor: () sair da run e voltar ao lobby
		PartyPrompt = "PartyPrompt", -- servidor -> dono do quadrado: (padIndex) abrir CREATE PARTY
		PartyClosed = "PartyClosed", -- servidor -> dono: () fechar CREATE PARTY (saiu do quadrado / tempo)
		Notice = "Notice", -- servidor -> cliente: (texto) aviso na tela
		Burst = "Burst", -- cliente -> servidor: (dirX, dirZ) rajada do tornado; recarga e alvo conferidos no servidor
		Died = "Died", -- servidor -> vítima: (nome de quem matou, nível, XP perdido, nível de quem matou) tela de morte
		Killed = "Killed", -- servidor -> quem matou: (nome da vítima, XP ganho) comemoração
		Knock = "Knock", -- servidor -> vítima: (vx, vz, segundos) empurrão (sucção); o cliente move o próprio tornado
	}),
	-- UnreliableRemoteEvent: só cosmético (perder um não muda o estado da cidade)
	Unreliable = table.freeze({
		-- servidor -> todos: (elementId, casterUserId, alvo: Vector3, nível, semente, origem: Vector3). Cada cliente
		-- remonta o MESMO golpe (Logic/ElementPlan) e desenha cada pulso; nada de lista de pulsos na rede.
		CastFx = "CastFx",
		ChainFx = "ChainFx", -- servidor -> todos: (casterUserId, pontos: { Vector3 }) saltos do raio em cadeia
		BurnFx = "BurnFx", -- servidor -> todos: (ids: { number }, segundos) construções que pegaram fogo
		BurstFx = "BurstFx", -- servidor -> todos: (origem: Vector3, dirX, dirZ, alcance) efeito da rajada
		-- servidor -> todos: (skill, userId, início, ox, oy, oz, dirX, dirZ, raio) Q começou; o cliente calcula as zonas
		SkillFx = "SkillFx",
		SkillEndFx = "SkillEndFx", -- servidor -> todos: (userId, x, z, raio, força) explosão final do Q
	}),
	Functions = table.freeze({
		CitySnapshot = "CitySnapshot", -- cliente -> servidor: () -> buffer Protocol.Snapshot (entrada/seq perdido)
		BuyItem = "BuyItem", -- (itemId) -> (sucesso, motivo)
		EquipItem = "EquipItem", -- (itemId) -> sucesso
		ClaimDaily = "ClaimDaily", -- () -> sucesso
		ClaimWeekly = "ClaimWeekly", -- () -> sucesso
		Rebirth = "Rebirth", -- () -> sucesso (o servidor confere nível máximo, barra cheia e rebirths)
		Evolve = "Evolve", -- () -> sucesso (sobe 1 nível com a barra cheia; o servidor confere)
		Special = "Special", -- (dirX, dirZ) -> nome da skill ou nil (Q; o servidor confere vida, forma e recarga)
		CreateParty = "CreateParty", -- (padIndex, {Map, Difficulty, Size}) -> (sucesso, motivo)
		CancelParty = "CancelParty", -- (padIndex) -> () botão BACK
	}),
})
