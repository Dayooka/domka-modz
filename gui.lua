-- ═══════════════════════════════════════════════════════════════
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- Biztonsági fallback, ha közvetlenül futna
local CFG = _G.KillAuraCFG or {
    ENABLED = true,
    RANGE = 24,
    CHASE_RANGE = 50,
    MAX_TARGETS = 10,
    BURST_DELAY = 0.004,
    MULTIPLY = 2,
    MULT_DELAY = 0.006,
    TARGET_PRIORITY = "nearest",
    ATTACK_PLAYERS = false,
    EXEC_THRESHOLD = 0.15,
    EXEC_HOLD = 0.3,
    EXEC_CD = 2.0,
    BEHIND_OFFSET = 2.5,
    BEHIND_RATE = 0.03,
    BEHIND_ON_ATTACK = true,
    UNDERGROUND_DEPTH = 10,
    UNDERGROUND_ENABLED = true,
    FREEZE_ENABLED = true,
}

_G.KillAuraCFG = CFG

local Window = Rayfield:CreateWindow({
   Name = "Domka modz | KillAura v8",
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
-- │  TAB: MAIN & COMBAT                                          │
-- └──────────────────────────────────────────────────────────────┘
local CombatTab = Window:CreateTab("Combat", 4483362458)

CombatTab:CreateSection("General Controls")

CombatTab:CreateToggle({
   Name = "KillAura Enabled",
   CurrentValue = CFG.ENABLED,
   Flag = "EnabledToggle",
   Callback = function(Value)
      CFG.ENABLED = Value
   end,
})

CombatTab:CreateToggle({
   Name = "Attack Players",
   CurrentValue = CFG.ATTACK_PLAYERS,
   Flag = "AttackPlayersToggle",
   Callback = function(Value)
      CFG.ATTACK_PLAYERS = Value
   end,
})

CombatTab:CreateDropdown({
   Name = "Target Priority",
   Options = {"nearest", "lowest_hp", "mixed"},
   CurrentOption = CFG.TARGET_PRIORITY,
   Flag = "TargetPriorityDropdown",
   Callback = function(Option)
      CFG.TARGET_PRIORITY = Option
   end,
})

CombatTab:CreateSection("Range & Targeting")

CombatTab:CreateSlider({
   Name = "Aura Range",
   Range = {5, 100},
   Increment = 1,
   Suffix = "studs",
   CurrentValue = CFG.RANGE,
   Flag = "RangeSlider",
   Callback = function(Value)
      CFG.RANGE = Value
   end,
})

CombatTab:CreateSlider({
   Name = "Chase Range (Knockback)",
   Range = {10, 150},
   Increment = 1,
   Suffix = "studs",
   CurrentValue = CFG.CHASE_RANGE,
   Flag = "ChaseRangeSlider",
   Callback = function(Value)
      CFG.CHASE_RANGE = Value
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
   end,
})

-- ┌──────────────────────────────────────────────────────────────┐
-- │  TAB: EXECUTION & FREEZE                                     │
-- └──────────────────────────────────────────────────────────────┘
local ExecTab = Window:CreateTab("Execution", 4483362458)

ExecTab:CreateSection("Execution Settings")

ExecTab:CreateSlider({
   Name = "Execution HP Threshold",
   Range = {0.05, 0.5},
   Increment = 0.01,
   Suffix = "% HP",
   CurrentValue = CFG.EXEC_THRESHOLD,
   Flag = "ExecThreshSlider",
   Callback = function(Value)
      CFG.EXEC_THRESHOLD = Value
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
   end,
})

ExecTab:CreateSection("Target Control & Freeze")

ExecTab:CreateToggle({
   Name = "Enable Target Freeze",
   CurrentValue = CFG.FREEZE_ENABLED,
   Flag = "FreezeToggle",
   Callback = function(Value)
      CFG.FREEZE_ENABLED = Value
   end,
})

-- ┌──────────────────────────────────────────────────────────────┐
-- │  TAB: MOVEMENT & POSITION                                    │
-- └──────────────────────────────────────────────────────────────┘
local MoveTab = Window:CreateTab("Movement", 4483362458)

MoveTab:CreateSection("Position & Teleport")

MoveTab:CreateSlider({
   Name = "Behind Offset",
   Range = {1, 10},
   Increment = 0.5,
   Suffix = "studs",
   CurrentValue = CFG.BEHIND_OFFSET,
   Flag = "BehindOffsetSlider",
   Callback = function(Value)
      CFG.BEHIND_OFFSET = Value
   end,
})

MoveTab:CreateSlider({
   Name = "Underground Depth",
   Range = {5, 30},
   Increment = 1,
   Suffix = "studs",
   CurrentValue = CFG.UNDERGROUND_DEPTH,
   Flag = "UGDepthSlider",
   Callback = function(Value)
      CFG.UNDERGROUND_DEPTH = Value
   end,
})

MoveTab:CreateToggle({
   Name = "Underground Enabled",
   CurrentValue = CFG.UNDERGROUND_ENABLED,
   Flag = "UGEnabledToggle",
   Callback = function(Value)
      CFG.UNDERGROUND_ENABLED = Value
   end,
})

MoveTab:CreateToggle({
   Name = "Behind On Attack",
   CurrentValue = CFG.BEHIND_ON_ATTACK,
   Flag = "BehindOnAttackToggle",
   Callback = function(Value)
      CFG.BEHIND_ON_ATTACK = Value
   end,
})

Rayfield:Notify({
   Title = "Domka modz",
   Content = "KillAura v8 GUI sikeresen betöltve!",
   Duration = 5,
   Image = 4483362458,
})
