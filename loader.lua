-- ═══════════════════════════════════════════════════════════════
-- Domka modz - Master Loader (GitHub Sync)
-- ═══════════════════════════════════════════════════════════════

local repoBase = "https://raw.githubusercontent.com/Dayooka/domka-modz/refs/heads/main/"

-- KillAura globális konfiguráció
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
}

-- Pontosan a képen látható fájlnevek sorrendben:
local modulesToLoad = {
    "_Config.lua",
    "_Shared.lua",
    "combat.lua",
    "autoblock.lua",
    "autovanish.lua",
    "autodb.lua",
    "autoload.lua",
    "autosenzu.lua",
    "autodaily.lua",
    "npcfarm.lua",
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

print("[DOMKA MODZ] Teljes rendszer aktív!")
