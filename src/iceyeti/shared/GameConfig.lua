-- Shared configuration for the competitive soccer game.
local Config = {}
Config.GameName = "PITCH: Competitive Soccer"
Config.FieldWidth = 180
Config.FieldLength = 280
Config.MatchLengthSeconds = 180
Config.IntermissionSeconds = 12
Config.KickCooldown = 0.45
Config.KickRange = 13
Config.KickPower = 82
Config.KickLift = 13
Config.DataStoreName = "IceYetiSurvival_v1" -- Kept intentionally to preserve existing player records.
Config.AutoSaveSeconds = 60
Config.WalkSpeed = 18
Config.SprintSpeed = 23
return Config