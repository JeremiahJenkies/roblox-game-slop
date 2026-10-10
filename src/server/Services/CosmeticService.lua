--!strict
-- Server-authoritative, earnable cosmetics. This service intentionally sells no gameplay power.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local ProductsConfig = require(Shared:WaitForChild("Config"):WaitForChild("ProductsConfig"))
local DataService = require(script.Parent:WaitForChild("DataService"))

local CosmeticService = {}
local lastAction: {[Player]: number} = {}

local function publishProfile(player: Player, profile: {[string]: any})
    local events = ReplicatedStorage:FindFirstChild("SoccerRemotes")
    local remote = events and events:FindFirstChild("ProfileUpdate")
    if remote and remote:IsA("RemoteEvent") then
        local snapshot = table.clone(profile)
        snapshot.Owned = table.clone(profile.Owned or {})
        remote:FireClient(player, snapshot)
    end
end

local function notify(player: Player, message: string)
    local events = ReplicatedStorage:FindFirstChild("SoccerRemotes")
    local remote = events and events:FindFirstChild("Notice")
    if remote and remote:IsA("RemoteEvent") then remote:FireClient(player, message) end
end

local function process(player: Player, action: any, itemKey: any)
    if action ~= "BuyCosmetic" and action ~= "EquipCosmetic" then return end
    if typeof(itemKey) ~= "string" or #itemKey > 40 then return end
    local now = os.clock()
    if now - (lastAction[player] or 0) < 0.2 then return end
    lastAction[player] = now
    local item = ProductsConfig.Items[itemKey]
    if type(item) ~= "table" then notify(player, "That cosmetic is unavailable."); return end
    local profile = DataService.GetProfile(player)
    if not profile then notify(player, "Your profile is still loading."); return end
    profile.Owned = type(profile.Owned) == "table" and profile.Owned or {}
    local isOwned = profile.Owned[itemKey] == true or (tonumber(item.Price) or 0) == 0

    if action == "BuyCosmetic" then
        if isOwned then notify(player, "You already own " .. tostring(item.DisplayName) .. "."); return end
        local price = math.max(0, math.floor(tonumber(item.Price) or 0))
        local coins = math.max(0, math.floor(tonumber(profile.Coins) or 0))
        if coins < price then notify(player, "You need " .. tostring(price - coins) .. " more credits."); return end
        profile.Coins = coins - price
        profile.Owned[itemKey] = true
        notify(player, "Purchased " .. tostring(item.DisplayName) .. ".")
    else
        if not isOwned then notify(player, "Buy that cosmetic before equipping it."); return end
        local field = ProductsConfig.AllowedEquipFields[item.Type]
        if type(field) ~= "string" then return end
        profile[field] = itemKey
        profile.Owned[itemKey] = true
        notify(player, "Equipped " .. tostring(item.DisplayName) .. ".")
    end
    publishProfile(player, profile)
end

function CosmeticService.Init()
    local events = Remotes.InitServer()
    local actionRemote = events:WaitForChild("ActionRequest") :: RemoteEvent
    actionRemote.OnServerEvent:Connect(process)
    Players.PlayerRemoving:Connect(function(player) lastAction[player] = nil end)
    print("[CosmeticService] Server-validated cosmetic purchases and equipment are active.")
end

return CosmeticService
