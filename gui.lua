local Players = game:GetService("Players")
local LP      = Players.LocalPlayer

local Cfg    = _G._AIO_Config
local Shared = _G._AIO_Shared

if not Cfg then
    warn("[GUI] _Config nem talalhato!")
    return
end

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name             = "DOMKA MODZ - AIO HUB",
    LoadingTitle     = "DOMKA MODZ Betöltése...",
    LoadingSubtitle  = "by Dayooka",
    ConfigurationSaving = {
        Enabled    = false,
        FolderName = nil,
        FileName   = "AIO_Hub_Config",
    },
    KeySystem = false,
})

local MainTab = Window:CreateTab("AIO Hub", "home")

-- ── Összes BE/KI ──────────────────────────────────────────────────
local allOn = true
MainTab:CreateButton({
    Name     = "Összes modul BE / KI (ALL)",
    Callback = function()
        allOn = not allOn
        Cfg.setAllEnabled(allOn)
        Rayfield:Notify({
            Title    = "AIO Hub",
            Content  = allOn and "Minden modul bekapcsolva!" or "Minden modul kikapcsolva!",
            Duration = 2,
            Image    = 4483362458,
        })
    end,
})

MainTab:CreateDivider()

-- ── Kártya definíciók ─────────────────────────────────────────────
-- Minden kártyának lehet:
--   cfgKey    → Config modul neve
--   label     → Szekció cím
--   modKey    → _G._AIO_Modules kulcs (statisztikához)
--   statFn    → function(stats) → string
--   extras    → [{label, cfgKey, key}] toggle-ok
--   sliders   → [{label, cfgKey, key, min, max, step}]
--   dropdowns → [{label, cfgKey, key, options}]
--   inputs    → [{label, cfgKey, key, placeholder}]
--   buttons   → [{label, callback}]

local CARD_DEFS = {
    -- ── AntiDetect ────────────────────────────────────────────────
    {
        cfgKey = "StateProbeBypass",
        label  = "Anti-Detect",
        modKey = "StateProbeBypass",
        statFn = function(stats)
            return "StateProbe Bypass: " .. (stats.status or "-")
        end,
    },
    -- ── ReleaseSkill ──────────────────────────────────────────────
    {
        cfgKey = "ReleaseSkill",
        label  = "Skill KillAura",
        modKey = "ReleaseSkill",
        statFn = function(stats)
            return string.format("Status: %s | Cel: %s", stats.status or "-", stats.target or "-")
        end,
        extras = {
            { label="Attackol Jatekost", cfgKey="ReleaseSkill", key="ATTACK_PLAYERS" },
        },
        sliders = {
            { label="Range",       cfgKey="ReleaseSkill", key="LOCK_ON_RANGE", min=5,   max=60,   step=1     },
            { label="Burst Delay", cfgKey="ReleaseSkill", key="BURST_DELAY",   min=0.0, max=0.05, step=0.002 },
        },
        dropdowns = {
            {
                label   = "Skill Type",
                cfgKey  = "ReleaseSkill",
                key     = "SKILL_TYPE",
                options = { "Melee", "Ki", "Beam" },
            },
        },
    },
    -- ── Clash Mash ────────────────────────────────────────────────
    {
        cfgKey = "MeleeClashMash",
        label  = "Auto Clash Mash",
        modKey = "MeleeClashMash",
        statFn = function(stats)
            return string.format("Status: %s | Mash: %d", stats.status or "-", stats.mashCount or 0)
        end,
        sliders = {
            { label="Mash Value", cfgKey="MeleeClashMash", key="MASH_VALUE", min=5,    max=100, step=5    },
            { label="Mash Delay", cfgKey="MeleeClashMash", key="MASH_DELAY", min=0.01, max=0.2, step=0.01 },
        },
    },
    -- ── Auto Fishing ──────────────────────────────────────────────
    {
        cfgKey = "Fishing",
        label  = "Auto Fishing",
        modKey = "Fishing",
        statFn = function(stats)
            return string.format("Status: %s | Fogva: %d", stats.status or "-", stats.caught or 0)
        end,
        sliders = {
            { label="Seq Delay", cfgKey="Fishing", key="SEQUENCE_DELAY", min=0.1, max=2.0, step=0.1  },
            { label="Jitter",    cfgKey="Fishing", key="JITTER",         min=0.0, max=0.5, step=0.05 },
        },
    },
    -- ── Auto Chamber ──────────────────────────────────────────────
    {
        cfgKey = "Chamber",
        label  = "Auto Chamber (XP)",
        modKey = "Chamber",
        statFn = function(stats)
            return string.format("Status: %s | Sessions: %d", stats.status or "-", stats.xpSessions or 0)
        end,
        extras = {
            { label="Auto Mod", cfgKey="Chamber", key="USE_AUTO_MODE" },
        },
        sliders = {
            { label="Action Delay",  cfgKey="Chamber", key="ACTION_DELAY",  min=0.1, max=5.0, step=0.1 },
            { label="Gravity Level", cfgKey="Chamber", key="GRAVITY_LEVEL", min=1,   max=10,  step=1   },
        },
    },
    -- ── Gym ───────────────────────────────────────────────────────
    {
        cfgKey = "Gym",
        label  = "Gym Automation",
        modKey = "Gym",
        statFn = function(stats)
            return string.format("%s | %s | P:%d G:%d S:%d Miss:%d",
                stats.station or "-", stats.status or "-",
                stats.perfect or 0, stats.good or 0,
                stats.sloppy  or 0, stats.missed or 0)
        end,
        sliders = {
            { label="Offset (sec)", cfgKey="Gym", key="TIMING_OFFSET_SECONDS", min=-0.1, max=0.1, step=0.005 },
        },
    },
    -- ── Kill Aura ─────────────────────────────────────────────────
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
            { label="Range",         cfgKey="KillAura", key="RANGE",          min=5,    max=60,   step=1     },
            { label="Chase Range",   cfgKey="KillAura", key="CHASE_RANGE",    min=10,   max=150,  step=5     },
            { label="Max Targets",   cfgKey="KillAura", key="MAX_TARGETS",    min=1,    max=20,   step=1     },
            { label="Light x Mult",  cfgKey="KillAura", key="LIGHT_MULTIPLY", min=1,    max=10,   step=1     },
            { label="Light Count",   cfgKey="KillAura", key="LIGHT_COUNT",    min=1,    max=8,    step=1     },
            { label="Heavy x Mult",  cfgKey="KillAura", key="HEAVY_MULTIPLY", min=1,    max=5,    step=1     },
            { label="Heavy Hold",    cfgKey="KillAura", key="HEAVY_HOLD",     min=0.1,  max=1.0,  step=0.05  },
            { label="Burst Delay",   cfgKey="KillAura", key="BURST_DELAY",    min=0.0,  max=0.05, step=0.002 },
            { label="Attack Delay",  cfgKey="KillAura", key="ATTACK_DELAY",   min=0.0,  max=0.5,  step=0.01  },
            { label="Exec Thresh%",  cfgKey="KillAura", key="EXEC_THRESHOLD", min=0.05, max=0.5,  step=0.05  },
            { label="Exec Hold",     cfgKey="KillAura", key="EXEC_HOLD",      min=0.1,  max=1.0,  step=0.05  },
            { label="Behind Offset", cfgKey="KillAura", key="BEHIND_OFFSET",  min=0.5,  max=8.0,  step=0.5   },
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
    -- ── Auto Block / Parry ────────────────────────────────────────
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
    -- ── Auto Vanish ───────────────────────────────────────────────
    {
        cfgKey = "Vanish",
        label  = "Auto Vanish",
        modKey = "Vanish",
        statFn = function(stats)
            return string.format("V:%d | S:%d | Ki:%d%% | Lanc:%d",
                stats.totalVanish or 0, stats.totalStep or 0,
                stats.ki          or 0, stats.chain     or 0)
        end,
        extras = {
            { label="Post-Step", cfgKey="Vanish", key="POST_STEP" },
        },
    },
    -- ── Auto Dragon Ball ──────────────────────────────────────────
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
    -- ── Auto Loot Farm ────────────────────────────────────────────
    {
        cfgKey = "Loot",
        label  = "Auto Loot Farm",
        modKey = "Loot",
        statFn = function(stats)
            return string.format("Talalt: %d | Felvett: %d", stats.found or 0, stats.collected or 0)
        end,
    },
    -- ── Auto Senzu Farm ───────────────────────────────────────────
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
    -- ── Auto Daily Farm ───────────────────────────────────────────
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
    -- ── Auto NPC Farm ─────────────────────────────────────────────
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
    -- ── Auto Quest ────────────────────────────────────────────────
    {
        cfgKey = "AutoQuest",
        label  = "Auto Quest",
        modKey = "AutoQuest",
        statFn = function(stats)
            return string.format(
                "Aktív: %d | Elfogadva: %d | Vége: %d | Utolsó: %s",
                stats.active    or 0,
                stats.accepted  or 0,
                stats.ended     or 0,
                stats.lastQuest or "-"
            )
        end,
        extras = {
            { label="Auto Dialog",    cfgKey="AutoQuest", key="autoDialog"   },
            { label="Auto Board",     cfgKey="AutoQuest", key="autoBoard"    },
            { label="Auto Errand",    cfgKey="AutoQuest", key="autoErrand"   },
            { label="Auto Daily",     cfgKey="AutoQuest", key="autoDaily"    },
            { label="Auto Complete",  cfgKey="AutoQuest", key="autoComplete" },
            { label="Auto Teleport",  cfgKey="AutoQuest", key="autoTeleport" },
            { label="Auto Párbeszéd", cfgKey="AutoQuest", key="autoDialogue" },
        },
        sliders = {
            { label="Accept Delay",   cfgKey="AutoQuest", key="acceptDelay",    min=0,   max=3,  step=0.1 },
            { label="Cooldown (s)",   cfgKey="AutoQuest", key="cooldown",       min=0,   max=15, step=0.5 },
            { label="TP Offset",      cfgKey="AutoQuest", key="teleportOffset", min=3,   max=40, step=1   },
            { label="Check Interval", cfgKey="AutoQuest", key="checkInterval",  min=0.5, max=10, step=0.5 },
            { label="Dialog Delay",   cfgKey="AutoQuest", key="dialogueDelay",  min=0,   max=2,  step=0.1 },
        },
    },
    -- ── Auto Longevity (Gyógyulás) ────────────────────────────────
    {
        cfgKey = "AutoLongevity",
        label  = "Auto Longevity (Gyógyulás)",
        modKey = "AutoLongevity",
        statFn = function(stats)
            return string.format(
                "HP: %s%% | Státusz: %s | Módszer: %s | Gyógyult: %dx",
                stats.hp        or "?",
                stats.status    or "-",
                stats.method    or "-",
                stats.healed    or 0
            )
        end,
        extras = {
            { label="Pod Használat",     cfgKey="AutoLongevity", key="usePods"        },
            { label="Pod-hoz Teleport",  cfgKey="AutoLongevity", key="teleportToPod"  },
            { label="Pihenés (Rest)",     cfgKey="AutoLongevity", key="useRest"        },
        },
        sliders = {
            { label="HP Küszöb %",        cfgKey="AutoLongevity", key="healthThreshold",    min=0.1,  max=1.0,  step=0.05 },
            { label="Longevity Küszöb %", cfgKey="AutoLongevity", key="longevityThreshold", min=0.1,  max=1.0,  step=0.05 },
            { label="Pod Offset (studs)", cfgKey="AutoLongevity", key="podOffset",          min=1,    max=15,   step=1    },
            { label="Pod Magasság",        cfgKey="AutoLongevity", key="podHeight",          min=1,    max=10,   step=1    },
            { label="Ellenőrzés (s)",     cfgKey="AutoLongevity", key="checkInterval",      min=0.5,  max=10,   step=0.5  },
            { label="Max Idő (s)",        cfgKey="AutoLongevity", key="healTimeout",        min=30,   max=600,  step=10   },
            { label="Kilépési Táv",        cfgKey="AutoLongevity", key="exitOffset",         min=5,    max=30,   step=1    },
        },
    },
}

-- ── Elem referenciák szinkronhoz ──────────────────────────────────
local toggleElements = {}
local statLabels     = {}

-- ── Kártyák renderelése ───────────────────────────────────────────
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
    table.insert(statLabels, {
        modKey  = def.modKey,
        element = statParagraph,
        statFn  = def.statFn,
        cfgKey  = def.cfgKey,
    })

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

    -- Dropdown-ok
    if def.dropdowns then
        for _, dd in ipairs(def.dropdowns) do
            local curVal = Cfg.get(dd.cfgKey, dd.key) or dd.options[1]
            local ddElement = MainTab:CreateDropdown({
                Name          = dd.label,
                Options       = dd.options,
                CurrentOption = { curVal },
                Flag          = dd.cfgKey .. "_" .. dd.key,
                Callback      = function(Value)
                    local v = type(Value) == "table" and Value[1] or Value
                    Cfg.set(dd.cfgKey, dd.key, v)
                end,
            })
            table.insert(toggleElements, {
                cfgKey     = dd.cfgKey,
                key        = dd.key,
                element    = ddElement,
                isDropdown = true,
            })
        end
    end

    -- Input mezők
    if def.inputs then
        for _, inp in ipairs(def.inputs) do
            local curVal = Cfg.get(inp.cfgKey, inp.key) or ""
            MainTab:CreateInput({
                Name                      = inp.label,
                CurrentValue              = tostring(curVal),
                PlaceholderText           = inp.placeholder or "",
                RemoveTextAfterFocusLost  = false,
                Flag                      = inp.cfgKey .. "_" .. inp.key,
                Callback                  = function(Value)
                    Cfg.set(inp.cfgKey, inp.key, Value)
                end,
            })
        end
    end

    -- Gombok
    if def.buttons then
        for _, btn in ipairs(def.buttons) do
            MainTab:CreateButton({
                Name     = btn.label,
                Callback = btn.callback or function() end,
            })
        end
    end

    MainTab:CreateDivider()
end

-- ── Quest kiválasztás szekció (AutoQuest alatt) ───────────────────
do
    MainTab:CreateSection("Quest Farm Kiválasztás")

    -- Elérhető questek listája paragraph (frissítés gomb után töltődik)
    local questListParagraph = MainTab:CreateParagraph({
        Title   = "Elérhető questek",
        Content = "Kattints a 'Frissítés' gombra a questek betöltéséhez.",
    })

    -- Frissítés gomb
    MainTab:CreateButton({
        Name     = "Quest Lista Frissítése",
        Callback = function()
            local mods  = _G._AIO_Modules or {}
            local aqMod = mods["AutoQuest"]

            if not aqMod or not aqMod.getQuestList then
                pcall(function()
                    questListParagraph:Set({
                        Title   = "Elérhető questek",
                        Content = "Az AutoQuest modul még nem töltődött be!",
                    })
                end)
                return
            end

            local list = aqMod.getQuestList()
            if #list == 0 then
                pcall(function()
                    questListParagraph:Set({
                        Title   = "Elérhető questek",
                        Content = "Nincs elérhető quest. Lépj quest tábla közelébe!",
                    })
                end)
                return
            end

            -- Formázott lista
            local lines = { "ID → Név (típus)\n" }
            for _, q in ipairs(list) do
                table.insert(lines, string.format(
                    "[%s] %s  (%s)",
                    q.id   or "?",
                    q.name or "?",
                    q.kind or "?"
                ))
            end

            pcall(function()
                questListParagraph:Set({
                    Title   = string.format("Elérhető questek (%d db)", #list),
                    Content = table.concat(lines, "\n"),
                })
            end)

            Rayfield:Notify({
                Title    = "Quest Lista",
                Content  = string.format("%d quest betöltve!", #list),
                Duration = 2,
            })
        end,
    })

    -- Quest ID input – ide bemásolja a fenti listáról az ID-t
    local curSelected = Cfg.get("AutoQuest", "selectedQuestId") or ""
    MainTab:CreateInput({
        Name                     = "Farm Quest ID (üres = mind)",
        CurrentValue             = curSelected,
        PlaceholderText          = "pl. quest_saiyan_001  (üres = minden quest)",
        RemoveTextAfterFocusLost = false,
        Flag                     = "AutoQuest_selectedQuestId",
        Callback                 = function(Value)
            local trimmed = Value and Value:match("^%s*(.-)%s*$") or ""
            Cfg.set("AutoQuest", "selectedQuestId", trimmed)
            Rayfield:Notify({
                Title    = "Quest Farm",
                Content  = trimmed == ""
                    and "Quest szűrő törölve – minden quest elfogadva."
                    or  ("Csak ez a quest: " .. trimmed),
                Duration = 2,
            })
        end,
    })

    -- Gyorsgomb: szűrő törlése
    MainTab:CreateButton({
        Name     = "Szűrő Törlése (Összes Quest)",
        Callback = function()
            Cfg.set("AutoQuest", "selectedQuestId", "")
            pcall(function()
                -- input Field visszaállítása – Rayfield Flag alapú reset
            end)
            Rayfield:Notify({
                Title    = "Quest Farm",
                Content  = "Szűrő törölve – minden quest elfogadva.",
                Duration = 2,
            })
        end,
    })

    MainTab:CreateDivider()
end

-- ── Config változás → UI szinkron ─────────────────────────────────
Cfg.onChange(function(mod, key, val)
    for _, item in ipairs(toggleElements) do
        if item.cfgKey == mod and item.key == key then
            if item.isDropdown then
                pcall(function()
                    item.element:Set(type(val) == "table" and val or { val })
                end)
            else
                pcall(function() item.element:Set(val) end)
            end
        end
    end
end)

-- ── Stat frissítő loop ────────────────────────────────────────────
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
            elseif sl.statFn then
                -- modKey nélküli kártya (pl. KillAura – CFG-ből olvassa)
                local ok2, text = pcall(sl.statFn, {})
                if ok2 and text then
                    pcall(function()
                        sl.element:Set({ Title="Statisztika", Content=text })
                    end)
                end
            end
        end
    end
end)

print("[GUI_Controller - Rayfield] OK")
