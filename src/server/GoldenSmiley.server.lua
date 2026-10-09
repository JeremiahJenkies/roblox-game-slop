-- Golden Smiley starter item
-- Rojo maps this Script into ServerScriptService.Server.
-- Spawns a shiny golden emoji with simple 3D eyes and a curved smile.

local Workspace = game:GetService("Workspace")

local existing = Workspace:FindFirstChild("GoldenSmiley")
if existing then
    existing:Destroy()
end

local model = Instance.new("Model")
model.Name = "GoldenSmiley"

local function makePart(name, shape, size, position, color, material)
    local part = Instance.new("Part")
    part.Name = name
    part.Shape = shape
    part.Size = size
    part.Position = position
    part.Color = color
    part.Material = material or Enum.Material.Metal
    part.Anchored = true
    part.CanCollide = false
    part.CastShadow = true
    part.Parent = model
    return part
end

-- Main gold face
local center = Vector3.new(0, 5, 0)
local gold = Color3.fromRGB(255, 190, 25)
local dark = Color3.fromRGB(65, 35, 12)

local face = makePart(
    "GoldenFace",
    Enum.PartType.Ball,
    Vector3.new(3.4, 3.4, 0.75),
    center,
    gold,
    Enum.Material.Metal
)
face.Reflectance = 0.12
model.PrimaryPart = face

-- Soft golden glow
local light = Instance.new("PointLight")
light.Name = "GoldenGlow"
light.Color = Color3.fromRGB(255, 190, 45)
light.Brightness = 1.2
light.Range = 10
light.Parent = face

-- Put face details on the front (-Z)
local frontOffset = -0.39

for _, eye in ipairs({
    {name = "LeftEye", x = -0.62},
    {name = "RightEye", x = 0.62},
}) do
    local part = makePart(
        eye.name,
        Enum.PartType.Ball,
        Vector3.new(0.28, 0.43, 0.12),
        center + Vector3.new(eye.x, 0.42, frontOffset - 0.02),
        dark,
        Enum.Material.SmoothPlastic
    )
end

-- Build a curved smile from small rounded segments.
local smilePoints = {
    {-0.65, -0.25},
    {-0.48, -0.43},
    {-0.25, -0.54},
    {0, -0.58},
    {0.25, -0.54},
    {0.48, -0.43},
    {0.65, -0.25},
}

for i, point in ipairs(smilePoints) do
    makePart(
        "Smile" .. i,
        Enum.PartType.Ball,
        Vector3.new(0.19, 0.19, 0.1),
        center + Vector3.new(point[1], point[2], frontOffset - 0.025),
        dark,
        Enum.Material.SmoothPlastic
    )
end

model.Parent = Workspace
print("Golden Smiley starter item spawned!")
