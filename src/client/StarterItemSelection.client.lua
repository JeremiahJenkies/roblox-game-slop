-- Polished starter-item selection UI.
-- Rojo path: src/client/StarterItemSelection.client.lua

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("SelectStarterItem")

local GOLD = Color3.fromRGB(255, 194, 46)
local GOLD_LIGHT = Color3.fromRGB(255, 222, 130)
local PANEL = Color3.fromRGB(20, 21, 29)
local PANEL_LIGHT = Color3.fromRGB(31, 33, 44)
local TEXT = Color3.fromRGB(245, 245, 250)
local MUTED = Color3.fromRGB(157, 161, 177)
local GREEN = Color3.fromRGB(100, 224, 151)

local gui = Instance.new("ScreenGui")
gui.Name = "StarterItemSelectionUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 20
gui.Parent = player:WaitForChild("PlayerGui")

local function addCorner(instance, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius)
    corner.Parent = instance
    return corner
end

local function addStroke(instance, color, thickness, transparency)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color
    stroke.Thickness = thickness
    stroke.Transparency = transparency or 0
    stroke.Parent = instance
    return stroke
end

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.52)
panel.Size = UDim2.new(0.86, 0, 0, 290)
panel.BackgroundColor3 = PANEL
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = gui
addCorner(panel, 18)
addStroke(panel, Color3.fromRGB(76, 78, 94), 1, 0.2)

local sizeConstraint = Instance.new("UISizeConstraint")
sizeConstraint.MinSize = Vector2.new(300, 290)
sizeConstraint.MaxSize = Vector2.new(430, 290)
sizeConstraint.Parent = panel

local panelPadding = Instance.new("UIPadding")
panelPadding.PaddingTop = UDim.new(0, 18)
panelPadding.PaddingBottom = UDim.new(0, 16)
panelPadding.PaddingLeft = UDim.new(0, 18)
panelPadding.PaddingRight = UDim.new(0, 18)
panelPadding.Parent = panel

local header = Instance.new("Frame")
header.Name = "Header"
header.BackgroundTransparency = 1
header.Size = UDim2.new(1, 0, 0, 48)
header.Parent = panel

local eyebrow = Instance.new("TextLabel")
eyebrow.BackgroundTransparency = 1
eyebrow.Size = UDim2.new(1, -42, 0, 16)
eyebrow.Font = Enum.Font.GothamBold
eyebrow.Text = "LOADOUT  /  STARTER ITEM"
eyebrow.TextSize = 10
eyebrow.TextColor3 = GOLD
eyebrow.TextXAlignment = Enum.TextXAlignment.Left
eyebrow.Parent = header

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(0, 17)
title.Size = UDim2.new(1, -42, 0, 29)
title.Font = Enum.Font.GothamBold
title.Text = "Choose your starter"
title.TextSize = 21
title.TextColor3 = TEXT
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header

local close = Instance.new("TextButton")
close.Name = "Close"
close.AnchorPoint = Vector2.new(1, 0)
close.Position = UDim2.new(1, 0, 0, 0)
close.Size = UDim2.fromOffset(32, 32)
close.BackgroundColor3 = PANEL_LIGHT
close.Text = "×"
close.TextColor3 = MUTED
close.TextSize = 24
close.Font = Enum.Font.Gotham
close.AutoButtonColor = true
close.Parent = header
addCorner(close, 10)

local card = Instance.new("Frame")
card.Name = "GoldenSmileyCard"
card.Position = UDim2.fromOffset(0, 58)
card.Size = UDim2.new(1, 0, 0, 126)
card.BackgroundColor3 = PANEL_LIGHT
card.BorderSizePixel = 0
card.Parent = panel
addCorner(card, 14)
local cardStroke = addStroke(card, GOLD, 1, 0.65)

local preview = Instance.new("Frame")
preview.Name = "Preview"
preview.Position = UDim2.fromOffset(12, 12)
preview.Size = UDim2.fromOffset(100, 100)
preview.BackgroundColor3 = Color3.fromRGB(55, 42, 20)
preview.BorderSizePixel = 0
preview.Parent = card
addCorner(preview, 12)

local previewGradient = Instance.new("UIGradient")
previewGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(92, 66, 22)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(35, 31, 28)),
})
previewGradient.Rotation = 45
previewGradient.Parent = preview

local emoji = Instance.new("TextLabel")
emoji.Name = "Emoji"
emoji.BackgroundTransparency = 1
emoji.Size = UDim2.fromScale(1, 1)
emoji.Font = Enum.Font.Gotham
emoji.Text = "☺"
emoji.TextColor3 = GOLD
emoji.TextSize = 70
emoji.Parent = preview

local emojiStroke = Instance.new("UIStroke")
emojiStroke.Color = GOLD_LIGHT
emojiStroke.Thickness = 1
emojiStroke.Transparency = 0.35
emojiStroke.Parent = emoji

local itemName = Instance.new("TextLabel")
itemName.BackgroundTransparency = 1
itemName.Position = UDim2.fromOffset(124, 17)
itemName.Size = UDim2.new(1, -136, 0, 25)
itemName.Font = Enum.Font.GothamBold
itemName.Text = "Golden Smiley"
itemName.TextSize = 16
itemName.TextColor3 = TEXT
itemName.TextXAlignment = Enum.TextXAlignment.Left
itemName.Parent = card

local rarity = Instance.new("TextLabel")
rarity.BackgroundTransparency = 1
rarity.Position = UDim2.fromOffset(124, 44)
rarity.Size = UDim2.new(1, -136, 0, 20)
rarity.Font = Enum.Font.GothamMedium
rarity.Text = "✦  STARTER  •  LEGENDARY STYLE"
rarity.TextSize = 9
rarity.TextColor3 = GOLD
rarity.TextXAlignment = Enum.TextXAlignment.Left
rarity.Parent = card

local description = Instance.new("TextLabel")
description.BackgroundTransparency = 1
description.Position = UDim2.fromOffset(124, 67)
description.Size = UDim2.new(1, -136, 0, 37)
description.Font = Enum.Font.Gotham
description.Text = "A little golden grin to start your journey."
description.TextWrapped = true
description.TextSize = 11
description.TextColor3 = MUTED
description.TextXAlignment = Enum.TextXAlignment.Left
description.TextYAlignment = Enum.TextYAlignment.Top
description.Parent = card

local selectButton = Instance.new("TextButton")
selectButton.Name = "SelectButton"
selectButton.Position = UDim2.new(0, 0, 0, 196)
selectButton.Size = UDim2.new(1, 0, 0, 42)
selectButton.BackgroundColor3 = GOLD
selectButton.BorderSizePixel = 0
selectButton.Font = Enum.Font.GothamBold
selectButton.Text = "SELECT STARTER"
selectButton.TextColor3 = Color3.fromRGB(37, 27, 8)
selectButton.TextSize = 13
selectButton.AutoButtonColor = false
selectButton.Parent = panel
addCorner(selectButton, 12)

local buttonGradient = Instance.new("UIGradient")
buttonGradient.Color = ColorSequence.new(GOLD_LIGHT, GOLD)
buttonGradient.Rotation = 90
buttonGradient.Parent = selectButton

local status = Instance.new("TextLabel")
status.Name = "Status"
status.BackgroundTransparency = 1
status.Position = UDim2.new(0, 0, 0, 246)
status.Size = UDim2.new(1, 0, 0, 18)
status.Font = Enum.Font.GothamMedium
status.Text = "Choose an item to set your starter."
status.TextSize = 10
status.TextColor3 = MUTED
status.Parent = panel

local openButton = Instance.new("TextButton")
openButton.Name = "OpenLoadout"
openButton.AnchorPoint = Vector2.new(0, 1)
openButton.Position = UDim2.new(0, 22, 1, -22)
openButton.Size = UDim2.fromOffset(150, 42)
openButton.BackgroundColor3 = PANEL
openButton.BorderSizePixel = 0
openButton.Font = Enum.Font.GothamBold
openButton.Text = "✦  STARTER ITEMS"
openButton.TextColor3 = GOLD_LIGHT
openButton.TextSize = 12
openButton.AutoButtonColor = false
openButton.Parent = gui
addCorner(openButton, 13)
addStroke(openButton, GOLD, 1, 0.55)

local selected = player:GetAttribute("SelectedStarterItem") or ""

local function refresh()
    if selected == "Golden Smiley" then
        selectButton.Text = "✓  SELECTED"
        selectButton.TextColor3 = Color3.fromRGB(20, 43, 29)
        selectButton.BackgroundColor3 = GREEN
        status.Text = "Golden Smiley is your selected starter."
        status.TextColor3 = GREEN
        cardStroke.Transparency = 0.15
    else
        selectButton.Text = "SELECT STARTER"
        selectButton.TextColor3 = Color3.fromRGB(37, 27, 8)
        selectButton.BackgroundColor3 = GOLD
        status.Text = "Choose an item to set your starter."
        status.TextColor3 = MUTED
        cardStroke.Transparency = 0.65
    end
end

local function setPanelVisible(visible)
    panel.Visible = visible
    if visible then
        panel.BackgroundTransparency = 1
        panel.Size = UDim2.new(0.86, 0, 0, 270)
        TweenService:Create(panel, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            BackgroundTransparency = 0,
            Size = UDim2.new(0.86, 0, 0, 290),
        }):Play()
    end
end

openButton.Activated:Connect(function()
    setPanelVisible(not panel.Visible)
end)

close.Activated:Connect(function()
    setPanelVisible(false)
end)

selectButton.Activated:Connect(function()
    selectButton.Text = "SAVING..."
    remote:FireServer("Golden Smiley")
end)

remote.OnClientEvent:Connect(function(action, itemNameFromServer)
    if action == "Selected" and itemNameFromServer == "Golden Smiley" then
        selected = itemNameFromServer
        refresh()
    end
end)

player:GetAttributeChangedSignal("SelectedStarterItem"):Connect(function()
    selected = player:GetAttribute("SelectedStarterItem") or ""
    refresh()
end)

refresh()
