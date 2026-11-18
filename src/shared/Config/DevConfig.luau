--!strict
-- Ferramentas de desenvolvedor (só para quem está em Admins, ou no Studio).
-- /noclip no chat: liga/desliga o voo atravessando tudo (WASD + câmera, Espaço sobe, Ctrl/Q desce,
-- Shift acelera). É só no cliente: mexe no próprio personagem.

return table.freeze({
	Admins = table.freeze({ 509787337 }), -- UserIds que podem usar
	NoclipCommand = "/noclip",
	FlySpeed = 60,
	FastSpeed = 160,
})
