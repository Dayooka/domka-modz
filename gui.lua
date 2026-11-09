local Players = game:GetService("Players")
local LP      = Players.LocalPlayer

local Cfg     = _G._AIO_Config
local Shared  = _G._AIO_Shared
local modules = _G._AIO_Modules or {}

if not Cfg then
    warn("[GUI] _Config nem talalhato!")
    return
end

-- Rayfield betöltése
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- Ablak létrehozása
local Window = Rayfield:CreateWindow({
    Name = "DOMKA MODZ - AIO HUB",
    LoadingTitle = "DOMKA MODZ Betöltése...",
    LoadingSubtitle = "by Dayooka",
    ConfigurationSaving = {
        Enabled = false,
        FolderName = nil,
        FileName = "AIO_Hub_Config"
    },
    KeySystem = false,
})

local MainTab = Window:CreateTab("AIO Hub", "home")

-- Összes BE/KI
local allOn = true
MainTab:CreateButton({
    Name = "Összes modul BE / KI (ALL)",
    Callback = function()
        allOn = not allOn
        Cfg.setAllEnabled(allOn)
        local msg = allOn and "Minden modul bekapcsolva!" or "Minden modul kikapcsolva!"
        Rayfield:Notify({
            Title   = "AIO Hub",
            Content = msg,
            Duration= 2,
            Image   = 4483362458,
        })
    end,
})

MainTab:CreateDivider()

-- Kártya definíciók
local CARD_DEFS = {
    {
        cfgKey = "Gym",
        label  = "Gym Automation",
        modKey = "Gym",
        statFn = function(stats)
            return string.format("%s | %s | P:%d G:%d S:%d Miss:%d",
                stats.station or "-", stats.status or "-",
                stats.perfect or 0, stats.good or 0, stats.sloppy or 0, stats.missed or 0)
        end,
        sliders = {
            { label="Offset (sec)", cfgKey="Gym", key="TIMING_OFFSET_SECONDS", min=-0.1, max=0.1, step=0.005 },
        },
    },
    {
        cfgKey = "KillAura",
        label  = "Kill Aura",
        modKey = nil,
        statFn = function(_)
            local mode   = Cfg.get("KillAura","ATTACK_MODE")     or "mixed"
            local range  = Cfg.get("KillAura","RANGE")           or 24
            local freeze = Cfg.get("KillAura","FREEZE_ENABLED") and "BE" or "KI"
            local prio   = Cfg.get("KillAura","TARGET_PRIORITY") or "nearest"
            return string.format("Mode:%s | Range:%d | Freeze:%s | %s", mode, range, freeze, tostring(prio))
        end,
        extras = {
            { label="Freeze",      cfgKey="KillAura", key="FREEZE_ENABLED"      },
            { label="Players",     cfgKey="KillAura", key="ATTACK_PLAYERS"      },
            { label="Underground", cfgKey="KillAura", key="UNDERGROUND_ENABLED" },
            { label="Execute",     cfgKey="KillAura", key="EXEC_ENABLED"        },
            { label="Teleport",    cfgKey="KillAura", key="TELEPORT_ENABLED"    },
        },
        sliders = {
            { label="Range",        cfgKey="KillAura", key="RANGE",          min=5,    max=60,   step=1    },
            { label="Chase Range",  cfgKey="KillAura", key="CHASE_RANGE",    min=10,   max=150,  step=5    },
            { label="Max Targets",  cfgKey="KillAura", key="MAX_TARGETS",    min=1,    max=20,   step=1    },
            { label="Light x Mult", cfgKey="KillAura", key="LIGHT_MULTIPLY", min=1,    max=10,   step=1    },
            { label="Light Count",  cfgKey="KillAura", key="LIGHT_COUNT",    min=1,    max=8,    step=1    },
            { label="Heavy x Mult", cfgKey="KillAura", key="HEAVY_MULTIPLY", min=1,    max=5,    step=1    },
            { label="Heavy Hold",   cfgKey="KillAura", key="HEAVY_HOLD",     min=0.1,  max=1.0,  step=0.05 },
            { label="Burst Delay",  cfgKey="KillAura", key="BURST_DELAY",    min=0.0,  max=0.05, step=0.002},
            { label="Attack Delay", cfgKey="KillAura", key="ATTACK_DELAY",   min=0.0,  max=0.5,  step=0.01 },
            { label="Exec Thresh%", cfgKey="KillAura", key="EXEC_THRESHOLD", min=0.05, max=0.5,  step=0.05 },
            { label="Exec Hold",    cfgKey="KillAura", key="EXEC_HOLD",      min=0.1,  max=1.0,  step=0.05 },
            { label="Behind Offset",cfgKey="KillAura", key="BEHIND_OFFSET",  min=0.5,  max=8.0,  step=0.5  },
        },
        dropdowns = {
            {
                label   = "Attack Mode",
                cfgKey  = "KillAura",
                key     = "ATTACK_MODE",
                options = { "mixed", "light", "heavy", "grab" },
            },
            {
                label   = "Target Priority",
                cfgKey  = "KillAura",
                key     = "TARGET_PRIORITY",
                options = { "nearest", "lowest_hp", "mixed" },
            },
        },
    },
    {
        cfgKey = "BlockParry",
        label  = "Auto Block / Parry",
        modKey = "BlockParry",
        statFn = function(stats)
            return string.format("Block: %d | Parry: %d", stats.totalBlock or 0, stats.totalParry or 0)
        end,
        extras = {
            { label="Preemptiv", cfgKey="BlockParry", key="PREEMPTIVE" },
        },
    },
    {
        cfgKey = "Vanish",
        label  = "Auto Vanish",
        modKey = "Vanish",
        statFn = function(stats)
            return string.format("V:%d | S:%d | Ki:%d%% | Lanc:%d",
                stats.totalVanish or 0, stats.totalStep or 0, stats.ki or 0, stats.chain or 0)
        end,
        extras = {
            { label="Post-Step", cfgKey="Vanish", key="POST_STEP" },
        },
    },
    {
        cfgKey = "DragonBall",
        label  = "Auto Dragon Ball",
        modKey = "DragonBall",
        statFn = function(stats)
            return string.format("Earth: %d/7 | Namek: %d/7", stats.earth or 0, stats.namek or 0)
        end,
        extras = {
            { label="Auto Summon", cfgKey="DragonBall", key="AUTO_SUMMON" },
        },
    },
    {
        cfgKey = "Loot",
        label  = "Auto Loot Farm",
        modKey = "Loot",
        statFn = function(stats)
            return string.format("Talalt: %d | Felvett: %d", stats.found or 0, stats.collected or 0)
        end,
    },
    {
        cfgKey = "Senzu",
        label  = "Auto Senzu Farm",
        modKey = "Senzu",
        statFn = function(stats)
            return string.format("%s | Kovetkezo: %ds", stats.status or "-", stats.nextIn or 0)
        end,
        extras = {
            { label="Auto Ultet", cfgKey="Senzu", key="AUTO_REPLANT" },
        },
    },
    {
        cfgKey = "Daily",
        label  = "Auto Daily Farm",
        modKey = "Daily",
        statFn = function(stats)
            return string.format("Statusz: %s", stats.status or "-")
        end,
        extras = {
            { label="Extras", cfgKey="Daily", key="CLAIM_EXTRAS" },
        },
    },
    {
        cfgKey = "NPCFarm",
        label  = "Auto NPC Farm",
        modKey = "NPCFarm",
        statFn = function(stats)
            return string.format("Kills: %d | Target: %s", stats.kills or 0, tostring(stats.target or "-"))
        end,
        extras = {
            { label="Grab",   cfgKey="NPCFarm", key="GRAB_ENABLED"    },
            { label="TP NPC", cfgKey="NPCFarm", key="TELEPORT_TO_NPC" },
        },
    },
}

-- Elem referenciák
local toggleElements = {}
local statLabels     = {}

-- Modulok felépítése
for _, def in ipairs(CARD_DEFS) do
    MainTab:CreateSection(def.label)

    -- Fő toggle
    local isEnabled = Cfg.get(def.cfgKey, "enabled") or false
    local mainToggle = MainTab:CreateToggle({
        Name         = "Bekapcsolva",
        CurrentValue = isEnabled,
        Flag         = def.cfgKey .. "_enabled",
        Callback     = function(Value)
            if Cfg.get(def.cfgKey, "enabled") ~= Value then
                Cfg.set(def.cfgKey, "enabled", Value)
            end
        end,
    })
    table.insert(toggleElements, { cfgKey=def.cfgKey, key="enabled", element=mainToggle })

    -- Stat paragraph
    local statParagraph = MainTab:CreateParagraph({
        Title   = "Statisztika",
        Content = "Adatok betoltese...",
    })
    table.insert(statLabels, { modKey=def.modKey, element=statParagraph, statFn=def.statFn })

    -- Extra toggle-ok
    if def.extras then
        for _, ex in ipairs(def.extras) do
            local exVal = Cfg.get(ex.cfgKey, ex.key)
            if exVal == nil then exVal = false end
            local exToggle = MainTab:CreateToggle({
                Name         = ex.label,
                CurrentValue = exVal,
                Flag         = ex.cfgKey .. "_" .. ex.key,
                Callback     = function(Value)
                    Cfg.set(ex.cfgKey, ex.key, Value)
                end,
            })
            table.insert(toggleElements, { cfgKey=ex.cfgKey, key=ex.key, element=exToggle })
        end
    end

    -- Sliderek
    if def.sliders then
        for _, sl in ipairs(def.sliders) do
            local curVal = Cfg.get(sl.cfgKey, sl.key)
            if curVal == nil then curVal = sl.min end
            MainTab:CreateSlider({
                Name         = sl.label,
                Range        = { sl.min, sl.max },
                Increment    = sl.step,
                CurrentValue = curVal,
                Flag         = sl.cfgKey .. "_" .. sl.key,
                Callback     = function(Value)
                    Cfg.set(sl.cfgKey, sl.key, Value)
                end,
            })
        end
    end

    -- Dropdown-ok (pl. Attack Mode, Target Priority)
    if def.dropdowns then
        for _, dd in ipairs(def.dropdowns) do
            local curVal = Cfg.get(dd.cfgKey, dd.key) or dd.options[1]
            local ddElement = MainTab:CreateDropdown({
                Name         = dd.label,
                Options      = dd.options,
                CurrentOption= { curVal },
                Flag         = dd.cfgKey .. "_" .. dd.key,
                Callback     = function(Value)
                    -- Rayfield visszaadhat táblát vagy stringet
                    local v = type(Value) == "table" and Value[1] or Value
                    Cfg.set(dd.cfgKey, dd.key, v)
                end,
            })
            table.insert(toggleElements, { cfgKey=dd.cfgKey, key=dd.key, element=ddElement, isDropdown=true })
        end
    end

    MainTab:CreateDivider()
end

-- Config változás → toggle/dropdown szinkronizáció
Cfg.onChange(function(mod, key, val)
    for _, item in ipairs(toggleElements) do
        if item.cfgKey == mod and item.key == key then
            if item.isDropdown then
                -- Dropdown: Set az aktuális opcióval
                pcall(function()
                    item.element:Set(type(val) == "table" and val or { val })
                end)
            else
                pcall(function() item.element:Set(val) end)
            end
        end
    end
end)

-- Stat frissítő loop
task.spawn(function()
    while true do
        task.wait(0.5)
        local mods = _G._AIO_Modules or {}
        for _, sl in ipairs(statLabels) do
            if sl.modKey then
                local mod = mods[sl.modKey]
                if mod and mod.getStats then
                    local ok, stats = pcall(mod.getStats)
                    if ok and stats and sl.statFn then
                        local ok2, text = pcall(sl.statFn, stats)
                        if ok2 and text then
                            pcall(function()
                                sl.element:Set({ Title="Statisztika", Content=text })
                            end)
                        end
                    end
                end
            end
        end
    end
end)

print("[GUI_Controller - Rayfield] OK")
