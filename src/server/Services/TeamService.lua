--!strict
local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlayerConfig = require(Shared:WaitForChild("Config"):WaitForChild("PlayerConfig"))
local ProductsConfig = require(Shared:WaitForChild("Config"):WaitForChild("ProductsConfig"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local Maid = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Maid"))
local TeamService = {}
local playerMaids: {[Player]: any} = {}
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
    local redTeam = teamA
    local blueTeam = teamB
    if not redTeam or not blueTeam then return end
    local aCount, bCount = countTeams()
    local selected: Team = aCount <= bCount and redTeam or blueTeam
    player.Team = selected
    player:SetAttribute("Team", selected.Name)
    player.Neutral = false
end

local function applyFootballAppearance(player: Player, character: Model)
    local teamName = player:GetAttribute("Team") or (player.Team and player.Team.Name) or "Red"
    -- Large wings, layered clothing and tools can interfere with tackles and make the practice camera unreadable.
    -- The foundation uses simple team-coloured bodies; cosmetic kits will replace this in a later milestone.
    for _, child in ipairs(character:GetChildren()) do
        if child:IsA("Accessory") or child:IsA("Tool") or child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic") then
            child:Destroy()
        end
    end
    local bodyColors = character:FindFirstChildOfClass("BodyColors")
    if bodyColors then
        local teamColor = teamName == "Red" and Color3.fromRGB(190, 44, 48) or Color3.fromRGB(42, 92, 173)
        local shortsColor = Color3.fromRGB(35, 43, 53)
        local profile = DataService.GetProfile(player)
        local equippedKit = profile and profile.EquippedKit or "Default"
        local kit = ProductsConfig.Items[equippedKit]
        if kit and typeof(kit.AccentColor) == "Color3" then shortsColor = kit.AccentColor end
        bodyColors.TorsoColor3 = teamColor
        bodyColors.LeftArmColor3 = teamColor
        bodyColors.RightArmColor3 = teamColor
        bodyColors.LeftLegColor3 = shortsColor
        bodyColors.RightLegColor3 = shortsColor
    end
end
function TeamService.PlaceCharacter(player: Player, character: Model)
    local root = character:WaitForChild("HumanoidRootPart", 10)
    if not root or not root:IsA("BasePart") then return end
    if not player.Team then TeamService.Assign(player) end
    local teamName = player.Team and player.Team.Name or player:GetAttribute("Team")
    applyFootballAppearance(player, character)
    local stadium = workspace:FindFirstChild("SoccerStadium")
    local spawnName = teamName == "Red" and "TeamASpawn" or "TeamBSpawn"
    local spawnPart = stadium and stadium:FindFirstChild(spawnName)
    if spawnPart and spawnPart:IsA("BasePart") and character.Parent then
        local randomOffset = Vector3.new(math.random(-PlayerConfig.SpawnRandomOffset, PlayerConfig.SpawnRandomOffset), PlayerConfig.CharacterSpawnHeight, math.random(-PlayerConfig.SpawnRandomOffset, PlayerConfig.SpawnRandomOffset))
        character:PivotTo(spawnPart.CFrame + randomOffset)
    end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.WalkSpeed = PlayerConfig.WalkSpeed
        humanoid.UseJumpPower = true
        humanoid.JumpPower = PlayerConfig.JumpPower
    end
end

function TeamService.ResetEnds()
    local stadium = workspace:FindFirstChild("SoccerStadium")
    local redSpawn = stadium and stadium:FindFirstChild("TeamASpawn")
    local blueSpawn = stadium and stadium:FindFirstChild("TeamBSpawn")
    if not redSpawn or not blueSpawn or not redSpawn:IsA("BasePart") or not blueSpawn:IsA("BasePart") then return end
    for _, player in ipairs(Players:GetPlayers()) do
        local character = player.Character
        local target = player:GetAttribute("Team") == "Blue" and blueSpawn or redSpawn
        if character and character.Parent then
            character:PivotTo(target.CFrame + Vector3.new(0, PlayerConfig.CharacterSpawnHeight, 0))
        end
    end
end

function TeamService.SwitchEnds()
    local stadium = workspace:FindFirstChild("SoccerStadium")
    local redSpawn = stadium and stadium:FindFirstChild("TeamASpawn")
    local blueSpawn = stadium and stadium:FindFirstChild("TeamBSpawn")
    if not redSpawn or not blueSpawn or not redSpawn:IsA("BasePart") or not blueSpawn:IsA("BasePart") then return end
    for _, player in ipairs(Players:GetPlayers()) do
        local character = player.Character
        local target = player:GetAttribute("Team") == "Red" and blueSpawn or redSpawn
        if character and character.Parent and target:IsA("BasePart") then
            character:PivotTo(target.CFrame + Vector3.new(0, PlayerConfig.CharacterSpawnHeight, 0))
        end
    end
end

local function setupPlayer(player: Player)
    player.CameraMinZoomDistance = 16
    player.CameraMaxZoomDistance = 70
    if playerMaids[player] then playerMaids[player]:Destroy() end
    local maid = Maid.new()
    playerMaids[player] = maid
    local currentTeam = player.Team
    if currentTeam ~= teamA and currentTeam ~= teamB then
        TeamService.Assign(player)
    elseif currentTeam then
        player:SetAttribute("Team", currentTeam.Name)
        player.Neutral = false
    end
    maid:GiveTask(player.CharacterAdded:Connect(function(character)
        task.spawn(TeamService.PlaceCharacter, player, character)
    end))
    if player.Character then task.spawn(TeamService.PlaceCharacter, player, player.Character) end
end

function TeamService.Init()
    teamA = getOrCreateTeam("Red", BrickColor.new("Bright red"))
    teamB = getOrCreateTeam("Blue", BrickColor.new("Bright blue"))
    Players.PlayerAdded:Connect(setupPlayer)
    Players.PlayerRemoving:Connect(function(player)
        local maid = playerMaids[player]
        if maid then maid:Destroy(); playerMaids[player] = nil end
    end)
    for _, player in ipairs(Players:GetPlayers()) do setupPlayer(player) end
    print("[TeamService] Balanced Red and Blue teams are ready.")
end

return TeamService