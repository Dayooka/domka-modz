--[[
    01_AutoBlockParry  –  LocalScript
    Elhelyezés: StarterPlayerScripts > AIOScripts
    Config:  _Config.get("BlockParry", key)
    Státusz: require(this).getStats()
]]

local Cfg    = (_G._AIO_Config)
local Shared = (_G._AIO_Shared)
local RS     = game:GetService("ReplicatedStorage")
local Players= game:GetService("Players")
local CS     = game:GetService("CollectionService")

local S = {
    blocking     = false,
    lastBlockAt  = 0,
    lastHitAt    = 0,
    lastHP       = math.huge,
    lastStepAt   = 0,
    preemptLock  = false,
    totalParry   = 0,
    totalBlock   = 0,
}
local lastTrig = 0

-- ── Feltételek ─────────────────────────────────────────────────────
local function canBlock() return Shared.canBlock() end
local function canStep()
    return Shared.canStep(S.lastStepAt, Cfg.get("BlockParry","STEP_COOLDOWN"))
end

local function enemyNear()
    local range = Cfg.get("BlockParry","PREEMPTIVE_RANGE") or 20
    local hrp   = Shared.getHRP()
    if not hrp then return false end
    local Ent   = Shared.getEntities()
    if Ent then
        for _, npc in ipairs(CS:GetTagged(Ent.Tag.NPC)) do
            if npc:IsA("Model") and npc:IsDescendantOf(workspace) then
                local h = npc:FindFirstChildOfClass("Humanoid")
                local r = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChild("Torso")
                if h and h.Health > 0 and r then
                    if (r.Position - hrp.Position).Magnitude <= range then return true end
                end
            end
        end
    end
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= Shared.getLP() and pl.Character then
            local r = pl.Character:FindFirstChild("HumanoidRootPart")
            if r and (r.Position - hrp.Position).Magnitude <= range then return true end
        end
    end
    return false
end

-- ── Végrehajtás ────────────────────────────────────────────────────
local function fireBlock()
    local now  = tick()
    local cd   = Cfg.get("BlockParry","BLOCK_COOLDOWN") or 0.22
    local hold = Cfg.get("BlockParry","BLOCK_HOLD")     or 0.55
    if now - S.lastBlockAt < cd then return end
    if not canBlock() then return end
    S.blocking    = true
    S.lastBlockAt = now
    S.totalBlock  = S.totalBlock + 1
    Shared.perform("Block", { phase = "start" })
    task.delay(hold, function()
        if S.blocking and not S.preemptLock then
            Shared.perform("Block", { phase = "stop" })
            S.blocking = false
        end
    end)
end

local function fireStep()
    if not canStep() then fireBlock(); return end
    local dirs = Cfg.get("BlockParry","STEP_DIRS") or { "back","left","right" }
    S.lastStepAt = tick()
    S.totalParry = S.totalParry + 1
    Shared.perform("SideStep", {
        kind = dirs[math.random(1, #dirs)],
        air  = Shared.isAirborne(),
    })
end

local function onHit()
    if not Cfg.get("BlockParry","enabled") then return end
    local now  = tick()
    local dedup = Cfg.get("BlockParry","DEDUP_WIN") or 0.07
    if now - lastTrig < dedup then return end
    lastTrig = now
    fireBlock()
    task.delay(Cfg.get("BlockParry","PARRY_DELAY") or 0.06, fireStep)
end

-- ── 4 rétegű detektálás ────────────────────────────────────────────
local function attachLastHit(c)
    local v = c:GetAttribute("LastHitAt")
    if v then S.lastHitAt = v end
    c:GetAttributeChangedSignal("LastHitAt"):Connect(function()
        local nv = c:GetAttribute("LastHitAt")
        if nv and nv ~= S.lastHitAt then S.lastHitAt = nv; onHit() end
    end)
end

local function attachHP(h)
    S.lastHP = h.Health
    h.HealthChanged:Connect(function(hp)
        local d = S.lastHP - hp; S.lastHP = hp
        if d >= (Cfg.get("BlockParry","HP_DROP_MIN") or 0.5) then onHit() end
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
end

-- ── Preemptív mód ──────────────────────────────────────────────────
task.spawn(function()
    while true do
        local rehold = Cfg.get("BlockParry","PREEMPTIVE_REHOLD") or 0.48
        task.wait(rehold)
        if Cfg.get("BlockParry","enabled") and Cfg.get("BlockParry","PREEMPTIVE") then
            if enemyNear() and canBlock() then
                S.preemptLock = true
                Shared.perform("Block", { phase = "start" })
                S.blocking = true; S.lastBlockAt = tick()
            else
                if S.preemptLock then
                    S.preemptLock = false
                    Shared.perform("Block", { phase = "stop" })
                    S.blocking = false
                end
            end
        else
            if S.preemptLock then
                S.preemptLock = false
                Shared.perform("Block", { phase = "stop" })
                S.blocking = false
            end
        end
    end
end)

-- ── Karakter újratöltés ────────────────────────────────────────────
Shared.getLP().CharacterAdded:Connect(function(c)
    S.blocking = false; S.lastBlockAt = 0; S.lastHitAt = 0
    S.lastHP = math.huge; S.lastStepAt = 0; lastTrig = 0; S.preemptLock = false
    attachLastHit(c)
    attachHP(c:WaitForChild("Humanoid"))
end)

local char = Shared.getLP().Character or Shared.getLP().CharacterAdded:Wait()
attachLastHit(char)
attachHP(char:WaitForChild("Humanoid"))

-- ── Publikus API ───────────────────────────────────────────────────
local Module = {}
function Module.getStats()
    return {
        enabled    = Cfg.get("BlockParry","enabled"),
        blocking   = S.blocking,
        totalBlock = S.totalBlock,
        totalParry = S.totalParry,
    }
end

print("[AutoBlockParry] ✓")
_G._AIO_Modules = _G._AIO_Modules or {}
_G._AIO_Modules["BlockParry"] = Module
return Module
