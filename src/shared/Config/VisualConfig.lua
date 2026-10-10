--!strict
-- Performance-aware visual quality presets. Gameplay must never depend on graphics quality.
return {
    DefaultQuality = "High",
    Presets = {
        Low = {CrowdEnabled = false, ExtraLights = false, EffectsScale = 0.25, Shadows = false, MaxParticles = 20},
        Medium = {CrowdEnabled = true, ExtraLights = false, EffectsScale = 0.5, Shadows = true, MaxParticles = 60},
        High = {CrowdEnabled = true, ExtraLights = true, EffectsScale = 1, Shadows = true, MaxParticles = 120},
        Ultra = {CrowdEnabled = true, ExtraLights = true, EffectsScale = 1.35, Shadows = true, MaxParticles = 200},
    },
    BallTrailSpeedThreshold = 60,
    ReplaySeconds = 8,
    ReplaySampleRate = 10,
}