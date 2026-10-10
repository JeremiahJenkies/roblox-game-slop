--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ProductsConfig = require(Shared:WaitForChild("Config"):WaitForChild("ProductsConfig"))
local events = require(Shared:WaitForChild("Remotes")).GetClient()
local actionRemote: RemoteEvent = events.ActionRequest
local profile: {[string]: any} = {}
local isOpen = false

local function round(instance: Instance, radius: number)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius)
    corner.Parent = instance
end

local gui = Instance.new("ScreenGui")
gui.Name = "PITCHCosmeticShop"
gui.ResetOnSpawn = false
gui.DisplayOrder = 25
gui.Parent = playerGui

local openButton = Instance.new("TextButton")
openButton.Name = "OpenShop"
openButton.AnchorPoint = Vector2.new(1, 0)
openButton.Position = UDim2.new(1, -18, 0, 150)
openButton.Size = UDim2.fromOffset(132, 44)
openButton.BackgroundColor3 = Color3.fromRGB(24, 44, 57)
openButton.Text = "KIT SHOP"
openButton.TextColor3 = Color3.new(1, 1, 1)
openButton.Font = Enum.Font.GothamBlack
openButton.TextSize = 14
openButton.Parent = gui
round(openButton, 12)

local panel = Instance.new("Frame")
panel.Name = "ShopPanel"
panel.AnchorPoint = Vector2.new(1, 0.5)
panel.Position = UDim2.new(1, -18, 0.5, 0)
panel.Size = UDim2.new(0, 330, 0.72, 0)
panel.BackgroundColor3 = Color3.fromRGB(12, 22, 31)
panel.Visible = false
panel.Parent = gui
round(panel, 16)

local heading = Instance.new("TextLabel")
heading.BackgroundTransparency = 1
heading.Position = UDim2.fromOffset(14, 8)
heading.Size = UDim2.new(1, -60, 0, 34)
heading.Text = "COSMETIC LOCKER"
heading.TextColor3 = Color3.new(1, 1, 1)
heading.Font = Enum.Font.GothamBlack
heading.TextSize = 17
heading.TextXAlignment = Enum.TextXAlignment.Left
heading.Parent = panel

local closeButton = Instance.new("TextButton")
closeButton.Position = UDim2.new(1, -44, 0, 8)
closeButton.Size = UDim2.fromOffset(32, 32)
closeButton.Text = "X"
closeButton.Font = Enum.Font.GothamBlack
closeButton.TextColor3 = Color3.new(1, 1, 1)
closeButton.BackgroundColor3 = Color3.fromRGB(55, 68, 79)
closeButton.Parent = panel
round(closeButton, 9)

local credits = Instance.new("TextLabel")
credits.Name = "Credits"
credits.BackgroundTransparency = 1
credits.Position = UDim2.fromOffset(14, 42)
credits.Size = UDim2.new(1, -28, 0, 22)
credits.Text = "CREDITS: 0"
credits.TextColor3 = Color3.fromRGB(255, 205, 120)
credits.Font = Enum.Font.GothamBold
credits.TextSize = 12
credits.TextXAlignment = Enum.TextXAlignment.Left
credits.Parent = panel

local list = Instance.new("ScrollingFrame")
list.Name = "Items"
list.Position = UDim2.fromOffset(10, 70)
list.Size = UDim2.new(1, -20, 1, -82)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 5
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.CanvasSize = UDim2.new()
list.Parent = panel
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 7)
layout.SortOrder = Enum.SortOrder.Name
layout.Parent = list
local padding = Instance.new("UIPadding")
padding.PaddingBottom = UDim.new(0, 8)
padding.Parent = list

local itemButtons: {[string]: TextButton} = {}
local itemKeys = {}
for key in pairs(ProductsConfig.Items) do table.insert(itemKeys, key) end
table.sort(itemKeys)
for _, key in ipairs(itemKeys) do
    local item = ProductsConfig.Items[key]
    local row = Instance.new("Frame")
    row.Name = key
    row.Size = UDim2.new(1, -8, 0, 62)
    row.BackgroundColor3 = Color3.fromRGB(26, 39, 50)
    row.Parent = list
    round(row, 10)
    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Position = UDim2.fromOffset(10, 5)
    title.Size = UDim2.new(1, -118, 0, 25)
    title.Text = tostring(item.DisplayName)
    title.TextColor3 = Color3.new(1, 1, 1)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 12
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = row
    local price = Instance.new("TextLabel")
    price.BackgroundTransparency = 1
    price.Position = UDim2.fromOffset(10, 30)
    price.Size = UDim2.new(1, -118, 0, 20)
    price.Text = tostring(item.Price) .. " credits"
    price.TextColor3 = Color3.fromRGB(166, 187, 200)
    price.Font = Enum.Font.Gotham
    price.TextSize = 11
    price.TextXAlignment = Enum.TextXAlignment.Left
    price.Parent = row
    local button = Instance.new("TextButton")
    button.Name = "Action"
    button.AnchorPoint = Vector2.new(1, 0.5)
    button.Position = UDim2.new(1, -8, 0.5, 0)
    button.Size = UDim2.fromOffset(96, 38)
    button.BackgroundColor3 = Color3.fromRGB(41, 127, 86)
    button.Text = "EQUIP"
    button.TextColor3 = Color3.new(1, 1, 1)
    button.Font = Enum.Font.GothamBlack
    button.TextSize = 11
    button.Parent = row
    round(button, 8)
    itemButtons[key] = button
    button.Activated:Connect(function()
        local owned = type(profile.Owned) == "table" and profile.Owned[key] == true
        local free = (tonumber(item.Price) or 0) == 0
        actionRemote:FireServer((owned or free) and "EquipCosmetic" or "BuyCosmetic", key)
    end)
end

local function refresh()
    credits.Text = "CREDITS: " .. tostring(profile.Coins or 0)
    for key, button in pairs(itemButtons) do
        local item = ProductsConfig.Items[key]
        local owned = type(profile.Owned) == "table" and profile.Owned[key] == true
        local free = (tonumber(item.Price) or 0) == 0
        local field = ProductsConfig.AllowedEquipFields[item.Type]
        local equipped = field and profile[field] == key
        if equipped then
            button.Text = "EQUIPPED"
            button.BackgroundColor3 = Color3.fromRGB(48, 77, 91)
        elseif owned or free then
            button.Text = "EQUIP"
            button.BackgroundColor3 = Color3.fromRGB(41, 127, 86)
        else
            button.Text = "BUY"
            button.BackgroundColor3 = (tonumber(profile.Coins) or 0) >= (tonumber(item.Price) or 0) and Color3.fromRGB(41, 100, 156) or Color3.fromRGB(75, 81, 88)
        end
    end
end

events.ProfileUpdate.OnClientEvent:Connect(function(nextProfile: any)
    if type(nextProfile) ~= "table" then return end
    profile = nextProfile
    refresh()
end)
openButton.Activated:Connect(function()
    isOpen = not isOpen
    panel.Visible = isOpen
    openButton.Text = isOpen and "CLOSE SHOP" or "KIT SHOP"
    refresh()
end)
closeButton.Activated:Connect(function()
    isOpen = false
    panel.Visible = false
    openButton.Text = "KIT SHOP"
end)
events.ProfileRequest:FireServer("RequestProfile")
refresh()
print("[PITCH] Cosmetic locker ready.");
