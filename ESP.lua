-- ================================================================
-- Standalone ESP Library
-- Supports: 2D Box, Corner Box, Name ESP, Tracers, Health Bar
-- ================================================================

local ESPLibrary = {}
ESPLibrary.__index = ESPLibrary

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local lp = Players.LocalPlayer

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

function ESPLibrary.new()
    local self = setmetatable({}, ESPLibrary)
    
    self.enabled = false
    self.espType = "2D Box"
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

function ESPLibrary:getFullBodyBounds(char)
    local camera = workspace.CurrentCamera
    if not camera then return nil, nil, nil, false end
    
    local parts = {
        "Head",
        "UpperTorso",
        "LowerTorso", 
        "HumanoidRootPart",
        "LeftUpperArm",
        "RightUpperArm",
        "LeftLowerArm",
        "RightLowerArm",
        "LeftHand",
        "RightHand",
        "LeftUpperLeg",
        "RightUpperLeg",
        "LeftLowerLeg",
        "RightLowerLeg",
        "LeftFoot",
        "RightFoot"
    }
    
    local validParts = {}
    local minX, maxX = math.huge, -math.huge
    local minY, maxY = math.huge, -math.huge
    local anyOnScreen = false
    
    for _, partName in ipairs(parts) do
        local part = char:FindFirstChild(partName)
        if part then
            local screenPos, onScreen = camera:WorldToViewportPoint(part.Position)
            if onScreen then
                anyOnScreen = true
                minX = math.min(minX, screenPos.X)
                maxX = math.max(maxX, screenPos.X)
                minY = math.min(minY, screenPos.Y)
                maxY = math.max(maxY, screenPos.Y)
            end
            table.insert(validParts, part)
        end
    end
    
    if not anyOnScreen then
        local root = char:FindFirstChild("HumanoidRootPart")
        if root then
            local screenPos, onScreen = camera:WorldToViewportPoint(root.Position)
            if onScreen then
                anyOnScreen = true
                minX, maxX = screenPos.X - 50, screenPos.X + 50
                minY, maxY = screenPos.Y - 100, screenPos.Y + 100
            end
        end
    end
    
    if not anyOnScreen then
        return nil, nil, nil, false
    end
    
    local padding = 5
    minX = math.max(0, minX - padding)
    minY = math.max(0, minY - padding)
    maxX = math.min(camera.ViewportSize.X, maxX + padding)
    maxY = math.min(camera.ViewportSize.Y, maxY + padding)
    
    local width = maxX - minX
    local height = maxY - minY
    local centerX = (minX + maxX) / 2
    local centerY = (minY + maxY) / 2
    
    if width < 10 or height < 10 then
        return nil, nil, nil, false
    end
    
    return Vector2.new(centerX, centerY), width, height, true
end

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
    end
end

function ESPLibrary:clearAllDrawings()
    for char, cache in pairs(self.drawings) do
        self:clearPlayerDrawings(char)
    end
end

function ESPLibrary:createDrawingsForPlayer(char)
    if self.drawings[char] then return end
    
    self.drawings[char] = {
        box = createDrawing("Square", {Thickness = 1.5, Filled = false, Visible = false}),
        name = createDrawing("Text", {Size = 14, Center = true, Outline = true, Font = 2, Visible = false}),
        tracer = createDrawing("Line", {Thickness = 1.5, Visible = false}),
        healthBG = createDrawing("Square", {Thickness = 1, Filled = true, Color = Color3.new(0,0,0), Visible = false}),
        healthMain = createDrawing("Square", {Thickness = 1, Filled = true, Visible = false}),
        c1 = createDrawing("Line", {Thickness = 2, Visible = false}),
        c2 = createDrawing("Line", {Thickness = 2, Visible = false}),
        c3 = createDrawing("Line", {Thickness = 2, Visible = false}),
        c4 = createDrawing("Line", {Thickness = 2, Visible = false}),
        c5 = createDrawing("Line", {Thickness = 2, Visible = false}),
        c6 = createDrawing("Line", {Thickness = 2, Visible = false}),
        c7 = createDrawing("Line", {Thickness = 2, Visible = false}),
        c8 = createDrawing("Line", {Thickness = 2, Visible = false})
    }
end

function ESPLibrary:update()
    if not self.enabled then
        self:clearAllDrawings()
        return
    end
    
    local camera = workspace.CurrentCamera
    if not camera then return end
    
    local currentCharacters = {}
    
    for _, player in ipairs(Players:GetPlayers()) do
        if self.ignoreLocal and player == lp then continue end
        
        local char = player.Character
        if not char then continue end
        
        currentCharacters[char] = true
        
        local hum = char:FindFirstChildOfClass("Humanoid")
        local root = char:FindFirstChild("HumanoidRootPart")
        
        if not (hum and root and hum.Health > 0) then
            self:clearPlayerDrawings(char)
            continue
        end
        
        self:createDrawingsForPlayer(char)
        local d = self.drawings[char]
        local center, width, height, onScreen = self:getFullBodyBounds(char)
        
        if not onScreen then 
            self:clearPlayerDrawings(char)
            continue
        end
        
        if self.espType == "2D Box" then
            d.box.Visible = true
            d.box.Size = Vector2.new(width, height)
            d.box.Position = Vector2.new(center.X - width/2, center.Y - height/2)
            d.box.Color = self.espColor
        elseif self.espType == "Corner Box" then
            local cs = math.min(width / 4, 20)
            local px, py = center.X - width/2, center.Y - height/2
            
            d.c1.From, d.c1.To = Vector2.new(px, py), Vector2.new(px + cs, py)
            d.c2.From, d.c2.To = Vector2.new(px, py), Vector2.new(px, py + cs)
            d.c3.From, d.c3.To = Vector2.new(px + width, py), Vector2.new(px + width - cs, py)
            d.c4.From, d.c4.To = Vector2.new(px + width, py), Vector2.new(px + width, py + cs)
            d.c5.From, d.c5.To = Vector2.new(px, py + height), Vector2.new(px + cs, py + height)
            d.c6.From, d.c6.To = Vector2.new(px, py + height), Vector2.new(px, py + height - cs)
            d.c7.From, d.c7.To = Vector2.new(px + width, py + height), Vector2.new(px + width - cs, py + height)
            d.c8.From, d.c8.To = Vector2.new(px + width, py + height), Vector2.new(px + width, py + height - cs)
            
            for i = 1, 8 do 
                local ln = d["c"..i]
                ln.Visible = true
                ln.Color = self.espColor
            end
        end
        
        if self.nameEsp then
            d.name.Visible = true
            d.name.Text = player.Name
            d.name.Position = Vector2.new(center.X, center.Y - height/2 - 15)
            d.name.Color = self.nameColor
        end
        
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
            
            local healthColor = self.healthBarColor
            if hp <= 0.3 then
                healthColor = Color3.fromRGB(255, 50, 50)
            elseif hp <= 0.6 then
                healthColor = Color3.fromRGB(255, 165, 0)
            end
            d.healthMain.Color = healthColor
        end
        
        if self.tracers then
            d.tracer.Visible = true
            d.tracer.From = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y)
            d.tracer.To = Vector2.new(center.X, center.Y + height/2)
            d.tracer.Color = self.tracerColor
        end
    end
    
    for char, _ in pairs(self.drawings) do
        if not currentCharacters[char] then
            self:clearPlayerDrawings(char)
        end
    end
end

function ESPLibrary:start()
    if self.renderConn then return end
    self.renderConn = RunService.RenderStepped:Connect(function()
        self:update()
    end)
end

function ESPLibrary:stop()
    if self.renderConn then
        self.renderConn:Disconnect()
        self.renderConn = nil
    end
    self:clearAllDrawings()
end

function ESPLibrary:destroy()
    self:stop()
    for char, drawings in pairs(self.drawings) do
        for _, drawing in pairs(drawings) do
            if drawing and drawing.Remove then
                drawing:Remove()
            end
        end
    end
    self.drawings = {}
end

return ESPLibrary
