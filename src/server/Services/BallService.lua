--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local BallConfig = require(Shared:WaitForChild("Config"):WaitForChild("BallConfig"))
local MatchConfig = require(Shared:WaitForChild("Config"):WaitForChild("MatchConfig"))
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
local scoredThisTrip = false
local maid = Maid.new()
local kickRemote: RemoteEvent? = nil
local actionRemote: RemoteEvent? = nil
local noticeRemote: RemoteEvent? = nil
local lastTackleAt: {[Player]: number} = {}
local radius = BallConfig.Radius
local physicsAccumulator = 0
local slowGroundSince: number? = nil
local physicsRayParams = RaycastParams.new()
physicsRayParams.FilterType = Enum.RaycastFilterType.Exclude
physicsRayParams.IgnoreWater = true

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

local function attachPanel(targetBall: Part, index: number, normal: Vector3)
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
    panel.Parent = targetBall
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = targetBall
    weld.Part1 = panel
    weld.Parent = panel
end

local function addBallPanels(targetBall: Part)
    -- A compact black-panel pattern so the sphere reads as a football without a third-party texture.
    local normals = {
        Vector3.new(0, 1, 0), Vector3.new(0, -1, 0),
        Vector3.new(0.85, 0.35, 0.39), Vector3.new(-0.85, 0.35, 0.39),
        Vector3.new(0.85, -0.35, 0.39), Vector3.new(-0.85, -0.35, 0.39),
        Vector3.new(0.39, 0.35, -0.85), Vector3.new(-0.39, 0.35, -0.85),
        Vector3.new(0.39, -0.35, -0.85), Vector3.new(-0.39, -0.35, -0.85),
        Vector3.new(0.0, 0.84, -0.54), Vector3.new(0.0, -0.84, 0.54),
    }
    for index, normal in ipairs(normals) do attachPanel(targetBall, index, normal) end
end

local function getKickoffPosition(): Vector3
    return Vector3.new(0, getPitchTop() + radius + 0.025, 0)
end

function BallService.ResetBall()
    local currentBall = ball
    if not currentBall or not currentBall.Parent then return end
    releasePossession()
    currentBall.AssemblyLinearVelocity = Vector3.zero
    currentBall.AssemblyAngularVelocity = Vector3.zero
    currentBall.CFrame = CFrame.new(getKickoffPosition())
    scoredThisTrip = false
    currentBall:SetAttribute("LastTouchedByUserId", 0)
    currentBall:SetAttribute("PreviousTouchedByUserId", 0)
    currentBall:SetAttribute("LastTouchedTeam", "")
    currentBall:SetAttribute("PreviousTouchedTeam", "")
    currentBall:SetAttribute("PossessorUserId", 0)
    previousPosition = currentBall.Position
    lastMovedAt = os.clock()
    pcall(function() currentBall:SetNetworkOwner(nil) end)
end

function BallService.GetBall(): Part?
    return ball
end

function BallService.PlaceForRestart(position: Vector3)
    local currentBall = ball
    if not currentBall or not currentBall.Parent then return end
    releasePossession()
    currentBall.AssemblyLinearVelocity = Vector3.zero
    currentBall.AssemblyAngularVelocity = Vector3.zero
    currentBall.CFrame = CFrame.new(position)
    scoredThisTrip = false
    currentBall:SetAttribute("LastTouchedByUserId", 0)
    currentBall:SetAttribute("PreviousTouchedByUserId", 0)
    currentBall:SetAttribute("LastTouchedTeam", "")
    currentBall:SetAttribute("PreviousTouchedTeam", "")
    currentBall:SetAttribute("PossessorUserId", 0)
    previousPosition = currentBall.Position
    lastMovedAt = os.clock()
    pcall(function() currentBall:SetNetworkOwner(nil) end)
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
    physicsRayParams.FilterDescendantsInstances = {newBall}
    addBallPanels(newBall)
    pcall(function() newBall:SetNetworkOwner(nil) end)
    previousPosition = newBall.Position
    lastMovedAt = os.clock()
    Workspace:SetAttribute("BallReady", true)
    print("[BallService] Server-owned football created at kickoff.")
end

local function releasePossession()
    local currentBall = ball
    if not currentBall then return end
    local align = currentBall:FindFirstChild("PITCHPossessionAlign")
    if align then align:Destroy() end
    local ballAttachment = currentBall:FindFirstChild("PITCHPossessionAttachment")
    if ballAttachment then ballAttachment:Destroy() end
    for _, candidate in ipairs(Players:GetPlayers()) do
        local character = candidate.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        local target = root and root:FindFirstChild("PITCHBallTargetAttachment")
        if target then target:Destroy() end
    end
    currentBall:SetAttribute("PossessorUserId", 0)
end

local function attachPossession(player: Player, root: BasePart)
    local currentBall = ball
    if not currentBall or not currentBall.Parent then return end
    releasePossession()
    local ballAttachment = Instance.new("Attachment")
    ballAttachment.Name = "PITCHPossessionAttachment"
    ballAttachment.Parent = currentBall
    local target = Instance.new("Attachment")
    target.Name = "PITCHBallTargetAttachment"
    -- Keep the ball near the feet and ahead of the avatar's facing direction.
    target.Position = Vector3.new(0, -1.25, -BallConfig.DribbleTargetOffset)
    target.Parent = root
    local align = Instance.new("AlignPosition")
    align.Name = "PITCHPossessionAlign"
    align.Mode = Enum.PositionAlignmentMode.TwoAttachment
    align.Attachment0 = ballAttachment
    align.Attachment1 = target
    align.ApplyAtCenterOfMass = true
    align.RigidityEnabled = false
    align.Responsiveness = 35
    align.MaxForce = 50000
    align.MaxVelocity = 55
    align.Parent = currentBall
    currentBall.AssemblyAngularVelocity = Vector3.zero
    currentBall:SetAttribute("PossessorUserId", player.UserId)
    pcall(function() currentBall:SetNetworkOwner(nil) end)
end

local function attemptTackle(player: Player)
    local currentBall = ball
    if not currentBall or not currentBall.Parent then return end
    local state = MatchService.GetState()
    if state.phase ~= "PLAYING" and state.phase ~= "PRACTICE" then return end
    local now = os.clock()
    if now - (lastTackleAt[player] or 0) < 1.25 then return end
    lastTackleAt[player] = now
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then return end

    local possessorId = currentBall:GetAttribute("PossessorUserId")
    local possessor = typeof(possessorId) == "number" and possessorId > 0 and Players:GetPlayerByUserId(possessorId) or nil
    if not possessor or possessor == player then return end
    local opponentCharacter = possessor.Character
    local opponentRoot = opponentCharacter and opponentCharacter:FindFirstChild("HumanoidRootPart")
    local opponentHumanoid = opponentCharacter and opponentCharacter:FindFirstChildOfClass("Humanoid")
    if not opponentRoot or not opponentRoot:IsA("BasePart") or not opponentHumanoid or opponentHumanoid.Health <= 0 then return end
    local offset = opponentRoot.Position - root.Position
    if offset.Magnitude > 7 then return end
    local forward = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
    local toOpponent = Vector3.new(offset.X, 0, offset.Z)
    if forward.Magnitude > 0.05 and toOpponent.Magnitude > 0.05 and forward.Unit:Dot(toOpponent.Unit) < -0.15 then return end

    -- A successful close-range tackle strips possession and gives the tackler control.
    local lastTeam = player:GetAttribute("Team") or (player.Team and player.Team.Name)
    local opponentTeam = possessor:GetAttribute("Team") or (possessor.Team and possessor.Team.Name)
    if lastTeam == opponentTeam then return end
    recordTouch(player)
    attachPossession(player, root)
    currentBall.AssemblyLinearVelocity = Vector3.zero
    currentBall.AssemblyAngularVelocity = Vector3.zero
    notifyAll(player.DisplayName .. " won the tackle!")
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
    releasePossession()
    local desiredSpeed = basePower * power
    currentBall.AssemblyLinearVelocity = finalDirection * math.max(currentBall.AssemblyLinearVelocity.Magnitude * 0.25, 0)
    currentBall:ApplyImpulse(finalDirection * desiredSpeed * currentBall.AssemblyMass)
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
    if goalLocked or scoredThisTrip then return true end
    goalLocked = true
    local currentBall = ball
    local scorerId = currentBall and currentBall:GetAttribute("LastTouchedByUserId") or 0
    local assistId = currentBall and currentBall:GetAttribute("PreviousTouchedByUserId") or 0
    local accepted = MatchService.RegisterGoal(scoringTeam, scorerId, assistId)
    if accepted then
        scoredThisTrip = true
        if currentBall then currentBall:SetAttribute("PossessorUserId", 0) end
        notifyAll("GOAL! " .. scoringTeam .. " scores!")
        task.delay(MatchConfig.GoalResetSeconds, function()
            BallService.ResetBall()
            goalLocked = false
        end)
    else
        -- A crossing during a stoppage is not a goal; leave the ball eligible for the next live play.
        scoredThisTrip = false
        goalLocked = false
    end
    return true
end

local function checkForGoal(previous: Vector3, current: Vector3): boolean
    local halfLength = PitchConfig.Length / 2
    local matchState = MatchService.GetState()
    -- Teams switch ends at half-time: Red attacks south in half one and north in half two.
    local redAttacksNorth = (tonumber(matchState.half) or 1) == 2
    local northScoringTeam = redAttacksNorth and "Red" or "Blue"
    local southScoringTeam = redAttacksNorth and "Blue" or "Red"
    if pointAtGoalPlane(previous, current, -halfLength, northScoringTeam, true) then return true end
    if pointAtGoalPlane(previous, current, halfLength, southScoringTeam, false) then return true end
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
    if not beyondSide and not beyondEnd and not belowMap then return false end

    local state = MatchService.GetState()
    if state.phase ~= "PLAYING" or belowMap then
        BallService.ResetBall()
        return true
    end

    local currentBall = ball
    local lastTeam = currentBall and currentBall:GetAttribute("LastTouchedTeam") or ""
    if lastTeam ~= "Red" and lastTeam ~= "Blue" then lastTeam = "Red" end
    local awardedTeam = lastTeam == "Red" and "Blue" or "Red"
    local pitchTop = getPitchTop()
    local restartType: string
    local spot: Vector3

    if beyondSide then
        restartType = "THROW_IN"
        spot = Vector3.new(math.sign(position.X) * (halfWidth - radius - 0.15), pitchTop + radius + 0.03,
            math.clamp(position.Z, -halfLength + 2, halfLength - 2))
    else
        local northEnd = position.Z < 0
        local defendingTeam = northEnd and "Red" or "Blue"
        local attackingTeam = northEnd and "Blue" or "Red"
        if lastTeam == defendingTeam then
            restartType = "CORNER"
            awardedTeam = attackingTeam
            spot = Vector3.new(math.sign(position.X == 0 and 1 or position.X) * (halfWidth - radius - 0.2),
                pitchTop + radius + 0.03, northEnd and (-halfLength + 1.5) or (halfLength - 1.5))
        else
            restartType = "GOAL_KICK"
            awardedTeam = defendingTeam
            spot = Vector3.new(0, pitchTop + radius + 0.03, northEnd and (-halfLength + PitchConfig.GoalAreaDepth / 2) or (halfLength - PitchConfig.GoalAreaDepth / 2))
        end
    end

    BallService.PlaceForRestart(spot)
    MatchService.BeginRestart(restartType, awardedTeam, spot)
    return true
end

function BallService.Init()
    Workspace:SetAttribute("BallReady", false)
    local folder = ReplicatedStorage:WaitForChild("SoccerRemotes")
    kickRemote = folder:WaitForChild("KickBall") :: RemoteEvent
    actionRemote = folder:WaitForChild("ActionRequest") :: RemoteEvent
    noticeRemote = folder:WaitForChild("Notice") :: RemoteEvent
    stadium = Workspace:WaitForChild("SoccerStadium", 10) :: Folder?
    if not stadium then error("PitchService must create SoccerStadium before BallService.Init") end
    createBall()
    kickRemote.OnServerEvent:Connect(doKick)
    if actionRemote then
        actionRemote.OnServerEvent:Connect(function(player: Player, action: any)
            if action == "Tackle" then attemptTackle(player) end
        end)
    end
    maid:GiveTask(Players.PlayerRemoving:Connect(function(player)
        lastKickAt[player] = nil
        lastDribbleAt[player] = nil
        lastTackleAt[player] = nil
    end))
    maid:GiveTask(RunService.Heartbeat:Connect(function(deltaTime: number)
        local currentBall = ball
        local currentStadium = stadium
        if not currentBall or not currentBall.Parent or not currentStadium or not currentStadium.Parent then return end

        -- Fixed 60 Hz custom-force step so drag and spin decay are independent of server frame rate.
        physicsAccumulator = math.min(physicsAccumulator + math.min(deltaTime, 0.1), 0.2)
        local fixedStep = 1 / 60
        while physicsAccumulator >= fixedStep do
            physicsAccumulator -= fixedStep
            local velocity = currentBall.AssemblyLinearVelocity
            local angular = currentBall.AssemblyAngularVelocity
            if velocity.Magnitude > BallConfig.MaxSpeed then
                velocity = velocity.Unit * BallConfig.MaxSpeed
            end
            if angular.Magnitude > BallConfig.MaxAngularSpeed then
                angular = angular.Unit * BallConfig.MaxAngularSpeed
            end

            local groundHit = Workspace:Raycast(currentBall.Position, Vector3.new(0, -(radius + 0.16), 0), physicsRayParams)
            local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
            if groundHit and velocity.Y <= BallConfig.MinBounceSpeed then
                local resistance = horizontal.Magnitude > 3 and BallConfig.SlidingFriction or BallConfig.GroundRollingResistance
                local reducedSpeed = math.max(0, horizontal.Magnitude - resistance * fixedStep)
                if horizontal.Magnitude > 0.001 then horizontal = horizontal.Unit * reducedSpeed end
                local vertical = math.abs(velocity.Y) < BallConfig.MinBounceSpeed and 0 or velocity.Y * 0.25
                velocity = Vector3.new(horizontal.X, vertical, horizontal.Z)
                if horizontal.Magnitude <= BallConfig.RestSpeed and math.abs(vertical) < BallConfig.RestSpeed then
                    slowGroundSince = slowGroundSince or os.clock()
                    if os.clock() - slowGroundSince >= BallConfig.SleepSeconds then
                        velocity = Vector3.zero
                        angular = Vector3.zero
                    end
                else
                    slowGroundSince = nil
                end
            else
                slowGroundSince = nil
                local speed = velocity.Magnitude
                if speed > 0.001 then
                    velocity -= velocity.Unit * (BallConfig.AirDrag * speed * speed * fixedStep)
                end
            end
            angular *= math.max(0, 1 - BallConfig.SpinDecay * fixedStep)
            currentBall.AssemblyLinearVelocity = velocity
            currentBall.AssemblyAngularVelocity = angular
        end

        local currentPosition = currentBall.Position
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
    -- Close-control possession: the ball physically follows the nearest player who reaches it.
    -- It remains unanchored; an AlignPosition constraint lets tackles, kicks and ball physics stay responsive.
    task.spawn(function()
        while ball and ball.Parent do
            task.wait(0.05)
            local currentBall = ball
            if not currentBall or not currentBall.Parent or goalLocked then continue end
            local matchState = MatchService.GetState()
            if matchState.phase ~= "PLAYING" and matchState.phase ~= "PRACTICE" then
                releasePossession()
                continue
            end

            local possessorId = currentBall:GetAttribute("PossessorUserId")
            local possessor = typeof(possessorId) == "number" and possessorId > 0 and Players:GetPlayerByUserId(possessorId) or nil
            local chosenPlayer: Player? = nil
            local chosenRoot: BasePart? = nil
            local chosenHumanoid: Humanoid? = nil

            if possessor then
                local character = possessor.Character
                local root = character and character:FindFirstChild("HumanoidRootPart")
                local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0
                    and (root.Position - currentBall.Position).Magnitude <= BallConfig.DribbleReleaseRange + 2 then
                    chosenPlayer = possessor
                    chosenRoot = root
                    chosenHumanoid = humanoid
                end
            end

            if not chosenPlayer then
                releasePossession()
                local nearestDistance = BallConfig.TouchRange
                for _, candidate in ipairs(Players:GetPlayers()) do
                    local character = candidate.Character
                    local root = character and character:FindFirstChild("HumanoidRootPart")
                    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                    if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
                        local distance = (root.Position - currentBall.Position).Magnitude
                        if distance <= nearestDistance then
                            nearestDistance = distance
                            chosenPlayer = candidate
                            chosenRoot = root
                            chosenHumanoid = humanoid
                        end
                    end
                end
                if chosenPlayer and chosenRoot then
                    recordTouch(chosenPlayer)
                    attachPossession(chosenPlayer, chosenRoot)
                end
            end

            if chosenPlayer and chosenRoot and chosenHumanoid then
                local direction = Vector3.new(chosenHumanoid.MoveDirection.X, 0, chosenHumanoid.MoveDirection.Z)
                if direction.Magnitude < 0.1 then
                    local look = chosenRoot.CFrame.LookVector
                    direction = Vector3.new(look.X, 0, look.Z)
                end
                local target = chosenRoot:FindFirstChild("PITCHBallTargetAttachment")
                if target and target:IsA("Attachment") and direction.Magnitude > 0.1 then
                    target.Position = Vector3.new(0, -1.25, -BallConfig.DribbleTargetOffset)
                    target.CFrame = CFrame.new(target.Position)
                    lastDribbleAt[chosenPlayer] = os.clock()
                    lastMovedAt = os.clock()
                end
            end
        end
    end)
    print("[BallService] Validated kicks, close-control possession, tackle steals, adjustable power and half-aware goal detection are active.")
end

return BallService