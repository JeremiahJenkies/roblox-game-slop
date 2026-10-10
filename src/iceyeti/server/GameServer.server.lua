-- Server-authoritative survival loop, world generation, yeti AI, and persistence.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

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
local lastFlareAt = {}

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

local function broadcast()
	stateEvent:FireAllClients({
		day = currentDay,
		targetDays = Config.TargetDays,
		phase = phase,
		secondsLeft = secondsLeft,
		alive = #Players:GetPlayers(),
		campFuel = campFuel,
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
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.32
	Lighting.ClockTime = 0
	Lighting.Brightness = 1.1
	Lighting.Ambient = Color3.fromRGB(80, 92, 125)
	Lighting.OutdoorAmbient = Color3.fromRGB(43, 51, 78)
	Lighting.FogColor = Color3.fromRGB(120, 145, 175)
	Lighting.FogStart = 80
	Lighting.FogEnd = 260
	Lighting.EnvironmentDiffuseScale = 0.25
	Lighting.EnvironmentSpecularScale = 0.3
	Lighting.ExposureCompensation = -0.15

	-- Ground is the only large surface. Props sit above it rather than sharing a coplanar face.
	local ground = makePart(mapFolder, "FrozenGround", Vector3.new(300, 4, 300), CFrame.new(0, -2, 0), Color3.fromRGB(170, 198, 215), Enum.Material.Snow)
	ground.TopSurface = Enum.SurfaceType.Smooth
	ground.CastShadow = false
	makePart(mapFolder, "MainTrail", Vector3.new(20, 0.3, 190), CFrame.new(0, 0.2, 0), Color3.fromRGB(90, 112, 142), Enum.Material.Slate)
	makePart(mapFolder, "CampPlatform", Vector3.new(52, 1, 40), CFrame.new(0, 0.4, 66), Color3.fromRGB(65, 77, 94), Enum.Material.Slate)
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
	fireLight.Brightness = 2.2
	fireLight.Range = 24
	fireLight.Parent = flame
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
			local trunk = makePart(mapFolder, "DeadPineTrunk", Vector3.new(2, height, 2), CFrame.new(x, height/2, z), Color3.fromRGB(45, 48, 60), Enum.Material.Wood)
			trunk.Shape = Enum.PartType.Cylinder
			trunk.CanCollide = false
			trunk.CastShadow = true
			local crown = makePart(mapFolder, "FrostedPine", Vector3.new(rng:NextInteger(8, 14), height, rng:NextInteger(8, 14)), CFrame.new(x, height * 0.72, z), Color3.fromRGB(45, 70, 91), Enum.Material.Slate)
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
			local rock = makePart(mapFolder, "HarvestableFrostRock", Vector3.new(4, 3, 4), CFrame.new(x, 1.1, z), Color3.fromRGB(103, 128, 151), Enum.Material.Rock)
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
		makePart(mapFolder, "IceShard", Vector3.new(5, rng:NextInteger(7, 15), 5), CFrame.new(x, 5, z) * CFrame.Angles(0, 0, math.rad(rng:NextInteger(-12, 12))), Color3.fromRGB(116, 202, 230), Enum.Material.Glass)
	end

	yetisFolder = Instance.new("Folder")
	yetisFolder.Name = "Yetis"
	yetisFolder.Parent = mapFolder
end

local function defaultProfile()
	return {coins = 0, bestDay = 0, wins = 0, wood = 0, stone = 0}
end

local function saveProfile(player)
	local data = profiles[player]
	if not data or not store then return end
	local payload = {coins = data.coins, bestDay = data.bestDay, wins = data.wins, wood = data.wood, stone = data.stone}
	local ok, err = pcall(function()
		store:SetAsync("player_" .. player.UserId, payload)
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
	elseif store and not ok then
		warn("[IceYeti] Data load failed for " .. player.Name .. ": " .. tostring(saved))
	end
	profiles[player] = data
	player:SetAttribute("Coins", data.coins)
	player:SetAttribute("BestDay", data.bestDay)
	player:SetAttribute("Wins", data.wins)
	player:SetAttribute("Wood", data.wood)
	player:SetAttribute("Stone", data.stone)
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
							targetHumanoid:TakeDamage(Config.BaseYetiDamage + math.floor((day - 1) / 8) * Config.DamagePerDay)
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
end)

local function onCharacter(player, character)
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
			profile.coins += reward
			profile.bestDay = math.max(profile.bestDay, day)
			player:SetAttribute("Coins", profile.coins)
			player:SetAttribute("BestDay", profile.bestDay)
			noticeEvent:FireClient(player, "Survived day " .. day .. "! +" .. reward .. " coins")
			task.spawn(saveProfile, player)
		end
	end
end

task.spawn(function()
	while true do
		phase = "Camp"
		secondsLeft = Config.IntermissionSeconds
		if yetisFolder then yetisFolder:ClearAllChildren() end
		notifyAll("The camp is safe... for now.")
		while secondsLeft > 0 do
			campFuel = math.max(0, campFuel - 0.08)
			if campfireFlame then campfireFlame.Transparency = campFuel > 0 and 0 or 0.75 end
			broadcast(); task.wait(1); secondsLeft -= 1
		end

		currentDay += 1
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
		end

		phase = "Yeti Hunt"
		secondsLeft = Config.DayLengthSeconds
		notifyAll("DAY " .. currentDay .. " — THE ICE YETIS ARE HUNTING!")
		local spawnCount = math.clamp(1 + math.floor((currentDay - 1) / 5), 1, 12)
		for i = 1, spawnCount do
			local x = rng:NextInteger(-90, 90)
			local z = rng:NextInteger(-105, 5)
			spawnYeti(currentDay, Vector3.new(x, 0, z))
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
