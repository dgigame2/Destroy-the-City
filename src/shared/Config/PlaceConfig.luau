--!strict
-- Os dois lugares do jogo (mesma experiência no Roblox):
--   Lobby: lugar inicial. Loja, roleta, recompensas, classes e a área "START A RUN" onde as parties se formam.
--   Run: a cidade. Cada party vai para um servidor reservado só dela.
-- Com os ids em 0, o servidor descobre sozinho: o lugar chamado RunPlaceName é a run e o outro é o lobby.
-- Só preencha os ids se der nome diferente ao lugar. No Studio o teleporte nunca funciona.
-- Qual papel cada lugar tem vem do Rojo: ReplicatedStorage.PlaceRole ("Lobby" no default.project.json,
-- "Run" no run.project.json).

return table.freeze({
	RunPlaceName = "Run",
	LobbyPlaceId = 0,
	RunPlaceId = 0,
})
