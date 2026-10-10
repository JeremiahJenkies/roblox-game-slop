--!strict
-- All RemoteEvents are created here on the server. Clients only retrieve existing remotes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = {}
local FOLDER_NAME = "SoccerRemotes"
local EVENT_NAMES = {
    "StateUpdate",
    "Notice",
    "KickBall",
    "ActionRequest",
    "ProfileUpdate",
}

function Remotes.InitServer()
    local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
    if folder and not folder:IsA("Folder") then
        folder:Destroy()
        folder = nil
    end
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = FOLDER_NAME
        folder.Parent = ReplicatedStorage
    end
    for _, name in ipairs(EVENT_NAMES) do
        local remote = folder:FindFirstChild(name)
        if remote and not remote:IsA("RemoteEvent") then
            remote:Destroy()
            remote = nil
        end
        if not remote then
            remote = Instance.new("RemoteEvent")
            remote.Name = name
            remote.Parent = folder
        end
    end
    return folder
end

function Remotes.GetClient()
    local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
    local result = {}
    for _, name in ipairs(EVENT_NAMES) do
        result[name] = folder:WaitForChild(name)
    end
    return result
end

return Remotes