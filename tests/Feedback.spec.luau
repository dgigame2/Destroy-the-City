-- Regra da skill goat: toda ação do jogador tem SOM + SHAKE + NÚMERO (Config/FeedbackConfig).
local FeedbackConfig = require("../src/shared/Config/FeedbackConfig")
local Shake = require("../src/shared/Logic/Shake")

-- ações do jogo que precisam de feedback (cada uma tem que existir no FeedbackConfig)
local ACTIONS = {
	"Cast",
	"Chain",
	"Level",
	"Eat",
	"Click",
	"Buy",
	"Fail",
	"Coins",
	"Gems",
	"Reward",
	"Spin",
	"TierUp",
	"ZoneClear",
	"Burst", -- fim de uma leva grande de destruição
}

return function(t)
	for _, name in ACTIONS do
		t.test(`feedback "{name}": tem som, shake e número`, function()
			local kind = FeedbackConfig.Kinds[name]
			t.truthy(kind ~= nil)
			t.truthy(type(kind.Sound.Id) == "string" and #kind.Sound.Id > 0)
			t.truthy(kind.Sound.Volume > 0 and kind.Sound.Volume <= 1)
			t.truthy((kind.Shake.Camera or 0) > 0 or (kind.Shake.Ui or 0) > 0)
			t.truthy(kind.Shake.Seconds > 0 and kind.Shake.Seconds <= 1)
			t.truthy(type(kind.Number.Format) == "string" and #kind.Number.Format > 0)
			-- número escondido só onde o usuário pediu (clique e prêmio)
			if kind.Number.Hidden then
				t.truthy(name == "Click" or name == "Reward")
			end
			-- o formato aceita um número inteiro
			t.truthy(type(string.format(kind.Number.Format, 12)) == "string")
		end)
	end

	t.test("todo tipo do FeedbackConfig está na lista de ações testadas", function()
		local listed = {}
		for _, name in ACTIONS do
			listed[name] = true
		end
		for name in FeedbackConfig.Kinds do
			t.truthy(listed[name])
		end
	end)

	t.test("clique e prêmio não mostram número (pedido do usuário: poluía a tela)", function()
		t.truthy(FeedbackConfig.Kinds.Click.Number.Hidden)
		t.truthy(FeedbackConfig.Kinds.Reward.Number.Hidden)
		t.truthy((FeedbackConfig.Kinds.Reward.Shake.Ui :: number) <= 5)
	end)

	t.test("número some em menos de 1 segundo", function()
		t.truthy(FeedbackConfig.NumberSeconds < 1)
	end)

	t.test("ações frequentes: som baixo e com intervalo mínimo (comer e dinheiro)", function()
		for _, name in { "Eat", "Coins", "Click" } do
			local s = FeedbackConfig.Kinds[name].Sound
			t.truthy(s.Volume <= 0.3 and s.MinGap > 0)
		end
		t.truthy(FeedbackConfig.Kinds.Coins.Sound.Volume < FeedbackConfig.Kinds.Eat.Sound.Volume)
	end)

	t.test("shake: tremores seguidos não passam do teto", function()
		local v = 0
		for _ = 1, 100 do
			v = Shake.add(v, FeedbackConfig.Kinds.Eat.Shake.Camera :: number, FeedbackConfig.MaxCameraShake)
		end
		t.near(v, FeedbackConfig.MaxCameraShake)
	end)

	t.test("shake: decai até zero no tempo certo", function()
		t.near(Shake.decay(1, 1, 0.5, 0.25), 0.5)
		t.near(Shake.decay(1, 1, 0.5, 1), 0)
	end)

	t.test("balanço da UI começa e termina parado", function()
		t.near(Shake.uiAngle(10, 0), 0)
		t.near(Shake.uiAngle(10, 1), 0)
		t.truthy(math.abs(Shake.uiAngle(10, 0.08)) > 0)
	end)

	t.test("números seguidos se somam dentro da janela", function()
		t.equal(Shake.merge(5, 10, 3, 10.2, 0.4), 8)
		t.equal(Shake.merge(5, 10, 3, 11, 0.4), 3)
		t.equal(Shake.merge(5, 10, 3, 10.1, 0), 3)
	end)
end
