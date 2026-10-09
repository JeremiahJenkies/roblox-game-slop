-- Server-authoritative starter-item selection.
-- Rojo path: src/server/StarterItemSelection.server.lua

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remote = ReplicatedStorage:FindFirstChild("SelectStarterItem")
if not remote then
    remote = Instance.new("RemoteEvent")
    remote.Name = "SelectStarterItem"
    remote.Parent = ReplicatedStorage
end

local VALID_ITEMS = {
    ["Golden Smiley"] = true,
}

local function setDefault(player)
    if player:GetAttribute("SelectedStarterItem") == nil then
        player:SetAttribute("SelectedStarterItem", "")
    end
end

Players.PlayerAdded:Connect(setDefault)
for _, player in ipairs(Players:GetPlayers()) do
    setDefault(player)
end

remote.OnServerEvent:Connect(function(player, itemName)
    if typeof(itemName) ~= "string" or not VALID_ITEMS[itemName] then
        return
    end

    player:SetAttribute("SelectedStarterItem", itemName)
    remote:FireClient(player, "Selected", itemName)
end)
