-- ══════════════════════════════════════════════════════════════════════
local CFG = {
    VANISH_DELAY     = 0.04,
    VANISH_COOLDOWN  = 0.46,
    KI_VANISH        = 0.20,
    KI_STEP          = 0.06,
    CHAIN_MAX        = 4,
    CHAIN_RESET      = 2.5,
    POST_STEP        = true,
    POST_STEP_DELAY  = 0.10,
    STEP_DIRS        = { "back", "left", "right" },
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
}
local lastTrig = 0

local function getKi()
    if not char then return 1 end
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

local function vanishCost()
    return CombatPublic.VANISH_COST_FRACTION + (S.chainCount * 0.04)
end

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

local function execBlock()
    if not canBlock() then return end
    Remotes.PerformAction:FireServer("Block",{phase="start"})
    task.delay(CFG.BLOCK_HOLD, function()
        Remotes.PerformAction:FireServer("Block",{phase="stop"})
    end)
end

local function execStep()
    local ki=getKi()
    if not canStep(ki) then execBlock(); return end
    S.lastStepAt=tick()
    local air=char:GetAttribute("Flying")==true or hum.FloorMaterial==Enum.Material.Air
    local dir=CFG.STEP_DIRS[math.random(1,#CFG.STEP_DIRS)]
    Remotes.PerformAction:FireServer("SideStep",{kind=dir, air=air})
end

local function execVanish()
    -- Globális GUI kapcsoló ellenőrzése
    if _G.KillAuraCFG and _G.KillAuraCFG.AUTO_VANISH_ENABLED == false then return end

    local now=tick()
    if now-S.lastChainAt > CFG.CHAIN_RESET then S.chainCount=0 end

    local ki=getKi()
    if canVanish(ki) then
        S.lastVanish=now; S.lastChainAt=now; S.chainCount+=1
        Remotes.PerformAction:FireServer("Vanish",{})
        if CFG.POST_STEP then
            task.delay(CFG.POST_STEP_DELAY, execStep)
        end
    else
        for _, fb in ipairs(CFG.FALLBACK) do
            if fb=="SideStep" and canStep(ki) then execStep(); return
            elseif fb=="Block" and canBlock() then execBlock(); return
            end
        end
    end
end

local function onHit(src)
    if _G.KillAuraCFG and _G.KillAuraCFG.AUTO_VANISH_ENABLED == false then return end
    local now=tick()
    if now-lastTrig < CFG.DEDUP_WIN then return end
    lastTrig=now
    task.delay(CFG.VANISH_DELAY, execVanish)
end

local function attachLastHit(c)
    local v=c:GetAttribute("LastHitAt"); if v then S.lastHitAt=v end
    c:GetAttributeChangedSignal("LastHitAt"):Connect(function()
        local nv=c:GetAttribute("LastHitAt")
        if nv and nv~=S.lastHitAt then S.lastHitAt=nv; onHit("LastHitAt") end
    end)
end

local function attachHP(h)
    S.lastHP=h.Health
    h.HealthChanged:Connect(function(hp)
        local d=S.lastHP-hp; S.lastHP=hp
        if d>=CFG.HP_DROP_MIN then onHit("HP-"..d) end
    end)
end

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

    local mcv=RemF:FindFirstChild("MeleeClashVanish")
    if mcv then mcv.OnClientEvent:Connect(function()
        execVanish()
    end) end
end

RunService.Heartbeat:Connect(function()
    if S.chainCount>0 and tick()-S.lastChainAt>CFG.CHAIN_RESET then
        S.chainCount=0
    end
end)

LP.CharacterAdded:Connect(function(c)
    char=c; hum=c:WaitForChild("Humanoid"); hrp=c:WaitForChild("HumanoidRootPart")
    S.lastVanish=0; S.lastHitAt=0; S.lastHP=math.huge
    S.chainCount=0; S.lastChainAt=0; S.lastStepAt=0; lastTrig=0
    attachLastHit(c); attachHP(hum)
end)

attachLastHit(char); attachHP(hum)
print("[AutoVanish PRO] ✓ Betöltve és összekötve a Master GUI-val")
