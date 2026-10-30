-- ═══════════════════════════════════════════════════════════════
-- Domka modz - Loader
-- ═══════════════════════════════════════════════════════════════

local repoBase = "https://raw.githubusercontent.com/Dayooka/domka-modz/refs/heads/main/"

-- Globális konfigurációs tábla, hogy a GUI és a Combat is elérje ugyanazokat az értékeket
getgenv().DomkaConfig = {
    RANGE = 25,
    MAX_TARGETS = 10,
    BURST_DELAY = 0.004,
    MULTIPLY = 3,
    MULT_DELAY = 0.004,
    EXEC_THRESHOLD = 0.15,
    EXEC_HOLD = 0.3,
    EXEC_CD = 2.0,
    DIRECT_DMG = 20,
    DIRECT_RATE = 0.08,
    BEHIND_OFFSET = 2.5,
    BEHIND_RATE = 0.08,
    UNDERGROUND_DEPTH = 12,
    UV_RESET_RATE = 0.05,
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

print("[DOMKA MODZ] Minden modul sikeresen betöltve!")
