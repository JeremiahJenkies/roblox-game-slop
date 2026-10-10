--!strict
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local PitchConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("PitchConfig"))

local PitchService = {}
local stadium: Folder? = nil
local function makePart(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?, transparency: number?): Part
    local part = Instance.new("Part")
    part.Name = name
    part.Size = size
    part.CFrame = cframe
    part.Color = color
    part.Material = material or Enum.Material.SmoothPlastic
    part.Transparency = transparency or 0
    part.Anchored = true
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    part.Parent = parent
    return part
end

local function flatLine(parent: Instance, name: string, size: Vector3, x: number, z: number, color: Color3)
    local line = makePart(parent, name, Vector3.new(size.X, PitchConfig.LineHeight, size.Z), CFrame.new(x, PitchConfig.MarkingCenterY, z), color, Enum.Material.SmoothPlastic)
    line.CanCollide = false
    line.CastShadow = false
    return line
end

local function segment(parent: Instance, name: string, a: Vector3, b: Vector3, color: Color3)
    local delta = b - a
    local length = delta.Magnitude
    if length <= 0.01 then return end
    local midpoint = (a + b) / 2
    local part = makePart(parent, name, Vector3.new(PitchConfig.LineThickness, PitchConfig.LineHeight, length + PitchConfig.LineThickness * 0.5), CFrame.lookAt(midpoint, b), color, Enum.Material.SmoothPlastic)
    part.CanCollide = false
    part.CastShadow = false
    return part
end

local function arc(parent: Instance, name: string, cx: number, cz: number, radius: number, startAngle: number, endAngle: number, steps: number, color: Color3)
    local last: Vector3? = nil
    for index = 0, steps do
        local angle = math.rad(startAngle + (endAngle - startAngle) * (index / steps))
        local current = Vector3.new(cx + math.cos(angle) * radius, PitchConfig.CircleMarkingCenterY, cz + math.sin(angle) * radius)
        if last then segment(parent, name .. "_" .. tostring(index), last, current, color) end
        last = current
    end
end

local function makeMarker(parent: Instance, name: string, position: Vector3, purpose: string, teamName: string?)
    local marker = makePart(parent, name, Vector3.new(2, 0.2, 2), CFrame.new(position), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, 1)
    marker.CanCollide = false
    marker.CanTouch = false
    marker.CanQuery = false
    marker:SetAttribute("IsPositionMarker", true)
    marker:SetAttribute("Purpose", purpose)
    if teamName then marker:SetAttribute("Team", teamName) end
    return marker
end

local function buildGoal(parent: Instance, teamName: string, sign: number, halfLength: number)
    local goal = Instance.new("Model")
    goal.Name = "Goal" .. teamName
    goal:SetAttribute("DefendingTeam", teamName)
    goal.Parent = parent
    local halfGoal = PitchConfig.GoalWidth / 2
    local z = sign * halfLength
    local postSize = PitchConfig.GoalPostThickness
    local pitchTop = PitchConfig.SurfaceCenterY + PitchConfig.SurfaceThickness / 2
    local postColor = Color3.fromRGB(242, 245, 241)
    for _, x in ipairs({-halfGoal, halfGoal}) do
        makePart(goal, "GoalPost", Vector3.new(postSize, PitchConfig.GoalHeight, postSize), CFrame.new(x, pitchTop + PitchConfig.GoalHeight / 2, z), postColor, Enum.Material.Metal)
    end
    makePart(goal, "Crossbar", Vector3.new(PitchConfig.GoalWidth + postSize, postSize, postSize), CFrame.new(0, pitchTop + PitchConfig.GoalHeight, z), postColor, Enum.Material.Metal)
    local backZ = z + sign * PitchConfig.GoalDepth
    for _, x in ipairs({-halfGoal, halfGoal}) do
        local sideNet = makePart(goal, "GoalNetSide", Vector3.new(0.18, PitchConfig.GoalHeight, PitchConfig.GoalDepth), CFrame.new(x, pitchTop + PitchConfig.GoalHeight / 2, z + sign * PitchConfig.GoalDepth / 2), Color3.fromRGB(202, 215, 219), Enum.Material.Fabric, PitchConfig.GoalNetTransparency)
        sideNet.CanCollide = true
        sideNet.CanTouch = false
        sideNet.CanQuery = true
    end
    local rearNet = makePart(goal, "GoalNetBack", Vector3.new(PitchConfig.GoalWidth, PitchConfig.GoalHeight, 0.18), CFrame.new(0, pitchTop + PitchConfig.GoalHeight / 2, backZ), Color3.fromRGB(202, 215, 219), Enum.Material.Fabric, PitchConfig.GoalNetTransparency)
    rearNet.CanCollide = true
    rearNet.CanTouch = false
    rearNet.CanQuery = true
    -- The nets are collidable so shots stop inside the goal; scoring uses swept goal-plane detection in BallService.
    local trigger = makePart(goal, "GoalPlaneMarker", Vector3.new(PitchConfig.GoalWidth - 0.5, PitchConfig.GoalHeight - 0.5, 0.25), CFrame.new(0, pitchTop + PitchConfig.GoalHeight / 2, z + sign * 0.25), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, 1)
    trigger.CanCollide = false
    trigger.CanTouch = false
    trigger:SetAttribute("GoalPlane", true)
    trigger:SetAttribute("DefendingTeam", teamName)
    return goal
end

local function configureLighting()
    -- Technology is configured in Studio, not by a runtime Script.
    Lighting.GlobalShadows = true
    Lighting.ClockTime = 16.25
    Lighting.Brightness = 2.2
    Lighting.EnvironmentDiffuseScale = 0.8
    Lighting.EnvironmentSpecularScale = 0.8
    Lighting.Ambient = Color3.fromRGB(112, 125, 140)
    Lighting.OutdoorAmbient = Color3.fromRGB(128, 143, 153)
    Lighting.FogStart = 650
    Lighting.FogEnd = 1500
    Lighting.FogColor = Color3.fromRGB(177, 207, 228)
    local atmosphere = Lighting:FindFirstChild("SoccerAtmosphere") or Instance.new("Atmosphere")
    atmosphere.Name = "SoccerAtmosphere"
    atmosphere.Density = 0.16
    atmosphere.Offset = 0.12
    atmosphere.Color = Color3.fromRGB(199, 218, 235)
    atmosphere.Decay = Color3.fromRGB(115, 141, 160)
    atmosphere.Haze = 0.65
    atmosphere.Glare = 0.12
    atmosphere.Parent = Lighting
    local bloom = Lighting:FindFirstChild("SoccerBloom") or Instance.new("BloomEffect")
    bloom.Name = "SoccerBloom"; bloom.Intensity = 0.12; bloom.Size = 18; bloom.Threshold = 1.4; bloom.Parent = Lighting
    local grade = Lighting:FindFirstChild("SoccerColorGrade") or Instance.new("ColorCorrectionEffect")
    grade.Name = "SoccerColorGrade"; grade.Brightness = 0.01; grade.Contrast = 0.08; grade.Saturation = 0.08; grade.TintColor = Color3.fromRGB(245, 250, 255); grade.Parent = Lighting
    local sunRays = Lighting:FindFirstChild("SoccerSunRays") or Instance.new("SunRaysEffect")
    sunRays.Name = "SoccerSunRays"; sunRays.Intensity = 0.035; sunRays.Spread = 0.7; sunRays.Parent = Lighting
    local sky = Lighting:FindFirstChild("SoccerSky") or Instance.new("Sky")
    sky.Name = "SoccerSky"; sky.CelestialBodiesShown = true; sky.StarCount = 0; sky.SunAngularSize = 12; sky.Parent = Lighting
    local clouds = Workspace.Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
    clouds.Cover = 0.28; clouds.Density = 0.32; clouds.Color = Color3.fromRGB(237, 243, 249); clouds.Parent = Workspace.Terrain
end

function PitchService.Build()
    Workspace:SetAttribute("PitchReady", false)
    local existing = Workspace:FindFirstChild("SoccerStadium")
    if existing then existing:Destroy() end
    local baseplate = Workspace:FindFirstChild("Baseplate")
    if baseplate and baseplate:IsA("BasePart") then baseplate:Destroy() end
    stadium = Instance.new("Folder")
    stadium.Name = "SoccerStadium"
    stadium:SetAttribute("PitchWidth", PitchConfig.Width)
    stadium:SetAttribute("PitchLength", PitchConfig.Length)
    stadium:SetAttribute("PitchReady", false)
    stadium.Parent = Workspace
    configureLighting()

    local width, length = PitchConfig.Width, PitchConfig.Length
    local halfWidth, halfLength = width / 2, length / 2
    local grass = Color3.fromRGB(40, 112, 65)
    local lineColor = Color3.fromRGB(235, 240, 229)
    local turf = makePart(stadium, "PitchSurface", Vector3.new(width, PitchConfig.SurfaceThickness, length), CFrame.new(0, PitchConfig.SurfaceCenterY, 0), grass, Enum.Material.Grass)
    turf:SetAttribute("GameplaySurface", true)
    turf.CastShadow = false
    makePart(stadium, "StadiumGround", Vector3.new(width + PitchConfig.GroundMargin * 2, PitchConfig.GroundThickness, length + PitchConfig.GroundMargin * 2), CFrame.new(0, PitchConfig.SurfaceCenterY - PitchConfig.SurfaceThickness / 2 - PitchConfig.GroundThickness / 2, 0), Color3.fromRGB(49, 70, 53), Enum.Material.Grass)

    -- Alternating turf bands create a visible mowing pattern without heavy textures.
    for band = 1, PitchConfig.MowingStripeCount do
        local bandLength = length / PitchConfig.MowingStripeCount
        local z = -halfLength + (band - 0.5) * bandLength
        local bandPart = makePart(stadium, "MowingStripe", Vector3.new(width - 1, PitchConfig.MowingStripeThickness, bandLength), CFrame.new(0, PitchConfig.MowingStripeSurfaceY, z), band % 2 == 0 and Color3.fromRGB(44, 124, 71) or Color3.fromRGB(36, 104, 59), Enum.Material.Grass)
        bandPart.CanCollide = false; bandPart.CastShadow = false
    end

    -- Core field markings.
    flatLine(stadium, "TouchlineWest", Vector3.new(PitchConfig.LineThickness, 0, length), -halfWidth, 0, lineColor)
    flatLine(stadium, "TouchlineEast", Vector3.new(PitchConfig.LineThickness, 0, length), halfWidth, 0, lineColor)
    flatLine(stadium, "GoalLineNorth", Vector3.new(width, 0, PitchConfig.LineThickness), 0, -halfLength, lineColor)
    flatLine(stadium, "GoalLineSouth", Vector3.new(width, 0, PitchConfig.LineThickness), 0, halfLength, lineColor)
    flatLine(stadium, "HalfwayLine", Vector3.new(width, 0, PitchConfig.LineThickness), 0, 0, lineColor)
    arc(stadium, "CentreCircle", 0, 0, PitchConfig.CentreCircleRadius, 0, 360, PitchConfig.CentreCircleSegments, lineColor)
    local centreSpot = makePart(stadium, "CentreSpot", Vector3.new(PitchConfig.CentreSpotRadius * 2, PitchConfig.SpotThickness, PitchConfig.CentreSpotRadius * 2), CFrame.new(0, PitchConfig.SpotCenterY, 0), lineColor, Enum.Material.SmoothPlastic)
    centreSpot.Shape = Enum.PartType.Ball; centreSpot.CanCollide = false

    local function drawBox(name: string, sign: number, boxWidth: number, depth: number)
        local innerZ = sign * (halfLength - depth)
        flatLine(stadium, name .. "Inner", Vector3.new(boxWidth, 0, PitchConfig.LineThickness), 0, innerZ, lineColor)
        flatLine(stadium, name .. "Left", Vector3.new(PitchConfig.LineThickness, 0, depth), -boxWidth / 2, sign * (halfLength - depth / 2), lineColor)
        flatLine(stadium, name .. "Right", Vector3.new(PitchConfig.LineThickness, 0, depth), boxWidth / 2, sign * (halfLength - depth / 2), lineColor)
        local spotZ = sign * (halfLength - PitchConfig.PenaltySpotDepth)
        if name == "PenaltyArea" then
            local spot = makePart(stadium, "PenaltySpot", Vector3.new(PitchConfig.PenaltySpotRadius * 2, PitchConfig.SpotThickness, PitchConfig.PenaltySpotRadius * 2), CFrame.new(0, PitchConfig.SpotCenterY, spotZ), lineColor, Enum.Material.SmoothPlastic)
            spot.Shape = Enum.PartType.Ball; spot.CanCollide = false
            arc(stadium, "PenaltyArc", 0, spotZ, PitchConfig.PenaltyArcRadius, sign == 1 and 205 or 25, sign == 1 and 335 or 155, PitchConfig.PenaltyArcSegments, lineColor)
        end
        return
    end
    drawBox("PenaltyArea", -1, PitchConfig.PenaltyAreaWidth, PitchConfig.PenaltyAreaDepth)
    drawBox("PenaltyArea", 1, PitchConfig.PenaltyAreaWidth, PitchConfig.PenaltyAreaDepth)
    drawBox("GoalArea", -1, PitchConfig.GoalAreaWidth, PitchConfig.GoalAreaDepth)
    drawBox("GoalArea", 1, PitchConfig.GoalAreaWidth, PitchConfig.GoalAreaDepth)
    for _, xSign in ipairs({-1, 1}) do
        for _, zSign in ipairs({-1, 1}) do
            local cx, cz = xSign * halfWidth, zSign * halfLength
            local startAngle = xSign == -1 and (zSign == -1 and 0 or 270) or (zSign == -1 and 90 or 180)
            arc(stadium, "CornerArc", cx, cz, PitchConfig.CornerArcRadius, startAngle, startAngle + 90, PitchConfig.CornerArcSegments, lineColor)
        end
    end

    -- Goals and hidden position markers for later services.
    buildGoal(stadium, "Red", -1, halfLength)
    buildGoal(stadium, "Blue", 1, halfLength)
    makeMarker(stadium, "TeamASpawn", Vector3.new(0, PitchConfig.MarkerY, -PitchConfig.SpawnInset), "Team A spawn", "Red")
    makeMarker(stadium, "TeamBSpawn", Vector3.new(0, PitchConfig.MarkerY, PitchConfig.SpawnInset), "Team B spawn", "Blue")
    makeMarker(stadium, "KickoffSpot", Vector3.new(0, PitchConfig.MarkerY, 0), "Kickoff")
    makeMarker(stadium, "BallSpawn", Vector3.new(0, PitchConfig.BallMarkerY, 0), "Ball spawn")

    -- Invisible containment barriers sit just beyond the out-of-bounds detection zones.
    -- Keep a gap after the restart threshold so BallService can award throw-ins, corners and goal kicks first.
    local wallColor = Color3.fromRGB(30, 39, 48)
    local wallHeight, wallThickness = PitchConfig.BoundaryHeight, PitchConfig.BoundaryThickness
    local sideDetectionLimit = halfWidth + radius + 0.5
    local endDetectionLimit = halfLength + PitchConfig.GoalDepth + radius + 2
    local sideWallX = sideDetectionLimit + wallThickness / 2 + 3
    local endWallZ = endDetectionLimit + wallThickness / 2 + 3
    for _, xSign in ipairs({-1, 1}) do
        makePart(stadium, "InvisibleSideBoundary", Vector3.new(wallThickness, wallHeight, length + 2 * PitchConfig.GoalDepth + 20),
            CFrame.new(xSign * sideWallX, wallHeight / 2, 0), wallColor, Enum.Material.SmoothPlastic, 1)
    end
    for _, zSign in ipairs({-1, 1}) do
        makePart(stadium, "InvisibleEndBoundary", Vector3.new(width + 2 * PitchConfig.GoalDepth + 20, wallHeight, wallThickness),
            CFrame.new(0, wallHeight / 2, zSign * endWallZ), wallColor, Enum.Material.SmoothPlastic, 1)
    end

    if PitchConfig.DecorativePartsEnabled then
        -- Long-side stands are built as actual stepped seating, not a solid block that hides its rows.
        for _, side in ipairs({-1, 1}) do
            for row = 1, PitchConfig.StandRows do
                local x = side * (halfWidth + PitchConfig.StandFirstRowOffset + (row - 1) * PitchConfig.StandHorizontalSpacing)
                local rowY = row * PitchConfig.StandVerticalSpacing
                local rowColor = row % 2 == 0 and Color3.fromRGB(175, 54, 60) or Color3.fromRGB(63, 100, 139)
                local seats = makePart(stadium, "StandTier", Vector3.new(PitchConfig.StandRowDepth, PitchConfig.StandRowThickness, length + PitchConfig.StandEndOverhang), CFrame.new(x, rowY, 0), rowColor, Enum.Material.Metal)
                seats.CastShadow = true
                local supportHeight = math.max(0.1, rowY - (PitchConfig.SurfaceCenterY + PitchConfig.SurfaceThickness / 2))
                for _, zSign in ipairs({-1, 1}) do
                    local supportZ = zSign * (halfLength + PitchConfig.StandEndOverhang / 2 - 4)
                    makePart(stadium, "StandTierSupport", Vector3.new(PitchConfig.StandSupportThickness, supportHeight, PitchConfig.StandSupportThickness), CFrame.new(x, PitchConfig.SurfaceCenterY + PitchConfig.SurfaceThickness / 2 + supportHeight / 2, supportZ), Color3.fromRGB(53, 65, 76), Enum.Material.Metal)
                end
            end
            local lastRowX = halfWidth + PitchConfig.StandFirstRowOffset + (PitchConfig.StandRows - 1) * PitchConfig.StandHorizontalSpacing
            local backWallX = side * (lastRowX + PitchConfig.StandRowDepth / 2 + 3)
            local wallHeight = PitchConfig.StandRows * PitchConfig.StandVerticalSpacing + 2
            makePart(stadium, "StandBackWall", Vector3.new(PitchConfig.StandSupportThickness, wallHeight, length + PitchConfig.StandEndOverhang), CFrame.new(backWallX, wallHeight / 2, 0), Color3.fromRGB(42, 52, 63), Enum.Material.Metal)
        end
        -- End stands step away from the goal nets and include visible support posts.
        local endStandWidth = width - PitchConfig.EndStandWidthInset
        for _, sign in ipairs({-1, 1}) do
            for row = 1, PitchConfig.EndStandRows do
                local z = sign * (halfLength + PitchConfig.EndStandFirstRowOffset + (row - 1) * PitchConfig.EndStandZSpacing)
                local rowY = row * PitchConfig.EndStandVerticalSpacing
                local rowColor = row % 2 == 0 and Color3.fromRGB(175, 54, 60) or Color3.fromRGB(63, 100, 139)
                makePart(stadium, "EndStandTier", Vector3.new(endStandWidth, PitchConfig.EndStandRowThickness, PitchConfig.EndStandRowDepth), CFrame.new(0, rowY, z), rowColor, Enum.Material.Metal)
                local supportHeight = math.max(0.1, rowY - (PitchConfig.SurfaceCenterY + PitchConfig.SurfaceThickness / 2))
                for _, xSign in ipairs({-1, 1}) do
                    local supportX = xSign * (endStandWidth / 2 - PitchConfig.EndStandSupportInset)
                    makePart(stadium, "EndStandTierSupport", Vector3.new(PitchConfig.StandSupportThickness, supportHeight, PitchConfig.StandSupportThickness), CFrame.new(supportX, PitchConfig.SurfaceCenterY + PitchConfig.SurfaceThickness / 2 + supportHeight / 2, z), Color3.fromRGB(53, 65, 76), Enum.Material.Metal)
                end
            end
            local backWallZ = sign * (halfLength + PitchConfig.EndStandBackwallOffset)
            local wallHeight = PitchConfig.EndStandRows * PitchConfig.EndStandVerticalSpacing + 2
            makePart(stadium, "EndStandBackWall", Vector3.new(endStandWidth, wallHeight, PitchConfig.StandSupportThickness), CFrame.new(0, wallHeight / 2, backWallZ), Color3.fromRGB(42, 52, 63), Enum.Material.Metal)
        end
        for _, xSign in ipairs({-1, 1}) do
            for _, zSign in ipairs({-1, 1}) do
                local x = xSign * (halfWidth + PitchConfig.StandOffset + 8)
                local z = zSign * (halfLength + 8)
                makePart(stadium, "FloodlightPole", Vector3.new(1.4, PitchConfig.FloodlightHeight, 1.4), CFrame.new(x, PitchConfig.FloodlightHeight / 2, z), Color3.fromRGB(55, 66, 78), Enum.Material.Metal)
                local rig = makePart(stadium, "FloodlightRig", Vector3.new(PitchConfig.FloodlightWidth, 1.2, PitchConfig.FloodlightDepth), CFrame.new(x, PitchConfig.FloodlightHeight, z), Color3.fromRGB(43, 52, 63), Enum.Material.Metal)
                local light = Instance.new("PointLight")
                light.Name = "Floodlight"; light.Color = Color3.fromRGB(227, 239, 255); light.Brightness = PitchConfig.FloodlightBrightness; light.Range = PitchConfig.FloodlightRange; light.Shadows = true; light.Parent = rig
            end
        end
    end

    stadium:SetAttribute("PitchReady", true)
    Workspace:SetAttribute("PitchReady", true)
    print("[PITCH] Pitch generated: " .. tostring(width) .. " x " .. tostring(length) .. " studs; goals, markings, spawns and stands are ready.")
    return stadium
end

function PitchService.GetStadium(): Folder?
    return stadium
end

function PitchService.Init()
    PitchService.Build()
end

return PitchService