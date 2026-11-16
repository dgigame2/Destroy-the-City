--!strict
-- Mira dos desastres (client/Controllers/AimVisual): círculo tracejado girando no chão e, no tornado, uma
-- fileira de setas andando na direção em que ele vai. Medidas relativas ao raio do desastre (r).

return table.freeze({
	Dashes = 20, -- traços no círculo
	DashFill = 0.55, -- quanto de cada trecho é traço (o resto é vão)
	DashWidth = 0.06, -- largura do traço (x r), com mínimo MinWidth
	MinWidth = 0.8,
	Spin = 0.5, -- giro do tracejado (radianos por segundo)
	FillTransparency = 0.82, -- disco clarinho dentro do círculo
	LineTransparency = 0.1,
	Lift = 0.6, -- altura acima do chão (studs)
	-- brilho (pedido do usuário): traços e setas em neon + luz colorida no centro da mira
	Glow = table.freeze({ Material = "Neon", LightBrightness = 2.5, LightRange = 1.6 }), -- alcance da luz = r x isso
	Thickness = 0.5, -- espessura dos traços e setas (aparecem por cima de calçadas e canteiros baixos)

	-- setas do tornado ("V" apontando para a frente)
	ArrowSpacing = 1.3, -- distância entre setas (x r)
	ArrowSize = 0.75, -- comprimento de cada perna da seta (x r)
	ArrowLift = 1.5, -- setas um pouco acima do chão (passam por cima de canteiros e calçadas)
	ArrowAngle = 35, -- abertura de cada perna em relação ao caminho (graus)
	ArrowFlow = 1.5, -- setas por segundo andando para a frente
	MaxArrows = 16,
})
