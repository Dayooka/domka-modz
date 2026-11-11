-- ═══════════════════════════════════════════════════════════════
-- Domka Modz - Master Loader
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

    AUTO_BLOCK_ENABLED    = true,
    AUTO_VANISH_ENABLED   = true,
    AUTO_DB_ENABLED       = false,
    AUTO_LOOT_ENABLED     = false,
    AUTO_SENZU_ENABLED    = false,
    AUTO_DAILY_ENABLED    = false,
    AUTO_NPC_FARM_ENABLED = false,
}

_G._AIO_Modules = {}

-- Betöltési sorrend:
-- 1. _Config + _Shared (ezektől függenek a többiek)
-- 2. combat (KillAura)
-- 3. AIO modulok
-- 4. npcfarm
-- 5. gui (utoljára, mikor minden modul már fut)
local modulesToLoad = {
    "_Config.lua",
    "_Shared.lua",
    "antidetect.lua",   -- StateProbeBypass – LEGELŐSZÖR!
    "combat.lua",
    "clashmash.lua",    -- Clash mash – combat előtt init
    "autoblock.lua",
    "autovanish.lua",
    "autodb.lua",
    "autoloot.lua",
    "autosenzu.lua",
    "autodaily.lua",
    "npcfarm.lua",
    "releaseskill.lua",
    "autofishing.lua",
    "autochamber.lua",
    "gym.lua",
    "autoquest.lua",
    "gui.lua",
}

print("[DOMKA MODZ] Modulok inicializalasa...")

for _, fileName in ipairs(modulesToLoad) do
    local ok, err = pcall(function()
        -- Cache-bust: timestamp hozzáadása hogy mindig friss verziót kapjon
        local url = repoBase .. fileName .. "?t=" .. tostring(os.time())
        local src = game:HttpGet(url)
        if not src or src == "" then
            error("Ures valasz / nem talalhato")
        end
        local fn, loadErr = loadstring(src)
        if not fn then
            error("loadstring hiba: " .. tostring(loadErr))
        end
        fn()
    end)
    if not ok then
        warn("[DOMKA MODZ] Hiba: " .. fileName .. " -> " .. tostring(err))
    else
        print("[DOMKA MODZ] OK: " .. fileName)
    end
    task.wait(0.05)
end

print("[DOMKA MODZ] Rendszer elindult!")
