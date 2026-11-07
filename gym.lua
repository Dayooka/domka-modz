local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local Workspace         = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

-- ── Config bridge ──────────────────────────────────────────────
local AIOCfg = _G._AIO_Config
local function CFG(key)
    if AIOCfg then
        local v = AIOCfg.get("Gym", key)
        if v ~= nil then return v end
    end
    local defaults = {
        enabled               = true,
        TIMING_OFFSET_SECONDS = 0,
        SOLVER_ITERATIONS     = 48,
        HEARTBEAT_THRESHOLD   = 0.06,
        MAX_LATE_SECONDS      = 0.02,
    }
    return defaults[key]
end

-- ── Modulok ────────────────────────────────────────────────────
local Modules   = ReplicatedStorage:WaitForChild("Modules", 15)
local GymConfig = require(Modules:WaitForChild("GymConfig"))
local Remotes   = require(Modules:WaitForChild("Remotes"))

local function getRemote(name)
    local r = Remotes[name]
    assert(typeof(r) == "Instance" and r:IsA("RemoteEvent"), "Gym: Missing RemoteEvent: " .. name)
    return r
end

local GymRunStarted = getRemote("GymRunStarted")
local GymRepPrompt  = getRemote("GymRepPrompt")
local GymHoldStart  = getRemote("GymHoldStart")
local GymRep        = getRemote("GymRep")
local GymRepResult  = getRemote("GymRepResult")
local GymEnded      = getRemote("GymEnded")

-- ── Állapot ────────────────────────────────────────────────────
local session    = nil
local statusText = "Várakozás..."

local S = {
    status    = "Idle",
    station   = "-",
    sent      = 0,
    confirmed = 0,
    missed    = 0,
    perfect   = 0,
    good      = 0,
    sloppy    = 0,
}

local function isFiniteNumber(v)
    return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

-- ── Solver ─────────────────────────────────────────────────────
local function solveTarget(shape)
    if type(shape) ~= "table" then return nil end
    if not isFiniteNumber(shape.duration) or shape.duration <= 0 then return nil end
    local ease = shape.ease
    if not isFiniteNumber(ease) or ease <= 0 then ease = 1 end
    local low, high = 0, 1
    local iters = CFG("SOLVER_ITERATIONS")
    for _ = 1, iters do
        local mid    = (low + high) * 0.5
        local target = GymConfig.targetAt(shape, mid)
        if not isFiniteNumber(target) then return nil end
        if mid < target then low = mid else high = mid end
    end
    local progress = (low + high) * 0.5
    local elapsed  = shape.duration * (progress ^ (1 / ease))
    if not isFiniteNumber(elapsed) or elapsed < 0 then return nil end
    return progress, elapsed
end

-- ── Validáció ──────────────────────────────────────────────────
local function isCurrentRep(cs, rep)
    return CFG("enabled")
        and session == cs
        and cs.activeRep == rep
        and not rep.cancelled
        and not rep.sent
end

-- ── Várakozás ──────────────────────────────────────────────────
local function waitUntil(deadline, cs, rep)
    while isCurrentRep(cs, rep) do
        local remaining = deadline - Workspace:GetServerTimeNow()
        if remaining <= 0 then return true end
        local hbThresh = CFG("HEARTBEAT_THRESHOLD")
        if remaining > hbThresh then
            task.wait(math.max(0.01, remaining - hbThresh * 0.5))
        else
            RunService.Heartbeat:Wait()
        end
    end
    return false
end

-- ── Rep küldés ─────────────────────────────────────────────────
local function sendRep(cs, rep)
    if session ~= cs or rep.sent or rep.cancelled then return false end
    local now      = Workspace:GetServerTimeNow()
    local curProg  = GymConfig.valueAt(now - rep.startTime, rep.shape.duration, rep.shape.ease)
    local curTgt   = GymConfig.targetAt(rep.shape, curProg)
    local quality  = GymConfig.qualityFor(rep.shape, curProg, curTgt)

    rep.sent = true; rep.sentTime = now; rep.predictedQuality = quality
    cs.activeRep = nil; cs.submitted[rep.index] = rep
    cs.stats.sent = cs.stats.sent + 1
    if cs.stats.predicted[quality] then
        cs.stats.predicted[quality] = cs.stats.predicted[quality] + 1
    end

    local ok, err = pcall(function() GymRep:FireServer(rep.index, now) end)
    if not ok then
        cs.submitted[rep.index] = nil
        cs.stats.sent = math.max(0, cs.stats.sent - 1)
        warn("[Gym] GymRep failed:", err)
        return false
    end

    S.sent   = cs.stats.sent
    S.status = "Rep OK: " .. quality
    if quality == "Perfect" then S.perfect = S.perfect + 1
    elseif quality == "Good" then S.good    = S.good + 1
    else                          S.sloppy  = S.sloppy + 1 end
    print("[Gym] Rep küldve –", quality)
    return true
end

-- ── Prompt feldolgozás ─────────────────────────────────────────
local function processPrompt(prompt)
    local cs = session
    if not cs or type(prompt) ~= "table" then return end
    if not CFG("enabled") then return end
    if prompt.index == nil then return end
    if prompt.coached == true then return end

    local shape = GymConfig.shapeFrom(prompt)
    if not shape then warn("[Gym] Érvénytelen rep shape"); return end

    local station = cs.station
    if station.mode ~= "Hold" and station.mode ~= "Sweep" then return end

    local progress, elapsed = solveTarget(shape)
    if not progress or not elapsed then return end

    local startTime
    if station.mode == "Hold" then
        startTime = Workspace:GetServerTimeNow()
    else
        if not isFiniteNumber(prompt.startTime) then return end
        startTime = prompt.startTime
    end

    local deadline = startTime + elapsed + CFG("TIMING_OFFSET_SECONDS")
    local now      = Workspace:GetServerTimeNow()
    if deadline < now - CFG("MAX_LATE_SECONDS") then return end

    if cs.activeRep then cs.activeRep.cancelled = true; cs.activeRep = nil end

    local rep = {
        index       = prompt.index,
        shape       = shape,
        progress    = progress,
        elapsed     = elapsed,
        startTime   = startTime,
        deadline    = deadline,
        holdStarted = false,
        sent        = false,
        cancelled   = false,
    }
    cs.activeRep = rep

    if station.mode == "Hold" then
        rep.holdStarted = true
        local ok, err = pcall(function() GymHoldStart:FireServer(rep.index, startTime) end)
        if not ok then
            rep.cancelled = true; cs.activeRep = nil
            warn("[Gym] GymHoldStart failed:", err); return
        end
    end

    S.status = string.format("%s → %.3f", station.displayName or station.id or "Gym", progress)

    task.spawn(function()
        if not waitUntil(deadline, cs, rep) then return end
        if not isCurrentRep(cs, rep) then return end
        sendRep(cs, rep)
    end)
end

-- ── Remote listenrek ───────────────────────────────────────────
GymRunStarted.OnClientEvent:Connect(function(data)
    if type(data) ~= "table" then return end
    local station = GymConfig.get(data.stationId)
    if not station then return end
    session = {
        stationId  = data.stationId,
        station    = station,
        activeRep  = nil,
        submitted  = {},
        stats      = { sent=0, predicted={Perfect=0,Good=0,Sloppy=0},
                       confirmed=0, serverQuality={Perfect=0,Good=0,Sloppy=0},
                       serverUnknown=0, serverMissed=0 },
    }
    S.station = station.displayName or station.id or "Gym"
    S.status  = "Session indult"
    print("[Gym] Session:", S.station)
end)

GymRepPrompt.OnClientEvent:Connect(processPrompt)

GymRepResult.OnClientEvent:Connect(function(result)
    if type(result) ~= "table" or not session then return end
    local rep = session.submitted[result.index]
    if not rep then return end
    session.submitted[result.index] = nil
    session.stats.confirmed = session.stats.confirmed + 1
    S.confirmed = session.stats.confirmed
    if result.missed == true then
        session.stats.serverMissed = session.stats.serverMissed + 1
        S.missed  = session.stats.serverMissed
        S.status  = "MISS!"
    elseif type(result.quality) == "string" then
        local q = result.quality
        session.stats.serverQuality[q] = (session.stats.serverQuality[q] or 0) + 1
        S.status = "Server: " .. q
    else
        session.stats.serverUnknown = session.stats.serverUnknown + 1
    end
end)

GymEnded.OnClientEvent:Connect(function()
    if session and session.activeRep then session.activeRep.cancelled = true end
    session   = nil
    S.station = "-"
    S.status  = "Session vége"
    print("[Gym] Session vége")
end)

LocalPlayer.CharacterRemoving:Connect(function()
    if session and session.activeRep then session.activeRep.cancelled = true end
    session = nil
end)

-- ── Publikus API ───────────────────────────────────────────────
_G._AIO_Modules = _G._AIO_Modules or {}
_G._AIO_Modules["Gym"] = {
    getStats = function()
        return {
            enabled   = CFG("enabled"),
            station   = S.station,
            status    = S.status,
            sent      = S.sent,
            confirmed = S.confirmed,
            missed    = S.missed,
            perfect   = S.perfect,
            good      = S.good,
            sloppy    = S.sloppy,
        }
    end
}

print("[Gym] OK")
