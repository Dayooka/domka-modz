local Cfg    = require(script.Parent._Config)
local Shared = require(script.Parent._Shared)
local RS     = game:GetService("ReplicatedStorage")

local CP = Shared.getCombatPublic()   -- CombatPublic.VANISH_COST_FRACTION

local S = {
    lastVanish   = 0,
    lastHitAt    = 0,
    lastHP       = math.huge,
    chainCount   = 0,
    lastChainAt  = 0,
    lastStepAt   = 0,
    totalVanish  = 0,
    totalStep    = 0,
    totalBlock   = 0,
    mode         = "Idle",
}
local lastTrig = 0

-- ── Ki + vanish cost ───────────────────────────────────────────────
local function getKi() return Shared.getKiPct() end
local function vanishCost()
    local base = CP and CP.VANISH_COST_FRACTION or 0.14
    return base + S.chainCount * 0.04
end

-- ── Feltételek ─────────────────────────────────────────────────────
local function canVanish(ki)
    local cd  = Cfg.get("Vanish","VANISH_COOLDOWN") or 0.46
    local max = Cfg.get("Vanish","CHAIN_MAX")        or 4
    local min = Cfg.get("Vanish","KI_VANISH")        or 0.20
    if tick() - S.lastVanish < cd    then return false end
    if S.chainCount >= max            then return false end
    if ki < min or ki < vanishCost() then return false end
    return Shared.canBlock()
end
local function canStep(ki)
    local minKi = Cfg.get("Vanish","KI_STEP") or 0.06
    if ki < minKi then return false end
    return Shared.canStep(S.lastStepAt, Cfg.get("Vanish","STEP_COOLDOWN"))
end

-- ── Végrehajtás ────────────────────────────────────────────────────
local function execBlock()
    if not Shared.canBlock() then return end
    S.totalBlock += 1; S.mode = "Block"
    local hold = Cfg.get("Vanish","BLOCK_HOLD") or 0.55
    Shared.perform("Block", { phase = "start" })
    task.delay(hold, function()
        Shared.perform("Block", { phase = "stop" })
        if S.mode == "Block" then S.mode = "Idle" end
    end)
end

local function execStep()
    local ki = getKi()
    if not canStep(ki) then execBlock(); return end
    S.lastStepAt = tick(); S.totalStep += 1; S.mode = "Step"
    local dirs = Cfg.get("Vanish","STEP_DIRS") or { "back","left","right" }
    Shared.perform("SideStep", {
        kind = dirs[math.random(1, #dirs)],
        air  = Shared.isAirborne(),
    })
    task.delay(0.4, function() if S.mode == "Step" then S.mode = "Idle" end end)
end

local function execVanish()
    local now    = tick()
    local reset  = Cfg.get("Vanish","CHAIN_RESET") or 2.5
    if now - S.lastChainAt > reset then S.chainCount = 0 end

    local ki = getKi()
    if canVanish(ki) then
        S.mode = "Vanish"; S.totalVanish += 1
        S.lastVanish = now; S.lastChainAt = now; S.chainCount += 1
        Shared.perform("Vanish", {})
        if Cfg.get("Vanish","POST_STEP") then
            task.delay(Cfg.get("Vanish","POST_STEP_DELAY") or 0.10, execStep)
        end
        local cd = Cfg.get("Vanish","VANISH_COOLDOWN") or 0.46
        task.delay(cd, function() if S.mode == "Vanish" then S.mode = "Idle" end end)
    else
        local fb = Cfg.get("Vanish","FALLBACK") or { "SideStep","Block" }
        for _, f in ipairs(fb) do
            if f == "SideStep" and canStep(ki) then execStep(); return
            elseif f == "Block" and Shared.canBlock() then execBlock(); return end
        end
    end
end

-- ── Hit detektálás ─────────────────────────────────────────────────
local function onHit()
    if not Cfg.get("Vanish","enabled") then return end
    local now   = tick()
    local dedup = Cfg.get("Vanish","DEDUP_WIN") or 0.07
    if now - lastTrig < dedup then return end
    lastTrig = now
    task.delay(Cfg.get("Vanish","VANISH_DELAY") or 0.04, execVanish)
end

local function attachLastHit(c)
    local v = c:GetAttribute("LastHitAt"); if v then S.lastHitAt = v end
    c:GetAttributeChangedSignal("LastHitAt"):Connect(function()
        local nv = c:GetAttribute("LastHitAt")
        if nv and nv ~= S.lastHitAt then S.lastHitAt = nv; onHit() end
    end)
end
local function attachHP(h)
    S.lastHP = h.Health
    h.HealthChanged:Connect(function(hp)
        local d = S.lastHP - hp; S.lastHP = hp
        local min = Cfg.get("Vanish","HP_DROP_MIN") or 0.5
        if d >= min then onHit() end
    end)
end

local RemF = RS:WaitForChild("Remotes", 10)
if RemF then
    local hs = RemF:FindFirstChild("HitStop")
    if hs then hs.OnClientEvent:Connect(function(v)
        if v == nil or v == Shared.getChar() then onHit() end
    end) end
    local cf = RemF:FindFirstChild("CombatFeedback")
    if cf then cf.OnClientEvent:Connect(function(d)
        if type(d) == "table" then
            local t = d.type or d.feedbackType or d[1]
            if t == "Hit" or t == "hit" then onHit() end
        end
    end) end
    local mcv = RemF:FindFirstChild("MeleeClashVanish")
    if mcv then mcv.OnClientEvent:Connect(function() onHit() end) end
end

game:GetService("RunService").Heartbeat:Connect(function()
    local reset = Cfg.get("Vanish","CHAIN_RESET") or 2.5
    if S.chainCount > 0 and tick() - S.lastChainAt > reset then S.chainCount = 0 end
end)

local LP = Shared.getLP()
LP.CharacterAdded:Connect(function(c)
    S.lastVanish=0; S.lastHitAt=0; S.lastHP=math.huge
    S.chainCount=0; S.lastChainAt=0; S.lastStepAt=0; lastTrig=0; S.mode="Idle"
    attachLastHit(c); attachHP(c:WaitForChild("Humanoid"))
end)
local char = LP.Character or LP.CharacterAdded:Wait()
attachLastHit(char); attachHP(char:WaitForChild("Humanoid"))

-- ── Publikus API ───────────────────────────────────────────────────
local Module = {}
function Module.getStats()
    return {
        enabled     = Cfg.get("Vanish","enabled"),
        mode        = S.mode,
        chain       = S.chainCount,
        ki          = math.floor(getKi() * 100),
        totalVanish = S.totalVanish,
        totalStep   = S.totalStep,
        totalBlock  = S.totalBlock,
    }
end

print("[AutoVanish] ✓")
return Module
