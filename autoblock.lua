local CFG = {
    -- STEP_PERFECT_WINDOW = 0.3 → ezen belül kell küldeni
    -- Delay legyen minimális hogy biztosan a perfect ablakba essen
    PARRY_DELAY      = 0.06,

    -- STEP_IFRAME = 0.28 → ennyi ideig van iFrame SideStep után
    -- STEP_COOLDOWN = 0.5 → ennél ne küldjük hamarabb
    STEP_COOLDOWN    = 0.52,   -- kicsit több mint a szerver cooldown

    -- Block hold – elég hosszú hogy a szerver feldolgozza
    BLOCK_HOLD       = 0.55,
    BLOCK_COOLDOWN   = 0.22,

    -- SideStep irányok (ground timing alapján back a legjobb: 15 studs)
    STEP_DIRS        = { "back", "left", "right" },

    -- HP drop küszöb
    HP_DROP_MIN      = 0.5,

    -- Deduplikáció ablak
    DEDUP_WIN        = 0.07,

    -- Preemptív block ha ellenség közel (MELEE_APPROACH_MAX = 24)
    PREEMPTIVE       = false,   -- true = mindig block ha valaki 20 studson belül
    PREEMPTIVE_RANGE = 20,
    PREEMPTIVE_REHOLD= 0.48,

    DEBUG = false,
}

-- ══════════════════════════════════════════
-- SERVICES & MODULOK
-- ══════════════════════════════════════════
local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS         = game:GetService("ReplicatedStorage")
local CS         = game:GetService("CollectionService")

local Remotes     = require(RS.Modules.Remotes)
local ActionState = require(RS.Modules.ActionState)
local Entities    = require(RS.Modules.Entities)
local CombatPublic= require(RS.Modules.CombatPublic)

-- ══════════════════════════════════════════
-- KARAKTER
-- ══════════════════════════════════════════
local LP   = Players.LocalPlayer
local char = LP.Character or LP.CharacterAdded:Wait()
local hum  = char:WaitForChild("Humanoid")
local hrp  = char:WaitForChild("HumanoidRootPart")

LP.CharacterAdded:Connect(function(c)
    char=c; hum=c:WaitForChild("Humanoid"); hrp=c:WaitForChild("HumanoidRootPart")
end)

-- ══════════════════════════════════════════
-- ÁLLAPOT
-- ══════════════════════════════════════════
local S = {
    blocking=false, lastBlockAt=0,
    lastHitAt=0, lastHP=math.huge,
    lastStepAt=0,
}
local lastTrig = 0
local function dbg(...) if CFG.DEBUG then print("[ABP]",...) end end

-- ══════════════════════════════════════════
-- FELTÉTELEK (pontos ActionState API alapján)
-- ══════════════════════════════════════════
local function canBlock()
    return not ActionState.isDowned(char)
       and not ActionState.isChanneling(char)
       and not ActionState.isIncapacitated(char)
       and not ActionState.isRooted(char)
       and not ActionState.isIntangible(char)
end

local function canStep()
    -- inStepIFrames = StepIFrameUntil attribútum
    return canBlock()
       and not ActionState.inStepIFrames(char)
       and (tick() - S.lastStepAt >= CFG.STEP_COOLDOWN)
end

-- Van-e ellenség MELEE_APPROACH_MAX-on belül?
local function enemyNear(range)
    range = range or CombatPublic.MELEE_APPROACH_MAX
    if not hrp then return false end
    for _, npc in ipairs(CS:GetTagged(Entities.Tag.NPC)) do
        if npc:IsA("Model") and npc:IsDescendantOf(workspace) then
            local h = npc:FindFirstChildOfClass("Humanoid")
            local r = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChild("Torso")
            if h and h.Health > 0 and r then
                if (r.Position - hrp.Position).Magnitude <= range then return true end
            end
        end
    end
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= LP and pl.Character then
            local r = pl.Character:FindFirstChild("HumanoidRootPart")
            if r and (r.Position - hrp.Position).Magnitude <= range then return true end
        end
    end
    return false
end

-- ══════════════════════════════════════════
-- VÉGREHAJTÁS
-- ══════════════════════════════════════════
local function fireBlock()
    local now = tick()
    if now - S.lastBlockAt < CFG.BLOCK_COOLDOWN then return end
    if not canBlock() then return end
    S.blocking=true; S.lastBlockAt=now
    Remotes.PerformAction:FireServer("Block", { phase="start" })
    dbg("Block START")
    task.delay(CFG.BLOCK_HOLD, function()
        if S.blocking and not S.preemptLock then
            Remotes.PerformAction:FireServer("Block", { phase="stop" })
            S.blocking=false
            dbg("Block STOP")
        end
    end)
end

local function fireStep()
    if not canStep() then fireBlock(); return end
    S.lastStepAt = tick()
    local dir = CFG.STEP_DIRS[math.random(1,#CFG.STEP_DIRS)]
    -- CombatMovement.isAirborne: Flying attr vagy FloorMaterial
    local air = char:GetAttribute("Flying")==true
             or hum.FloorMaterial==Enum.Material.Air
    Remotes.PerformAction:FireServer("SideStep", { kind=dir, air=air })
    dbg("SideStep →", dir, "air=", air)
end

local function onHit(src)
    local now = tick()
    if now - lastTrig < CFG.DEDUP_WIN then return end
    lastTrig = now
    dbg("HIT –", src)

    -- Azonnali block
    fireBlock()

    -- STEP_PERFECT_WINDOW-on belül SideStep
    task.delay(CFG.PARRY_DELAY, fireStep)
end

-- ══════════════════════════════════════════
-- 4 RÉTEGŰ DETEKTÁLÁS
-- ══════════════════════════════════════════
-- Réteg 1: LastHitAt (ActionState.LAST_HIT_ATTR = "LastHitAt")
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

-- Réteg 2: HealthChanged
local function attachHP(h)
    S.lastHP = h.Health
    h.HealthChanged:Connect(function(hp)
        local d = S.lastHP - hp; S.lastHP = hp
        if d >= CFG.HP_DROP_MIN then onHit("HP-"..d) end
    end)
end

-- Réteg 3+4: HitStop + CombatFeedback remote-ok
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

-- ══════════════════════════════════════════
-- PREEMPTÍV MÓD (opcionális)
-- ══════════════════════════════════════════
S.preemptLock = false
if CFG.PREEMPTIVE then
    task.spawn(function()
        while true do
            task.wait(CFG.PREEMPTIVE_REHOLD)
            if enemyNear(CFG.PREEMPTIVE_RANGE) and canBlock() then
                S.preemptLock = true
                Remotes.PerformAction:FireServer("Block", { phase="start" })
                S.blocking=true; S.lastBlockAt=tick()
            else
                if S.preemptLock then
                    S.preemptLock=false
                    Remotes.PerformAction:FireServer("Block", { phase="stop" })
                    S.blocking=false
                end
            end
        end
    end)
end

-- ══════════════════════════════════════════
-- KARAKTER ÚJRATÖLTÉS
-- ══════════════════════════════════════════
LP.CharacterAdded:Connect(function(c)
    char=c; hum=c:WaitForChild("Humanoid"); hrp=c:WaitForChild("HumanoidRootPart")
    S.blocking=false; S.lastBlockAt=0; S.lastHitAt=0
    S.lastHP=math.huge; S.lastStepAt=0; lastTrig=0
    attachLastHit(c); attachHP(hum)
end)

attachLastHit(char); attachHP(hum)
print("[AutoBlockParry] ✓ betöltve | PreemptiveBlock:", CFG.PREEMPTIVE)
