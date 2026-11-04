-- ═══════════════════════════════════════════════════════════════

local repoBase = "https://raw.githubusercontent.com/Dayooka/domka-modz/refs/heads/main/"

-- Globális konfigurációs tábla a v7-es összes opcióval
getgenv().DomkaConfig = {
    -- Basic Aura settings
    RANGE                     = 24,
    CHASE_RANGE               = 50,
    MAX_TARGETS               = 10,
    BURST_DELAY               = 0.004,
    MULTIPLY                  = 2,
    MULT_DELAY                = 0.006,

    -- Execution settings
    EXEC_THRESHOLD            = 0.15,
    EXEC_HOLD                 = 0.3,
    EXEC_CD                   = 2.0,

    -- Direct Damage & Position
    DIRECT_DMG                = 20,
    DIRECT_RATE               = 0.08,
    BEHIND_OFFSET             = 2.5,
    BEHIND_RATE               = 0.03,
    UNDERGROUND_DEPTH         = 12,

    -- Advanced v7 Toggles
    ATTACK_PLAYERS            = false,
    ATTACK_PLAYERS_THRESHOLD  = 0.3,
    FREEZE_ENABLED            = true,
    FREEZE_RATE               = 0,
    BEHIND_ON_ATTACK          = true,
    UNDERGROUND_AFTER_BURST   = false,
}

-- 1. Háttérlogika (Combat) betöltése
local successCombat, combatErr = pcall(function()
    return loadstring(game:HttpGet(repoBase .. "combat.lua"))()
end)

if not successCombat then
    warn("[DOMKA MODZ] Hiba a combat script betöltésekor: ", combatErr)
    return
end

-- 2. GUI betöltése
local successGui, guiErr = pcall(function()
    return loadstring(game:HttpGet(repoBase .. "gui.lua"))()
end)

if not successGui then
    warn("[DOMKA MODZ] Hiba a GUI betöltésekor: ", guiErr)
    return
end

print("[DOMKA MODZ]")
