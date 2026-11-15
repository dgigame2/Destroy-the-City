--!strict
-- Único lugar onde os nomes de RemoteEvents/RemoteFunctions existem.

return table.freeze({
	Events = table.freeze({
		BuildingEaten = "BuildingEaten", -- servidor -> todos: (model, eater, coins, gems)
		WheelSpun = "WheelSpun", -- servidor -> todos: (player, segmentIndex)
		RewardGranted = "RewardGranted", -- servidor -> cliente: (text, icon)
		LeaveMatch = "LeaveMatch", -- cliente -> servidor: () sair da run e voltar ao lobby
		PartyPrompt = "PartyPrompt", -- servidor -> dono do quadrado: (padIndex) abrir CREATE PARTY
		PartyClosed = "PartyClosed", -- servidor -> dono: () fechar CREATE PARTY (saiu do quadrado / tempo)
		Notice = "Notice", -- servidor -> cliente: (texto) aviso na tela
		ZoneCleared = "ZoneCleared", -- servidor -> todos: ({Zone, Name, Next, NextIndex, Gems, Cash, Frenzy, Gate})
	}),
	Functions = table.freeze({
		BuyUpgrade = "BuyUpgrade", -- cliente -> servidor: (upgradeId) -> sucesso
		BuyItem = "BuyItem", -- (itemOuClasseId) -> (sucesso, motivo)
		EquipItem = "EquipItem", -- (itemOuClasseId) -> sucesso
		ClaimDaily = "ClaimDaily", -- () -> sucesso
		ClaimWeekly = "ClaimWeekly", -- () -> sucesso
		SpinWheel = "SpinWheel", -- ("Free" | "Extra" | "Gems") -> índice da fatia ou nil
		CreateParty = "CreateParty", -- (padIndex, {Map, Difficulty, Size}) -> (sucesso, motivo)
		LoadRun = "LoadRun", -- (padIndex, runId) -> (sucesso, motivo)
		CancelParty = "CancelParty", -- (padIndex) -> () botão BACK
	}),
})
