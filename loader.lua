-- ═══════════════════════════════════════════════════════════════
-- Domka modz - Master Loader
-- ═══════════════════════════════════════════════════════════════

local repoBase = "https://raw.githubusercontent.com/Dayooka/domka-modz/refs/heads/main/"

_G.KillAuraCFG = {
    ENABLED               = true,
    RANGE                 = 24,
    CHASE_RANGE           = 50,
    MAX_TARGETS           = 10,
    BURST_DELAY           = 0.004,
    MULTIPLY              = 2,
    MULT_DELAY            = 0.006,
    TARGET_PRIORITY       = "nearest",
    ATTACK_PLAYERS        = false,
    EXEC_THRESHOLD        = 0.15,
    EXEC_HOLD             = 0.3,
    EXEC_CD               = 2.5,
    BEHIND_OFFSET         = 2.5,
    BEHIND_RATE           = 0.08,
    UNDERGROUND_DEPTH     = 10,
    UNDERGROUND_ENABLED   = true,
    FREEZE_ENABLED        = true,

    AUTO_BLOCK_ENABLED    = false,
    AUTO_VANISH_ENABLED   = false,
    AUTO_DB_ENABLED       = false,
    AUTO_LOOT_ENABLED     = false,
    AUTO_SENZU_ENABLED    = false,
    AUTO_DAILY_ENABLED    = false,
    AUTO_NPC_FARM_ENABLED = false,
}

local modulesToLoad = {
    "_Config.lua",
    "_Shared.lua",
    "combat.lua",
    "01_AutoBlockParry.lua",
    "02_AutoVanish.lua",
    "03_AutoDragonBall.lua",
    "04_AutoLoot.lua",
    "05_AutoSenzu.lua",
    "06_AutoDaily.lua",
    "07_AutoNPCFarm.lua",
    "gui.lua",
}

print("[DOMKA MODZ] Modulok inicializálása...")

for _, fileName in ipairs(modulesToLoad) do
    local success, err = pcall(function()
        return loadstring(game:HttpGet(repoBase .. fileName))()
    end)
    if not success then
        warn("[DOMKA MODZ] Hiba a(z) " .. fileName .. " betöltésekor: ", err)
    else
        print("[DOMKA MODZ] Sikeresen betöltve: " .. fileName)
    end
end

print("[DOMKA MODZ] Rendszer elindult!")
