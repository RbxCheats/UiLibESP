-- ================================================================
-- Advanced ESP Library
-- Features: 2D Box, Corner Box, Name ESP, Tracers, Health Bar
-- ================================================================

local ESPLibrary = {}
ESPLibrary.__index = ESPLibrary

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local lp = Players.LocalPlayer

local function createDrawing(class, props)
    local d = Drawing.new(class)
    for k, v in pairs(props or {}) do 
        d[k] = v
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

function ESPLibrary:getAllBodyParts(character)
    local parts = {}
    local partNames = {
        "Head", "UpperTorso", "LowerTorso", "HumanoidRootPart",
        "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm",
        "LeftHand", "RightHand", "LeftUpperLeg", "RightUpperLeg",
        "LeftLowerLeg", "RightLowerLeg", "LeftFoot", "RightFoot"
    }
    
    for _, name in ipairs(partNames) do
        local part = character:FindFirstChild(name)
        if part then
            table.insert(parts, part)
        end
    end
    
    return parts
end

function ESPLibrary:getBoundingBox(character)
    local camera = Workspace.CurrentCamera
    if not camera then return nil end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then
        return nil
    end
    
    local parts = self:getAllBodyParts(character)
    if #parts == 0 then
        local root = character:FindFirstChild("HumanoidRootPart")
        if root then
            local pos, onScreen = camera:WorldToViewportPoint(root.Position)
            if onScreen then
                return {
                    X = pos.X - 50,
                    Y = pos.Y - 100,
                    Width = 100,
                    Height = 200,
                    OnScreen = true,
                    CenterX = pos.X,
                    CenterY = pos.Y
                }
            end
        end
        return nil
    end
    
    local minX, maxX = math.huge, -math.huge
    local minY, maxY = math.huge, -math.huge
    local anyOnScreen = false
    
    for _, part in ipairs(parts) do
        local pos, onScreen = camera:WorldToViewportPoint(part.Position)
        if onScreen then
            anyOnScreen = true
            minX = math.min(minX, pos.X)
            maxX = math.max(maxX, pos.X)
            minY = math.min(minY, pos.Y)
            maxY = math.max(maxY, pos.Y)
        end
    end
    
    if not anyOnScreen then
        return nil
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
    
    if width < 2 or height < 2 then
        return nil
    end
    
    return {
        X = minX,
        Y = minY,
        Width = width,
        Height = height,
        CenterX = centerX,
        CenterY = centerY,
        OnScreen = true
    }
end

function ESPLibrary:clearDrawings(character)
    local d = self.drawings[character]
    if not d then return end
    
    for _, drawing in pairs(d) do
        if drawing then
            drawing.Visible = false
        end
    end
end

function ESPLibrary:clearAllDrawings()
    for character, drawings in pairs(self.drawings) do
        self:clearDrawings(character)
    end
end

function ESPLibrary:setupDrawings(character)
    if self.drawings[character] then
        return
    end
    
    self.drawings[character] = {
        box = createDrawing("Square", {Thickness = 1.5, Filled = false, Visible = false}),
        name = createDrawing("Text", {Size = 14, Center = true, Outline = true, Font = 2, Visible = false}),
        tracer = createDrawing("Line", {Thickness = 1.5, Visible = false}),
        healthBg = createDrawing("Square", {Thickness = 1, Filled = true, Color = Color3.fromRGB(0, 0, 0), Visible = false}),
        healthFill = createDrawing("Square", {Thickness = 1, Filled = true, Visible = false}),
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

function ESPLibrary:draw2DBox(drawings, bounds, color)
    drawings.box.Visible = true
    drawings.box.Size = Vector2.new(bounds.Width, bounds.Height)
    drawings.box.Position = Vector2.new(bounds.X, bounds.Y)
    drawings.box.Color = color
end

function ESPLibrary:drawCornerBox(drawings, bounds, color, distance)
    local offset = math.clamp(1 / math.max(distance, 1) * 750, 10, 150)
    local thickness = math.clamp(1 / math.max(distance, 1) * 100, 1, 3)
    
    local x, y = bounds.X, bounds.Y
    local w, h = bounds.Width, bounds.Height
    
    drawings.c1.From = Vector2.new(x, y)
    drawings.c1.To = Vector2.new(x + offset, y)
    drawings.c2.From = Vector2.new(x, y)
    drawings.c2.To = Vector2.new(x, y + offset)
    
    drawings.c3.From = Vector2.new(x + w, y)
    drawings.c3.To = Vector2.new(x + w - offset, y)
    drawings.c4.From = Vector2.new(x + w, y)
    drawings.c4.To = Vector2.new(x + w, y + offset)
    
    drawings.c5.From = Vector2.new(x, y + h)
    drawings.c5.To = Vector2.new(x + offset, y + h)
    drawings.c6.From = Vector2.new(x, y + h)
    drawings.c6.To = Vector2.new(x, y + h - offset)
    
    drawings.c7.From = Vector2.new(x + w, y + h)
    drawings.c7.To = Vector2.new(x + w - offset, y + h)
    drawings.c8.From = Vector2.new(x + w, y + h)
    drawings.c8.To = Vector2.new(x + w, y + h - offset)
    
    for i = 1, 8 do
        local line = drawings["c"..i]
        line.Visible = true
        line.Color = color
        line.Thickness = thickness
    end
end

function ESPLibrary:drawName(drawings, playerName, bounds, color)
    drawings.name.Visible = true
    drawings.name.Text = playerName
    drawings.name.Position = Vector2.new(bounds.CenterX, bounds.Y - 15)
    drawings.name.Color = color
end

function ESPLibrary:drawHealthBar(drawings, healthPercent, bounds, color)
    local barWidth = 4
    local barHeight = bounds.Height * healthPercent
    local barX = bounds.X + bounds.Width + 3
    local barY = bounds.Y + bounds.Height - barHeight
    
    drawings.healthBg.Visible = true
    drawings.healthBg.Size = Vector2.new(barWidth + 2, bounds.Height)
    drawings.healthBg.Position = Vector2.new(barX - 1, bounds.Y)
    
    drawings.healthFill.Visible = true
    drawings.healthFill.Size = Vector2.new(barWidth, barHeight)
    drawings.healthFill.Position = Vector2.new(barX, barY)
    
    local healthColor = color
    if healthPercent <= 0.3 then
        healthColor = Color3.fromRGB(255, 50, 50)
    elseif healthPercent <= 0.6 then
        healthColor = Color3.fromRGB(255, 165, 0)
    end
    drawings.healthFill.Color = healthColor
end

function ESPLibrary:drawTracer(drawings, camera, bounds, color)
    local screenBottom = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y)
    local targetPos = Vector2.new(bounds.CenterX, bounds.Y + bounds.Height)
    
    drawings.tracer.Visible = true
    drawings.tracer.From = screenBottom
    drawings.tracer.To = targetPos
    drawings.tracer.Color = color
end

function ESPLibrary:hideAllDrawings(drawings)
    if drawings.box then drawings.box.Visible = false end
    if drawings.name then drawings.name.Visible = false end
    if drawings.tracer then drawings.tracer.Visible = false end
    if drawings.healthBg then drawings.healthBg.Visible = false end
    if drawings.healthFill then drawings.healthFill.Visible = false end
    
    for i = 1, 8 do
        local line = drawings["c"..i]
        if line then line.Visible = false end
    end
end

function ESPLibrary:update()
    if not self.enabled then
        self:clearAllDrawings()
        return
    end
    
    local camera = Workspace.CurrentCamera
    if not camera then return end
    
    local activeCharacters = {}
    
    for _, player in ipairs(Players:GetPlayers()) do
        if self.ignoreLocal and player == lp then
            goto continue
        end
        
        local character = player.Character
        if not character then
            goto continue
        end
        
        activeCharacters[character] = true
        
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        local root = character:FindFirstChild("HumanoidRootPart")
        
        if not humanoid or not root or humanoid.Health <= 0 then
            if self.drawings[character] then
                self:hideAllDrawings(self.drawings[character])
            end
            goto continue
        end
        
        self:setupDrawings(character)
        local drawings = self.drawings[character]
        local bounds = self:getBoundingBox(character)
        
        if not bounds or not bounds.OnScreen then
            self:hideAllDrawings(drawings)
            goto continue
        end
        
        local distance = (camera.CFrame.Position - root.Position).Magnitude
        local healthPercent = humanoid.Health / humanoid.MaxHealth
        
        if self.espType == "2D Box" then
            for i = 1, 8 do
                local line = drawings["c"..i]
                if line then line.Visible = false end
            end
            self:draw2DBox(drawings, bounds, self.espColor)
        elseif self.espType == "Corner Box" then
            drawings.box.Visible = false
            self:drawCornerBox(drawings, bounds, self.espColor, distance)
        end
        
        if self.nameEsp then
            self:drawName(drawings, player.Name, bounds, self.nameColor)
        else
            drawings.name.Visible = false
        end
        
        if self.healthBar then
            self:drawHealthBar(drawings, healthPercent, bounds, self.healthBarColor)
        else
            if drawings.healthBg then drawings.healthBg.Visible = false end
            if drawings.healthFill then drawings.healthFill.Visible = false end
        end
        
        if self.tracers then
            self:drawTracer(drawings, camera, bounds, self.tracerColor)
        else
            if drawings.tracer then drawings.tracer.Visible = false end
        end
        
        ::continue::
    end
    
    for character, drawings in pairs(self.drawings) do
        if not activeCharacters[character] then
            self:hideAllDrawings(drawings)
        end
    end
end

function ESPLibrary:start()
    if self.renderConn then
        self.renderConn:Disconnect()
    end
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
    for character, drawings in pairs(self.drawings) do
        for _, drawing in pairs(drawings) do
            if drawing and drawing.Remove then
                drawing:Remove()
            end
        end
    end
    self.drawings = {}
end

return ESPLibrary
