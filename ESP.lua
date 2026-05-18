--[[
    Advanced ESP Library for Roblox
    Features:
    - 2D Box & Corner Box ESP
    - Tracer to bottom middle of box
    - Health bar, Name, Distance, Skeleton
    - Team check & Wall check
    - Fully customizable settings
    - Clean and optimized
]]

local ESPLib = {}

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Bone connections for skeleton
local bones = {
    {"Head", "UpperTorso"},
    {"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
    {"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"}, {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "LowerTorso"},
    {"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"}, {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"}
}

-- Default Settings
local ESP_SETTINGS = {
    Enabled = false,
    -- Box settings
    ShowBox = false,
    BoxType = "2D", -- "2D" or "Corner"
    BoxColor = Color3.new(1, 1, 1),
    BoxOutlineColor = Color3.new(0, 0, 0),
    -- Name
    ShowName = false,
    NameColor = Color3.new(1, 1, 1),
    -- Health
    ShowHealth = false,
    HealthHighColor = Color3.new(0, 1, 0),
    HealthLowColor = Color3.new(1, 0, 0),
    HealthOutlineColor = Color3.new(0, 0, 0),
    -- Distance
    ShowDistance = false,
    -- Skeleton
    ShowSkeletons = false,
    SkeletonsColor = Color3.new(1, 1, 1),
    -- Tracer
    ShowTracer = false,
    TracerColor = Color3.new(1, 1, 1),
    TracerThickness = 2,
    TracerPosition = "Bottom", -- "Top", "Middle", "Bottom"
    -- Filters
    Teamcheck = false,
    WallCheck = false,
}

-- Cache for player ESP objects
local espCache = {}

-- Helper: Create a Drawing object with properties
local function createDrawing(class, properties)
    local drawing = Drawing.new(class)
    for prop, val in pairs(properties) do
        drawing[prop] = val
    end
    return drawing
end

-- Helper: Check if player is behind a wall (modern raycast)
local function isPlayerBehindWall(player)
    local character = player.Character
    if not character then return false end
    
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return false end
    
    local origin = camera.CFrame.Position
    local direction = (rootPart.Position - origin).Unit * (rootPart.Position - origin).Magnitude
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = {localPlayer.Character, character}
    
    local result = workspace:Raycast(origin, direction, raycastParams)
    return result and result.Instance:IsA("Part") or result and result.Instance:IsA("MeshPart")
end

-- Create ESP drawings for a new player
local function createEsp(player)
    local esp = {
        -- Box (2D)
        box = createDrawing("Square", {Color = ESP_SETTINGS.BoxColor, Thickness = 1, Filled = false, Visible = false}),
        boxOutline = createDrawing("Square", {Color = ESP_SETTINGS.BoxOutlineColor, Thickness = 3, Filled = false, Visible = false}),
        -- Corner box lines (up to 16)
        boxLines = {},
        -- Name
        name = createDrawing("Text", {Color = ESP_SETTINGS.NameColor, Outline = true, Center = true, Size = 13, Visible = false}),
        -- Health bar (vertical line on left)
        healthOutline = createDrawing("Line", {Thickness = 3, Color = ESP_SETTINGS.HealthOutlineColor, Visible = false}),
        health = createDrawing("Line", {Thickness = 2, Visible = false}),
        -- Distance
        distance = createDrawing("Text", {Color = Color3.new(1,1,1), Size = 12, Outline = true, Center = true, Visible = false}),
        -- Tracer (single line)
        tracer = createDrawing("Line", {Thickness = ESP_SETTINGS.TracerThickness, Color = ESP_SETTINGS.TracerColor, Transparency = 1, Visible = false}),
        -- Skeleton lines
        skeletonLines = {},
    }
    espCache[player] = esp
end

-- Remove ESP for a leaving player
local function removeEsp(player)
    local esp = espCache[player]
    if not esp then return end
    
    -- Remove all drawings
    esp.box:Remove()
    esp.boxOutline:Remove()
    esp.name:Remove()
    esp.healthOutline:Remove()
    esp.health:Remove()
    esp.distance:Remove()
    esp.tracer:Remove()
    for _, line in ipairs(esp.boxLines) do line:Remove() end
    for _, lineData in ipairs(esp.skeletonLines) do lineData[1]:Remove() end
    
    espCache[player] = nil
end

-- Update ESP for all players each frame
local function updateEsp()
    for player, esp in pairs(espCache) do
        local character = player.Character
        local humanoid = character and character:FindFirstChild("Humanoid")
        local rootPart = character and character:FindFirstChild("HumanoidRootPart")
        local head = character and character:FindFirstChild("Head")
        
        -- Visibility conditions
        local isValid = character and humanoid and rootPart and head
        local isTeammate = ESP_SETTINGS.Teamcheck and player.Team == localPlayer.Team
        local isBehindWall = ESP_SETTINGS.WallCheck and isPlayerBehindWall(player)
        local shouldRender = ESP_SETTINGS.Enabled and isValid and not isTeammate and not isBehindWall
        
        if shouldRender then
            -- Get screen position and box dimensions
            local hrpPos, onScreen = camera:WorldToViewportPoint(rootPart.Position)
            if not onScreen then
                -- Hide everything if off-screen
                esp.box.Visible = false; esp.boxOutline.Visible = false; esp.name.Visible = false
                esp.healthOutline.Visible = false; esp.health.Visible = false; esp.distance.Visible = false
                esp.tracer.Visible = false
                for _, line in ipairs(esp.boxLines) do line.Visible = false end
                for _, lineData in ipairs(esp.skeletonLines) do lineData[1].Visible = false end
                goto continue
            end
            
            -- Compute box size and position
            local bottomY = camera:WorldToViewportPoint(rootPart.Position - Vector3.new(0, 3, 0)).Y
            local topY = camera:WorldToViewportPoint(rootPart.Position + Vector3.new(0, 2.6, 0)).Y
            local charHeight = (bottomY - topY) / 2
            local boxSize = Vector2.new(math.floor(charHeight * 1.8), math.floor(charHeight * 1.9))
            local boxPos = Vector2.new(math.floor(hrpPos.X - charHeight * 1.8 / 2), math.floor(hrpPos.Y - charHeight * 1.6 / 2))
            
            -- ----- BOX RENDERING (2D or Corner) -----
            if ESP_SETTINGS.ShowBox then
                if ESP_SETTINGS.BoxType == "2D" then
                    -- Hide corner lines if any
                    for _, line in ipairs(esp.boxLines) do line.Visible = false end
                    -- Update and show standard boxes
                    esp.box.Position = boxPos
                    esp.box.Size = boxSize
                    esp.box.Color = ESP_SETTINGS.BoxColor
                    esp.box.Visible = true
                    esp.boxOutline.Position = boxPos
                    esp.boxOutline.Size = boxSize
                    esp.boxOutline.Visible = true
                elseif ESP_SETTINGS.BoxType == "Corner" then
                    -- Hide standard boxes
                    esp.box.Visible = false
                    esp.boxOutline.Visible = false
                    -- Create corner lines if not exist
                    if #esp.boxLines == 0 then
                        for i = 1, 16 do
                            local line = createDrawing("Line", {Thickness = 2, Color = ESP_SETTINGS.BoxColor, Transparency = 1})
                            table.insert(esp.boxLines, line)
                        end
                    end
                    -- Calculate corner dimensions
                    local lineW = boxSize.X / 5
                    local lineH = boxSize.Y / 6
                    local lines = esp.boxLines
                    -- Top left
                    lines[1].From = Vector2.new(boxPos.X - 1, boxPos.Y - 1)
                    lines[1].To = Vector2.new(boxPos.X + lineW, boxPos.Y - 1)
                    lines[2].From = Vector2.new(boxPos.X - 1, boxPos.Y - 1)
                    lines[2].To = Vector2.new(boxPos.X - 1, boxPos.Y + lineH)
                    -- Top right
                    lines[3].From = Vector2.new(boxPos.X + boxSize.X - lineW, boxPos.Y - 1)
                    lines[3].To = Vector2.new(boxPos.X + boxSize.X + 1, boxPos.Y - 1)
                    lines[4].From = Vector2.new(boxPos.X + boxSize.X + 1, boxPos.Y - 1)
                    lines[4].To = Vector2.new(boxPos.X + boxSize.X + 1, boxPos.Y + lineH)
                    -- Bottom left
                    lines[5].From = Vector2.new(boxPos.X - 1, boxPos.Y + boxSize.Y - lineH)
                    lines[5].To = Vector2.new(boxPos.X - 1, boxPos.Y + boxSize.Y + 1)
                    lines[6].From = Vector2.new(boxPos.X - 1, boxPos.Y + boxSize.Y + 1)
                    lines[6].To = Vector2.new(boxPos.X + lineW, boxPos.Y + boxSize.Y + 1)
                    -- Bottom right
                    lines[7].From = Vector2.new(boxPos.X + boxSize.X - lineW, boxPos.Y + boxSize.Y + 1)
                    lines[7].To = Vector2.new(boxPos.X + boxSize.X + 1, boxPos.Y + boxSize.Y + 1)
                    lines[8].From = Vector2.new(boxPos.X + boxSize.X + 1, boxPos.Y + boxSize.Y - lineH)
                    lines[8].To = Vector2.new(boxPos.X + boxSize.X + 1, boxPos.Y + boxSize.Y + 1)
                    -- Inner lines (thinner)
                    for i = 9, 16 do
                        lines[i].Thickness = 1
                        lines[i].Color = ESP_SETTINGS.BoxOutlineColor
                    end
                    lines[9].From = Vector2.new(boxPos.X, boxPos.Y)
                    lines[9].To = Vector2.new(boxPos.X, boxPos.Y + lineH)
                    lines[10].From = Vector2.new(boxPos.X, boxPos.Y)
                    lines[10].To = Vector2.new(boxPos.X + lineW, boxPos.Y)
                    lines[11].From = Vector2.new(boxPos.X + boxSize.X - lineW, boxPos.Y)
                    lines[11].To = Vector2.new(boxPos.X + boxSize.X, boxPos.Y)
                    lines[12].From = Vector2.new(boxPos.X + boxSize.X, boxPos.Y)
                    lines[12].To = Vector2.new(boxPos.X + boxSize.X, boxPos.Y + lineH)
                    lines[13].From = Vector2.new(boxPos.X, boxPos.Y + boxSize.Y - lineH)
                    lines[13].To = Vector2.new(boxPos.X, boxPos.Y + boxSize.Y)
                    lines[14].From = Vector2.new(boxPos.X, boxPos.Y + boxSize.Y)
                    lines[14].To = Vector2.new(boxPos.X + lineW, boxPos.Y + boxSize.Y)
                    lines[15].From = Vector2.new(boxPos.X + boxSize.X - lineW, boxPos.Y + boxSize.Y)
                    lines[15].To = Vector2.new(boxPos.X + boxSize.X, boxPos.Y + boxSize.Y)
                    lines[16].From = Vector2.new(boxPos.X + boxSize.X, boxPos.Y + boxSize.Y - lineH)
                    lines[16].To = Vector2.new(boxPos.X + boxSize.X, boxPos.Y + boxSize.Y)
                    -- Show all corner lines
                    for _, line in ipairs(lines) do line.Visible = true end
                end
            else
                -- Hide all box elements
                esp.box.Visible = false
                esp.boxOutline.Visible = false
                for _, line in ipairs(esp.boxLines) do line.Visible = false end
            end
            
            -- ----- NAME -----
            if ESP_SETTINGS.ShowName then
                esp.name.Text = string.lower(player.Name)
                esp.name.Position = Vector2.new(boxPos.X + boxSize.X/2, boxPos.Y - 16)
                esp.name.Color = ESP_SETTINGS.NameColor
                esp.name.Visible = true
            else
                esp.name.Visible = false
            end
            
            -- ----- HEALTH BAR -----
            if ESP_SETTINGS.ShowHealth and humanoid then
                local healthPercent = humanoid.Health / humanoid.MaxHealth
                local barX = boxPos.X - 6
                local barTop = boxPos.Y
                local barBottom = boxPos.Y + boxSize.Y
                esp.healthOutline.From = Vector2.new(barX, barBottom)
                esp.healthOutline.To = Vector2.new(barX, barTop)
                esp.healthOutline.Visible = true
                esp.health.From = Vector2.new(barX + 1, barBottom)
                esp.health.To = Vector2.new(barX + 1, barBottom - (boxSize.Y * healthPercent))
                esp.health.Color = ESP_SETTINGS.HealthLowColor:Lerp(ESP_SETTINGS.HealthHighColor, healthPercent)
                esp.health.Visible = true
            else
                esp.healthOutline.Visible = false
                esp.health.Visible = false
            end
            
            -- ----- DISTANCE -----
            if ESP_SETTINGS.ShowDistance then
                local dist = (camera.CFrame.Position - rootPart.Position).Magnitude
                esp.distance.Text = string.format("%.1f", dist) .. " studs"
                esp.distance.Position = Vector2.new(boxPos.X + boxSize.X/2, boxPos.Y + boxSize.Y + 5)
                esp.distance.Visible = true
            else
                esp.distance.Visible = false
            end
            
            -- ----- SKELETON -----
            if ESP_SETTINGS.ShowSkeletons then
                -- Create skeleton lines if needed
                if #esp.skeletonLines == 0 then
                    for _, bonePair in ipairs(bones) do
                        local line = createDrawing("Line", {Thickness = 1, Color = ESP_SETTINGS.SkeletonsColor, Transparency = 1})
                        table.insert(esp.skeletonLines, {line, bonePair[1], bonePair[2]})
                    end
                end
                -- Update each bone line
                for _, lineData in ipairs(esp.skeletonLines) do
                    local line, partA, partB = lineData[1], lineData[2], lineData[3]
                    local boneA = character:FindFirstChild(partA)
                    local boneB = character:FindFirstChild(partB)
                    if boneA and boneB then
                        local posA = camera:WorldToViewportPoint(boneA.Position)
                        local posB = camera:WorldToViewportPoint(boneB.Position)
                        line.From = Vector2.new(posA.X, posA.Y)
                        line.To = Vector2.new(posB.X, posB.Y)
                        line.Color = ESP_SETTINGS.SkeletonsColor
                        line.Visible = true
                    else
                        line.Visible = false
                    end
                end
            else
                for _, lineData in ipairs(esp.skeletonLines) do
                    lineData[1].Visible = false
                end
            end
            
            -- ----- TRACER (to bottom middle of box) -----
            if ESP_SETTINGS.ShowTracer then
                -- Origin point based on TracerPosition setting
                local originY
                if ESP_SETTINGS.TracerPosition == "Top" then
                    originY = 0
                elseif ESP_SETTINGS.TracerPosition == "Middle" then
                    originY = camera.ViewportSize.Y / 2
                else -- Bottom
                    originY = camera.ViewportSize.Y
                end
                local origin = Vector2.new(camera.ViewportSize.X / 2, originY)
                -- Target: bottom middle of the ESP box
                local target = Vector2.new(boxPos.X + boxSize.X / 2, boxPos.Y + boxSize.Y)
                esp.tracer.From = origin
                esp.tracer.To = target
                esp.tracer.Color = ESP_SETTINGS.TracerColor
                esp.tracer.Thickness = ESP_SETTINGS.TracerThickness
                esp.tracer.Visible = true
            else
                esp.tracer.Visible = false
            end
            
        else
            -- Player not visible or ESP disabled -> hide everything
            esp.box.Visible = false
            esp.boxOutline.Visible = false
            esp.name.Visible = false
            esp.healthOutline.Visible = false
            esp.health.Visible = false
            esp.distance.Visible = false
            esp.tracer.Visible = false
            for _, line in ipairs(esp.boxLines) do line.Visible = false end
            for _, lineData in ipairs(esp.skeletonLines) do lineData[1].Visible = false end
        end
        
        ::continue::
    end
end

-- Initialize ESP for all existing players and set up connections
local function init()
    -- Create ESP for all other players
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            createEsp(player)
        end
    end
    
    -- Connect events
    Players.PlayerAdded:Connect(function(player)
        if player ~= localPlayer then
            createEsp(player)
        end
    end)
    
    Players.PlayerRemoving:Connect(removeEsp)
    RunService.RenderStepped:Connect(updateEsp)
end

-- Public API: Get/Set settings
function ESPLib.GetSettings()
    return ESP_SETTINGS
end

function ESPLib.SetSettings(newSettings)
    for k, v in pairs(newSettings) do
        ESP_SETTINGS[k] = v
    end
end

function ESPLib.Toggle()
    ESP_SETTINGS.Enabled = not ESP_SETTINGS.Enabled
end

function ESPLib.Start()
    init()
end

-- For loadstring compatibility: auto-start but also return API
ESPLib.Start()

return ESPLib
