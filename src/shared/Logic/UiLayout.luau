--!strict
-- Escala das interfaces para qualquer tamanho de tela. Função pura.

local UiLayout = {}

export type UiConfig = { DesignWidth: number, DesignHeight: number, MinScale: number, MaxScale: number }

-- O layout de referência cabe inteiro na tela (usa o lado mais apertado).
function UiLayout.scale(viewportW: number, viewportH: number, config: UiConfig): number
	local s = math.min(viewportW / config.DesignWidth, viewportH / config.DesignHeight)
	return math.clamp(s, config.MinScale, config.MaxScale)
end

return UiLayout
