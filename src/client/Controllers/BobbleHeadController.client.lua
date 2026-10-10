--!strict
-- Local visual-only wobble, applied to every visible player's neck joint.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local phaseOffsets: {[Model]: number} = {}
local function phaseFor(character: Model): number
    local phase = phaseOffsets[character]
    if phase == nil then
        phase = (math.abs(string.byte(character.Name, 1) or 1) % 17) * 0.31
        phaseOffsets[character] = phase
    end
    return phase
end

RunService.PreSimulation:Connect(function()
    local now = os.clock()
    for _, player in ipairs(Players:GetPlayers()) do
        local character = player.Character
        if character and character.Parent then
            local head = character:FindFirstChild("Head")
            local neck = character:FindFirstChild("Neck", true)
            local root = character:FindFirstChild("HumanoidRootPart")
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if head and head:IsA("BasePart") and head:GetAttribute("PITCHBobbleScaled") == true
                and neck and neck:IsA("Motor6D") and root and root:IsA("BasePart") and humanoid then
                local speed = math.clamp(root.AssemblyLinearVelocity.Magnitude / 18, 0, 1.4)
                local movement = humanoid.MoveDirection.Magnitude
                local phase = phaseFor(character)
                local pitch = math.sin(now * (5 + speed * 3) + phase) * (0.025 + 0.045 * speed)
                local yaw = math.cos(now * 3.5 + phase) * (0.025 + 0.025 * movement)
                local roll = math.sin(now * 6 + phase) * (0.035 + 0.055 * speed)
                neck.Transform = CFrame.Angles(pitch, yaw, roll)
            end
        end
    end
end)

Players.PlayerRemoving:Connect(function(player)
    if player.Character then phaseOffsets[player.Character] = nil end
end)
print("[PITCH] Bobble-head wobble is active for all players.")
