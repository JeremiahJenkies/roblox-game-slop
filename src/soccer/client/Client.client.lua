-- PITCH soccer HUD and kick controls. The server validates every kick and owns match scoring.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("SoccerRemotes")
local stateEvent = remotes:WaitForChild("StateUpdate")
local noticeEvent = remotes:WaitForChild("Notice")
local kickEvent = remotes:WaitForChild("KickBall")
local gui = Instance.new("ScreenGui"); gui.Name = "SoccerHUD"; gui.ResetOnSpawn = false; gui.DisplayOrder = 20; gui.Parent = player:WaitForChild("PlayerGui")
local function rounded(obj, radius) local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, radius); c.Parent = obj end
local function label(parent, name, text, size, position, fontSize, color)
 local l = Instance.new("TextLabel"); l.Name = name; l.Text = text; l.Size = size; l.Position = position; l.BackgroundTransparency = 1
 l.Font = Enum.Font.GothamBold; l.TextSize = fontSize; l.TextColor3 = color; l.TextXAlignment = Enum.TextXAlignment.Center; l.Parent = parent; return l
end
local navy = Color3.fromRGB(14, 23, 32); local white = Color3.fromRGB(244, 247, 244); local red = Color3.fromRGB(238, 83, 85); local blue = Color3.fromRGB(83, 154, 255)
local top = Instance.new("Frame"); top.Name = "Scoreboard"; top.AnchorPoint = Vector2.new(0.5,0); top.Position = UDim2.new(0.5,0,0,18); top.Size = UDim2.new(0.78,0,0,104); top.BackgroundColor3 = navy; top.BackgroundTransparency = 0.08; top.Parent = gui; rounded(top,16)
local outline = Instance.new("UIStroke"); outline.Color = Color3.fromRGB(126, 153, 170); outline.Transparency = 0.45; outline.Parent = top
label(top,"GameTitle","P I T C H   /   C O M P E T I T I V E   S O C C E R",UDim2.new(1,0,0,22),UDim2.fromOffset(0,8),12,Color3.fromRGB(183,202,215))
local redScore = label(top,"RedScore","RED  0",UDim2.new(0.35,0,0,38),UDim2.new(0.03,0,0,32),21,red)
local clock = label(top,"Clock","KICKOFF",UDim2.new(0.24,0,0,34),UDim2.new(0.38,0,0,34),17,white)
local blueScore = label(top,"BlueScore","0  BLUE",UDim2.new(0.35,0,0,38),UDim2.new(0.62,0,0,32),21,blue)
local phaseLabel = label(top,"Phase","GET READY",UDim2.new(1,0,0,18),UDim2.new(0,0,0,78),10,Color3.fromRGB(185,201,211))
local teamCard = Instance.new("Frame"); teamCard.Name = "PlayerCard"; teamCard.Position = UDim2.new(0,18,0,136); teamCard.Size = UDim2.fromOffset(190,76); teamCard.BackgroundColor3 = navy; teamCard.BackgroundTransparency = 0.1; teamCard.Parent = gui; rounded(teamCard,12)
local teamLabel = label(teamCard,"Team","TEAM: ASSIGNING",UDim2.new(1,-12,0,26),UDim2.fromOffset(6,7),14,white)
local statsLabel = label(teamCard,"Stats","W 0   G 0   MATCHES 0",UDim2.new(1,-12,0,22),UDim2.fromOffset(6,39),10,Color3.fromRGB(192,211,221))
local kickButton = Instance.new("TextButton"); kickButton.Name = "KickButton"; kickButton.AnchorPoint = Vector2.new(1,1); kickButton.Position = UDim2.new(1,-24,1,-34); kickButton.Size = UDim2.fromOffset(164,68); kickButton.BackgroundColor3 = Color3.fromRGB(245,247,242); kickButton.Text = "KICK  [E]"; kickButton.TextColor3 = Color3.fromRGB(20,31,40); kickButton.Font = Enum.Font.GothamBlack; kickButton.TextSize = 18; kickButton.Parent = gui; rounded(kickButton,18)
local kickStroke = Instance.new("UIStroke"); kickStroke.Color = Color3.fromRGB(173,204,216); kickStroke.Thickness = 2; kickStroke.Parent = kickButton
local notice = Instance.new("TextLabel"); notice.Name = "Notice"; notice.AnchorPoint = Vector2.new(0.5,0); notice.Position = UDim2.new(0.5,0,0,136); notice.Size = UDim2.new(0.7,0,0,42); notice.BackgroundColor3 = navy; notice.BackgroundTransparency = 1; notice.TextTransparency = 1; notice.TextColor3 = white; notice.TextWrapped = true; notice.Font = Enum.Font.GothamBold; notice.TextSize = 15; notice.Parent = gui; rounded(notice,10)
local noticeId = 0
local function showNotice(message)
 noticeId += 1; local id = noticeId; notice.Text = tostring(message); notice.BackgroundTransparency = 0.12; notice.TextTransparency = 0
 task.delay(2.8,function() if id == noticeId and notice.Parent then notice.BackgroundTransparency = 1; notice.TextTransparency = 1 end end)
end
local function kick()
 local character = player.Character; local root = character and character:FindFirstChild("HumanoidRootPart"); local ball = workspace:FindFirstChild("SoccerStadium") and workspace.SoccerStadium:FindFirstChild("MatchBall")
 if not root or not ball then showNotice("Waiting for the match ball..."); return end
 if (root.Position - ball.Position).Magnitude > 13 then showNotice("Get closer to the ball!"); return end
 local camera = workspace.CurrentCamera; local direction
 if UserInputService.MouseEnabled then
  local mouse = player:GetMouse(); local target = mouse.Hit.Position; direction = Vector3.new(target.X - ball.Position.X, math.clamp(target.Y - ball.Position.Y,0,10), target.Z - ball.Position.Z)
 else direction = camera and camera.CFrame.LookVector or root.CFrame.LookVector end
 if direction.Magnitude > 0 then direction = direction.Unit end
 kickEvent:FireServer(direction)
end
kickButton.Activated:Connect(kick)
UserInputService.InputBegan:Connect(function(input, processed)
 if processed then return end
 if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.ButtonR2 then kick() end
end)
local function updatePlayerStats()
 local team = player:GetAttribute("Team") or "ASSIGNING"
 teamLabel.Text = "TEAM: " .. string.upper(team); teamLabel.TextColor3 = team == "Red" and red or (team == "Blue" and blue or white)
 statsLabel.Text = "W " .. tostring(player:GetAttribute("SoccerWins") or 0) .. "   G " .. tostring(player:GetAttribute("Goals") or 0) .. "   MATCHES " .. tostring(player:GetAttribute("Matches") or 0)
end
for _, attr in ipairs({"Team","SoccerWins","Goals","Matches"}) do player:GetAttributeChangedSignal(attr):Connect(updatePlayerStats) end
updatePlayerStats()
stateEvent.OnClientEvent:Connect(function(state)
 if type(state) ~= "table" then return end
 redScore.Text = "RED  " .. tostring(state.redScore or 0); blueScore.Text = tostring(state.blueScore or 0) .. "  BLUE"
 phaseLabel.Text = string.upper(tostring(state.phase or "READY")) .. "  •  MATCH " .. tostring(state.matchNumber or 0)
 local remaining = math.max(0, tonumber(state.secondsLeft) or 0); clock.Text = string.format("%02d:%02d", math.floor(remaining/60), remaining%60)
 if state.phase == "LIVE" then clock.TextColor3 = Color3.fromRGB(142,245,177) else clock.TextColor3 = white end
end)
noticeEvent.OnClientEvent:Connect(showNotice)