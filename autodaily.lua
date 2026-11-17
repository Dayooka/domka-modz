-- autodaily.lua – FIX: vararg '...' hiba javítva
-- Hiba oka: loadstring()-en belül '...' nem használható közvetlen kontextusban.
-- Megoldás: a '...' tartalmát elmentjük egy lokális táblába a script elején.

local _args = { ... }   -- ← ez a sor javítja a hibát

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cfg    = _G._AIO_Config
local Shared = _G._AIO_Shared

if not Cfg or not Shared then
    warn("[AutoDaily] _Config vagy _Shared nem talalhato!")
    return
end

local Remotes = Shared.getRemotes()

local stats = {
    status   = "Készenlét",
    claimed  = 0,
    spins    = 0,
    nextIn   = 0,
}

local running = false
local lastRun = 0

local function claimDailyReward()
    local ok, result = pcall(function()
        return Remotes.ClaimDailyReward:InvokeServer()
    end)
    return ok and result ~= nil
end

local function claimDailyGoal()
    local ok, result = pcall(function()
        return Remotes.ClaimDailyGoal:InvokeServer()
    end)
    return ok and tonumber(result) ~= nil and tonumber(result) > 0
end

local function spinDailyWheel()
    local ok = pcall(function()
        Remotes.SpinDailyWheel:FireServer()
    end)
    return ok
end

local function redeemAFK()
    local ok = pcall(function()
        Remotes.RedeemAFK:FireServer()
    end)
    return ok
end

local function runDaily()
    if running then return end
    running = true
    stats.status = "Futás..."

    -- Napi jutalom
    local callDelay = Cfg.get("Daily", "CALL_DELAY") or 0.70
    task.wait(callDelay)

    local ok = claimDailyReward()
    if ok then
        stats.claimed += 1
        stats.status   = "Napi jutalom begyűjtve!"
    end

    task.wait(callDelay)

    -- Daily Goal
    if Cfg.get("Daily", "CLAIM_EXTRAS") then
        local goalOk = claimDailyGoal()
        if goalOk then stats.status = "Daily Goal begyűjtve!" end
        task.wait(callDelay)

        -- Spin
        local maxSpins = Cfg.get("Daily", "SPIN_MAX") or 7
        for _ = 1, maxSpins do
            if not Cfg.get("Daily", "enabled") then break end
            local spinOk = spinDailyWheel()
            if spinOk then
                stats.spins += 1
                task.wait(callDelay)
            else
                break
            end
        end

        -- AFK jutalom
        redeemAFK()
        task.wait(callDelay)
    end

    stats.status = "Kész – következő: " .. (Cfg.get("Daily","LOOP_HOURS") or 24) .. "h"
    lastRun  = os.clock()
    running  = false
end

-- Fő loop
task.spawn(function()
    while true do
        task.wait(5)
        if not Cfg.get("Daily","enabled") then
            stats.status = "Kikapcsolva"
            task.wait(5)
        else
            local loopHours = Cfg.get("Daily","LOOP_HOURS") or 24
            local elapsed   = os.clock() - lastRun
            local remaining = math.max(0, loopHours * 3600 - elapsed)
            stats.nextIn    = math.floor(remaining)

            if remaining <= 0 then
                task.spawn(runDaily)
            else
                stats.status = string.format("Következő: %dh %dm",
                    math.floor(remaining / 3600),
                    math.floor((remaining % 3600) / 60))
            end
            task.wait(30)
        end
    end
end)

-- Config onChange
Cfg.onChange(function(mod, key, val)
    if mod ~= "Daily" then return end
    if key == "enabled" and val == true and not running then
        lastRun = 0  -- azonnal fusson ha bekapcsoljuk
    end
end)

_G._AIO_Modules = _G._AIO_Modules or {}
_G._AIO_Modules["Daily"] = {
    getStats = function()
        return {
            status  = stats.status,
            claimed = stats.claimed,
            spins   = stats.spins,
            nextIn  = stats.nextIn,
        }
    end,
}

print("[AutoDaily] OK")
