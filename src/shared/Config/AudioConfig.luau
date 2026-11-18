--!strict
-- Ritmo do combo de mordidas. Os sons de cada ação ficam em Config/FeedbackConfig (som + shake + número).

return table.freeze({
	ComboWindowSeconds = 1.5, -- mordidas com menos que isso entre elas contam como combo
	-- Sons que o Roblox cria no HumanoidRootPart de todo personagem: ficam mudos (sem passos, pulo, queda...).
	MutedCharacterSounds = table.freeze({
		"Running",
		"Climbing",
		"Jumping",
		"Landing",
		"FreeFalling",
		"GettingUp",
		"Swimming",
		"Splash",
		"Died",
	}),
})
