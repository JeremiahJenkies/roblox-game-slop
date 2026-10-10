--!strict
-- Cosmetic items only. Never sell competitive advantages.
return {
    Items = {
        Default = {Type = "Kit", DisplayName = "Classic Kit", Price = 0, TeamColor = "Team", AccentColor = Color3.fromRGB(35, 43, 53)},
        Night = {Type = "Kit", DisplayName = "Night Match Kit", Price = 250, TeamColor = "Team", AccentColor = Color3.fromRGB(30, 34, 49)},
        Volt = {Type = "Kit", DisplayName = "Volt Kit", Price = 500, TeamColor = "Team", AccentColor = Color3.fromRGB(180, 220, 67)},
        ClassicTrail = {Type = "BallTrail", DisplayName = "Classic Trail", Price = 0},
        BlueTrail = {Type = "BallTrail", DisplayName = "Blue Trail", Price = 150},
        GoldTrail = {Type = "BallTrail", DisplayName = "Gold Trail", Price = 350},
        DefaultGoal = {Type = "GoalEffect", DisplayName = "Standard Goal", Price = 0},
        Confetti = {Type = "GoalEffect", DisplayName = "Confetti Goal", Price = 400},
    },
    AllowedEquipFields = {Kit = "EquippedKit", BallTrail = "EquippedBallTrail", GoalEffect = "EquippedGoalEffect"},
}