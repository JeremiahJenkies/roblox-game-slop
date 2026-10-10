--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local BallConfig = require(Shared:WaitForChild("Config"):WaitForChild("BallConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local player = Players.LocalPlayer
local events = Remotes.GetClient()
local kickRemote: RemoteEvent = events.KickBall
local noticeRemote: RemoteEvent = events.Notice

-- Remove previously synced LocalScripts and ScreenGuis from the older prototypes.
-- These paths were removed from default.project.json, but Studio can retain instances that were already synced.
local legacyScriptNames = {SoccerClient = true, IceYetiClient = true}
local playerScripts = player:WaitForChild("PlayerScripts")
for _, child in ipairs(playerScripts:GetChildren()) do
    if child ~= script and child:IsA("LocalScript") and legacyScriptNames[child.Name] then
        warn("[PITCH] Removing stale client script: " .. child.Name)
        child:Destroy()
    end
end
local playerGui = player:WaitForChild("PlayerGui")
for _, child in ipairs(playerGui:GetChildren()) do
    if child:IsA("ScreenGui") and (child.Name == "SoccerHUD" or child.Name == "IceYetiHUD") then
        warn("[PITCH] Removing stale HUD: " .. child.Name)
        child:Destroy()
    end
end

player.CameraMode = Enum.CameraMode.Classic
player.CameraMinZoomDistance = 16
player.CameraMaxZoomDistance = 70

local gui = Instance.new("ScreenGui")
gui.Name = "PITCHControls"
gui.ResetOnSpawn = false
gui.DisplayOrder = 25
gui.Parent = playerGui

local function rounded(instance: Instance, radius: number)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius)
    corner.Parent = instance
end

local function addButton(action: string, title: string, hotkey: string, order: number, color: Color3)
    local button = Instance.new("TextButton")
    button.Name = action .. "Button"
    button.AnchorPoint = Vector2.new(1, 1)
    button.Position = UDim2.new(1, -22 - (order - 1) * 136, 1, -26)
    button.Size = UDim2.fromOffset(124, 58)
    button.BackgroundColor3 = color
    button.Text = title .. "  [" .. hotkey .. "]"
    button.TextColor3 = Color3.fromRGB(246, 249, 251)
    button.Font = Enum.Font.GothamBlack
    button.TextSize = 14
    button.AutoButtonColor = true
    button.Parent = gui
    rounded(button, 13)
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(212, 228, 238)
    stroke.Transparency = 0.65
    stroke.Parent = button
    button.Activated:Connect(function()
        local actionDirection
        local camera = Workspace.CurrentCamera
        if UserInputService.MouseEnabled then
            local mouse = player:GetMouse()
            local target = mouse.Hit.Position
            local ballObject = Workspace:FindFirstChild("SoccerStadium") and Workspace.SoccerStadium:FindFirstChild("MatchBall")
            local origin = ballObject and ballObject:IsA("BasePart") and ballObject.Position or (player.Character and player.Character:GetPivot().Position or Vector3.zero)
            actionDirection = target - origin
        else
            actionDirection = camera and camera.CFrame.LookVector or Vector3.new(0, 0, -1)
        end
        if not actionDirection or actionDirection.Magnitude < 0.05 then return end
        local normalized = actionDirection.Unit
        local power = action == "Pass" and 0.72 or (action == "Lob" and 0.82 or 0.9)
        kickRemote:FireServer(action, normalized, power)
    end)
    return button
end

local passButton = addButton("Pass", "PASS", "Q", 3, Color3.fromRGB(50, 102, 146))
local lobButton = addButton("Lob", "LOB", "F", 2, Color3.fromRGB(91, 83, 145))
local shootButton = addButton("Shoot", "SHOOT", "E", 1, Color3.fromRGB(34, 126, 78))

local function tryAction(action: string)
    local camera = Workspace.CurrentCamera
    local direction = camera and camera.CFrame.LookVector or Vector3.new(0, 0, -1)
    if UserInputService.MouseEnabled then
        local mouse = player:GetMouse()
        local target = mouse.Hit.Position
        local ballObject = Workspace:FindFirstChild("SoccerStadium") and Workspace.SoccerStadium:FindFirstChild("MatchBall")
        local origin = ballObject and ballObject:IsA("BasePart") and ballObject.Position or (player.Character and player.Character:GetPivot().Position or Vector3.zero)
        direction = target - origin
    end
    if direction.Magnitude < 0.05 then return end
    local power = action == "Pass" and 0.72 or (action == "Lob" and 0.82 or 0.9)
    kickRemote:FireServer(action, direction.Unit, power)
end

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.E then
        tryAction("Shoot")
    elseif input.KeyCode == Enum.KeyCode.Q then
        tryAction("Pass")
    elseif input.KeyCode == Enum.KeyCode.F then
        tryAction("Lob")
    end
end)

local shadow = Instance.new("Part")
shadow.Name = "LocalBallShadow"
shadow.Shape = Enum.PartType.Cylinder
shadow.Size = Vector3.new(3.0, 0.035, 3.0)
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
    local origin = ballObject.Position + Vector3.new(0, 2, 0)
    local result = Workspace:Raycast(origin, Vector3.new(0, -200, 0), shadowParams)
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
    shootButton.Active = ready; passButton.Active = ready; lobButton.Active = ready
end)

print("[PITCH] Pass (Q), Shoot (E) and Lob (F) controls ready; mobile buttons are available.")