--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then return end

local servicesFolder = script.Parent:WaitForChild("Services")
local Maid = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Maid"))
local playerMaids: {[Player]: any} = {}
local DataService = require(servicesFolder:WaitForChild("DataService"))
local PitchService = require(servicesFolder:WaitForChild("PitchService"))
local BallService = require(servicesFolder:WaitForChild("BallService"))
local BallConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("BallConfig"))
local PitchConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("PitchConfig"))
local DribbleService = require(servicesFolder:WaitForChild("DribbleService"))

local function attach(player: Player)
    if playerMaids[player] then playerMaids[player]:Destroy() end
    local maid = Maid.new()
    playerMaids[player] = maid
    maid:GiveTask(player.Chatted:Connect(function(message: string)
        local command = string.lower(message)
        if command == "/stats" then
            local profile = DataService.GetProfile(player)
            print("[DevCommands] Profile for " .. player.Name .. ": " .. (profile and game:GetService("HttpService"):JSONEncode(profile) or "<profile loading>"))
        elseif command == "/pitch" then
            local ok, result = pcall(PitchService.Build)
            if ok then print("[DevCommands] Pitch rebuilt by " .. player.Name)
            else warn("[DevCommands] Pitch rebuild failed: " .. tostring(result)) end
        elseif command == "/ballreset" then
            BallService.ResetBall()
            print("[DevCommands] Ball reset requested by " .. player.Name)
        elseif command == "/ballshoot" then
            local ball = BallService.GetBall()
            if ball then
                ball.AssemblyLinearVelocity = Vector3.zero
                ball.AssemblyAngularVelocity = Vector3.zero
                local direction = Vector3.new(0, 0.12, -1).Unit
                ball:ApplyImpulse(direction * BallConfig.ShotPower * ball.AssemblyMass)
                print("[DevCommands] Test shot fired. Ball speed: " .. tostring(math.floor(ball.AssemblyLinearVelocity.Magnitude)))
            else
                warn("[DevCommands] No ball exists yet.")
            end
        elseif command == "/ballout" then
            local ball = BallService.GetBall()
            if ball then
                ball.CFrame = CFrame.new(PitchConfig.Width, PitchConfig.SurfaceCenterY + 3, 0)
                ball.AssemblyLinearVelocity = Vector3.new(30, 0, 0)
                print("[DevCommands] Out-of-bounds test triggered.")
            end
        elseif command == "/dribbledebug" then
            DribbleService.SetDebug(true)
            print("[DevCommands] Dribble debug markers enabled.")
        elseif command == "/dribbledebugoff" then
            DribbleService.SetDebug(false)
            print("[DevCommands] Dribble debug markers disabled.")
        elseif command == "/dribletouch" then
            DribbleService.DebugTouch(player)
            print("[DevCommands] Forced a Studio-only test touch.")
        elseif string.sub(command, 1, 14) == "/dribbleskill " then
            local skill = tonumber(string.sub(command, 15))
            if skill then
                player:SetAttribute("DribbleSkill", math.clamp(skill, 0, 1))
                print("[DevCommands] DribbleSkill set to " .. tostring(player:GetAttribute("DribbleSkill")))
            else
                warn("[DevCommands] Usage: /dribbleskill 0.0 to 1.0")
            end
        elseif command == "/ballinfo" then
            local ball = BallService.GetBall()
            if ball then
                print("[DevCommands] speed=" .. tostring(math.floor(ball.AssemblyLinearVelocity.Magnitude * 100) / 100)
                    .. " spin=" .. tostring(math.floor(ball.AssemblyAngularVelocity.Magnitude * 100) / 100)
                    .. " lastTouch=" .. tostring(ball:GetAttribute("LastTouchedByUserId")))
            end
        end
    end))
end

Players.PlayerAdded:Connect(attach)
Players.PlayerRemoving:Connect(function(player)
    local maid = playerMaids[player]
    if maid then maid:Destroy(); playerMaids[player] = nil end
end)
for _, player in ipairs(Players:GetPlayers()) do attach(player) end
print("[DevCommands] Studio-only /stats, /pitch and dribbling debug commands enabled.")