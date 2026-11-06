local Cfg    = require(script.Parent._Config)
local Shared = require(script.Parent._Shared)

local S = { status = "Idle", nextIn = 0, lastRun = 0, log = {} }

local function addLog(msg)
    table.insert(S.log, 1, msg)
    if #S.log > 12 then table.remove(S.log) end
    S.status = msg
    print("[AutoDaily]", msg)
end

local function call(name, ...)
    local retries = Cfg.get("Daily","MAX_RETRIES") or 3
    for _ = 1, retries do
        local r = Shared.invoke(name, ...)
        if r ~= nil then return r end
        task.wait(1.2)
    end
    return nil
end

local function runDaily()
    local cd = Cfg.get("Daily","CALL_DELAY") or 0.70
    addLog("Panel megnyitás...")
    Shared.invoke("OpenDailyRewards"); task.wait(cd)

    addLog("Lekérés..."); call("GetDailyRewards"); task.wait(cd)

    addLog("Napi jutalom...")
    local r = call("ClaimDailyReward")
    addLog(r and "✅ ClaimDailyReward" or "⚠ Már felvéve"); task.wait(cd)

    addLog("Napi cél..."); call("ClaimDailyGoal"); task.wait(cd)

    addLog("Spin kerék...")
    local spinMax = Cfg.get("Daily","SPIN_MAX") or 7
    for i = 1, spinMax do
        local sr = call("SpinDailyWheel")
        if sr then addLog("Spin #"..i.." ✅")
        else addLog("Spin kész"); break end
        task.wait(cd)
    end

    addLog("AFK jutalmak...")
    Shared.invoke("OpenAFKRewards"); task.wait(cd)
    Shared.invoke("PlayerActive");   task.wait(cd)
    call("RedeemAFK");               task.wait(cd)
    call("RequestIdleRefresh");      task.wait(cd)

    if Cfg.get("Daily","CLAIM_EXTRAS") then
        addLog("Battle Pass..."); call("GetBattlePass"); task.wait(cd); call("ClaimBattlePass"); task.wait(cd)
        addLog("Mail...")
        local mail = call("GetMail")
        if type(mail) == "table" then
            for _, m in ipairs(mail) do call("ClaimMail", m.id or m); task.wait(0.3) end
        end
        task.wait(cd)
        addLog("Group Reward..."); call("ClaimGroupReward"); task.wait(cd)
        addLog("Free Boost...");   call("ClaimFreeBoost");   task.wait(cd)
    end

    addLog("✅ Daily kész!")
    S.lastRun = tick()
end

task.spawn(function()
    task.wait(2)
    while true do
        if not Cfg.get("Daily","enabled") then
            S.status = "Kikapcsolva"; task.wait(1); continue
        end
        local ok, err = pcall(runDaily)
        if not ok then addLog("❌ " .. tostring(err)) end
        if not Cfg.get("Daily","AUTO_LOOP") then break end
        local wait = (Cfg.get("Daily","LOOP_HOURS") or 24) * 3600
        S.nextIn = tick() + wait
        task.wait(wait)
    end
end)

local Module = {}
function Module.getStats()
    return {
        enabled = Cfg.get("Daily","enabled"),
        status  = S.status,
        log     = S.log,
        nextIn  = math.max(0, math.floor(S.nextIn - tick())),
        lastRun = S.lastRun,
    }
end
print("[AutoDaily] ✓")
return Module
