-- ═══════════════════════════════════════════════════════════════
-- Domka modz - Master GUI (KillAura v8 + All Modules Integration)
-- ═══════════════════════════════════════════════════════════════

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local CFG = _G.KillAuraCFG or {
    ENABLED = true, RANGE = 24, CHASE_RANGE = 50, MAX_TARGETS = 10,
    BURST_DELAY = 0.004, MULTIPLY = 2, MULT_DELAY = 0.006,
    TARGET_PRIORITY = "nearest", ATTACK_PLAYERS = false,
    EXEC_THRESHOLD = 0.15, EXEC_HOLD = 0.3, EXEC_CD = 2.0,
    BEHIND_OFFSET = 2.5, BEHIND_RATE = 0.03, BEHIND_ON_ATTACK = true,
    UNDERGROUND_DEPTH = 10, UNDERGROUND_ENABLED = true, FREEZE_ENABLED = true,
    AUTO_BLOCK_ENABLED = true, AUTO_VANISH_ENABLED = true, AUTO_DB_ENABLED = true,
    AUTO_LOOT_ENABLED = true, AUTO_SENZU_ENABLED = true, AUTO_DAILY_ENABLED = true,
    AUTO_NPC_FARM_ENABLED = true,
}

_G.KillAuraCFG = CFG

local Window = Rayfield:CreateWindow({
   Name = "Domka modz | All-In-One Master Suite",
   LoadingTitle = "Domka modz Framework",
   LoadingSubtitle = "by Domka",
   ConfigurationSaving = { Enabled = false, FolderName = nil, FileName = "DomkaConfig" },
   Discord = { Enabled = false, Invite = "noinvite", RememberJoins = true },
   KeySystem = false
})

-- ┌──────────────────────────────────────────────────────────────┐
-- │  TAB 1: KILLAURA COMBAT                                      │
-- └──────────────────────────────────────────────────────────────┘
local CombatTab = Window:CreateTab("KillAura", 4483362458)

CombatTab:CreateSection("Fő Kapcsolók")

CombatTab:CreateToggle({
   Name = "KillAura Engedélyezése", CurrentValue = CFG.ENABLED, Flag = "KillAuraToggle",
   Callback = function(Value) CFG.ENABLED = Value end,
})

CombatTab:CreateToggle({
   Name = "Játékosok Támadása (Attack Players)", CurrentValue = CFG.ATTACK_PLAYERS, Flag = "AttackPlayersToggle",
   Callback = function(Value) CFG.ATTACK_PLAYERS = Value end,
})

CombatTab:CreateDropdown({
   Name = "Célpont Prioritás", Options = {"nearest", "lowest_hp", "mixed"}, CurrentOption = CFG.TARGET_PRIORITY,
   Flag = "TargetPriorityDropdown", Callback = function(Option) CFG.TARGET_PRIORITY = Option end,
})

CombatTab:CreateSection("Hatótáv & Célzás")

CombatTab:CreateSlider({
   Name = "Aura Hatótáv (Range)", Range = {5, 100}, Increment = 1, Suffix = "studs",
   CurrentValue = CFG.RANGE, Flag = "RangeSlider", Callback = function(Value) CFG.RANGE = Value end,
})

CombatTab:CreateSlider({
   Name = "Chase Range (Követési táv)", Range = {10, 150}, Increment = 1, Suffix = "studs",
   CurrentValue = CFG.CHASE_RANGE, Flag = "ChaseRangeSlider", Callback = function(Value) CFG.CHASE_RANGE = Value end,
})

CombatTab:CreateSlider({
   Name = "Max Célpontok Száma", Range = {1, 25}, Increment = 1, Suffix = "targets",
   CurrentValue = CFG.MAX_TARGETS, Flag = "MaxTargetsSlider", Callback = function(Value) CFG.MAX_TARGETS = Value end,
})

CombatTab:CreateSection("Sebesség & Szorzók")

CombatTab:CreateSlider({
   Name = "Packet Szorzás (Multiplier)", Range = {1, 10}, Increment = 1, Suffix = "x",
   CurrentValue = CFG.MULTIPLY, Flag = "MultiplierSlider", Callback = function(Value) CFG.MULTIPLY = Value end,
})

CombatTab:CreateSlider({
   Name = "Burst Delay", Range = {0.001, 0.05}, Increment = 0.001, Suffix = "s",
   CurrentValue = CFG.BURST_DELAY, Flag = "BurstDelaySlider", Callback = function(Value) CFG.BURST_DELAY = Value end,
})

-- ┌──────────────────────────────────────────────────────────────┐
-- │  TAB 2: DEFENSE & CONTROL                                    │
-- └──────────────────────────────────────────────────────────────┘
local DefTab = Window:CreateTab("Védelem", 4483362458)

DefTab:CreateSection("Auto Block & Vanish")

DefTab:CreateToggle({
   Name = "Auto Block / Parry", CurrentValue = CFG.AUTO_BLOCK_ENABLED, Flag = "BlockToggle",
   Callback = function(Value) CFG.AUTO_BLOCK_ENABLED = Value end,
})

DefTab:CreateToggle({
   Name = "Auto Vanish PRO", CurrentValue = CFG.AUTO_VANISH_ENABLED, Flag = "VanishToggle",
   Callback = function(Value) CFG.AUTO_VANISH_ENABLED = Value end,
})

DefTab:CreateSection("Célpont Lefagyasztása & Mozgás")

DefTab:CreateToggle({
   Name = "Target Freeze (NPC Mozgás Letiltás)", CurrentValue = CFG.FREEZE_ENABLED, Flag = "FreezeToggle",
   Callback = function(Value) CFG.FREEZE_ENABLED = Value end,
})

DefTab:CreateToggle({
   Name = "Underground Végrehajtás", CurrentValue = CFG.UNDERGROUND_ENABLED, Flag = "UGToggle",
   Callback = function(Value) CFG.UNDERGROUND_ENABLED = Value end,
})

DefTab:CreateSlider({
   Name = "Underground Mélység", Range = {5, 30}, Increment = 1, Suffix = "studs",
   CurrentValue = CFG.UNDERGROUND_DEPTH, Flag = "UGDepthSlider", Callback = function(Value) CFG.UNDERGROUND_DEPTH = Value end,
})

-- ┌──────────────────────────────────────────────────────────────┐
-- │  TAB 3: AUTOMATION & FARMING                                 │
-- └──────────────────────────────────────────────────────────────┘
local FarmTab = Window:CreateTab("Automata Farmok", 4483362458)

FarmTab:CreateSection("Farm Modulok Ki/Be Kapcsolása")

FarmTab:CreateToggle({
   Name = "Auto NPC Kill Farm", CurrentValue = CFG.AUTO_NPC_FARM_ENABLED, Flag = "NPCFarmToggle",
   Callback = function(Value) CFG.AUTO_NPC_FARM_ENABLED = Value end,
})

FarmTab:CreateToggle({
   Name = "Auto Loot Farm (Földön lévő cuccok)", CurrentValue = CFG.AUTO_LOOT_ENABLED, Flag = "LootToggle",
   Callback = function(Value) CFG.AUTO_LOOT_ENABLED = Value end,
})

FarmTab:CreateToggle({
   Name = "Auto Senzu Farm (Ültetés & Aratás)", CurrentValue = CFG.AUTO_SENZU_ENABLED, Flag = "SenzuToggle",
   Callback = function(Value) CFG.AUTO_SENZU_ENABLED = Value end,
})

FarmTab:CreateToggle({
   Name = "Auto Dragon Ball Collector", CurrentValue = CFG.AUTO_DB_ENABLED, Flag = "DBToggle",
   Callback = function(Value) CFG.AUTO_DB_ENABLED = Value end,
})

FarmTab:CreateToggle({
   Name = "Auto Daily & AFK Jutalom Claim", CurrentValue = CFG.AUTO_DAILY_ENABLED, Flag = "DailyToggle",
   Callback = function(Value) CFG.AUTO_DAILY_ENABLED = Value end,
})

Rayfield:Notify({
   Title = "Domka modz",
   Content = "Master Suite sikeresen betöltve!",
   Duration = 5,
   Image = 4483362458,
})
