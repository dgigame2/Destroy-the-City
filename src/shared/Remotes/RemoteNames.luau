--!strict
-- Único lugar onde os nomes de RemoteEvents/RemoteFunctions existem.

return table.freeze({
	Events = table.freeze({
		BuildingEaten = "BuildingEaten", -- servidor -> todos: (model, eater, coins, gems)
		BuildingRegenerated = "BuildingRegenerated", -- servidor -> todos: (model)
		PlayerEaten = "PlayerEaten", -- servidor -> todos: (eater, victim)
		VoteStarted = "VoteStarted", -- servidor -> todos: (options, endsAt)
		VoteUpdated = "VoteUpdated", -- servidor -> todos: (counts)
		CastVote = "CastVote", -- cliente -> servidor: (mapId)
		WheelSpun = "WheelSpun", -- servidor -> todos: (player, segmentIndex)
		RewardGranted = "RewardGranted", -- servidor -> cliente: (text, icon)
		JoinMatch = "JoinMatch", -- cliente -> servidor: () entrar na partida em andamento
		SetAutoJoin = "SetAutoJoin", -- cliente -> servidor: (bool) entrar sozinho na próxima partida
	}),
	Functions = table.freeze({
		BuyUpgrade = "BuyUpgrade", -- cliente -> servidor: (upgradeId) -> sucesso
		BuyItem = "BuyItem", -- (itemOuClasseId) -> (sucesso, motivo)
		EquipItem = "EquipItem", -- (itemOuClasseId) -> sucesso
		ClaimDaily = "ClaimDaily", -- () -> sucesso
		ClaimWeekly = "ClaimWeekly", -- () -> sucesso
		SpinWheel = "SpinWheel", -- ("Free" | "Extra" | "Gems") -> índice da fatia ou nil
	}),
})
