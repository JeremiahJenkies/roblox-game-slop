--!strict
-- Impulse-based dribbling. The ball stays server-owned and is never welded/constrained to a player.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"):WaitForChild("DribbleConfig"))
local PlayerConfig = require(Shared:WaitForChild("Config"):WaitForChild("PlayerConfig"))

local DribbleService = {}
export type Hooks = { GetBall: () -> BasePart?, CanDribble: (Player) -> boolean, OnTouch: ((Player) -> ())? }
local hooks: Hooks? = nil
local started, enabled, debugEnabled = false, true, false
local accumulator = 0
local rng = Random.new()
local lastTouch: {[Player]: number} = {}
local kickLock: {[Player]: number} = {}
local dribbleLock: {[Player]: number} = {}
local lastMove: {[Player]: Vector3} = {}
local skillCooldown: {[Player]: {[string]: number}} = {}
local debugFolder: Folder? = nil
local shieldOriginalSpeed: {[Player]: number} = {}

local function flat(v: Vector3): Vector3 return Vector3.new(v.X, 0, v.Z) end
local function unit(v: Vector3, fallback: Vector3): Vector3 return v.Magnitude > 1e-4 and v.Unit or fallback end
local function rootFor(player: Player): (BasePart?, Humanoid?)
    local character = player.Character
    if not character then return nil, nil end
    local root = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then return root, humanoid end
    return nil, nil
end
local function skillFor(player: Player): number
    local skill = player:GetAttribute("DribbleSkill")
    if typeof(skill) ~= "number" or skill ~= skill then skill = Config.DefaultSkill end
    return math.clamp(skill :: number, 0, 1)
end
local function tiredMultiplier(player: Player): number
    return (tonumber(player:GetAttribute("Stamina")) or 100) <= Config.TiredThreshold and Config.TiredTouchMultiplier or 1
end
local function debugMarkers(root: BasePart, foot: Vector3, target: Vector3)
    if not debugEnabled or not RunService:IsStudio() then return end
    if not debugFolder or not debugFolder.Parent then
        debugFolder = Instance.new("Folder")
        debugFolder.Name = "PITCHDribbleDebug"
        debugFolder.Parent = workspace
    end
    local function marker(name: string, position: Vector3, size: Vector3, color: Color3)
        local part = debugFolder and debugFolder:FindFirstChild(name)
        if not part then
            part = Instance.new("Part")
            part.Name = name
            part.Anchored = true
            part.CanCollide = false
            part.CanTouch = false
            part.CanQuery = false
            part.Material = Enum.Material.Neon
            part.Parent = debugFolder
        end
        if part:IsA("BasePart") then
            part.Position = position
            part.Size = size
            part.Color = color
            part.Transparency = 0.35
        end
    end
    marker("FootPoint", foot, Vector3.new(0.35, 0.35, 0.35), Color3.fromRGB(80, 255, 120))
    marker("BallTarget", target, Vector3.new(0.45, 0.45, 0.45), Color3.fromRGB(255, 190, 40))
    marker("TouchRange", root.Position, Vector3.new(Config.TouchRange * 2, 0.08, Config.TouchRange * 2), Color3.fromRGB(60, 180, 255))
end
local function pushToVelocity(ball: BasePart, desired: Vector3, strength: number)
    if ball.Anchored or ball.AssemblyMass <= 0 then return end
    local current = ball.AssemblyLinearVelocity
    local target = Vector3.new(desired.X, current.Y, desired.Z)
    local delta = target - current
    if delta.Magnitude > Config.MaxDribbleBallSpeed then delta = delta.Unit * Config.MaxDribbleBallSpeed end
    ball:ApplyImpulse(delta * ball.AssemblyMass * math.clamp(strength, 0, 1))
    local result = ball.AssemblyLinearVelocity
    local horizontal = flat(result)
    if horizontal.Magnitude > Config.MaxDribbleBallSpeed then
        horizontal = horizontal.Unit * Config.MaxDribbleBallSpeed
        ball.AssemblyLinearVelocity = Vector3.new(horizontal.X, result.Y, horizontal.Z)
    end
end
local function evaluate(player: Player, ball: BasePart, now: number)
    local h = hooks
    if not h or not h.CanDribble(player) then return nil end
    if now < (kickLock[player] or 0) or now < (dribbleLock[player] or 0) then return nil end
    if now - (lastTouch[player] or 0) < Config.TouchInterval then return nil end
    local root, humanoid = rootFor(player)
    if not root or not humanoid then return nil end
    local look = unit(flat(root.CFrame.LookVector), Vector3.new(0, 0, -1))
    local foot = Vector3.new(root.Position.X, ball.Position.Y, root.Position.Z) + look * Config.FootForwardOffset
    local toBall = flat(ball.Position - foot)
    local distance = toBall.Magnitude
    if distance > Config.TouchRange then return nil end
    if distance > 0.05 and look:Dot(toBall.Unit) < Config.MinFacingDot then return nil end
    local feetY = root.Position.Y - (humanoid.HipHeight + root.Size.Y / 2)
    if ball.Position.Y - ball.Size.X / 2 - feetY > Config.MaxTouchHeight then return nil end
    return {player = player, root = root, humanoid = humanoid, foot = foot, distance = distance, toBall = toBall}
end
type Candidate = { player: Player, root: BasePart, humanoid: Humanoid, foot: Vector3, distance: number, toBall: Vector3 }

local function step()
    local h = hooks
    local ball = h and h.GetBall()
    if not enabled or not h or not ball or not ball.Parent or ball.Anchored then return end
    pcall(function() ball:SetNetworkOwner(nil) end)
    local now = os.clock()
    local candidates: {Candidate} = {}
    for _, player in ipairs(Players:GetPlayers()) do
        local candidate = evaluate(player, ball, now)
        if candidate then table.insert(candidates, candidate) end
    end
    if #candidates == 0 then return end
    table.sort(candidates, function(a, b)
        if math.abs(a.distance - b.distance) > 0.05 then return a.distance < b.distance end
        local facingA = unit(flat(a.root.CFrame.LookVector), Vector3.new(0, 0, -1)):Dot(unit(a.toBall, Vector3.new(0, 0, -1)))
        local facingB = unit(flat(b.root.CFrame.LookVector), Vector3.new(0, 0, -1)):Dot(unit(b.toBall, Vector3.new(0, 0, -1)))
        if math.abs(facingA - facingB) > 0.02 then return facingA > facingB end
        return flat(a.root.AssemblyLinearVelocity).Magnitude > flat(b.root.AssemblyLinearVelocity).Magnitude
    end)
    local c = candidates[1]
    local player, root, humanoid = c.player, c.root, c.humanoid
    local ballVelocity = ball.AssemblyLinearVelocity
    local playerVelocity = flat(root.AssemblyLinearVelocity)
    local speed = playerVelocity.Magnitude
    local tired = tiredMultiplier(player)
    local target: Vector3
    if speed < Config.MinMoveSpeed or flat(humanoid.MoveDirection).Magnitude < 0.05 then
        target = c.foot
        if flat(ballVelocity).Magnitude < Config.TrapMaxBallSpeed then
            local damped = flat(ballVelocity) * Config.TrapDamping
            ball:ApplyImpulse((Vector3.new(damped.X, ballVelocity.Y, damped.Z) - ballVelocity) * ball.AssemblyMass * tired)
        end
    else
        local direction = playerVelocity.Unit
        local alpha = math.clamp(speed / Config.RefSpeed, 0, 1)
        local lead = Config.LeadMin + (Config.LeadMax - Config.LeadMin) * alpha
        if player:GetAttribute("Sprinting") == true then lead *= Config.SprintLeadMultiplier end
        local previous = lastMove[player]
        local errorVector = Vector3.zero
        if previous then
            local turnAlpha = (1 - math.clamp(previous:Dot(direction), -1, 1)) / 2
            local errorSize = Config.TurnErrorMax * turnAlpha * (1 - skillFor(player))
            if errorSize > 0 then errorVector = Vector3.new(-direction.Z, 0, direction.X) * rng:NextNumber(-errorSize, errorSize) end
        end
        lastMove[player] = direction
        target = Vector3.new(root.Position.X, ball.Position.Y, root.Position.Z) + direction * (Config.FootForwardOffset + lead) + errorVector
        local desired = playerVelocity + flat(target - ball.Position) * Config.CorrectionGain
        local maxSpeed = math.min(math.max(speed * Config.MaxSpeedFactor, Config.MinTouchSpeed), Config.MaxDribbleBallSpeed)
        if desired.Magnitude > maxSpeed then desired = desired.Unit * maxSpeed end
        pushToVelocity(ball, desired * tired, Config.TouchStrength)
    end
    lastTouch[player] = now
    ball:SetAttribute("PossessorUserId", player.UserId)
    if h.OnTouch then h.OnTouch(player) end
    debugMarkers(root, c.foot, target)
end
function DribbleService.NotifyKick(player: Player)
    kickLock[player] = os.clock() + Config.KickLockout
end
function DribbleService.NotifyTackle(winner: Player, loser: Player?)
    local h = hooks
    local ball = h and h.GetBall()
    if not ball then return end
    if loser then dribbleLock[loser] = os.clock() + Config.TackleLockout end
    ball:SetAttribute("PossessorUserId", 0)
    local winnerRoot = rootFor(winner)
    local loserRoot = loser and rootFor(loser) or nil
    if winnerRoot then
        local away = loserRoot and flat(winnerRoot.Position - loserRoot.Position) or flat(winnerRoot.CFrame.LookVector)
        pushToVelocity(ball, unit(away, Vector3.new(0, 0, -1)) * Config.TackleLooseImpulse, 0.9)
    end
end
function DribbleService.RequestSkillMove(player: Player, moveName: any): boolean
    if typeof(moveName) ~= "string" then return false end
    local allowed = {KnockOn = true, DragBack = true, StepOver = true, QuickTurn = true, Shield = true, Feint = true}
    if not allowed[moveName] then return false end
    local h = hooks
    local ball = h and h.GetBall()
    if not h or not ball or not ball.Parent or not h.CanDribble(player) then return false end
    local root, humanoid = rootFor(player)
    if not root or not humanoid or (root.Position - ball.Position).Magnitude > Config.SkillRange then return false end
    local now = os.clock()
    local cooldowns = skillCooldown[player] or {}
    skillCooldown[player] = cooldowns
    local cooldown = moveName == "KnockOn" and Config.KnockOnCooldown or moveName == "DragBack" and Config.DragBackCooldown or moveName == "QuickTurn" and Config.QuickTurnCooldown or moveName == "Shield" and Config.ShieldCooldown or Config.SkillCooldown
    if now < (cooldowns[moveName] or 0) then return false end
    local cost = moveName == "KnockOn" and Config.KnockOnStaminaCost or moveName == "DragBack" and Config.DragBackStaminaCost or moveName == "QuickTurn" and Config.QuickTurnStaminaCost or moveName == "Shield" and Config.ShieldStaminaCost or Config.SkillStaminaCost
    local stamina = tonumber(player:GetAttribute("Stamina")) or 100
    if stamina < cost then return false end
    player:SetAttribute("Stamina", stamina - cost)
    cooldowns[moveName] = now + cooldown
    root:SetAttribute("PITCHSkillMove", moveName)
    root:SetAttribute("PITCHSkillMoveUntil", now + 0.55)
    local forward = unit(flat(root.CFrame.LookVector), Vector3.new(0, 0, -1))
    local direction = unit(flat(humanoid.MoveDirection), forward)
    if moveName == "KnockOn" then
        ball:SetAttribute("PossessorUserId", 0)
        pushToVelocity(ball, direction * Config.KnockOnImpulse, 1)
    elseif moveName == "DragBack" then
        ball:SetAttribute("PossessorUserId", 0)
        pushToVelocity(ball, -forward * Config.DragBackImpulse, 0.75)
    elseif moveName == "QuickTurn" then
        ball:SetAttribute("PossessorUserId", 0)
        local turn = Vector3.new(-forward.Z, 0, forward.X)
        pushToVelocity(ball, unit(direction, turn) * Config.QuickTurnImpulse, 0.8)
    elseif moveName == "Shield" then
        shieldOriginalSpeed[player] = humanoid.WalkSpeed
        humanoid.WalkSpeed *= Config.ShieldWalkSpeedMultiplier
        player:SetAttribute("PITCHShieldUntil", now + 0.8)
    else
        local right = flat(root.CFrame.RightVector)
        local side = direction:Dot(right) >= 0 and 1 or -1
        pushToVelocity(ball, direction * 5 + right * side * 7, 0.65)
    end
    task.delay(0.6, function()
        if root.Parent and root:GetAttribute("PITCHSkillMoveUntil") == now + 0.55 then
            root:SetAttribute("PITCHSkillMove", nil)
            root:SetAttribute("PITCHSkillMoveUntil", nil)
        end
        if moveName == "Shield" and player.Parent == Players then
            local _, currentHumanoid = rootFor(player)
            local original = shieldOriginalSpeed[player]
            if currentHumanoid and original then currentHumanoid.WalkSpeed = original end
            shieldOriginalSpeed[player] = nil
        end
    end)
    return true
end
function DribbleService.SetEnabled(value: boolean) enabled = value end
function DribbleService.SetDebug(value: boolean)
    if not RunService:IsStudio() then return end
    debugEnabled = value
    if not value and debugFolder then debugFolder:Destroy(); debugFolder = nil end
end
function DribbleService.DebugTouch(player: Player)
    if not RunService:IsStudio() then return end
    local h = hooks
    local ball = h and h.GetBall()
    local root = rootFor(player)
    if ball and root then
        pushToVelocity(ball, unit(flat(root.CFrame.LookVector), Vector3.new(0, 0, -1)) * Config.MinTouchSpeed, 0.5)
        if h and h.OnTouch then h.OnTouch(player) end
    end
end
function DribbleService.Init(newHooks: Hooks)
    if started then return end
    started = true
    hooks = newHooks
    Players.PlayerRemoving:Connect(function(player)
        lastTouch[player] = nil; kickLock[player] = nil; dribbleLock[player] = nil
        lastMove[player] = nil; skillCooldown[player] = nil; shieldOriginalSpeed[player] = nil
    end)
    RunService.Heartbeat:Connect(function(dt)
        accumulator += math.min(dt, 0.1)
        local interval = 1 / Config.StepRate
        if accumulator < interval then return end
        accumulator %= interval
        step()
    end)
end
return DribbleService