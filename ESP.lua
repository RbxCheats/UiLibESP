--[[
    ESP Library (Dynamic Team Color Patch)
    GitHub: https://raw.githubusercontent.com/RbxCheats/UiLibESP/refs/heads/main/ESP.lua
]]

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer
local camera      = workspace.CurrentCamera

local ESP = {}

-- ── Updated Settings Architecture ─────────────────────────────────────────────
ESP.Settings = {
    Enabled            = false,
    
    -- Box Properties
    ShowBox            = true,
    BoxType            = "2D",          
    UseTeamColor       = true,           -- Toggle to determine color logic
    BoxColor           = Color3.fromRGB(255, 255, 255), -- Global fallback
    FriendlyColor      = Color3.fromRGB(76, 175, 138),  -- Default Team Green
    EnemyColor         = Color3.fromRGB(224, 92, 92),   -- Default Enemy Red
    BoxOutlineColor    = Color3.fromRGB(0, 0, 0),
    BoxThickness       = 1,             

    -- Name
    ShowName           = false,
    NameColor          = Color3.fromRGB(255, 255, 255),

    -- Health bar
    ShowHealth         = false,
    HealthHighColor    = Color3.fromRGB(0, 255, 0),
    HealthLowColor     = Color3.fromRGB(255, 0, 0),
    HealthOutlineColor = Color3.fromRGB(0, 0, 0),

    -- Distance
    ShowDistance       = false,
    DistanceColor      = Color3.fromRGB(255, 255, 255),

    -- Tracer
    ShowTracer         = false,
    TracerColor        = Color3.fromRGB(255, 255, 255),
    TracerThickness    = 2,
    TracerPosition     = "Bottom",      

    -- Filters
    Teamcheck          = false,
    WallCheck          = false,
}

local cache       = {}   
local connection  = nil  
local started     = false

-- ── Helpers ───────────────────────────────────────────────────────────────────
local function newDrawing(class, props)
    local d = Drawing.new(class)
    for k, v in pairs(props) do d[k] = v end
    return d
end

local function safeRemove(d)
    if d and d.Remove then pcall(d.Remove, d) end
end

local function behindWall(player)
    local char = player.Character
    if not char then return false end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return false end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local exclude = {char}
    if localPlayer.Character then table.insert(exclude, localPlayer.Character) end
    params.FilterDescendantsInstances = exclude

    local result = workspace:Raycast(camera.CFrame.Position, root.Position - camera.CFrame.Position, params)
    return result ~= nil and result.Instance ~= nil and result.Instance:IsA("BasePart") and result.Instance.CanCollide
end

local function hideAll(e)
    e.box.Visible          = false
    e.boxOutline.Visible   = false
    e.name.Visible         = false
    e.healthOutline.Visible= false
    e.health.Visible       = false
    e.distance.Visible     = false
    e.tracer.Visible       = false
    for _, l in ipairs(e.boxLines) do l.Visible = false end
end

local function createESP(plr)
    local s = ESP.Settings
    cache[plr] = {
        box          = newDrawing("Square", {Color = s.BoxColor, Thickness = s.BoxThickness, Filled = false, Visible = false}),
        boxOutline   = newDrawing("Square", {Color = s.BoxOutlineColor, Thickness = 1, Filled = false, Visible = false}),
        boxLines     = {},
        name         = newDrawing("Text",   {Color = s.NameColor, Outline = true, Center = true, Size = 13, Visible = false}),
        healthOutline= newDrawing("Line",   {Color = s.HealthOutlineColor, Thickness = 3, Visible = false}),
        health       = newDrawing("Line",   {Thickness = 2, Visible = false}),
        distance     = newDrawing("Text",   {Color = s.DistanceColor, Size = 12, Outline = true, Center = true, Visible = false}),
        tracer       = newDrawing("Line",   {Color = s.TracerColor, Thickness = s.TracerThickness, Transparency = 1, Visible = false}),
    }
end

local function removeESP(plr)
    local e = cache[plr]
    if not e then return end
    safeRemove(e.box); safeRemove(e.boxOutline); safeRemove(e.name)
    safeRemove(e.healthOutline); safeRemove(e.health)
    safeRemove(e.distance); safeRemove(e.tracer)
    for _, l in ipairs(e.boxLines) do safeRemove(l) end
    cache[plr] = nil
end

-- ── Real-time Active Renderer Loop ────────────────────────────────────────────
local function update()
    local s = ESP.Settings

    for plr, e in pairs(cache) do
        local char  = plr.Character
        local hum   = char and char:FindFirstChildOfClass("Humanoid")
        local root  = char and char:FindFirstChild("HumanoidRootPart")
        local head  = char and char:FindFirstChild("Head")
        local valid = char and hum and root and head and hum.Health > 0

        local isTeammate  = (plr.Team == localPlayer.Team)
        local teamInvalid = s.Teamcheck and isTeammate
        local wall        = s.WallCheck and valid and behindWall(plr)

        if not (s.Enabled and valid and not teamInvalid and not wall) then
            hideAll(e)
        else
            local hrpPos, onScreen = camera:WorldToViewportPoint(root.Position)
            if not onScreen then
                hideAll(e)
            else
                -- Dynamic Color Calculation Pipeline
                local currentRenderColor = s.BoxColor
                if s.UseTeamColor then
                    currentRenderColor = isTeammate and s.FriendlyColor or s.EnemyColor
                end

                -- Box Positioning math bounds calculations
                local topY    = camera:WorldToViewportPoint(root.Position + Vector3.new(0,  2.6, 0)).Y
                local bottomY = camera:WorldToViewportPoint(root.Position - Vector3.new(0,  3.0, 0)).Y
                local h       = math.floor(bottomY - topY)
                local w       = math.floor(h * 0.65)
                local boxSize = Vector2.new(w, h)
                local boxPos  = Vector2.new(math.floor(hrpPos.X - w * 0.5), math.floor(hrpPos.Y - h * 0.5))

                -- Box Component Drawing
                if s.ShowBox then
                    if s.BoxType == "2D" then
                        for _, l in ipairs(e.boxLines) do l.Visible = false end
                        e.boxOutline.Position = Vector2.new(boxPos.X - 1, boxPos.Y - 1)
                        e.boxOutline.Size = Vector2.new(w + 2, h + 2)
                        e.boxOutline.Visible = true

                        e.box.Position = boxPos
                        e.box.Size = boxSize
                        e.box.Color = currentRenderColor
                        e.box.Thickness = s.BoxThickness
                        e.box.Visible = true
                    else
                        -- Corner Boxes Rendering Mode
                        e.box.Visible = false
                        e.boxOutline.Visible = false
                        if #e.boxLines == 0 then
                            for _ = 1, 8 do
                                table.insert(e.boxLines, newDrawing("Line", {
                                    Thickness = s.BoxThickness,
                                    Color = currentRenderColor,
                                    Transparency = 1,
                                    Visible = false,
                                }))
                            end
                        end
                        local lW = math.floor(w / 5)
                        local lH = math.floor(h / 6)
                        local L = e.boxLines
                        local bx, by = boxPos.X, boxPos.Y
                        local bx2, by2 = bx + w, by + h

                        L[1].From, L[1].To = Vector2.new(bx, by), Vector2.new(bx + lW, by)
                        L[2].From, L[2].To = Vector2.new(bx, by), Vector2.new(bx, by + lH)
                        L[3].From, L[3].To = Vector2.new(bx2, by), Vector2.new(bx2 - lW, by)
                        L[4].From, L[4].To = Vector2.new(bx2, by), Vector2.new(bx2, by + lH)
                        L[5].From, L[5].To = Vector2.new(bx, by2), Vector2.new(bx + lW, by2)
                        L[6].From, L[6].To = Vector2.new(bx, by2), Vector2.new(bx, by2 - lH)
                        L[7].From, L[7].To = Vector2.new(bx2, by2), Vector2.new(bx2 - lW, by2)
                        L[8].From, L[8].To = Vector2.new(bx2, by2), Vector2.new(bx2, by2 - lH)

                        for _, line in ipairs(L) do
                            line.Color = currentRenderColor
                            line.Visible = true
                        end
                    end
                else
                    e.box.Visible = false
                    e.boxOutline.Visible = false
                    for _, l in ipairs(e.boxLines) do l.Visible = false end
                end

                -- Match Tracer color to box settings dynamically
                if s.ShowTracer then
                    local startPos = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y)
                    if s.TracerPosition == "Top" then startPos = Vector2.new(camera.ViewportSize.X / 2, 0)
                    elseif s.TracerPosition == "Middle" then startPos = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2) end
                    e.tracer.From = startPos
                    e.tracer.To = Vector2.new(hrpPos.X, boxPos.Y + h)
                    e.tracer.Color = currentRenderColor
                    e.tracer.Visible = true
                else
                    e.tracer.Visible = false
                end

                -- Name Labels Display
                if s.ShowName then
                    e.name.Text = plr.Name
                    e.name.Position = Vector2.new(boxPos.X + w / 2, boxPos.Y - 16)
                    e.name.Visible = true
                else e.name.Visible = false end

                -- Health Bars Setup
                if s.ShowHealth then
                    local pct = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                    local barX = boxPos.X - 6
                    e.healthOutline.From = Vector2.new(barX, boxPos.Y)
                    e.healthOutline.To   = Vector2.new(barX, boxPos.Y + h)
                    e.healthOutline.Visible = true
                    e.health.From = Vector2.new(barX, boxPos.Y + h)
                    e.health.To   = Vector2.new(barX, boxPos.Y + h - math.floor(h * pct))
                    e.health.Color = s.HealthLowColor:Lerp(s.HealthHighColor, pct)
                    e.health.Visible = true
                else e.healthOutline.Visible = false; e.health.Visible = false end

                -- Distance Setup
                if s.ShowDistance then
                    local dist = math.floor((camera.CFrame.Position - root.Position).Magnitude)
                    e.distance.Text = tostring(dist) .. " studs"
                    e.distance.Position = Vector2.new(boxPos.X + w / 2, boxPos.Y + h + 2)
                    e.distance.Visible = true
                else e.distance.Visible = false end
            end
        end
    end
end

function ESP:Start()
    if started then return end
    started = true
    for _, plr in ipairs(Players:GetPlayers()) do if plr ~= localPlayer then createESP(plr) end end
    Players.PlayerAdded:Connect(function(plr) if plr ~= localPlayer then createESP(plr) end end)
    Players.PlayerRemoving:Connect(removeESP)
    connection = RunService.Heartbeat:Connect(update)
end

function ESP:Stop()
    if not started then return end; started = false
    if connection then connection:Disconnect(); connection = nil end
    for plr in pairs(cache) do removeESP(plr) end
end

function ESP:Toggle() self.Settings.Enabled = not self.Settings.Enabled end
function ESP:Set(key, value) if self.Settings[key] ~= nil then self.Settings[key] = value end end

return ESP
