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
local sprintButton = addButton("SprintButton", "SPRINT", isTouch and "TAP TO TOGGLE" or "[SHIFT]", UDim2.new(0, isTouch and 158 or 18, 1, -(isTouch and 138 or 20)), UDim2.fromOffset(isTouch and 132 or 106, isTouch and 62 or 48), Color3.fromRGB(183, 116, 35))
sprintButton.AnchorPoint = Vector2.new(0, 1)
local sprinting = false
local humanoid: Humanoid? = nil

local function applySprint()
    local character = player.Character
    local currentHumanoid = character and character:FindFirstChildOfClass("Humanoid")
    humanoid = currentHumanoid
    if currentHumanoid then
        currentHumanoid.WalkSpeed = sprinting and PlayerConfig.SprintSpeed or PlayerConfig.WalkSpeed
    end
    sprintButton.Text = sprinting and "SPRINT ON" or ("SPRINT\n" .. (isTouch and "TAP TO TOGGLE" or "[SHIFT]"))
    sprintButton.BackgroundColor3 = sprinting and Color3.fromRGB(34, 151, 91) or Color3.fromRGB(183, 116, 35)
end

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
    local power = action == "Pass" and 0.72 or (action == "Lob" and 0.82 or 0.9)
    kickRemote:FireServer(action, direction.Unit, power)
end

passButton.Activated:Connect(function() kick("Pass") end)
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

print("[PITCH] Player controls ready: default movement, sprint, pass, shoot, lob and mobile action buttons.")
