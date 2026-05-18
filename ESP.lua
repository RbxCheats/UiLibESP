--[[
    ESP Library (Fixed Team Color Variant)
    GitHub: https://raw.githubusercontent.com/RbxCheats/UiLibESP/refs/heads/main/ESP.lua
]]

-- ── Services ──────────────────────────────────────────────────────────────────

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer
local camera      = workspace.CurrentCamera

-- Custom Gameplay Layout Folder
local CharacterFolder = workspace:WaitForChild("Gameplay"):WaitForChild("Characters")

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
    Enabled            = false,

    -- Box
    ShowBox            = true,
    BoxType            = "2D",          -- "2D" or "Corner"
    FriendlyColor      = Color3.fromRGB(0, 255, 0),
    EnemyColor         = Color3.fromRGB(255, 0, 0),
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
    TracerThickness    = 2,
    TracerPosition     = "Bottom",      -- "Top", "Middle", "Bottom"

    -- Filters
    Teamcheck          = false,
    WallCheck          = false,
}

-- ── Internal state ────────────────────────────────────────────────────────────

local cache       = {}   -- [Player] = esp object
local connection  = nil  -- RenderStepped/Heartbeat connection
local started     = false

-- ── Private helpers ───────────────────────────────────────────────────────────

local function GetCharacter(plr)
    if not plr then return nil end
    return CharacterFolder:FindFirstChild(plr.Name) or plr.Character
end

local function IsFriendly(plr)
    if not plr then return false end
    if localPlayer.Team and plr.Team then
        return localPlayer.Team == plr.Team
    end
    local myTeam = localPlayer:GetAttribute("Team") or (localPlayer.Team and localPlayer.Team.Name)
    local targetTeam = plr:GetAttribute("Team") or (plr.Team and plr.Team.Name)
    if myTeam and targetTeam then
        return myTeam == targetTeam
    end
    return false
end

local function newDrawing(class, props)
    local d = Drawing.new(class)
    for k, v in pairs(props) do d[k] = v end
    return d
end

local function safeRemove(d)
    if d and d.Remove then pcall(d.Remove, d) end
end

local function behindWall(player)
    local char = GetCharacter(player)
    if not char then return false end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return false end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local exclude = {char, camera}
    local myChar = GetCharacter(localPlayer)
    if myChar then table.insert(exclude, myChar) end
    params.FilterDescendantsInstances = exclude

    local result = workspace:Raycast(
        camera.CFrame.Position,
        root.Position - camera.CFrame.Position,
        params
    )
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
    for _, l  in ipairs(e.boxLines)      do l.Visible     = false end
    for _, ld in ipairs(e.skeletonLines) do ld[1].Visible = false end
end

-- ── ESP object creation / removal ─────────────────────────────────────────────

local function createESP(plr)
    local s = ESP.Settings
    cache[plr] = {
        box          = newDrawing("Square", {Thickness = s.BoxThickness, Filled = false, Visible = false}),
        boxOutline   = newDrawing("Square", {Color = s.BoxOutlineColor, Thickness = 1,              Filled = false, Visible = false}),
        boxLines     = {},
        name         = newDrawing("Text",   {Color = s.NameColor,       Outline = true, Center = true, Size = 13, Visible = false}),
        healthOutline= newDrawing("Line",   {Color = s.HealthOutlineColor, Thickness = 3, Visible = false}),
        health       = newDrawing("Line",   {Thickness = 2, Visible = false}),
        distance     = newDrawing("Text",   {Color = s.DistanceColor,   Size = 12, Outline = true, Center = true, Visible = false}),
        tracer       = newDrawing("Line",   {Thickness = s.TracerThickness, Transparency = 1, Visible = false}),
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
    if not s.Enabled then
        for _, e in pairs(cache) do hideAll(e) end
        return
    end

    for plr, e in pairs(cache) do
        local char  = GetCharacter(plr)
        local hum   = char and char:FindFirstChildOfClass("Humanoid")
        local root  = char and char:FindFirstChild("HumanoidRootPart")
        local head  = char and char:FindFirstChild("Head")
        local valid = char and hum and root and head and hum.Health > 0

        local teamInvalid = s.Teamcheck and IsFriendly(plr)
        local wall        = s.WallCheck and valid and behindWall(plr)

        if not (valid and not teamInvalid and not wall) then
            hideAll(e)
        else
            local hrpPos, onScreen = camera:WorldToViewportPoint(root.Position)
            if not onScreen then
                hideAll(e)
            else
                -- Resolve individual target color instantly
                local dynamicColor = IsFriendly(plr) and s.FriendlyColor or s.EnemyColor

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
                        for _, l in ipairs(e.boxLines) do l.Visible = false end
                        e.boxOutline.Position = Vector2.new(boxPos.X - 1, boxPos.Y - 1)
                        e.boxOutline.Size = Vector2.new(w + 2, h + 2)
                        e.boxOutline.Visible = true

                        e.box.Position = boxPos
                        e.box.Size = boxSize
                        e.box.Color = dynamicColor
                        e.box.Thickness = s.BoxThickness
                        e.box.Visible = true
                    else
                        -- Corner Boxes
                        e.box.Visible = false
                        e.boxOutline.Visible = false
                        if #e.boxLines == 0 then
                            for _ = 1, 8 do
                                table.insert(e.boxLines, newDrawing("Line", {
                                    Thickness = s.BoxThickness,
                                    Transparency = 1,
                                    Visible = false,
                                }))
                            end
                        end
                        local lAnc = math.floor(w / 5)
                        local L = e.boxLines
                        local bx, by = boxPos.X, boxPos.Y
                        local bx2, by2 = bx + w, by + h

                        L[1].From, L[1].To = Vector2.new(bx, by), Vector2.new(bx + lAnc, by)
                        L[2].From, L[2].To = Vector2.new(bx, by), Vector2.new(bx, by + lAnc)
                        L[3].From, L[3].To = Vector2.new(bx2, by), Vector2.new(bx2 - lAnc, by)
                        L[4].From, L[4].To = Vector2.new(bx2, by), Vector2.new(bx2, by + lAnc)
                        L[5].From, L[5].To = Vector2.new(bx, by2), Vector2.new(bx + lAnc, by2)
                        L[6].From, L[6].To = Vector2.new(bx, by2), Vector2.new(bx, by2 - lAnc)
                        L[7].From, L[7].To = Vector2.new(bx2, by2), Vector2.new(bx2 - lAnc, by2)
                        L[8].From, L[8].To = Vector2.new(bx2, by2), Vector2.new(bx2, by2 - lAnc)

                        for _, line in ipairs(L) do
                            line.Color = dynamicColor
                            line.Visible = true
                        end
                    end
                else
                    e.box.Visible = false
                    e.boxOutline.Visible = false
                    for _, l in ipairs(e.boxLines) do l.Visible = false end
                end

                -- ── NAME ─────────────────────────────────────────────────────
                if s.ShowName then
                    e.name.Text = plr.Name
                    e.name.Position = Vector2.new(boxPos.X + w / 2, boxPos.Y - 16)
                    e.name.Color = s.NameColor
                    e.name.Visible = true
                else
                    e.name.Visible = false
                end

                -- ── HEALTH BAR ───────────────────────────────────────────────
                if s.ShowHealth then
                    local pct = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                    local hBarH = math.floor(h * pct)
                    local barX = boxPos.X - 6

                    e.healthOutline.From = Vector2.new(barX, boxPos.Y)
                    e.healthOutline.To   = Vector2.new(barX, boxPos.Y + h)
                    e.healthOutline.Visible = true

                    e.health.From = Vector2.new(barX, boxPos.Y + h)
                    e.health.To   = Vector2.new(barX, boxPos.Y + h - hBarH)
                    e.health.Color = s.HealthLowColor:Lerp(s.HealthHighColor, pct)
                    e.health.Visible = true
                else
                    e.healthOutline.Visible = false
                    e.health.Visible = false
                end

                -- ── DISTANCE ─────────────────────────────────────────────────
                if s.ShowDistance then
                    local dist = math.floor((camera.CFrame.Position - root.Position).Magnitude)
                    e.distance.Text = tostring(dist) .. " studs"
                    e.distance.Position = Vector2.new(boxPos.X + w / 2, boxPos.Y + h + 2)
                    e.distance.Color = s.DistanceColor
                    e.distance.Visible = true
                else
                    e.distance.Visible = false
                end

                -- ── TRACER ───────────────────────────────────────────────────
                if s.ShowTracer then
                    local startPos = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y)
                    if s.TracerPosition == "Top" then
                        startPos = Vector2.new(camera.ViewportSize.X / 2, 0)
                    elseif s.TracerPosition == "Middle" then
                        startPos = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
                    end
                    e.tracer.From = startPos
                    e.tracer.To = Vector2.new(hrpPos.X, boxPos.Y + h)
                    e.tracer.Color = dynamicColor
                    e.tracer.Visible = true
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

-- Stop the ESP
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
        if self.Settings[k] ~= nil then self.Settings[k] = v end
    end
end

function ESP:Set(key, value)
    if self.Settings[key] ~= nil then self.Settings[key] = value end
end

function ESP:Get(key)
    return self.Settings[key]
end

return ESP
