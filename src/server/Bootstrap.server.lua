--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
-- Rojo does not always remove objects that were created by an older, now-unmapped project tree.
-- Clean up only the specifically known legacy game folders before starting the new services.
for _, legacyName in ipairs({"IceYetiServer", "SoccerServer"}) do
    local legacy = ServerScriptService:FindFirstChild(legacyName)
    if legacy then
        warn("[Bootstrap] Removing stale legacy server folder: " .. legacyName)
        legacy:Destroy()
    end
end
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local servicesFolder = script.Parent:WaitForChild("Services")

-- Fixed initialization order: profiles first, then world, team placement, and match state.
Remotes.InitServer()
local serviceNames = {
    "DataService",
    "PitchService",
    "TeamService",
    "MatchService",
    "BallService",
}

for _, serviceName in ipairs(serviceNames) do
    local moduleScript = servicesFolder:WaitForChild(serviceName)
    local service = require(moduleScript)
    assert(type(service) == "table" and type(service.Init) == "function", serviceName .. " must return a table with Init()")
    local ok, err = pcall(service.Init)
    if not ok then
        error("[Bootstrap] Failed to initialize " .. serviceName .. ": " .. tostring(err))
    end
    print("[Bootstrap] Initialized " .. serviceName)
end

print("[PITCH] Foundation bootstrap complete.")