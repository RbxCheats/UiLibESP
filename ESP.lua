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
            if data.Components.Name.Outline then data.Components.Name.Outline.Visible = false end
        end
        if data.Components.Distance then
            if data.Components.Distance.Main then data.Components.Distance.Main.Visible = false end
            if data.Components.Distance.Outline then data.Components.Distance.Outline.Visible = false end
        end
    else
        -- Calculate distance and fade
        local distance = Utilities:GetDistance(rootPart.Position, Camera.CFrame.Position)
        local distanceFormatted = Utilities:FormatDistance(distance)
        local transparency = 1
        
        if self.Settings.TransparencyFade and distance > self.Settings.FadeDistance then
            transparency = 1 - self:Clamp((distance - self.Settings.FadeDistance) / (self.Settings.MaxDistance - self.Settings.FadeDistance), 0, 1)
        end
        
        -- Visibility check
        local isVisible = self:IsVisible(player)
        if self.Settings.VisibleCheck and not isVisible and self.Settings.CullBehindWalls then
            transparency = transparency * 0.3
        end
        
        -- Get player color based on priority/enemy/team
        local playerColor = self:GetColorForPlayer(player)
        local health, maxHealth = self:GetHealth(player)
        local armor, maxArmor = self:GetArmor(player)
        
        -- Draw Box
        if self.Settings.BoxEnabled and screenBounds.OnScreen then
            if not data.Components.Box then
                data.Components.Box = self:DrawBox(screenBounds, playerColor, transparency)
            else
                data.Components.Box.Box.Size = screenBounds.Size
                data.Components.Box.Box.Position = screenBounds.Position
                data.Components.Box.Box.Color = playerColor
                data.Components.Box.Box.Transparency = 1 - transparency
                
                if data.Components.Box.Outline then
                    data.Components.Box.Outline.Size = screenBounds.Size
                    data.Components.Box.Outline.Position = screenBounds.Position - Vector2.new(1, 1)
                    data.Components.Box.Outline.Transparency = 1 - transparency
                end
                
                if data.Components.Box.Fill then
                    data.Components.Box.Fill.Size = screenBounds.Size
                    data.Components.Box.Fill.Position = screenBounds.Position
                    data.Components.Box.Fill.Transparency = 1 - (self.Settings.BoxFillTransparency * transparency)
                end
            end
            data.Components.Box.Box.Visible = true
            if data.Components.Box.Outline then data.Components.Box.Outline.Visible = true end
            if data.Components.Box.Fill then data.Components.Box.Fill.Visible = true end
        elseif data.Components.Box then
            data.Components.Box.Box.Visible = false
            if data.Components.Box.Outline then data.Components.Box.Outline.Visible = false end
            if data.Components.Box.Fill then data.Components.Box.Fill.Visible = false end
        end
        
        -- Draw Health Bar
        if self.Settings.HealthBarEnabled and screenBounds.OnScreen then
            if not data.Components.HealthBar then
                data.Components.HealthBar = self:DrawHealthBar(screenBounds, health, maxHealth, transparency)
            else
                -- Update health bar position and size
                local barWidth = self.Settings.HealthBarWidth
                local healthPercent = health / maxHealth
                local color = Utilities:ColorLerp(self.Settings.HealthBarLowColor, self.Settings.HealthBarColor, healthPercent)
                
                if self.Settings.HealthBarPosition == "Left" then
                    data.Components.HealthBar.Fill.Position = Vector2.new(
                        screenBounds.Position.X - barWidth - 2,
                        screenBounds.Position.Y + screenBounds.Size.Y * (1 - healthPercent)
                    )
                    data.Components.HealthBar.Fill.Size = Vector2.new(barWidth, screenBounds.Size.Y * healthPercent)
                    
                    if data.Components.HealthBar.Background then
                        data.Components.HealthBar.Background.Position = Vector2.new(screenBounds.Position.X - barWidth - 2, screenBounds.Position.Y)
                        data.Components.HealthBar.Background.Size = Vector2.new(barWidth, screenBounds.Size.Y)
                    end
                elseif self.Settings.HealthBarPosition == "Right" then
                    data.Components.HealthBar.Fill.Position = Vector2.new(
                        screenBounds.Position.X + screenBounds.Size.X + 2,
                        screenBounds.Position.Y + screenBounds.Size.Y * (1 - healthPercent)
                    )
                    data.Components.HealthBar.Fill.Size = Vector2.new(barWidth, screenBounds.Size.Y * healthPercent)
                    
                    if data.Components.HealthBar.Background then
                        data.Components.HealthBar.Background.Position = Vector2.new(screenBounds.Position.X + screenBounds.Size.X + 2, screenBounds.Position.Y)
                        data.Components.HealthBar.Background.Size = Vector2.new(barWidth, screenBounds.Size.Y)
                    end
                elseif self.Settings.HealthBarPosition == "Top" then
                    data.Components.HealthBar.Fill.Position = screenBounds.Position
                    data.Components.HealthBar.Fill.Size = Vector2.new(screenBounds.Size.X * healthPercent, barWidth)
                    
                    if data.Components.HealthBar.Background then
                        data.Components.HealthBar.Background.Position = Vector2.new(screenBounds.Position.X, screenBounds.Position.Y - barWidth - 2)
                        data.Components.HealthBar.Background.Size = Vector2.new(screenBounds.Size.X, barWidth)
                    end
                elseif self.Settings.HealthBarPosition == "Bottom" then
                    data.Components.HealthBar.Fill.Position = screenBounds.Position
                    data.Components.HealthBar.Fill.Size = Vector2.new(screenBounds.Size.X * healthPercent, barWidth)
                    
                    if data.Components.HealthBar.Background then
                        data.Components.HealthBar.Background.Position = Vector2.new(screenBounds.Position.X, screenBounds.Position.Y + screenBounds.Size.Y + 2)
                        data.Components.HealthBar.Background.Size = Vector2.new(screenBounds.Size.X, barWidth)
                    end
                end
                
                data.Components.HealthBar.Fill.Color = color
                data.Components.HealthBar.Fill.Transparency = 1 - transparency
                if data.Components.HealthBar.Background then
                    data.Components.HealthBar.Background.Transparency = 1 - (transparency * 0.7)
                end
            end
            
            data.Components.HealthBar.Fill.Visible = true
            if data.Components.HealthBar.Background then data.Components.HealthBar.Background.Visible = true end
        elseif data.Components.HealthBar then
            if data.Components.HealthBar.Fill then data.Components.HealthBar.Fill.Visible = false end
            if data.Components.HealthBar.Background then data.Components.HealthBar.Background.Visible = false end
        end
        
        -- Draw Armor Bar
        if self.Settings.ArmorBarEnabled and screenBounds.OnScreen then
            if not data.Components.ArmorBar then
                data.Components.ArmorBar = self:DrawArmorBar(screenBounds, armor, maxArmor, transparency)
            else
                -- Update armor bar
                local barWidth = self.Settings.ArmorBarWidth
                local armorPercent = armor / maxArmor
                
                if self.Settings.ArmorBarPosition == "Left" then
                    local offset = self.Settings.HealthBarEnabled and (barWidth + 4) or 0
                    data.Components.ArmorBar.Fill.Position = Vector2.new(
                        screenBounds.Position.X - barWidth - 2 - offset,
                        screenBounds.Position.Y + screenBounds.Size.Y * (1 - armorPercent)
                    )
                    data.Components.ArmorBar.Fill.Size = Vector2.new(barWidth, screenBounds.Size.Y * armorPercent)
                    
                    if data.Components.ArmorBar.Background then
                        data.Components.ArmorBar.Background.Position = Vector2.new(screenBounds.Position.X - barWidth - 2 - offset, screenBounds.Position.Y)
                        data.Components.ArmorBar.Background.Size = Vector2.new(barWidth, screenBounds.Size.Y)
                    end
                elseif self.Settings.ArmorBarPosition == "Right" then
                    local offset = self.Settings.HealthBarEnabled and (barWidth + 4) or 0
                    data.Components.ArmorBar.Fill.Position = Vector2.new(
                        screenBounds.Position.X + screenBounds.Size.X + 2 + offset,
                        screenBounds.Position.Y + screenBounds.Size.Y * (1 - armorPercent)
                    )
                    data.Components.ArmorBar.Fill.Size = Vector2.new(barWidth, screenBounds.Size.Y * armorPercent)
                    
                    if data.Components.ArmorBar.Background then
                        data.Components.ArmorBar.Background.Position = Vector2.new(screenBounds.Position.X + screenBounds.Size.X + 2 + offset, screenBounds.Position.Y)
                        data.Components.ArmorBar.Background.Size = Vector2.new(barWidth, screenBounds.Size.Y)
                    end
                end
                
                data.Components.ArmorBar.Fill.Transparency = 1 - transparency
                if data.Components.ArmorBar.Background then
                    data.Components.ArmorBar.Background.Transparency = 1 - (transparency * 0.7)
                end
            end
            
            data.Components.ArmorBar.Fill.Visible = true
            if data.Components.ArmorBar.Background then data.Components.ArmorBar.Background.Visible = true end
        elseif data.Components.ArmorBar then
            if data.Components.ArmorBar.Fill then data.Components.ArmorBar.Fill.Visible = false end
            if data.Components.ArmorBar.Background then data.Components.ArmorBar.Background.Visible = false end
        end
        
        -- Draw Name
        if self.Settings.NameEnabled and screenBounds.OnScreen then
            local playerName = player.Name
            if self.Settings.NameShorten and #playerName > self.Settings.NameMaxLength then
                playerName = string.sub(playerName, 1, self.Settings.NameMaxLength) .. ".."
            end
            
            local namePosition
            if self.Settings.NamePosition == "Top" then
                namePosition = Vector2.new(
                    screenBounds.Position.X + screenBounds.Size.X / 2,
                    screenBounds.Position.Y - 5
                )
            elseif self.Settings.NamePosition == "Bottom" then
                namePosition = Vector2.new(
                    screenBounds.Position.X + screenBounds.Size.X / 2,
                    screenBounds.Position.Y + screenBounds.Size.Y + 5
                )
            elseif self.Settings.NamePosition == "Left" then
                namePosition = Vector2.new(
                    screenBounds.Position.X - 5,
                    screenBounds.Position.Y + screenBounds.Size.Y / 2
                )
            elseif self.Settings.NamePosition == "Right" then
                namePosition = Vector2.new(
                    screenBounds.Position.X + screenBounds.Size.X + 5,
                    screenBounds.Position.Y + screenBounds.Size.Y / 2
                )
            end
            
            if not data.Components.Name then
                data.Components.Name = self:DrawText(playerName, namePosition, playerColor, self.Settings.NameOutlineColor, transparency, true)
            else
                data.Components.Name.Main.Text = playerName
                data.Components.Name.Main.Position = namePosition
                data.Components.Name.Main.Color = playerColor
                data.Components.Name.Main.Transparency = 1 - transparency
                
                if data.Components.Name.Outline then
                    data.Components.Name.Outline.Text = playerName
                    data.Components.Name.Outline.Position = namePosition + Vector2.new(1, 1)
                    data.Components.Name.Outline.Transparency = 1 - transparency
                end
            end
            data.Components.Name.Main.Visible = true
            if data.Components.Name.Outline then data.Components.Name.Outline.Visible = true end
        elseif data.Components.Name then
            if data.Components.Name.Main then data.Components.Name.Main.Visible = false end
            if data.Components.Name.Outline then data.Components.Name.Outline.Visible = false end
        end
        
        -- Draw Distance
        if self.Settings.DistanceEnabled and screenBounds.OnScreen then
            local distancePosition
            if self.Settings.DistancePosition == "Top" then
                distancePosition = Vector2.new(
                    screenBounds.Position.X + screenBounds.Size.X / 2,
                    screenBounds.Position.Y - 20
                )
            elseif self.Settings.DistancePosition == "Bottom" then
                distancePosition = Vector2.new(
                    screenBounds.Position.X + screenBounds.Size.X / 2,
                    screenBounds.Position.Y + screenBounds.Size.Y + 18
                )
            end
            
            if not data.Components.Distance then
                data.Components.Distance = self:DrawDistance(distanceFormatted, distancePosition, self.Settings.DistanceColor, self.Settings.DistanceOutlineColor, transparency, true)
            else
                local distanceText = self.Settings.DistanceUnits == "Meters" and 
                                     string.format("%dm", distanceFormatted.Meters) or 
                                     string.format("%d", distanceFormatted.Studs)
                
                data.Components.Distance.Main.Text = distanceText
                data.Components.Distance.Main.Position = distancePosition
                data.Components.Distance.Main.Transparency = 1 - transparency
                
                if data.Components.Distance.Outline then
                    data.Components.Distance.Outline.Text = distanceText
                    data.Components.Distance.Outline.Position = distancePosition + Vector2.new(1, 1)
                    data.Components.Distance.Outline.Transparency = 1 - transparency
                end
            end
            data.Components.Distance.Main.Visible = true
            if data.Components.Distance.Outline then data.Components.Distance.Outline.Visible = true end
        elseif data.Components.Distance then
            if data.Components.Distance.Main then data.Components.Distance.Main.Visible = false end
            if data.Components.Distance.Outline then data.Components.Distance.Outline.Visible = false end
        end
        
        -- Draw Tracers
        if self.Settings.TracerEnabled and screenBounds.OnScreen then
            if not data.Components.Tracer then
                data.Components.Tracer = self:DrawTracer(rootPart.Position, self.Settings.TracerFrom, playerColor, self.Settings.TracerThickness, transparency)
            else
                data.Components.Tracer.From = self.Settings.TracerFrom == "Bottom" and 
                                              Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y) or
                                              (self.Settings.TracerFrom == "Top" and 
                                               Vector2.new(Camera.ViewportSize.X / 2, 0) or
                                               Camera.ViewportSize / 2)
                
                local worldPos, _ = Camera:WorldToViewportPoint(rootPart.Position)
                data.Components.Tracer.To = Vector2.new(worldPos.X, worldPos.Y)
                data.Components.Tracer.Color = playerColor
                data.Components.Tracer.Transparency = 1 - transparency
            end
            data.Components.Tracer.Visible = true
        elseif data.Components.Tracer then
            data.Components.Tracer.Visible = false
        end
        
        -- Draw Snaplines
        if self.Settings.SnaplineEnabled and screenBounds.OnScreen then
            if not data.Components.Snapline then
                data.Components.Snapline = self:DrawSnapline(rootPart.Position, playerColor, self.Settings.SnaplineThickness, transparency)
            else
                local worldPos, _ = Camera:WorldToViewportPoint(rootPart.Position)
                data.Components.Snapline.To = Vector2.new(worldPos.X, worldPos.Y)
                data.Components.Snapline.Color = playerColor
                data.Components.Snapline.Transparency = 1 - transparency
            end
            data.Components.Snapline.Visible = true
        elseif data.Components.Snapline then
            data.Components.Snapline.Visible = false
        end
        
        -- Draw Off-screen Arrow
        if self.Settings.ArrowEnabled and not screenBounds.OnScreen then
            if not data.Components.Arrow then
                data.Components.Arrow = self:DrawOffscreenArrow(rootPart.Position, playerColor, transparency)
            else
                -- Update arrow position based on new player position
                local screenCenter = Camera.ViewportSize / 2
                local worldPos, _ = Camera:WorldToViewportPoint(rootPart.Position)
                local direction = (Vector2.new(worldPos.X, worldPos.Y) - screenCenter).Unit
                local arrowPos = screenCenter + direction * self.Settings.ArrowRadius
                
                arrowPos = Vector2.new(
                    self:Clamp(arrowPos.X, self.Settings.ArrowSize, Camera.ViewportSize.X - self.Settings.ArrowSize),
                    self:Clamp(arrowPos.Y, self.Settings.ArrowSize, Camera.ViewportSize.Y - self.Settings.ArrowSize)
                )
                
                local angle = math.atan2(direction.Y, direction.X)
                local arrowSize = self.Settings.ArrowSize
                
                data.Components.Arrow.PointA = arrowPos + Vector2.new(math.cos(angle) * arrowSize, math.sin(angle) * arrowSize)
                data.Components.Arrow.PointB = arrowPos + Vector2.new(math.cos(angle + 2.2) * (arrowSize * 0.6), math.sin(angle + 2.2) * (arrowSize * 0.6))
                data.Components.Arrow.PointC = arrowPos + Vector2.new(math.cos(angle - 2.2) * (arrowSize * 0.6), math.sin(angle - 2.2) * (arrowSize * 0.6))
                data.Components.Arrow.Color = playerColor
                data.Components.Arrow.Transparency = 1 - transparency
            end
            data.Components.Arrow.Visible = true
        elseif data.Components.Arrow then
            data.Components.Arrow.Visible = false
        end
    end
    
    -- Update Chams/Highlight
    if self.Settings.ChamsEnabled then
        local isVisible = self:IsVisible(player)
        if (not self.Settings.ChamsVisibleOnly or isVisible) and self:IsAlive(player) then
            if not data.Chams then
                data.Chams = Instance.new("Highlight")
                data.Chams.Parent = CoreGui
            end
            
            data.Chams.Adornee = character
            data.Chams.Enabled = true
            data.Chams.FillColor = self.Settings.ChamsFillColor
            data.Chams.OutlineColor = self.Settings.ChamsOutlineColor
            data.Chams.FillTransparency = self.Settings.ChamsFillTransparency
            data.Chams.OutlineTransparency = self.Settings.ChamsOutlineTransparency
            data.Chams.DepthMode = self.Settings.ChamsDepthMode == "AlwaysOnTop" and 
                                   Enum.HighlightDepthMode.AlwaysOnTop or 
                                   Enum.HighlightDepthMode.Occluded
        elseif data.Chams then
            data.Chams.Enabled = false
        end
    elseif data and data.Chams then
        data.Chams.Enabled = false
    end
    
    -- Track position for trails
    if self.Settings.TrailEnabled and self:IsAlive(player) then
        if not data.TrailPoints then
            data.TrailPoints = {}
        end
        
        table.insert(data.TrailPoints, 1, rootPart.Position)
        
        -- Limit trail length
        while #data.TrailPoints > self.Settings.TrailLength do
            table.remove(data.TrailPoints)
        end
        
        -- Draw trail
        if not data.Components.Trail then
            data.Components.Trail = {}
        end
        
        -- Clear old trail drawings
        for _, trail in pairs(data.Components.Trail) do
            if trail and trail.Remove then
                trail:Remove()
            end
        end
        data.Components.Trail = {}
        
        -- Draw new trail
        for i = 1, #data.TrailPoints - 1 do
            local startPoint = data.TrailPoints[i]
            local endPoint = data.TrailPoints[i + 1]
            
            local startScreen, startOn = Camera:WorldToViewportPoint(startPoint)
            local endScreen, endOn = Camera:WorldToViewportPoint(endPoint)
            
            if startOn and endOn then
                local trailAlpha = 1 - (i / #data.TrailPoints) * self.Settings.TrailTransparency
                local trail = self:CreateDrawing("Line", {
                    From = Vector2.new(startScreen.X, startScreen.Y),
                    To = Vector2.new(endScreen.X, endScreen.Y),
                    Color = self.Settings.TrailColor,
                    Thickness = 1,
                    Visible = true,
                    Transparency = 1 - trailAlpha
                })
                table.insert(data.Components.Trail, trail)
            end
        end
    elseif data and data.Components.Trail then
        for _, trail in pairs(data.Components.Trail) do
            if trail then
                trail.Visible = false
            end
        end
    end
end

-- ============================================================================
-- Object ESP (for non-player entities)
-- ============================================================================

function ESP:AddObject(name, primaryPart, options)
    options = options or {}
    
    local objectData = {
        Name = name,
        PrimaryPart = primaryPart,
        Options = options,
        Components = {}
    }
    
    table.insert(self.Objects, objectData)
    return objectData
end

function ESP:RemoveObject(object)
    for i, obj in pairs(self.Objects) do
        if obj == object then
            -- Destroy components
            for _, component in pairs(obj.Components) do
                if component and component.Remove then
                    component:Remove()
                end
            end
            table.remove(self.Objects, i)
            break
        end
    end
end

function ESP:UpdateObject(object)
    if not self.Settings.Enabled or not object.PrimaryPart then
        if object.Components.Name then object.Components.Name.Visible = false end
        if object.Components.Distance then object.Components.Distance.Visible = false end
        return
    end
    
    local pos, onScreen = Camera:WorldToViewportPoint(object.PrimaryPart.Position)
    local distance = Utilities:GetDistance(object.PrimaryPart.Position, Camera.CFrame.Position)
    local distanceFormatted = Utilities:FormatDistance(distance)
    
    if onScreen and distance < self.Settings.MaxDistanceObjects then
        -- Draw name
        if not object.Components.Name then
            local nameText = object.Name
            if object.Options.Shorten and #nameText > (object.Options.MaxLength or 10) then
                nameText = string.sub(nameText, 1, object.Options.MaxLength or 10) .. ".."
            end
            
            object.Components.Name = self:CreateDrawing("Text", {
                Text = nameText,
                Position = Vector2.new(pos.X, pos.Y - 20),
                Color = object.Options.Color or Color3.new(1, 1, 1),
                Font = self.Settings.NameFont,
                Size = self.Settings.NameSize,
                Center = true,
                Visible = true
            })
        else
            object.Components.Name.Position = Vector2.new(pos.X, pos.Y - 20)
        end
        
        -- Draw distance
        if object.Options.ShowDistance then
            if not object.Components.Distance then
                local distanceText = string.format("%dm", distanceFormatted.Meters)
                object.Components.Distance = self:CreateDrawing("Text", {
                    Text = distanceText,
                    Position = Vector2.new(pos.X, pos.Y - 5),
                    Color = object.Options.DistanceColor or Color3.new(0.7, 0.7, 0.7),
                    Font = self.Settings.NameFont,
                    Size = self.Settings.NameSize - 2,
                    Center = true,
                    Visible = true
                })
            else
                object.Components.Distance.Position = Vector2.new(pos.X, pos.Y - 5)
                object.Components.Distance.Text = string.format("%dm", distanceFormatted.Meters)
            end
            object.Components.Distance.Visible = true
        elseif object.Components.Distance then
            object.Components.Distance.Visible = false
        end
        
        object.Components.Name.Visible = true
    else
        if object.Components.Name then object.Components.Name.Visible = false end
        if object.Components.Distance then object.Components.Distance.Visible = false end
    end
end

-- ============================================================================
-- Main Update Loop
-- ============================================================================

function ESP:Update()
    -- Rate limiting
    if self.Settings.UpdateRate > 0 then
        local now = tick()
        if now - self.LastUpdate < 1 / self.Settings.UpdateRate then
            return
        end
        self.LastUpdate = now
    end
    
    -- Update all players
    local playerCount = 0
    for _, player in pairs(Players:GetPlayers()) do
        if playerCount >= self.Settings.MaxPlayers then break end
        if player ~= LocalPlayer then
            self:UpdatePlayer(player)
            playerCount = playerCount + 1
        end
    end
    
    -- Update all objects
    for _, object in pairs(self.Objects) do
        self:UpdateObject(object)
    end
end

-- ============================================================================
-- Control Methods
-- ============================================================================

function ESP:Enable()
    self.Settings.Enabled = true
    if not self.RenderConnection then
        self.RenderConnection = RunService.RenderStepped:Connect(function()
            self:Update()
        end)
    end
end

function ESP:Disable()
    self.Settings.Enabled = false
    if self.RenderConnection then
        self.RenderConnection:Disconnect()
        self.RenderConnection = nil
    end
    
    -- Clean up all drawings
    self.DrawingManager:DestroyAll()
    
    -- Clean up chams
    for _, data in pairs(self.Players) do
        if data.Chams then
            data.Chams.Enabled = false
        end
    end
end

function ESP:Toggle()
    if self.Settings.Enabled then
        self:Disable()
    else
        self:Enable()
    end
    return self.Settings.Enabled
end

function ESP:Destroy()
    self:Disable()
    
    -- Clean up all player data
    for player, _ in pairs(self.Players) do
        self:RemovePlayer(player)
    end
    
    -- Clean up objects
    for _, object in pairs(self.Objects) do
        self:RemoveObject(object)
    end
    
    self.Players = {}
    self.Objects = {}
end

-- ============================================================================
-- Configuration Methods
-- ============================================================================

function ESP:SetSetting(key, value)
    if self.Settings[key] ~= nil then
        self.Settings[key] = value
    end
end

function ESP:GetSetting(key)
    return self.Settings[key]
end

function ESP:LoadConfig(config)
    for key, value in pairs(config) do
        if self.Settings[key] ~= nil then
            self.Settings[key] = value
        end
    end
end

function ESP:SaveConfig()
    local config = {}
    for key, value in pairs(self.Settings) do
        -- Skip function references and internal tables
        if type(value) ~= "function" and key ~= "OverrideGetTeam" and 
           key ~= "OverrideGetCharacter" and key ~= "OverrideGetTool" and
           key ~= "OverrideGetHealth" and key ~= "OverrideGetArmor" and
           key ~= "OverrideGetPriority" and key ~= "OverrideIsVisible" then
            config[key] = value
        end
    end
    return config
end

-- ============================================================================
-- Priority Management
-- ============================================================================

function ESP:AddPriority(player)
    if type(player) == "string" then
        table.insert(self.Settings.PriorityPlayers, player)
    elseif player.Name then
        table.insert(self.Settings.PriorityPlayers, player)
    end
end

function ESP:RemovePriority(player)
    for i, priority in pairs(self.Settings.PriorityPlayers) do
        if priority == player or priority == player.Name then
            table.remove(self.Settings.PriorityPlayers, i)
            break
        end
    end
end

function ESP:ClearPriorities()
    self.Settings.PriorityPlayers = {}
end

-- ============================================================================
-- Export
-- ============================================================================

-- Create a default instance
local defaultESP = ESP:New()

return {
    New = ESP.New,
    Default = defaultESP,
    Utilities = Utilities,
    Version = "2.0.0",
    GitHub = "https://github.com/RbxCheats/UiLibESP"
}
