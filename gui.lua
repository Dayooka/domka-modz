local Cfg      = require(script.Parent._Config)
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "Domka modz | KillAura v9 Master Suite",
   LoadingTitle = "Domka modz Framework",
   LoadingSubtitle = "by Domka",
   ConfigurationSaving = { Enabled = false },
   KeySystem = false
})

-- ┌──────────────────────────────────────────────────────────────┐
-- │  TAB 1: KILLAURA v9                                          │
-- └──────────────────────────────────────────────────────────────┘
local CombatTab = Window:CreateTab("KillAura v9", 4483362458)

CombatTab:CreateSection("Fő Kapcsolók")
CombatTab:CreateToggle({
   Name = "KillAura Főkapcsoló", CurrentValue = Cfg.get("KillAura", "enabled"),
   Callback = function(Value) Cfg.set("KillAura", "enabled", Value) end,
})
CombatTab:CreateToggle({
   Name = "Játékosok Támadása", CurrentValue = Cfg.get("KillAura", "ATTACK_PLAYERS"),
   Callback = function(Value) Cfg.set("KillAura", "ATTACK_PLAYERS", Value) end,
})
CombatTab:CreateDropdown({
   Name = "Célpont Prioritás", Options = {"nearest", "lowest_hp", "mixed"}, CurrentOption = Cfg.get("KillAura", "TARGET_PRIORITY"),
   Callback = function(Option) Cfg.set("KillAura", "TARGET_PRIORITY", Option) end,
})

CombatTab:CreateSection("Hatótáv & Célzás")
CombatTab:CreateSlider({
   Name = "Aura Range", Range = {5, 100}, Increment = 1, Suffix = "studs",
   CurrentValue = Cfg.get("KillAura", "RANGE"),
   Callback = function(Value) Cfg.set("KillAura", "RANGE", Value) end,
})
CombatTab:CreateSlider({
   Name = "Chase Range", Range = {10, 150}, Increment = 1, Suffix = "studs",
   CurrentValue = Cfg.get("KillAura", "CHASE_RANGE"),
   Callback = function(Value) Cfg.set("KillAura", "CHASE_RANGE", Value) end,
})
CombatTab:CreateSlider({
   Name = "Max Targets", Range = {1, 25}, Increment = 1, Suffix = "targets",
   CurrentValue = Cfg.get("KillAura", "MAX_TARGETS"),
   Callback = function(Value) Cfg.set("KillAura", "MAX_TARGETS", Value) end,
})

CombatTab:CreateSection("Sebesség & Szorzó")
CombatTab:CreateSlider({
   Name = "Attack Multiplier", Range = {1, 10}, Increment = 1, Suffix = "x",
   CurrentValue = Cfg.get("KillAura", "MULTIPLY"),
   Callback = function(Value) Cfg.set("KillAura", "MULTIPLY", Value) end,
})
CombatTab:CreateSlider({
   Name = "Burst Delay", Range = {0.001, 0.05}, Increment = 0.001, Suffix = "s",
   CurrentValue = Cfg.get("KillAura", "BURST_DELAY"),
   Callback = function(Value) Cfg.set("KillAura", "BURST_DELAY", Value) end,
})

-- ┌──────────────────────────────────────────────────────────────┐
-- │  TAB 2: VÉDELEM                                              │
-- └──────────────────────────────────────────────────────────────┘
local DefTab = Window:CreateTab("Védelem", 4483362458)

DefTab:CreateSection("Védelmi Rendszerek (Alapból Off)")
DefTab:CreateToggle({
   Name = "Auto Block / Parry", CurrentValue = Cfg.get("BlockParry", "enabled"),
   Callback = function(Value) Cfg.set("BlockParry", "enabled", Value) end,
})
DefTab:CreateToggle({
   Name = "Auto Vanish PRO", CurrentValue = Cfg.get("Vanish", "enabled"),
   Callback = function(Value) Cfg.set("Vanish", "enabled", Value) end,
})

DefTab:CreateSection("Fagyasztás & Földalatti")
DefTab:CreateToggle({
   Name = "Target Freeze", CurrentValue = Cfg.get("KillAura", "FREEZE_ENABLED"),
   Callback = function(Value) Cfg.set("KillAura", "FREEZE_ENABLED", Value) end,
})
DefTab:CreateToggle({
   Name = "Underground Engedélyezése", CurrentValue = Cfg.get("KillAura", "UNDERGROUND_ENABLED"),
   Callback = function(Value) Cfg.set("KillAura", "UNDERGROUND_ENABLED", Value) end,
})
DefTab:CreateSlider({
   Name = "Underground Mélység", Range = {5, 30}, Increment = 1, Suffix = "studs",
   CurrentValue = Cfg.get("KillAura", "UNDERGROUND_DEPTH"),
   Callback = function(Value) Cfg.set("KillAura", "UNDERGROUND_DEPTH", Value) end,
})

-- ┌──────────────────────────────────────────────────────────────┐
-- │  TAB 3: AUTOMATA FARMOK                                      │
-- └──────────────────────────────────────────────────────────────┘
local FarmTab = Window:CreateTab("Automata Farmok", 4483362458)

FarmTab:CreateSection("Farm Modulok (Alapból Off)")
FarmTab:CreateToggle({
   Name = "Auto NPC Kill Farm", CurrentValue = Cfg.get("NPCFarm", "enabled"),
   Callback = function(Value) Cfg.set("NPCFarm", "enabled", Value) end,
})
FarmTab:CreateToggle({
   Name = "Auto Loot Farm", CurrentValue = Cfg.get("Loot", "enabled"),
   Callback = function(Value) Cfg.set("Loot", "enabled", Value) end,
})
FarmTab:CreateToggle({
   Name = "Auto Senzu Farm", CurrentValue = Cfg.get("Senzu", "enabled"),
   Callback = function(Value) Cfg.set("Senzu", "enabled", Value) end,
})
FarmTab:CreateToggle({
   Name = "Auto Dragon Ball Collector", CurrentValue = Cfg.get("DragonBall", "enabled"),
   Callback = function(Value) Cfg.set("DragonBall", "enabled", Value) end,
})
FarmTab:CreateToggle({
   Name = "Auto Daily & AFK Rewards", CurrentValue = Cfg.get("Daily", "enabled"),
   Callback = function(Value) Cfg.set("Daily", "enabled", Value) end,
})

Rayfield:Notify({
   Title = "Domka modz",
   Content = "KillAura v9 Master Suite sikeresen betöltve!",
   Duration = 5,
})
