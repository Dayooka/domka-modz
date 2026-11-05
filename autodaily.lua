-- ══════════════════════════════════════════════════════════════════════
local CFG = {
    CALL_DELAY   = 0.70,
    MAX_RETRIES  = 3,
    RETRY_DELAY  = 1.2,
    SPIN_MAX     = 7,
    AUTO_LOOP    = true,
    LOOP_HOURS   = 24,
    CLAIM_EXTRAS = true,
    DEBUG        = false,
}

local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")
local LP      = Players.LocalPlayer

local RemFolder = RS:WaitForChild("Remotes",10)
local function getR(name) return RemFolder and RemFolder:FindFirstChild(name) end

local function call(name,...)
    local r=getR(name); if not r then return nil end
    for i=1,CFG.MAX_RETRIES do
        local ok,res=pcall(function(...)
            return r:IsA("RemoteFunction") and r:InvokeServer(...)
                or (r:FireServer(...) or true)
        end,...)
        if ok then return res end
        task.wait(CFG.RETRY_DELAY)
    end
    return nil
end

local function runDaily()
    if _G.KillAuraCFG and _G.KillAuraCFG.AUTO_DAILY_ENABLED == false then return end

    task.wait(CFG.CALL_DELAY)
    call("OpenDailyRewards")
    task.wait(CFG.CALL_DELAY)
    call("GetDailyRewards")
    task.wait(CFG.CALL_DELAY)
    call("ClaimDailyReward")
    task.wait(CFG.CALL_DELAY)
    call("ClaimDailyGoal")
    task.wait(CFG.CALL_DELAY)

    for i=1,CFG.SPIN_MAX do
        local sr=call("SpinDailyWheel")
        if not sr then break end
        task.wait(CFG.CALL_DELAY)
    end

    call("OpenAFKRewards")
    task.wait(CFG.CALL_DELAY)
    call("PlayerActive")
    task.wait(CFG.CALL_DELAY)
    call("RedeemAFK")
    task.wait(CFG.CALL_DELAY)
    call("RequestIdleRefresh")
    task.wait(CFG.CALL_DELAY)

    if CFG.CLAIM_EXTRAS then
        call("GetBattlePass")
        task.wait(CFG.CALL_DELAY)
        call("ClaimBattlePass")
        task.wait(CFG.CALL_DELAY)

        local mail=call("GetMail")
        if type(mail)=="table" then
            for _,m in ipairs(mail) do
                call("ClaimMail", m.id or m)
                task.wait(0.3)
            end
        end
        task.wait(CFG.CALL_DELAY)
        call("ClaimGroupReward")
        task.wait(CFG.CALL_DELAY)
        call("ClaimFreeBoost")
        task.wait(CFG.CALL_DELAY)
    end
end

task.spawn(function()
    task.wait(2)
    while true do
        if _G.KillAuraCFG and _G.KillAuraCFG.AUTO_DAILY_ENABLED == false then
            task.wait(3)
            continue
        end

        pcall(runDaily)
        if not CFG.AUTO_LOOP then break end
        task.wait(CFG.LOOP_HOURS * 3600)
    end
end)

print("[AutoDaily] ✓ Betöltve és összekötve a Master GUI-val")
