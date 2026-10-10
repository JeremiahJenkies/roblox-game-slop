--!strict
local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("PlayerConfig"))
local TeamService = {}
local teamA: Team? = nil
local teamB: Team? = nil

local function getOrCreateTeam(name: string, brickColor: BrickColor): Team
    local existing = Teams:FindFirstChild(name)
    if existing and existing:IsA("Team") then
        existing.TeamColor = brickColor
        existing.AutoAssignable = false
        return existing
    end
    if existing then existing:Destroy() end
    local team = Instance.new("Team")
    team.Name = name
    team.TeamColor = brickColor
    team.AutoAssignable = false
    team.Parent = Teams
    return team
end

local function countTeams(): (number, number)
    local aCount, bCount = 0, 0
    for _, player in ipairs(Players:GetPlayers()) do
        if teamA and player.Team == teamA then aCount += 1 end
        if teamB and player.Team == teamB then bCount += 1 end
    end
    return aCount, bCount
end

function TeamService.Assign(player: Player)
    if not teamA or not teamB then return end
    local aCount, bCount = countTeams()
    local selected = aCount <= bCount and teamA or teamB
    player.Team = selected
    player:SetAttribute("Team", selected.Name)
    player.Neutral = false
end

function TeamService.PlaceCharacter(player: Player, character: Model)
    local root = character:WaitForChild("HumanoidRootPart", 10)
    if not root or not root:IsA("BasePart") then return end
    if not player.Team then TeamService.Assign(player) end
    local teamName = player.Team and player.Team.Name or player:GetAttribute("Team")
    local stadium = workspace:FindFirstChild("SoccerStadium")
    local spawnName = teamName == "Red" and "TeamASpawn" or "TeamBSpawn"
    local spawnPart = stadium and stadium:FindFirstChild(spawnName)
    if spawnPart and spawnPart:IsA("BasePart") and character.Parent then
        local randomOffset = Vector3.new(math.random(-5, 5), PlayerConfig.CharacterSpawnHeight, math.random(-5, 5))
        character:PivotTo(spawnPart.CFrame + randomOffset)
    end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.WalkSpeed = PlayerConfig.WalkSpeed
        humanoid.UseJumpPower = true
        humanoid.JumpPower = PlayerConfig.JumpPower
    end
end

local function setupPlayer(player: Player)
    if not player.Team then TeamService.Assign(player) end
    player.CharacterAdded:Connect(function(character)
        task.spawn(TeamService.PlaceCharacter, player, character)
    end)
    if player.Character then task.spawn(TeamService.PlaceCharacter, player, player.Character) end
end

function TeamService.Init()
    teamA = getOrCreateTeam("Red", BrickColor.new("Bright red"))
    teamB = getOrCreateTeam("Blue", BrickColor.new("Bright blue"))
    Players.PlayerAdded:Connect(setupPlayer)
    for _, player in ipairs(Players:GetPlayers()) do task.spawn(setupPlayer, player) end
    print("[TeamService] Balanced Red and Blue teams are ready.")
end

return TeamService