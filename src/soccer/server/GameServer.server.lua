-- Server-authoritative soccer match, stadium generation, ball physics, and persistent profiles.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

-- Preserve the existing DataStore name, player_<UserId> keys, and legacy profile fields.
local store
local storeOk, storeResult = pcall(function() return DataStoreService:GetDataStore(Config.DataStoreName) end)
if storeOk then store = storeResult else warn("[Soccer] DataStore unavailable; progress is session-only: " .. tostring(storeResult)) end
local remotes = ReplicatedStorage:FindFirstChild("SoccerRemotes") or Instance.new("Folder")
remotes.Name = "SoccerRemotes"; remotes.Parent = ReplicatedStorage
local function getRemote(name)
 local remote = remotes:FindFirstChild(name) or Instance.new("RemoteEvent")
 remote.Name = name; remote.Parent = remotes; return remote
end
local stateEvent = getRemote("StateUpdate")
local noticeEvent = getRemote("Notice")
local kickEvent = getRemote("KickBall")
local profiles, lastKick = {}, {}
local teamScores = {Red = 0, Blue = 0}
local phase, secondsLeft, matchNumber = "KICKOFF", Config.IntermissionSeconds, 0
local stadium, ball, northGoal, southGoal, redSpawn, blueSpawn
local goalLocked = false
local function part(parent, name, size, cf, color, material, transparency)
 local p = Instance.new("Part"); p.Name = name; p.Size = size; p.CFrame = cf; p.Color = color
 p.Material = material or Enum.Material.SmoothPlastic; p.Anchored = true; p.TopSurface = Enum.SurfaceType.Smooth
 p.BottomSurface = Enum.SurfaceType.Smooth; p.Transparency = transparency or 0; p.Parent = parent; return p
end
local function profileDefaults()
 return {dataVersion = 3, coins = 0, bestDay = 0, wins = 0, wood = 0, stone = 0, xp = 0, trophies = 0, discoveries = {}, goals = 0, assists = 0, matches = 0, cleanSheets = 0, soccerWins = 0}
end
local function saveProfile(player)
 local data = profiles[player]; if not data or not store then return end
 local payload = {dataVersion = 3, coins = data.coins, bestDay = data.bestDay, wins = data.wins, wood = data.wood, stone = data.stone, xp = data.xp, trophies = data.trophies, discoveries = data.discoveries, goals = data.goals, assists = data.assists, matches = data.matches, cleanSheets = data.cleanSheets, soccerWins = data.soccerWins}
 local ok, err = pcall(function() store:UpdateAsync("player_" .. player.UserId, function(old)
  -- Merge into the existing record so legacy and unknown fields are not discarded.
  old = type(old) == "table" and old or {}
  for key, value in pairs(payload) do old[key] = value end
  return old
 end) end)
 if not ok then warn("[Soccer] Save failed for " .. player.Name .. ": " .. tostring(err)) end
end
local function setProfileAttributes(player, data)
 for _, key in ipairs({"coins", "wins", "goals", "assists", "matches", "cleanSheets", "soccerWins", "xp", "trophies"}) do
  local attr = key:sub(1,1):upper() .. key:sub(2); player:SetAttribute(attr, tonumber(data[key]) or 0)
 end
end
local function loadProfile(player)
 local data = profileDefaults(); local ok, saved = false, nil
 if store then ok, saved = pcall(function() return store:GetAsync("player_" .. player.UserId) end) end
 if ok and type(saved) == "table" then
  for _, key in ipairs({"coins", "bestDay", "wins", "wood", "stone", "xp", "trophies", "goals", "assists", "matches", "cleanSheets", "soccerWins"}) do
   data[key] = math.max(0, math.floor(tonumber(saved[key]) or 0))
  end
  if type(saved.discoveries) == "table" then data.discoveries = saved.discoveries end
 elseif store and not ok then warn("[Soccer] Load failed for " .. player.Name .. ": " .. tostring(saved)) end
 profiles[player] = data; setProfileAttributes(player, data)
end
local function notify(player, message) noticeEvent:FireClient(player, message) end
local function broadcast()
 stateEvent:FireAllClients({phase = phase, secondsLeft = secondsLeft, matchNumber = matchNumber, redScore = teamScores.Red, blueScore = teamScores.Blue, redPlayers = 0, bluePlayers = 0})
end
local function assignTeams()
 local redCount, blueCount = 0, 0
 for _, player in ipairs(Players:GetPlayers()) do
  local team = (redCount <= blueCount) and "Red" or "Blue"
  player:SetAttribute("Team", team)
  if team == "Red" then redCount += 1 else blueCount += 1 end
 end
end
local function placeCharacter(player, character)
 local root = character:WaitForChild("HumanoidRootPart", 8); if not root then return end
 task.wait(0.1)
 local team = player:GetAttribute("Team") or "Red"
 local base = team == "Red" and redSpawn or blueSpawn
 if base and character.Parent then character:PivotTo(base.CFrame + Vector3.new(math.random(-7,7), 4, math.random(-6,6))) end
 local humanoid = character:FindFirstChildOfClass("Humanoid")
 if humanoid then humanoid.WalkSpeed = Config.WalkSpeed end
end
local function resetBall()
 if not ball or not ball.Parent then return end
 ball.AssemblyLinearVelocity = Vector3.zero; ball.AssemblyAngularVelocity = Vector3.zero
 ball.CFrame = CFrame.new(0, 4, 0); pcall(function() ball:SetNetworkOwner(nil) end)
end
local function scoreGoal(team)
 if goalLocked or phase ~= "LIVE" then return end
 goalLocked = true; teamScores[team] += 1
 if team == "Red" then
  for _, p in ipairs(Players:GetPlayers()) do if p:GetAttribute("Team") == "Red" then notify(p, "GOAL! Red team scores!") else notify(p, "Red team scored.") end end
 else
  for _, p in ipairs(Players:GetPlayers()) do if p:GetAttribute("Team") == "Blue" then notify(p, "GOAL! Blue team scores!") else notify(p, "Blue team scored.") end end
 end
 broadcast(); task.wait(2); resetBall(); goalLocked = false
end
local function buildStadium()
 local old = Workspace:FindFirstChild("SoccerStadium"); if old then old:Destroy() end
 stadium = Instance.new("Folder"); stadium.Name = "SoccerStadium"; stadium.Parent = Workspace
 local width, length = Config.FieldWidth, Config.FieldLength
 -- Lighting.Technology is Studio-only; attempting to set it from a runtime script throws and stops the stadium from generating.
 -- Set Lighting > Technology to Future manually in Studio for the intended high-quality lighting.
 Lighting.GlobalShadows = true; Lighting.ClockTime = 16.5
 Lighting.Brightness = 2.2; Lighting.EnvironmentDiffuseScale = 0.8; Lighting.EnvironmentSpecularScale = 0.8
 Lighting.Ambient = Color3.fromRGB(115, 126, 139); Lighting.OutdoorAmbient = Color3.fromRGB(105, 118, 130)
 local atmosphere = Lighting:FindFirstChild("SoccerAtmosphere") or Instance.new("Atmosphere")
 atmosphere.Name = "SoccerAtmosphere"; atmosphere.Density = 0.18; atmosphere.Offset = 0.15; atmosphere.Color = Color3.fromRGB(199, 218, 235); atmosphere.Decay = Color3.fromRGB(92, 113, 137); atmosphere.Haze = 0.8; atmosphere.Glare = 0.12; atmosphere.Parent = Lighting
 local bloom = Lighting:FindFirstChild("SoccerBloom") or Instance.new("BloomEffect")
 bloom.Name = "SoccerBloom"; bloom.Intensity = 0.16; bloom.Size = 18; bloom.Threshold = 1.35; bloom.Parent = Lighting
 local grade = Lighting:FindFirstChild("SoccerColorGrade") or Instance.new("ColorCorrectionEffect")
 grade.Name = "SoccerColorGrade"; grade.Brightness = 0.015; grade.Contrast = 0.08; grade.Saturation = 0.06; grade.TintColor = Color3.fromRGB(244, 248, 255); grade.Parent = Lighting
 local rays = Lighting:FindFirstChild("SoccerSunRays") or Instance.new("SunRaysEffect")
 rays.Name = "SoccerSunRays"; rays.Intensity = 0.045; rays.Spread = 0.65; rays.Parent = Lighting
 local sky = Lighting:FindFirstChild("SoccerSky") or Instance.new("Sky")
 sky.Name = "SoccerSky"; sky.CelestialBodiesShown = true; sky.StarCount = 0; sky.SunAngularSize = 14; sky.Parent = Lighting
 local clouds = Workspace.Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
 clouds.Cover = 0.28; clouds.Density = 0.32; clouds.Color = Color3.fromRGB(236, 243, 251); clouds.Parent = Workspace.Terrain
 local ground = part(stadium, "StadiumGround", Vector3.new(width + 100, 2, length + 100), CFrame.new(0, -1.3, 0), Color3.fromRGB(45, 66, 49), Enum.Material.Grass)
 ground.CastShadow = false
 part(stadium, "Pitch", Vector3.new(width, 1, length), CFrame.new(0, 0, 0), Color3.fromRGB(39, 112, 65), Enum.Material.Grass)
 for i = 1, 10 do
  local z = -length/2 + (i - 0.5) * (length/10)
  local stripe = part(stadium, "MowingStripe", Vector3.new(width - 2, 0.03, length/10), CFrame.new(0, 0.515, z), i % 2 == 0 and Color3.fromRGB(43, 124, 70) or Color3.fromRGB(37, 108, 61), Enum.Material.Grass)
  stripe.CanCollide = false
 end
 local lineColor = Color3.fromRGB(239, 242, 229)
 local function line(name, size, pos) local p = part(stadium, name, size, CFrame.new(pos), lineColor, Enum.Material.SmoothPlastic); p.CanCollide = false end
 line("TouchlineWest", Vector3.new(0.35, 0.05, length), Vector3.new(-width/2, 0.54, 0))
 line("TouchlineEast", Vector3.new(0.35, 0.05, length), Vector3.new(width/2, 0.54, 0))
 line("GoalLineNorth", Vector3.new(width, 0.05, 0.35), Vector3.new(0, 0.54, -length/2))
 line("GoalLineSouth", Vector3.new(width, 0.05, 0.35), Vector3.new(0, 0.54, length/2))
 line("HalfwayLine", Vector3.new(width, 0.05, 0.35), Vector3.new(0, 0.54, 0))
 local center = Instance.new("Part"); center.Name = "CenterCircleGuide"; center.Shape = Enum.PartType.Cylinder; center.Size = Vector3.new(0.05, 26, 26); center.CFrame = CFrame.new(0, 0.55, 0) * CFrame.Angles(0, 0, math.rad(90)); center.Anchored = true; center.CanCollide = false; center.Transparency = 0.35; center.Color = lineColor; center.Material = Enum.Material.SmoothPlastic; center.Parent = stadium
 local function box(name, x, z, w, d)
  line(name .. "Top", Vector3.new(w, 0.05, 0.3), Vector3.new(x, 0.55, z - d/2))
  line(name .. "Bottom", Vector3.new(w, 0.05, 0.3), Vector3.new(x, 0.55, z + d/2))
  line(name .. "Left", Vector3.new(0.3, 0.05, d), Vector3.new(x - w/2, 0.55, z))
  line(name .. "Right", Vector3.new(0.3, 0.05, d), Vector3.new(x + w/2, 0.55, z))
 end
 box("NorthPenaltyArea", 0, -length/2 + 18, 80, 36); box("SouthPenaltyArea", 0, length/2 - 18, 80, 36)
 local function goal(name, z, sign)
  local folder = Instance.new("Model"); folder.Name = name; folder.Parent = stadium
  local backZ = z + sign * 10
  for _, x in ipairs({-12, 12}) do local post = part(folder, "GoalPost", Vector3.new(0.7, 8, 0.7), CFrame.new(x, 4, z), Color3.fromRGB(245, 245, 238), Enum.Material.Metal); post.Anchored = true end
  part(folder, "Crossbar", Vector3.new(24.7, 0.7, 0.7), CFrame.new(0, 8, z), Color3.fromRGB(245, 245, 238), Enum.Material.Metal)
  for _, x in ipairs({-12, 12}) do part(folder, "NetSide", Vector3.new(0.25, 8, 10), CFrame.new(x, 4, (z + backZ)/2), Color3.fromRGB(210, 218, 222), Enum.Material.Fabric, 0.65) end
  part(folder, "NetRoof", Vector3.new(24, 0.25, 10), CFrame.new(0, 8, (z + backZ)/2), Color3.fromRGB(210, 218, 222), Enum.Material.Fabric, 0.7)
  local trigger = part(folder, "GoalTrigger", Vector3.new(23, 7, 3), CFrame.new(0, 3.5, z + sign * 2), Color3.new(1,1,1), Enum.Material.SmoothPlastic, 1)
  trigger.CanCollide = false; trigger.CanTouch = true; return trigger
 end
 northGoal = goal("NorthGoal", -length/2, -1); southGoal = goal("SouthGoal", length/2, 1)
 redSpawn = part(stadium, "RedSpawn", Vector3.new(12, 1, 8), CFrame.new(0, 1, length/2 - 35), Color3.fromRGB(194, 56, 57), Enum.Material.SmoothPlastic); redSpawn.Transparency = 1; redSpawn.CanCollide = false
 blueSpawn = part(stadium, "BlueSpawn", Vector3.new(12, 1, 8), CFrame.new(0, 1, -length/2 + 35), Color3.fromRGB(61, 118, 207), Enum.Material.SmoothPlastic); blueSpawn.Transparency = 1; blueSpawn.CanCollide = false
 -- Continuous grandstands along both touchlines and behind each goal.
 for _, side in ipairs({-1, 1}) do
  local x = side * (width/2 + 17)
  local stand = part(stadium, "TouchlineGrandstand", Vector3.new(18, 12, length + 42), CFrame.new(x, 5.5, 0), Color3.fromRGB(50, 61, 74), Enum.Material.Metal)
  stand.CastShadow = true
  for row = 1, 5 do
   local seatBand = part(stadium, "StandSeatBand", Vector3.new(18, 1.15, length + 38), CFrame.new(x, row * 1.75 + 1, 0), row % 2 == 0 and Color3.fromRGB(177, 54, 57) or Color3.fromRGB(61, 95, 132), Enum.Material.Metal)
   seatBand.CanCollide = true
  end
 end
 for _, endSign in ipairs({-1, 1}) do
  local z = endSign * (length/2 + 20)
  part(stadium, "EndGrandstand", Vector3.new(width/2, 10, 18), CFrame.new(0, 4.5, z), Color3.fromRGB(48, 59, 72), Enum.Material.Metal)
  for row = 1, 4 do
   part(stadium, "EndStandSeatBand", Vector3.new(width/2 - 6, 1, 18), CFrame.new(0, row * 1.8, z), row % 2 == 0 and Color3.fromRGB(177, 54, 57) or Color3.fromRGB(61, 95, 132), Enum.Material.Metal)
  end
 end
 -- Four floodlight towers frame the pitch and add scale to the stadium.
 for _, xSign in ipairs({-1, 1}) do
  for _, zSign in ipairs({-1, 1}) do
   local x, z = xSign * (width/2 + 12), zSign * (length/2 + 12)
   part(stadium, "FloodlightPole", Vector3.new(1.4, 28, 1.4), CFrame.new(x, 14, z), Color3.fromRGB(57, 67, 78), Enum.Material.Metal)
   local rig = part(stadium, "FloodlightRig", Vector3.new(8, 2, 2), CFrame.new(x, 28.5, z), Color3.fromRGB(38, 47, 58), Enum.Material.Metal)
   for lamp = 1, 4 do
    local lightPanel = part(stadium, "FloodlightPanel", Vector3.new(1.2, 0.3, 1.5), CFrame.new(x - 3 + lamp * 1.6, 27.9, z - zSign * 0.8), Color3.fromRGB(245, 249, 255), Enum.Material.Neon)
    lightPanel.CanCollide = false
   end
   local flood = Instance.new("SurfaceLight"); flood.Name = "PitchFloodlight"; flood.Face = Enum.NormalId.Bottom; flood.Brightness = 2.5; flood.Range = 48; flood.Angle = 120; flood.Parent = rig
  end
 end
 ball = Instance.new("Part"); ball.Name = "MatchBall"; ball.Shape = Enum.PartType.Ball; ball.Size = Vector3.new(3.2,3.2,3.2); ball.Position = Vector3.new(0,4,0)
 ball.Color = Color3.fromRGB(245,245,238); ball.Material = Enum.Material.SmoothPlastic; ball.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.45, 0.35, 1, 1); ball.Anchored = false; ball.CanCollide = true; ball.Parent = stadium
 ball:SetAttribute("SoccerBall", true); pcall(function() ball:SetNetworkOwner(nil) end)
 ball.Touched:Connect(function(hit)
  if hit == northGoal then scoreGoal("Red") elseif hit == southGoal then scoreGoal("Blue") end
 end)
end
kickEvent.OnServerEvent:Connect(function(player, direction)
 if phase ~= "LIVE" or not ball or not ball.Parent then return end
 if typeof(direction) ~= "Vector3" or direction.Magnitude < 0.05 or direction.Magnitude > 1.1 then return end
 local character = player.Character; local root = character and character:FindFirstChild("HumanoidRootPart")
 if not root or (root.Position - ball.Position).Magnitude > Config.KickRange then notify(player, "Move closer to the ball to kick."); return end
 local now = os.clock(); if now - (lastKick[player] or 0) < Config.KickCooldown then return end; lastKick[player] = now
 local flat = Vector3.new(direction.X, 0, direction.Z); if flat.Magnitude < 0.05 then flat = root.CFrame.LookVector end; flat = flat.Unit
 local lift = math.clamp(direction.Y, 0, 0.65) * Config.KickLift
 ball:ApplyImpulse((flat * Config.KickPower + Vector3.new(0, lift, 0)) * ball.AssemblyMass)
end)
local function finishMatch()
 phase = "FULL TIME"; broadcast()
 for _, player in ipairs(Players:GetPlayers()) do
  local data = profiles[player]
  if data then
   data.matches += 1
   local team = player:GetAttribute("Team")
   if team and teamScores[team] > teamScores[team == "Red" and "Blue" or "Red"] then data.soccerWins += 1; data.coins += 25; notify(player, "Full time — your team won! +25 credits")
   elseif teamScores.Red == teamScores.Blue then data.coins += 10; notify(player, "Full time — draw! +10 credits")
   else notify(player, "Full time — good match. Keep practising!") end
   setProfileAttributes(player, data); task.spawn(saveProfile, player)
  end
 end
 task.wait(5); teamScores = {Red = 0, Blue = 0}; resetBall()
end
Players.PlayerAdded:Connect(function(player)
 loadProfile(player); player.CharacterAdded:Connect(function(character) placeCharacter(player, character) end)
 if player.Character then task.spawn(placeCharacter, player, player.Character) end
 task.defer(assignTeams); notify(player, "Welcome to PITCH. Get close to the ball and press E or tap KICK.")
end)
Players.PlayerRemoving:Connect(function(player) saveProfile(player); profiles[player] = nil; lastKick[player] = nil end)
for _, player in ipairs(Players:GetPlayers()) do task.spawn(function() loadProfile(player) end) end
local buildOk, buildError = pcall(buildStadium)
if not buildOk then
 warn("[PITCH] Stadium generation failed: " .. tostring(buildError))
else
 print("[PITCH] Stadium, goals, and match ball created successfully.")
end
assignTeams()
task.spawn(function()
 while true do
  phase = "KICKOFF"; secondsLeft = Config.IntermissionSeconds; broadcast()
  while secondsLeft > 0 do task.wait(1); secondsLeft -= 1; broadcast() end
  matchNumber += 1; teamScores = {Red = 0, Blue = 0}; resetBall(); phase = "LIVE"; secondsLeft = Config.MatchLengthSeconds; broadcast()
  while secondsLeft > 0 and phase == "LIVE" do task.wait(1); secondsLeft -= 1; broadcast() end
  finishMatch()
 end
end)
task.spawn(function() while true do task.wait(Config.AutoSaveSeconds); for _, player in ipairs(Players:GetPlayers()) do task.spawn(saveProfile, player) end end end)
game:BindToClose(function() for _, player in ipairs(Players:GetPlayers()) do saveProfile(player) end; task.wait(2) end)