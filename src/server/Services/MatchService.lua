--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local MatchConfig = require(Shared:WaitForChild("Config"):WaitForChild("MatchConfig"))
local PitchConfig = require(Shared:WaitForChild("Config"):WaitForChild("PitchConfig"))
local RewardsConfig = require(Shared:WaitForChild("Config"):WaitForChild("RewardsConfig"))
local DataService = require(script.Parent:WaitForChild("DataService"))

local MatchService = {}
local state: {[string]: any} = {
    phase = "INTERMISSION", secondsLeft = MatchConfig.IntermissionSeconds,
    matchNumber = 0, redScore = 0, blueScore = 0, half = 1, matchClock = 0,
    restartType = "", restartTeam = "", mode = MatchConfig.DefaultMode,
}
local stateEvent: RemoteEvent? = nil
local noticeEvent: RemoteEvent? = nil
local started = false
local transitionId = 0
local goalIds: {[number]: boolean} = {}

local function publish()
    if stateEvent then stateEvent:FireAllClients(table.clone(state)) end
end

local function announce(message: string)
    if noticeEvent then noticeEvent:FireAllClients(message) end
end

local function setPhase(phase: string, seconds: number, message: string?)
    state.phase = phase
    state.secondsLeft = math.max(0, math.floor(seconds))
    if message then announce(message) end
    publish()
end

local function resetBall(position: Vector3?)
    local stadium = Workspace:FindFirstChild("SoccerStadium")
    local ball = stadium and stadium:FindFirstChild("MatchBall")
    if not ball or not ball:IsA("BasePart") then return end
    local y = PitchConfig.SurfaceCenterY + PitchConfig.SurfaceThickness / 2 + ball.Size.Y / 2 + 0.025
    ball.AssemblyLinearVelocity = Vector3.zero
    ball.AssemblyAngularVelocity = Vector3.zero
    ball.CFrame = CFrame.new(position or Vector3.new(0, y, 0))
    ball:SetAttribute("LastTouchedByUserId", 0)
    ball:SetAttribute("PreviousTouchedByUserId", 0)
    ball:SetAttribute("LastTouchedTeam", "")
    ball:SetAttribute("PreviousTouchedTeam", "")
    pcall(function() ball:SetNetworkOwner(nil) end)
end

local function setRestart(restartType: string, teamName: string, message: string)
    transitionId += 1
    local token = transitionId
    state.restartType = restartType
    state.restartTeam = teamName
    setPhase(restartType == "KICKOFF" and "KICKOFF" or "RESTART", MatchConfig.KickoffCountdownSeconds, message)
    task.delay(MatchConfig.KickoffCountdownSeconds, function()
        if token ~= transitionId or (state.phase ~= "KICKOFF" and state.phase ~= "RESTART") then return end
        state.restartType = ""
        state.restartTeam = ""
        setPhase("PLAYING", MatchConfig.HalfLengthSeconds - state.matchClock, "Play on!")
    end)
end

function MatchService.GetState()
    return table.clone(state)
end

function MatchService.SetState(nextState: {[string]: any})
    -- Kept for internal compatibility; only whitelisted public match fields can be changed.
    for _, key in ipairs({"mode"}) do
        if nextState[key] ~= nil and type(nextState[key]) == "string" then state[key] = nextState[key] end
    end
    publish()
end

function MatchService.RegisterGoal(scoringTeam: string, scorerUserId: any, assisterUserId: any): boolean
    if state.phase ~= "PLAYING" then return false end
    if scoringTeam ~= "Red" and scoringTeam ~= "Blue" then return false end
    local matchNumber = state.matchNumber
    if goalIds[matchNumber] then return false end
    -- A single-frame guard prevents duplicate score events while the ball crosses the goal plane.
    goalIds[matchNumber] = true
    local scoreKey = scoringTeam == "Red" and "redScore" or "blueScore"
    state[scoreKey] += 1
    local scorer = typeof(scorerUserId) == "number" and Players:GetPlayerByUserId(scorerUserId) or nil
    if scorer and (scorer:GetAttribute("Team") == scoringTeam or (scorer.Team and scorer.Team.Name == scoringTeam)) then
        DataService.IncrementStat(scorer, "Goals", 1)
        DataService.IncrementStat(scorer, "XP", RewardsConfig.GoalXP)
    else
        scorer = nil
    end
    local assister = typeof(assisterUserId) == "number" and Players:GetPlayerByUserId(assisterUserId) or nil
    if assister and assister ~= scorer and (assister:GetAttribute("Team") == scoringTeam or (assister.Team and assister.Team.Name == scoringTeam)) then
        DataService.IncrementStat(assister, "Assists", 1)
        DataService.IncrementStat(assister, "XP", RewardsConfig.AssistXP)
    end
    resetBall()
    state.restartType = "KICKOFF"
    state.restartTeam = scoringTeam == "Red" and "Blue" or "Red"
    transitionId += 1
    local token = transitionId
    setPhase("KICKOFF", MatchConfig.GoalResetSeconds, "GOAL! " .. scoringTeam .. " scores. Kick-off to " .. state.restartTeam .. "!")
    task.delay(MatchConfig.GoalResetSeconds, function()
        if token ~= transitionId or state.phase ~= "KICKOFF" then return end
        goalIds[matchNumber] = nil
        setRestart("KICKOFF", state.restartTeam, "Kick-off!")
    end)
    return true
end

function MatchService.BeginRestart(restartType: string, awardedTeam: string, spot: Vector3): boolean
    if state.phase ~= "PLAYING" then return false end
    if restartType ~= "THROW_IN" and restartType ~= "CORNER" and restartType ~= "GOAL_KICK" then return false end
    if awardedTeam ~= "Red" and awardedTeam ~= "Blue" then return false end
    if typeof(spot) ~= "Vector3" or spot.X ~= spot.X or spot.Y ~= spot.Y or spot.Z ~= spot.Z then return false end
    transitionId += 1
    local token = transitionId
    state.restartType = restartType
    state.restartTeam = awardedTeam
    state.restartX = math.clamp(spot.X, -PitchConfig.Width / 2, PitchConfig.Width / 2)
    state.restartZ = math.clamp(spot.Z, -PitchConfig.Length / 2, PitchConfig.Length / 2)
    local readable = restartType == "THROW_IN" and "Throw-in" or (restartType == "CORNER" and "Corner" or "Goal kick")
    setPhase("RESTART", MatchConfig.RestartFreezeSeconds, readable .. " to " .. awardedTeam .. ".")
    task.delay(MatchConfig.RestartFreezeSeconds, function()
        if token ~= transitionId or state.phase ~= "RESTART" then return end
        state.restartType = ""
        state.restartTeam = ""
        setPhase("PLAYING", math.max(0, MatchConfig.HalfLengthSeconds - state.matchClock), "Play on!")
    end)
    return true
end

local function awardMatchResults()
    for _, player in ipairs(Players:GetPlayers()) do
        DataService.IncrementStat(player, "MatchesPlayed", 1)
        DataService.IncrementStat(player, "Coins", RewardsConfig.MatchParticipationCoins)
        local teamName = player:GetAttribute("Team") or (player.Team and player.Team.Name)
        if state.redScore == state.blueScore then
            DataService.IncrementStat(player, "Coins", RewardsConfig.DrawCoins)
        elseif (state.redScore > state.blueScore and teamName == "Red") or (state.blueScore > state.redScore and teamName == "Blue") then
            DataService.IncrementStat(player, "Wins", 1)
            DataService.IncrementStat(player, "Coins", RewardsConfig.WinCoins)
            DataService.IncrementStat(player, "XP", RewardsConfig.WinXP)
        else
            DataService.IncrementStat(player, "Losses", 1)
            DataService.IncrementStat(player, "Coins", RewardsConfig.LossCoins)
        end
    end
end

local function startMatch()
    transitionId += 1
    state.matchNumber += 1
    state.redScore = 0
    state.blueScore = 0
    state.half = 1
    state.matchClock = 0
    goalIds[state.matchNumber] = nil
    resetBall()
    setRestart("KICKOFF", "Red", "Match " .. tostring(state.matchNumber) .. " — kick-off!")
end

local function beginSecondHalf()
    state.half = 2
    state.matchClock = 0
    resetBall()
    setRestart("KICKOFF", "Blue", "Second half — kick-off!")
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
        if not started then
            started = true
            setPhase("INTERMISSION", MatchConfig.IntermissionSeconds, "Teams ready. Match begins soon.")
        end
        while true do
            task.wait(MatchConfig.StateBroadcastSeconds)
            if state.phase == "INTERMISSION" then
                state.secondsLeft = math.max(0, state.secondsLeft - MatchConfig.StateBroadcastSeconds)
                if state.secondsLeft <= 0 then startMatch() else publish() end
            elseif state.phase == "PLAYING" then
                state.matchClock += MatchConfig.StateBroadcastSeconds
                state.secondsLeft = math.max(0, MatchConfig.HalfLengthSeconds - state.matchClock)
                if state.secondsLeft <= 0 then
                    if state.half == 1 then
                        transitionId += 1
                        local token = transitionId
                        setPhase("HALF_TIME", MatchConfig.HalfTimeSeconds, "Half-time!")
                        task.delay(MatchConfig.HalfTimeSeconds, function()
                            if token == transitionId and state.phase == "HALF_TIME" then beginSecondHalf() end
                        end)
                    else
                        transitionId += 1
                        local token = transitionId
                        setPhase("FULL_TIME", MatchConfig.IntermissionSeconds, "Full time! Red " .. tostring(state.redScore) .. " - " .. tostring(state.blueScore) .. " Blue.")
                        awardMatchResults()
                        task.delay(MatchConfig.IntermissionSeconds, function()
                            if token == transitionId and state.phase == "FULL_TIME" then
                                setPhase("INTERMISSION", MatchConfig.IntermissionSeconds, "Next match loading.")
                            end
                        end)
                    end
                else
                    publish()
                end
            elseif state.phase == "HALF_TIME" or state.phase == "FULL_TIME" or state.phase == "KICKOFF" or state.phase == "RESTART" then
                state.secondsLeft = math.max(0, state.secondsLeft - MatchConfig.StateBroadcastSeconds)
                publish()
            end
        end
    end)
    print("[MatchService] Match lifecycle active: intermission, kick-off, two halves, results and restarts.")
end

return MatchService
