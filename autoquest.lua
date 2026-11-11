local Cfg    = _G._AIO_Config
local Shared = _G._AIO_Shared

if not Cfg then
    warn("[AutoQuest] _Config nem talalhato!")
    return
end

local RS      = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- ── 1. AutoQuest modul betöltése (RS → _G → inline) ────────────
local AutoQuest

do
    local ok, res = pcall(function()
        return require(RS.Modules.AutoQuest)
    end)
    if ok and type(res) == "table" then
        AutoQuest = res
        print("[AutoQuest] Modul: ReplicatedStorage.Modules.AutoQuest")
    end
end

if not AutoQuest and type(_G.AutoQuest) == "table" then
    AutoQuest = _G.AutoQuest
    print("[AutoQuest] Modul: _G.AutoQuest (extern)")
end

-- ── 2. Inline fallback ────────────────────────────────────────
if not AutoQuest then
    print("[AutoQuest] RS modul nem letezik -> inline fallback")

    local AQ = {}
    local defaults = {
        enabled = false,
        autoDialog = true, autoBoard = true, autoErrand = true,
        autoDaily = true, autoComplete = true, autoTeleport = true,
        autoDialogue = true,
        acceptDelay = 0.5, cooldown = 3,
        teleportOffset = 5, teleportHeight = 3,
        checkInterval = 1, dialogueDelay = 0.3,
    }
    for k, v in pairs(defaults) do AQ[k] = v end

    AQ.activeQuests  = {}
    local acceptedCbs, endedCbs = {}, {}
    local lastAccept, lastDialogueAt = 0, 0

    function AQ.onAccepted(fn)
        if type(fn) == "function" then table.insert(acceptedCbs, fn) end
    end
    function AQ.onEnded(fn)
        if type(fn) == "function" then table.insert(endedCbs, fn) end
    end
    function AQ.setEnabled(v) AQ.enabled = v == true end

    local Remotes = RS:WaitForChild("Remotes", 30)
    local function findRemote(n) return Remotes and Remotes:FindFirstChild(n, true) end

    -- vararg-safe: pcall(method, self, ...) form, no anonymous function
    local function invoke(r, ...)
        if not r then return nil end
        if r:IsA("RemoteEvent") then
            return (pcall(r.FireServer, r, ...))
        elseif r:IsA("RemoteFunction") then
            local ok, res = pcall(r.InvokeServer, r, ...)
            if ok then return res end
        end
        return nil
    end

    -- vararg-safe: pcall(cb, ...) with cb user function (not anonymous)
    local function fire(list, ...)
        for _, cb in ipairs(list) do pcall(cb, ...) end
    end

    local function qid(p)
        if type(p) == "table" then
            return p.questId or p.id or p.quest or p.lesson or p.key
        end
        return p and tostring(p)
    end

    do
        local r = findRemote("QuestQueued")
        if r and r:IsA("RemoteEvent") then
            r.OnClientEvent:Connect(function(payload)
                if not AQ.enabled then return end
                local id = qid(payload); if not id then return end
                local now = os.clock()
                if now - lastAccept < AQ.cooldown then return end
                lastAccept = now
                AQ.activeQuests[id] = {
                    id = id, startedAt = now, lastProgressAt = now,
                    progress = 0, state = "queued", raw = payload,
                }
                if AQ.autoComplete then
                    task.delay(AQ.acceptDelay, function()
                        if not AQ.activeQuests[id] then return end
                        local a = findRemote("RequestAcceptQuest")
                        if a then
                            invoke(a, id)
                            AQ.activeQuests[id].state = "active"
                            fire(acceptedCbs, id, "queued")
                        end
                    end)
                end
            end)
        end
    end

    do
        local r = findRemote("QuestProgress")
        if r and r:IsA("RemoteEvent") then
            r.OnClientEvent:Connect(function(q, prog)
                local id = qid(q); if not id then return end
                local e = AQ.activeQuests[id]
                if e then
                    e.progress = tonumber(prog) or (e.progress + 1)
                    e.lastProgressAt = os.clock()
                end
            end)
        end
    end

    do
        local r = findRemote("QuestEnded")
        if r and r:IsA("RemoteEvent") then
            r.OnClientEvent:Connect(function(p)
                local id = qid(p); if id then AQ.activeQuests[id] = nil end
                fire(endedCbs, p)
            end)
        end
    end

    do
        local r = findRemote("ErrandProgress")
        if r and r:IsA("RemoteEvent") then
            r.OnClientEvent:Connect(function(eid)
                if not AQ.enabled or not AQ.autoErrand then return end
                local id = qid(eid)
                if id and AQ.activeQuests[id] then
                    local ab = findRemote("RequestAbandonErrand")
                    if ab then invoke(ab, id) end
                    AQ.activeQuests[id] = nil
                end
            end)
        end
    end

    do
        local r = findRemote("ErrandEnded")
        if r and r:IsA("RemoteEvent") then
            r.OnClientEvent:Connect(function(p)
                local id = qid(p); if id then AQ.activeQuests[id] = nil end
            end)
        end
    end

    local function countActive()
        local n = 0; for _ in pairs(AQ.activeQuests) do n += 1 end; return n
    end

    task.spawn(function()
        while true do
            task.wait(AQ.checkInterval)
            if not AQ.enabled then continue end
            if AQ.autoBoard and countActive() == 0 then
                local b = findRemote("OpenQuestBoard"); if b then invoke(b) end
            end
            if AQ.autoDialogue then
                local now = os.clock()
                if now - lastDialogueAt >= AQ.dialogueDelay then
                    lastDialogueAt = now
                    local da = findRemote("DialogueAction")
                    if da then invoke(da, "advance") end
                end
            end
            if AQ.autoDaily then
                local d = findRemote("ClaimDailyReward"); if d then invoke(d) end
            end
            local now = os.clock()
            for id, q in pairs(AQ.activeQuests) do
                if q.state == "active"
                    and (now - (q.lastProgressAt or q.startedAt)) > 120 then
                    local a = findRemote("RequestAbandonQuest")
                    if a then invoke(a, id) end
                    AQ.activeQuests[id] = nil
                end
            end
        end
    end)

    AutoQuest    = AQ
    _G.AutoQuest = AQ
end

-- ── 3. Stat számlálók ─────────────────────────────────────────
local stats = { active = 0, accepted = 0, ended = 0, lastQuest = "-" }

AutoQuest.onAccepted(function(questId)
    stats.accepted  = stats.accepted + 1
    stats.lastQuest = tostring(questId)
end)

AutoQuest.onEnded(function(payload)
    stats.ended = stats.ended + 1
    local id = type(payload) == "table"
        and (payload.questId or payload.id or payload.lesson)
        or payload
    if id then stats.lastQuest = tostring(id) end
end)

task.spawn(function()
    while true do
        task.wait(1)
        local n = 0
        for _ in pairs(AutoQuest.activeQuests or {}) do n += 1 end
        stats.active = n
    end
end)

-- ── 4. Config → AutoQuest szinkron ────────────────────────────
local SYNC_KEYS = {
    "autoDialog", "autoBoard", "autoErrand", "autoDaily",
    "autoComplete", "autoTeleport", "autoDialogue",
    "acceptDelay", "cooldown", "teleportOffset",
    "teleportHeight", "checkInterval", "dialogueDelay",
}

local function syncToAutoQuest()
    for _, key in ipairs(SYNC_KEYS) do
        local val = Cfg.get("AutoQuest", key)
        if val ~= nil then AutoQuest[key] = val end
    end
    AutoQuest.setEnabled(Cfg.get("AutoQuest", "enabled") == true)
end

syncToAutoQuest()

Cfg.onChange(function(mod, key, val)
    if mod ~= "AutoQuest" then return end
    if key == "enabled" then
        AutoQuest.setEnabled(val == true)
    else
        AutoQuest[key] = val
    end
end)

-- ── 5. GUI regisztráció ───────────────────────────────────────
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

print("[AutoQuest] OK (fallback: " .. tostring(_G.AutoQuest ~= nil) .. ")")
