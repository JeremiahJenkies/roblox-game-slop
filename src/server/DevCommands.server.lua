--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then return end

local servicesFolder = script.Parent:WaitForChild("Services")
local Maid = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Maid"))
local playerMaids: {[Player]: any} = {}
local DataService = require(servicesFolder:WaitForChild("DataService"))
local PitchService = require(servicesFolder:WaitForChild("PitchService"))

local function attach(player: Player)
    if playerMaids[player] then playerMaids[player]:Destroy() end
    local maid = Maid.new()
    playerMaids[player] = maid
    maid:GiveTask(player.Chatted:Connect(function(message: string)
        local command = string.lower(message)
        if command == "/stats" then
            local profile = DataService.GetProfile(player)
            print("[DevCommands] Profile for " .. player.Name .. ": " .. (profile and game:GetService("HttpService"):JSONEncode(profile) or "<profile loading>"))
        elseif command == "/pitch" then
            local ok, result = pcall(PitchService.Build)
            if ok then print("[DevCommands] Pitch rebuilt by " .. player.Name)
            else warn("[DevCommands] Pitch rebuild failed: " .. tostring(result)) end
        end
    end))
end

Players.PlayerAdded:Connect(attach)
Players.PlayerRemoving:Connect(function(player)
    local maid = playerMaids[player]
    if maid then maid:Destroy(); playerMaids[player] = nil end
end)
for _, player in ipairs(Players:GetPlayers()) do attach(player) end
print("[DevCommands] Studio-only /stats and /pitch commands enabled.")