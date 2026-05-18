--[[
    ESP Library (Dynamic Team Color Patch)
    GitHub: https://raw.githubusercontent.com/RbxCheats/UiLibESP/refs/heads/main/ESP.lua
]]

-- ── Services ──────────────────────────────────────────────────────────────────

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer
local camera      = workspace.CurrentCamera

-- ── Skeleton bone pairs ───────────────────────────────────────────────────────

local BONES = {
    {"Head",       "UpperTorso"},
    {"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
    {"UpperTorso", "LeftUpperArm"},  {"LeftUpperArm",  "LeftLowerArm"},  {"LeftLowerArm",  "LeftHand"},
    {"UpperTorso", "LowerTorso"},
    {"LowerTorso", "LeftUpperLeg"},  {"LeftUpperLeg",  "LeftLowerLeg"},  {"LeftLowerLeg",  "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"},
}

-- ── Library table ─────────────────────────────────────────────────────────────

local ESP = {}

-- ── Default settings ──────────────────────────────────────────────────────────

ESP.Settings = {
    -- Master switch
    Enabled            = false,

    -- Box Configurations (Default Team Green / Enemy Red Pre-Configured)
    ShowBox            = true,
    BoxType            = "2D",          -- "2D" or "Corner"
    UseTeamColor       = true,          -- Added Master Toggle Control
    BoxColor           = Color3.new(1, 1, 1),
    FriendlyColor      = Color3.fromRGB(0, 255, 0), -- Default Green
    EnemyColor         = Color3.fromRGB(255, 0, 0),  -- Default Red
    BoxOutlineColor    = Color3.new(0, 0, 0),
    BoxThickness       = 1,             

    -- Name
    ShowName           = false,
    NameColor          = Color3.new(1, 1, 1),

    -- Health bar
    ShowHealth         = false,
    HealthHighColor    = Color3.new(0, 1, 0),
    HealthLowColor     = Color3.new(1, 0, 0),
    HealthOutlineColor = Color3.new(0, 0, 0),

    -- Distance
    ShowDistance       = false,
    DistanceColor      = Color3.new(1, 1, 1),

    -- Skeleton
    ShowSkeletons      = false,
    SkeletonsColor     = Color3.new(1, 1, 1),

    -- Tracer
    ShowTracer         = false,
    TracerColor        = Color3.new(1, 1, 1),
    TracerThickness    = 2,
    TracerPosition     = "Bottom",      -- "Top", "Middle", "Bottom"

    -- Filters
    Teamcheck          = false,
    WallCheck          = false,
}

-- ── Internal state ────────────────────────────────────────────────────────────

local cache       = {}   -- [Player] = esp object
local connection  = nil  -- RenderStepped connection
local started     = false

-- ── Private helpers ───────────────────────────────────────────────────────────

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

    local result = workspace:Raycast(
        camera.CFrame.Position,
        root.Position - camera.CFrame.Position,
        params
    )
    return result ~= nil
        and result.Instance ~= nil
        and result.Instance:IsA("BasePart")
        and result.Instance.CanCollide
end

local function hideAll(e)
    e.box.Visible          = false
    e.boxOutline.Visible   = false
    e.name.Visible         = false
    e.healthOutline.Visible= false
    e.health.Visible       = false
    e.distance.Visible     = false
    e.tracer.Visible       = false
    for _, l  in ipairs(e.boxLines)      do l.Visible     = false end
    for _, ld in ipairs(e.skeletonLines) do ld[1].Visible = false end
end

-- ── ESP object creation / removal ─────────────────────────────────────────────

local function createESP(plr)
    local s = ESP.Settings
    cache[plr] = {
        box          = newDrawing("Square", {Color = s.BoxColor,        Thickness = s.BoxThickness, Filled = false, Visible = false}),
        boxOutline   = newDrawing("Square", {Color = s.BoxOutlineColor, Thickness = 1,              Filled = false, Visible = false}),
        boxLines     = {},
        name         = newDrawing("Text",   {Color = s.NameColor,       Outline = true, Center = true, Size = 13, Visible = false}),
        healthOutline= newDrawing("Line",   {Color = s.HealthOutlineColor, Thickness = 3, Visible = false}),
        health       = newDrawing("Line",   {Thickness = 2, Visible = false}),
        distance     = newDrawing("Text",   {Color = s.DistanceColor,   Size = 12, Outline = true, Center = true, Visible = false}),
        tracer       = newDrawing("Line",   {Color = s.TracerColor,     Thickness = s.TracerThickness, Transparency = 1, Visible = false}),
        skeletonLines= {},
    }
end

local function removeESP(plr)
    local e = cache[plr]
    if not e then return end
    safeRemove(e.box); safeRemove(e.boxOutline); safeRemove(e.name)
    safeRemove(e.healthOutline); safeRemove(e.health)
    safeRemove(e.distance); safeRemove(e.tracer)
    for _, l  in ipairs(e.boxLines)      do safeRemove(l)     end
    for _, ld in ipairs(e.skeletonLines) do safeRemove(ld[1]) end
    cache[plr] = nil
end

-- ── Per-frame update ──────────────────────────────────────────────────────────

local function update()
    local s = ESP.Settings

    for plr, e in pairs(cache) do
        local char  = plr.Character
        local hum   = char and char:FindFirstChildOfClass("Humanoid")
        local root  = char and char:FindFirstChild("HumanoidRootPart")
        local head  = char and char:FindFirstChild("Head")
        local valid = char and hum and root and head and hum.Health > 0

        local isFriendly  = (plr.Team == localPlayer.Team)
        local teamInvalid = s.Teamcheck and isFriendly
        local wall        = s.WallCheck and valid and behindWall(plr)

        if not (s.Enabled and valid and not teamInvalid and not wall) then
            hideAll(e)
        else
            local hrpPos, onScreen = camera:WorldToViewportPoint(root.Position)
            if not onScreen then
                hideAll(e)
            else
                -- Determine Dynamic Processing Colors Individually 
                local runtimeColor = s.BoxColor
                if s.UseTeamColor then
                    runtimeColor = isFriendly and s.FriendlyColor or s.EnemyColor
                end

                -- Box dimensions
                local topY    = camera:WorldToViewportPoint(root.Position + Vector3.new(0,  2.6, 0)).Y
                local bottomY = camera:WorldToViewportPoint(root.Position - Vector3.new(0,  3.0, 0)).Y
                local h       = math.floor(bottomY - topY)
                local w       = math.floor(h * 0.65)
                local boxSize = Vector2.new(w, h)
                local boxPos  = Vector2.new(
                    math.floor(hrpPos.X - w * 0.5),
                    math.floor(hrpPos.Y - h * 0.5)
                )

                -- ── BOX ──────────────────────────────────────────────────────
                if s.ShowBox then
                    if s.BoxType == "2D" then
                        -- Hide corner lines
                        for _, l in ipairs(e.boxLines) do l.Visible = false end

                        -- Outline: 1 px outside the inner box on all sides
                        e.boxOutline.Position  = Vector2.new(boxPos.X - 1, boxPos.Y - 1)
                        e.boxOutline.Size      = Vector2.new(w + 2, h + 2)
                        e.boxOutline.Color     = s.BoxOutlineColor
                        e.boxOutline.Thickness = 1
                        e.boxOutline.Visible   = true

                        -- Inner colored box
                        e.box.Position  = boxPos
                        e.box.Size      = boxSize
                        e.box.Color     = runtimeColor
                        e.box.Thickness = s.BoxThickness
                        e.box.Visible   = true

                    else -- Corner
                        e.box.Visible        = false
                        e.boxOutline.Visible = false

                        -- Create corner lines on first use
                        if #e.boxLines == 0 then
                            for _ = 1, 8 do
                                table.insert(e.boxLines, newDrawing("Line", {
                                    Thickness    = s.BoxThickness,
                                    Color        = runtimeColor,
                                    Transparency = 1,
                                    Visible      = false,
                                }))
                            end
                        end

                        local lW   = math.floor(w / 5)
                        local lH   = math.floor(h / 6)
                        local L    = e.boxLines
                        local bx   = boxPos.X;   local by  = boxPos.Y
                        local bx2  = bx + w;     local by2 = by + h

                        -- Top-left
                        L[1].From, L[1].To = Vector2.new(bx,     by),     Vector2.new(bx+lW,  by)
                        L[2].From, L[2].To = Vector2.new(bx,     by),     Vector2.new(bx,     by+lH)
                        -- Top-right
                        L[3].From, L[3].To = Vector2.new(bx2-lW, by),     Vector2.new(bx2,    by)
                        L[4].From, L[4].To = Vector2.new(bx2,    by),     Vector2.new(bx2,    by+lH)
                        -- Bottom-left
                        L[5].From, L[5].To = Vector2.new(bx,     by2-lH), Vector2.new(bx,     by2)
                        L[6].From, L[6].To = Vector2.new(bx,     by2),    Vector2.new(bx+lW,  by2)
                        -- Bottom-right
                        L[7].From, L[7].To = Vector2.new(bx2-lW, by2),    Vector2.new(bx2,    by2)
                        L[8].From, L[8].To = Vector2.new(bx2,    by2-lH), Vector2.new(bx2,    by2)

                        for _, l in ipairs(L) do
                            l.Color     = runtimeColor
                            l.Thickness = s.BoxThickness
                            l.Visible   = true
                        end
                    end
                else
                    e.box.Visible        = false
                    e.boxOutline.Visible = false
                    for _, l in ipairs(e.boxLines) do l.Visible = false end
                end

                -- ── NAME ─────────────────────────────────────────────────────
                if s.ShowName then
                    e.name.Text     = string.lower(plr.Name)
                    e.name.Position = Vector2.new(boxPos.X + w * 0.5, boxPos.Y - 16)
                    e.name.Color    = s.NameColor
                    e.name.Visible  = true
                else
                    e.name.Visible = false
                end

                -- ── HEALTH BAR ───────────────────────────────────────────────
                if s.ShowHealth then
                    local pct = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                    local bx  = boxPos.X - 6

                    e.healthOutline.From    = Vector2.new(bx, boxPos.Y + h)
                    e.healthOutline.To      = Vector2.new(bx, boxPos.Y)
                    e.healthOutline.Color   = s.HealthOutlineColor
                    e.healthOutline.Visible = true

                    e.health.From    = Vector2.new(bx, boxPos.Y + h)
                    e.health.To      = Vector2.new(bx, boxPos.Y + h - h * pct)
                    e.health.Color   = s.HealthLowColor:Lerp(s.HealthHighColor, pct)
                    e.health.Visible = true
                else
                    e.healthOutline.Visible = false
                    e.health.Visible        = false
                end

                -- ── DISTANCE ─────────────────────────────────────────────────
                if s.ShowDistance then
                    local dist = (camera.CFrame.Position - root.Position).Magnitude
                    e.distance.Text     = string.format("%.0f studs", dist)
                    e.distance.Position = Vector2.new(boxPos.X + w * 0.5, boxPos.Y + h + 5)
                    e.distance.Color    = s.DistanceColor
                    e.distance.Visible  = true
                else
                    e.distance.Visible = false
                end

                -- ── SKELETON ─────────────────────────────────────────────────
                if s.ShowSkeletons then
                    if #e.skeletonLines == 0 then
                        for _, bp in ipairs(BONES) do
                            table.insert(e.skeletonLines, {
                                newDrawing("Line", {
                                    Thickness    = 1,
                                    Color        = s.SkeletonsColor,
                                    Transparency = 1,
                                    Visible      = false,
                                }),
                                bp[1], bp[2]
                            })
                        end
                    end

                    for _, ld in ipairs(e.skeletonLines) do
                        local line, nameA, nameB = ld[1], ld[2], ld[3]
                        local partA = char:FindFirstChild(nameA)
                        local partB = char:FindFirstChild(nameB)
                        if partA and partB then
                            local sA, aOn = camera:WorldToViewportPoint(partA.Position)
                            local sB, bOn = camera:WorldToViewportPoint(partB.Position)
                            if aOn and bOn then
                                line.From    = Vector2.new(sA.X, sA.Y)
                                line.To      = Vector2.new(sB.X, sB.Y)
                                line.Color   = s.SkeletonsColor
                                line.Visible = true
                            else
                                line.Visible = false
                            end
                        else
                            line.Visible = false
                        end
                    end
                else
                    for _, ld in ipairs(e.skeletonLines) do ld[1].Visible = false end
                end

                -- ── TRACER ───────────────────────────────────────────────────
                if s.ShowTracer then
                    local vp    = camera.ViewportSize
                    local origY = s.TracerPosition == "Top"    and 0
                               or s.TracerPosition == "Middle" and vp.Y * 0.5
                               or vp.Y

                    e.tracer.From      = Vector2.new(vp.X * 0.5, origY)
                    e.tracer.To        = Vector2.new(boxPos.X + w * 0.5, boxPos.Y + h)
                    e.tracer.Color     = runtimeColor
                    e.tracer.Thickness = s.TracerThickness
                    e.tracer.Visible   = true
                else
                    e.tracer.Visible = false
                end
            end
        end
    end
end

-- ── Public API ────────────────────────────────────────────────────────────────

function ESP:Start()
    if started then return end
    started = true

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= localPlayer then createESP(plr) end
    end

    Players.PlayerAdded:Connect(function(plr)
        if plr ~= localPlayer then createESP(plr) end
    end)
    Players.PlayerRemoving:Connect(removeESP)

    connection = RunService.Heartbeat:Connect(update)
end

function ESP:Stop()
    if not started then return end
    started = false

    if connection then connection:Disconnect(); connection = nil end

    for plr in pairs(cache) do removeESP(plr) end
end

function ESP:Toggle()
    self.Settings.Enabled = not self.Settings.Enabled
end

function ESP:SetSettings(tbl)
    for k, v in pairs(tbl) do
        if self.Settings[k] ~= nil then
            self.Settings[k] = v
        end
    end
end

function ESP:Set(key, value)
    if self.Settings[key] ~= nil then
        self.Settings[key] = value
    end
end

function ESP:Get(key)
    return self.Settings[key]
end

return ESP
