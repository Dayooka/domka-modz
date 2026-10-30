-- ═══════════════════════════════════════════════════════════════
-- Domka modz - Advanced GUI (Rayfield Integration)
-- ═══════════════════════════════════════════════════════════════

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local CFG = getgenv().DomkaConfig or {
    RANGE             = 25,
    MAX_TARGETS       = 10,
    BURST_DELAY       = 0.004,
    MULTIPLY          = 3,
    MULT_DELAY        = 0.004,
    EXEC_THRESHOLD    = 0.15,
    EXEC_HOLD         = 0.3,
    EXEC_CD           = 2.0,
    DIRECT_DMG        = 20,
    DIRECT_RATE       = 0.08,
    BEHIND_OFFSET     = 2.5,
    BEHIND_RATE       = 0.08,
    UNDERGROUND_DEPTH = 12,
    UV_RESET_RATE     = 0.05,
}

local Window = Rayfield:CreateWindow({
   Name = "Domka modz | Advanced Combat",
   LoadingTitle = "Domka modz Framework",
   LoadingSubtitle = "by Domka",
   ConfigurationSaving = {
      Enabled = false,
      FolderName = nil,
      FileName = "DomkaConfig"
   },
   Discord = {
      Enabled = false,
      Invite = "noinvite",
      RememberJoins = true
   },
   KeySystem = false
})

-- ┌──────────────────────────────────────────────────────────────┐
-- │  TAB: COMBAT & TARGETING                                     │
-- └──────────────────────────────────────────────────────────────┘
local CombatTab = Window:CreateTab("Combat", 4483362458)

CombatTab:CreateSection("Targeting & Range")

CombatTab:CreateSlider({
   Name = "Targeting Range",
   Range = {5, 100},
   Increment = 1,
   Suffix = "studs",
   CurrentValue = CFG.RANGE,
   Flag = "RangeSlider",
   Callback = function(Value)
      CFG.RANGE = Value
      getgenv().DomkaConfig.RANGE = Value
   end,
})

CombatTab:CreateSlider({
   Name = "Max Targets",
   Range = {1, 25},
   Increment = 1,
   Suffix = "targets",
   CurrentValue = CFG.MAX_TARGETS,
   Flag = "MaxTargetsSlider",
   Callback = function(Value)
      CFG.MAX_TARGETS = Value
      getgenv().DomkaConfig.MAX_TARGETS = Value
   end,
})

CombatTab:CreateSlider({
   Name = "Teleport Behind Offset",
   Range = {1, 10},
   Increment = 0.5,
   Suffix = "studs",
   CurrentValue = CFG.BEHIND_OFFSET,
   Flag = "BehindOffsetSlider",
   Callback = function(Value)
      CFG.BEHIND_OFFSET = Value
      getgenv().DomkaConfig.BEHIND_OFFSET = Value
   end,
})

CombatTab:CreateSection("Attack Multipliers & Speed")

CombatTab:CreateSlider({
   Name = "Attack Multiplier",
   Range = {1, 10},
   Increment = 1,
   Suffix = "x",
   CurrentValue = CFG.MULTIPLY,
   Flag = "MultiplierSlider",
   Callback = function(Value)
      CFG.MULTIPLY = Value
      getgenv().DomkaConfig.MULTIPLY = Value
   end,
})

CombatTab:CreateSlider({
   Name = "Burst Delay",
   Range = {0.001, 0.05},
   Increment = 0.001,
   Suffix = "s",
   CurrentValue = CFG.BURST_DELAY,
   Flag = "BurstDelaySlider",
   Callback = function(Value)
      CFG.BURST_DELAY = Value
      getgenv().DomkaConfig.BURST_DELAY = Value
   end,
})

CombatTab:CreateSlider({
   Name = "Direct Damage",
   Range = {0, 100},
   Increment = 5,
   Suffix = "HP",
   CurrentValue = CFG.DIRECT_DMG,
   Flag = "DirectDmgSlider",
   Callback = function(Value)
      CFG.DIRECT_DMG = Value
      getgenv().DomkaConfig.DIRECT_DMG = Value
   end,
})

-- ┌──────────────────────────────────────────────────────────────┐
-- │  TAB: EXECUTION & MOVEMENT                                   │
-- └──────────────────────────────────────────────────────────────┘
local ExecTab = Window:CreateTab("Execution", 4483362458)

ExecTab:CreateSection("Grab & Auto Execution")

ExecTab:CreateSlider({
   Name = "Execution HP Threshold",
   Range = {0.05, 0.5},
   Increment = 0.01,
   Suffix = "% HP",
   CurrentValue = CFG.EXEC_THRESHOLD,
   Flag = "ExecThreshSlider",
   Callback = function(Value)
      CFG.EXEC_THRESHOLD = Value
      getgenv().DomkaConfig.EXEC_THRESHOLD = Value
   end,
})

ExecTab:CreateSlider({
   Name = "Execution Hold Duration",
   Range = {0.1, 1.0},
   Increment = 0.05,
   Suffix = "s",
   CurrentValue = CFG.EXEC_HOLD,
   Flag = "ExecHoldSlider",
   Callback = function(Value)
      CFG.EXEC_HOLD = Value
      getgenv().DomkaConfig.EXEC_HOLD = Value
   end,
})

ExecTab:CreateSlider({
   Name = "Execution Cooldown",
   Range = {0.5, 5.0},
   Increment = 0.1,
   Suffix = "s",
   CurrentValue = CFG.EXEC_CD,
   Flag = "ExecCDSlider",
   Callback = function(Value)
      CFG.EXEC_CD = Value
      getgenv().DomkaConfig.EXEC_CD = Value
   end,
})

ExecTab:CreateSection("Underground Protection")

ExecTab:CreateSlider({
   Name = "Underground Depth",
   Range = {5, 30},
   Increment = 1,
   Suffix = "studs",
   CurrentValue = CFG.UNDERGROUND_DEPTH,
   Flag = "UGDepthSlider",
   Callback = function(Value)
      CFG.UNDERGROUND_DEPTH = Value
      getgenv().DomkaConfig.UNDERGROUND_DEPTH = Value
   end,
})

-- ┌──────────────────────────────────────────────────────────────┐
-- │  TAB: SETTINGS                                               │
-- └──────────────────────────────────────────────────────────────┘
local SettingsTab = Window:CreateTab("Settings", 4483362458)

SettingsTab:CreateSection("System Controls")

SettingsTab:CreateButton({
   Name = "Force Upvalue Scan",
   Callback = function()
      Rayfield:Notify({
         Title = "Domka modz",
         Content = "Upvalue rescan elindítva...",
         Duration = 3,
         Image = 4483362458,
      })
   end,
})

Rayfield:Notify({
   Title = "Domka modz",
   Content = "GUI sikeresen betöltve!",
   Duration = 5,
   Image = 4483362458,
})
