-- Server-only progression rules for the 99-night survival game.
-- All rewards are calculated by the server; clients never submit reward amounts.
local ProgressionService = {}

ProgressionService.DataVersion = 2
ProgressionService.TrophyThresholds = {
	{trophies = 0, multiplier = 1.0},
	{trophies = 1, multiplier = 1.1},
	{trophies = 3, multiplier = 1.25},
	{trophies = 6, multiplier = 1.5},
	{trophies = 10, multiplier = 1.75},
}

function ProgressionService.GetMultiplier(trophies)
	local count = math.max(0, math.floor(tonumber(trophies) or 0))
	local multiplier = 1.0
	for _, tier in ipairs(ProgressionService.TrophyThresholds) do
		if count >= tier.trophies then
			multiplier = tier.multiplier
		else
			break
		end
	end
	return multiplier
end

function ProgressionService.GetSurvivalXP(night)
	local n = math.max(1, math.floor(tonumber(night) or 1))
	return 10 + n * 2
end

function ProgressionService.GetMilestoneTrophy(night)
	local n = math.floor(tonumber(night) or 0)
	if n > 0 and n % 10 == 0 then
		return 1
	end
	if n == 99 then
		return 5
	end
	return 0
end

function ProgressionService.ApplySurvivalReward(profile, night)
	local baseXP = ProgressionService.GetSurvivalXP(night)
	local multiplier = ProgressionService.GetMultiplier(profile.trophies)
	local earnedXP = math.floor(baseXP * multiplier)
	profile.xp = math.max(0, math.floor(tonumber(profile.xp) or 0)) + earnedXP
	local trophiesEarned = ProgressionService.GetMilestoneTrophy(night)
	profile.trophies = math.max(0, math.floor(tonumber(profile.trophies) or 0)) + trophiesEarned
	profile.dataVersion = ProgressionService.DataVersion
	return earnedXP, trophiesEarned, multiplier
end

return ProgressionService
