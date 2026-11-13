-- Verificações de animação do goat (6.4) sobre os dados: poses possíveis, loops sem salto,
-- transições suaves (sem movimentos bruscos) e amostragem correta.
local AnimSampler = require("../src/shared/Logic/AnimSampler")
local AnimationConfig = require("../src/shared/Config/AnimationConfig")

local JOINTS = {
	Root = true,
	Waist = true,
	Neck = true,
	LeftArm = true,
	RightArm = true,
	LeftForearm = true,
	RightForearm = true,
	LeftLeg = true,
	RightLeg = true,
	LeftShin = true,
	RightShin = true,
}

-- Limites de pose possíveis (graus). Joelhos e cotovelos só dobram para um lado.
local LIMITS = {
	Neck = { Pitch = { -35, 35 }, Yaw = { -45, 45 }, Roll = { -20, 20 } },
	Waist = { Pitch = { -25, 30 }, Yaw = { -30, 30 }, Roll = { -20, 20 } },
	LeftShin = { Pitch = { -120, 0 } },
	RightShin = { Pitch = { -120, 0 } },
	LeftForearm = { Pitch = { 0, 130 } },
	RightForearm = { Pitch = { 0, 130 } },
	LeftLeg = { Pitch = { -60, 90 } },
	RightLeg = { Pitch = { -60, 90 } },
	LeftArm = { Pitch = { -60, 160 }, Roll = { -150, 40 } },
	RightArm = { Pitch = { -60, 160 }, Roll = { -40, 150 } },
	Root = { Up = { -1, 1 } },
}

local MAX_DEGREES_PER_SECOND = 1200 -- acima disso o movimento fica brusco demais

return function(t)
	for name, animation in AnimationConfig do
		t.test(`{name}: só juntas conhecidas`, function()
			for _, frame in animation.Keyframes do
				for joint in frame.Pose do
					if not JOINTS[joint] then
						error(`junta desconhecida: {joint}`)
					end
				end
			end
		end)

		t.test(`{name}: tempos crescentes, começa em 0 e termina na duração`, function()
			local frames = animation.Keyframes
			t.equal(frames[1].Time, 0)
			t.near(frames[#frames].Time, animation.Duration)
			for i = 2, #frames do
				t.truthy(frames[i].Time > frames[i - 1].Time)
			end
		end)

		t.test(`{name}: nenhuma pose impossível (limites das juntas)`, function()
			for _, frame in animation.Keyframes do
				for joint, pose in frame.Pose do
					local limits = LIMITS[joint]
					if limits then
						for channel, range in limits do
							local v = (pose :: any)[channel] or 0
							if v < range[1] or v > range[2] then
								error(`{joint}.{channel} = {v} fora de [{range[1]}, {range[2]}] em t={frame.Time}`)
							end
						end
					end
				end
			end
		end)

		if animation.Loop then
			t.test(`{name}: loop sem salto (última pose = primeira)`, function()
				local first = AnimSampler.sample(animation, 0)
				local last = AnimSampler.sample(animation, animation.Duration - 1e-6)
				for joint, pose in first do
					for channel, v in pose do
						t.truthy(math.abs(v - (last[joint] :: any)[channel]) < 0.5)
					end
				end
			end)
		end

		t.test(`{name}: sem movimento brusco entre quadros`, function()
			local frames = animation.Keyframes
			for i = 2, #frames do
				local dt = frames[i].Time - frames[i - 1].Time
				for joint, pose in frames[i].Pose do
					local before = frames[i - 1].Pose[joint] or {}
					for _, channel in { "Pitch", "Yaw", "Roll" } do
						local delta = math.abs(((pose :: any)[channel] or 0) - ((before :: any)[channel] or 0))
						if delta / dt > MAX_DEGREES_PER_SECOND then
							error(`{joint}.{channel} muda {delta}° em {dt}s`)
						end
					end
				end
			end
		end)
	end

	t.test("amostra no quadro-chave devolve a pose do quadro", function()
		local walk = AnimationConfig.Walk
		local sample = AnimSampler.sample(walk, walk.Keyframes[3].Time)
		t.near(sample.LeftLeg.Pitch, walk.Keyframes[3].Pose.LeftLeg.Pitch :: number)
	end)

	t.test("meio do caminho fica entre os dois quadros", function()
		local walk = AnimationConfig.Walk
		local mid = AnimSampler.sample(walk, walk.Keyframes[2].Time / 2)
		t.truthy(mid.LeftLeg.Pitch < 38 and mid.LeftLeg.Pitch > 0)
	end)

	t.test("animação sem loop para no fim", function()
		local land = AnimationConfig.Land
		local after = AnimSampler.sample(land, land.Duration + 5)
		t.near(after.Root.Up, 0)
	end)

	t.test("blend e add", function()
		local a = { Neck = { Pitch = 0, Yaw = 0, Roll = 0, Up = 0 } }
		local b = { Neck = { Pitch = 20, Yaw = 0, Roll = 0, Up = 0 } }
		t.near(AnimSampler.blend(a, b, 0.5).Neck.Pitch, 10)
		t.near(AnimSampler.add(b, b, 0.5).Neck.Pitch, 30)
	end)
end
