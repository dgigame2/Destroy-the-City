--!strict
-- Interpola as poses do AnimationConfig no tempo. Função pura (testável fora do Roblox).

export type JointPose = { Pitch: number?, Yaw: number?, Roll: number?, Up: number? }
export type Keyframe = { Time: number, Pose: { [string]: JointPose } }
export type Animation = { Duration: number, Loop: boolean, Keyframes: { Keyframe } }
export type Sample = { [string]: { Pitch: number, Yaw: number, Roll: number, Up: number } }

local CHANNELS = { "Pitch", "Yaw", "Roll", "Up" }

local AnimSampler = {}

-- Suavização seno (entra e sai devagar).
local function ease(alpha: number): number
	return (1 - math.cos(alpha * math.pi)) / 2
end

local function value(pose: JointPose?, channel: string): number
	return if pose then (pose :: any)[channel] or 0 else 0
end

-- Pose de todas as juntas no tempo t (em segundos). Animações em loop dão a volta; as outras param no fim.
function AnimSampler.sample(animation: Animation, t: number): Sample
	local frames = animation.Keyframes
	local time = if animation.Loop then t % animation.Duration else math.clamp(t, 0, animation.Duration)
	local a, b = frames[1], frames[#frames]
	for i = 1, #frames - 1 do
		if time >= frames[i].Time and time <= frames[i + 1].Time then
			a, b = frames[i], frames[i + 1]
			break
		end
	end
	local span = b.Time - a.Time
	local alpha = if span > 0 then ease((time - a.Time) / span) else 0

	local joints: { [string]: boolean } = {}
	for joint in a.Pose do
		joints[joint] = true
	end
	for joint in b.Pose do
		joints[joint] = true
	end
	local result: Sample = {}
	for joint in joints do
		local out: any = { Pitch = 0, Yaw = 0, Roll = 0, Up = 0 }
		for _, channel in CHANNELS do
			local from, to = value(a.Pose[joint], channel), value(b.Pose[joint], channel)
			out[channel] = from + (to - from) * alpha
		end
		result[joint] = out
	end
	return result
end

-- Mistura duas amostras: weight 0 = só a, 1 = só b. Juntas que faltam contam como pose neutra.
function AnimSampler.blend(a: Sample, b: Sample, weight: number): Sample
	local result: Sample = {}
	local joints: { [string]: boolean } = {}
	for joint in a do
		joints[joint] = true
	end
	for joint in b do
		joints[joint] = true
	end
	for joint in joints do
		local pa: any = a[joint] or { Pitch = 0, Yaw = 0, Roll = 0, Up = 0 }
		local pb: any = b[joint] or { Pitch = 0, Yaw = 0, Roll = 0, Up = 0 }
		local out: any = { Pitch = 0, Yaw = 0, Roll = 0, Up = 0 }
		for _, channel in CHANNELS do
			out[channel] = pa[channel] + (pb[channel] - pa[channel]) * weight
		end
		result[joint] = out
	end
	return result
end

-- Soma uma camada por cima (ex.: mordida enquanto anda), com peso.
function AnimSampler.add(base: Sample, layer: Sample, weight: number): Sample
	local result: Sample = table.clone(base)
	for joint, pose in layer do
		local current: any = result[joint] or { Pitch = 0, Yaw = 0, Roll = 0, Up = 0 }
		local layerPose: any = pose
		local out: any = { Pitch = 0, Yaw = 0, Roll = 0, Up = 0 }
		for _, channel in CHANNELS do
			out[channel] = current[channel] + layerPose[channel] * weight
		end
		result[joint] = out
	end
	return result
end

return AnimSampler
