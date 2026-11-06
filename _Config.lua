--[[
    _Config  –  Központi Konfiguráció
    Minden modul innen olvassa a beállításait és az enabled státuszokat.
]]

local Cfg = {
    KillAura = {
        enabled             = true,
        RANGE               = 24,
        CHASE_RANGE         = 50,
        MAX_TARGETS         = 10,
        BURST_DELAY         = 0.004,
        MULTIPLY            = 2,
        MULT_DELAY          = 0.006,
        TARGET_PRIORITY     = "nearest",
        ATTACK_PLAYERS      = false,
        EXEC_THRESHOLD      = 0.15,
        EXEC_HOLD           = 0.3,
        EXEC_CD             = 2.5,
        BEHIND_OFFSET       = 2.5,
        BEHIND_RATE         = 0.08,
        UNDERGROUND_DEPTH   = 10,
        UNDERGROUND_ENABLED = true,
        FREEZE_ENABLED      = true,
    },
    BlockParry = {
        enabled             = false, -- Alapból kikapcsolva
        PARRY_DELAY         = 0.06,
        STEP_COOLDOWN       = 0.52,
        BLOCK_HOLD          = 0.55,
        BLOCK_COOLDOWN      = 0.22,
        STEP_DIRS           = { "back", "left", "right" },
        HP_DROP_MIN         = 0.5,
        DEDUP_WIN           = 0.07,
        PREEMPTIVE          = false,
        PREEMPTIVE_RANGE    = 20,
        PREEMPTIVE_REHOLD   = 0.48,
    },
    Vanish = {
        enabled             = false, -- Alapból kikapcsolva
        VANISH_DELAY        = 0.04,
        VANISH_COOLDOWN     = 0.46,
        KI_VANISH           = 0.20,
        KI_STEP             = 0.06,
        CHAIN_MAX           = 4,
        CHAIN_RESET         = 2.5,
        POST_STEP           = true,
        POST_STEP_DELAY     = 0.10,
        STEP_DIRS           = { "back", "left", "right" },
        FALLBACK            = { "SideStep", "Block" },
        BLOCK_HOLD          = 0.55,
        STEP_COOLDOWN       = 0.52,
        HP_DROP_MIN         = 0.5,
        DEDUP_WIN           = 0.07,
    },
    DragonBall = {
        enabled             = false, -- Alapból kikapcsolva
        TP_OFFSET_Y         = 3,
        TP_DELAY            = 0.30,
        MAX_RETRIES         = 4,
        RETRY_DELAY         = 0.18,
        AUTO_SUMMON         = false,
        LOOP                = true,
        EARTH               = { "DragonBall_01","DragonBall_02","DragonBall_03","DragonBall_04","DragonBall_05","DragonBall_06","DragonBall_07" },
        NAMEK               = { "NamekDragonBall_01","NamekDragonBall_02","NamekDragonBall_03","NamekDragonBall_04","NamekDragonBall_05","NamekDragonBall_06","NamekDragonBall_07" },
    },
    Loot = {
        enabled             = false, -- Alapból kikapcsolva
        TP_OFFSET_Y         = 3,
        TP_DELAY            = 0.22,
        SCAN_INTERVAL       = 1.0,
        MAX_PER_SCAN        = 40,
        LOOT_FOLDERS        = { "LootDrops", "MapLoot", "WorldDrops", "IngredientPickups" },
    },
    Senzu = {
        enabled             = false, -- Alapból kikapcsolva
        CALL_DELAY          = 0.55,
        CHECK_INTERVAL      = 25,
        AUTO_REPLANT        = true,
        TP_TO_FARM          = true,
        TP_OFFSET_Y         = 4,
    },
    Daily = {
        enabled             = false, -- Alapból kikapcsolva
        CALL_DELAY          = 0.70,
        MAX_RETRIES         = 3,
        RETRY_DELAY         = 1.2,
        SPIN_MAX            = 7,
        AUTO_LOOP           = true,
        LOOP_HOURS          = 24,
        CLAIM_EXTRAS        = true,
    },
    NPCFarm = {
        enabled             = false, -- Alapból kikapcsolva
        LIGHT_COUNT         = 4,
        HEAVY_AFTER_LIGHT   = true,
        GRAB_ENABLED        = true,
        GRAB_HOLD           = 0.32,
        ATTACK_CD           = 0.18,
        COMBO_DELAY         = 0.22,
        SCAN_RANGE          = 150,
        LOOP_DELAY          = 0.5,
        TELEPORT_TO_NPC     = true,
        TP_OFFSET           = Vector3.new(0, 1, 2),
    }
}

local listeners = {}

local Module = {}
function Module.get(modName, key)
    if not Cfg[modName] then return nil end
    if key == nil then return Cfg[modName] end
    return Cfg[modName][key]
end

function Module.set(modName, key, val)
    if Cfg[modName] then
        Cfg[modName][key] = val
        for _, cb in ipairs(listeners) do
            pcall(cb, modName, key, val)
        end
    end
end

function Module.onChange(cb)
    table.insert(listeners, cb)
end

_G.KillAuraCFG = Cfg.KillAura
return Module
