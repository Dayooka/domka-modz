-- ══════════════════════════════════════════════════════════════════════
local CFG = {
    PARRY_DELAY      = 0.06,
    STEP_COOLDOWN    = 0.52,
    BLOCK_HOLD       = 0.55,
    BLOCK_COOLDOWN   = 0.22,
    STEP_DIRS        = { "back", "left", "right" },
    HP_DROP_MIN      = 0.5,
    DEDUP_WIN        = 0.07,
    PREEMPTIVE       = false,
    PREEMPTIVE_RANGE = 20,
    PREEMPTIVE_REHOLD= 0.48,
    DEBUG            = false,
}

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS         = game:GetService("ReplicatedStorage")
local CS         = game:GetService("CollectionService")

local Remotes     = require(RS.Modules.Remotes)
local ActionState = require(RS.Modules.ActionState)
local Entities    = require(RS.Modules.Entities)
local CombatPublic= require(RS.Modules.CombatPublic)

local LP   = Players.LocalPlayer
local char = LP.Character or LP.CharacterAdded:Wait()
local hum  = char:WaitForChild("Humanoid")
local hrp  = char:WaitForChild("HumanoidRootPart")

LP.CharacterAdded:Connect(function(c)
    char=c; hum=c:WaitForChild("Humanoid"); hrp=c:WaitForChild("HumanoidRootPart")
end)

local S = { blocking=false, lastBlockAt=0, lastHitAt=0, lastHP=math.huge, lastStepAt=0 }
local lastTrig = 0
local function dbg(...) if CFG.DEBUG then print("[ABP]",...) end end

local function canBlock()
    return not ActionState.isDowned(char)
       and not ActionState.isChanneling(char)
       and not ActionState.isIncapacitated(char)
       and not ActionState.isRooted(char)
       and not ActionState.isIntangible(char)
end

local function canStep()
    return canBlock()
       and not ActionState.inStepIFrames(char)
       and (tick() - S.lastStepAt >= CFG.STEP_COOLDOWN)
end

local function fireBlock()
    -- Globális GUI kapcsoló ellenőrzése
    if _G.KillAuraCFG and _G.KillAuraCFG.AUTO_BLOCK_ENABLED == false then return end

    local now = tick()
    if now - S.lastBlockAt < CFG.BLOCK_COOLDOWN then return end
    if not canBlock() then return end
    S.blocking=true; S.lastBlockAt=now
    Remotes.PerformAction:FireServer("Block", { phase="start" })
    task.delay(CFG.BLOCK_HOLD, function()
        if S.blocking and not S.preemptLock then
            Remotes.PerformAction:FireServer("Block", { phase="stop" })
            S.blocking=false
        end
    end)
end

local function fireStep()
    if _G.KillAuraCFG and _G.KillAuraCFG.AUTO_BLOCK_ENABLED == false then return end
    if not canStep() then fireBlock(); return end
    S.lastStepAt = tick()
    local dir = CFG.STEP_DIRS[math.random(1,#CFG.STEP_DIRS)]
    local air = char:GetAttribute("Flying")==true or hum.FloorMaterial==Enum.Material.Air
    Remotes.PerformAction:FireServer("SideStep", { kind=dir, air=air })
end

local function onHit(src)
    if _G.KillAuraCFG and _G.KillAuraCFG.AUTO_BLOCK_ENABLED == false then return end
    local now = tick()
    if now - lastTrig < CFG.DEDUP_WIN then return end
    lastTrig = now
    fireBlock()
    task.delay(CFG.PARRY_DELAY, fireStep)
end

local function attachLastHit(c)
    local v = c:GetAttribute("LastHitAt")
    if v then S.lastHitAt = v end
    c:GetAttributeChangedSignal("LastHitAt"):Connect(function()
        local nv = c:GetAttribute("LastHitAt")
        if nv and nv ~= S.lastHitAt then
            S.lastHitAt = nv
            onHit("LastHitAt")
        end
    end)
end

local function attachHP(h)
    S.lastHP = h.Health
    h.HealthChanged:Connect(function(hp)
        local d = S.lastHP - hp; S.lastHP = hp
        if d >= CFG.HP_DROP_MIN then onHit("HP-"..d) end
    end)
end

local RemF = RS:WaitForChild("Remotes", 10)
if RemF then
    local hs = RemF:FindFirstChild("HitStop")
    if hs then hs.OnClientEvent:Connect(function(v)
        if v==nil or v==char then onHit("HitStop") end
    end) end

    local cf = RemF:FindFirstChild("CombatFeedback")
    if cf then cf.OnClientEvent:Connect(function(d)
        if type(d)=="table" then
            local t=d.type or d.feedbackType or d[1]
            if t=="Hit" or t=="hit" then onHit("CombatFeedback") end
        end
    end) end
end

LP.CharacterAdded:Connect(function(c)
    char=c; hum=c:WaitForChild("Humanoid"); hrp=c:WaitForChild("HumanoidRootPart")
    S.blocking=false; S.lastBlockAt=0; S.lastHitAt=0
    S.lastHP=math.huge; S.lastStepAt=0; lastTrig=0
    attachLastHit(c); attachHP(hum)
end)

attachLastHit(char); attachHP(hum)
print("[AutoBlockParry] ✓ Betöltve és összekötve a Master GUI-val")
