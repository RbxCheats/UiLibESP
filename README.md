# ESP Library for Roblox

A powerful, standalone ESP (Extra Sensory Perception) library for Roblox that provides player visualization features including 2D boxes, 3D boxes, corner boxes, name tags, tracers, and health bars. Designed to be easily integrated into any cheat menu or GUI.

## 📋 Table of Contents
- [Features](#features)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [API Reference](#api-reference)
- [Integration Examples](#integration-examples)
- [Configuration Options](#configuration-options)
- [Bug Fixes & Troubleshooting](#bug-fixes--troubleshooting)
- [Performance Optimization](#performance-optimization)
- [Best Practices](#best-practices)

## ✨ Features

- **Multiple ESP Types**
  - 2D Box ESP - Simple rectangular outlines
  - Corner Box ESP - Minimalist corner brackets
  - 3D Box ESP - Fully rotatable boxes matching player orientation

- **Visual Elements**
  - Player Name Display
  - Health Bars with dynamic coloring
  - Tracers from screen center to players
  - Customizable colors for all elements

- **Technical Benefits**
  - Minimal performance overhead
  - Automatic cleanup on player leave
  - Dynamic drawing management
  - Standalone - no external dependencies
  - Easy integration with any UI library

## 📥 Installation

### Method 1: Raw LoadString (Recommended)

```lua
local ESPLibrary = loadstring(game:HttpGet("https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/ESP_Library.lua"))()
```

### Method 2: Local Script Storage

```lua
-- Store in your script
local ESPLibrary = {
    -- Copy the entire library code here
}
```

## 🚀 Quick Start

### Basic Implementation

```lua
-- Load the library
local ESPLibrary = loadstring(game:HttpGet("https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/ESP_Library.lua"))()

-- Create a new ESP instance
local esp = ESPLibrary.new()

-- Configure basic settings
esp.enabled = true
esp.espType = "2D Box"
esp.nameEsp = true
esp.tracers = true
esp.healthBar = true

-- Start the ESP system
esp:start()
```

### With Custom Colors

```lua
local esp = ESPLibrary.new()

-- Custom color scheme
esp.espColor = Color3.fromRGB(255, 100, 0)      -- Orange boxes
esp.nameColor = Color3.fromRGB(255, 255, 255)   -- White names
esp.tracerColor = Color3.fromRGB(255, 0, 0)     -- Red tracers
esp.healthBarColor = Color3.fromRGB(0, 255, 0)  -- Green health bars

esp.enabled = true
esp:start()
```

## 📚 API Reference

### Constructor

| Method | Description | Returns |
|--------|-------------|---------|
| `ESPLibrary.new()` | Creates a new ESP instance | ESP object |

### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `enabled` | boolean | false | Master toggle for ESP |
| `espType` | string | "2D Box" | ESP style ("2D Box", "Corner Box", "3D Box") |
| `nameEsp` | boolean | false | Show player names |
| `tracers` | boolean | false | Show tracers to players |
| `healthBar` | boolean | false | Show health bars |
| `ignoreLocal` | boolean | true | Skip drawing ESP on local player |
| `espColor` | Color3 | White | Color of boxes |
| `nameColor` | Color3 | White | Color of name text |
| `tracerColor` | Color3 | White | Color of tracer lines |
| `healthBarColor` | Color3 | Green | Color of health bars |

### Methods

| Method | Parameters | Description |
|--------|------------|-------------|
| `:start()` | None | Begins the ESP render loop |
| `:stop()` | None | Stops rendering and hides all ESP |
| `:destroy()` | None | Completely removes all drawings and stops |
| `:update()` | None | Manually updates ESP (auto-called in loop) |

## 🔌 Integration Examples

### Integration with RbxImGui

```lua
-- Load both libraries
local RbxImGui = loadstring(game:HttpGet("https://raw.githubusercontent.com/RbxCheats/UiLib/refs/heads/main/RobloxUI.lua"))()
local ESPLibrary = loadstring(game:HttpGet("https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/ESP_Library.lua"))()

-- Create ESP instance
local esp = ESPLibrary.new()

-- Create UI window
local win = RbxImGui.new("My Cheat Menu")
win:AddTab("Visuals")

local visuals = win:Tab("Visuals")

-- ESP Master toggle
visuals:Toggle("ESP Enabled", false, function(v)
    esp.enabled = v
    if v then esp:start() else esp:stop() end
end)

-- ESP Type dropdown
visuals:Dropdown("ESP Type", {"2D Box", "Corner Box", "3D Box"}, function(v)
    esp.espType = v
end)

-- Feature toggles
visuals:Toggle("Name ESP", false, function(v) esp.nameEsp = v end)
visuals:Toggle("Tracers", false, function(v) esp.tracers = v end)
visuals:Toggle("Health Bar", false, function(v) esp.healthBar = v end)

-- Color pickers
visuals:Separator()
visuals:Label("Colors")
visuals:ColorPicker("Box Color", Color3.fromRGB(255, 0, 0), function(c) esp.espColor = c end)
visuals:ColorPicker("Name Color", Color3.fromRGB(255, 255, 255), function(c) esp.nameColor = c end)
visuals:ColorPicker("Tracer Color", Color3.fromRGB(0, 255, 0), function(c) esp.tracerColor = c end)
visuals:ColorPicker("Health Color", Color3.fromRGB(0, 255, 0), function(c) esp.healthBarColor = c end)

win:Render()
```

### Integration with Simple UI Library

```lua
-- Simple bindable UI
local ESPLibrary = loadstring(game:HttpGet("https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/ESP_Library.lua"))()
local esp = ESPLibrary.new()

-- Keyboard bindings
local UserInputService = game:GetService("UserInputService")

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.F1 then
        esp.enabled = not esp.enabled
        if esp.enabled then 
            esp:start()
            print("ESP Enabled")
        else 
            esp:stop()
            print("ESP Disabled")
        end
    elseif input.KeyCode == Enum.KeyCode.F2 then
        esp.espType = esp.espType == "2D Box" and "3D Box" or "2D Box"
        print("ESP Type: " .. esp.espType)
    end
end)

-- Command line interface
local function executeCommand(cmd)
    local args = {}
    for arg in string.gmatch(cmd, "%S+") do
        table.insert(args, arg)
    end
    
    if args[1] == "esp" then
        if args[2] == "on" then
            esp.enabled = true
            esp:start()
        elseif args[2] == "off" then
            esp.enabled = false
            esp:stop()
        elseif args[2] == "type" and args[3] then
            esp.espType = args[3]
        end
    end
end

-- Example: executeCommand("esp on")
```

## ⚙️ Configuration Options

### ESP Type Comparison

| Type | Best For | Performance | Visibility |
|------|----------|-------------|------------|
| 2D Box | General use, long distance | Excellent | Good |
| Corner Box | Clean, minimal look | Excellent | Very Good |
| 3D Box | Close quarters, orientation | Good | Excellent |

### Recommended Settings by Scenario

**Arena/Battle Royale Games:**
```lua
esp.espType = "Corner Box"  -- Less clutter
esp.tracers = true          -- Track distant enemies
esp.nameEsp = true          -- Identify targets
```

**Horror/Stealth Games:**
```lua
esp.espType = "2D Box"      -- Clear visibility
esp.healthBar = true        -- Track threat level
esp.nameEsp = false         -- Reduce screen clutter
```

**Casual/Social Games:**
```lua
esp.espType = "2D Box"
esp.nameEsp = true          -- See friend names
esp.tracers = false         -- Not needed
esp.healthBar = false
```

## 🐛 Bug Fixes & Troubleshooting

### Common Issues and Solutions

#### Issue 1: ESP Not Displaying
```lua
-- Solution: Check if camera exists and player characters are loaded
local function fixESPRendering()
    -- Ensure camera is valid
    if not workspace.CurrentCamera then
        wait(0.5)
        return false
    end
    
    -- Force character refresh for all players
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character and not player.Character:FindFirstChild("HumanoidRootPart") then
            player.Character = nil
            player:LoadCharacter()
        end
    end
    return true
end

-- Implement retry logic
local function safeStartESP(esp)
    local attempts = 0
    while attempts < 5 do
        if fixESPRendering() then
            esp:start()
            return true
        end
        attempts = attempts + 1
        wait(1)
    end
    return false
end
```

#### Issue 2: Performance Drops / Lag
```lua
-- Solution: Implement throttling and cleanup
local function optimizeESP(esp)
    -- Clean up old drawings periodically
    local cleanupTimer = 0
    
    game:GetService("RunService").Heartbeat:Connect(function(deltaTime)
        cleanupTimer = cleanupTimer + deltaTime
        
        -- Clean up every 5 seconds
        if cleanupTimer >= 5 then
            for char, drawings in pairs(esp.drawings) do
                -- Remove drawings for characters that no longer exist
                if not char or not char.Parent then
                    for _, drawing in pairs(drawings) do
                        if drawing and drawing.Remove then
                            drawing:Remove()
                        end
                    end
                    esp.drawings[char] = nil
                end
            end
            cleanupTimer = 0
        end
    end)
end
```

#### Issue 3: 3D Box Not Rotating Properly
```lua
-- Fix: Ensure bounding box calculation is accurate
local function fix3DBoxRotation(char)
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    
    -- Get actual character size
    local size = char:GetExtentsSize()
    
    -- Get proper CFrame from root part
    local cf = root.CFrame
    
    -- Adjust for character offset
    local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
    if torso then
        local offset = (torso.Position - root.Position).Y
        cf = cf * CFrame.new(0, offset, 0)
    end
    
    return cf, size
end
```

#### Issue 4: Tracers Drawn Behind Walls
```lua
-- Fix: Add visibility checking
local function addVisibilityCheck(esp)
    local originalUpdate = esp.update
    
    esp.update = function(self)
        -- Store original method
        originalUpdate(self)
        
        for char, drawings in pairs(self.drawings) do
            if drawings.tracer and drawings.tracer.Visible then
                local root = char:FindFirstChild("HumanoidRootPart")
                if root then
                    -- Check if visible
                    local ray = Ray.new(Camera.CFrame.Position, (root.Position - Camera.CFrame.Position).unit * 500)
                    local hit = workspace:FindPartOnRay(ray, char)
                    
                    -- Make tracer semi-transparent if behind wall
                    if hit and hit ~= char then
                        drawings.tracer.Transparency = 0.5
                    else
                        drawings.tracer.Transparency = 0
                    end
                end
            end
        end
    end
end
```

### Error Handling Wrapper

```lua
-- Wrapper for safe ESP operations
local function safeESP(esp)
    local originalUpdate = esp.update
    
    esp.update = function(self)
        local success, err = pcall(function()
            originalUpdate(self)
        end)
        
        if not success then
            warn("ESP Error: " .. tostring(err))
            -- Attempt recovery
            self:stop()
            wait(1)
            self:start()
        end
    end
    
    return esp
end

-- Usage
local esp = safeESP(ESPLibrary.new())
```

## ⚡ Performance Optimization

### Recommended Settings for Different Scenarios

**Low-End PCs:**
```lua
esp.espType = "2D Box"     -- Least intensive
esp.nameEsp = false         -- Text rendering is costly
esp.tracers = false         -- Additional lines reduce FPS
esp.healthBar = false       -- Minimize drawings
```

**Mid-Range PCs:**
```lua
esp.espType = "Corner Box"  -- Medium intensity
esp.nameEsp = true          -- Acceptable performance
esp.tracers = false         -- Optional
esp.healthBar = true        -- Good balance
```

**High-End PCs:**
```lua
esp.espType = "3D Box"      -- Most intensive
esp.nameEsp = true          
esp.tracers = true          
esp.healthBar = true        -- All features enabled
```

### Memory Management

```lua
-- Implement automatic cleanup
local function setupAutoCleanup(esp)
    -- Clean up on player leave
    Players.PlayerRemoving:Connect(function(player)
        if player.Character and esp.drawings[player.Character] then
            local drawings = esp.drawings[player.Character]
            for _, drawing in pairs(drawings) do
                if drawing and drawing.Remove then
                    drawing:Remove()
                end
            end
            esp.drawings[player.Character] = nil
        end
    end)
    
    -- Clean up on character death
    for _, player in ipairs(Players:GetPlayers()) do
        player.CharacterAdded:Connect(function(char)
            -- Previous character's drawings will be cleaned automatically
            wait(0.5)
            if esp.drawings[char] then
                esp.drawings[char] = nil
            end
        end)
    end
end
```

## 📝 Best Practices

1. **Always Destroy ESP When Done**
```lua
-- Script cleanup
game:GetService("Players").LocalPlayer.PlayerGui:WaitForChild("ScreenGui").Destroying:Connect(function()
    if esp then esp:destroy() end
end)
```

2. **Use Pcall for Safety**
```lua
local success, esp = pcall(function()
    return ESPLibrary.new()
end)

if not success then
    warn("Failed to load ESP Library")
    return
end
```

3. **Implement Toggle Cooldowns**
```lua
local lastToggle = 0
local toggleCooldown = 0.5

function toggleESP(esp)
    local now = tick()
    if now - lastToggle >= toggleCooldown then
        esp.enabled = not esp.enabled
        if esp.enabled then esp:start() else esp:stop() end
        lastToggle = now
    end
end
```

4. **Validate Game Environment**
```lua
function validateEnvironment()
    -- Check for required services
    assert(game:GetService("Players"), "Players service missing")
    assert(workspace.CurrentCamera, "Camera not found")
    
    -- Check for Roblox Studio vs Player
    if game:GetService("RunService"):IsStudio() then
        warn("Running in Studio - ESP may behave differently")
    end
    
    return true
end
```

## 📄 License

This ESP Library is provided as-is for educational purposes. Use responsibly and in accordance with Roblox Terms of Service.

## 🤝 Contributing

Found a bug or have a suggestion? Feel free to:
- Open an issue on GitHub
- Submit a pull request
- Contact the maintainer

---

**Version:** 1.0.0  
**Last Updated:** 2026  
**Compatible With:** All Roblox games  
**Dependencies:** None (standalone)
