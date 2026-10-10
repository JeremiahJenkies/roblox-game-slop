--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local MatchService = {}
local state: {[string]: any} = {phase = "LOBBY", secondsLeft = 0, matchNumber = 0, redScore = 0, blueScore = 0}
local stateEvent: RemoteEvent? = nil

function MatchService.GetState()
    return table.clone(state)
end

function MatchService.SetState(nextState: {[string]: any})
    for key, value in pairs(nextState) do state[key] = value end
    if stateEvent then stateEvent:FireAllClients(table.clone(state)) end
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
    print("[MatchService] Foundation lobby state is ready; match rules arrive in a later milestone.")
end

return MatchService