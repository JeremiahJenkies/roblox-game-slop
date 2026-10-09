-- Starter items, persistent inventory, shop and basic gameplay rewards.
-- Enable Studio Access to API Services in Game Settings > Security to test DataStores.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local store = DataStoreService:GetDataStore("SlopStarterData_v1")
local function getOrCreate(className, name)
    local obj = ReplicatedStorage:FindFirstChild(name)
    if not obj then
        obj = Instance.new(className)
        obj.Name = name
        obj.Parent = ReplicatedStorage
    end
    return obj
end

local action = getOrCreate("RemoteFunction", "StarterHubAction")
local getState = getOrCreate("RemoteFunction", "GetStarterHubState")

local CATALOG = {
    ["Golden Smiley"] = {price = 0, description = "Your shiny golden starter.", color = Color3.fromRGB(255, 190, 25)},
    ["Silver Star"] = {price = 100, description = "A cool silver collectible.", color = Color3.fromRGB(190, 205, 225)},
}
local sessions = {}

local function safeSave(player)
    local data = sessions[player]
    if not data then return end
    local payload = {coins = data.coins, owned = data.owned, selected = data.selected}
    local ok, err = pcall(function()
        store:SetAsync("player_" .. player.UserId, payload)
    end)
    if not ok then warn("Starter data save failed for " .. player.Name .. ": " .. tostring(err)) end
end

local function equipItem(player)
    local data = sessions[player]
    if not data then return end
    local backpack = player:FindFirstChildOfClass("Backpack")
    if not backpack then return end
    for _, container in ipairs({backpack, player.Character}) do
        if container then
            local old = container:FindFirstChild("StarterCollectible")
            if old then old:Destroy() end
        end
    end
    if data.selected == "" or not data.owned[data.selected] then return end
    local itemInfo = CATALOG[data.selected]
    if not itemInfo then return end

    local tool = Instance.new("Tool")
    tool.Name = "StarterCollectible"
    tool.ToolTip = data.selected
    tool.RequiresHandle = true
    tool.CanBeDropped = false

    local handle = Instance.new("Part")
    handle.Name = "Handle"
    handle.Shape = Enum.PartType.Ball
    handle.Size = Vector3.new(1.25, 1.25, 0.35)
    handle.Color = itemInfo.color
    handle.Material = Enum.Material.Metal
    handle.Reflectance = 0.12
    handle.CanCollide = false
    handle.Massless = true
    handle.Parent = tool

    if data.selected == "Golden Smiley" then
        local billboard = Instance.new("BillboardGui")
        billboard.Name = "SmileyFace"
        billboard.Size = UDim2.fromOffset(100, 100)
        billboard.AlwaysOnTop = false
        billboard.Parent = handle
        local label = Instance.new("TextLabel")
        label.BackgroundTransparency = 1
        label.Size = UDim2.fromScale(1, 1)
        label.Text = "☺"
        label.TextColor3 = Color3.fromRGB(65, 35, 12)
        label.TextScaled = true
        label.Font = Enum.Font.GothamBold
        label.Parent = billboard
    else
        local sparkle = Instance.new("BillboardGui")
        sparkle.Size = UDim2.fromOffset(90, 90)
        sparkle.Parent = handle
        local label = Instance.new("TextLabel")
        label.BackgroundTransparency = 1
        label.Size = UDim2.fromScale(1, 1)
        label.Text = "★"
        label.TextColor3 = Color3.fromRGB(60, 70, 90)
        label.TextScaled = true
        label.Font = Enum.Font.GothamBold
        label.Parent = sparkle
    end
    tool.Parent = backpack
end

local function publicState(player)
    local data = sessions[player]
    if not data then return nil end
    return {coins = data.coins, owned = data.owned, selected = data.selected, catalog = CATALOG}
end

local function loadPlayer(player)
    local data = {coins = 0, owned = {["Golden Smiley"] = true}, selected = "Golden Smiley"}
    local ok, saved = pcall(function()
        return store:GetAsync("player_" .. player.UserId)
    end)
    if ok and type(saved) == "table" then
        data.coins = math.max(0, tonumber(saved.coins) or 0)
        if type(saved.owned) == "table" then
            for name, owned in pairs(saved.owned) do
                if CATALOG[name] and owned == true then data.owned[name] = true end
            end
        end
        if type(saved.selected) == "string" and data.owned[saved.selected] and CATALOG[saved.selected] then
            data.selected = saved.selected
        end
    elseif not ok then
        warn("Starter data load failed for " .. player.Name .. ": " .. tostring(saved))
    end
    sessions[player] = data
    player:SetAttribute("Coins", data.coins)
    player:SetAttribute("SelectedStarterItem", data.selected)
    player.CharacterAdded:Connect(function()
        task.wait(0.5)
        equipItem(player)
    end)
    task.defer(function() equipItem(player) end)
end

Players.PlayerAdded:Connect(loadPlayer)
Players.PlayerRemoving:Connect(function(player)
    safeSave(player)
    sessions[player] = nil
end)
for _, player in ipairs(Players:GetPlayers()) do task.spawn(loadPlayer, player) end

getState.OnServerInvoke = function(player)
    while not sessions[player] and player.Parent do task.wait() end
    return publicState(player)
end

action.OnServerInvoke = function(player, verb, itemName)
    local data = sessions[player]
    if not data then return {ok = false, message = "Your data is still loading."} end
    if type(itemName) ~= "string" or not CATALOG[itemName] then
        return {ok = false, message = "That item is not available."}
    end
    local item = CATALOG[itemName]
    if verb == "Buy" then
        if data.owned[itemName] then return {ok = false, message = "You already own this item."} end
        if data.coins < item.price then return {ok = false, message = "You need more coins."} end
        data.coins -= item.price
        data.owned[itemName] = true
    elseif verb == "Equip" then
        if not data.owned[itemName] then return {ok = false, message = "Unlock this item first."} end
        data.selected = itemName
    else
        return {ok = false, message = "Unknown action."}
    end
    player:SetAttribute("Coins", data.coins)
    player:SetAttribute("SelectedStarterItem", data.selected)
    equipItem(player)
    safeSave(player)
    return {ok = true, message = verb == "Buy" and "Item unlocked!" or "Item equipped!", state = publicState(player)}
end

-- Basic gameplay loop: reward active players with coins every 60 seconds.
task.spawn(function()
    while true do
        task.wait(60)
        for _, player in ipairs(Players:GetPlayers()) do
            local data = sessions[player]
            if data and player.Character and player.Character:FindFirstChildOfClass("Humanoid") then
                data.coins += 10
                player:SetAttribute("Coins", data.coins)
                safeSave(player)
            end
        end
    end
end)

game:BindToClose(function()
    for _, player in ipairs(Players:GetPlayers()) do task.spawn(safeSave, player) end
    task.wait(2)
end)
