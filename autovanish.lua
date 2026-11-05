--[[
╔══════════════════════════════════════════════════════════════════════╗
║          AUTO VANISH  –  PRO  (forráskód alapján)                   ║
╠══════════════════════════════════════════════════════════════════════╣
║  Pontos értékek:                                                     ║
║    VANISH_COST_FRACTION = 0.14  (Ki 14%-a / vanish)                 ║
║    vanishCost(chainCount) – lánconként nő                           ║
║    vanishCounterWindow(chainCount) – counter ablak lánconként        ║
║    STEP_PERFECT_WINDOW = 0.3s                                        ║
║    STEP_IFRAME = 0.28s                                               ║
║    CLASH_GRADES: Perfect=0.06, Great=0.13, Good=0.22                ║
║                                                                      ║
║  VanishTo RemoteEvent – szerver visszajelzés a vanish-hoz           ║
║  MeleeClashVanish – clash közbeni vanish                            ║
╚══════════════════════════════════════════════════════════════════════╝
]]

local CFG = {
    -- Vanish delay a hit után – minél kisebb annál jobb
    -- Perfect clash window = 0.06s → ennél kicsit több
    VANISH_DELAY     = 0.04,
    VANISH_COOLDOWN  = 0.46,

    -- Ki küszöbök
    -- VANISH_COST_FRACTION = 0.14 → legalább 20% kell biztonságosan
    KI_VANISH        = 0.20,
    KI_STEP          = 0.06,   -- SideStep Ki costja alacsonyabb

    -- Lánc limit – vanishCost lánconként nő, 4 után túl drága
    CHAIN_MAX        = 4,
    CHAIN_RESET      = 2.5,

    -- Post-vanish SideStep (dupla dodge)
    -- STEP_TIMING air back: delay=0.06 → ezért kicsit több
    POST_STEP        = true,
    POST_STEP_DELAY  = 0.10,
    STEP_DIRS        = { "back", "left", "right" },

    -- Fallback sorrend
    FALLBACK         = { "SideStep", "Block" },
    BLOCK_HOLD       = 0.55,
    STEP_COOLDOWN    = 0.52,

    HP_DROP_MIN      = 0.5,
    DEDUP_WIN        = 0.07,
    DEBUG            = false,
}

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS         = game:GetService("ReplicatedStorage")

local Remotes     = require(RS.Modules.Remotes)
local ActionState = require(RS.Modules.ActionState)
local CombatPublic= require(RS.Modules.CombatPublic)

local LP   = Players.LocalPlayer
local char = LP.Character or LP.CharacterAdded:Wait()
local hum  = char:WaitForChild("Humanoid")
local hrp  = char:WaitForChild("HumanoidRootPart")

LP.CharacterAdded:Connect(function(c)
    char=c; hum=c:WaitForChild("Humanoid"); hrp=c:WaitForChild("HumanoidRootPart")
end)

local S = {
    lastVanish=0, lastHitAt=0, lastHP=math.huge,
    chainCount=0, lastChainAt=0, lastStepAt=0,
    totalVanish=0, totalStep=0, totalBlock=0,
    mode="Idle",
}
local lastTrig = 0
local function dbg(...) if CFG.DEBUG then print("[AVP]",...) end end

-- ══════════════════════════════════════════
-- GUI
-- ══════════════════════════════════════════
local sg = Instance.new("ScreenGui")
sg.Name,sg.ResetOnSpawn,sg.IgnoreGuiInset = "AVP_HUD",false,true
sg.Parent = LP:WaitForChild("PlayerGui")

local fr = Instance.new("Frame",sg)
fr.Size=UDim2.new(0,195,0,90); fr.Position=UDim2.new(0,12,0.5,54)
fr.BackgroundColor3=Color3.fromRGB(8,3,18); fr.BackgroundTransparency=0.12
fr.BorderSizePixel=0
Instance.new("UICorner",fr).CornerRadius=UDim.new(0,10)
local stk=Instance.new("UIStroke",fr); stk.Color=Color3.fromRGB(170,50,255); stk.Thickness=1.6

local titleL=Instance.new("TextLabel",fr)
titleL.Size=UDim2.new(1,0,0,22); titleL.Position=UDim2.new(0,0,0,4)
titleL.BackgroundTransparency=1; titleL.Text="👻 AUTO VANISH PRO"
titleL.TextColor3=Color3.fromRGB(190,70,255); titleL.Font=Enum.Font.GothamBold; titleL.TextSize=12

local modeL=Instance.new("TextLabel",fr)
modeL.Name="Mode"; modeL.Size=UDim2.new(1,-8,0,20); modeL.Position=UDim2.new(0,4,0,26)
modeL.BackgroundTransparency=1; modeL.TextColor3=Color3.fromRGB(220,120,255)
modeL.Font=Enum.Font.GothamBold; modeL.TextSize=14; modeL.TextXAlignment=Enum.TextXAlignment.Left
modeL.Text="● IDLE"

local statL=Instance.new("TextLabel",fr)
statL.Name="Stat"; statL.Size=UDim2.new(1,-8,0,14); statL.Position=UDim2.new(0,4,0,48)
statL.BackgroundTransparency=1; statL.TextColor3=Color3.fromRGB(140,100,180)
statL.Font=Enum.Font.Gotham; statL.TextSize=10; statL.TextXAlignment=Enum.TextXAlignment.Left
statL.Text="👻0 ⚡0 🛡0 | Lánc:0/"..CFG.CHAIN_MAX

local kiBarBg=Instance.new("Frame",fr)
kiBarBg.Size=UDim2.new(1,-10,0,6); kiBarBg.Position=UDim2.new(0,5,0,66)
kiBarBg.BackgroundColor3=Color3.fromRGB(20,10,40); kiBarBg.BorderSizePixel=0
Instance.new("UICorner",kiBarBg).CornerRadius=UDim.new(0,3)
local kiBar=Instance.new("Frame",kiBarBg); kiBar.Name="Fill"
kiBar.Size=UDim2.new(1,0,1,0); kiBar.BackgroundColor3=Color3.fromRGB(100,50,255); kiBar.BorderSizePixel=0
Instance.new("UICorner",kiBar).CornerRadius=UDim.new(0,3)

local function setMode(m,color)
    S.mode=m
    if modeL then modeL.Text=m; modeL.TextColor3=color or Color3.fromRGB(220,120,255) end
end
local function updateHUD(ki)
    if kiBar then kiBar.Size=UDim2.new(math.clamp(ki,0,1),0,1,0) end
    if statL then statL.Text="👻"..S.totalVanish.." ⚡"..S.totalStep.." 🛡"..S.totalBlock
        .." | Lánc:"..S.chainCount.."/"..CFG.CHAIN_MAX end
end

-- ══════════════════════════════════════════
-- KI LEKÉRÉS (Stats gyerek attribútumokból)
-- ══════════════════════════════════════════
local function getKi()
    if not char then return 1 end
    -- Humanoid.Stats attribútumok
    local hs = hum and hum:FindFirstChild("Stats")
    if hs then
        local k=hs:GetAttribute("Ki") or hs:GetAttribute("Energy")
        local m=hs:GetAttribute("MaxKi") or hs:GetAttribute("MaxEnergy")
        if k and m and m>0 then return k/m end
    end
    local k=char:GetAttribute("Ki"); local m=char:GetAttribute("MaxKi")
    if k and m and m>0 then return k/m end
    return 1
end

-- vanishCost(chainCount) – CombatPublic alapján: VANISH_COST_FRACTION + lánc szorzó
-- A pontos képlet nem ismert, de VANISH_COST_FRACTION=0.14 az alap
local function vanishCost()
    return CombatPublic.VANISH_COST_FRACTION + (S.chainCount * 0.04)
end

-- ══════════════════════════════════════════
-- FELTÉTELEK
-- ══════════════════════════════════════════
local function canVanish(ki)
    if tick()-S.lastVanish < CFG.VANISH_COOLDOWN then return false end
    if S.chainCount >= CFG.CHAIN_MAX then return false end
    if ki < CFG.KI_VANISH then return false end
    if ki < vanishCost() then return false end
    return not ActionState.isDowned(char)
       and not ActionState.isChanneling(char)
       and not ActionState.isIncapacitated(char)
       and not ActionState.isIntangible(char)
       and not ActionState.isRooted(char)
end

local function canStep(ki)
    if tick()-S.lastStepAt < CFG.STEP_COOLDOWN then return false end
    if ki < CFG.KI_STEP then return false end
    return not ActionState.isDowned(char)
       and not ActionState.isChanneling(char)
       and not ActionState.isIncapacitated(char)
       and not ActionState.inStepIFrames(char)
end

local function canBlock()
    return not ActionState.isDowned(char)
       and not ActionState.isChanneling(char)
       and not ActionState.isIncapacitated(char)
       and not ActionState.isRooted(char)
end

-- ══════════════════════════════════════════
-- VÉGREHAJTÁS
-- ══════════════════════════════════════════
local function execBlock()
    if not canBlock() then return end
    setMode("🛡 BLOCK", Color3.fromRGB(255,210,60))
    S.totalBlock+=1
    Remotes.PerformAction:FireServer("Block",{phase="start"})
    task.delay(CFG.BLOCK_HOLD, function()
        Remotes.PerformAction:FireServer("Block",{phase="stop"})
        if S.mode=="🛡 BLOCK" then setMode("● IDLE") end
    end)
end

local function execStep()
    local ki=getKi()
    if not canStep(ki) then execBlock(); return end
    S.lastStepAt=tick(); S.totalStep+=1
    setMode("⚡ SIDESTEP", Color3.fromRGB(80,200,255))
    local air=char:GetAttribute("Flying")==true or hum.FloorMaterial==Enum.Material.Air
    local dir=CFG.STEP_DIRS[math.random(1,#CFG.STEP_DIRS)]
    Remotes.PerformAction:FireServer("SideStep",{kind=dir, air=air})
    task.delay(0.4, function() if S.mode=="⚡ SIDESTEP" then setMode("● IDLE") end end)
end

local function execVanish()
    local now=tick()
    -- Lánc reset
    if now-S.lastChainAt > CFG.CHAIN_RESET then S.chainCount=0 end

    local ki=getKi()
    if canVanish(ki) then
        setMode("👻 VANISH", Color3.fromRGB(220,60,255))
        S.totalVanish+=1; S.lastVanish=now; S.lastChainAt=now; S.chainCount+=1
        Remotes.PerformAction:FireServer("Vanish",{})
        dbg("Vanish! lánc="..S.chainCount.." cost="..string.format("%.2f",vanishCost()))
        -- Post-Step a STEP_TIMING air alapján
        if CFG.POST_STEP then
            task.delay(CFG.POST_STEP_DELAY, execStep)
        end
        task.delay(CFG.VANISH_COOLDOWN, function()
            if S.mode=="👻 VANISH" then setMode("● IDLE") end
        end)
    else
        -- Fallback sorrendben
        for _, fb in ipairs(CFG.FALLBACK) do
            if fb=="SideStep" and canStep(ki) then execStep(); return
            elseif fb=="Block" and canBlock() then execBlock(); return
            end
        end
    end
    updateHUD(ki)
end

-- ══════════════════════════════════════════
-- 4+1 RÉTEGŰ DETEKTÁLÁS
-- ══════════════════════════════════════════
local function onHit(src)
    local now=tick()
    if now-lastTrig < CFG.DEDUP_WIN then return end
    lastTrig=now
    dbg("HIT –",src)
    task.delay(CFG.VANISH_DELAY, execVanish)
end

-- Réteg 1: LastHitAt
local function attachLastHit(c)
    local v=c:GetAttribute("LastHitAt"); if v then S.lastHitAt=v end
    c:GetAttributeChangedSignal("LastHitAt"):Connect(function()
        local nv=c:GetAttribute("LastHitAt")
        if nv and nv~=S.lastHitAt then S.lastHitAt=nv; onHit("LastHitAt") end
    end)
end

-- Réteg 2: HealthChanged
local function attachHP(h)
    S.lastHP=h.Health
    h.HealthChanged:Connect(function(hp)
        local d=S.lastHP-hp; S.lastHP=hp
        if d>=CFG.HP_DROP_MIN then onHit("HP-"..d) end
    end)
end

-- Réteg 3: HitStop + Réteg 4: CombatFeedback + Réteg 5: VanishTo visszajelzés
local RemF=RS:WaitForChild("Remotes",10)
if RemF then
    local hs=RemF:FindFirstChild("HitStop")
    if hs then hs.OnClientEvent:Connect(function(v)
        if v==nil or v==char then onHit("HitStop") end
    end) end

    local cf=RemF:FindFirstChild("CombatFeedback")
    if cf then cf.OnClientEvent:Connect(function(d)
        if type(d)=="table" then
            local t=d.type or d.feedbackType or d[1]
            if t=="Hit" or t=="hit" then onHit("CF") end
        end
    end) end

    -- MeleeClashVanish – clash közbeni vanish lehetőség
    local mcv=RemF:FindFirstChild("MeleeClashVanish")
    if mcv then mcv.OnClientEvent:Connect(function()
        dbg("MeleeClashVanish!")
        execVanish()
    end) end
end

-- Heartbeat: Ki bar + lánc reset
RunService.Heartbeat:Connect(function()
    updateHUD(getKi())
    if S.chainCount>0 and tick()-S.lastChainAt>CFG.CHAIN_RESET then
        S.chainCount=0
    end
end)

-- Karakter újratöltés
LP.CharacterAdded:Connect(function(c)
    char=c; hum=c:WaitForChild("Humanoid"); hrp=c:WaitForChild("HumanoidRootPart")
    S.lastVanish=0; S.lastHitAt=0; S.lastHP=math.huge
    S.chainCount=0; S.lastChainAt=0; S.lastStepAt=0; lastTrig=0
    setMode("● IDLE"); attachLastHit(c); attachHP(hum)
end)

attachLastHit(char); attachHP(hum)
print("[AutoVanish PRO] ✓ betöltve | VANISH_COST_FRACTION=", CombatPublic.VANISH_COST_FRACTION)
