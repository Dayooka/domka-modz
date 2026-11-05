-- ═══════════════════════════════════════════════════════════════
local repoBase = "https://raw.githubusercontent.com/Dayooka/domka-modz/refs/heads/main/"

-- Globális konfigurációs tábla a v8-as összes új opcióval
_G.KillAuraCFG = {
    -- ── Fő kapcsoló ───────────────────────────────────────────
    ENABLED           = true,

    -- ── Aura ──────────────────────────────────────────────────
    RANGE             = 24,
    CHASE_RANGE       = 50,
    MAX_TARGETS       = 10,
    BURST_DELAY       = 0.004,
    MULTIPLY          = 2,
    MULT_DELAY        = 0.006,

    -- ── Célpont prioritás ─────────────────────────────────────
    TARGET_PRIORITY   = "nearest", -- "nearest", "lowest_hp", "mixed"

    -- ── Player targeting ──────────────────────────────────────
    ATTACK_PLAYERS    = false,

    -- ── Execution (Grab) ──────────────────────────────────────
    EXEC_THRESHOLD    = 0.15,
    EXEC_HOLD         = 0.3,
    EXEC_CD           = 2.0,

    -- ── Pozíció ───────────────────────────────────────────────
    BEHIND_OFFSET     = 2.5,
    BEHIND_RATE       = 0.03,
    BEHIND_ON_ATTACK  = true,

    -- ── Underground ───────────────────────────────────────────
    UNDERGROUND_DEPTH = 10,
    UNDERGROUND_ENABLED = true,

    -- ── Freeze ────────────────────────────────────────────────
    FREEZE_ENABLED    = true,
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

print("[DOMKA MODZ] Minden v8 modul sikeresen betöltve!")
