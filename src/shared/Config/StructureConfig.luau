--!strict
-- Resistência das construções contra desastres (Logic/Disasters).
-- HP = HpPerScale x RequiredScale do tier (TierConfig): com o poder igual ao exigido pelo tier, um meteoro
-- no centro derruba em ~1 acerto; com mais poder, cai mais rápido. Abaixo do exigido o desastre arranha pouco:
-- o dano vira UnderPower x (poder / exigido) do normal. Toda construção da área leva dano, mas as fortes
-- (avião, hangar, arranha-céu) levam muitos acertos até você ficar mais forte.
-- Conductors: modelos que conduzem o raio (não perdem força e esticam o pulo).

return table.freeze({
	HpPerScale = 120,
	UnderPower = 0.35,
	Conductors = table.freeze({
		Lamp = true,
		PowerPylon = true, -- torre de transmissão: o raio adora
		Hydrant = true,
		Car = true,
		BusStop = true,
		Crane = true,
		TVTower = true,
		Lighthouse = true,
		ControlTower = true,
		CoolingTower = true,
		FactoryHall = true,
		ContainerStack = true,
		GlassTower = true,
		SpireTower = true,
		Hangar = true,
	}),
})
