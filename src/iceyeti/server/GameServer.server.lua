-- Server-authoritative survival loop, world generation, yeti AI, and persistence.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local EnemySpawner = require(script.Parent:WaitForChild("EnemySpawner"))
local ProgressionService = require(script.Parent:WaitForChild("ProgressionService"))

-- DataStores are unavailable in unpublished places or when Studio API access is disabled.
-- Never let that stop the remotes and core game from starting.
local store
local storeOk, storeResult = pcall(function()
	return DataStoreService:GetDataStore(Config.DataStoreName)
end)
if storeOk then
	store = storeResult
else
	warn("[IceYeti] DataStore unavailable; playing with session-only data. Publish the experience and enable Studio Access to API Services to persist progress. Details: " .. tostring(storeResult))
end
local remotes = ReplicatedStorage:FindFirstChild("IceYetiRemotes") or Instance.new("Folder")
remotes.Name = "IceYetiRemotes"
remotes.Parent = ReplicatedStorage
local stateEvent = remotes:FindFirstChild("StateUpdate") or Instance.new("RemoteEvent")
stateEvent.Name = "StateUpdate"
stateEvent.Parent = remotes
local noticeEvent = remotes:FindFirstChild("Notice") or Instance.new("RemoteEvent")
noticeEvent.Name = "Notice"
noticeEvent.Parent = remotes
local flareEvent = remotes:FindFirstChild("ThrowFlare") or Instance.new("RemoteEvent")
flareEvent.Name = "ThrowFlare"
flareEvent.Parent = remotes
local sprintEvent = remotes:FindFirstChild("Sprint") or Instance.new("RemoteEvent")
sprintEvent.Name = "Sprint"
sprintEvent.Parent = remotes
local lastFlareAt = {}
local sprinting = {}
local staminaByPlayer = {}
local cacheClaims = {}

local currentDay = 0
local phase = "Preparing"
local secondsLeft = Config.IntermissionSeconds
local alive = {}
local profiles = {}
local roundRunning = false
local rng = Random.new()
local mapFolder
local yetisFolder
local lobbySpawn
local campFuel = 100
local campfireFlame
local saveProfile

local function broadcast()
	stateEvent:FireAllClients({
		day = currentDay,
		targetDays = Config.TargetDays,
		phase = phase,
		secondsLeft = secondsLeft,
		alive = #Players:GetPlayers(),
		campFuel = campFuel,
		isBloodMoon = currentDay > 0 and currentDay % 5 == 0 and phase == "Yeti Hunt",
	})
end

local function notifyAll(message)
	noticeEvent:FireAllClients(message)
end

local function makePart(parent, name, size, cframe, color, material, anchored)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.Slate
	part.Anchored = anchored ~= false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function buildWorld()
	local old = Workspace:FindFirstChild("IceYetiWorld")
	if old then old:Destroy() end
	mapFolder = Instance.new("Folder")
	mapFolder.Name = "IceYetiWorld"
	mapFolder.Parent = Workspace

	-- Remove the default Baseplate: its top face overlaps the generated ground and can shimmer (z-fighting).
	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then baseplate:Destroy() end
	pcall(function() Lighting.Technology = Enum.Technology.Future end)
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.18
	Lighting.ClockTime = 0.25
	Lighting.Brightness = 1.8
	Lighting.Ambient = Color3.fromRGB(63, 76, 91)
	Lighting.OutdoorAmbient = Color3.fromRGB(30, 42, 54)
	Lighting.FogColor = Color3.fromRGB(45, 63, 77)
	Lighting.FogStart = 38
	Lighting.FogEnd = 245
	Lighting.EnvironmentDiffuseScale = 0.45
	Lighting.EnvironmentSpecularScale = 0.55
	Lighting.ExposureCompensation = -0.03

	-- Cinematic environment stack: cool moonlight, soft bloom and restrained colour grading.
	local atmosphere = Lighting:FindFirstChild("IceYetiAtmosphere") or Instance.new("Atmosphere")
	atmosphere.Name = "IceYetiAtmosphere"
	atmosphere.Density = 0.34
	atmosphere.Offset = 0.08
	atmosphere.Color = Color3.fromRGB(156, 190, 211)
	atmosphere.Decay = Color3.fromRGB(45, 63, 78)
	atmosphere.Glare = 0.12
	atmosphere.Haze = 2.1
	atmosphere.Parent = Lighting
	local bloom = Lighting:FindFirstChild("IceYetiBloom") or Instance.new("BloomEffect")
	bloom.Name = "IceYetiBloom"
	bloom.Intensity = 0.32
	bloom.Size = 24
	bloom.Threshold = 1.4
	bloom.Parent = Lighting
	local grade = Lighting:FindFirstChild("IceYetiColorGrade") or Instance.new("ColorCorrectionEffect")
	grade.Name = "IceYetiColorGrade"
	grade.Brightness = -0.015
	grade.Contrast = 0.16
	grade.Saturation = -0.02
	grade.TintColor = Color3.fromRGB(195, 218, 235)
	grade.Parent = Lighting
	local rays = Lighting:FindFirstChild("IceYetiSunRays") or Instance.new("SunRaysEffect")
	rays.Name = "IceYetiSunRays"
	rays.Intensity = 0.025
	rays.Spread = 0.72
	rays.Parent = Lighting

	local sky = Lighting:FindFirstChildOfClass("Sky") or Instance.new("Sky")
	sky.Name = "IceYetiNightSky"
	sky.StarCount = 2200
	sky.CelestialBodiesShown = true
	sky.Parent = Lighting
	local clouds = Workspace.Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = 0.78
	clouds.Density = 0.62
	clouds.Color = Color3.fromRGB(111, 129, 143)
	clouds.Parent = Workspace.Terrain

	-- Ground is the only large surface. Props sit above it rather than sharing a coplanar face.
	local ground = makePart(mapFolder, "FrozenGround", Vector3.new(300, 4, 300), CFrame.new(0, -2, 0), Color3.fromRGB(58, 88, 55), Enum.Material.Grass)
	ground.TopSurface = Enum.SurfaceType.Smooth
	ground.CastShadow = false
	makePart(mapFolder, "MainTrail", Vector3.new(20, 0.3, 190), CFrame.new(0, 0.2, 0), Color3.fromRGB(94, 74, 52), Enum.Material.Ground)
	makePart(mapFolder, "CampPlatform", Vector3.new(52, 1, 40), CFrame.new(0, 0.4, 66), Color3.fromRGB(91, 78, 57), Enum.Material.WoodPlanks)
	lobbySpawn = Instance.new("SpawnLocation")
	lobbySpawn.Name = "CampSpawn"
	lobbySpawn.Size = Vector3.new(8, 1, 8)
	lobbySpawn.CFrame = CFrame.new(0, 1.5, 66)
	lobbySpawn.Anchored = true
	lobbySpawn.Neutral = true
	lobbySpawn.Duration = 0
	lobbySpawn.Color = Color3.fromRGB(255, 139, 58)
	lobbySpawn.Material = Enum.Material.Neon
	lobbySpawn.Parent = mapFolder

	-- A warm, safe camp contrasts with the haunted blue ice forest.
	makePart(mapFolder, "CampfireBowl", Vector3.new(5, 1, 5), CFrame.new(0, 1, 66), Color3.fromRGB(38, 31, 38), Enum.Material.Basalt)
	local flame = makePart(mapFolder, "HalloweenFlame", Vector3.new(1.8, 2.8, 1.8), CFrame.new(0, 2.8, 66), Color3.fromRGB(255, 91, 28), Enum.Material.Neon)
	campfireFlame = flame
	flame.Shape = Enum.PartType.Ball
	local fuelPrompt = Instance.new("ProximityPrompt")
	fuelPrompt.Name = "AddCampfireFuel"
	fuelPrompt.ActionText = "Feed Fire (1 Wood)"
	fuelPrompt.ObjectText = "Campfire Fuel: 100%"
	fuelPrompt.HoldDuration = 0.35
	fuelPrompt.MaxActivationDistance = 12
	fuelPrompt.RequiresLineOfSight = false
	fuelPrompt.Parent = flame
	fuelPrompt.Triggered:Connect(function(player)
		local data = profiles[player]
		if not data or data.wood < 1 then
			noticeEvent:FireClient(player, "You need at least 1 wood to feed the campfire.")
			return
		end
		if campFuel >= 100 then
			noticeEvent:FireClient(player, "The campfire is already full.")
			return
		end
		data.wood -= 1
		campFuel = math.min(100, campFuel + 22)
		player:SetAttribute("Wood", data.wood)
		fuelPrompt.ObjectText = "Campfire Fuel: " .. math.floor(campFuel) .. "%"
		noticeEvent:FireClient(player, "You added wood to the campfire. Keep the flame alive!")
	end)
	local fireLight = Instance.new("PointLight")
	fireLight.Color = Color3.fromRGB(255, 105, 45)
	fireLight.Brightness = 2.8
	fireLight.Range = 30
	fireLight.Shadows = true
	fireLight.Parent = flame
	local fireAttachment = Instance.new("Attachment")
	fireAttachment.Position = Vector3.new(0, 0.8, 0)
	fireAttachment.Parent = flame
	local embers = Instance.new("ParticleEmitter")
	embers.Name = "CampfireEmbers"
	embers.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	embers.Color = ColorSequence.new(Color3.fromRGB(255, 104, 36), Color3.fromRGB(255, 211, 102))
	embers.LightEmission = 0.8
	embers.Rate = 12
	embers.Lifetime = NumberRange.new(0.5, 1.4)
	embers.Speed = NumberRange.new(2, 5)
	embers.SpreadAngle = Vector2.new(18, 18)
	embers.Acceleration = Vector3.new(0, 2, 0)
	embers.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 0)})
	embers.Parent = fireAttachment
	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "CampfireSmoke"
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(70, 78, 83), Color3.fromRGB(122, 128, 130))
	smoke.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1)})
	smoke.Rate = 4
	smoke.Lifetime = NumberRange.new(2.5, 4)
	smoke.Speed = NumberRange.new(2, 4)
	smoke.SpreadAngle = Vector2.new(16, 16)
	smoke.Acceleration = Vector3.new(0, 1.5, 0)
	smoke.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 4)})
	smoke.Parent = fireAttachment
	makePart(mapFolder, "CampSign", Vector3.new(14, 7, 1), CFrame.new(0, 4, 43), Color3.fromRGB(43, 34, 45), Enum.Material.WoodPlanks)
	local signGui = Instance.new("SurfaceGui")
	signGui.Face = Enum.NormalId.Front
	signGui.Parent = mapFolder.CampSign
	local signText = Instance.new("TextLabel")
	signText.Size = UDim2.fromScale(1, 1)
	signText.BackgroundTransparency = 1
	signText.Text = "100 DAYS\nIN THE FROST"
	signText.TextColor3 = Color3.fromRGB(255, 166, 86)
	signText.TextScaled = true
	signText.Font = Enum.Font.GothamBlack
	signText.Parent = signGui

	for i = 1, 48 do
		local x = rng:NextInteger(-135, 135)
		local z = rng:NextInteger(-130, 130)
		if math.abs(x) > 17 or z < 38 then
			local height = rng:NextInteger(10, 25)
			local trunk = makePart(mapFolder, "DeadPineTrunk", Vector3.new(2, height, 2), CFrame.new(x, height/2, z), Color3.fromRGB(73, 54, 39), Enum.Material.Wood)
			trunk.Shape = Enum.PartType.Cylinder
			trunk.CanCollide = false
			trunk.CastShadow = true
			local crown = makePart(mapFolder, "FrostedPine", Vector3.new(rng:NextInteger(8, 14), height, rng:NextInteger(8, 14)), CFrame.new(x, height * 0.72, z), Color3.fromRGB(35, 79, 47), Enum.Material.Grass)
			crown.Shape = Enum.PartType.Ball
			crown.CanCollide = false
			crown.CastShadow = true
			local harvestPrompt = Instance.new("ProximityPrompt")
			harvestPrompt.Name = "HarvestWood"
			harvestPrompt.ActionText = "Gather Wood"
			harvestPrompt.ObjectText = "Dead Pine"
			harvestPrompt.HoldDuration = 0.7
			harvestPrompt.MaxActivationDistance = 10
			harvestPrompt.RequiresLineOfSight = false
			harvestPrompt.Parent = trunk
			local harvested = false
			harvestPrompt.Triggered:Connect(function(player)
				local data = profiles[player]
				if harvested or not data then return end
				harvested = true
				data.wood += 3
				player:SetAttribute("Wood", data.wood)
				noticeEvent:FireClient(player, "+3 wood gathered")
				trunk:Destroy()
				if crown.Parent then crown:Destroy() end
			end)
			if i % 4 == 0 then
				local pumpkin = makePart(mapFolder, "GlowingPumpkin", Vector3.new(2.8, 2.4, 2.8), CFrame.new(x + 3, 1.4, z + 2), Color3.fromRGB(255, 111, 35), Enum.Material.Neon)
				pumpkin.Shape = Enum.PartType.Ball
				local light = Instance.new("PointLight")
				light.Color = pumpkin.Color
				light.Brightness = 0.7
				light.Range = 10
				light.Parent = pumpkin
			end
		end
	end

	for i = 1, 18 do
		local x = rng:NextInteger(-118, 118)
		local z = rng:NextInteger(-112, 28)
		if math.abs(x) > 20 then
			local rock = makePart(mapFolder, "HarvestableFrostRock", Vector3.new(4, 3, 4), CFrame.new(x, 1.1, z), Color3.fromRGB(91, 103, 73), Enum.Material.Rock)
			rock.Shape = Enum.PartType.Ball
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Mine Stone"
			prompt.ObjectText = "Frost Rock"
			prompt.HoldDuration = 0.8
			prompt.MaxActivationDistance = 9
			prompt.RequiresLineOfSight = false
			prompt.Parent = rock
			local mined = false
			prompt.Triggered:Connect(function(player)
				local data = profiles[player]
				if mined or not data then return end
				mined = true
				data.stone += 2
				player:SetAttribute("Stone", data.stone)
				noticeEvent:FireClient(player, "+2 stone mined")
				rock:Destroy()
			end)
		end
	end

	-- Supply caches reward exploration. Each player can claim each cache once per day.
	for i = 1, 8 do
		local x = (i % 2 == 0) and rng:NextInteger(38, 110) or rng:NextInteger(-110, -38)
		local z = rng:NextInteger(-105, 25)
		local crate = makePart(mapFolder, "SupplyCache" .. i, Vector3.new(4, 3, 4), CFrame.new(x, 1.7, z), Color3.fromRGB(106, 72, 43), Enum.Material.WoodPlanks)
		local lid = makePart(mapFolder, "CacheLid" .. i, Vector3.new(4.2, 0.6, 4.2), CFrame.new(x, 3.45, z), Color3.fromRGB(148, 105, 59), Enum.Material.WoodPlanks)
		local glow = makePart(mapFolder, "CacheBeacon" .. i, Vector3.new(0.35, 0.35, 0.35), CFrame.new(x, 4.1, z), Color3.fromRGB(255, 191, 82), Enum.Material.Neon)
		glow.Shape = Enum.PartType.Ball
		glow.CanCollide = false
		local light = Instance.new("PointLight")
		light.Color = glow.Color
		light.Brightness = 0.65
		light.Range = 8
		light.Parent = glow
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "SearchSupplyCache"
		prompt.ActionText = "Search Cache"
		prompt.ObjectText = "Abandoned Supplies"
		prompt.HoldDuration = 0.8
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = crate
		prompt.Triggered:Connect(function(player)
			local data = profiles[player]
			if not data then return end
			cacheClaims[i] = cacheClaims[i] or {}
			if cacheClaims[i][player.UserId] == currentDay then
				noticeEvent:FireClient(player, "You already searched this cache today.")
				return
			end
			cacheClaims[i][player.UserId] = currentDay
			data.wood += 2
			data.stone += 1
			data.coins += 12
			player:SetAttribute("Wood", data.wood)
			player:SetAttribute("Stone", data.stone)
			player:SetAttribute("Coins", data.coins)
			lid.Color = Color3.fromRGB(65, 61, 51)
			glow.Transparency = 0.85
			light.Enabled = false
			noticeEvent:FireClient(player, "Supply cache found: +2 wood, +1 stone, +12 coins!")
			task.spawn(saveProfile, player)
		end)
	end

	-- A costly camp medic gives players a recovery option between hunts.
	local medic = makePart(mapFolder, "MedicStation", Vector3.new(4, 4, 4), CFrame.new(-13, 2.5, 65), Color3.fromRGB(58, 92, 72), Enum.Material.WoodPlanks)
	local medicCross = makePart(mapFolder, "MedicCross", Vector3.new(0.6, 2.2, 0.35), CFrame.new(-13, 3, 62.8), Color3.fromRGB(255, 226, 203), Enum.Material.Neon)
	medicCross.CanCollide = false
	local medicPrompt = Instance.new("ProximityPrompt")
	medicPrompt.ActionText = "Recover (20 Coins)"
	medicPrompt.ObjectText = "Camp Medic"
	medicPrompt.HoldDuration = 0.5
	medicPrompt.MaxActivationDistance = 10
	medicPrompt.RequiresLineOfSight = false
	medicPrompt.Parent = medic
	medicPrompt.Triggered:Connect(function(player)
		local data = profiles[player]
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not data or not humanoid or humanoid.Health <= 0 then return end
		if humanoid.Health >= humanoid.MaxHealth then
			noticeEvent:FireClient(player, "You're already at full health.")
			return
		end
		if data.coins < 20 then
			noticeEvent:FireClient(player, "You need 20 coins to recover.")
			return
		end
		data.coins -= 20
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + 45)
		player:SetAttribute("Coins", data.coins)
		noticeEvent:FireClient(player, "The camp medic restored up to 45 health.")
		task.spawn(saveProfile, player)
	end)

	local bench = makePart(mapFolder, "CraftingBench", Vector3.new(5, 2, 3), CFrame.new(13, 1.5, 65), Color3.fromRGB(92, 57, 42), Enum.Material.WoodPlanks)
	local benchPrompt = Instance.new("ProximityPrompt")
	benchPrompt.ActionText = "Build Shelter (15 Wood, 8 Stone)"
	benchPrompt.ObjectText = "Camp Workbench"
	benchPrompt.HoldDuration = 1
	benchPrompt.MaxActivationDistance = 12
	benchPrompt.RequiresLineOfSight = false
	benchPrompt.Parent = bench
	benchPrompt.Triggered:Connect(function(player)
		local data = profiles[player]
		if not data then return end
		if mapFolder:FindFirstChild("TeamShelter") then
			noticeEvent:FireClient(player, "Your team shelter is already built.")
			return
		end
		if data.wood < 15 or data.stone < 8 then
			noticeEvent:FireClient(player, "Shelter needs 15 wood and 8 stone. Gather from trees and rocks.")
			return
		end
		data.wood -= 15; data.stone -= 8
		player:SetAttribute("Wood", data.wood); player:SetAttribute("Stone", data.stone)
		local shelter = Instance.new("Model")
		shelter.Name = "TeamShelter"
		shelter.Parent = mapFolder
		local function piece(name, size, pos, color, material)
			local p = makePart(shelter, name, size, CFrame.new(pos), color, material)
			p.CastShadow = true
			return p
		end
		piece("Floor", Vector3.new(18, 1, 14), Vector3.new(24, 0.7, 65), Color3.fromRGB(91, 66, 51), Enum.Material.WoodPlanks)
		piece("BackWall", Vector3.new(18, 8, 1), Vector3.new(24, 5, 58), Color3.fromRGB(66, 56, 55), Enum.Material.WoodPlanks)
		piece("LeftWall", Vector3.new(1, 8, 14), Vector3.new(15, 5, 65), Color3.fromRGB(76, 61, 56), Enum.Material.WoodPlanks)
		piece("RightWall", Vector3.new(1, 8, 14), Vector3.new(33, 5, 65), Color3.fromRGB(76, 61, 56), Enum.Material.WoodPlanks)
		piece("FrontLeft", Vector3.new(6, 8, 1), Vector3.new(18, 5, 72), Color3.fromRGB(76, 61, 56), Enum.Material.WoodPlanks)
		piece("FrontRight", Vector3.new(6, 8, 1), Vector3.new(30, 5, 72), Color3.fromRGB(76, 61, 56), Enum.Material.WoodPlanks)
		piece("Roof", Vector3.new(20, 1, 16), Vector3.new(24, 9.5, 65), Color3.fromRGB(42, 48, 61), Enum.Material.Slate)
		task.spawn(saveProfile, player)
		noticeEvent:FireAllClients(player.Name .. " built the team shelter!")
	end)

	for i = 1, 7 do
		local x = (i % 2 == 0) and -34 or 34
		local z = -105 + i * 23
		local shard = makePart(mapFolder, "IceShard", Vector3.new(5, rng:NextInteger(7, 15), 5), CFrame.new(x, 5, z) * CFrame.Angles(0, 0, math.rad(rng:NextInteger(-12, 12))), Color3.fromRGB(104, 156, 177), Enum.Material.Glass)
		shard.Transparency = 0.22
		shard.CastShadow = false
	end

	-- A distant watchtower gives the forest a strong silhouette and a navigation landmark.
	local towerX, towerZ = -82, -72
	for _, offset in ipairs({Vector3.new(-5, 8, -5), Vector3.new(5, 8, -5), Vector3.new(-5, 8, 5), Vector3.new(5, 8, 5)}) do
		local leg = makePart(mapFolder, "WatchtowerSupport", Vector3.new(1.3, 16, 1.3), CFrame.new(towerX + offset.X, 8, towerZ + offset.Z), Color3.fromRGB(66, 49, 39), Enum.Material.Wood)
		leg.CFrame = leg.CFrame * CFrame.Angles(math.rad(offset.X * 0.6), 0, math.rad(offset.Z * 0.6))
	end
	makePart(mapFolder, "WatchtowerDeck", Vector3.new(14, 1.2, 14), CFrame.new(towerX, 16, towerZ), Color3.fromRGB(82, 61, 45), Enum.Material.WoodPlanks)
	makePart(mapFolder, "WatchtowerRoof", Vector3.new(16, 1, 16), CFrame.new(towerX, 23, towerZ), Color3.fromRGB(40, 49, 58), Enum.Material.Slate)
	for _, rail in ipairs({
		{Vector3.new(0, 18, -6.5), Vector3.new(14, 1, 1)},
		{Vector3.new(0, 18, 6.5), Vector3.new(14, 1, 1)},
		{Vector3.new(-6.5, 18, 0), Vector3.new(1, 1, 14)},
		{Vector3.new(6.5, 18, 0), Vector3.new(1, 1, 14)}
	}) do
		makePart(mapFolder, "WatchtowerRail", rail[2], CFrame.new(towerX + rail[1].X, rail[1].Y, towerZ + rail[1].Z), Color3.fromRGB(67, 50, 39), Enum.Material.Wood)
	end
	local beacon = makePart(mapFolder, "TowerBeacon", Vector3.new(1.5, 2.2, 1.5), CFrame.new(towerX, 20.5, towerZ), Color3.fromRGB(124, 211, 255), Enum.Material.Neon)
	beacon.Shape = Enum.PartType.Ball
	beacon.CanCollide = false
	local beaconLight = Instance.new("PointLight")
	beaconLight.Color = beacon.Color
	beaconLight.Brightness = 1.1
	beaconLight.Range = 28
	beaconLight.Parent = beacon

	-- A ruined cabin with glowing windows makes the map feel inhabited and worth exploring.
	local cabinX, cabinZ = 84, -64
	makePart(mapFolder, "AbandonedCabin", Vector3.new(22, 12, 18), CFrame.new(cabinX, 6, cabinZ), Color3.fromRGB(62, 58, 53), Enum.Material.WoodPlanks)
	makePart(mapFolder, "CabinRoof", Vector3.new(24, 1.5, 20), CFrame.new(cabinX, 12.7, cabinZ), Color3.fromRGB(42, 51, 61), Enum.Material.Slate)
	makePart(mapFolder, "CabinDoor", Vector3.new(4, 7, 0.5), CFrame.new(cabinX, 3.8, cabinZ + 9.3), Color3.fromRGB(35, 35, 34), Enum.Material.Wood)
	for _, wx in ipairs({cabinX - 7, cabinX + 7}) do
		local window = makePart(mapFolder, "CabinWindow", Vector3.new(3, 3, 0.3), CFrame.new(wx, 7, cabinZ + 9.4), Color3.fromRGB(255, 175, 83), Enum.Material.Neon)
		window.CanCollide = false
		local windowLight = Instance.new("PointLight")
		windowLight.Color = window.Color
		windowLight.Brightness = 0.55
		windowLight.Range = 10
		windowLight.Parent = window
	end
	local cabinPrompt = Instance.new("ProximityPrompt")
	cabinPrompt.ActionText = "Search Cabin"
	cabinPrompt.ObjectText = "Abandoned Cabin"
	cabinPrompt.HoldDuration = 1
	cabinPrompt.MaxActivationDistance = 10
	cabinPrompt.RequiresLineOfSight = false
	cabinPrompt.Parent = mapFolder.CabinDoor
	cabinPrompt.Triggered:Connect(function(player)
		local data = profiles[player]
		if not data then return end
		data.coins += 25
		data.wood += 3
		player:SetAttribute("Coins", data.coins)
		player:SetAttribute("Wood", data.wood)
		cabinPrompt.Enabled = false
		noticeEvent:FireClient(player, "Cabin searched: +25 coins and +3 wood!")
		task.spawn(saveProfile, player)
	end)

	-- Snowfall spans a single emitter volume rather than many tiny parts, keeping the effect inexpensive.
	local snowVolume = makePart(mapFolder, "SnowfallVolume", Vector3.new(260, 1, 260), CFrame.new(0, 54, 0), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
	snowVolume.Transparency = 1
	snowVolume.CanCollide = false
	snowVolume.CastShadow = false
	local snowEmitter = Instance.new("ParticleEmitter")
	snowEmitter.Name = "AmbientSnow"
	snowEmitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	snowEmitter.Color = ColorSequence.new(Color3.fromRGB(215, 239, 255))
	snowEmitter.LightEmission = 0.25
	snowEmitter.Rate = 32
	snowEmitter.Lifetime = NumberRange.new(5, 8)
	snowEmitter.Speed = NumberRange.new(2, 5)
	snowEmitter.SpreadAngle = Vector2.new(8, 8)
	snowEmitter.Acceleration = Vector3.new(1.5, 0, 0.5)
	snowEmitter.Drag = 0.5
	snowEmitter.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(1, 0.05)})
	snowEmitter.Parent = snowVolume

	-- Warm lanterns lead the eye toward camp and add depth to the trail.
	for i = 1, 9 do
		local z = 42 - i * 17
		for _, side in ipairs({-1, 1}) do
			local x = side * 12
			local post = makePart(mapFolder, "TrailLanternPost", Vector3.new(0.6, 5, 0.6), CFrame.new(x, 2.5, z), Color3.fromRGB(56, 44, 36), Enum.Material.Wood)
			local lantern = makePart(mapFolder, "TrailLantern", Vector3.new(1.1, 1.4, 1.1), CFrame.new(x, 5.1, z), Color3.fromRGB(255, 177, 91), Enum.Material.Neon)
			lantern.CanCollide = false
			local lanternLight = Instance.new("PointLight")
			lanternLight.Color = lantern.Color
			lanternLight.Brightness = 0.65
			lanternLight.Range = 12
			lanternLight.Shadows = false
			lanternLight.Parent = lantern
		end
	end

	-- Landmark pass: a ruined cabin, a lookout tower, and a frosted cave make the forest easier to navigate.
	-- Keep each structure as a small number of anchored parts to avoid unnecessary physics cost.
	local cabin = Instance.new("Model")
	cabin.Name = "AbandonedCabin"
	cabin.Parent = mapFolder
	makePart(cabin, "CabinFloor", Vector3.new(18, 1, 14), CFrame.new(-83, 0.5, -76), Color3.fromRGB(66, 52, 46), Enum.Material.WoodPlanks)
	makePart(cabin, "CabinBack", Vector3.new(18, 9, 1), CFrame.new(-83, 5, -83), Color3.fromRGB(58, 48, 45), Enum.Material.WoodPlanks)
	makePart(cabin, "CabinLeft", Vector3.new(1, 9, 14), CFrame.new(-92, 5, -76), Color3.fromRGB(72, 56, 47), Enum.Material.WoodPlanks)
	makePart(cabin, "CabinRight", Vector3.new(1, 9, 14), CFrame.new(-74, 5, -76), Color3.fromRGB(72, 56, 47), Enum.Material.WoodPlanks)
	makePart(cabin, "CabinRoof", Vector3.new(20, 1.5, 16), CFrame.new(-83, 10, -76), Color3.fromRGB(41, 52, 62), Enum.Material.Slate)
	local cabinMarker = makePart(cabin, "CabinLantern", Vector3.new(1, 1, 1), CFrame.new(-83, 7, -68), Color3.fromRGB(255, 171, 76), Enum.Material.Neon)
	cabinMarker.Shape = Enum.PartType.Ball
	cabinMarker.CanCollide = false
	local cabinLight = Instance.new("PointLight")
	cabinLight.Color = cabinMarker.Color
	cabinLight.Brightness = 1.1
	cabinLight.Range = 18
	cabinLight.Parent = cabinMarker

	local tower = Instance.new("Model")
	tower.Name = "FrostwatchTower"
	tower.Parent = mapFolder
	makePart(tower, "TowerBase", Vector3.new(12, 1, 12), CFrame.new(88, 0.5, -48), Color3.fromRGB(63, 57, 52), Enum.Material.WoodPlanks)
	for _, offset in ipairs({Vector3.new(-5, 8, -5), Vector3.new(5, 8, -5), Vector3.new(-5, 8, 5), Vector3.new(5, 8, 5)}) do
		makePart(tower, "SupportBeam", Vector3.new(1, 16, 1), CFrame.new(88 + offset.X, offset.Y, -48 + offset.Z), Color3.fromRGB(72, 58, 46), Enum.Material.Wood)
	end
	makePart(tower, "TowerPlatform", Vector3.new(14, 1, 14), CFrame.new(88, 16, -48), Color3.fromRGB(80, 65, 52), Enum.Material.WoodPlanks)
	makePart(tower, "TowerRoof", Vector3.new(16, 1, 16), CFrame.new(88, 22, -48), Color3.fromRGB(45, 53, 65), Enum.Material.Slate)
	local towerBeacon = makePart(tower, "TowerBeacon", Vector3.new(1.3, 1.3, 1.3), CFrame.new(88, 20, -48), Color3.fromRGB(111, 215, 255), Enum.Material.Neon)
	towerBeacon.Shape = Enum.PartType.Ball
	towerBeacon.CanCollide = false
	local beaconLight = Instance.new("PointLight")
	beaconLight.Color = towerBeacon.Color
	beaconLight.Brightness = 1.4
	beaconLight.Range = 24
	beaconLight.Parent = towerBeacon

	local cave = Instance.new("Model")
	cave.Name = "FrostCave"
	cave.Parent = mapFolder
	for i, data in ipairs({
		{Vector3.new(5, 12, 8), Vector3.new(112, 6, 20)},
		{Vector3.new(5, 10, 8), Vector3.new(124, 5, 20)},
		{Vector3.new(8, 5, 8), Vector3.new(118, 11, 20)},
		{Vector3.new(4, 8, 5), Vector3.new(118, 4, 26)},
	}) do
		local rock = makePart(cave, "CaveIceRock" .. i, data[1], CFrame.new(data[2]), Color3.fromRGB(92, 145, 170), Enum.Material.Ice)
		rock.Shape = Enum.PartType.Ball
	end
	local caveGlow = makePart(cave, "CaveGlow", Vector3.new(1.5, 1.5, 1.5), CFrame.new(118, 2, 16), Color3.fromRGB(126, 220, 255), Enum.Material.Neon)
	caveGlow.Shape = Enum.PartType.Ball
	caveGlow.CanCollide = false
	local caveLight = Instance.new("PointLight")
	caveLight.Color = caveGlow.Color
	caveLight.Brightness = 1
	caveLight.Range = 16
	caveLight.Parent = caveGlow

	-- One-time exploration discoveries are saved inside the existing player profile.
	local discoveries = {
		{model = cabin, id = "Cabin", part = cabinMarker, title = "Abandoned Cabin", coins = 25, wood = 3, stone = 0},
		{model = tower, id = "Tower", part = towerBeacon, title = "Frostwatch Tower", coins = 35, wood = 0, stone = 3},
		{model = cave, id = "Cave", part = caveGlow, title = "Frost Cave", coins = 40, wood = 1, stone = 2},
	}
	for _, discovery in ipairs(discoveries) do
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "Discover" .. discovery.id
		prompt.ActionText = "Record Discovery"
		prompt.ObjectText = discovery.title
		prompt.HoldDuration = 0.6
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = discovery.part
		prompt.Triggered:Connect(function(player)
			local data = profiles[player]
			if not data then return end
			data.discoveries = data.discoveries or {}
			if data.discoveries[discovery.id] then
				noticeEvent:FireClient(player, "Already recorded: " .. discovery.title)
				return
			end
			data.discoveries[discovery.id] = true
			data.coins += discovery.coins
			data.wood += discovery.wood
			data.stone += discovery.stone
			player:SetAttribute("Coins", data.coins)
			player:SetAttribute("Wood", data.wood)
			player:SetAttribute("Stone", data.stone)
			player:SetAttribute("Discoveries", (data.discoveries.Cabin and 1 or 0) + (data.discoveries.Tower and 1 or 0) + (data.discoveries.Cave and 1 or 0))
			noticeEvent:FireClient(player, "Discovery logged: " .. discovery.title .. "  •  +" .. discovery.coins .. " coins")
			task.spawn(saveProfile, player)
		end)
	end

	yetisFolder = Instance.new("Folder")
	yetisFolder.Name = "Yetis"
	yetisFolder.Parent = mapFolder
end

local function defaultProfile()
	return {dataVersion = ProgressionService.DataVersion, coins = 0, bestDay = 0, wins = 0, wood = 0, stone = 0, xp = 0, trophies = 0, discoveries = {}}
end

saveProfile = function(player)
	local data = profiles[player]
	if not data or not store then return end
	local payload = {dataVersion = ProgressionService.DataVersion, coins = data.coins, bestDay = data.bestDay, wins = data.wins, wood = data.wood, stone = data.stone, xp = data.xp or 0, trophies = data.trophies or 0, discoveries = data.discoveries or {}}
	local ok, err = pcall(function()
		store:UpdateAsync("player_" .. player.UserId, function()
			return payload
		end)
	end)
	if not ok then warn("[IceYeti] Save failed for " .. player.Name .. ": " .. tostring(err)) end
end

local function loadProfile(player)
	local data = defaultProfile()
	local ok, saved = false, nil
	if store then
		ok, saved = pcall(function()
			return store:GetAsync("player_" .. player.UserId)
		end)
	end
	if ok and type(saved) == "table" then
		data.coins = math.max(0, tonumber(saved.coins) or 0)
		data.bestDay = math.clamp(tonumber(saved.bestDay) or 0, 0, Config.TargetDays)
		data.wins = math.max(0, tonumber(saved.wins) or 0)
		data.wood = math.max(0, tonumber(saved.wood) or 0)
		data.stone = math.max(0, tonumber(saved.stone) or 0)
		data.xp = math.max(0, math.floor(tonumber(saved.xp) or 0))
		data.trophies = math.max(0, math.floor(tonumber(saved.trophies) or 0))
		data.dataVersion = ProgressionService.DataVersion
		if type(saved.discoveries) == "table" then
			data.discoveries = {
				Cabin = saved.discoveries.Cabin == true,
				Tower = saved.discoveries.Tower == true,
				Cave = saved.discoveries.Cave == true,
			}
		end
	elseif store and not ok then
		warn("[IceYeti] Data load failed for " .. player.Name .. ": " .. tostring(saved))
	end
	profiles[player] = data
	player:SetAttribute("Coins", data.coins)
	player:SetAttribute("BestDay", data.bestDay)
	player:SetAttribute("Wins", data.wins)
	player:SetAttribute("Wood", data.wood)
	player:SetAttribute("Stone", data.stone)
	player:SetAttribute("XP", data.xp or 0)
	player:SetAttribute("Trophies", data.trophies or 0)
	player:SetAttribute("XPMultiplier", ProgressionService.GetMultiplier(data.trophies))
	player:SetAttribute("Discoveries", (data.discoveries.Cabin and 1 or 0) + (data.discoveries.Tower and 1 or 0) + (data.discoveries.Cave and 1 or 0))
end

local function livingPlayers()
	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and root and humanoid.Health > 0 then table.insert(list, player) end
	end
	return list
end

local function spawnYeti(day, spawnPosition)
	local model = Instance.new("Model")
	model.Name = "IceYeti_Day" .. day
	model:SetAttribute("IsIceYeti", true)
	model.Parent = yetisFolder
	local root = makePart(model, "HumanoidRootPart", Vector3.new(4, 5, 3), CFrame.new(spawnPosition + Vector3.new(0, 4, 0)), Color3.fromRGB(160, 220, 238), Enum.Material.Ice, true)
	root.Shape = Enum.PartType.Block
	root.CustomPhysicalProperties = PhysicalProperties.new(1, 0.5, 0, 1, 1)
	local body = makePart(model, "YetiBody", Vector3.new(6, 6, 4), root.CFrame * CFrame.new(0, 0.5, 0), Color3.fromRGB(208, 233, 242), Enum.Material.Snow, true)
	body.CanCollide = false
	local head = makePart(model, "YetiHead", Vector3.new(4, 3.5, 3.5), root.CFrame * CFrame.new(0, 4, -0.4), Color3.fromRGB(224, 243, 248), Enum.Material.Snow, true)
	head.CanCollide = false
	local eye1 = makePart(model, "EyeLeft", Vector3.new(0.45, 0.45, 0.2), head.CFrame * CFrame.new(-0.8, 0.2, -1.7), Color3.fromRGB(255, 70, 50), Enum.Material.Neon, true)
	eye1.CanCollide = false
	local eye2 = makePart(model, "EyeRight", Vector3.new(0.45, 0.45, 0.2), head.CFrame * CFrame.new(0.8, 0.2, -1.7), Color3.fromRGB(255, 70, 50), Enum.Material.Neon, true)
	eye2.CanCollide = false

	-- A more readable, layered low-poly creature silhouette; all detail pieces move with the root.
	local leftArm = makePart(model, "HeavyLeftArm", Vector3.new(2.2, 5.2, 2.5), root.CFrame * CFrame.new(-3.65, 0.25, -0.1) * CFrame.Angles(0, 0, math.rad(-12)), Color3.fromRGB(185, 218, 231), Enum.Material.Snow, true)
	local rightArm = makePart(model, "HeavyRightArm", Vector3.new(2.2, 5.2, 2.5), root.CFrame * CFrame.new(3.65, 0.25, -0.1) * CFrame.Angles(0, 0, math.rad(12)), Color3.fromRGB(185, 218, 231), Enum.Material.Snow, true)
	local leftHand = makePart(model, "LeftIceClaws", Vector3.new(1.8, 1.3, 1.8), root.CFrame * CFrame.new(-3.8, -2.6, -0.2), Color3.fromRGB(110, 179, 202), Enum.Material.Ice, true)
	local rightHand = makePart(model, "RightIceClaws", Vector3.new(1.8, 1.3, 1.8), root.CFrame * CFrame.new(3.8, -2.6, -0.2), Color3.fromRGB(110, 179, 202), Enum.Material.Ice, true)
	local jaw = makePart(model, "FrostJaw", Vector3.new(2.4, 0.65, 1.1), head.CFrame * CFrame.new(0, -1.05, -1.35), Color3.fromRGB(79, 112, 135), Enum.Material.Slate, true)
	local hornL = makePart(model, "IceHornLeft", Vector3.new(0.75, 2.2, 0.75), head.CFrame * CFrame.new(-1.25, 1.75, 0.1) * CFrame.Angles(0, 0, math.rad(-24)), Color3.fromRGB(123, 208, 231), Enum.Material.Glass, true)
	local hornR = makePart(model, "IceHornRight", Vector3.new(0.75, 2.2, 0.75), head.CFrame * CFrame.new(1.25, 1.75, 0.1) * CFrame.Angles(0, 0, math.rad(24)), Color3.fromRGB(123, 208, 231), Enum.Material.Glass, true)
	for _, detail in ipairs({leftArm, rightArm, leftHand, rightHand, jaw, hornL, hornR}) do
		detail.CanCollide = false
		detail.CastShadow = true
	end
	leftArm.Shape = Enum.PartType.Ball
	rightArm.Shape = Enum.PartType.Ball
	leftHand.Shape = Enum.PartType.Ball
	rightHand.Shape = Enum.PartType.Ball
	jaw.Shape = Enum.PartType.Block
	hornL.Shape = Enum.PartType.Cylinder
	hornR.Shape = Enum.PartType.Cylinder

	local weldRoot = Instance.new("WeldConstraint")
	weldRoot.Part0 = root; weldRoot.Part1 = body; weldRoot.Parent = root
	for _, part in ipairs({head, eye1, eye2, leftArm, rightArm, leftHand, rightHand, jaw, hornL, hornR}) do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body; weld.Part1 = part; weld.Parent = body
	end
	local humanoid = Instance.new("Humanoid")
	humanoid.Name = "YetiHumanoid"
	humanoid.MaxHealth = Config.BaseYetiHealth + (day - 1) * Config.HealthPerDay
	humanoid.Health = humanoid.MaxHealth
	humanoid.WalkSpeed = Config.BaseYetiSpeed + math.floor((day - 1) / 10) * Config.SpeedPerTenDays
	humanoid.DisplayName = "ICE YETI"
	humanoid.Parent = model

	-- Clear, lightweight overhead health bar so players can judge whether a Yeti is nearly defeated.
	local healthBillboard = Instance.new("BillboardGui")
	healthBillboard.Name = "YetiHealthBar"
	healthBillboard.Size = UDim2.fromOffset(140, 28)
	healthBillboard.StudsOffset = Vector3.new(0, 7.5, 0)
	healthBillboard.AlwaysOnTop = true
	healthBillboard.MaxDistance = 120
	healthBillboard.Adornee = head
	healthBillboard.Parent = model
	local healthBack = Instance.new("Frame")
	healthBack.Name = "Back"
	healthBack.Size = UDim2.new(1, 0, 0, 9)
	healthBack.Position = UDim2.fromOffset(0, 17)
	healthBack.BackgroundColor3 = Color3.fromRGB(28, 31, 36)
	healthBack.BorderSizePixel = 0
	healthBack.Parent = healthBillboard
	local healthBackCorner = Instance.new("UICorner")
	healthBackCorner.CornerRadius = UDim.new(1, 0)
	healthBackCorner.Parent = healthBack
	local healthFill = Instance.new("Frame")
	healthFill.Name = "Fill"
	healthFill.Size = UDim2.fromScale(1, 1)
	healthFill.BackgroundColor3 = Color3.fromRGB(111, 224, 255)
	healthFill.BorderSizePixel = 0
	healthFill.Parent = healthBack
	local healthFillCorner = Instance.new("UICorner")
	healthFillCorner.CornerRadius = UDim.new(1, 0)
	healthFillCorner.Parent = healthFill
	local healthName = Instance.new("TextLabel")
	healthName.Name = "Name"
	healthName.Size = UDim2.new(1, 0, 0, 15)
	healthName.BackgroundTransparency = 1
	healthName.Font = Enum.Font.GothamBlack
	healthName.Text = "ICE YETI"
	healthName.TextColor3 = Color3.fromRGB(225, 245, 255)
	healthName.TextStrokeTransparency = 0.4
	healthName.TextSize = 11
	healthName.Parent = healthBillboard
	local function refreshHealthBar()
		local ratio = math.clamp(humanoid.Health / math.max(1, humanoid.MaxHealth), 0, 1)
		healthFill.Size = UDim2.fromScale(ratio, 1)
		healthFill.BackgroundColor3 = ratio <= 0.25 and Color3.fromRGB(255, 75, 74) or (ratio <= 0.55 and Color3.fromRGB(255, 175, 69) or Color3.fromRGB(111, 224, 255))
		healthName.Text = "ICE YETI  •  " .. math.ceil(humanoid.Health) .. " HP"
	end
	humanoid.HealthChanged:Connect(refreshHealthBar)
	refreshHealthBar()
	model.PrimaryPart = root
	pcall(function() root:SetNetworkOwner(nil) end)

	humanoid.Died:Connect(function()
		local lastUserId = model:GetAttribute("LastHitUserId")
		local player = lastUserId and Players:GetPlayerByUserId(lastUserId)
		if player and profiles[player] then
			local reward = Config.BaseReward + day * Config.RewardPerDay
			profiles[player].coins += reward
			player:SetAttribute("Coins", profiles[player].coins)
			noticeEvent:FireClient(player, "+" .. reward .. " coins for defeating an Ice Yeti!")
			task.spawn(saveProfile, player)
		end
		task.delay(3, function() if model.Parent then model:Destroy() end end)
	end)

	task.spawn(function()
		local lastAttack = 0
		while model.Parent and humanoid.Health > 0 do
			local target, dist
			for _, player in ipairs(livingPlayers()) do
				local char = player.Character
				local targetRoot = char and char:FindFirstChild("HumanoidRootPart")
				local d = targetRoot and (targetRoot.Position - root.Position).Magnitude
				local campDistance = targetRoot and (targetRoot.Position - Vector3.new(0, 0, 66)).Magnitude or math.huge
				if d and not (campFuel > 0 and campDistance <= 25) and (not dist or d < dist) then target, dist = player, d end
			end
			if target then
				local targetRoot = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
				if targetRoot then
					local offset = targetRoot.Position - root.Position
					local flatOffset = Vector3.new(offset.X, 0, offset.Z)
					if flatOffset.Magnitude > 2 then
						local step = math.min(flatOffset.Magnitude, humanoid.WalkSpeed * 0.28)
						model:PivotTo(model:GetPivot() + flatOffset.Unit * step)
					end
					if dist <= Config.AttackRange and os.clock() - lastAttack >= Config.AttackCooldown then
						lastAttack = os.clock()
						local targetHumanoid = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
						if targetHumanoid and targetHumanoid.Health > 0 then
							targetHumanoid:TakeDamage(Config.BaseYetiDamage + math.floor((day - 1) / 8) * Config.DamagePerDay + (day % 5 == 0 and 4 or 0))
						end
					end
				end
			end
			task.wait(0.4)
		end
	end)
	return model
end


flareEvent.OnServerEvent:Connect(function(player, target)
	if typeof(target) ~= "Instance" or not target:IsA("Model") then return end
	if not target:GetAttribute("IsIceYeti") or not yetisFolder or not target:IsDescendantOf(yetisFolder) then return end
	local now = os.clock()
	if lastFlareAt[player] and now - lastFlareAt[player] < 1.1 then return end
	local character = player.Character
	local playerRoot = character and character:FindFirstChild("HumanoidRootPart")
	local playerHumanoid = character and character:FindFirstChildOfClass("Humanoid")
	local targetRoot = target:FindFirstChild("HumanoidRootPart")
	local targetHumanoid = target:FindFirstChildOfClass("Humanoid")
	if not playerRoot or not playerHumanoid or playerHumanoid.Health <= 0 or not targetRoot or not targetHumanoid or targetHumanoid.Health <= 0 then return end
	if (playerRoot.Position - targetRoot.Position).Magnitude > 90 then
		noticeEvent:FireClient(player, "That Yeti is too far away!")
		return
	end
	lastFlareAt[player] = now
	target:SetAttribute("LastHitUserId", player.UserId)
	targetHumanoid:TakeDamage(35)
	noticeEvent:FireClient(player, "Flare hit! The Yeti has " .. math.max(0, math.floor(targetHumanoid.Health)) .. " health left.")
end)

Players.PlayerRemoving:Connect(function(player)
	lastFlareAt[player] = nil
	sprinting[player] = nil
	staminaByPlayer[player] = nil
end)

sprintEvent.OnServerEvent:Connect(function(player, enabled)
	if typeof(enabled) ~= "boolean" then return end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		sprinting[player] = false
		return
	end
	if enabled and (staminaByPlayer[player] or 100) > 5 then
		sprinting[player] = true
	else
		sprinting[player] = false
		humanoid.WalkSpeed = 16
	end
end)

-- Server-owned stamina prevents clients from granting themselves unlimited sprint.
task.spawn(function()
	while true do
		task.wait(0.25)
		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local stamina = staminaByPlayer[player]
			if stamina == nil then stamina = 100 end
			if humanoid and humanoid.Health > 0 then
				if sprinting[player] and stamina > 0 then
					stamina = math.max(0, stamina - 2.5)
					humanoid.WalkSpeed = 23
					if stamina <= 0 then sprinting[player] = false; humanoid.WalkSpeed = 16 end
				else
					stamina = math.min(100, stamina + 1.5)
					humanoid.WalkSpeed = 16
				end
				staminaByPlayer[player] = stamina
				player:SetAttribute("Stamina", math.floor(stamina))
			end
		end
	end
end)

local function onCharacter(player, character)
	sprinting[player] = false
	staminaByPlayer[player] = 100
	player:SetAttribute("Stamina", 100)
	local humanoid = character:WaitForChild("Humanoid", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not humanoid or not root then return end
	task.wait(0.15)
	if lobbySpawn and character.Parent then character:PivotTo(lobbySpawn.CFrame + Vector3.new(0, 4, 0)) end
	humanoid.Died:Connect(function()
		noticeEvent:FireClient(player, "You were caught by the frost. You'll return at the next day.")
	end)
end

Players.PlayerAdded:Connect(function(player)
	loadProfile(player)
	player.CharacterAdded:Connect(function(character) onCharacter(player, character) end)
end)
Players.PlayerRemoving:Connect(function(player)
	saveProfile(player)
	profiles[player] = nil
end)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(function()
		loadProfile(player)
		player.CharacterAdded:Connect(function(character) onCharacter(player, character) end)
	end)
end

buildWorld()
broadcast()

local function awardSurvival(day)
	for _, player in ipairs(livingPlayers()) do
		local profile = profiles[player]
		if profile then
			local reward = Config.BaseReward + day * Config.RewardPerDay
			local earnedXP, trophiesEarned, multiplier = ProgressionService.ApplySurvivalReward(profile, day)
			profile.coins += reward
			profile.bestDay = math.max(profile.bestDay, day)
			player:SetAttribute("Coins", profile.coins)
			player:SetAttribute("BestDay", profile.bestDay)
			player:SetAttribute("XP", profile.xp)
			player:SetAttribute("Trophies", profile.trophies)
			player:SetAttribute("XPMultiplier", ProgressionService.GetMultiplier(profile.trophies))
			local extra = trophiesEarned > 0 and (" | +" .. trophiesEarned .. " trophy") or ""
			noticeEvent:FireClient(player, "Survived night " .. day .. "! +" .. reward .. " coins, +" .. earnedXP .. " XP (" .. string.format("%.2f", multiplier) .. "x)" .. extra)
			task.spawn(saveProfile, player)
		end
	end
end

-- Periodic saves protect progress if a player disconnects unexpectedly.
task.spawn(function()
	while true do
		task.wait(60)
		for _, player in ipairs(Players:GetPlayers()) do
			task.spawn(saveProfile, player)
		end
	end
end)

task.spawn(function()
	while true do
		phase = "Camp"
		Lighting.FogColor = Color3.fromRGB(45, 63, 77)
		Lighting.FogEnd = 245
		Lighting.ClockTime = 0.25
		local atmosphere = Lighting:FindFirstChild("IceYetiAtmosphere")
		if atmosphere then atmosphere.Color = Color3.fromRGB(156, 190, 211); atmosphere.Decay = Color3.fromRGB(45, 63, 78) end
		secondsLeft = Config.IntermissionSeconds
		if yetisFolder then yetisFolder:ClearAllChildren() end
		EnemySpawner.ClearRound()
		notifyAll("The camp is safe... for now.")
		while secondsLeft > 0 do
			campFuel = math.max(0, campFuel - 0.08)
			if campfireFlame then campfireFlame.Transparency = campFuel > 0 and 0 or 0.75 end
			broadcast(); task.wait(1); secondsLeft -= 1
		end

		currentDay += 1
		cacheClaims = {}
		if currentDay > Config.TargetDays then
			currentDay = Config.TargetDays
			phase = "Victory"
			for _, player in ipairs(Players:GetPlayers()) do
				local profile = profiles[player]
				if profile then
					profile.wins += 1
					player:SetAttribute("Wins", profile.wins)
					task.spawn(saveProfile, player)
				end
			end
			notifyAll("YOU SURVIVED ALL 100 DAYS! The Frost is broken!")
			task.wait(30)
			currentDay = 0
			cacheClaims = {}
		end

		phase = "Yeti Hunt"
		secondsLeft = Config.DayLengthSeconds
		if currentDay % 5 == 0 then
			Lighting.FogColor = Color3.fromRGB(104, 38, 45)
			Lighting.FogEnd = 150
			Lighting.ClockTime = 0
			local atmosphere = Lighting:FindFirstChild("IceYetiAtmosphere")
			if atmosphere then atmosphere.Color = Color3.fromRGB(192, 116, 137); atmosphere.Decay = Color3.fromRGB(83, 34, 48) end
			notifyAll("BLOOD MOON — the Yetis are stronger and the forest turns crimson!")
		else
			Lighting.FogColor = Color3.fromRGB(45, 63, 77)
			Lighting.FogEnd = 245
			local atmosphere = Lighting:FindFirstChild("IceYetiAtmosphere")
			if atmosphere then atmosphere.Color = Color3.fromRGB(156, 190, 211); atmosphere.Decay = Color3.fromRGB(45, 63, 78) end
			notifyAll("DAY " .. currentDay .. " — THE ICE YETIS ARE HUNTING!")
		end
		-- If designers configure spawn points and templates, use the modular spawner.
		-- Otherwise preserve the original generated-yeti wave unchanged.
		if EnemySpawner.HasConfiguredSpawnPoints() then
			local configuredCount = EnemySpawner.SpawnForDay(currentDay, yetisFolder)
			if configuredCount == 0 then
				warn("[IceYeti] Configured spawn points produced no enemies. Check EnemyTemplates and spawn attributes.")
			end
		else
			local spawnCount = math.clamp(1 + math.floor((currentDay - 1) / 5) + (currentDay % 5 == 0 and 1 or 0), 1, 12)
			for i = 1, spawnCount do
				local x = rng:NextInteger(-90, 90)
				local z = rng:NextInteger(-105, 5)
				spawnYeti(currentDay, Vector3.new(x, 0, z))
			end
		end
		while secondsLeft > 0 do
			campFuel = math.max(0, campFuel - 0.35)
			if campfireFlame then campfireFlame.Transparency = campFuel > 0 and 0 or 0.75 end
			broadcast()
			if #livingPlayers() == 0 and #Players:GetPlayers() > 0 then
				notifyAll("Everyone is down! Hold on until the next camp phase.")
				break
			end
			task.wait(1)
			secondsLeft -= 1
		end
		awardSurvival(currentDay)
	end
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do task.spawn(saveProfile, player) end
	task.wait(2)
end)
