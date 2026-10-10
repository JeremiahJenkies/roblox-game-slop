-- Halloween survival HUD and client-side visual polish. Gameplay decisions stay on the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("IceYetiRemotes")
local stateEvent = remotes:WaitForChild("StateUpdate")
local noticeEvent = remotes:WaitForChild("Notice")
local flareEvent = remotes:WaitForChild("ThrowFlare")

local gui = Instance.new("ScreenGui")
gui.Name = "IceYetiHUD"
gui.ResetOnSpawn = false
gui.DisplayOrder = 20
gui.Parent = player:WaitForChild("PlayerGui")

local function rounded(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

local function makeLabel(parent, name, text, size, position, font, color, textSize)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Text = text
	label.Size = size
	label.Position = position
	label.Font = font or Enum.Font.Gotham
	label.TextColor3 = color or Color3.fromRGB(245, 242, 238)
	label.TextSize = textSize or 14
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

local showNotice

local top = Instance.new("Frame")
top.Name = "TopBar"
top.AnchorPoint = Vector2.new(0.5, 0)
top.Position = UDim2.new(0.5, 0, 0, 18)
top.Size = UDim2.new(0.9, 0, 0, 88)
top.BackgroundColor3 = Color3.fromRGB(20, 24, 36)
top.BackgroundTransparency = 0.08
top.Parent = gui
rounded(top, 16)
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(255, 116, 65)
stroke.Transparency = 0.25
stroke.Parent = top

makeLabel(top, "GameTitle", "SURVIVE ICE YETIS", UDim2.new(1, -24, 0, 26), UDim2.fromOffset(16, 10), Enum.Font.GothamBlack, Color3.fromRGB(255, 145, 83), 18)
local dayLabel = makeLabel(top, "Day", "DAY 0 / 100", UDim2.new(0.48, 0, 0, 25), UDim2.fromOffset(16, 45), Enum.Font.GothamBold, Color3.fromRGB(245, 245, 250), 15)
local phaseLabel = makeLabel(top, "Phase", "PREPARING", UDim2.new(0.5, -16, 0, 25), UDim2.new(0.5, 0, 0, 45), Enum.Font.GothamBold, Color3.fromRGB(130, 218, 255), 14)
phaseLabel.TextXAlignment = Enum.TextXAlignment.Right


local flareButton = Instance.new("TextButton")
flareButton.Name = "ThrowFlare"
flareButton.AnchorPoint = Vector2.new(1, 0)
flareButton.Position = UDim2.new(1, -18, 0, 120)
flareButton.Size = UDim2.fromOffset(170, 48)
flareButton.BackgroundColor3 = Color3.fromRGB(174, 66, 42)
flareButton.Text = "✦  THROW FLARE"
flareButton.TextColor3 = Color3.fromRGB(255, 242, 225)
flareButton.Font = Enum.Font.GothamBlack
flareButton.TextSize = 13
flareButton.Parent = gui
rounded(flareButton, 12)
local flareStroke = Instance.new("UIStroke")
flareStroke.Color = Color3.fromRGB(255, 157, 87)
flareStroke.Transparency = 0.2
flareStroke.Parent = flareButton

local function nearestYeti()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local world = workspace:FindFirstChild("IceYetiWorld")
	local folder = world and world:FindFirstChild("Yetis")
	if not root or not folder then return nil end
	local selected, selectedDistance
	for _, model in ipairs(folder:GetChildren()) do
		if model:IsA("Model") and model:GetAttribute("IsIceYeti") then
			local yetiRoot = model:FindFirstChild("HumanoidRootPart")
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if yetiRoot and humanoid and humanoid.Health > 0 then
				local distance = (yetiRoot.Position - root.Position).Magnitude
				if distance <= 90 and (not selectedDistance or distance < selectedDistance) then
					selected, selectedDistance = model, distance
				end
			end
		end
	end
	return selected, selectedDistance
end

flareButton.Activated:Connect(function()
	local target, distance = nearestYeti()
	if not target then
		showNotice("No Ice Yeti in flare range. Keep moving!")
		return
	end
	flareEvent:FireServer(target)
	flareButton.Text = "FLARE THROWN"
	task.delay(0.65, function()
		if flareButton.Parent then flareButton.Text = "✦  THROW FLARE" end
	end)
end)

local stats = Instance.new("Frame")
stats.Name = "PlayerStats"
stats.Position = UDim2.new(0, 18, 0, 120)
stats.Size = UDim2.fromOffset(190, 88)
stats.BackgroundColor3 = Color3.fromRGB(20, 24, 36)
stats.BackgroundTransparency = 0.1
stats.Parent = gui
rounded(stats, 13)
local coinsLabel = makeLabel(stats, "Coins", "◈  0 COINS", UDim2.new(1, -20, 0, 24), UDim2.fromOffset(12, 10), Enum.Font.GothamBold, Color3.fromRGB(255, 195, 78), 14)
local bestLabel = makeLabel(stats, "BestDay", "BEST DAY  0", UDim2.new(1, -20, 0, 22), UDim2.fromOffset(12, 36), Enum.Font.GothamBold, Color3.fromRGB(208, 227, 240), 12)
local winsLabel = makeLabel(stats, "Wins", "100-DAY WINS  0", UDim2.new(1, -20, 0, 22), UDim2.fromOffset(12, 59), Enum.Font.GothamBold, Color3.fromRGB(208, 227, 240), 12)

local timerBack = Instance.new("Frame")
timerBack.Name = "TimerBack"
timerBack.AnchorPoint = Vector2.new(0.5, 1)
timerBack.Position = UDim2.new(0.5, 0, 1, -24)
timerBack.Size = UDim2.new(0.58, 0, 0, 12)
timerBack.BackgroundColor3 = Color3.fromRGB(25, 29, 42)
timerBack.Parent = gui
rounded(timerBack, 6)
local timerFill = Instance.new("Frame")
timerFill.Name = "Fill"
timerFill.Size = UDim2.fromScale(1, 1)
timerFill.BackgroundColor3 = Color3.fromRGB(255, 117, 65)
timerFill.Parent = timerBack
rounded(timerFill, 6)
local timerText = makeLabel(gui, "Timer", "GET READY", UDim2.new(0.8, 0, 0, 22), UDim2.new(0.1, 0, 1, -53), Enum.Font.GothamBold, Color3.fromRGB(245, 242, 238), 12)
timerText.TextXAlignment = Enum.TextXAlignment.Center

local notice = Instance.new("TextLabel")
notice.Name = "Notice"
notice.AnchorPoint = Vector2.new(0.5, 0)
notice.Position = UDim2.new(0.5, 0, 0, 120)
notice.Size = UDim2.new(0.86, 0, 0, 54)
notice.BackgroundColor3 = Color3.fromRGB(47, 24, 33)
notice.BackgroundTransparency = 1
notice.TextTransparency = 1
notice.Text = ""
notice.TextWrapped = true
notice.Font = Enum.Font.GothamBlack
notice.TextSize = 17
notice.TextColor3 = Color3.fromRGB(255, 167, 116)
notice.Parent = gui
rounded(notice, 12)

showNotice = function(message)
	notice.Text = tostring(message)
	TweenService:Create(notice, TweenInfo.new(0.2), {BackgroundTransparency = 0.08, TextTransparency = 0}):Play()
	task.delay(3.5, function()
		if notice.Parent then
			TweenService:Create(notice, TweenInfo.new(0.35), {BackgroundTransparency = 1, TextTransparency = 1}):Play()
		end
	end)
end

local function updateStats()
	coinsLabel.Text = "◈  " .. tostring(player:GetAttribute("Coins") or 0) .. " COINS"
	bestLabel.Text = "BEST DAY  " .. tostring(player:GetAttribute("BestDay") or 0)
	winsLabel.Text = "100-DAY WINS  " .. tostring(player:GetAttribute("Wins") or 0)
end
player:GetAttributeChangedSignal("Coins"):Connect(updateStats)
player:GetAttributeChangedSignal("BestDay"):Connect(updateStats)
player:GetAttributeChangedSignal("Wins"):Connect(updateStats)
updateStats()

stateEvent.OnClientEvent:Connect(function(state)
	if type(state) ~= "table" then return end
	dayLabel.Text = string.format("DAY %d / %d", state.day or 0, state.targetDays or 100)
	phaseLabel.Text = string.upper(tostring(state.phase or "UNKNOWN"))
	local duration = (state.phase == "Yeti Hunt") and 75 or 12
	local remaining = math.max(0, tonumber(state.secondsLeft) or 0)
	timerFill.Size = UDim2.fromScale(math.clamp(remaining / duration, 0, 1), 1)
	timerText.Text = (state.phase == "Yeti Hunt" and "SURVIVE THE HUNT  •  " or "NEXT HUNT IN  •  ") .. tostring(remaining) .. "s"
	phaseLabel.TextColor3 = state.phase == "Yeti Hunt" and Color3.fromRGB(255, 118, 91) or Color3.fromRGB(130, 218, 255)
end)
noticeEvent.OnClientEvent:Connect(showNotice)

-- Small local atmospheric layer; no gameplay authority is placed on the client.
local atmosphere = Lighting:FindFirstChild("IceYetiAtmosphere") or Instance.new("Atmosphere")
atmosphere.Name = "IceYetiAtmosphere"
atmosphere.Density = 0.32
atmosphere.Offset = 0.12
atmosphere.Color = Color3.fromRGB(164, 190, 224)
atmosphere.Decay = Color3.fromRGB(60, 68, 105)
atmosphere.Glare = 0.1
atmosphere.Haze = 1.8
atmosphere.Parent = Lighting
