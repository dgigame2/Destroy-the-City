--!strict
-- Superfície das peças. Vibe "Diorama" dos mapas: tudo liso (sem stud), plástico suave, cantos chanfrados
-- pelas meshes do kit do Blender (MeshKitConfig). Para voltar ao visual de stud: Material = "Plastic",
-- Surface = "Studs", BottomSurface = "Inlet".
-- MaterialVariant: nome de um MaterialVariant criado em MaterialService no Studio (vazio = não usa).

return table.freeze({
	Material = "SmoothPlastic",
	Surface = "Smooth",
	BottomSurface = "Smooth",
	MaterialVariant = "",
	-- papéis de cor que ficam lisos de qualquer jeito (luzes e água)
	Smooth = table.freeze({ Light = true, Water = true }),
})
