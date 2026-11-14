local Config = {}

local listeners = {}

function Config.onChange(fn)
    table.insert(listeners, fn)
    return #listeners
end

function Config.removeListener(idx)
    listeners[idx] = nil
end

local function fire(mod, key, val)
    for _, fn in pairs(listeners) do
        task.spawn(pcall, fn, mod, key, val)
    end
end

local data = {}

function Config.set(mod, key, value)
    if not data[mod] then data[mod] = {} end
    data[mod][key] = value
    fire(mod, key, value)
end

function Config.get(mod, key)
    return data[mod] and data[mod][key]
end

function Config.toggle(mod)
    local current = Config.get(mod, "enabled")
    Config.set(mod, "enabled", not current)
    return not current
end

function Config.getAll()
    local copy = {}
    for mod, cfg in pairs(data) do
        copy[mod] = {}
        for k, v in pairs(cfg) do copy[mod][k] = v end
    end
    return copy
end

function Config.setAllEnabled(enabled)
    for mod in pairs(data) do
        Config.set(mod, "enabled", enabled)
    end
end

function Config.getModules()
    local list = {}
    for mod in pairs(data) do table.insert(list, mod) end
    table.sort(list)
    return list
end

local defaults = {

    StateProbeBypass = {
        enabled = true,
    },

    ReleaseSkill = {
        enabled        = false,
        SKILL_TYPE     = "Melee",
        LOCK_ON_RANGE  = 24,
        BURST_DELAY    = 0.004,
        ATTACK_PLAYERS = false,
    },

    ZBurstDash = {
        enabled        = false,
        AUTO_DASH      = false,
        COOLDOWN_SPOOF = false,
    },

    MeleeClashMash = {
        enabled    = true,
        MASH_VALUE = 50,
        MASH_DELAY = 0.05,
    },

    Fishing = {
        enabled        = false,
        AUTO_BAIT      = true,
        SEQUENCE_DELAY = 0.3,
        JITTER         = 0.15,
    },

    Cooking = {
        enabled       = false,
        PRESS_DELAY   = 0.4,
        COLLECT_DELAY = 0.5,
    },

    Chamber = {
        enabled       = false,
        USE_AUTO_MODE = true,
        GRAVITY_LEVEL = 1,
        ACTION_DELAY  = 1.0,
    },

    Gym = {
        enabled                  = true,
        TIMING_OFFSET_SECONDS    = 0,
        SOLVER_ITERATIONS        = 48,
        HEARTBEAT_THRESHOLD      = 0.06,
        MAX_LATE_SECONDS         = 0.02,
    },

    KillAura = {
        enabled             = true,
        ATTACK_MODE         = "mixed",
        LIGHT_COUNT         = 4,
        LIGHT_MULTIPLY      = 2,
        MULT_DELAY          = 0.006,
        HEAVY_MULTIPLY      = 1,
        HEAVY_HOLD          = 0.22,
        BURST_DELAY         = 0.004,
        ATTACK_DELAY        = 0.0,
        RANGE               = 24,
        CHASE_RANGE         = 50,
        MAX_TARGETS         = 10,
        TARGET_PRIORITY     = "nearest",
        ATTACK_PLAYERS      = false,
        EXEC_ENABLED        = true,
        EXEC_THRESHOLD      = 0.15,
        EXEC_HOLD           = 0.3,
        EXEC_CD             = 2.5,
        BEHIND_OFFSET       = 2.5,
        BEHIND_RATE         = 0.08,
        TELEPORT_ENABLED    = true,
        UNDERGROUND_DEPTH   = 10,
        UNDERGROUND_ENABLED = true,
        FREEZE_ENABLED      = false,
    },

    BlockParry = {
        enabled          = true,
        PARRY_DELAY      = 0.06,
        BLOCK_HOLD       = 0.55,
        BLOCK_COOLDOWN   = 0.22,
        STEP_COOLDOWN    = 0.52,
        STEP_DIRS        = { "back", "left", "right" },
        HP_DROP_MIN      = 0.5,
        DEDUP_WIN        = 0.07,
        PREEMPTIVE       = false,
        PREEMPTIVE_RANGE = 20,
        PREEMPTIVE_REHOLD= 0.48,
    },

    Vanish = {
        enabled         = false,
        VANISH_DELAY    = 0.04,
        VANISH_COOLDOWN = 0.46,
        KI_VANISH       = 0.20,
        KI_STEP         = 0.06,
        CHAIN_MAX       = 4,
        CHAIN_RESET     = 2.5,
        POST_STEP       = true,
        POST_STEP_DELAY = 0.10,
        STEP_DIRS       = { "back", "left", "right" },
        FALLBACK        = { "SideStep", "Block" },
        BLOCK_HOLD      = 0.55,
        STEP_COOLDOWN   = 0.52,
        HP_DROP_MIN     = 0.5,
        DEDUP_WIN       = 0.07,
    },

    DragonBall = {
        enabled     = false,
        TP_OFFSET_Y = 3,
        TP_DELAY    = 0.30,
        MAX_RETRIES = 4,
        RETRY_DELAY = 0.18,
        AUTO_SUMMON = false,
        LOOP        = true,
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
        enabled      = false,
        TP_OFFSET_Y  = 3,
        TP_DELAY     = 0.22,
        SCAN_INTERVAL= 1.0,
        MAX_PER_SCAN = 40,
        LOOT_FOLDERS = { "LootDrops","MapLoot","WorldDrops","IngredientPickups" },
    },

    Senzu = {
        enabled       = false,
        CALL_DELAY    = 0.55,
        CHECK_INTERVAL= 25,
        AUTO_REPLANT  = true,
        TP_TO_FARM    = true,
        TP_OFFSET_Y   = 4,
    },

    Daily = {
        enabled     = false,
        CALL_DELAY  = 0.70,
        MAX_RETRIES = 3,
        SPIN_MAX    = 7,
        AUTO_LOOP   = true,
        LOOP_HOURS  = 24,
        CLAIM_EXTRAS= true,
    },

    NPCFarm = {
        enabled           = false,
        LIGHT_COUNT       = 4,
        HEAVY_AFTER_LIGHT = true,
        GRAB_ENABLED      = true,
        GRAB_HOLD         = 0.32,
        ATTACK_CD         = 0.18,
        COMBO_DELAY       = 0.22,
        TELEPORT_TO_NPC   = true,
        TP_OFFSET         = Vector3.new(0, 1, 2),
        SCAN_RANGE        = 150,
        LOOP_DELAY        = 0.5,
    },

    -- ── AutoQuest ─────────────────────────────────────────────────
    AutoQuest = {
        enabled          = false,
        autoDialog       = true,
        autoBoard        = false,
        autoErrand       = false,
        autoDaily        = false,
        autoComplete     = true,
        autoTeleport     = true,
        autoDialogue     = true,
        acceptDelay      = 0,
        cooldown         = 2,
        teleportOffset   = 12,
        teleportHeight   = 4,
        checkInterval    = 1,
        dialogueDelay    = 0.6,
        -- Quest kiválasztás
        -- Üres string = minden questet elfogad
        -- Quest ID = csak azt a questet farmolj
        selectedQuestId  = "",
    },

    -- ── AutoLongevity ─────────────────────────────────────────────
    AutoLongevity = {
        enabled             = false,
        healthThreshold     = 0.6,   -- HP % küszöb (0.6 = 60%)
        longevityThreshold  = 0.6,   -- Longevity % küszöb
        usePods             = true,  -- HealingPod használata
        teleportToPod       = true,  -- Pod-hoz teleportálás
        podOffset           = 5,     -- Távolság a pod-tól (studs)
        podHeight           = 3,     -- Magasság (studs)
        useRest             = true,  -- Pihenés ha nincs pod
        checkInterval       = 1,     -- Ellenőrzési frekvencia (s)
        healTimeout         = 180,   -- Max gyógyulási idő (s)
        exitOffset          = 12,    -- Kilépési távolság (studs)
    },
}

for mod, cfg in pairs(defaults) do
    data[mod] = {}
    for k, v in pairs(cfg) do data[mod][k] = v end
end

_G._AIO_Config = Config
return Config
