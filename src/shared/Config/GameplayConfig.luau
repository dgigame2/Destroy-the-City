--!strict
-- Chave da migração (Eat City -> desastres). Rollback: troque Mode para "Eat" e o jogo volta ao comer antigo
-- (EatService come em volta, personagem cresce). Em "Disasters" o personagem não cresce: o crescimento vira o
-- PODER dos desastres (atributo Power), e as construções caem pelos desastres (server/DisasterService).
-- Não remova o modo "Eat" antes de validar os desastres no Studio.

return table.freeze({
	Mode = "Disasters", -- "Disasters" | "Eat"
})
