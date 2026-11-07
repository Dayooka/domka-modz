local Players = game:GetService("Players")
local LP      = Players.LocalPlayer

-- Modulok lekerese _G-bol
local Cfg     = _G._AIO_Config
local Shared  = _G._AIO_Shared
local modules = _G._AIO_Modules or {}

if not Cfg then
    warn("[GUI] _Config nem talalhato! Futtasd elobb a _Config.lua-t")
    return
end

-- Rayfield betöltése
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- Ablak létrehozása
local Window = Rayfield:CreateWindow({
    Name = "DOMKA MODZ - AIO HUB",
    LoadingTitle = "DOMKA MODZ Betöltése...",
    LoadingSubtitle = "by EyooDayo",
    ConfigurationSaving = {
        Enabled = false,
        FolderName = nil,
        FileName = "AIO_Hub_Config"
    },
    KeySystem = false,
})

-- Fő Tab létrehozása
local MainTab = Window:CreateTab("AIO Hub", "home")

-- Összes BE/KI kapcsoló állapot
local allOn = true
MainTab:CreateButton({
    Name = "Összes modul BE / KI (ALL)",
    Callback = function()
        allOn = not allOn
        Cfg.setAllEnabled(allOn)
        Rayfield:Notify({
            Title = "AIO Hub",
            Content = allOn = true and "Minden modul bekapcsolva!" or "Minden modul kikapcsolva!",
            Duration = 2,
            Image = 4483362458,
        })
    end,
})

MainTab:CreateDivider()

-- ── Kártyák / Modulok definíciói ────────────────────────────────────
local CARD_DEFS = {
    {
        cfgKey  = "Gym",
        label   = "Gym Automation",
        modKey  = "Gym",
        statFn  = function(stats)
            return string.format("%s | %s | P:%d G:%d S:%d Miss:%d", 
                stats.station or "-", stats.status or "-", 
                stats.perfect or 0, stats.good or 0, stats.sloppy or 0, stats.missed or 0)
        end,
        sliders = {
            { label="Offset (sec)", cfgKey="Gym", key="TIMING_OFFSET_SECONDS", min=-0.1, max=0.1, step=0.005 },
        },
    },
    {
        cfgKey  = "KillAura",
        label   = "Kill Aura",
        modKey  = nil,
        statFn  = function(_)
            local cfg = Cfg
            local range  = cfg.get("KillAura","RANGE")        or 24
            local mult   = cfg.get("KillAura","MULTIPLY")      or 2
            local freeze = cfg.get("KillAura","FREEZE_ENABLED") and "BE" or "KI"
            local prio   = cfg.get("KillAura","TARGET_PRIORITY") or "nearest"
            return string.format("Range: %d | x%d | Freeze: %s | %s", range, mult, freeze, tostring(prio))
        end,
        extras = {
            { label="Freeze", cfgKey="KillAura", key="FREEZE_ENABLED" },
            { label="Players", cfgKey="KillAura", key="ATTACK_PLAYERS" },
            { label="Underground", cfgKey="KillAura", key="UNDERGROUND_ENABLED" },
        },
        sliders = {
            { label="Range",    cfgKey="KillAura", key="RANGE",        min=5,  max=60,  step=1  },
            { label="x Mult",   cfgKey="KillAura", key="MULTIPLY",     min=1,  max=10,  step=1  },
            { label="Exec %",   cfgKey="KillAura", key="EXEC_THRESHOLD", min=0.05, max=0.5, step=0.05 },
            { label="MaxTargets", cfgKey="KillAura", key="MAX_TARGETS", min=1, max=20, step=1 },
        },
    },
    {
        cfgKey  = "BlockParry",
        label   = "Auto Block / Parry",
        modKey  = "BlockParry",
        statFn  = function(stats)
            return string.format("Block: %d | Parry: %d", stats.totalBlock or 0, stats.totalParry or 0)
        end,
        extras = {
            { label="Preemptiv", cfgKey="BlockParry", key="PREEMPTIVE" },
        },
    },
    {
        cfgKey  = "Vanish",
        label   = "Auto Vanish",
        modKey  = "Vanish",
        statFn  = function(stats)
            return string.format("V:%d | S:%d | Ki:%d%s | Lanc:%d", 
                stats.totalVanish or 0, stats.totalStep or 0, stats.ki or 0, "%", stats.chain or 0)
        end,
        extras = {
            { label="Post-Step", cfgKey="Vanish", key="POST_STEP" },
        },
    },
    {
        cfgKey  = "DragonBall",
        label   = "Auto Dragon Ball",
        modKey  = "DragonBall",
        statFn  = function(stats)
            return string.format("Earth: %d/7 | Namek: %d/7", stats.earth or 0, stats.namek or 0)
        end,
        extras = {
            { label="Auto Summon", cfgKey="DragonBall", key="AUTO_SUMMON" },
        },
    },
    {
        cfgKey  = "Loot",
        label   = "Auto Loot Farm",
        modKey  = "Loot",
        statFn  = function(stats)
            return string.format("Talált: %d | Felvett: %d", stats.found or 0, stats.collected or 0)
        end,
    },
    {
        cfgKey  = "Senzu",
        label   = "Auto Senzu Farm",
        modKey  = "Senzu",
        statFn  = function(stats)
            return string.format("%s | Következő: %ds", stats.status or "-", stats.nextIn or 0)
        end,
        extras = {
            { label="Auto Ultet", cfgKey="Senzu", key="AUTO_REPLANT" },
        },
    },
    {
        cfgKey  = "Daily",
        label   = "Auto Daily Farm",
        modKey  = "Daily",
        statFn  = function(stats)
            return string.format("Státusz: %s", stats.status or "-")
        end,
        extras = {
            { label="Extras", cfgKey="Daily", key="CLAIM_EXTRAS" },
        },
    },
    {
        cfgKey  = "NPCFarm",
        label   = "Auto NPC Farm",
        modKey  = "NPCFarm",
        statFn  = function(stats)
            return string.format("Kills: %d | Target: %s", stats.kills or 0, tostring(stats.target or "-"))
        end,
        extras = {
            { label="Grab", cfgKey="NPCFarm", key="GRAB_ENABLED" },
            { label="TP NPC", cfgKey="NPCFarm", key="TELEPORT_TO_NPC" },
        },
    },
}

-- Elem referenciák tárolása a dinamikus frissítésekhez
local toggleElements = {}
local statLabels = {}

-- Modulok felépítése a Rayfieldben
for _, def in ipairs(CARD_DEFS) do
    MainTab:CreateSection(def.label)

    -- Fő kapcsoló (BE/KI)
    local isEnabled = Cfg.get(def.cfgKey, "enabled") or false
    local mainToggle = MainTab:CreateToggle({
        Name = "Bekapcsolva",
        CurrentValue = isEnabled,
        Flag = def.cfgKey .. "_enabled",
        Callback = function(Value)
            local current = Cfg.get(def.cfgKey, "enabled")
            if current ~= Value then
                Cfg.set(def.cfgKey, "enabled", Value)
            end
        end,
    })
    
    table.insert(toggleElements, { cfgKey = def.cfgKey, key = "enabled", element = mainToggle })

    -- Statisztika sor (Paragraphként jelenik meg)
    local statParagraph = MainTab:CreateParagraph({
        Title = "Statisztika",
        Content = "Adatok betöltése..."
    })
    table.insert(statLabels, { modKey = def.modKey, element = statParagraph, statFn = def.statFn })

    -- Extra al-toggle-ok
    if def.extras then
        for _, ex in ipairs(def.extras) do
            local exVal = Cfg.get(ex.cfgKey, ex.key) or false
            MainTab:CreateToggle({
                Name = ex.label,
                CurrentValue = exVal,
                Flag = ex.cfgKey .. "_" .. ex.key,
                Callback = function(Value)
                    Cfg.set(ex.cfgKey, ex.key, Value)
                end,
            })
        end
    end

    -- Sliderek
    if def.sliders then
        for _, sl in ipairs(def.sliders) do
            local curVal = Cfg.get(sl.cfgKey, sl.key) or sl.min
            MainTab:CreateSlider({
                Name = sl.label,
                Range = {sl.min, sl.max},
                Increment = sl.step,
                CurrentValue = curVal,
                Flag = sl.cfgKey .. "_" .. sl.key,
                Callback = function(Value)
                    Cfg.set(sl.cfgKey, sl.key, Value)
                end,
            })
        end
    end

    MainTab:CreateDivider()
end

-- ── Szinkronizáció és Háttérfolyamatok ──────────────────────────────

-- Konfiguráció változás figyelése kívülről (ha más script módosít valamit)
Cfg.onChange(function(mod, key, val)
    for _, item in ipairs(toggleElements) do
        if item.cfgKey == mod and item.key == key then
            pcall(function()
                item.element:Set(val)
            end)
        end
    end
end)

-- Statisztika frissítő loop (0.5 másodpercenként lekéri a modulok adatait)
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
                                sl.element:Set({
                                    Title = "Statisztika",
                                    Content = text
                                })
                            end)
                        end
                    end
                end
            end
        end
    end
end)

print("[GUI_Controller - Rayfield] OK - Minden modul betöltve!")
