--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local player = Players.LocalPlayer
local events = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes")).GetClient()
local stateEvent: RemoteEvent = events.StateUpdate
local noticeEvent: RemoteEvent = events.Notice
local stateRequest: RemoteEvent = events.StateRequest
local profileRequest: RemoteEvent = events.ProfileRequest

local COLORS = {
    Background = Color3.fromRGB(13, 22, 31),
    Panel = Color3.fromRGB(19, 31, 42),
    Text = Color3.fromRGB(242, 247, 250),
    Muted = Color3.fromRGB(163, 185, 200),
    Red = Color3.fromRGB(238, 83, 85),
    Blue = Color3.fromRGB(83, 154, 255),
    Green = Color3.fromRGB(106, 219, 150),
}

local gui = Instance.new("ScreenGui")
gui.Name = "PITCHHUD"
gui.ResetOnSpawn = false
gui.DisplayOrder = 20
gui.IgnoreGuiInset = false
gui.Parent = player:WaitForChild("PlayerGui")

local function rounded(instance: Instance, radius: number)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius)
    corner.Parent = instance
end

local function label(parent: Instance, name: string, value: string, size: UDim2, position: UDim2, textSize: number, color: Color3, font: Enum.Font?)
    local item = Instance.new("TextLabel")
    item.Name = name
    item.BackgroundTransparency = 1
    item.Text = value
    item.Size = size
    item.Position = position
    item.Font = font or Enum.Font.GothamBold
    item.TextColor3 = color
    item.TextSize = textSize
    item.TextWrapped = true
    item.TextXAlignment = Enum.TextXAlignment.Center
    item.Parent = parent
    return item
end

local top = Instance.new("Frame")
top.Name = "PITCHHeader"
top.AnchorPoint = Vector2.new(0.5, 0)
top.Position = UDim2.new(0.5, 0, 0, 16)
top.Size = UDim2.new(0.76, 0, 0, 95)
top.BackgroundColor3 = COLORS.Background
top.BackgroundTransparency = 0.06
top.Parent = gui
rounded(top, 16)
local topStroke = Instance.new("UIStroke")
topStroke.Color = Color3.fromRGB(107, 134, 153)
topStroke.Transparency = 0.45
topStroke.Parent = top
label(top, "Title", "P I T C H", UDim2.new(1, 0, 0, 31), UDim2.fromOffset(0, 7), 23, COLORS.Text, Enum.Font.GothamBlack)
label(top, "Subtitle", "COMPETITIVE SOCCER  /  FOUNDATION BUILD", UDim2.new(1, 0, 0, 15), UDim2.fromOffset(0, 39), 10, COLORS.Muted)
local phaseLabel = label(top, "Phase", "LOBBY", UDim2.new(1, 0, 0, 22), UDim2.fromOffset(0, 61), 13, COLORS.Green, Enum.Font.GothamBlack)

local statusBar = Instance.new("Frame")
statusBar.Name = "StadiumStatus"
statusBar.AnchorPoint = Vector2.new(0.5, 0)
statusBar.Position = UDim2.new(0.5, 0, 0, 121)
statusBar.Size = UDim2.new(0.52, 0, 0, 34)
statusBar.BackgroundColor3 = COLORS.Panel
statusBar.BackgroundTransparency = 0.08
statusBar.Parent = gui
rounded(statusBar, 10)
local stadiumLabel = label(statusBar, "StadiumReady", "GENERATING STADIUM...", UDim2.new(1, -16, 1, 0), UDim2.fromOffset(8, 0), 12, COLORS.Muted)

local teamCard = Instance.new("Frame")
teamCard.Name = "TeamCard"
teamCard.Position = UDim2.new(0, 18, 0, 174)
teamCard.Size = UDim2.fromOffset(208, 112)
teamCard.BackgroundColor3 = COLORS.Background
teamCard.BackgroundTransparency = 0.1
teamCard.Parent = gui
rounded(teamCard, 13)
local teamLabel = label(teamCard, "Team", "TEAM: ASSIGNING", UDim2.new(1, -16, 0, 27), UDim2.fromOffset(8, 8), 14, COLORS.Text, Enum.Font.GothamBlack)
local statsLabel = label(teamCard, "Stats", "WINS 0  •  GOALS 0", UDim2.new(1, -16, 0, 22), UDim2.fromOffset(8, 43), 11, COLORS.Muted)
local matchesLabel = label(teamCard, "Matches", "MATCHES 0  •  LEVEL 1", UDim2.new(1, -16, 0, 22), UDim2.fromOffset(8, 70), 10, COLORS.Muted)
local coinsLabel = label(teamCard, "Coins", "CREDITS 0  •  XP 0", UDim2.new(1, -16, 0, 18), UDim2.fromOffset(8, 91), 9, Color3.fromRGB(255, 204, 120))

local notice = Instance.new("TextLabel")
notice.Name = "Notice"
notice.AnchorPoint = Vector2.new(0.5, 1)
notice.Position = UDim2.new(0.5, 0, 1, -24)
notice.Size = UDim2.new(0.62, 0, 0, 44)
notice.BackgroundColor3 = COLORS.Background
notice.BackgroundTransparency = 1
notice.TextTransparency = 1
notice.TextColor3 = COLORS.Text
notice.Font = Enum.Font.GothamBold
notice.TextSize = 14
notice.TextWrapped = true
notice.Parent = gui
rounded(notice, 11)
local noticeToken = 0
local function showNotice(message: any)
    noticeToken += 1
    local token = noticeToken
    notice.Text = tostring(message)
    notice.BackgroundTransparency = 0.08
    notice.TextTransparency = 0
    task.delay(3, function()
        if notice.Parent and noticeToken == token then
            notice.BackgroundTransparency = 1
            notice.TextTransparency = 1
        end
    end)
end

local function updatePitchStatus()
    local ready = Workspace:GetAttribute("PitchReady") == true
    stadiumLabel.Text = ready and "STADIUM READY  •  PITCH, GOALS, SPAWNS AND STANDS CREATED" or "GENERATING STADIUM..."
    stadiumLabel.TextColor3 = ready and COLORS.Green or COLORS.Muted
end

local function updateTeam()
    local team = tostring(player:GetAttribute("Team") or (player.Team and player.Team.Name) or "Assigning")
    teamLabel.Text = "TEAM: " .. string.upper(team)
    teamLabel.TextColor3 = team == "Red" and COLORS.Red or (team == "Blue" and COLORS.Blue or COLORS.Text)
end

local function updateProfile(profile: any)
    if type(profile) ~= "table" then return end
    statsLabel.Text = "WINS " .. tostring(profile.Wins or 0) .. "  •  GOALS " .. tostring(profile.Goals or 0)
    matchesLabel.Text = "MATCHES " .. tostring(profile.MatchesPlayed or 0) .. "  •  LEVEL " .. tostring(profile.Level or 1)
    coinsLabel.Text = "CREDITS " .. tostring(profile.Coins or 0) .. "  •  XP " .. tostring(profile.XP or 0)
end

stateEvent.OnClientEvent:Connect(function(state: any)
    if type(state) ~= "table" then return end
    phaseLabel.Text = string.upper(tostring(state.phase or "LOBBY"))
end)
noticeEvent.OnClientEvent:Connect(showNotice)
events.ProfileUpdate.OnClientEvent:Connect(updateProfile)
player:GetAttributeChangedSignal("Team"):Connect(updateTeam)
Workspace:GetAttributeChangedSignal("PitchReady"):Connect(updatePitchStatus)
player:GetPropertyChangedSignal("Team"):Connect(updateTeam)
updateTeam()
updatePitchStatus()
stateRequest:FireServer("RequestState")
profileRequest:FireServer("RequestProfile")