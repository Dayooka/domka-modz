--[[
    autodaily.lua - Auto Daily Farm
    Config:  _G._AIO_Config.get("Daily", key)
    Statusz: _G._AIO_Modules["Daily"].getStats()

    VALÓDI REMOTE-OK (forrás 16. szekció alapján):
    RemoteFunction-ok: GetDailyRewards, ClaimDailyReward,
        SpinDailyWheel, GetBattlePass, ClaimBattlePass
    RemoteEvent-ek: OpenDailyRewards, ClaimDailyGoal,
        OpenAFKRewards, RedeemAFK, PlayerActive, RequestIdleRefresh

    NEM LÉTEZŐ remote-ok (törölve): ClaimGroupReward,
        ClaimFreeBoost, GetMail, ClaimMail
]]

local Cfg    = _G._AIO_Config
local Shared = _G._AIO_Shared

local S = { status = "Idle", nextIn = 0, lastRun = 0, log = {} }

local function addLog(msg)
    table.insert(S.log, 1, msg)
    if #S.log > 12 then table.remove(S.log) end
    S.status = msg
    print("[AutoDaily]", msg)
end

-- Remote hívó: RemoteFunction → InvokeServer, RemoteEvent → FireServer
local function call(name, ...)
    local retries = Cfg.get("Daily","MAX_RETRIES") or 3
    for _ = 1, retries do
        local r = Shared.invoke(name, ...)
        if r ~= nil then return r end
        task.wait(1.0)
    end
    return nil
end

-- RemoteEvent küldés (nem vár visszajelzést)
local function fire(name, ...)
    local RemFolder = game:GetService("ReplicatedStorage"):WaitForChild("Remotes", 10)
    local r = RemFolder and RemFolder:FindFirstChild(name)
    if r and r:IsA("RemoteEvent") then
        pcall(function() r:FireServer(...) end)
    end
end

local function runDaily()
    local cd = Cfg.get("Daily","CALL_DELAY") or 0.70

    -- 1. Panel megnyitás (RemoteEvent)
    addLog("Panel megnyitas...")
    fire("OpenDailyRewards")
    task.wait(cd)

    -- 2. Napi jutalmak lekérése (RemoteFunction)
    addLog("Lekeres...")
    call("GetDailyRewards")
    task.wait(cd)

    -- 3. Napi jutalom claim (RemoteFunction)
    addLog("Napi jutalom...")
    local r = call("ClaimDailyReward")
    addLog(r and "ClaimDailyReward OK" or "Mar felveve / nincs")
    task.wait(cd)

    -- 4. Napi cél (RemoteEvent)
    addLog("Napi cel...")
    fire("ClaimDailyGoal")
    task.wait(cd)

    -- 5. Spin kerék (RemoteFunction – visszaad eredményt)
    addLog("Spin kerek...")
    local spinMax = Cfg.get("Daily","SPIN_MAX") or 7
    for i = 1, spinMax do
        local sr = call("SpinDailyWheel")
        if sr then
            addLog("Spin #" .. i .. " OK")
        else
            addLog("Spin kesz (" .. (i-1) .. "/" .. spinMax .. ")")
            break
        end
        task.wait(cd)
    end

    -- 6. AFK jutalmak
    addLog("AFK jutalmak...")
    fire("OpenAFKRewards")
    task.wait(cd)
    fire("PlayerActive")
    task.wait(cd)
    call("RedeemAFK")
    task.wait(cd)
    call("RequestIdleRefresh")
    task.wait(cd)

    -- 7. Battle Pass (ha CLAIM_EXTRAS engedélyezett)
    if Cfg.get("Daily","CLAIM_EXTRAS") then
        addLog("Battle Pass...")
        call("GetBattlePass")
        task.wait(cd)
        local bp = call("ClaimBattlePass")
        addLog(bp and "BattlePass OK" or "BattlePass: nincs / mar felveve")
        task.wait(cd)
    end

    addLog("Daily kesz!")
    S.lastRun = tick()
end

task.spawn(function()
    task.wait(2)
    while true do
        if not Cfg.get("Daily","enabled") then
            S.status = "Kikapcsolva"
            task.wait(1)
        else
            local ok, err = pcall(runDaily)
            if not ok then addLog("Hiba: " .. tostring(err)) end
            if not Cfg.get("Daily","AUTO_LOOP") then break end
            local wait = (Cfg.get("Daily","LOOP_HOURS") or 24) * 3600
            S.nextIn = tick() + wait
            task.wait(wait)
        end
    end
end)

_G._AIO_Modules = _G._AIO_Modules or {}
_G._AIO_Modules["Daily"] = {
    getStats = function()
        return {
            enabled = Cfg.get("Daily","enabled"),
            status  = S.status,
            log     = S.log,
            nextIn  = math.max(0, math.floor(S.nextIn - tick())),
            lastRun = S.lastRun,
        }
    end
}

print("[AutoDaily] OK")
