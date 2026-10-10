-- Server-only, attribute-driven enemy template spawner.
-- Spawn point attributes override defaults; template attributes override type definitions.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local EnemyConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("EnemyConfig"))

local Spawner = {}
local spawnedByRound = {}
local templates = ReplicatedStorage:FindFirstChild(EnemyConfig.TemplateFolderName)
if not templates then
	templates = Instance.new("Folder")
	templates.Name = EnemyConfig.TemplateFolderName
	templates.Parent = ReplicatedStorage
end

local function finiteNumber(value)
	return typeof(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function positiveNumber(value, fallback, minimum, maximum)
	if not finiteNumber(value) or value < minimum then return fallback end
	return math.clamp(value, minimum, maximum)
end

local function getAttribute(source, key, fallback)
	local value = source:GetAttribute(key)
	if value == nil then return fallback end
	return value
end

local function resolveStat(template, enemyType, key)
	local typeConfig = EnemyConfig.Types[enemyType] or {}
	local fallback = typeConfig[key]
	if fallback == nil then fallback = EnemyConfig.Defaults[key] end
	local value = template:GetAttribute(key)
	if value == nil then value = fallback end
	if not finiteNumber(value) then value = fallback end
	return value
end

local function getSpawnCFrame(spawnPoint)
	if spawnPoint:IsA("BasePart") then
		return spawnPoint.CFrame + Vector3.new(0, spawnPoint.Size.Y / 2 + 3, 0)
	elseif spawnPoint:IsA("Model") then
		return spawnPoint:GetPivot() + Vector3.new(0, 3, 0)
	end
	return nil
end

local function validateRig(model)
	if not model:IsA("Model") then return false, "template is not a Model" end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then return false, "template has no Humanoid" end
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then return false, "template has no BasePart HumanoidRootPart" end
	if not model.PrimaryPart then model.PrimaryPart = root end
	return true
end

local function findTemplate(enemyType)
	local found = templates:FindFirstChild(enemyType)
	if found and found:IsA("Model") then return found end
	return nil
end

local function spawnOne(spawnPoint, destination, day)
	local enemyType = getAttribute(spawnPoint, "EnemyType", "Common")
	if typeof(enemyType) ~= "string" or enemyType == "" then
		warn("[EnemySpawner] Invalid EnemyType on " .. spawnPoint:GetFullName())
		return nil
	end
	local template = findTemplate(enemyType)
	if not template then
		warn("[EnemySpawner] No Model named '" .. enemyType .. "' in ReplicatedStorage/" .. EnemyConfig.TemplateFolderName)
		return nil
	end
	local ok, reason = validateRig(template)
	if not ok then
		warn("[EnemySpawner] Invalid template " .. template:GetFullName() .. ": " .. reason)
		return nil
	end

	local clone
	local success, err = pcall(function()
		clone = template:Clone()
		local maxHealth = positiveNumber(resolveStat(template, enemyType, "MaxHealth"), 100, 1, 1000000)
		local damage = positiveNumber(resolveStat(template, enemyType, "Damage"), 10, 0, 100000)
		local level = positiveNumber(resolveStat(template, enemyType, "Level"), 1, 1, 100000)
		local moveSpeed = positiveNumber(resolveStat(template, enemyType, "MoveSpeed"), 12, 0, 1000)
		clone:SetAttribute("EnemyType", enemyType)
		clone:SetAttribute("Level", level)
		clone:SetAttribute("Damage", damage)
		clone:SetAttribute("MaxHealth", maxHealth)
		clone:SetAttribute("MoveSpeed", moveSpeed)
		clone:SetAttribute("IsIceYeti", true)

		local humanoid = clone:FindFirstChildOfClass("Humanoid")
		humanoid.MaxHealth = maxHealth
		humanoid.Health = maxHealth
		humanoid.WalkSpeed = moveSpeed
		humanoid.DisplayName = enemyType
		for _, item in ipairs(clone:GetDescendants()) do
			if item:IsA("BasePart") then
				item.Anchored = false
			end
		end
		clone.Parent = destination
		local targetCFrame = getSpawnCFrame(spawnPoint)
		if not targetCFrame then error("spawn point must be a BasePart or Model") end
		clone:PivotTo(targetCFrame)
		pcall(function() clone:FindFirstChild("HumanoidRootPart"):SetNetworkOwner(nil) end)
	end)
	if not success then
		if clone then clone:Destroy() end
		warn("[EnemySpawner] Spawn failed at " .. spawnPoint:GetFullName() .. ": " .. tostring(err))
		return nil
	end
	return clone
end

function Spawner.HasConfiguredSpawnPoints()
	local folder = Workspace:FindFirstChild(EnemyConfig.SpawnFolderName)
	if not folder then return false end
	for _, point in ipairs(folder:GetChildren()) do
		if (point:IsA("BasePart") or point:IsA("Model")) and point:GetAttribute("SpawnEnabled") ~= false then
			if typeof(point:GetAttribute("EnemyType")) == "string" then return true end
		end
	end
	return false
end

function Spawner.SpawnForDay(day, destination)
	local folder = Workspace:FindFirstChild(EnemyConfig.SpawnFolderName)
	if not folder then return 0 end
	if not finiteNumber(day) then return 0 end
	destination = destination or Workspace:FindFirstChild(EnemyConfig.ActiveFolderName)
	if not destination then
		destination = Instance.new("Folder")
		destination.Name = EnemyConfig.ActiveFolderName
		destination.Parent = Workspace
	end

	-- One spawn pass per day prevents repeated phase updates from duplicating a wave.
	if spawnedByRound[day] then return 0 end
	spawnedByRound[day] = true
	local total = 0
	for _, point in ipairs(folder:GetDescendants()) do
		if point:IsA("BasePart") or point:IsA("Model") then
			local enabled = getAttribute(point, "SpawnEnabled", EnemyConfig.Defaults.SpawnEnabled)
			local minDay = positiveNumber(getAttribute(point, "MinDay", EnemyConfig.Defaults.MinDay), 1, 1, 100000)
			local maxDay = positiveNumber(getAttribute(point, "MaxDay", EnemyConfig.Defaults.MaxDay), 100, minDay, 100000)
			local count = positiveNumber(getAttribute(point, "SpawnCount", EnemyConfig.Defaults.SpawnCount), 1, 1, 100)
			if enabled == true and day >= minDay and day <= maxDay and getSpawnCFrame(point) then
				for _ = 1, math.floor(count) do
					if spawnOne(point, destination, day) then total += 1 end
				end
			end
		end
	end
	return total
end

function Spawner.ClearRound(day)
	if day ~= nil then spawnedByRound[day] = nil else table.clear(spawnedByRound) end
	local folder = Workspace:FindFirstChild(EnemyConfig.ActiveFolderName)
	if folder then folder:ClearAllChildren() end
end

function Spawner.GetTemplateFolder()
	return templates
end

return Spawner
