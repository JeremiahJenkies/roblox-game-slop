--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local MatchConfig = require(Shared:WaitForChild("Config"):WaitForChild("MatchConfig"))
local RewardsConfig = require(Shared:WaitForChild("Config"):WaitForChild("RewardsConfig"))
local DataService = require(script.Parent:WaitForChild("DataService"))

local MatchService = {}
local state: {[string]: any} = {
    phase = "KICKOFF", secondsLeft = MatchConfig.KickoffCountdownSeconds,
    matchNumber = 0, redScore = 0, blueScore = 0, half = 1,
    restartType = "", restartTeam = "", matchClock = 0,
}
local stateEvent: RemoteEvent? = nil
local noticeEvent: RemoteEvent? = nil
local matchStarted = false
local restartToken = 0

local function publish()
    if stateEvent then stateEvent:FireAllClients(table.clone(state)) end
end

local function announce(message: string)
    if noticeEvent then noticeEvent:FireAllClients(message) end
end

function MatchService.GetState()
    return table.clone(state)
end

function MatchService.SetState(nextState: {[string]: any})
    for key, value in pairs(nextState) do state[key] = value end
    publish()
end

function MatchService.RegisterGoal(scoringTeam: string, scorerUserId: any, assisterUserId: any): boolean
    if state.phase ~= "PLAYING" then return false end
    if scoringTeam ~= "Red" and scoringTeam ~= "Blue" then return false end
    local scoreKey = scoringTeam == "Red" and "redScore" or "blueScore"
    state[scoreKey] += 1
    local scorer = typeof(scorerUserId) == "number" and Players:GetPlayerByUserId(scorerUserId) or nil
    if scorer and (scorer:GetAttribute("Team") == scoringTeam or (scorer.Team and scorer.Team.Name == scoringTeam)) then
        DataService.IncrementStat(scorer, "Goals", 1)
        DataService.IncrementStat(scorer, "XP", RewardsConfig.GoalXP)
    end
    local assister = typeof(assisterUserId) == "number" and Players:GetPlayerByUserId(assisterUserId) or nil
    if assister and assister ~= scorer and (assister:GetAttribute("Team") == scoringTeam or (assister.Team and assister.Team.Name == scoringTeam)) then
        DataService.IncrementStat(assister, "Assists", 1)
        DataService.IncrementStat(assister, "XP", RewardsConfig.AssistXP)
    end
    state.phase = "KICKOFF"
    state.secondsLeft = MatchConfig.KickoffCountdownSeconds
    state.restartType = "KICKOFF"
    state.restartTeam = scoringTeam == "Red" and "Blue" or "Red"
    publish()
    announce("GOAL! " .. scoringTeam .. " scores! Kick-off to " .. state.restartTeam .. ".")
    restartToken += 1
    local token = restartToken
    task.delay(MatchConfig.KickoffCountdownSeconds, function()
        if token == restartToken and state.phase == "KICKOFF" then
            state.phase = "PLAYING"
            state.restartType = ""
            state.restartTeam = ""
            publish()
            announce("Play on!")
        end
    end)
    return true
end

function MatchService.BeginRestart(restartType: string, awardedTeam: string, spot: Vector3)
    if state.phase ~= "PLAYING" then return false end
    if restartType ~= "THROW_IN" and restartType ~= "CORNER" and restartType ~= "GOAL_KICK" then return false end
    if awardedTeam ~= "Red" and awardedTeam ~= "Blue" then return false end
    restartToken += 1
    local token = restartToken
    state.phase = "RESTART"
    state.secondsLeft = MatchConfig.KickoffCountdownSeconds
    state.restartType = restartType
    state.restartTeam = awardedTeam
    state.restartX = spot.X
    state.restartZ = spot.Z
    publish()
    local readable = restartType == "THROW_IN" and "Throw-in" or (restartType == "CORNER" and "Corner" or "Goal kick")
    announce(readable .. " to " .. awardedTeam .. ".")
    task.delay(MatchConfig.KickoffCountdownSeconds, function()
        if token == restartToken and state.phase == "RESTART" then
            state.phase = "PLAYING"
            state.restartType = ""
            state.restartTeam = ""
            publish()
            announce("Play on!")
        end
    end)
    return true
end

local function setPhase(phase: string, seconds: number, message: string)
    state.phase = phase
    state.secondsLeft = seconds
    state.restartType = ""
    state.restartTeam = ""
    publish()
    announce(message)
end

local function startMatch()
    state.matchNumber += 1
    state.redScore = 0
    state.blueScore = 0
    state.half = 1
    state.matchClock = 0
    state.phase = "KICKOFF"
    state.secondsLeft = MatchConfig.KickoffCountdownSeconds
    state.restartType = "KICKOFF"
    state.restartTeam = "Red"
    publish()
    announce("Match " .. tostring(state.matchNumber) .. " — kick-off!")
    restartToken += 1
    local token = restartToken
    task.delay(MatchConfig.KickoffCountdownSeconds, function()
        if token == restartToken and state.phase == "KICKOFF" then
            state.phase = "PLAYING"
            state.restartType = ""
            state.restartTeam = ""
            publish()
            announce("Kick-off! Play!")
        end
    end)
end

function MatchService.Init()
    local folder = Remotes.InitServer()
    stateEvent = folder:WaitForChild("StateUpdate") :: RemoteEvent
    noticeEvent = folder:WaitForChild("Notice") :: RemoteEvent
    local stateRequest = folder:WaitForChild("StateRequest") :: RemoteEvent
    stateRequest.OnServerEvent:Connect(function(player: Player, action: any)
        if action == "RequestState" then stateEvent:FireClient(player, table.clone(state)) end
    end)
    Players.PlayerAdded:Connect(function(player)
        task.defer(function() if player.Parent and stateEvent then stateEvent:FireClient(player, table.clone(state)) end end)
    end)

    task.spawn(function()
        task.wait(1)
        if not matchStarted then
            matchStarted = true
            startMatch()
        end
        local tickCounter = 0
        while true do
            task.wait(1)
            tickCounter += 1
            if state.phase == "PLAYING" then
                state.matchClock += 1
                state.secondsLeft = math.max(0, MatchConfig.HalfLengthSeconds - state.matchClock)
                if state.secondsLeft <= 0 then
                    if state.half == 1 then
                        setPhase("HALF_TIME", MatchConfig.HalfTimeSeconds, "Half-time!")
                        task.delay(MatchConfig.HalfTimeSeconds, function()
                            if state.phase == "HALF_TIME" then
                                state.half = 2
                                state.matchClock = 0
                                state.phase = "KICKOFF"
                                state.secondsLeft = MatchConfig.KickoffCountdownSeconds
                                state.restartType = "KICKOFF"
                                state.restartTeam = "Blue"
                                publish()
                                announce("Second half — kick-off!")
                                restartToken += 1
                                local token = restartToken
                                task.delay(MatchConfig.KickoffCountdownSeconds, function()
                                    if token == restartToken and state.phase == "KICKOFF" then
                                        state.phase = "PLAYING"
                                        state.restartType = ""
                                        state.restartTeam = ""
                                        publish()
                                    end
                                end)
                            end
                        end)
                    else
                        setPhase("FULL_TIME", 0, "Full time! Final score: Red " .. tostring(state.redScore) .. " - " .. tostring(state.blueScore) .. " Blue.")
                        task.delay(MatchConfig.IntermissionSeconds, function()
                            if state.phase == "FULL_TIME" then startMatch() end
                        end)
                    end
                end
            elseif state.phase == "KICKOFF" or state.phase == "RESTART" or state.phase == "HALF_TIME" then
                state.secondsLeft = math.max(0, (state.secondsLeft or 0) - 1)
            end
            if tickCounter % 1 == 0 then publish() end
        end
    end)
    print("[MatchService] Timed match loop active: kick-off, two halves, full-time and restarts.")
end

return MatchService
