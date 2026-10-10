--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local BallConfig = require(Shared:WaitForChild("Config"):WaitForChild("BallConfig"))
local PlayerConfig = require(Shared:WaitForChild("Config"):WaitForChild("PlayerConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local events = Remotes.GetClient()
local kickRemote: RemoteEvent = events.KickBall
local actionRemote: RemoteEvent = events.ActionRequest

-- Clear only known old prototype scripts and their duplicate interface.
for _, child in ipairs(player:WaitForChild("PlayerScripts"):GetChildren()) do
    if child ~= script and child:IsA("LocalScript") and (child.Name == "SoccerClient" or child.Name == "IceYetiClient") then
        child:Destroy()
    end
end
local playerGui = player:WaitForChild("PlayerGui")
for _, child in ipairs(playerGui:GetChildren()) do
    if child:IsA("ScreenGui") and (child.Name == "SoccerHUD" or child.Name == "IceYetiHUD" or child.Name == "PITCHControls") then
        child:Destroy()
    end
end

player.CameraMode = Enum.CameraMode.Classic
player.CameraMinZoomDistance = 10
player.CameraMaxZoomDistance = 70

local isTouch = UserInputService.TouchEnabled
local gui = Instance.new("ScreenGui")
gui.Name = "PITCHControls"
gui.ResetOnSpawn = false
gui.DisplayOrder = 30
gui.IgnoreGuiInset = false
gui.Parent = playerGui

local function round(instance: Instance, radius: number)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius)
    corner.Parent = instance
end

local function addButton(name: string, title: string, hint: string, position: UDim2, size: UDim2, color: Color3)
    local button = Instance.new("TextButton")
    button.Name = name
    button.AnchorPoint = Vector2.new(1, 1)
    button.Position = position
    button.Size = size
    button.BackgroundColor3 = color
    button.BackgroundTransparency = 0.04
    button.Text = title .. (hint ~= "" and ("\n" .. hint) or "")
    button.TextColor3 = Color3.fromRGB(250, 252, 255)
    button.Font = Enum.Font.GothamBlack
    button.TextSize = isTouch and 17 or 14
    button.TextWrapped = true
    button.AutoButtonColor = true
    button.Selectable = true
    button.Parent = gui
    round(button, isTouch and 18 or 12)
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(230, 239, 247)
    stroke.Transparency = 0.55
    stroke.Thickness = 1.5
    stroke.Parent = button
    return button
end

local actionWidth = isTouch and 112 or 106
local actionHeight = isTouch and 70 or 54
local actionGap = isTouch and 9 or 8
local bottom = isTouch and 28 or 20
local right = isTouch and 18 or 18
local shootButton = addButton("ShootButton", "SHOOT", isTouch and "POWER" or "[E]", UDim2.new(1, -right, 1, -bottom), UDim2.fromOffset(actionWidth, actionHeight), Color3.fromRGB(27, 132, 79))
local lobButton = addButton("LobButton", "LOB", isTouch and "HIGH" or "[F]", UDim2.new(1, -right, 1, -(bottom + actionHeight + actionGap)), UDim2.fromOffset(actionWidth, actionHeight), Color3.fromRGB(96, 83, 160))
local passButton = addButton("PassButton", "PASS", isTouch and "TEAMMATE" or "[Q]", UDim2.new(1, -right, 1, -(bottom + (actionHeight + actionGap) * 2)), UDim2.fromOffset(actionWidth, actionHeight), Color3.fromRGB(43, 105, 159))
local tackleButton = addButton("TackleButton", "TACKLE", isTouch and "STEAL BALL" or "[C]", UDim2.new(1, -right, 1, -(bottom + (actionHeight + actionGap) * 3)), UDim2.fromOffset(actionWidth, actionHeight), Color3.fromRGB(185, 63, 55))
local feintButton = addButton("FeintButton", "FEINT", isTouch and "SIDE TOUCH" or "[Z]", UDim2.new(0, 18, 1, -(isTouch and 286 or 132)), UDim2.fromOffset(isTouch and 112 or 94, isTouch and 54 or 44), Color3.fromRGB(143, 69, 211))
feintButton.AnchorPoint = Vector2.new(0, 1)
local stepOverButton = addButton("StepOverButton", "STEP OVER", isTouch and "SKILL MOVE" or "[X]", UDim2.new(0, isTouch and 138 or 120, 1, -(isTouch and 286 or 132)), UDim2.fromOffset(isTouch and 118 or 104, isTouch and 54 or 44), Color3.fromRGB(224, 105, 38))
stepOverButton.AnchorPoint = Vector2.new(0, 1)
local sprintButton = addButton("SprintButton", "SPRINT", isTouch and "TAP TO TOGGLE" or "[SHIFT]", UDim2.new(0, isTouch and 158 or 18, 1, -(isTouch and 138 or 20)), UDim2.fromOffset(isTouch and 132 or 106, isTouch and 62 or 48), Color3.fromRGB(183, 116, 35))
sprintButton.AnchorPoint = Vector2.new(0, 1)
local staminaPanel = Instance.new("Frame")
staminaPanel.Name = "StaminaMeter"
staminaPanel.AnchorPoint = Vector2.new(0, 1)
staminaPanel.Position = UDim2.new(0, 18, 1, -(isTouch and 210 or 78))
staminaPanel.Size = UDim2.fromOffset(isTouch and 250 or 210, 24)
staminaPanel.BackgroundColor3 = Color3.fromRGB(15, 25, 32)
staminaPanel.BackgroundTransparency = 0.12
staminaPanel.Parent = gui
round(staminaPanel, 8)
local staminaFill = Instance.new("Frame")
staminaFill.Name = "Fill"
staminaFill.Size = UDim2.fromScale(1, 1)
staminaFill.BackgroundColor3 = Color3.fromRGB(77, 210, 139)
staminaFill.BorderSizePixel = 0
staminaFill.Parent = staminaPanel
round(staminaFill, 8)
local staminaText = Instance.new("TextLabel")
staminaText.Name = "Label"
staminaText.BackgroundTransparency = 1
staminaText.Size = UDim2.fromScale(1, 1)
staminaText.Font = Enum.Font.GothamBold
staminaText.TextSize = 11
staminaText.TextColor3 = Color3.new(1, 1, 1)
staminaText.Text = "STAMINA 100%"
staminaText.ZIndex = 2
staminaText.Parent = staminaPanel
local function updateStamina()
    local amount = math.clamp(tonumber(player:GetAttribute("Stamina")) or 100, 0, 100)
    staminaFill.Size = UDim2.fromScale(amount / 100, 1)
    staminaText.Text = "STAMINA " .. tostring(math.floor(amount)) .. "%"
    staminaFill.BackgroundColor3 = amount < 25 and Color3.fromRGB(232, 92, 82) or Color3.fromRGB(77, 210, 139)
end
player:GetAttributeChangedSignal("Stamina"):Connect(updateStamina)
updateStamina()

-- Adjustable kick strength, shared by pass, shot and lob controls.
local kickPower = 0.75
local powerPanel = Instance.new("Frame")
powerPanel.Name = "KickPowerControl"
powerPanel.AnchorPoint = Vector2.new(0.5, 1)
powerPanel.Position = UDim2.new(0.5, 0, 1, -(isTouch and 28 or 20))
powerPanel.Size = UDim2.fromOffset(isTouch and 260 or 300, 68)
powerPanel.BackgroundColor3 = Color3.fromRGB(15, 25, 32)
powerPanel.BackgroundTransparency = 0.08
powerPanel.Parent = gui
round(powerPanel, 12)
local powerLabel = Instance.new("TextLabel")
powerLabel.BackgroundTransparency = 1
powerLabel.Position = UDim2.fromOffset(10, 3)
powerLabel.Size = UDim2.new(1, -20, 0, 23)
powerLabel.Font = Enum.Font.GothamBlack
powerLabel.TextSize = 12
powerLabel.TextColor3 = Color3.new(1, 1, 1)
powerLabel.Text = "KICK POWER 75%"
powerLabel.Parent = powerPanel
local powerTrack = Instance.new("TextButton")
powerTrack.Name = "PowerTrack"
powerTrack.Position = UDim2.fromOffset(14, 34)
powerTrack.Size = UDim2.new(1, -28, 0, 20)
powerTrack.BackgroundColor3 = Color3.fromRGB(49, 63, 75)
powerTrack.Text = ""
powerTrack.AutoButtonColor = false
powerTrack.Parent = powerPanel
round(powerTrack, 8)
local powerFill = Instance.new("Frame")
powerFill.Name = "Fill"
powerFill.Size = UDim2.fromScale((kickPower - 0.2) / 0.8, 1)
powerFill.BackgroundColor3 = Color3.fromRGB(255, 177, 71)
powerFill.BorderSizePixel = 0
powerFill.Parent = powerTrack
round(powerFill, 8)
local powerKnob = Instance.new("Frame")
powerKnob.Name = "Knob"
powerKnob.AnchorPoint = Vector2.new(0.5, 0.5)
powerKnob.Position = UDim2.new((kickPower - 0.2) / 0.8, 0, 0.5, 0)
powerKnob.Size = UDim2.fromOffset(14, 26)
powerKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
powerKnob.BorderSizePixel = 0
powerKnob.Parent = powerTrack
round(powerKnob, 7)
-- Hold left mouse (or touch and hold the meter) to charge power.
-- Releasing lets the meter drain back to its 20% resting value.
local chargingPower = false
local chargeRate = 0.55 -- full charge in about 1.45 seconds
local drainRate = 1.1
local function renderKickPower()
    local visualFraction = (kickPower - 0.2) / 0.8
    powerFill.Size = UDim2.fromScale(visualFraction, 1)
    powerKnob.Position = UDim2.new(visualFraction, 0, 0.5, 0)
    powerLabel.Text = "KICK POWER " .. tostring(math.floor(kickPower * 100 + 0.5)) .. "%"
end
local function beginCharging()
    chargingPower = true
end
local function stopCharging()
    chargingPower = false
end
powerTrack.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        beginCharging()
    end
end)
UserInputService.InputBegan:Connect(function(input, processed)
    if input.UserInputType == Enum.UserInputType.MouseButton1 and not processed then
        beginCharging()
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        stopCharging()
    end
end)
RunService.RenderStepped:Connect(function(deltaTime)
    if chargingPower then
        kickPower = math.min(1, kickPower + chargeRate * deltaTime)
    else
        kickPower = math.max(0.2, kickPower - drainRate * deltaTime)
    end
    renderKickPower()
end)
local sprinting = false
local humanoid: Humanoid? = nil

local function applySprint()
    actionRemote:FireServer("Sprint", sprinting)
    sprintButton.Text = sprinting and "SPRINT ON" or ("SPRINT\n" .. (isTouch and "TAP TO TOGGLE" or "[SHIFT]"))
    sprintButton.BackgroundColor3 = sprinting and Color3.fromRGB(34, 151, 91) or Color3.fromRGB(183, 116, 35)
end
player:GetAttributeChangedSignal("Sprinting"):Connect(function()
    sprinting = player:GetAttribute("Sprinting") == true
    sprintButton.Text = sprinting and "SPRINT ON" or ("SPRINT\n" .. (isTouch and "TAP TO TOGGLE" or "[SHIFT]"))
    sprintButton.BackgroundColor3 = sprinting and Color3.fromRGB(34, 151, 91) or Color3.fromRGB(183, 116, 35)
end)

player.CharacterAdded:Connect(function(character)
    sprinting = false
    humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
    task.defer(applySprint)
end)
if player.Character then
    humanoid = player.Character:FindFirstChildOfClass("Humanoid")
    task.defer(applySprint)
end
sprintButton.Activated:Connect(function()
    sprinting = not sprinting
    applySprint()
end)

local function kick(action: string)
    local camera = Workspace.CurrentCamera
    local direction = camera and camera.CFrame.LookVector or Vector3.new(0, 0, -1)
    if UserInputService.MouseEnabled and not isTouch then
        local mouse = player:GetMouse()
        local target = mouse.Hit.Position
        local stadium = Workspace:FindFirstChild("SoccerStadium")
        local ballObject = stadium and stadium:FindFirstChild("MatchBall")
        local origin = ballObject and ballObject:IsA("BasePart") and ballObject.Position
            or (player.Character and player.Character:GetPivot().Position or Vector3.zero)
        direction = target - origin
    end
    if direction.Magnitude < 0.05 then return end
    kickRemote:FireServer(action, direction.Unit, kickPower)
end

passButton.Activated:Connect(function() kick("Pass") end)
tackleButton.Activated:Connect(function() actionRemote:FireServer("Tackle") end)
feintButton.Activated:Connect(function() actionRemote:FireServer("SkillMove", "Feint") end)
stepOverButton.Activated:Connect(function() actionRemote:FireServer("SkillMove", "StepOver") end)
shootButton.Activated:Connect(function() kick("Shoot") end)
lobButton.Activated:Connect(function() kick("Lob") end)

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
        sprinting = not sprinting
        applySprint()
    elseif input.KeyCode == Enum.KeyCode.E then
        kick("Shoot")
    elseif input.KeyCode == Enum.KeyCode.Q then
        kick("Pass")
    elseif input.KeyCode == Enum.KeyCode.F then
        kick("Lob")
    elseif input.KeyCode == Enum.KeyCode.C then
        actionRemote:FireServer("Tackle")
    elseif input.KeyCode == Enum.KeyCode.Z then
        actionRemote:FireServer("SkillMove", "Feint")
    elseif input.KeyCode == Enum.KeyCode.X then
        actionRemote:FireServer("SkillMove", "StepOver")
    end
end)

local shadow = Instance.new("Part")
shadow.Name = "LocalBallShadow"
shadow.Shape = Enum.PartType.Cylinder
shadow.Size = Vector3.new(3, 0.035, 3)
shadow.Color = Color3.fromRGB(10, 18, 13)
shadow.Material = Enum.Material.SmoothPlastic
shadow.Transparency = 0.62
shadow.Anchored = true
shadow.CanCollide = false
shadow.CanTouch = false
shadow.CanQuery = false
shadow.CastShadow = false
shadow.Parent = Workspace

local shadowParams = RaycastParams.new()
shadowParams.FilterType = Enum.RaycastFilterType.Exclude
shadowParams.IgnoreWater = true

RunService.RenderStepped:Connect(function()
    local stadium = Workspace:FindFirstChild("SoccerStadium")
    local ballObject = stadium and stadium:FindFirstChild("MatchBall")
    if not ballObject or not ballObject:IsA("BasePart") then
        shadow.Transparency = 1
        return
    end
    local excluded: {Instance} = {ballObject}
    if player.Character then table.insert(excluded, player.Character) end
    shadowParams.FilterDescendantsInstances = excluded
    local result = Workspace:Raycast(ballObject.Position + Vector3.new(0, 2, 0), Vector3.new(0, -200, 0), shadowParams)
    if not result then
        shadow.Transparency = 1
        return
    end
    local height = math.max(0, ballObject.Position.Y - result.Position.Y)
    local diameter = math.clamp(BallConfig.Radius * 2 + height * 0.08, BallConfig.Radius * 2, BallConfig.Radius * 3.8)
    shadow.Size = Vector3.new(diameter, 0.035, diameter)
    shadow.CFrame = CFrame.new(result.Position + Vector3.new(0, 0.025, 0))
    shadow.Transparency = math.clamp(0.5 + height * 0.018, 0.5, 0.86)
end)

Workspace:GetAttributeChangedSignal("BallReady"):Connect(function()
    local ready = Workspace:GetAttribute("BallReady") == true
    shootButton.Active = ready
    passButton.Active = ready
    lobButton.Active = ready
end)

print("[PITCH] Player controls ready: sprint, close-control dribbling, feints, step-overs, tackling, adjustable pass/shot/lob power and mobile action buttons.")
