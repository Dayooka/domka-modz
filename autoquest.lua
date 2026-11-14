-- autoquest.lua
-- Híd: AutoQuest modul <-> _AIO_Config <-> GUI
-- Regisztrálja _G._AIO_Modules["AutoQuest"]-t a stat frissítőhöz

local Cfg = _G._AIO_Config
if not Cfg then
    warn("[AutoQuest] _Config nem talalhato!")
    return
end

-- ── AutoQuest modul (Executor verzió - Biztonságos fallback) ──────
local AutoQuest = {}
AutoQuest.enabled = false
AutoQuest.activeQuests = {}
AutoQuest.sideQuests = {}
AutoQuest.hiddenQuests = {}
AutoQuest.boardQuests = {}

-- Eseménykezelő függvények tárolói
local acceptedCallbacks = {}
local endedCallbacks = {}
local filterCallback = nil

function AutoQuest.setEnabled(state)
    AutoQuest.enabled = state
    print("[AutoQuest] Állapot megváltozott:", state)
end

function AutoQuest.onAccepted(callback)
    table.insert(acceptedCallbacks, callback)
end

function AutoQuest.onEnded(callback)
    table.insert(endedCallbacks, callback)
end

function AutoQuest.setFilter(callback)
    filterCallback = callback
end

function AutoQuest.getQuestName(questId)
    return tostring(questId)
end

function AutoQuest.accept(questId)
    print("[AutoQuest] Kézi elfogadás:", questId)
    return true
end

function AutoQuest.getObjective(questId)
    return nil
end

function AutoQuest.goToObjective(questId)
    print("[AutoQuest] Teleport célpontra:", questId)
end

-- ── Stat számlálók ────────────────────────────────────────────────
local stats = {
    active    = 0,
    accepted  = 0,
    ended     = 0,
    lastQuest = "-",
    status    = "Készenlét",
}

-- Elfogadás számláló
AutoQuest.onAccepted(function(questId, source)
    stats.accepted  = stats.accepted + 1
    stats.lastQuest = tostring(questId)
    stats.status    = "Elfogadva: " .. tostring(questId)
end)

-- Befejezés számláló
AutoQuest.onEnded(function(payload)
    stats.ended  = stats.ended + 1
    stats.status = "Befejezve"
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
        if AutoQuest.activeQuests then
            for _ in pairs(AutoQuest.activeQuests) do count = count + 1 end
        end
        stats.active = count
        if count > 0 then
            stats.status = string.format("Farmolás (%d aktív)", count)
        elseif stats.status == string.format("Farmolás (%d aktív)", count) then
            stats.status = "Készenlét"
        end
    end
end)

-- ── Quest szűrő: selectedQuestId alapján ─────────────────────────
-- Ha a Config-ban van selectedQuestId, csak azt a questet fogadja el.
-- Ha üres, minden quest elfogadott.
AutoQuest.setFilter(function(offer, source)
    if not Cfg.get("AutoQuest", "enabled") then return false end

    local selectedId = Cfg.get("AutoQuest", "selectedQuestId") or ""
    if selectedId == "" then
        -- Nincs szűrő → minden quest OK
        return true
    end

    -- Quest ID vagy cím alapján szűrés
    local offerId    = offer and (offer.questId or offer.id or "") or ""
    local offerTitle = string.lower(offer and offer.title or "")
    local searchLow  = string.lower(selectedId)

    return string.lower(offerId) == searchLow
        or string.find(offerTitle, searchLow, 1, true) ~= nil
end)

-- ── Config → AutoQuest szinkron ───────────────────────────────────
local SYNC_KEYS = {
    "autoDialog", "autoBoard", "autoErrand", "autoDaily",
    "autoComplete", "autoTeleport", "autoDialogue",
    "acceptDelay", "cooldown", "teleportOffset",
    "teleportHeight", "checkInterval", "dialogueDelay",
}

local function syncToModule()
    AutoQuest.setEnabled(Cfg.get("AutoQuest", "enabled") == true)
    for _, key in ipairs(SYNC_KEYS) do
        local val = Cfg.get("AutoQuest", key)
        if val ~= nil then
            AutoQuest[key] = val
        end
    end
end

-- Első szinkron betöltéskor
syncToModule()

-- Config változáskor → frissítés
Cfg.onChange(function(mod, key, val)
    if mod ~= "AutoQuest" then return end
    if key == "enabled" then
        AutoQuest.setEnabled(val == true)
        stats.status = val and "Aktív" or "Kikapcsolva"
    elseif key == "selectedQuestId" then
        -- A filter automatikusan olvassa a Config-ból
        -- Nincs külön teendő
    else
        AutoQuest[key] = val
    end
end)

-- ── _G._AIO_Modules regisztráció ─────────────────────────────────
-- GUI stat frissítő + quest lista expose a GUI quest választóhoz
_G._AIO_Modules = _G._AIO_Modules or {}

_G._AIO_Modules["AutoQuest"] = {

    -- Stat paragraph frissítéséhez
    getStats = function()
        return {
            active    = stats.active,
            accepted  = stats.accepted,
            ended     = stats.ended,
            lastQuest = stats.lastQuest,
            status    = stats.status,
        }
    end,

    -- GUI Quest Lista Frissítése gomb hívja
    -- Visszaadja az összes ismert questet {id, name, kind} formában
    getQuestList = function()
        local list = {}

        -- Side questek
        for _, q in ipairs(AutoQuest.sideQuests or {}) do
            if type(q) == "table" and q.id then
                table.insert(list, {
                    id   = q.id,
                    name = AutoQuest.getQuestName(q.id),
                    kind = "side",
                })
            end
        end

        -- Hidden questek
        for _, q in ipairs(AutoQuest.hiddenQuests or {}) do
            if type(q) == "table" and q.id then
                table.insert(list, {
                    id   = q.id,
                    name = AutoQuest.getQuestName(q.id),
                    kind = "hidden",
                })
            end
        end

        -- Board questek
        for _, q in ipairs(AutoQuest.boardQuests or {}) do
            if type(q) == "table" and q.questId then
                table.insert(list, {
                    id   = q.questId,
                    name = AutoQuest.getQuestName(q.questId),
                    kind = "board",
                })
            end
        end

        -- Aktív questek
        for id, _ in pairs(AutoQuest.activeQuests or {}) do
            -- Ne duplázza ha már benne van
            local found = false
            for _, existing in ipairs(list) do
                if existing.id == id then found = true ; break end
            end
            if not found then
                table.insert(list, {
                    id   = id,
                    name = AutoQuest.getQuestName(id),
                    kind = "active",
                })
            end
        end

        return list
    end,

    -- Kézi quest elfogadás más scriptekből
    acceptQuest = function(questId)
        return AutoQuest.accept(questId)
    end,

    -- Aktív quest célpont lekérése
    getObjective = function(questId)
        return AutoQuest.getObjective(questId)
    end,

    -- Quest célponthoz teleport
    goToObjective = function(questId)
        return AutoQuest.goToObjective(questId)
    end,
}

print("[AutoQuest] OK")
