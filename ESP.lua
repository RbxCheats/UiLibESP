--[[
    Advanced ESP Library for Roblox (Optimized & Bug-Fixed)
    Features:
    - 2D Box & Corner Box ESP
    - Tracer to bottom middle of box
    - Health bar, Name, Distance, Skeleton
    - Team check & Wall check
    - Fully customizable settings
]]

local ESPLib = {}

-- Services
local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local localPlayer = Players.LocalPlayer
local camera      = workspace.CurrentCamera

-- Bone connections for skeleton
local BONES = {
    {"Head",       "UpperTorso"},
    {"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
    {"UpperTorso", "LeftUpperArm"},  {"LeftUpperArm",  "LeftLowerArm"},  {"LeftLowerArm",  "LeftHand"},
    {"UpperTorso", "LowerTorso"},
    {"LowerTorso", "LeftUpperLeg"},  {"LeftUpperLeg",  "LeftLowerLeg"},  {"LeftLowerLeg",  "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"},
}

-- Default Settings
local ESP_SETTINGS = {
    Enabled   = false,
    -- Box
    ShowBox          = false,
    BoxType          = "2D", -- "2D" or "Corner"
    BoxColor         = Color3.new(1, 1, 1),
    BoxOutlineColor  = Color3.new(0, 0, 0),
    -- Name
    ShowName  = false,
    NameColor = Color3.new(1, 1, 1),
    -- Health
    ShowHealth         = false,
    HealthHighColor    = Color3.new(0, 1, 0),
    HealthLowColor     = Color3.new(1, 0, 0),
    HealthOutlineColor = Color3.new(0, 0, 0),
    -- Distance
    ShowDistance = false,
    -- Skeleton
    ShowSkeletons  = false,
    SkeletonsColor = Color3.new(1, 1, 1),
    -- Tracer
    ShowTracer       = false,
    TracerColor      = Color3.new(1, 1, 1),
    TracerThickness  = 2,
    TracerPosition   = "Bottom", -- "Top", "Middle", "Bottom"
    -- Filters
    Teamcheck = false,
    WallCheck = false,
}

-- Cache for player ESP objects
local espCache = {}

-- ── Helpers ──────────────────────────────────────────────────────────────────

local function createDrawing(class, properties)
    local d = Drawing.new(class)
    for k, v in pairs(properties) do
        d[k] = v
    end
    return d
end

-- BUG FIX: raycast direction was not normalised; we now pass the full vector
-- (workspace:Raycast length is derived from the direction magnitude, which is correct here)
local function isPlayerBehindWall(player)
    local character = player.Character
    if not character then return false end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return false end

    local origin    = camera.CFrame.Position
    local direction = rootPart.Position - origin

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    -- Guard: localPlayer.Character may be nil
    local exclude = {character}
    if localPlayer.Character then
        table.insert(exclude, localPlayer.Character)
    end
    params.FilterDescendantsInstances = exclude

    local result = workspace:Raycast(origin, direction, params)
    return result ~= nil and result.Instance ~= nil
        and result.Instance:IsA("BasePart")
        and result.Instance.CanCollide
end

-- Hide every drawing belonging to an esp entry
local function hideAll(esp)
    esp.box.Visible         = false
    esp.boxOutline.Visible  = false
    esp.name.Visible        = false
    esp.healthOutline.Visible = false
    esp.health.Visible      = false
    esp.distance.Visible    = false
    esp.tracer.Visible      = false
    for _, line in ipairs(esp.boxLines) do
        line.Visible = false
    end
    for _, ld in ipairs(esp.skeletonLines) do
        ld[1].Visible = false
    end
end

-- ── ESP object management ────────────────────────────────────────────────────

local function createEsp(player)
    local skeletonLines = {}
    -- Pre-create skeleton lines (avoids lazy allocation inside the render loop)
    for _, bonePair in ipairs(BONES) do
        local line = createDrawing("Line", {
            Thickness    = 1,
            Color        = ESP_SETTINGS.SkeletonsColor,
            Transparency = 1,
            Visible      = false,
        })
        table.insert(skeletonLines, {line, bonePair[1], bonePair[2]})
    end

    -- Corner box: only 8 lines needed (one per corner edge).
    -- BUG FIX: original used 16 lines (8 outer + 8 redundant "inner" copies).
    local boxLines = {}
    for i = 1, 8 do
        boxLines[i] = createDrawing("Line", {
            Thickness    = 2,
            Color        = ESP_SETTINGS.BoxColor,
            Transparency = 1,
            Visible      = false,
        })
    end

    espCache[player] = {
        box          = createDrawing("Square", {Color = ESP_SETTINGS.BoxColor,        Thickness = 1, Filled = false, Visible = false}),
        boxOutline   = createDrawing("Square", {Color = ESP_SETTINGS.BoxOutlineColor, Thickness = 3, Filled = false, Visible = false}),
        boxLines     = boxLines,
        name         = createDrawing("Text", {Color = ESP_SETTINGS.NameColor, Outline = true, Center = true, Size = 13, Visible = false}),
        healthOutline= createDrawing("Line", {Thickness = 3, Color = ESP_SETTINGS.HealthOutlineColor, Visible = false}),
        health       = createDrawing("Line", {Thickness = 2, Visible = false}),
        distance     = createDrawing("Text", {Color = Color3.new(1,1,1), Size = 12, Outline = true, Center = true, Visible = false}),
        tracer       = createDrawing("Line", {Thickness = ESP_SETTINGS.TracerThickness, Color = ESP_SETTINGS.TracerColor, Transparency = 1, Visible = false}),
        skeletonLines= skeletonLines,
    }
end

local function removeEsp(player)
    local esp = espCache[player]
    if not esp then return end

    -- Remove each drawing individually so one failure doesn't skip the rest
    local function safeRemove(d) if d and d.Remove then pcall(d.Remove, d) end end

    safeRemove(esp.box)
    safeRemove(esp.boxOutline)
    safeRemove(esp.name)
    safeRemove(esp.healthOutline)
    safeRemove(esp.health)
    safeRemove(esp.distance)
    safeRemove(esp.tracer)
    for _, line in ipairs(esp.boxLines)      do safeRemove(line)    end
    for _, ld   in ipairs(esp.skeletonLines) do safeRemove(ld[1])   end

    espCache[player] = nil
end

-- ── Per-frame update ─────────────────────────────────────────────────────────

local function updateEsp()
    for player, esp in pairs(espCache) do
        local character = player.Character
        local humanoid  = character and character:FindFirstChildOfClass("Humanoid")
        local rootPart  = character and character:FindFirstChild("HumanoidRootPart")
        local head      = character and character:FindFirstChild("Head")

        local isValid    = character and humanoid and rootPart and head and humanoid.Health > 0
        local isTeammate = ESP_SETTINGS.Teamcheck and player.Team == localPlayer.Team
        local isBehindWall = ESP_SETTINGS.WallCheck and isValid and isPlayerBehindWall(player)
        local shouldRender = ESP_SETTINGS.Enabled and isValid and not isTeammate and not isBehindWall

        if not shouldRender then
            hideAll(esp)
        else
            -- BUG FIX: use WorldToViewportPoint return value directly; only call it twice
            local hrpScreen, onScreen = camera:WorldToViewportPoint(rootPart.Position)
            if not onScreen then
                hideAll(esp)
            else
                -- BUG FIX: charHeight was halved incorrectly before.
                -- topY and bottomY give the full pixel span of the character.
                local topScreen    = camera:WorldToViewportPoint(rootPart.Position + Vector3.new(0, 2.6, 0))
                local bottomScreen = camera:WorldToViewportPoint(rootPart.Position - Vector3.new(0, 3.0, 0))
                local charHeight   = bottomScreen.Y - topScreen.Y   -- full pixel height (no ÷2)
                local boxW         = math.floor(charHeight * 0.65)  -- roughly half the old *1.8/2 ratio
                local boxH         = math.floor(charHeight)
                local boxSize      = Vector2.new(boxW, boxH)
                local boxPos       = Vector2.new(
                    math.floor(hrpScreen.X - boxW * 0.5),
                    math.floor(hrpScreen.Y - boxH * 0.5)
                )

                -- ── BOX ──────────────────────────────────────────────────────
                if ESP_SETTINGS.ShowBox then
                    if ESP_SETTINGS.BoxType == "2D" then
                        for _, line in ipairs(esp.boxLines) do line.Visible = false end

                        esp.boxOutline.Position = boxPos
                        esp.boxOutline.Size     = boxSize
                        esp.boxOutline.Color    = ESP_SETTINGS.BoxOutlineColor
                        esp.boxOutline.Visible  = true

                        esp.box.Position = boxPos
                        esp.box.Size     = boxSize
                        esp.box.Color    = ESP_SETTINGS.BoxColor
                        esp.box.Visible  = true

                    elseif ESP_SETTINGS.BoxType == "Corner" then
                        esp.box.Visible        = false
                        esp.boxOutline.Visible = false

                        local lW    = math.floor(boxW / 5)
                        local lH    = math.floor(boxH / 6)
                        local lines = esp.boxLines
                        local bx, by = boxPos.X, boxPos.Y
                        local bx2, by2 = bx + boxW, by + boxH

                        -- Top-left
                        lines[1].From = Vector2.new(bx,      by);      lines[1].To = Vector2.new(bx + lW,  by)
                        lines[2].From = Vector2.new(bx,      by);      lines[2].To = Vector2.new(bx,       by + lH)
                        -- Top-right
                        lines[3].From = Vector2.new(bx2 - lW, by);     lines[3].To = Vector2.new(bx2,      by)
                        lines[4].From = Vector2.new(bx2,      by);     lines[4].To = Vector2.new(bx2,      by + lH)
                        -- Bottom-left
                        lines[5].From = Vector2.new(bx,       by2 - lH); lines[5].To = Vector2.new(bx,    by2)
                        lines[6].From = Vector2.new(bx,       by2);    lines[6].To = Vector2.new(bx + lW, by2)
                        -- Bottom-right
                        lines[7].From = Vector2.new(bx2 - lW, by2);   lines[7].To = Vector2.new(bx2,      by2)
                        lines[8].From = Vector2.new(bx2,      by2 - lH); lines[8].To = Vector2.new(bx2,  by2)

                        for _, line in ipairs(lines) do
                            line.Color   = ESP_SETTINGS.BoxColor
                            line.Visible = true
                        end
                    end
                else
                    esp.box.Visible        = false
                    esp.boxOutline.Visible = false
                    for _, line in ipairs(esp.boxLines) do line.Visible = false end
                end

                -- ── NAME ─────────────────────────────────────────────────────
                if ESP_SETTINGS.ShowName then
                    esp.name.Text     = string.lower(player.Name)
                    esp.name.Position = Vector2.new(boxPos.X + boxW * 0.5, boxPos.Y - 16)
                    esp.name.Color    = ESP_SETTINGS.NameColor
                    esp.name.Visible  = true
                else
                    esp.name.Visible = false
                end

                -- ── HEALTH BAR ───────────────────────────────────────────────
                if ESP_SETTINGS.ShowHealth then
                    local pct  = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
                    local barX = boxPos.X - 6
                    local barTop    = boxPos.Y
                    local barBottom = boxPos.Y + boxH

                    esp.healthOutline.From    = Vector2.new(barX, barBottom)
                    esp.healthOutline.To      = Vector2.new(barX, barTop)
                    esp.healthOutline.Visible = true

                    esp.health.From    = Vector2.new(barX, barBottom)
                    esp.health.To      = Vector2.new(barX, barBottom - boxH * pct)
                    esp.health.Color   = ESP_SETTINGS.HealthLowColor:Lerp(ESP_SETTINGS.HealthHighColor, pct)
                    esp.health.Visible = true
                else
                    esp.healthOutline.Visible = false
                    esp.health.Visible        = false
                end

                -- ── DISTANCE ─────────────────────────────────────────────────
                if ESP_SETTINGS.ShowDistance then
                    local dist = (camera.CFrame.Position - rootPart.Position).Magnitude
                    esp.distance.Text     = string.format("%.0f studs", dist)
                    esp.distance.Position = Vector2.new(boxPos.X + boxW * 0.5, boxPos.Y + boxH + 5)
                    esp.distance.Visible  = true
                else
                    esp.distance.Visible = false
                end

                -- ── SKELETON ─────────────────────────────────────────────────
                if ESP_SETTINGS.ShowSkeletons then
                    for _, ld in ipairs(esp.skeletonLines) do
                        local line, nameA, nameB = ld[1], ld[2], ld[3]
                        local partA = character:FindFirstChild(nameA)
                        local partB = character:FindFirstChild(nameB)
                        if partA and partB then
                            local sA, aOn = camera:WorldToViewportPoint(partA.Position)
                            local sB, bOn = camera:WorldToViewportPoint(partB.Position)
                            if aOn and bOn then
                                line.From    = Vector2.new(sA.X, sA.Y)
                                line.To      = Vector2.new(sB.X, sB.Y)
                                line.Color   = ESP_SETTINGS.SkeletonsColor
                                line.Visible = true
                            else
                                line.Visible = false
                            end
                        else
                            line.Visible = false
                        end
                    end
                else
                    for _, ld in ipairs(esp.skeletonLines) do ld[1].Visible = false end
                end

                -- ── TRACER ───────────────────────────────────────────────────
                if ESP_SETTINGS.ShowTracer then
                    local vp   = camera.ViewportSize
                    local pos  = ESP_SETTINGS.TracerPosition
                    local origY = pos == "Top" and 0
                             or  pos == "Middle" and vp.Y * 0.5
                             or  vp.Y  -- "Bottom" (default)

                    esp.tracer.From      = Vector2.new(vp.X * 0.5, origY)
                    esp.tracer.To        = Vector2.new(boxPos.X + boxW * 0.5, boxPos.Y + boxH)
                    esp.tracer.Color     = ESP_SETTINGS.TracerColor
                    esp.tracer.Thickness = ESP_SETTINGS.TracerThickness
                    esp.tracer.Visible   = true
                else
                    esp.tracer.Visible = false
                end
            end
        end
    end
end

-- ── Initialisation ───────────────────────────────────────────────────────────

local function init()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            createEsp(player)
        end
    end

    Players.PlayerAdded:Connect(function(player)
        if player ~= localPlayer then
            createEsp(player)
        end
    end)

    Players.PlayerRemoving:Connect(removeEsp)

    -- BUG FIX: use Heartbeat instead of RenderStepped.
    -- RenderStepped blocks the render thread; Heartbeat runs after physics
    -- and is the correct hook for Drawing updates.
    RunService.Heartbeat:Connect(updateEsp)
end

-- ── Public API ───────────────────────────────────────────────────────────────

function ESPLib.GetSettings()
    return ESP_SETTINGS
end

function ESPLib.SetSettings(newSettings)
    for k, v in pairs(newSettings) do
        if ESP_SETTINGS[k] ~= nil then
            ESP_SETTINGS[k] = v
        end
    end
end

function ESPLib.Toggle()
    ESP_SETTINGS.Enabled = not ESP_SETTINGS.Enabled
end

-- BUG FIX: removed auto-call of ESPLib.Start() at module level.
-- Auto-starting on require causes uncontrollable side-effects; callers
-- should invoke ESPLib.Start() explicitly after configuring settings.
function ESPLib.Start()
    init()
end

return ESPLib
