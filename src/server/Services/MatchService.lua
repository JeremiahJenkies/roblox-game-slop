--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local RewardsConfig = require(Shared:WaitForChild("Config"):WaitForChild("RewardsConfig"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local MatchService = {}
local state: {[string]: any} = {phase = "PRACTICE", secondsLeft = 0, matchNumber = 0, redScore = 0, blueScore = 0}
local stateEvent: RemoteEvent? = nil

function MatchService.GetState()
    return table.clone(state)
end

function MatchService.SetState(nextState: {[string]: any})
    for key, value in pairs(nextState) do state[key] = value end
    if stateEvent then stateEvent:FireAllClients(table.clone(state)) end
end

function MatchService.RegisterGoal(scoringTeam: string, scorerUserId: any, assisterUserId: any): boolean
    if state.phase ~= "PRACTICE" and state.phase ~= "PLAYING" then return false end
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
    if stateEvent then stateEvent:FireAllClients(table.clone(state)) end
    return true
end

function MatchService.Init()
    local folder = Remotes.InitServer()
    local stateUpdateEvent = folder:WaitForChild("StateUpdate") :: RemoteEvent
    stateEvent = stateUpdateEvent
    local stateRequest = folder:WaitForChild("StateRequest") :: RemoteEvent
    stateRequest.OnServerEvent:Connect(function(player: Player, action: any)
        -- Clients may request a fresh snapshot, but cannot submit match-state changes.
        if action == "RequestState" then stateUpdateEvent:FireClient(player, table.clone(state)) end
    end)
    Players.PlayerAdded:Connect(function(player)
        task.defer(function() if player.Parent then stateUpdateEvent:FireClient(player, table.clone(state)) end end)
    end)
    task.spawn(function()
        while true do
            task.wait(2)
            if stateEvent then stateEvent:FireAllClients(table.clone(state)) end
        end
    end)
    print("[MatchService] Practice mode is active. Match timer, halves and restarts remain a later milestone.")
end

return MatchService