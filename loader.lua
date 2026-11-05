-- ═══════════════════════════════════════════════════════════════
-- Domka modz - Master Loader (v8 Final Architecture)
-- ═══════════════════════════════════════════════════════════════

local repoBase = "https://raw.githubusercontent.com/Dayooka/domka-modz/refs/heads/main/"

-- Globális Master Config (GUI & Modulok által megosztott)
_G.KillAuraCFG = {
    -- ── KillAura v8 ──────────────────────────────────────────
    ENABLED                 = true,
    RANGE                   = 24,
    CHASE_RANGE             = 50,
    MAX_TARGETS             = 10,
    BURST_DELAY             = 0.004,
    MULTIPLY                = 2,
    MULT_DELAY              = 0.006,
    TARGET_PRIORITY         = "nearest", -- "nearest", "lowest_hp", "mixed"
    ATTACK_PLAYERS          = false,
    EXEC_THRESHOLD          = 0.15,
    EXEC_HOLD               = 0.3,
    EXEC_CD                 = 2.0,
    BEHIND_OFFSET           = 2.5,
    BEHIND_RATE             = 0.03,
    BEHIND_ON_ATTACK        = true,
    UNDERGROUND_DEPTH       = 10,
    UNDERGROUND_ENABLED     = true,
    FREEZE_ENABLED          = true,

    -- ── Védelmi és Automata Modul Kapcsolók ─────────────────
    AUTO_BLOCK_ENABLED      = true,
    AUTO_VANISH_ENABLED     = true,
    AUTO_DB_ENABLED         = true,
    AUTO_LOOT_ENABLED       = true,
    AUTO_SENZU_ENABLED      = true,
    AUTO_DAILY_ENABLED      = true,
    AUTO_NPC_FARM_ENABLED   = true,
}

-- Modulok betöltési sorrendje
local modulesToLoad = {
    "combat.lua",    -- KillAura v8 Logic
    "autoblock.lua", -- Auto Block & Parry
    "autovanish.lua",-- Auto Vanish PRO
    "autodb.lua",    -- Auto Dragon Ball Collector
    "autoloot.lua",  -- Auto Loot Farm
    "autosenzu.lua", -- Auto Senzu Farm
    "autodaily.lua", -- Auto Daily & AFK Rewards
    "npcfarm.lua",   -- Auto NPC Kill Farm
    "gui.lua",       -- Rayfield Master GUI
}

print("[DOMKA MODZ] Modulok betöltése folyamatban...")

for _, fileName in ipairs(modulesToLoad) do
    local success, err = pcall(function()
        return loadstring(game:HttpGet(repoBase .. fileName))()
    end)
    if not success then
        warn("[DOMKA MODZ] Hiba a " .. fileName .. " betöltésekor: ", err)
    else
        print("[DOMKA MODZ] Betöltve: " .. fileName)
    end
end

print("[DOMKA MODZ] Minden modul és a Master GUI sikeresen elindult!")
