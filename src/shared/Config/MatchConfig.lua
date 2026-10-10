--!strict
return {
    DataStoreName = "IceYetiSurvival_v1", -- Keep the existing store and player keys.
    DataVersion = 4,
    AutoSaveSeconds = 60,
    IntermissionSeconds = 12,
    HalfLengthSeconds = 180,
    HalfTimeSeconds = 15,
    GoalResetSeconds = 3,
    KickoffCountdownSeconds = 3,
    RestartFreezeSeconds = 3,
    MaximumPlayersPerTeam = 6,
    MinimumPlayersPerTeam = 1,
    UseReservedMatchServers = false,
    EnableFouls = false,
    EnableOffside = false,
    EnableExtraTime = false,
    EnablePenalties = false,
    SupportedModes = {"1v1", "2v2", "3v3", "5v5", "6v6"},
    DefaultMode = "Practice",
    StateBroadcastSeconds = 1,
}