-- ================================================================
-- Standalone ESP Library
-- Supports: 2D Box, 3D Box, Corner Box, Name ESP, Tracers, Health Bar
-- ================================================================

local ESPLibrary = {}
ESPLibrary.__index = ESPLibrary

-- Services
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Camera = workspace.CurrentCamera
local lp = Players.LocalPlayer

-- Drawing helper
local function createDrawing(class, props)
    local d = Drawing.new(class)
    for k, v in pairs(props or {}) do 
        if type(v) == "Vector2" or type(v) == "Color3" then
            d[k] = v
        else
            d[k] = v
        end
    end
    return d
end

-- Constructor
function ESPLibrary.new()
    local self = setmetatable({}, ESPLibrary)
    
    self.enabled = false
    self.espType = "2D Box" -- "2D Box", "Corner Box", "3D Box"
    self.nameEsp = false
    self.tracers = false
    self.healthBar = false
    self.ignoreLocal = true
    
    self.espColor = Color3.fromRGB(255, 255, 255)
    self.nameColor = Color3.fromRGB(255, 255, 255)
    self.tracerColor = Color3.fromRGB(255, 255, 255)
    self.healthBarColor = Color3.fromRGB(0, 255, 0)
    
    self.drawings = {}
    self.renderConn = nil
    
    return self
end

-- Get screen box position and size
function ESPLibrary:getScreenBox(char)
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return nil, nil, nil, false end
    
    local top = Camera:WorldToViewportPoint(root.Position + Vector3.new(0, 3, 0))
    local bottom = Camera:WorldToViewportPoint(root.Position - Vector3.new(0, 3.5, 0))
    local height = math.abs(top.Y - bottom.Y)
    local width = height * 0.55
    local center = Camera:WorldToViewportPoint(root.Position)
    
    return center, width, height, (top.Z > 0 and bottom.Z > 0)
end

-- Draw 3D box
function ESPLibrary:draw3DBox(d, cf, size, color)
    if #d.lines3d == 0 then
        for i = 1, 12 do 
            d.lines3d[i] = createDrawing("Line", {Thickness = 1.5, Color = color})
        end
    end
    
    local half = size * 0.5
    local corners = {
        cf * CFrame.new( half.X,  half.Y,  half.Z), cf * CFrame.new(-half.X,  half.Y,  half.Z),
        cf * CFrame.new(-half.X, -half.Y,  half.Z), cf * CFrame.new( half.X, -half.Y,  half.Z),
        cf * CFrame.new( half.X,  half.Y, -half.Z), cf * CFrame.new(-half.X,  half.Y, -half.Z),
        cf * CFrame.new(-half.X, -half.Y, -half.Z), cf * CFrame.new( half.X, -half.Y, -half.Z),
    }
    
    local screen = {}
    for i = 1, 8 do 
        screen[i] = Camera:WorldToViewportPoint(corners[i].Position) 
    end
    
    local edges = {{1,2},{2,3},{3,4},{4,1},{5,6},{6,7},{7,8},{8,5},{1,5},{2,6},{3,7},{4,8}}
    
    for i, e in ipairs(edges) do
        local p1, p2 = screen[e[1]], screen[e[2]]
        local line = d.lines3d[i]
        if line and p1.Z > 0 and p2.Z > 0 then
            line.Visible = true
            line.From = Vector2.new(p1.X, p1.Y)
            line.To = Vector2.new(p2.X, p2.Y)
            line.Color = color
        elseif line then
            line.Visible = false
        end
    end
end

-- Clear all drawings for a specific player
function ESPLibrary:clearPlayerDrawings(char)
    local d = self.drawings[char]
    if d then
        if d.box then d.box.Visible = false end
        if d.name then d.name.Visible = false end
        if d.tracer then d.tracer.Visible = false end
        if d.healthBG then d.healthBG.Visible = false end
        if d.healthMain then d.healthMain.Visible = false end
        if d.c1 then 
            for i = 1, 8 do 
                local ln = d["c"..i] 
                if ln then ln.Visible = false end 
            end 
        end
        if d.lines3d then 
            for _, line in ipairs(d.lines3d) do 
                if line then line.Visible = false end 
            end 
        end
    end
end

-- Clear all drawings
function ESPLibrary:clearAllDrawings()
    for char, cache in pairs(self.drawings) do
        self:clearPlayerDrawings(char)
    end
end

-- Create drawing objects for a player
function ESPLibrary:createDrawingsForPlayer(char)
    if self.drawings[char] then return end
    
    self.drawings[char] = {
        box = createDrawing("Square", {Thickness = 1, Filled = false, Color = self.espColor, Visible = false}),
        name = createDrawing("Text", {Size = 14, Color = Color3.new(1,1,1), Center = true, Outline = true, Font = 2, Visible = false}),
        tracer = createDrawing("Line", {Thickness = 1, Color = self.tracerColor, Visible = false}),
        healthBG = createDrawing("Square", {Thickness = 1, Filled = true, Color = Color3.new(0,0,0), Visible = false}),
        healthMain = createDrawing("Square", {Thickness = 1, Filled = true, Color = self.healthBarColor, Visible = false}),
        -- Corner box lines
        c1 = createDrawing("Line", {Thickness = 1.5, Color = self.espColor, Visible = false}),
        c2 = createDrawing("Line", {Thickness = 1.5, Color = self.espColor, Visible = false}),
        c3 = createDrawing("Line", {Thickness = 1.5, Color = self.espColor, Visible = false}),
        c4 = createDrawing("Line", {Thickness = 1.5, Color = self.espColor, Visible = false}),
        c5 = createDrawing("Line", {Thickness = 1.5, Color = self.espColor, Visible = false}),
        c6 = createDrawing("Line", {Thickness = 1.5, Color = self.espColor, Visible = false}),
        c7 = createDrawing("Line", {Thickness = 1.5, Color = self.espColor, Visible = false}),
        c8 = createDrawing("Line", {Thickness = 1.5, Color = self.espColor, Visible = false}),
        lines3d = {}
    }
end

-- Update ESP visuals
function ESPLibrary:update()
    if not self.enabled then
        self:clearAllDrawings()
        return
    end
    
    for _, player in ipairs(Players:GetPlayers()) do
        if self.ignoreLocal and player == lp then continue end
        
        local char = player.Character
        if not char then continue end
        
        local hum = char:FindFirstChildOfClass("Humanoid")
        local root = char:FindFirstChild("HumanoidRootPart")
        
        if not (hum and root and hum.Health > 0) then continue end
        
        self:createDrawingsForPlayer(char)
        local d = self.drawings[char]
        local center, width, height, onScreen = self:getScreenBox(char)
        
        if not onScreen then 
            self:clearPlayerDrawings(char)
            continue 
        end
        
        -- Box ESP based on type
        if self.espType == "2D Box" then
            d.box.Visible = true
            d.box.Size = Vector2.new(width, height)
            d.box.Position = Vector2.new(center.X - width/2, center.Y - height/2)
            d.box.Color = self.espColor
            
        elseif self.espType == "Corner Box" then
            local cs = width / 4
            local px, py = center.X - width/2, center.Y - height/2
            
            -- Top-left
            d.c1.From, d.c1.To = Vector2.new(px, py), Vector2.new(px + cs, py)
            d.c2.From, d.c2.To = Vector2.new(px, py), Vector2.new(px, py + cs)
            -- Top-right
            d.c3.From, d.c3.To = Vector2.new(px + width, py), Vector2.new(px + width - cs, py)
            d.c4.From, d.c4.To = Vector2.new(px + width, py), Vector2.new(px + width, py + cs)
            -- Bottom-left
            d.c5.From, d.c5.To = Vector2.new(px, py + height), Vector2.new(px + cs, py + height)
            d.c6.From, d.c6.To = Vector2.new(px, py + height), Vector2.new(px, py + height - cs)
            -- Bottom-right
            d.c7.From, d.c7.To = Vector2.new(px + width, py + height), Vector2.new(px + width - cs, py + height)
            d.c8.From, d.c8.To = Vector2.new(px + width, py + height), Vector2.new(px + width, py + height - cs)
            
            for i = 1, 8 do 
                local ln = d["c"..i]
                ln.Visible = true
                ln.Color = self.espColor
            end
            
        elseif self.espType == "3D Box" then
            local cf, size = char:GetBoundingBox()
            self:draw3DBox(d, cf, size, self.espColor)
        end
        
        -- Name ESP
        if self.nameEsp then
            d.name.Visible = true
            d.name.Text = player.Name
            d.name.Position = Vector2.new(center.X, center.Y + height/2 + 5)
            d.name.Color = self.nameColor
        end
        
        -- Health Bar
        if self.healthBar then
            local barW = 3
            local hp = hum.Health / hum.MaxHealth
            local hH = hp * height
            
            d.healthBG.Visible = true
            d.healthBG.Size = Vector2.new(barW + 2, height)
            d.healthBG.Position = Vector2.new(center.X + width/2 + 3, center.Y - height/2)
            
            d.healthMain.Visible = true
            d.healthMain.Size = Vector2.new(barW, hH)
            d.healthMain.Position = Vector2.new(center.X + width/2 + 4, center.Y + height/2 - hH)
            d.healthMain.Color = self.healthBarColor
        end
        
        -- Tracers
        if self.tracers then
            d.tracer.Visible = true
            d.tracer.From = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y)
            d.tracer.To = Vector2.new(center.X, center.Y + height/2)
            d.tracer.Color = self.tracerColor
        end
    end
end

-- Start the ESP render loop
function ESPLibrary:start()
    if self.renderConn then return end
    self.renderConn = RunService.RenderStepped:Connect(function()
        self:update()
    end)
end

-- Stop the ESP render loop
function ESPLibrary:stop()
    if self.renderConn then
        self.renderConn:Disconnect()
        self.renderConn = nil
    end
    self:clearAllDrawings()
end

-- Destroy all drawings and stop
function ESPLibrary:destroy()
    self:stop()
    for char, drawings in pairs(self.drawings) do
        for _, drawing in pairs(drawings) do
            if type(drawing) == "table" then
                for _, line in pairs(drawing) do
                    if line and line.Remove then line:Remove() end
                end
            elseif drawing and drawing.Remove then
                drawing:Remove()
            end
        end
    end
    self.drawings = {}
end

-- ================================================================
-- Example UI Setup (Using RbxImGui or your preferred UI library)
-- ================================================================

--[[
-- Load UI library
local RbxImGui = loadstring(game:HttpGet("https://raw.githubusercontent.com/RbxCheats/UiLib/refs/heads/main/RobloxUI.lua"))()

-- Create ESP instance
local esp = ESPLibrary.new()

-- Create window
local win = RbxImGui.new("ESP Trainer")
win:AddTab("ESP")

local espTab = win:Tab("ESP")

-- ESP Toggle
espTab:Toggle("ESP Enabled", false, function(v) 
    esp.enabled = v
    if v then esp:start() else esp:stop() end
end)

-- ESP Type
espTab:Dropdown("ESP Type", {"2D Box", "Corner Box", "3D Box"}, function(v) esp.espType = v end)

-- Features
espTab:Toggle("Name ESP", false, function(v) esp.nameEsp = v end)
espTab:Toggle("Tracers", false, function(v) esp.tracers = v end)
espTab:Toggle("Health Bar", false, function(v) esp.healthBar = v end)
espTab:Toggle("Ignore Local Player", true, function(v) esp.ignoreLocal = v end)

-- Color Pickers
espTab:Separator()
espTab:Label("Colors")
espTab:ColorPicker("Box Color", Color3.fromRGB(255, 255, 0), function(c) esp.espColor = c end)
espTab:ColorPicker("Name Color", Color3.fromRGB(255, 255, 255), function(c) esp.nameColor = c end)
espTab:ColorPicker("Tracer Color", Color3.fromRGB(255, 0, 0), function(c) esp.tracerColor = c end)
espTab:ColorPicker("Health Color", Color3.fromRGB(0, 255, 0), function(c) esp.healthBarColor = c end)

win:Render()
]]

-- Return the library
return ESPLibrary
