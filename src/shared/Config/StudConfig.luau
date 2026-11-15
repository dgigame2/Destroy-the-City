--!strict
-- Visual de "blocos com stud" (referências de mapa): usa o stud nativo do Roblox nas superfícies das peças.
-- Nenhuma textura própria: SurfaceType.Studs em cima/lados e Inlet embaixo.
-- MaterialVariant: se um dia quiser trocar por uma textura de stud do Toolbox, crie o MaterialVariant
-- dentro de MaterialService no Studio e coloque o nome dele aqui (vazio = não usa).

return table.freeze({
	Material = "Plastic", -- material base das peças com stud
	Surface = "Studs", -- cima e lados
	BottomSurface = "Inlet",
	MaterialVariant = "",
	-- papéis de cor que NÃO recebem stud (luzes e água ficam lisas)
	Smooth = table.freeze({ Light = true, Water = true }),
})
