--!strict
-- Aplica a iluminação do LightingConfig (referência 1: dia ensolarado, saturado, céu azul).

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LightingConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.LightingConfig)

local LightingService = {}

local function color(rgb: { number }): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local function ensure<T>(className: string, parent: Instance): T
	local existing = parent:FindFirstChildOfClass(className)
	if existing then
		return existing :: any
	end
	local created = Instance.new(className)
	created.Parent = parent
	return created :: any
end

function LightingService.apply()
	local c = LightingConfig
	Lighting.ClockTime = c.ClockTime
	Lighting.Brightness = c.Brightness
	Lighting.Ambient = color(c.Ambient)
	Lighting.OutdoorAmbient = color(c.OutdoorAmbient)
	Lighting.EnvironmentDiffuseScale = c.EnvironmentDiffuseScale
	Lighting.EnvironmentSpecularScale = c.EnvironmentSpecularScale
	Lighting.ShadowSoftness = c.ShadowSoftness
	Lighting.ExposureCompensation = c.ExposureCompensation
	Lighting.GlobalShadows = true

	local cc = ensure("ColorCorrectionEffect", Lighting) :: ColorCorrectionEffect
	cc.Saturation = c.ColorCorrection.Saturation
	cc.Contrast = c.ColorCorrection.Contrast
	cc.Brightness = c.ColorCorrection.Brightness
	cc.TintColor = color(c.ColorCorrection.TintColor)

	local bloom = ensure("BloomEffect", Lighting) :: BloomEffect
	bloom.Intensity = c.Bloom.Intensity
	bloom.Size = c.Bloom.Size
	bloom.Threshold = c.Bloom.Threshold

	local atmosphere = ensure("Atmosphere", Lighting) :: Atmosphere
	atmosphere.Density = c.Atmosphere.Density
	atmosphere.Offset = c.Atmosphere.Offset
	atmosphere.Color = color(c.Atmosphere.Color)
	atmosphere.Decay = color(c.Atmosphere.Decay)
	atmosphere.Glare = c.Atmosphere.Glare
	atmosphere.Haze = c.Atmosphere.Haze

	local rays = ensure("SunRaysEffect", Lighting) :: SunRaysEffect
	rays.Intensity = c.SunRays.Intensity
	rays.Spread = c.SunRays.Spread

	ensure("Sky", Lighting)
	local clouds = ensure("Clouds", Workspace.Terrain) :: Clouds
	clouds.Cover = c.Clouds.Cover
	clouds.Density = c.Clouds.Density
	clouds.Color = color(c.Clouds.Color)
end

export type BiomeLighting = {
	Ambient: { number },
	OutdoorAmbient: { number },
	AtmosphereColor: { number },
	AtmosphereDecay: { number },
	AtmosphereDensity: number,
	Haze: number,
	Glare: number,
	Saturation: number,
	Contrast: number,
	TintColor: { number },
	ClockTime: number, -- hora do dia (posição do sol e comprimento das sombras)
	Brightness: number,
	ShadowSoftness: number,
	Bloom: { Intensity: number, Size: number, Threshold: number },
	SunRays: { Intensity: number, Spread: number },
	Clouds: { Cover: number, Density: number, Color: { number } },
}

-- Clima do mapa atual: hora do dia, sol, nuvens, névoa e cores (manhã de jardim, tarde tropical,
-- sol baixo de inverno).
function LightingService.applyBiome(b: BiomeLighting)
	Lighting.ClockTime = b.ClockTime
	Lighting.Brightness = b.Brightness
	Lighting.ShadowSoftness = b.ShadowSoftness
	Lighting.Ambient = color(b.Ambient)
	Lighting.OutdoorAmbient = color(b.OutdoorAmbient)
	local atmosphere = ensure("Atmosphere", Lighting) :: Atmosphere
	atmosphere.Color = color(b.AtmosphereColor)
	atmosphere.Decay = color(b.AtmosphereDecay)
	atmosphere.Density = b.AtmosphereDensity
	atmosphere.Haze = b.Haze
	atmosphere.Glare = b.Glare
	local cc = ensure("ColorCorrectionEffect", Lighting) :: ColorCorrectionEffect
	cc.Saturation = b.Saturation
	cc.Contrast = b.Contrast
	cc.TintColor = color(b.TintColor)
	local bloom = ensure("BloomEffect", Lighting) :: BloomEffect
	bloom.Intensity = b.Bloom.Intensity
	bloom.Size = b.Bloom.Size
	bloom.Threshold = b.Bloom.Threshold
	local rays = ensure("SunRaysEffect", Lighting) :: SunRaysEffect
	rays.Intensity = b.SunRays.Intensity
	rays.Spread = b.SunRays.Spread
	local clouds = ensure("Clouds", Workspace.Terrain) :: Clouds
	clouds.Cover = b.Clouds.Cover
	clouds.Density = b.Clouds.Density
	clouds.Color = color(b.Clouds.Color)
end

return LightingService
