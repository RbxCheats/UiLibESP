--[[
    ██╗   ██╗██╗  ████████╗██╗███╗   ███╗ █████╗ ████████╗███████╗
    ██║   ██║██║  ╚══██╔══╝██║████╗ ████║██╔══██╗╚══██╔══╝██╔════╝
    ██║   ██║██║     ██║   ██║██╔████╔██║███████║   ██║   █████╗  
    ██║   ██║██║     ██║   ██║██║╚██╔╝██║██╔══██║   ██║   ██╔══╝  
    ╚██████╔╝███████╗██║   ██║██║ ╚═╝ ██║██║  ██║   ██║   ███████╗
     ╚═════╝ ╚══════╝╚═╝   ╚═╝╚═╝     ╚═╝╚═╝  ╚═╝   ╚═╝   ╚══════╝
    
    Ultimate ESP Library for Roblox
    GitHub: https://github.com/RbxCheats/UiLibESP
    Version: 2.0.0
--]]

-- Services
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

-- Local references
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ============================================================================
-- Utility Functions
-- ============================================================================

local Utilities = {}

function Utilities:Round(num)
    return math.floor(num + 0.5)
end

function Utilities:Vector2Round(v2)
    return Vector2.new(self:Round(v2.X), self:Round(v2.Y))
end

function Utilities:WorldToViewport(worldPos)
    return Camera:WorldToViewportPoint(worldPos)
end

function Utilities:Clamp(value, min, max)
    return math.clamp(value, min, max)
end

function Utilities:Lerp(a, b, t)
    return a + (b - a) * t
end

function Utilities:ColorLerp(c1, c2, t)
    return Color3.new(
        self:Lerp(c1.R, c2.R, t),
        self:Lerp(c1.G, c2.G, t),
        self:Lerp(c1.B, c2.B, t)
    )
end

function Utilities:GetDistance(pos1, pos2)
    return (pos1 - pos2).Magnitude
end

function Utilities:FormatDistance(distance)
    local studs = math.floor(distance + 0.5)
    local meters = math.floor(distance / 3.5714285714 + 0.5)
    return { Studs = studs, Meters = meters }
end

function Utilities:GetBoundingBox(part)
    local cframe, size = part.CFrame, part.Size
    local x, y, z = size.X / 2, size.Y / 2, size.Z / 2
    
    return {
        TopFrontRight = cframe * CFrame.new(x, y, z),
        TopFrontLeft = cframe * CFrame.new(-x, y, z),
        TopBackRight = cframe * CFrame.new(x, y, -z),
        TopBackLeft = cframe * CFrame.new(-x, y, -z),
        BottomFrontRight = cframe * CFrame.new(x, -y, z),
        BottomFrontLeft = cframe * CFrame.new(-x, -y, z),
        BottomBackRight = cframe * CFrame.new(x, -y, -z),
        BottomBackLeft = cframe * CFrame.new(-x, -y, -z)
    }
end

function Utilities:GetPlayerBoundingBox(character)
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return nil end
    
    local head = character:FindFirstChild("Head")
    local rootPart = humanoidRootPart
    local rootSize = rootPart.Size
    
    -- Calculate bounds using key body parts
    local minX, maxX = math.huge, -math.huge
    local minY, maxY = math.huge, -math.huge
    local minZ, maxZ = math.huge, -math.huge
    
    local parts = {
        rootPart,
        head,
        character:FindFirstChild("LeftUpperArm"),
        character:FindFirstChild("RightUpperArm"),
        character:FindFirstChild("LeftUpperLeg"),
        character:FindFirstChild("RightUpperLeg")
    }
    
    for _, part in pairs(parts) do
        if part then
            local pos = part.Position
            local size = part.Size / 2
            
            minX = math.min(minX, pos.X - size.X)
            maxX = math.max(maxX, pos.X + size.X)
            minY = math.min(minY, pos.Y - size.Y)
            maxY = math.max(maxY, pos.Y + size.Y)
            minZ = math.min(minZ, pos.Z - size.Z)
            maxZ = math.max(maxZ, pos.Z + size.Z)
        end
    end
    
    -- Fallback to root part only
    if minX == math.huge then
        minX, maxX = rootPart.Position.X - rootSize.X, rootPart.Position.X + rootSize.X
        minY, maxY = rootPart.Position.Y - rootSize.Y, rootPart.Position.Y + rootSize.Y
        minZ, maxZ = rootPart.Position.Z - rootSize.Z, rootPart.Position.Z + rootSize.Z
    end
    
    return {
        Min = Vector3.new(minX, minY, minZ),
        Max = Vector3.new(maxX, maxY, maxZ),
        Size = Vector3.new(maxX - minX, maxY - minY, maxZ - minZ)
    }
end

function Utilities:GetScreenBounds(character)
    local bounds = self:GetPlayerBoundingBox(character)
    if not bounds then return nil end
    
    local corners = {
        bounds.Min,
        bounds.Max,
        Vector3.new(bounds.Min.X, bounds.Min.Y, bounds.Max.Z),
        Vector3.new(bounds.Min.X, bounds.Max.Y, bounds.Min.Z),
        Vector3.new(bounds.Max.X, bounds.Min.Y, bounds.Min.Z),
        Vector3.new(bounds.Min.X, bounds.Max.Y, bounds.Max.Z),
        Vector3.new(bounds.Max.X, bounds.Min.Y, bounds.Max.Z),
        Vector3.new(bounds.Max.X, bounds.Max.Y, bounds.Min.Z)
    }
    
    local minX, maxX = Camera.ViewportSize.X, 0
    local minY, maxY = Camera.ViewportSize.Y, 0
    local allOnScreen = true
    
    for _, corner in pairs(corners) do
        local screenPos, onScreen = Camera:WorldToViewportPoint(corner)
        if not onScreen then
            allOnScreen = false
        else
            minX = math.min(minX, screenPos.X)
            maxX = math.max(maxX, screenPos.X)
            minY = math.min(minY, screenPos.Y)
            maxY = math.max(maxY, screenPos.Y)
        end
    end
    
    return {
        Position = Vector2.new(minX, minY),
        Size = Vector2.new(maxX - minX, maxY - minY),
        OnScreen = allOnScreen
    }
end

-- ============================================================================
-- Drawing Manager
-- ============================================================================

local DrawingManager = {}
DrawingManager.__index = DrawingManager

function DrawingManager:New()
    local self = setmetatable({}, DrawingManager)
    self.Objects = {}
    self.Pools = {}
    return self
end

function DrawingManager:Create(type, properties)
    local obj = Drawing.new(type)
    if properties then
        for prop, value in pairs(properties) do
            obj[prop] = value
        end
    end
    table.insert(self.Objects, obj)
    return obj
end

function DrawingManager:CreatePool(type, count, defaultProperties)
    local pool = {}
    for i = 1, count do
        pool[i] = self:Create(type, defaultProperties)
    end
    self.Pools[type] = pool
    return pool
end

function DrawingManager:Destroy(obj)
    if obj and obj.Remove then
        obj:Remove()
    end
    for i, existing in pairs(self.Objects) do
        if existing == obj then
            table.remove(self.Objects, i)
            break
        end
    end
end

function DrawingManager:DestroyAll()
    for _, obj in pairs(self.Objects) do
        if obj and obj.Remove then
            obj:Remove()
        end
    end
    self.Objects = {}
    self.Pools = {}
end

-- ============================================================================
-- Raycast Utilities
-- ============================================================================

local RaycastHelper = {}

function RaycastHelper:New()
    local self = {}
    self.Params = RaycastParams.new()
    self.Params.FilterType = Enum.RaycastFilterType.Blacklist
    self.Params.IgnoreWater = true
    self.IgnoreList = {}
    return self
end

function RaycastHelper:UpdateIgnoreList(ignore)
    self.IgnoreList = ignore
    self.Params.FilterDescendantsInstances = self.IgnoreList
end

function RaycastHelper:IsVisible(target, origin)
    if not origin then
        local character = LocalPlayer.Character
        if not character then return false end
        origin = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
        if not origin then return false end
        origin = origin.Position
    end
    
    local direction = (target.Position - origin).Unit * 1000
    local result = Workspace:Raycast(origin, direction, self.Params)
    
    if result and result.Instance:IsDescendantOf(target.Parent) then
        return true
    end
    return false
end

function RaycastHelper:IsVisibleRecursive(target, origin, maxDepth)
    maxDepth = maxDepth or 5
    if self:IsVisible(target, origin) then
        return true
    end
    
    -- Try from multiple points for better accuracy
    local points = {
        origin,
        origin + Vector3.new(0.5, 0, 0),
        origin + Vector3.new(-0.5, 0, 0),
        origin + Vector3.new(0, 0.5, 0),
        origin + Vector3.new(0, -0.5, 0)
    }
    
    for _, point in pairs(points) do
        if self:IsVisible(target, point) then
            return true
        end
    end
    
    return false
end

-- ============================================================================
-- ESP Core Class
-- ============================================================================

local ESP = {}
ESP.__index = ESP

-- Default settings
ESP.DefaultSettings = {
    -- Global
    Enabled = false,
    MaxDistance = 1000,
    MaxDistanceObjects = 500,
    TeamCheck = true,
    TeamColor = Color3.new(0, 0, 1),
    EnemyColor = Color3.new(1, 0, 0),
    FriendlyColor = Color3.new(0, 1, 0),
    
    -- Visibility
    VisibleCheck = false,
    VisibleCheckDepth = 3,
    TransparencyFade = true,
    FadeDistance = 100,
    
    -- Box
    BoxEnabled = true,
    BoxColor = Color3.new(1, 1, 1),
    BoxOutlineEnabled = true,
    BoxOutlineColor = Color3.new(0, 0, 0),
    BoxOutlineThickness = 3,
    BoxFillEnabled = false,
    BoxFillColor = Color3.new(0, 0, 0),
    BoxFillTransparency = 0.5,
    BoxCornerRadius = 0,
    
    -- Health Bar
    HealthBarEnabled = true,
    HealthBarPosition = "Left", -- Left, Right, Top, Bottom
    HealthBarWidth = 3,
    HealthBarColor = Color3.new(0, 1, 0),
    HealthBarLowColor = Color3.new(1, 0, 0),
    HealthBarBackgroundEnabled = true,
    HealthBarBackgroundColor = Color3.new(0.3, 0.3, 0.3),
    
    -- Armor/Kevlar Bar
    ArmorBarEnabled = false,
    ArmorBarPosition = "Left",
    ArmorBarWidth = 3,
    ArmorBarColor = Color3.new(0.3, 0.5, 1),
    ArmorBarBackgroundEnabled = true,
    
    -- Name
    NameEnabled = true,
    NamePosition = "Top", -- Top, Bottom, Left, Right
    NameColor = Color3.new(1, 1, 1),
    NameOutlineColor = Color3.new(0, 0, 0),
    NameOutlineEnabled = true,
    NameFont = 2,
    NameSize = 13,
    NameShorten = false,
    NameMaxLength = 10,
    
    -- Distance
    DistanceEnabled = true,
    DistancePosition = "Bottom",
    DistanceColor = Color3.new(1, 1, 1),
    DistanceOutlineColor = Color3.new(0, 0, 0),
    DistanceOutlineEnabled = true,
    DistanceUnits = "Meters", -- Meters, Studs
    
    -- Tool/Weapon
    ToolEnabled = true,
    ToolPosition = "Bottom",
    ToolColor = Color3.new(1, 1, 1),
    ToolOutlineColor = Color3.new(0, 0, 0),
    ToolOutlineEnabled = true,
    
    -- Health Text
    HealthTextEnabled = false,
    HealthTextPosition = "Left",
    HealthTextColor = Color3.new(1, 1, 1),
    
    -- Chams/Highlight
    ChamsEnabled = false,
    ChamsFillColor = Color3.new(1, 1, 1),
    ChamsOutlineColor = Color3.new(1, 1, 1),
    ChamsFillTransparency = 0.5,
    ChamsOutlineTransparency = 0,
    ChamsDepthMode = "AlwaysOnTop", -- AlwaysOnTop, Occluded
    ChamsVisibleOnly = true,
    
    -- Trails
    TrailEnabled = false,
    TrailLength = 20,
    TrailColor = Color3.new(1, 1, 1),
    TrailTransparency = 0.5,
    
    -- Tracers
    TracerEnabled = false,
    TracerFrom = "Bottom", -- Bottom, Center, Top
    TracerColor = Color3.new(1, 1, 1),
    TracerThickness = 1,
    
    -- Snaplines
    SnaplineEnabled = false,
    SnaplineColor = Color3.new(1, 1, 1),
    SnaplineThickness = 1,
    
    -- Radar
    RadarEnabled = false,
    RadarSize = 150,
    RadarPosition = "BottomRight", -- TopLeft, TopRight, BottomLeft, BottomRight
    RadarRange = 500,
    RadarDotSize = 3,
    RadarDotColor = Color3.new(1, 0, 0),
    RadarBackgroundColor = Color3.new(0, 0, 0),
    RadarBackgroundTransparency = 0.5,
    
    -- Off-screen Arrow
    ArrowEnabled = true,
    ArrowSize = 20,
    ArrowColor = Color3.new(1, 1, 1),
    ArrowRadius = 400,
    
    -- Highlight (separate from Chams)
    HighlightEnabled = false,
    HighlightColor = Color3.new(1, 0, 0),
    HighlightTarget = nil,
    
    -- Image ESP
    ImageEnabled = false,
    ImageUrl = "",
    ImageSize = Vector2.new(32, 32),
    
    -- 3D Objects
    ChinaHatEnabled = false,
    ChinaHatColor = Color3.new(1, 1, 1),
    ChinaHatTransparency = 0.5,
    ChinaHatRadius = 2,
    ChinaHatHeight = 1,
    ChinaHatOffset = 2,
    
    -- Performance
    UpdateRate = 0, -- 0 = every frame
    MaxPlayers = 50,
    CullBehindWalls = false,
    
    -- Priority System
    PriorityPlayers = {},
    PriorityColor = Color3.new(1, 0.5, 0),
    
    -- Custom Overrides
    OverrideGetTeam = nil,
    OverrideGetCharacter = nil,
    OverrideGetTool = nil,
    OverrideGetHealth = nil,
    OverrideGetArmor = nil,
    OverrideGetPriority = nil,
    OverrideIsVisible = nil
}

function ESP:New(settings)
    local self = setmetatable({}, ESP)
    
    -- Merge settings
    self.Settings = {}
    for key, value in pairs(ESP.DefaultSettings) do
        self.Settings[key] = settings and settings[key] ~= nil and settings[key] or value
    end
    
    -- Initialize tables
    self.Players = {}
    self.Objects = {}
    self.Trails = {}
    self.Drawings = {}
    
    -- Setup drawing manager
    self.DrawingManager = DrawingManager:New()
    
    -- Setup raycast helper
    self.RaycastHelper = RaycastHelper:New()
    
    -- State tracking
    self.RenderConnection = nil
    self.LastUpdate = tick()
    
    return self
end

-- ============================================================================
-- Drawing Helpers
-- ============================================================================

function ESP:CreateDrawing(type, properties)
    return self.DrawingManager:Create(type, properties)
end

function ESP:UpdateDrawingTransparency(drawing, transparency)
    if drawing then
        drawing.Transparency = 1 - self:Clamp(transparency, 0, 1)
    end
end

function ESP:Clamp(value, min, max)
    return Utilities:Clamp(value, min, max)
end

-- ============================================================================
-- Player Information Methods
-- ============================================================================

function ESP:GetTeam(player)
    if self.Settings.OverrideGetTeam then
        return self.Settings.OverrideGetTeam(player)
    end
    return player.Team
end

function ESP:GetCharacter(player)
    if self.Settings.OverrideGetCharacter then
        return self.Settings.OverrideGetCharacter(player)
    end
    return player.Character
end

function ESP:GetTool(player)
    if self.Settings.OverrideGetTool then
        return self.Settings.OverrideGetTool(player)
    end
    local character = self:GetCharacter(player)
    if character then
        local tool = character:FindFirstChildOfClass("Tool")
        if tool then
            return tool.Name
        end
    end
    return ""
end

function ESP:GetHealth(player)
    if self.Settings.OverrideGetHealth then
        return self.Settings.OverrideGetHealth(player)
    end
    local character = self:GetCharacter(player)
    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            return humanoid.Health, humanoid.MaxHealth
        end
    end
    return 0, 100
end

function ESP:GetArmor(player)
    if self.Settings.OverrideGetArmor then
        return self.Settings.OverrideGetArmor(player)
    end
    -- Check common armor instances
    local character = self:GetCharacter(player)
    if character then
        local armor = character:FindFirstChild("Armor") or 
                      character:FindFirstChild("Kevlar") or
                      character:FindFirstChild("Shield")
        if armor then
            return armor.Value if armor:IsA("NumberValue") else 100
        end
    end
    return 0, 100
end

function ESP:IsPriority(player)
    if self.Settings.OverrideGetPriority then
        return self.Settings.OverrideGetPriority(player)
    end
    for _, priority in pairs(self.Settings.PriorityPlayers) do
        if priority == player or priority == player.Name then
            return true
        end
    end
    return false
end

function ESP:IsEnemy(player)
    if player == LocalPlayer then return false end
    if not self.Settings.TeamCheck then return true end
    
    local localTeam = self:GetTeam(LocalPlayer)
    local playerTeam = self:GetTeam(player)
    
    if not localTeam or not playerTeam then return true end
    return localTeam ~= playerTeam
end

function ESP:GetColorForPlayer(player)
    if self:IsPriority(player) then
        return self.Settings.PriorityColor
    end
    if self:IsEnemy(player) then
        return self.Settings.EnemyColor
    end
    return self.Settings.FriendlyColor
end

function ESP:IsAlive(player)
    local character = self:GetCharacter(player)
    if not character then return false end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return false end
    
    local health, maxHealth = self:GetHealth(player)
    return health > 0 and humanoid.Health > 0
end

function ESP:IsVisible(target)
    if self.Settings.OverrideIsVisible then
        return self.Settings.OverrideIsVisible(target)
    end
    
    if not self.Settings.VisibleCheck then
        return true
    end
    
    local character = self:GetCharacter(target)
    if not character then return false end
    
    local head = character:FindFirstChild("Head")
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    
    if not head and not rootPart then return false end
    
    local targetPos = head and head or rootPart
    
    -- Update ignore list for raycast
    local ignoreList = {Camera, LocalPlayer.Character}
    self.RaycastHelper:UpdateIgnoreList(ignoreList)
    
    return self.RaycastHelper:IsVisibleRecursive(targetPos, nil, self.Settings.VisibleCheckDepth)
end

-- ============================================================================
-- Component Drawing Methods
-- ============================================================================

function ESP:DrawBox(screenBounds, color, transparency)
    local box = self:CreateDrawing("Square", {
        Size = screenBounds.Size,
        Position = screenBounds.Position,
        Color = color,
        Thickness = 1,
        Visible = true,
        Transparency = 1 - transparency
    })
    
    if self.Settings.BoxOutlineEnabled then
        local outline = self:CreateDrawing("Square", {
            Size = screenBounds.Size,
            Position = screenBounds.Position - Vector2.new(1, 1),
            Color = self.Settings.BoxOutlineColor,
            Thickness = self.Settings.BoxOutlineThickness,
            Visible = true,
            Transparency = 1 - transparency
        })
        return { Box = box, Outline = outline }
    end
    
    if self.Settings.BoxFillEnabled then
        local fill = self:CreateDrawing("Square", {
            Size = screenBounds.Size,
            Position = screenBounds.Position,
            Color = self.Settings.BoxFillColor,
            Thickness = 1,
            Filled = true,
            Visible = true,
            Transparency = 1 - (self.Settings.BoxFillTransparency * transparency)
        })
        return { Box = box, Fill = fill }
    end
    
    return { Box = box }
end

function ESP:DrawHealthBar(screenBounds, health, maxHealth, transparency)
    local components = {}
    local barWidth = self.Settings.HealthBarWidth
    local healthPercent = health / maxHealth
    local color = Utilities:ColorLerp(self.Settings.HealthBarLowColor, self.Settings.HealthBarColor, healthPercent)
    
    local barPosition, barSize
    
    if self.Settings.HealthBarPosition == "Left" then
        barPosition = Vector2.new(screenBounds.Position.X - barWidth - 2, screenBounds.Position.Y)
        barSize = Vector2.new(barWidth, screenBounds.Size.Y)
    elseif self.Settings.HealthBarPosition == "Right" then
        barPosition = Vector2.new(screenBounds.Position.X + screenBounds.Size.X + 2, screenBounds.Position.Y)
        barSize = Vector2.new(barWidth, screenBounds.Size.Y)
    elseif self.Settings.HealthBarPosition == "Top" then
        barPosition = Vector2.new(screenBounds.Position.X, screenBounds.Position.Y - barWidth - 2)
        barSize = Vector2.new(screenBounds.Size.X, barWidth)
    elseif self.Settings.HealthBarPosition == "Bottom" then
        barPosition = Vector2.new(screenBounds.Position.X, screenBounds.Position.Y + screenBounds.Size.Y + 2)
        barSize = Vector2.new(screenBounds.Size.X, barWidth)
    end
    
    -- Background
    if self.Settings.HealthBarBackgroundEnabled then
        local background = self:CreateDrawing("Square", {
            Position = barPosition,
            Size = barSize,
            Color = self.Settings.HealthBarBackgroundColor,
            Filled = true,
            Visible = true,
            Transparency = 1 - (transparency * 0.7)
        })
        components.Background = background
    end
    
    -- Fill
    local fillSize = barSize
    if self.Settings.HealthBarPosition == "Left" or self.Settings.HealthBarPosition == "Right" then
        fillSize = Vector2.new(barWidth, barSize.Y * healthPercent)
        fillPosition = Vector2.new(barPosition.X, barPosition.Y + barSize.Y - fillSize.Y)
    else
        fillSize = Vector2.new(barSize.X * healthPercent, barWidth)
        fillPosition = barPosition
    end
    
    local fill = self:CreateDrawing("Square", {
        Position = fillPosition,
        Size = fillSize,
        Color = color,
        Filled = true,
        Visible = true,
        Transparency = 1 - transparency
    })
    
    components.Fill = fill
    return components
end

function ESP:DrawArmorBar(screenBounds, armor, maxArmor, transparency)
    if not self.Settings.ArmorBarEnabled then return {} end
    
    local components = {}
    local barWidth = self.Settings.ArmorBarWidth
    local armorPercent = armor / maxArmor
    
    local barPosition, barSize
    
    if self.Settings.ArmorBarPosition == "Left" then
        local offset = self.Settings.HealthBarEnabled and (barWidth + 4) or 0
        barPosition = Vector2.new(screenBounds.Position.X - barWidth - 2 - offset, screenBounds.Position.Y)
        barSize = Vector2.new(barWidth, screenBounds.Size.Y)
    elseif self.Settings.ArmorBarPosition == "Right" then
        local offset = self.Settings.HealthBarEnabled and (barWidth + 4) or 0
        barPosition = Vector2.new(screenBounds.Position.X + screenBounds.Size.X + 2 + offset, screenBounds.Position.Y)
        barSize = Vector2.new(barWidth, screenBounds.Size.Y)
    end
    
    if self.Settings.ArmorBarBackgroundEnabled then
        local background = self:CreateDrawing("Square", {
            Position = barPosition,
            Size = barSize,
            Color = self.Settings.ArmorBarBackgroundColor,
            Filled = true,
            Visible = true,
            Transparency = 1 - (transparency * 0.7)
        })
        components.Background = background
    end
    
    local fillSize = Vector2.new(barWidth, barSize.Y * armorPercent)
    local fillPosition = Vector2.new(barPosition.X, barPosition.Y + barSize.Y - fillSize.Y)
    
    local fill = self:CreateDrawing("Square", {
        Position = fillPosition,
        Size = fillSize,
        Color = self.Settings.ArmorBarColor,
        Filled = true,
        Visible = true,
        Transparency = 1 - transparency
    })
    
    components.Fill = fill
    return components
end

function ESP:DrawText(text, position, color, outlineColor, transparency, center)
    local components = {}
    
    if self.Settings.NameOutlineEnabled then
        local outline = self:CreateDrawing("Text", {
            Text = text,
            Position = position + Vector2.new(1, 1),
            Color = outlineColor,
            Font = self.Settings.NameFont,
            Size = self.Settings.NameSize,
            Center = center,
            Visible = true,
            Transparency = 1 - transparency
        })
        components.Outline = outline
    end
    
    local main = self:CreateDrawing("Text", {
        Text = text,
        Position = position,
        Color = color,
        Font = self.Settings.NameFont,
        Size = self.Settings.NameSize,
        Center = center,
        Visible = true,
        Transparency = 1 - transparency
    })
    
    components.Main = main
    return components
end

function ESP:DrawDistance(distance, position, color, outlineColor, transparency, center)
    local distanceText = self.Settings.DistanceUnits == "Meters" and 
                         string.format("%dm", distance.Meters) or 
                         string.format("%d", distance.Studs)
    
    return self:DrawText(distanceText, position, color, outlineColor, transparency, center)
end

function ESP:DrawTracer(playerPos, from, color, thickness, transparency)
    local screenCenter = Camera.ViewportSize / 2
    local worldPos, onScreen = Camera:WorldToViewportPoint(playerPos)
    
    if not onScreen then return nil end
    
    local fromPos
    
    if self.Settings.TracerFrom == "Bottom" then
        fromPos = Vector2.new(screenCenter.X, Camera.ViewportSize.Y)
    elseif self.Settings.TracerFrom == "Top" then
        fromPos = Vector2.new(screenCenter.X, 0)
    else -- Center
        fromPos = screenCenter
    end
    
    local tracer = self:CreateDrawing("Line", {
        From = fromPos,
        To = Vector2.new(worldPos.X, worldPos.Y),
        Color = color,
        Thickness = thickness,
        Visible = true,
        Transparency = 1 - transparency
    })
    
    return tracer
end

function ESP:DrawSnapline(playerPos, color, thickness, transparency)
    local screenCenter = Camera.ViewportSize / 2
    local worldPos, onScreen = Camera:WorldToViewportPoint(playerPos)
    
    if not onScreen then return nil end
    
    local line = self:CreateDrawing("Line", {
        From = screenCenter,
        To = Vector2.new(worldPos.X, worldPos.Y),
        Color = color,
        Thickness = thickness,
        Visible = true,
        Transparency = 1 - transparency
    })
    
    return line
end

function ESP:DrawOffscreenArrow(playerPos, playerColor, transparency)
    local screenCenter = Camera.ViewportSize / 2
    local worldPos, onScreen = Camera:WorldToViewportPoint(playerPos)
    
    if onScreen then return nil end
    
    -- Calculate direction to off-screen target
    local direction = (Vector2.new(worldPos.X, worldPos.Y) - screenCenter).Unit
    local arrowPos = screenCenter + direction * self.Settings.ArrowRadius
    
    -- Clamp to screen edges
    arrowPos = Vector2.new(
        self:Clamp(arrowPos.X, self.Settings.ArrowSize, Camera.ViewportSize.X - self.Settings.ArrowSize),
        self:Clamp(arrowPos.Y, self.Settings.ArrowSize, Camera.ViewportSize.Y - self.Settings.ArrowSize)
    )
    
    -- Calculate triangle points for arrow
    local angle = math.atan2(direction.Y, direction.X)
    local arrowSize = self.Settings.ArrowSize
    
    local pointA = arrowPos + Vector2.new(math.cos(angle) * arrowSize, math.sin(angle) * arrowSize)
    local pointB = arrowPos + Vector2.new(math.cos(angle + 2.2) * (arrowSize * 0.6), math.sin(angle + 2.2) * (arrowSize * 0.6))
    local pointC = arrowPos + Vector2.new(math.cos(angle - 2.2) * (arrowSize * 0.6), math.sin(angle - 2.2) * (arrowSize * 0.6))
    
    local arrow = self:CreateDrawing("Triangle", {
        PointA = pointA,
        PointB = pointB,
        PointC = pointC,
        Color = playerColor,
        Filled = true,
        Visible = true,
        Transparency = 1 - transparency
    })
    
    return arrow
end

-- ============================================================================
-- Player ESP Management
-- ============================================================================

function ESP:AddPlayer(player)
    if self.Players[player] then
        self:RemovePlayer(player)
    end
    
    local playerData = {
        Player = player,
        Components = {},
        LastPosition = nil,
        TrailPoints = {},
        LastUpdate = tick()
    }
    
    self.Players[player] = playerData
    return playerData
end

function ESP:RemovePlayer(player)
    local data = self.Players[player]
    if data then
        -- Destroy all drawing components
        for _, component in pairs(data.Components) do
            if component then
                if type(component) == "table" then
                    for _, subComponent in pairs(component) do
                        if subComponent and subComponent.Remove then
                            subComponent:Remove()
                        end
                    end
                elseif component.Remove then
                    component:Remove()
                end
            end
        end
        self.Players[player] = nil
    end
end

function ESP:UpdatePlayer(player)
    local data = self.Players[player]
    if not data then
        data = self:AddPlayer(player)
    end
    
    -- Check if player is valid and ESP is enabled
    if not self.Settings.Enabled or not self:IsAlive(player) then
        -- Hide all components
        for _, component in pairs(data.Components) do
            if type(component) == "table" then
                for _, subComponent in pairs(component) do
                    if subComponent then
                        subComponent.Visible = false
                    end
                end
            elseif component then
                component.Visible = false
            end
        end
        return
    end
    
    local character = self:GetCharacter(player)
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    
    if not rootPart then return end
    
    -- Get screen bounds
    local screenBounds = Utilities:GetScreenBounds(character)
    if not screenBounds or (not screenBounds.OnScreen and not self.Settings.ArrowEnabled) then
        -- Hide box components
        if data.Components.Box then
            if data.Components.Box.Box then data.Components.Box.Box.Visible = false end
            if data.Components.Box.Outline then data.Components.Box.Outline.Visible = false end
            if data.Components.Box.Fill then data.Components.Box.Fill.Visible = false end
        end
        if data.Components.HealthBar then
            if data.Components.HealthBar.Background then data.Components.HealthBar.Background.Visible = false end
            if data.Components.HealthBar.Fill then data.Components.HealthBar.Fill.Visible = false end
        end
        if data.Components.ArmorBar then
            if data.Components.ArmorBar.Background then data.Components.ArmorBar.Background.Visible = false end
            if data.Components.ArmorBar.Fill then data.Components.ArmorBar.Fill.Visible = false end
        end
        if data.Components.Name then
            if data.Components.Name.Main then data.Components.Name.Main.Visible = false end
            if data.Components
