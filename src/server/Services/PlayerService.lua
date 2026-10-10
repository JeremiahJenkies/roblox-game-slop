--!strict
-- Server-authoritative movement and stamina. Client requests are intent, never trusted state.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlayerConfig = require(Shared:WaitForChild("Config"):WaitForChild("PlayerConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local PlayerService = {}
local sprinting: {[Player]: boolean} = {}
local lastRequest: {[Player]: number} = {}
local actionRemote: RemoteEvent? = nil

local function setSprint(player: Player, enabled: boolean)
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local stamina = tonumber(player:GetAttribute("Stamina")) or PlayerConfig.MaxStamina
    local allowed = enabled and stamina > 1 and humanoid ~= nil and humanoid.Health > 0
    sprinting[player] = allowed
    player:SetAttribute("Sprinting", allowed)
    if humanoid then humanoid.WalkSpeed = allowed and PlayerConfig.SprintSpeed or PlayerConfig.WalkSpeed end
end

local function setupPlayer(player: Player)
    sprinting[player] = false
    player:SetAttribute("Stamina", PlayerConfig.MaxStamina)
    player:SetAttribute("Sprinting", false)
    player.CharacterAdded:Connect(function(character)
        sprinting[player] = false
        player:SetAttribute("Sprinting", false)
        player:SetAttribute("Stamina", PlayerConfig.MaxStamina)
        local humanoid = character:WaitForChild("Humanoid", 10)
        if humanoid and humanoid:IsA("Humanoid") then
            humanoid.WalkSpeed = PlayerConfig.WalkSpeed
            humanoid.Died:Connect(function() setSprint(player, false) end)
        end
    end)
end

function PlayerService.Init()
    local events = Remotes.InitServer()
    actionRemote = events:WaitForChild("ActionRequest") :: RemoteEvent
    actionRemote.OnServerEvent:Connect(function(player: Player, action: any, value: any)
        if action ~= "Sprint" or typeof(value) ~= "boolean" then return end
        local now = os.clock()
        if now - (lastRequest[player] or 0) < 0.12 then return end
        lastRequest[player] = now
        setSprint(player, value)
    end)
    Players.PlayerAdded:Connect(setupPlayer)
    Players.PlayerRemoving:Connect(function(player)
        sprinting[player] = nil
        lastRequest[player] = nil
    end)
    for _, player in ipairs(Players:GetPlayers()) do setupPlayer(player) end

    task.spawn(function()
        local step = 0.25
        while true do
            task.wait(step)
            for player, active in pairs(sprinting) do
                if player.Parent ~= Players then
                    sprinting[player] = nil
                    lastRequest[player] = nil
                elseif active then
                    local character = player.Character
                    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                    local stamina = math.max(0, (tonumber(player:GetAttribute("Stamina")) or 0) - PlayerConfig.StaminaDrainPerSecond * step)
                    player:SetAttribute("Stamina", stamina)
                    if stamina <= 0 or not humanoid or humanoid.Health <= 0 or humanoid.MoveDirection.Magnitude < 0.05 then
                        setSprint(player, false)
                    end
                else
                    local stamina = math.min(PlayerConfig.MaxStamina, (tonumber(player:GetAttribute("Stamina")) or 0) + PlayerConfig.StaminaRegenPerSecond * step)
                    player:SetAttribute("Stamina", stamina)
                end
            end
        end
    end)
    print("[PlayerService] Server-validated sprint and stamina are active.")
end

return PlayerService
