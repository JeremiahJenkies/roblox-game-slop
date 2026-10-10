--!strict
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local MatchConfig = require(Shared:WaitForChild("Config"):WaitForChild("MatchConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))

type Profile = {[string]: any}
local DataService = {}
local profiles: {[Player]: Profile} = {}
local canSave: {[Player]: boolean} = {}
local store: GlobalDataStore? = nil
local profileUpdate: RemoteEvent? = nil
local profileRequest: RemoteEvent? = nil

local function copyDictionary(source: any): {[string]: any}
    local result: {[string]: any} = {}
    if type(source) == "table" then
        for key, value in pairs(source) do
            if type(key) == "string" then result[key] = value end
        end
    end
    return result
end

local function makeDefaultProfile(): Profile
    return {
        DataVersion = MatchConfig.DataVersion,
        Coins = 0,
        XP = 0,
        Level = 1,
        Wins = 0,
        Losses = 0,
        Goals = 0,
        Assists = 0,
        Saves = 0,
        MatchesPlayed = 0,
        EquippedKit = "Default",
        EquippedBallTrail = "Default",
        EquippedGoalEffect = "Default",
        Owned = {},
    }
end

local function nonNegativeInteger(value: any, defaultValue: number): number
    local numeric = tonumber(value)
    if not numeric or numeric ~= numeric or numeric == math.huge or numeric == -math.huge then
        return defaultValue
    end
    return math.max(0, math.floor(numeric))
end

local function normalizeProfile(saved: any): Profile
    local profile = makeDefaultProfile()
    if type(saved) ~= "table" then return profile end
    -- New profile fields take priority. Old lowercase fields are imported when present.
    profile.Coins = nonNegativeInteger(saved.Coins ~= nil and saved.Coins or saved.coins, 0)
    profile.XP = nonNegativeInteger(saved.XP ~= nil and saved.XP or saved.xp, 0)
    profile.Level = math.max(1, nonNegativeInteger(saved.Level, 1))
    -- Earlier survival wins lived in lowercase `wins`; those are preserved as legacy data,
    -- not silently converted into soccer wins. The prior soccer prototype used `soccerWins`.
    profile.Wins = nonNegativeInteger(saved.Wins ~= nil and saved.Wins or saved.soccerWins, 0)
    profile.Losses = nonNegativeInteger(saved.Losses, 0)
    profile.Goals = nonNegativeInteger(saved.Goals ~= nil and saved.Goals or saved.goals, 0)
    profile.Assists = nonNegativeInteger(saved.Assists ~= nil and saved.Assists or saved.assists, 0)
    profile.Saves = nonNegativeInteger(saved.Saves, 0)
    profile.MatchesPlayed = nonNegativeInteger(saved.MatchesPlayed ~= nil and saved.MatchesPlayed or saved.matches, 0)
    if type(saved.EquippedKit) == "string" then profile.EquippedKit = saved.EquippedKit end
    if type(saved.EquippedBallTrail) == "string" then profile.EquippedBallTrail = saved.EquippedBallTrail end
    if type(saved.EquippedGoalEffect) == "string" then profile.EquippedGoalEffect = saved.EquippedGoalEffect end
    profile.Owned = copyDictionary(saved.Owned)
    return profile
end

local function makeSavePayload(profile: Profile): Profile
    return {
        DataVersion = MatchConfig.DataVersion,
        Coins = profile.Coins, XP = profile.XP, Level = profile.Level,
        Wins = profile.Wins, Losses = profile.Losses, Goals = profile.Goals,
        Assists = profile.Assists, Saves = profile.Saves, MatchesPlayed = profile.MatchesPlayed,
        EquippedKit = profile.EquippedKit, EquippedBallTrail = profile.EquippedBallTrail,
        EquippedGoalEffect = profile.EquippedGoalEffect, Owned = copyDictionary(profile.Owned),
        -- Compatibility aliases used by the previous soccer prototype.
        coins = profile.Coins, xp = profile.XP, goals = profile.Goals,
        assists = profile.Assists, matches = profile.MatchesPlayed, soccerWins = profile.Wins,
    }
end

local function sendProfile(player: Player)
    local profile = profiles[player]
    if profile and profileUpdate then profileUpdate:FireClient(player, table.clone(profile)) end
end

function DataService.GetProfile(player: Player): Profile?
    return profiles[player]
end

function DataService.GetSnapshot(player: Player): Profile?
    local profile = profiles[player]
    if not profile then return nil end
    local snapshot = table.clone(profile)
    snapshot.Owned = copyDictionary(profile.Owned)
    return snapshot
end

function DataService.IncrementStat(player: Player, statName: string, amount: number): boolean
    local profile = profiles[player]
    if not profile or type(statName) ~= "string" or type(amount) ~= "number" then return false end
    local allowed = {Coins = true, XP = true, Wins = true, Losses = true, Goals = true, Assists = true, Saves = true, MatchesPlayed = true}
    if not allowed[statName] or amount ~= amount or amount == math.huge or amount == -math.huge then return false end
    profile[statName] = math.max(0, nonNegativeInteger(profile[statName], 0) + math.floor(amount))
    if statName == "XP" then profile.Level = math.max(1, math.floor(profile.XP / 100) + 1) end
    sendProfile(player)
    return true
end

function DataService.LoadProfile(player: Player)
    if profiles[player] then return end
    local ok, saved: any = false, nil
    if store then
        ok, saved = pcall(function() return store:GetAsync("player_" .. player.UserId) end)
    end
    if ok then
        canSave[player] = true
        profiles[player] = normalizeProfile(saved)
    else
        -- Never overwrite a possibly valid profile if loading failed. This session remains temporary.
        canSave[player] = false
        profiles[player] = makeDefaultProfile()
        warn("[DataService] Profile for " .. player.Name .. " is temporary because loading failed or DataStore is unavailable: " .. tostring(saved))
    end
    sendProfile(player)
end

function DataService.SaveProfile(player: Player)
    local profile = profiles[player]
    if not profile or not canSave[player] or not store then return false end
    local payload = makeSavePayload(profile)
    local ok, err = pcall(function()
        store:UpdateAsync("player_" .. player.UserId, function(existing)
            -- Merge instead of replacing the record. Legacy/unknown fields like bestDay, wood,
            -- stone, trophies, discoveries, and lowercase historical `wins` remain untouched.
            local merged = type(existing) == "table" and existing or {}
            for key, value in pairs(payload) do merged[key] = value end
            return merged
        end)
    end)
    if not ok then warn("[DataService] Save failed for " .. player.Name .. ": " .. tostring(err)) end
    return ok
end

function DataService.Init()
    local remotes = Remotes.InitServer()
    profileUpdate = remotes:WaitForChild("ProfileUpdate") :: RemoteEvent
    profileRequest = remotes:WaitForChild("ProfileRequest") :: RemoteEvent
    local storeOk, storeResult = pcall(function()
        return DataStoreService:GetDataStore(MatchConfig.DataStoreName)
    end)
    if storeOk then
        store = storeResult
    else
        warn("[DataService] DataStore unavailable; sessions will not be saved: " .. tostring(storeResult))
    end
    Players.PlayerAdded:Connect(function(player) DataService.LoadProfile(player) end)
    Players.PlayerRemoving:Connect(function(player)
        DataService.SaveProfile(player)
        profiles[player] = nil
        canSave[player] = nil
    end)
    if profileRequest then
        profileRequest.OnServerEvent:Connect(function(player, action)
            -- Only permit a profile snapshot request; clients cannot send profile values.
            if action == "RequestProfile" then sendProfile(player) end
        end)
    end
    for _, player in ipairs(Players:GetPlayers()) do task.spawn(DataService.LoadProfile, player) end
    task.spawn(function()
        while true do
            task.wait(MatchConfig.AutoSaveSeconds)
            for _, player in ipairs(Players:GetPlayers()) do task.spawn(DataService.SaveProfile, player) end
        end
    end)
    game:BindToClose(function()
        for _, player in ipairs(Players:GetPlayers()) do DataService.SaveProfile(player) end
        task.wait(2)
    end)
end

return DataService