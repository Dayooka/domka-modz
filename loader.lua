-- ═══════════════════════════════════════════════════════════════
local repoBase = "https://raw.githubusercontent.com/Dayooka/domka-modz/refs/heads/main/"

-- Globális Master Config (A farmok és védelmek alapból FALSE / inaktívak)
_G.KillAuraCFG = {
    -- ── KillAura v8 Konfiguráció ──────────────────────────────
    ENABLED             = false,
    RANGE               = 24,
    CHASE_RANGE         = 50,
    MAX_TARGETS         = 10,
    BURST_DELAY         = 0.004,
    MULTIPLY            = 2,
    MULT_DELAY          = 0.006,
    TARGET_PRIORITY     = "nearest", -- "nearest", "lowest_hp", "mixed"
    ATTACK_PLAYERS      = false,
    EXEC_THRESHOLD      = 0.15,
    EXEC_HOLD           = 0.3,
    EXEC_CD             = 2.0,
    BEHIND_OFFSET       = 2.5,
    BEHIND_RATE         = 0.03,
    BEHIND_ON_ATTACK    = true,
    UNDERGROUND_DEPTH   = 10,
    UNDERGROUND_ENABLED = true,
    FREEZE_ENABLED      = false,

    -- ── Külső Farm & Védelmi Modul Kapcsolók (Alapból kikapcsolva) ─
    AUTO_BLOCK_ENABLED    = false,
    AUTO_VANISH_ENABLED   = false,
    AUTO_DB_ENABLED       = false,
    AUTO_LOOT_ENABLED     = false,
    AUTO_SENZU_ENABLED    = false,
    AUTO_DAILY_ENABLED    = false,
    AUTO_NPC_FARM_ENABLED = false,
}

-- Betöltendő modulok listája sorrendben
local modulesToLoad = {
    "combat.lua",    -- KillAura v8 Logika
    "autoblock.lua", -- Auto Block & Parry (HUD nélkül)
    "autovanish.lua",-- Auto Vanish PRO (HUD nélkül)
    "autodb.lua",    -- Auto Dragon Ball (HUD nélkül)
    "autoloot.lua",  -- Auto Loot Farm (HUD nélkül)
    "autosenzu.lua", -- Auto Senzu Farm (HUD nélkül)
    "autodaily.lua", -- Auto Daily & AFK (HUD nélkül)
    "npcfarm.lua",   -- Auto NPC Kill Farm (HUD nélkül)
    "gui.lua",       -- Master Rayfield GUI
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

print("[DOMKA MODZ] Minden v8 rendszer aktív!")
