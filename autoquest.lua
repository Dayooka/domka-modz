-- autoquest.lua
-- Híd: AutoQuest modul <-> _Config <-> GUI

local Cfg    = _G._AIO_Config
local Shared = _G._AIO_Shared

if not Cfg then
    warn("[AutoQuest] _Config nem talalhato!")
    return
end

-- AutoQuest betöltése (a te saját autoquest modeled)
local AutoQuest = require(game.ReplicatedStorage.Modules.AutoQuest)

-- ── Stat számlálók ───────────────────────────────────────────────
local stats = {
    active    = 0,
    accepted  = 0,
    ended     = 0,
    lastQuest = "-",
}

-- Elfogadás számláló
AutoQuest.onAccepted(function(questId, source)
    stats.accepted  = stats.accepted + 1
    stats.lastQuest = questId
end)

-- Befejezés számláló
AutoQuest.onEnded(function(payload)
    stats.ended = stats.ended + 1
    local id = type(payload) == "table"
        and (payload.questId or payload.id or payload.lesson)
        or tostring(payload)
    if id then stats.lastQuest = tostring(id) end
end)

-- Aktív quest szám frissítése
task.spawn(function()
    while true do
        task.wait(1)
        local count = 0
        for _ in pairs(AutoQuest.activeQuests) do count += 1 end
        stats.active = count
    end
end)

-- ── Config → AutoQuest szinkron ──────────────────────────────────
-- Config értékek átírása az AutoQuest modulba
local SYNC_KEYS = {
    "autoDialog", "autoBoard", "autoErrand", "autoDaily",
    "autoComplete", "autoTeleport", "autoDialogue",
    "acceptDelay", "cooldown", "teleportOffset",
    "teleportHeight", "checkInterval", "dialogueDelay",
}

local function syncToAutoQuest()
    for _, key in SYNC_KEYS do
        local val = Cfg.get("AutoQuest", key)
        if val ~= nil then
            AutoQuest[key] = val
        end
    end
    -- Fő enabled kapcsoló
    AutoQuest.setEnabled(Cfg.get("AutoQuest", "enabled") == true)
end

-- Első szinkron
syncToAutoQuest()

-- Config változáskor → frissítés
Cfg.onChange(function(mod, key, val)
    if mod ~= "AutoQuest" then return end
    if key == "enabled" then
        AutoQuest.setEnabled(val == true)
    else
        AutoQuest[key] = val
    end
end)

-- ── Modul regisztráció a GUI számára ────────────────────────────
if not _G._AIO_Modules then _G._AIO_Modules = {} end

_G._AIO_Modules["AutoQuest"] = {
    getStats = function()
        return {
            active    = stats.active,
            accepted  = stats.accepted,
            ended     = stats.ended,
            lastQuest = stats.lastQuest,
            status    = AutoQuest.enabled and "Aktív" or "Kikapcsolva",
        }
    end,
}

print("[AutoQuest] OK")
