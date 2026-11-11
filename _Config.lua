--[[
╔══════════════════════════════════════════════════════════════════════╗
║  _Config  –  ModuleScript                                           ║
║  Elhelyezés: StarterPlayerScripts > AIOScripts > _Config            ║
║                                                                      ║
║  GUI-ból így használd:                                               ║
║    local Cfg = require(script.Parent._Config)                       ║
║                                                                      ║
║  Ki/bekapcsolás:                                                     ║
║    Cfg.set("BlockParry","enabled", true)                            ║
║    Cfg.toggle("Vanish")                                              ║
║                                                                      ║
║  Érték olvasás:                                                      ║
║    Cfg.get("BlockParry","BLOCK_HOLD")  → 0.55                       ║
║    Cfg.get("Vanish","enabled")         → true/false                 ║
║                                                                      ║
║  Változás figyelése:                                                 ║
║    Cfg.onChange(function(module, key, value) ... end)               ║
║                                                                      ║
║  Összes állapot:                                                     ║
║    Cfg.getAll()  →  { BlockParry={enabled=true,...}, ... }          ║
╚══════════════════════════════════════════════════════════════════════╝
]]

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

    -- ── StateProbeBypass ─────────────────────────────────────────
    -- Doksi 5. fejezet: StateProbeReport hookolása → mindig "tiszta" állapot
    -- Doksi 14.5.A: Ez a LEGELSŐ amit érdemes megcsinálni
    StateProbeBypass = {
        enabled = true,
    },

    -- ── ReleaseSkill (Skill KillAura) ────────────────────────────
    -- Doksi 14.2.A: ReleaseSkill + SetLockOnTarget combo
    -- Erősebb mint PerformAction mert a szerver skill-sebzést számol
    ReleaseSkill = {
        enabled        = false,  -- Óvatosan – erős!
        SKILL_TYPE     = "Melee", -- "Melee" | "Ki" | "Beam"
        LOCK_ON_RANGE  = 24,     -- LockOn.MAX_RANGE = 1000, de 24 biztonságos
        BURST_DELAY    = 0.004,
        ATTACK_PLAYERS = false,
    },

    -- ── ZBurstDash ───────────────────────────────────────────────
    -- Doksi 14.3.C: ZBurstDash spam mozgáshoz
    -- Config: COOLDOWN=10, ARRIVAL_RADIUS=12, TARGET_ARRIVAL_TIME=1.5
    ZBurstDash = {
        enabled       = false,
        AUTO_DASH     = false,   -- Auto dash legközelebbi NPC-hez
        COOLDOWN_SPOOF= false,   -- ZBurstDashReadyAt = 0 (attrib reset)
    },

    -- ── MeleeClashMash ───────────────────────────────────────────
    -- Doksi 14.2.C: Clash-ban auto mash → mindig megnyeri a clash-t
    MeleeClashMash = {
        enabled   = true,
        MASH_VALUE= 50,   -- Küldött mash érték (emberi max ~15-20 CPS)
        MASH_DELAY= 0.05, -- Küldések között (ne legyen 0!)
    },

    -- ── Auto Fishing ─────────────────────────────────────────────
    -- Doksi 14.4.B: Horgász szekvencia automatizálása
    Fishing = {
        enabled       = false,
        AUTO_BAIT     = true,
        SEQUENCE_DELAY= 0.3,   -- Emberi-szerű delay a lépések közt
        JITTER        = 0.15,  -- Random jitter (antidetect)
    },

    -- ── Auto Cooking ─────────────────────────────────────────────
    -- Doksi 4.9: CookingDone/Judged kliensjelentés
    Cooking = {
        enabled        = false,
        PRESS_DELAY    = 0.4,
        COLLECT_DELAY  = 0.5,
    },

    -- ── Auto Chamber (Gravity Chamber) ───────────────────────────
    -- Doksi 14.4: RequestChamberAuto – XP farm
    Chamber = {
        enabled       = false,
        USE_AUTO_MODE = true,   -- RequestChamberAuto (egyszerűbb)
        GRAVITY_LEVEL = 1,      -- RequestChamberGravity szint
        ACTION_DELAY  = 1.0,
    },

    Gym = {
        enabled               = true,
        TIMING_OFFSET_SECONDS = 0,       -- Timing eltolás (s) – negatív = korábban küld
        SOLVER_ITERATIONS     = 48,      -- Bisection pontosság
        HEARTBEAT_THRESHOLD   = 0.06,    -- Heartbeat váltás küszöb (s)
        MAX_LATE_SECONDS      = 0.02,    -- Max késés ami még elfogadott
    },

    KillAura = {
        enabled           = true,

        -- ── Támadás mód ─────────────────────────────────────────
        -- "light"  = csak LightAttack
        -- "heavy"  = csak HeavyAttack
        -- "mixed"  = Light combo majd Heavy finisher (LLLLM)
        -- "grab"   = csak Grab (execute)
        ATTACK_MODE       = "mixed",

        -- ── Combo beállítások ────────────────────────────────────
        LIGHT_COUNT       = 4,       -- Hány Light előtt jön Heavy (mixed módban)
        LIGHT_MULTIPLY    = 2,       -- LightAttack szerver-oldali sokszorozás
        MULT_DELAY        = 0.006,   -- Sokszorozás delay (s)
        HEAVY_MULTIPLY    = 1,       -- HeavyAttack sokszorozás
        HEAVY_HOLD        = 0.22,    -- HeavyAttack tartás (s)

        -- ── Timing ──────────────────────────────────────────────
        BURST_DELAY       = 0.004,   -- Multi-target burst delay (s)
        ATTACK_DELAY      = 0.0,     -- Extra delay ütések között (s)

        -- ── Távolság ────────────────────────────────────────────
        RANGE             = 24,      -- Támadási sugár (studs)
        CHASE_RANGE       = 50,      -- Üldözési sugár (studs)
        MAX_TARGETS       = 10,      -- Max egyidejű célpont

        -- ── Célpont prioritás ────────────────────────────────────
        -- "nearest" | "lowest_hp" | "mixed"
        TARGET_PRIORITY   = "nearest",
        ATTACK_PLAYERS    = false,

        -- ── Execute (knockdown/grab) ─────────────────────────────
        EXEC_ENABLED      = true,    -- Execute fázis engedélyezése
        EXEC_THRESHOLD    = 0.15,    -- HP % alatt execute fázis
        EXEC_HOLD         = 0.3,     -- Grab tartás idő (s)
        EXEC_CD           = 2.5,     -- Execute cooldown (s)

        -- ── Pozíció ─────────────────────────────────────────────
        BEHIND_OFFSET     = 2.5,
        BEHIND_RATE       = 0.08,
        TELEPORT_ENABLED  = true,    -- Mögé teleport engedélyezése

        -- ── Underground ─────────────────────────────────────────
        UNDERGROUND_DEPTH   = 10,
        UNDERGROUND_ENABLED = true,

        -- ── Freeze ──────────────────────────────────────────────
        FREEZE_ENABLED    = false,
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
        enabled           = false,
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
        enabled           = false,
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
        enabled           = false,
        TP_OFFSET_Y       = 3,
        TP_DELAY          = 0.22,
        SCAN_INTERVAL     = 1.0,
        MAX_PER_SCAN      = 40,
        LOOT_FOLDERS      = { "LootDrops","MapLoot","WorldDrops","IngredientPickups" },
    },

    Senzu = {
        enabled           = false,
        CALL_DELAY        = 0.55,
        CHECK_INTERVAL    = 25,
        AUTO_REPLANT      = true,
        TP_TO_FARM        = true,
        TP_OFFSET_Y       = 4,
    },

    Daily = {
        enabled           = false,
        CALL_DELAY        = 0.70,
        MAX_RETRIES       = 3,
        SPIN_MAX          = 7,
        AUTO_LOOP         = true,
        LOOP_HOURS        = 24,
        CLAIM_EXTRAS      = true,
    },
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
