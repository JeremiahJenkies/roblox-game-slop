--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local BallConfig = require(Shared:WaitForChild("Config"):WaitForChild("BallConfig"))
local PitchConfig = require(Shared:WaitForChild("Config"):WaitForChild("PitchConfig"))
local MatchService = require(script.Parent:WaitForChild("MatchService"))
local Maid = require(Shared:WaitForChild("Util"):WaitForChild("Maid"))

local BallService = {}
local ball: Part? = nil
local stadium: Folder? = nil
local previousPosition = Vector3.zero
local lastMovedAt = os.clock()
local lastKickAt: {[Player]: number} = {}
local lastDribbleAt: {[Player]: number} = {}
local goalLocked = false
local maid = Maid.new()
local kickRemote: RemoteEvent? = nil
local noticeRemote: RemoteEvent? = nil
local radius = BallConfig.Radius

local function finiteNumber(value: number): boolean
    return value == value and value ~= math.huge and value ~= -math.huge
end

local function validVector(value: any): boolean
    if typeof(value) ~= "Vector3" then return false end
    return finiteNumber(value.X) and finiteNumber(value.Y) and finiteNumber(value.Z)
end

local function notifyPlayer(player: Player, message: string)
    if noticeRemote then noticeRemote:FireClient(player, message) end
end

local function notifyAll(message: string)
    if noticeRemote then noticeRemote:FireAllClients(message) end
end

local function getPitchTop(): number
    return PitchConfig.SurfaceCenterY + PitchConfig.SurfaceThickness / 2
end

local function attachPanel(parent: Folder, targetBall: Part, index: number, normal: Vector3)
    local surfacePosition = targetBall.Position + normal.Unit * (radius - 0.015)
    local reference = math.abs(normal.Unit:Dot(Vector3.yAxis)) > 0.92 and Vector3.xAxis or Vector3.yAxis
    local right = reference:Cross(normal.Unit).Unit
    local back = right:Cross(normal.Unit).Unit
    local panel = Instance.new("Part")
    panel.Name = "BallPanel" .. tostring(index)
    panel.Shape = Enum.PartType.Cylinder
    panel.Size = Vector3.new(0.32, 0.045, 0.32)
    panel.CFrame = CFrame.fromMatrix(surfacePosition, right, normal.Unit, back)
    panel.Color = Color3.fromRGB(20, 25, 28)
    panel.Material = Enum.Material.SmoothPlastic
    panel.Anchored = false
    panel.CanCollide = false
    panel.CanTouch = false
    panel.CanQuery = false
    panel.Massless = true
    panel.CastShadow = false
    panel.Parent = parent
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = targetBall
    weld.Part1 = panel
    weld.Parent = panel
end

local function addBallPanels(targetBall: Part)
    if not stadium then return end
    -- A compact black-panel pattern so the sphere reads as a football without a third-party texture.
    local normals = {
        Vector3.new(0, 1, 0), Vector3.new(0, -1, 0),
        Vector3.new(0.85, 0.35, 0.39), Vector3.new(-0.85, 0.35, 0.39),
        Vector3.new(0.85, -0.35, 0.39), Vector3.new(-0.85, -0.35, 0.39),
        Vector3.new(0.39, 0.35, -0.85), Vector3.new(-0.39, 0.35, -0.85),
        Vector3.new(0.39, -0.35, -0.85), Vector3.new(-0.39, -0.35, -0.85),
        Vector3.new(0.0, 0.84, -0.54), Vector3.new(0.0, -0.84, 0.54),
    }
    for index, normal in ipairs(normals) do attachPanel(stadium, targetBall, index, normal) end
end

local function getKickoffPosition(): Vector3
    return Vector3.new(0, getPitchTop() + radius + 0.025, 0)
end

function BallService.ResetBall()
    local currentBall = ball
    if not currentBall or not currentBall.Parent then return end
    currentBall.AssemblyLinearVelocity = Vector3.zero
    currentBall.AssemblyAngularVelocity = Vector3.zero
    currentBall.CFrame = CFrame.new(getKickoffPosition())
    currentBall:SetAttribute("LastTouchedByUserId", 0)
    currentBall:SetAttribute("PreviousTouchedByUserId", 0)
    currentBall:SetAttribute("LastTouchedTeam", "")
    currentBall:SetAttribute("PreviousTouchedTeam", "")
    previousPosition = currentBall.Position
    lastMovedAt = os.clock()
    pcall(function() currentBall:SetNetworkOwner(nil) end)
end

function BallService.GetBall(): Part?
    return ball
end

local function createBall()
    if not stadium or not stadium.Parent then error("SoccerStadium must exist before BallService starts") end
    local existing = stadium:FindFirstChild("MatchBall")
    if existing then existing:Destroy() end
    local newBall = Instance.new("Part")
    newBall.Name = "MatchBall"
    newBall.Shape = Enum.PartType.Ball
    newBall.Size = Vector3.new(radius * 2, radius * 2, radius * 2)
    newBall.CFrame = CFrame.new(getKickoffPosition())
    newBall.Color = Color3.fromRGB(247, 247, 239)
    newBall.Material = Enum.Material.SmoothPlastic
    newBall.CustomPhysicalProperties = PhysicalProperties.new(BallConfig.Density, BallConfig.Friction, BallConfig.Elasticity, 1, 1)
    newBall.Anchored = false
    newBall.CanCollide = true
    newBall.CanTouch = false
    newBall.CanQuery = true
    newBall.CastShadow = true
    newBall:SetAttribute("IsSoccerBall", true)
    newBall:SetAttribute("LastTouchedByUserId", 0)
    newBall:SetAttribute("PreviousTouchedByUserId", 0)
    newBall:SetAttribute("LastTouchedTeam", "")
    newBall:SetAttribute("PreviousTouchedTeam", "")
    newBall.Parent = stadium
    ball = newBall
    addBallPanels(newBall)
    pcall(function() newBall:SetNetworkOwner(nil) end)
    previousPosition = newBall.Position
    lastMovedAt = os.clock()
    Workspace:SetAttribute("BallReady", true)
    print("[BallService] Server-owned football created at kickoff.")
end

local function recordTouch(player: Player)
    local currentBall = ball
    if not currentBall then return end
    local lastId = currentBall:GetAttribute("LastTouchedByUserId")
    local lastTeam = currentBall:GetAttribute("LastTouchedTeam")
    currentBall:SetAttribute("PreviousTouchedByUserId", typeof(lastId) == "number" and lastId or 0)
    currentBall:SetAttribute("PreviousTouchedTeam", typeof(lastTeam) == "string" and lastTeam or "")
    currentBall:SetAttribute("LastTouchedByUserId", player.UserId)
    currentBall:SetAttribute("LastTouchedTeam", player:GetAttribute("Team") or (player.Team and player.Team.Name) or "")
end

local function doKick(player: Player, action: any, direction: any, powerValue: any)
    local currentBall = ball
    if not currentBall or not currentBall.Parent then notifyPlayer(player, "The ball is respawning."); return end
    if action ~= "Pass" and action ~= "Shoot" and action ~= "Lob" and action ~= "Clearance" then return end
    if not validVector(direction) or direction.Magnitude < 0.05 or direction.Magnitude > 1.01 then
        notifyPlayer(player, "Invalid kick direction.")
        return
    end
    local power = typeof(powerValue) == "number" and finiteNumber(powerValue) and powerValue or 0.7
    if power < 0 or power > 1 then return end
    local state = MatchService.GetState()
    if state.phase ~= "PRACTICE" and state.phase ~= "PLAYING" then notifyPlayer(player, "Kicking is unavailable during this phase."); return end
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root or not root:IsA("BasePart") then return end
    if (root.Position - currentBall.Position).Magnitude > BallConfig.KickRange then
        notifyPlayer(player, "Move closer to the ball first.")
        return
    end
    local now = os.clock()
    if now - (lastKickAt[player] or 0) < BallConfig.KickCooldown then return end
    lastKickAt[player] = now

    local basePower = BallConfig.ShotPower
    if action == "Pass" then basePower = BallConfig.PassPower end
    if action == "Lob" then basePower = BallConfig.LobPower end
    if action == "Clearance" then basePower = BallConfig.ClearancePower end
    local requested = direction.Unit
    local y = 0
    if action == "Shoot" then y = math.clamp(requested.Y, 0, 0.35) end
    if action == "Lob" then y = math.max(0.45, math.clamp(requested.Y, 0, 0.75)) end
    if action == "Clearance" then y = math.max(0.18, math.clamp(requested.Y, 0, 0.55)) end
    local horizontal = Vector3.new(requested.X, 0, requested.Z)
    if horizontal.Magnitude < 0.05 then
        local look = root.CFrame.LookVector
        horizontal = Vector3.new(look.X, 0, look.Z)
    end
    if horizontal.Magnitude < 0.05 then return end
    local finalDirection = (horizontal.Unit + Vector3.new(0, y, 0)).Unit
    recordTouch(player)
    currentBall:ApplyImpulse(finalDirection * basePower * power * currentBall.AssemblyMass)
    currentBall.AssemblyAngularVelocity += Vector3.new(-finalDirection.Z, 0, finalDirection.X) * (basePower * power * 0.16)
    lastMovedAt = now
end

local function pointAtGoalPlane(previous: Vector3, current: Vector3, lineZ: number, scoringTeam: string, towardNorth: boolean): boolean
    local targetZ = lineZ + (towardNorth and -radius or radius)
    local crossed = towardNorth and previous.Z > targetZ and current.Z <= targetZ
        or (not towardNorth and previous.Z < targetZ and current.Z >= targetZ)
    if not crossed then return false end
    local deltaZ = current.Z - previous.Z
    if math.abs(deltaZ) < 0.0001 then return false end
    local alpha = math.clamp((targetZ - previous.Z) / deltaZ, 0, 1)
    local crossing = previous:Lerp(current, alpha)
    local halfOpening = PitchConfig.GoalWidth / 2 - radius
    local top = getPitchTop() + PitchConfig.GoalHeight - radius
    local bottom = getPitchTop() + radius
    if math.abs(crossing.X) > halfOpening or crossing.Y < bottom or crossing.Y > top then return false end
    if goalLocked then return true end
    goalLocked = true
    local currentBall = ball
    local scorerId = currentBall and currentBall:GetAttribute("LastTouchedByUserId") or 0
    local assistId = currentBall and currentBall:GetAttribute("PreviousTouchedByUserId") or 0
    local accepted = MatchService.RegisterGoal(scoringTeam, scorerId, assistId)
    if accepted then
        notifyAll("GOAL! " .. scoringTeam .. " scores!")
        task.delay(5, function()
            BallService.ResetBall()
            goalLocked = false
        end)
    else
        goalLocked = false
    end
    return true
end

local function checkForGoal(previous: Vector3, current: Vector3): boolean
    local halfLength = PitchConfig.Length / 2
    -- Red defends the north end; Blue defends the south end.
    if pointAtGoalPlane(previous, current, -halfLength, "Blue", true) then return true end
    if pointAtGoalPlane(previous, current, halfLength, "Red", false) then return true end
    return false
end

local function resolveFastTravel(previous: Vector3, current: Vector3)
    local currentBall = ball
    if not currentBall then return end
    local displacement = current - previous
    if displacement.Magnitude < 0.2 then return end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local excluded: {Instance} = {currentBall}
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character then table.insert(excluded, player.Character) end
    end
    params.FilterDescendantsInstances = excluded
    params.IgnoreWater = true
    local ok, result = pcall(function()
        return Workspace:Spherecast(previous, radius * 0.65, displacement, params)
    end)
    if not ok or not result then return end
    -- Goal geometry is intentionally collidable. Let physics resolve contact, but prevent high-speed tunnel-through.
    if result.Instance and result.Instance:IsDescendantOf(stadium :: Folder) and result.Instance.CanCollide then
        local incoming = currentBall.AssemblyLinearVelocity
        currentBall.Position = result.Position + result.Normal * (radius * 0.68)
        local normalSpeed = incoming:Dot(result.Normal)
        if normalSpeed < 0 then
            currentBall.AssemblyLinearVelocity = incoming - result.Normal * (1.65 * normalSpeed)
        end
    end
end

local function resetIfInvalidOrOutOfBounds(position: Vector3): boolean
    local halfWidth, halfLength = PitchConfig.Width / 2, PitchConfig.Length / 2
    local beyondSide = math.abs(position.X) > halfWidth + radius
    local beyondEnd = math.abs(position.Z) > halfLength + PitchConfig.GoalDepth + radius + 2
    local belowMap = position.Y < -8
    if beyondSide or beyondEnd or belowMap then
        BallService.ResetBall()
        return true
    end
    return false
end

function BallService.Init()
    local folder = ReplicatedStorage:WaitForChild("SoccerRemotes")
    kickRemote = folder:WaitForChild("KickBall") :: RemoteEvent
    noticeRemote = folder:WaitForChild("Notice") :: RemoteEvent
    stadium = Workspace:WaitForChild("SoccerStadium", 10) :: Folder?
    if not stadium then error("PitchService must create SoccerStadium before BallService.Init") end
    createBall()
    kickRemote.OnServerEvent:Connect(doKick)
    maid:GiveTask(Players.PlayerRemoving:Connect(function(player)
        lastKickAt[player] = nil
        lastDribbleAt[player] = nil
    end))
    maid:GiveTask(RunService.Heartbeat:Connect(function()
        local currentBall = ball
        local currentStadium = stadium
        if not currentBall or not currentBall.Parent or not currentStadium or not currentStadium.Parent then return end
        local currentPosition = currentBall.Position
        local velocity = currentBall.AssemblyLinearVelocity
        if velocity.Magnitude > BallConfig.MaxSpeed then
            currentBall.AssemblyLinearVelocity = velocity.Unit * BallConfig.MaxSpeed
            velocity = currentBall.AssemblyLinearVelocity
        elseif velocity.Magnitude < BallConfig.RestSpeed and velocity.Magnitude > 0 then
            currentBall.AssemblyLinearVelocity = Vector3.zero
            currentBall.AssemblyAngularVelocity = Vector3.zero
        end
        if checkForGoal(previousPosition, currentPosition) then
            previousPosition = currentBall.Position
            return
        end
        resolveFastTravel(previousPosition, currentPosition)
        currentPosition = currentBall.Position
        if resetIfInvalidOrOutOfBounds(currentPosition) then
            previousPosition = currentBall.Position
            return
        end
        if (currentPosition - previousPosition).Magnitude >= 0.12 then lastMovedAt = os.clock() end
        if os.clock() - lastMovedAt >= BallConfig.StuckBallSeconds then BallService.ResetBall() end
        previousPosition = currentBall.Position
    end))
    print("[BallService] Validated kicks, server physics, speed cap, anti-tunnelling and goal-plane checks are active.")
end

return BallService