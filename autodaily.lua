--[[
╔══════════════════════════════════════════════════════════════════════╗
║          AUTO DAILY FARM  (forráskód alapján)                       ║
╠══════════════════════════════════════════════════════════════════════╣
║  Pontos remote nevek (16. szekció alapján):                         ║
║    GetDailyRewards (RF), ClaimDailyReward (RF),                     ║
║    SpinDailyWheel (RF), OpenDailyRewards (RE),                      ║
║    ClaimDailyGoal (RF), OpenAFKRewards (RE), RedeemAFK (RF),        ║
║    PlayerActive (RE), RequestIdleRefresh (RF)                       ║
║  Bónusz: ClaimBattlePass (RF), GetMail + ClaimMail (RF),            ║
║    ClaimGroupReward (RF), ClaimFreeBoost (RF)                       ║
╚══════════════════════════════════════════════════════════════════════╝
]]

local CFG = {
    CALL_DELAY   = 0.70,
    MAX_RETRIES  = 3,
    RETRY_DELAY  = 1.2,
    SPIN_MAX     = 7,
    AUTO_LOOP    = true,
    LOOP_HOURS   = 24,
    -- Extra jutalmak (battle pass, mail, group, free boost)
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

local function dbg(...) if CFG.DEBUG then print("[Daily]",...) end end

-- GUI
local sg=Instance.new("ScreenGui"); sg.Name="Daily_HUD"; sg.ResetOnSpawn=false
sg.IgnoreGuiInset=true; sg.Parent=LP:WaitForChild("PlayerGui")
local fr=Instance.new("Frame",sg)
fr.Size=UDim2.new(0,195,0,120); fr.Position=UDim2.new(0,12,0,120)
fr.BackgroundColor3=Color3.fromRGB(6,8,14); fr.BackgroundTransparency=0.15; fr.BorderSizePixel=0
Instance.new("UICorner",fr).CornerRadius=UDim.new(0,10)
local stk=Instance.new("UIStroke",fr); stk.Color=Color3.fromRGB(80,160,255); stk.Thickness=1.4
local titleL=Instance.new("TextLabel",fr)
titleL.Size=UDim2.new(1,0,0,22); titleL.Position=UDim2.new(0,0,0,4)
titleL.BackgroundTransparency=1; titleL.Text="📅 AUTO DAILY FARM"
titleL.TextColor3=Color3.fromRGB(100,180,255); titleL.Font=Enum.Font.GothamBold; titleL.TextSize=12

local log=Instance.new("ScrollingFrame",fr)
log.Size=UDim2.new(1,-8,0,88); log.Position=UDim2.new(0,4,0,28)
log.BackgroundTransparency=1; log.BorderSizePixel=0
log.ScrollBarThickness=2; log.ScrollBarImageColor3=Color3.fromRGB(80,160,255)
log.CanvasSize=UDim2.new(0,0,0,0)
local ll=Instance.new("UIListLayout",log); ll.SortOrder=Enum.SortOrder.LayoutOrder; ll.Padding=UDim.new(0,2)

local li=0
local function addLog(msg,color)
    li+=1
    local l=Instance.new("TextLabel",log)
    l.Size=UDim2.new(1,-4,0,15); l.BackgroundTransparency=1
    l.Font=Enum.Font.Gotham; l.TextSize=10; l.TextXAlignment=Enum.TextXAlignment.Left
    l.TextColor3=color or Color3.fromRGB(200,200,200)
    l.Text=msg; l.LayoutOrder=li
    log.CanvasSize=UDim2.new(0,0,0,li*17); log.CanvasPosition=Vector2.new(0,li*17)
    print("[Daily]",msg)
end

local function runDaily()
    addLog("🔄 Daily farm indul...", Color3.fromRGB(100,200,255))
    task.wait(CFG.CALL_DELAY)

    -- 1. Panel megnyitás (RemoteEvent)
    addLog("📂 Panel megnyitás...")
    call("OpenDailyRewards")
    task.wait(CFG.CALL_DELAY)

    -- 2. Napi jutalmak lekérése
    addLog("📋 Lekérés...")
    call("GetDailyRewards")
    task.wait(CFG.CALL_DELAY)

    -- 3. Napi jutalom claim
    addLog("🎁 Napi jutalom...", Color3.fromRGB(255,220,60))
    local r=call("ClaimDailyReward")
    addLog(r and "  ✅ ClaimDailyReward OK!" or "  ⚠ Már felvéve/nincs",
        r and Color3.fromRGB(100,255,120) or Color3.fromRGB(180,180,100))
    task.wait(CFG.CALL_DELAY)

    -- 4. Napi cél
    addLog("🎯 Napi cél...")
    call("ClaimDailyGoal")
    task.wait(CFG.CALL_DELAY)

    -- 5. Spin kerék (max SPIN_MAX próbálkozás)
    addLog("🎡 Spin kerék...", Color3.fromRGB(255,180,60))
    for i=1,CFG.SPIN_MAX do
        local sr=call("SpinDailyWheel")
        if sr then
            addLog("  Spin #"..i.." ✅", Color3.fromRGB(120,255,160))
        else
            addLog("  Spin kész ("..i-1.."/7)", Color3.fromRGB(160,160,160))
            break
        end
        task.wait(CFG.CALL_DELAY)
    end

    -- 6. AFK jutalmak
    addLog("💤 AFK jutalmak...")
    call("OpenAFKRewards")
    task.wait(CFG.CALL_DELAY)
    call("PlayerActive")
    task.wait(CFG.CALL_DELAY)
    call("RedeemAFK")
    task.wait(CFG.CALL_DELAY)
    call("RequestIdleRefresh")
    task.wait(CFG.CALL_DELAY)

    if CFG.CLAIM_EXTRAS then
        -- 7. Battle Pass
        addLog("⚔ Battle Pass...")
        call("GetBattlePass")
        task.wait(CFG.CALL_DELAY)
        call("ClaimBattlePass")
        task.wait(CFG.CALL_DELAY)

        -- 8. Mail jutalmak (GetMail + ClaimMail)
        addLog("📬 Mail...")
        local mail=call("GetMail")
        if type(mail)=="table" then
            for _,m in ipairs(mail) do
                call("ClaimMail", m.id or m)
                task.wait(0.3)
            end
        end
        task.wait(CFG.CALL_DELAY)

        -- 9. Csoport jutalom
        addLog("👥 Csoport jutalom...")
        call("ClaimGroupReward")
        task.wait(CFG.CALL_DELAY)

        -- 10. Free Boost
        addLog("⚡ Free Boost...")
        call("ClaimFreeBoost")
        task.wait(CFG.CALL_DELAY)
    end

    addLog("🏁 Daily kész!", Color3.fromRGB(100,255,160))
end

task.spawn(function()
    task.wait(2)
    while true do
        local ok,err=pcall(runDaily)
        if not ok then addLog("❌ "..tostring(err), Color3.fromRGB(255,80,80)) end
        if not CFG.AUTO_LOOP then break end
        addLog("⏰ "..CFG.LOOP_HOURS.."h múlva újra", Color3.fromRGB(120,120,120))
        task.wait(CFG.LOOP_HOURS * 3600)
    end
end)

print("[AutoDaily] ✓ betöltve | Extras:", CFG.CLAIM_EXTRAS)
