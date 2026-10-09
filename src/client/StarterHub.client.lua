-- Starter Hub: inventory, starter selection and shop UI.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local action = ReplicatedStorage:WaitForChild("StarterHubAction")
local getState = ReplicatedStorage:WaitForChild("GetStarterHubState")

local GOLD = Color3.fromRGB(255, 194, 46)
local GOLD_LIGHT = Color3.fromRGB(255, 224, 145)
local PANEL = Color3.fromRGB(19, 21, 29)
local CARD = Color3.fromRGB(31, 34, 45)
local TEXT = Color3.fromRGB(245, 246, 250)
local MUTED = Color3.fromRGB(160, 165, 181)
local GREEN = Color3.fromRGB(101, 225, 153)
local RED = Color3.fromRGB(255, 125, 125)

local state
local gui = Instance.new("ScreenGui")
gui.Name = "StarterHubUI"
gui.ResetOnSpawn = false
gui.DisplayOrder = 30
gui.Parent = player:WaitForChild("PlayerGui")

local function corner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius)
    c.Parent = parent
end
local function stroke(parent, color, transparency)
    local s = Instance.new("UIStroke")
    s.Color = color
    s.Thickness = 1
    s.Transparency = transparency or 0.5
    s.Parent = parent
end
local function label(parent, name, text, size, position, font, color, textSize)
    local l = Instance.new("TextLabel")
    l.Name = name
    l.BackgroundTransparency = 1
    l.Text = text
    l.Size = size
    l.Position = position
    l.Font = font or Enum.Font.Gotham
    l.TextColor3 = color or TEXT
    l.TextSize = textSize or 13
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = parent
    return l
end

local open = Instance.new("TextButton")
open.Name = "OpenStarterHub"
open.Position = UDim2.new(0, 20, 1, -68)
open.Size = UDim2.fromOffset(160, 44)
open.BackgroundColor3 = PANEL
open.Text = "✦  STARTER HUB"
open.TextColor3 = GOLD_LIGHT
open.Font = Enum.Font.GothamBold
open.TextSize = 12
open.Parent = gui
corner(open, 13); stroke(open, GOLD, 0.4)

local panel = Instance.new("Frame")
panel.Name = "HubPanel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.new(0.9, 0, 0, 400)
panel.BackgroundColor3 = PANEL
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = gui
corner(panel, 18); stroke(panel, Color3.fromRGB(82, 85, 103), 0.2)
local constraint = Instance.new("UISizeConstraint")
constraint.MinSize = Vector2.new(310, 400)
constraint.MaxSize = Vector2.new(520, 400)
constraint.Parent = panel

local top = label(panel, "Eyebrow", "PLAYER COLLECTION  /  LOADOUT", UDim2.new(1, -100, 0, 16), UDim2.fromOffset(20, 16), Enum.Font.GothamBold, GOLD, 10)
local heading = label(panel, "Heading", "Starter Hub", UDim2.new(1, -100, 0, 30), UDim2.fromOffset(20, 34), Enum.Font.GothamBold, TEXT, 23)
local coins = label(panel, "Coins", "◈ 0 COINS", UDim2.fromOffset(130, 25), UDim2.new(1, -160, 0, 32), Enum.Font.GothamBold, GOLD_LIGHT, 13)
coins.TextXAlignment = Enum.TextXAlignment.Right

local close = Instance.new("TextButton")
close.Size = UDim2.fromOffset(32, 32)
close.Position = UDim2.new(1, -46, 0, 14)
close.BackgroundColor3 = CARD
close.Text = "×"
close.TextColor3 = TEXT
close.TextSize = 23
close.Font = Enum.Font.Gotham
close.Parent = panel
corner(close, 10)

local tabs = Instance.new("Frame")
tabs.BackgroundTransparency = 1
tabs.Position = UDim2.fromOffset(18, 78)
tabs.Size = UDim2.new(1, -36, 0, 38)
tabs.Parent = panel
local content = Instance.new("ScrollingFrame")
content.Name = "Items"
content.Position = UDim2.fromOffset(18, 126)
content.Size = UDim2.new(1, -36, 0, 220)
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.ScrollBarThickness = 4
content.ScrollBarImageColor3 = GOLD
content.CanvasSize = UDim2.new()
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.Parent = panel
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 9)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = content
local status = label(panel, "Status", "Loading your collection...", UDim2.new(1, -36, 0, 22), UDim2.new(0, 18, 1, -31), Enum.Font.GothamMedium, MUTED, 11)

local currentTab = "Inventory"
local function clearContent()
    for _, child in ipairs(content:GetChildren()) do
        if child ~= layout and not child:IsA("UIListLayout") then
            child:Destroy()
        end
    end
end

local function showStatus(message, success)
    status.Text = message
    status.TextColor3 = success and GREEN or RED
end

local function makeTab(name, xScale, width)
    local button = Instance.new("TextButton")
    button.Name = name .. "Tab"
    button.Position = UDim2.new(xScale, 0, 0, 0)
    button.Size = UDim2.new(width, -5, 1, 0)
    button.BackgroundColor3 = CARD
    button.Text = name
    button.TextColor3 = TEXT
    button.Font = Enum.Font.GothamBold
    button.TextSize = 12
    button.Parent = tabs
    corner(button, 10)
    button.Activated:Connect(function()
        currentTab = name
        render()
    end)
end

local function makeItemCard(name, info, owned)
    local item = Instance.new("Frame")
    item.Name = name:gsub("%s", "") .. "Card"
    item.Size = UDim2.new(1, -4, 0, 88)
    item.BackgroundColor3 = CARD
    item.BorderSizePixel = 0
    item.Parent = content
    corner(item, 13)
    stroke(item, name == (state and state.selected) and GOLD or Color3.fromRGB(65, 68, 82), 0.55)

    local preview = Instance.new("Frame")
    preview.Position = UDim2.fromOffset(10, 10)
    preview.Size = UDim2.fromOffset(66, 66)
    preview.BackgroundColor3 = name == "Golden Smiley" and Color3.fromRGB(83, 61, 25) or Color3.fromRGB(57, 64, 79)
    preview.Parent = item
    corner(preview, 11)
    local symbol = label(preview, "Icon", name == "Golden Smiley" and "☺" or "★", UDim2.fromScale(1, 1), UDim2.new(), Enum.Font.GothamBold, name == "Golden Smiley" and GOLD or Color3.fromRGB(215, 225, 240), 44)
    symbol.TextXAlignment = Enum.TextXAlignment.Center

    label(item, "ItemName", name, UDim2.new(1, -185, 0, 22), UDim2.fromOffset(87, 12), Enum.Font.GothamBold, TEXT, 14)
    label(item, "Description", info.description, UDim2.new(1, -185, 0, 30), UDim2.fromOffset(87, 36), Enum.Font.Gotham, MUTED, 10)

    local button = Instance.new("TextButton")
    button.AnchorPoint = Vector2.new(1, 0.5)
    button.Position = UDim2.new(1, -10, 0.5, 0)
    button.Size = UDim2.fromOffset(94, 34)
    button.BackgroundColor3 = owned and (state.selected == name and GREEN or Color3.fromRGB(61, 65, 80)) or GOLD
    button.Text = owned and (state.selected == name and "EQUIPPED" or "EQUIP") or (info.price == 0 and "FREE" or tostring(info.price) .. " COINS")
    button.TextColor3 = owned and (state.selected == name and Color3.fromRGB(20, 43, 29) or TEXT) or Color3.fromRGB(37, 27, 8)
    button.Font = Enum.Font.GothamBold
    button.TextSize = 9
    button.Parent = item
    corner(button, 9)
    button.Activated:Connect(function()
        if owned and state.selected == name then
            showStatus(name .. " is already equipped.", true)
            return
        end
        local verb = owned and "Equip" or "Buy"
        button.Text = "WAIT..."
        local ok, result = pcall(function()
            return action:InvokeServer(verb, name)
        end)
        if not ok or type(result) ~= "table" then
            showStatus("Couldn't contact the server. Try again.", false)
            render()
            return
        end
        showStatus(result.message or "Done.", result.ok == true)
        if result.ok and result.state then state = result.state end
        render()
    end)
end

function render()
    if not state then return end
    clearContent()
    coins.Text = "◈ " .. tostring(state.coins) .. " COINS"
    for _, child in ipairs(tabs:GetChildren()) do
        if child:IsA("TextButton") then
            child.BackgroundColor3 = child.Name == currentTab .. "Tab" and Color3.fromRGB(78, 62, 31) or CARD
            child.TextColor3 = child.Name == currentTab .. "Tab" and GOLD_LIGHT or TEXT
        end
    end
    for name, info in pairs(state.catalog) do
        local owned = state.owned[name] == true
        if (currentTab == "Shop") or ((currentTab == "Inventory" or currentTab == "Loadout") and owned) then
            makeItemCard(name, info, owned)
        end
    end
    local itemCount = 0
    for _, child in ipairs(content:GetChildren()) do
        if child:IsA("Frame") then itemCount += 1 end
    end
    if itemCount == 0 then
        label(content, "Empty", currentTab == "Shop" and "The shop is empty." or "No items yet.", UDim2.new(1, 0, 0, 40), UDim2.new(), Enum.Font.Gotham, MUTED, 12)
    end
end

makeTab("Inventory", 0, 1/3)
makeTab("Shop", 1/3, 1/3)
makeTab("Loadout", 2/3, 1/3)

open.Activated:Connect(function()
    panel.Visible = not panel.Visible
    if panel.Visible and not state then
        local ok, result = pcall(function() return getState:InvokeServer() end)
        if ok and type(result) == "table" then
            state = result
            render()
            showStatus("Welcome! Your starter collection is ready.", true)
        else
            showStatus("Couldn't load inventory. Check Output.", false)
        end
    end
end)
close.Activated:Connect(function() panel.Visible = false end)

-- Load the server state on startup so the hub is ready when opened.
task.spawn(function()
    local ok, result = pcall(function()
        return getState:InvokeServer()
    end)
    if ok and type(result) == "table" then
        state = result
        render()
        showStatus("Welcome! Your starter collection is ready.", true)
    else
        showStatus("Inventory is still loading. Open the hub again in a moment.", false)
    end
end)

player:GetAttributeChangedSignal("Coins"):Connect(function()
    if state then
        state.coins = player:GetAttribute("Coins") or state.coins
        coins.Text = "◈ " .. tostring(state.coins) .. " COINS"
    end
end)
