--!strict
-- Animações procedurais definidas como dados (goat 6.1): para cada quadro-chave, a pose de cada junta.
-- Juntas canônicas (valem para R15; o R6 usa o mapeamento do AnimationController):
--   Root (corpo inteiro), Waist (tronco), Neck (cabeça), LeftArm/RightArm (ombros),
--   LeftForearm/RightForearm (cotovelos, só R15), LeftLeg/RightLeg (quadris), LeftShin/RightShin (joelhos, só R15).
-- Pose de cada junta: { Pitch, Yaw, Roll, Up } em graus / studs (Up só no Root, em studs de escala 1).
--   Pitch positivo = para a frente (braço/perna para frente, cabeça/tronco inclinando para frente).
-- Time em segundos dentro da animação. Loop = a última pose deve ser igual à primeira.

export type JointPose = { Pitch: number?, Yaw: number?, Roll: number?, Up: number? }
export type Keyframe = { Time: number, Pose: { [string]: JointPose } }
export type Animation = { Duration: number, Loop: boolean, Keyframes: { Keyframe } }

local animations: { [string]: Animation } = {
	-- Respiração leve com balanço dos braços.
	Idle = {
		Duration = 2.4,
		Loop = true,
		Keyframes = {
			{
				Time = 0,
				Pose = {
					Root = { Up = 0 },
					Waist = { Pitch = 0 },
					LeftArm = { Roll = -4 },
					RightArm = { Roll = 4 },
					Neck = { Pitch = 0 },
				},
			},
			{
				Time = 1.2,
				Pose = {
					Root = { Up = 0.12 },
					Waist = { Pitch = -2 },
					LeftArm = { Roll = -8 },
					RightArm = { Roll = 8 },
					Neck = { Pitch = -3 },
				},
			},
			{
				Time = 2.4,
				Pose = {
					Root = { Up = 0 },
					Waist = { Pitch = 0 },
					LeftArm = { Roll = -4 },
					RightArm = { Roll = 4 },
					Neck = { Pitch = 0 },
				},
			},
		},
	},
	-- Passo cartunesco: pernas e braços opostos, quique duas vezes por ciclo, tronco inclinado.
	-- Duration é o ciclo em velocidade normal; o controlador acelera conforme a velocidade real.
	Walk = {
		Duration = 0.7,
		Loop = true,
		Keyframes = {
			{
				Time = 0,
				Pose = {
					Root = { Up = 0 },
					Waist = { Pitch = 6, Yaw = 8 },
					LeftLeg = { Pitch = 38 },
					RightLeg = { Pitch = -38 },
					LeftShin = { Pitch = -10 },
					RightShin = { Pitch = -40 },
					LeftArm = { Pitch = -40, Roll = -6 },
					RightArm = { Pitch = 40, Roll = 6 },
					LeftForearm = { Pitch = 10 },
					RightForearm = { Pitch = 30 },
				},
			},
			{
				Time = 0.175,
				Pose = {
					Root = { Up = 0.35 },
					Waist = { Pitch = 6, Yaw = 0 },
					LeftLeg = { Pitch = 0 },
					RightLeg = { Pitch = 0 },
					LeftShin = { Pitch = -45 },
					RightShin = { Pitch = -5 },
					LeftArm = { Pitch = 0, Roll = -6 },
					RightArm = { Pitch = 0, Roll = 6 },
					LeftForearm = { Pitch = 20 },
					RightForearm = { Pitch = 20 },
				},
			},
			{
				Time = 0.35,
				Pose = {
					Root = { Up = 0 },
					Waist = { Pitch = 6, Yaw = -8 },
					LeftLeg = { Pitch = -38 },
					RightLeg = { Pitch = 38 },
					LeftShin = { Pitch = -40 },
					RightShin = { Pitch = -10 },
					LeftArm = { Pitch = 40, Roll = -6 },
					RightArm = { Pitch = -40, Roll = 6 },
					LeftForearm = { Pitch = 30 },
					RightForearm = { Pitch = 10 },
				},
			},
			{
				Time = 0.525,
				Pose = {
					Root = { Up = 0.35 },
					Waist = { Pitch = 6, Yaw = 0 },
					LeftLeg = { Pitch = 0 },
					RightLeg = { Pitch = 0 },
					LeftShin = { Pitch = -5 },
					RightShin = { Pitch = -45 },
					LeftArm = { Pitch = 0, Roll = -6 },
					RightArm = { Pitch = 0, Roll = 6 },
					LeftForearm = { Pitch = 20 },
					RightForearm = { Pitch = 20 },
				},
			},
			{
				Time = 0.7,
				Pose = {
					Root = { Up = 0 },
					Waist = { Pitch = 6, Yaw = 8 },
					LeftLeg = { Pitch = 38 },
					RightLeg = { Pitch = -38 },
					LeftShin = { Pitch = -10 },
					RightShin = { Pitch = -40 },
					LeftArm = { Pitch = -40, Roll = -6 },
					RightArm = { Pitch = 40, Roll = 6 },
					LeftForearm = { Pitch = 10 },
					RightForearm = { Pitch = 30 },
				},
			},
		},
	},
	-- Subindo: braços para cima e para os lados, pernas encolhidas (pose de "estrela").
	Jump = {
		Duration = 0.25,
		Loop = false,
		Keyframes = {
			{
				Time = 0,
				Pose = {
					Waist = { Pitch = 0 },
					LeftArm = { Roll = -20 },
					RightArm = { Roll = 20 },
					LeftLeg = { Pitch = 0 },
					RightLeg = { Pitch = 0 },
				},
			},
			{
				Time = 0.25,
				Pose = {
					Waist = { Pitch = -8 },
					Neck = { Pitch = -10 },
					LeftArm = { Pitch = 20, Roll = -120 },
					RightArm = { Pitch = 20, Roll = 120 },
					LeftForearm = { Pitch = 20 },
					RightForearm = { Pitch = 20 },
					LeftLeg = { Pitch = 30 },
					RightLeg = { Pitch = -10 },
					LeftShin = { Pitch = -60 },
					RightShin = { Pitch = -30 },
				},
			},
		},
	},
	-- Caindo: braços balançando para cima.
	Fall = {
		Duration = 0.5,
		Loop = true,
		Keyframes = {
			{
				Time = 0,
				Pose = {
					LeftArm = { Pitch = 30, Roll = -110 },
					RightArm = { Pitch = 30, Roll = 110 },
					LeftLeg = { Pitch = 15 },
					RightLeg = { Pitch = -15 },
					LeftShin = { Pitch = -30 },
					RightShin = { Pitch = -30 },
				},
			},
			{
				Time = 0.25,
				Pose = {
					LeftArm = { Pitch = 50, Roll = -95 },
					RightArm = { Pitch = 50, Roll = 95 },
					LeftLeg = { Pitch = -15 },
					RightLeg = { Pitch = 15 },
					LeftShin = { Pitch = -20 },
					RightShin = { Pitch = -40 },
				},
			},
			{
				Time = 0.5,
				Pose = {
					LeftArm = { Pitch = 30, Roll = -110 },
					RightArm = { Pitch = 30, Roll = 110 },
					LeftLeg = { Pitch = 15 },
					RightLeg = { Pitch = -15 },
					LeftShin = { Pitch = -30 },
					RightShin = { Pitch = -30 },
				},
			},
		},
	},
	-- Pouso: agacha (squash) e volta.
	Land = {
		Duration = 0.28,
		Loop = false,
		Keyframes = {
			{
				Time = 0,
				Pose = {
					Root = { Up = -0.6 },
					Waist = { Pitch = 14 },
					LeftLeg = { Pitch = 30 },
					RightLeg = { Pitch = 30 },
					LeftShin = { Pitch = -55 },
					RightShin = { Pitch = -55 },
					LeftArm = { Roll = -35 },
					RightArm = { Roll = 35 },
				},
			},
			{
				Time = 0.28,
				Pose = {
					Root = { Up = 0 },
					Waist = { Pitch = 0 },
					LeftLeg = { Pitch = 0 },
					RightLeg = { Pitch = 0 },
					LeftShin = { Pitch = 0 },
					RightShin = { Pitch = 0 },
					LeftArm = { Roll = 0 },
					RightArm = { Roll = 0 },
				},
			},
		},
	},
	-- Mordida: braços agarram para a frente e puxam até a boca, cabeça dá uma "nhac".
	Chomp = {
		Duration = 0.32,
		Loop = false,
		Keyframes = {
			{
				Time = 0,
				Pose = {
					Waist = { Pitch = 0 },
					Neck = { Pitch = 0 },
					LeftArm = { Pitch = 0 },
					RightArm = { Pitch = 0 },
					LeftForearm = { Pitch = 0 },
					RightForearm = { Pitch = 0 },
				},
			},
			{
				Time = 0.1,
				Pose = {
					Waist = { Pitch = 14 },
					Neck = { Pitch = -18 },
					LeftArm = { Pitch = 95, Roll = 10 },
					RightArm = { Pitch = 95, Roll = -10 },
					LeftForearm = { Pitch = 10 },
					RightForearm = { Pitch = 10 },
				},
			},
			{
				Time = 0.2,
				Pose = {
					Waist = { Pitch = 6 },
					Neck = { Pitch = 22 },
					LeftArm = { Pitch = 70, Roll = 25 },
					RightArm = { Pitch = 70, Roll = -25 },
					LeftForearm = { Pitch = 80 },
					RightForearm = { Pitch = 80 },
				},
			},
			{
				Time = 0.32,
				Pose = {
					Waist = { Pitch = 0 },
					Neck = { Pitch = 0 },
					LeftArm = { Pitch = 0, Roll = 0 },
					RightArm = { Pitch = 0, Roll = 0 },
					LeftForearm = { Pitch = 0 },
					RightForearm = { Pitch = 0 },
				},
			},
		},
	},
}

return animations
