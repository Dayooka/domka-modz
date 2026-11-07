local Config = {}

-- ══════════════════════════════════════════
-- CHANGE LISTENER
-- ══════════════════════════════════════════
local listeners = {}

function Config.onChange(fn)
    table.insert(listeners, fn)
    return #listeners  -- visszaadja az index-et, ha le akarod szedni
end

function Config.removeListener(idx)
    listeners[idx] = nil
end

local function fire(mod, key, val)
    for _, fn in pairs(listeners) do
        task.spawn(pcall, fn, mod, key, val)
    end
end

-- ══════════════════════════════════════════
-- BELSŐ ADATTÁR
-- ══════════════════════════════════════════
local data = {}

-- ══════════════════════════════════════════
-- PUBLIKUS API
-- ══════════════════════════════════════════

-- Érték beállítása + listener értesítés
function Config.set(mod, key, value)
    if not data[mod] then data[mod] = {} end
    data[mod][key] = value
    fire(mod, key, value)
end

-- Érték olvasása
function Config.get(mod, key)
    return data[mod] and data[mod][key]
end

-- Toggle (enabled flag)
function Config.toggle(mod)
    local current = Config.get(mod, "enabled")
    Config.set(mod, "enabled", not current)
    return not current
end

-- Összes adat olvasása (GUI snapshot-hoz)
function Config.getAll()
    local copy = {}
    for mod, cfg in pairs(data) do
        copy[mod] = {}
        for k, v in pairs(cfg) do copy[mod][k] = v end
    end
    return copy
end

-- Összes modul ki/bekapcsolása
function Config.setAllEnabled(enabled)
    for mod in pairs(data) do
        Config.set(mod, "enabled", enabled)
    end
end

-- Modul-lista (GUI-nak)
function Config.getModules()
    local list = {}
    for mod in pairs(data) do table.insert(list, mod) end
    table.sort(list)
    return list
end

-- ══════════════════════════════════════════
-- ALAPÉRTELMEZETT ÉRTÉKEK
-- ══════════════════════════════════════════
local defaults = {

    KillAura = {
        enabled           = true,    -- _G.KillAuraCFG.ENABLED

        -- Távolság
        RANGE             = 24,      -- Támadási sugár (studs)
        CHASE_RANGE       = 50,      -- Üldözési sugár (studs)
        MAX_TARGETS       = 10,      -- Max egyidejű célpont

        -- Támadás timing
        BURST_DELAY       = 0.004,   -- Burst ütések közötti delay
        MULTIPLY          = 2,       -- LightAttack sokszorozás
        MULT_DELAY        = 0.006,   -- Sokszorozás delay

        -- Célpont prioritás: "nearest" | "lowest_hp" | "mixed"
        TARGET_PRIORITY   = "nearest",

        -- Játékos támadás
        ATTACK_PLAYERS    = false,

        -- Execute (knockdown/grab)
        EXEC_THRESHOLD    = 0.15,    -- HP % alatt execute fázis
        EXEC_HOLD         = 0.3,     -- Grab tartás idő (s)
        EXEC_CD           = 2.5,     -- Execute cooldown (s)

        -- Pozíció
        BEHIND_OFFSET     = 2.5,     -- Mögé teleport távolság
        BEHIND_RATE       = 0.08,    -- Mögé teleport min intervallum

        -- Underground (incapacitated állapotban)
        UNDERGROUND_DEPTH   = 10,
        UNDERGROUND_ENABLED = true,

        -- Freeze (NPC-k befagyasztása)
        FREEZE_ENABLED    = true,
    },

    BlockParry = {
        enabled           = true,
        PARRY_DELAY       = 0.06,
        BLOCK_HOLD        = 0.55,
        BLOCK_COOLDOWN    = 0.22,
        STEP_COOLDOWN     = 0.52,
        STEP_DIRS         = { "back", "left", "right" },
        HP_DROP_MIN       = 0.5,
        DEDUP_WIN         = 0.07,
        PREEMPTIVE        = false,
        PREEMPTIVE_RANGE  = 20,
        PREEMPTIVE_REHOLD = 0.48,
    },

    Vanish = {
        enabled           = true,
        VANISH_DELAY      = 0.04,
        VANISH_COOLDOWN   = 0.46,
        KI_VANISH         = 0.20,
        KI_STEP           = 0.06,
        CHAIN_MAX         = 4,
        CHAIN_RESET       = 2.5,
        POST_STEP         = true,
        POST_STEP_DELAY   = 0.10,
        STEP_DIRS         = { "back", "left", "right" },
        FALLBACK          = { "SideStep", "Block" },
        BLOCK_HOLD        = 0.55,
        STEP_COOLDOWN     = 0.52,
        HP_DROP_MIN       = 0.5,
        DEDUP_WIN         = 0.07,
    },

    DragonBall = {
        enabled           = true,
        TP_OFFSET_Y       = 3,
        TP_DELAY          = 0.30,
        MAX_RETRIES       = 4,
        RETRY_DELAY       = 0.18,
        AUTO_SUMMON       = false,
        LOOP              = true,
        EARTH = {
            "DragonBall_01","DragonBall_02","DragonBall_03",
            "DragonBall_04","DragonBall_05","DragonBall_06","DragonBall_07",
        },
        NAMEK = {
            "NamekDragonBall_01","NamekDragonBall_02","NamekDragonBall_03",
            "NamekDragonBall_04","NamekDragonBall_05","NamekDragonBall_06",
            "NamekDragonBall_07",
        },
    },

    Loot = {
        enabled           = true,
        TP_OFFSET_Y       = 3,
        TP_DELAY          = 0.22,
        SCAN_INTERVAL     = 1.0,
        MAX_PER_SCAN      = 40,
        LOOT_FOLDERS      = { "LootDrops","MapLoot","WorldDrops","IngredientPickups" },
    },

    Senzu = {
        enabled           = true,
        CALL_DELAY        = 0.55,
        CHECK_INTERVAL    = 25,
        AUTO_REPLANT      = true,
        TP_TO_FARM        = true,
        TP_OFFSET_Y       = 4,
    },

    Daily = {
        enabled           = true,
        CALL_DELAY        = 0.70,
        MAX_RETRIES       = 3,
        SPIN_MAX          = 7,
        AUTO_LOOP         = true,
        LOOP_HOURS        = 24,
        CLAIM_EXTRAS      = true,
    },

    NPCFarm = {
        enabled           = true,
        LIGHT_COUNT       = 4,
        HEAVY_AFTER_LIGHT = true,
        GRAB_ENABLED      = true,
        GRAB_HOLD         = 0.32,
        ATTACK_CD         = 0.18,
        COMBO_DELAY       = 0.22,
        TELEPORT_TO_NPC   = true,
        TP_OFFSET         = Vector3.new(0,1,2),
        SCAN_RANGE        = 150,
        LOOP_DELAY        = 0.5,
    },
}

-- Defaults betöltése a data táblába (listener nélkül – csendesen)
for mod, cfg in pairs(defaults) do
    data[mod] = {}
    for k, v in pairs(cfg) do data[mod][k] = v end
end

_G._AIO_Config = Config
return Config
