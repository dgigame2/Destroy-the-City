--!strict
-- Feedback triplo de toda ação do jogador (regra da skill goat): SOM + SHAKE + NÚMERO pequeno.
-- client/Feedback.luau toca os três a partir daqui; o teste Feedback.spec confere que todo tipo tem os três.
--
-- Sound: Id, Volume, Pitch (+ Jitter de pitch), MinGap = intervalo mínimo entre dois sons desse tipo.
-- Shake: Camera = força do tremor da câmera (studs, escala com o tamanho do jogador) OU Ui = graus de
--        balanço do botão/painel; Seconds = duração.
-- Number: Color, Format ("+%d", "-%d", texto fixo...), Merge = segundos em que números seguidos se somam.
-- Sons "rbxasset://sounds/..." vêm junto com o Roblox (não precisam de upload).

export type Sound = { Id: string, Volume: number, Pitch: number, Jitter: number, MinGap: number }
export type Shake = { Camera: number?, Ui: number?, Seconds: number }
-- Hidden = true: esse tipo NÃO mostra número (decisão do usuário, 16/11/2026: "+1" a cada clique e no prêmio
-- poluía a tela). O som e o balanço continuam.
export type Number = { Color: { number }, Format: string, Merge: number, Hidden: boolean? }
export type Kind = { Sound: Sound, Shake: Shake, Number: Number }

local POP = "rbxassetid://109359226723492"
local COIN = "rbxassetid://135483737426662"
local TIER_UP = "rbxassetid://134821092416328"

local function sound(id: string, volume: number, pitch: number, jitter: number, minGap: number): Sound
	return { Id = id, Volume = volume, Pitch = pitch, Jitter = jitter, MinGap = minGap }
end

local kinds: { [string]: Kind } = {
	-- comer uma construção (número = dinheiro dela, no mundo)
	Eat = {
		Sound = sound(POP, 0.28, 1, 0.04, 0.06),
		Shake = { Camera = 0.06, Seconds = 0.12 },
		Number = { Color = { 125, 255, 138 }, Format = "+%d 💵", Merge = 0 },
	},
	-- lançou um desastre (número = nome curto do desastre, vindo do Text)
	Cast = {
		Sound = sound("rbxasset://sounds/swoosh.wav", 0.3, 1.2, 0.08, 0.1),
		Shake = { Camera = 0.25, Seconds = 0.2 },
		Number = { Color = { 255, 227, 107 }, Format = "%d", Merge = 0 },
	},
	-- reação em cadeia passou de um degrau (número = tamanho da cadeia)
	Chain = {
		Sound = sound("rbxasset://sounds/electronicpingshort.wav", 0.4, 0.8, 0.05, 0.3),
		Shake = { Camera = 0.7, Seconds = 0.35 },
		Number = { Color = { 255, 160, 60 }, Format = "x%d", Merge = 0 },
	},
	-- desastre subiu de nível (número = nível novo, no painel de níveis)
	Level = {
		Sound = sound(TIER_UP, 0.45, 1.2, 0, 0.2),
		Shake = { Ui = 10, Seconds = 0.3 },
		Number = { Color = { 255, 227, 107 }, Format = "LV %d", Merge = 0 },
	},
	-- qualquer botão (número = "+1" pequeno no botão: confirma o toque)
	Click = {
		Sound = sound("rbxasset://sounds/switch.wav", 0.25, 1.1, 0.05, 0.05),
		Shake = { Ui = 4, Seconds = 0.15 },
		Number = { Color = { 255, 255, 255 }, Format = "+%d", Merge = 0.3, Hidden = true },
	},
	-- compra feita (loja, upgrade, roleta paga): número = quanto gastou
	Buy = {
		Sound = sound(COIN, 0.35, 1.15, 0.03, 0.1),
		Shake = { Ui = 10, Seconds = 0.25 },
		Number = { Color = { 255, 214, 70 }, Format = "-%d", Merge = 0 },
	},
	-- não deu (sem dinheiro, roleta indisponível): número = quanto falta (ou "x")
	Fail = {
		Sound = sound("rbxasset://sounds/clickfast.wav", 0.35, 0.6, 0, 0.15),
		Shake = { Ui = 14, Seconds = 0.3 },
		Number = { Color = { 255, 110, 110 }, Format = "✖ %d", Merge = 0 },
	},
	-- ganhou dinheiro/gemas (prêmio, roleta, vitória): número no contador do HUD
	Coins = {
		Sound = sound(COIN, 0.1, 1, 0.05, 0.25),
		Shake = { Ui = 4, Seconds = 0.15 },
		Number = { Color = { 125, 255, 138 }, Format = "%+d", Merge = 0.4 },
	},
	Gems = {
		Sound = sound("rbxasset://sounds/electronicpingshort.wav", 0.3, 1.3, 0.05, 0.2),
		Shake = { Ui = 8, Seconds = 0.2 },
		Number = { Color = { 120, 220, 255 }, Format = "%+d 💎", Merge = 0.4 },
	},
	-- prêmio resgatado (diário/semanal) ou prêmio especial
	Reward = {
		Sound = sound("rbxasset://sounds/electronicpingshort.wav", 0.45, 1, 0, 0.2),
		Shake = { Ui = 4, Seconds = 0.25 }, -- o cartão do prêmio é grande: balanço leve (antes 12 "tremia a tela")
		Number = { Color = { 255, 227, 107 }, Format = "+%d", Merge = 0, Hidden = true }, -- o cartão já mostra o prêmio
	},
	-- roleta girando
	Spin = {
		Sound = sound("rbxasset://sounds/swoosh.wav", 0.4, 1, 0.05, 0.3),
		Shake = { Ui = 8, Seconds = 0.25 },
		Number = { Color = { 255, 255, 255 }, Format = "-%d", Merge = 0 },
	},
	-- cresceu e pode comer coisas maiores (número = novo tamanho)
	TierUp = {
		Sound = sound(TIER_UP, 0.6, 1, 0, 0.3),
		Shake = { Camera = 0.6, Seconds = 0.35 },
		Number = { Color = { 255, 227, 107 }, Format = "SIZE %d", Merge = 0 },
	},
	-- área limpa (número = gemas ganhas)
	ZoneClear = {
		Sound = sound(TIER_UP, 0.7, 0.85, 0, 1),
		Shake = { Camera = 1.2, Seconds = 0.6 },
		Number = { Color = { 120, 220, 255 }, Format = "+%d 💎", Merge = 0 },
	},
}

return table.freeze({
	Kinds = table.freeze(kinds),
	MaxCameraShake = 1.5, -- teto (studs na escala 1): tremores seguidos não se somam sem limite
	NumberSeconds = 0.8, -- número sobe e some em menos de 1 segundo
	NumberRise = 40, -- pixels que o número sobe na tela
	NumberSize = 26, -- altura do número (px, na escala da UI)
})
