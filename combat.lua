-- KillAuraController – CLEAN v4
-- Upvalue réteg eltávolítva (executor nem támogatja)
-- Minden más réteg megmarad és működik

local Players           = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local ActionConfig      = require(ReplicatedStorage.Modules.ActionConfig)
local ActionState       = require(ReplicatedStorage.Modules.ActionState)
local CombatMovement    = require(ReplicatedStorage.Modules.CombatMovement)
local CombatPublic      = require(ReplicatedStorage.Modules.CombatPublic)
local CombatStylePublic = require(ReplicatedStorage.Modules.CombatStylePublic)
local Entities          = require(ReplicatedStorage.Modules.Entities)
local Remotes           = require(ReplicatedStorage.Modules.Remotes)

local LocalPlayer = Players.LocalPlayer

local CFG = {
    RANGE             = 25,
    MAX_TARGETS       = 10,
    BURST_DELAY       = 0.004,
    MULTIPLY          = 2,
    MULT_DELAY        = 0.006,
    EXEC_THRESHOLD    = 0.15,
    EXEC_HOLD         = 0.3,
    EXEC_CD           = 2.0,
    DIRECT_DMG        = 20,
    DIRECT_RATE       = 0.08,
    BEHIND_OFFSET     = 2.5,
    BEHIND_RATE       = 0.08,
    UNDERGROUND_DEPTH = 12,
}

-- ┌─────────────────────────────────────────────────────────────┐
-- │  RÉTEG 0 – MODULE POISONING                                 │
-- │  Shared table → CombatClient is látja a módosítást          │
-- └─────────────────────────────────────────────────────────────┘
local function poisonModules()
    if ActionConfig.LightAttack then ActionConfig.LightAttack.blockedBy = {} end
    if ActionConfig.HeavyAttack then ActionConfig.HeavyAttack.blockedBy = {} end
    if ActionConfig.Grab        then ActionConfig.Grab.blockedBy        = {} end

    CombatPublic.MELEE_APPROACH_MAX = 60
    CombatPublic.meleeApproachStop  = function() return 0.1 end
    CombatPublic.meleeLungeTravel   = function(dist) return dist - 0.1 end

    print("[POISON] Modulok módosítva")
end
poisonModules()

-- ┌─────────────────────────────────────────────────────────────┐
-- │  RÉTEG 1 – __namecall HOOK                                  │
-- │  A) GetAttribute spoof                                      │
-- │  B) SetAttribute blokkolás                                  │
-- │  C) FireServer szorzás (hookBypass guard-dal)               │
-- └─────────────────────────────────────────────────────────────┘
local GET_SPOOF    = { AttackCooldown=true, Swinging=true, HeavyCooldown=true }
local hookedRemote = Remotes.PerformAction
local hookBypass   = false
local oldNamecall

oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local char   = LocalPlayer.Character

    if method == "GetAttribute" and char and self == char then
        if GET_SPOOF[select(1,...)] then return nil end
    end

    if method == "SetAttribute" and char and self == char then
        if GET_SPOOF[select(1,...)] then return end
    end

    if method == "FireServer" and self == hookedRemote and not hookBypass then
        local action = select(1,...)
        local params = select(2,...)
        if action == "LightAttack" and type(params) == "table" then
            local p = params
            for i = 1, CFG.MULTIPLY do
                task.delay(i * CFG.MULT_DELAY, function()
                    hookBypass = true
                    pcall(function() hookedRemote:FireServer(action, p) end)
                    hookBypass = false
                end)
            end
        end
    end

    return oldNamecall(self, ...)
end))

-- ┌─────────────────────────────────────────────────────────────┐
-- │  RÉTEG 2 – firesignal FLUSH                                 │
-- │  AttributeChangedSignal("AttackCooldown") → CombatClient    │
-- │  flushCombatIntent()-je lefut saját magától                 │
-- └─────────────────────────────────────────────────────────────┘
local lastSigFlush = 0
local function forceFlush(char)
    if not firesignal then return end
    local now = os.clock()
    if now - lastSigFlush < 0.05 then return end
    lastSigFlush = now
    pcall(function()
        firesignal(char:GetAttributeChangedSignal("AttackCooldown"))
    end)
end

-- ┌─────────────────────────────────────────────────────────────┐
-- │  POZÍCIÓ MANAGER                                            │
-- └─────────────────────────────────────────────────────────────┘
local posState = { underground=false, surfaceY=nil, lastBehind=0 }

local function maintainUnderground(hrp)
    if not posState.underground or not posState.surfaceY then return end
    hrp.CFrame = CFrame.new(
        hrp.Position.X,
        posState.surfaceY - CFG.UNDERGROUND_DEPTH,
        hrp.Position.Z
    ) * (hrp.CFrame - hrp.CFrame.Position)
end

local function goUnderground(hrp)
    if posState.underground then return end
    posState.underground = true
    posState.surfaceY    = hrp.Position.Y
end

local function returnToSurface(hrp)
    if not posState.underground then return end
    posState.underground = false
    if posState.surfaceY then
        hrp.CFrame = CFrame.new(
            hrp.Position.X, posState.surfaceY, hrp.Position.Z
        ) * (hrp.CFrame - hrp.CFrame.Position)
        posState.surfaceY = nil
    end
end

local function teleportBehind(hrp, npcRoot)
    local now = os.clock()
    if now - posState.lastBehind < CFG.BEHIND_RATE then return end
    posState.lastBehind = now
    local behind = npcRoot.Position - npcRoot.CFrame.LookVector * CFG.BEHIND_OFFSET
    local rc = RaycastParams.new()
    rc.FilterType = Enum.RaycastFilterType.Exclude
    rc.FilterDescendantsInstances = {LocalPlayer.Character}
    rc.IgnoreWater = true
    if workspace:Raycast(npcRoot.Position, behind - npcRoot.Position, rc) then return end
    hrp.CFrame = CFrame.lookAt(behind, npcRoot.Position)
end

local UGND = {"Grabbed","Stunned","Ragdolled","Imprisoned","Pinned","KnockedDown"}
local function shouldGoUnderground(char)
    for _, a in UGND do
        if char:GetAttribute(a) then return true end
    end
    return false
end

-- ┌─────────────────────────────────────────────────────────────┐
-- │  COMBAT RENDSZER                                            │
-- └─────────────────────────────────────────────────────────────┘
local npcState   = {}
local lastDirDmg = {}
local attrConn   = nil

local function computeCFrame(char, hrp, npc, npcRoot)
    local delta = npcRoot.Position - hrp.Position
    local dist  = delta.Magnitude
    if dist < 0.01 then return hrp.CFrame end

    local myS  = CombatPublic.bodyScale and CombatPublic.bodyScale(char) or 1
    local tS   = CombatPublic.bodyScale and CombatPublic.bodyScale(npc)  or 1
    local stop = CombatPublic.meleeApproachStop(myS, tS)
    local maxD = CombatPublic.MELEE_APPROACH_MAX

    if dist <= stop or dist > maxD then
        local flat = Vector3.new(npcRoot.Position.X, hrp.Position.Y, npcRoot.Position.Z)
        return (flat - hrp.Position).Magnitude > 0.01
            and CFrame.lookAt(hrp.Position, flat)
            or  hrp.CFrame
    end

    local rc = RaycastParams.new()
    rc.FilterType = Enum.RaycastFilterType.Exclude
    rc.FilterDescendantsInstances = {char, npc}
    rc.IgnoreWater = true
    local unit   = delta.Unit
    local travel = CombatPublic.meleeLungeTravel(dist, stop)
    local hit    = workspace:Raycast(hrp.Position, unit * travel, rc)
    local actual = hit
               and math.max(0, (hit.Position - hrp.Position).Magnitude - 2)
               or  travel
    if actual <= 0.1 then return hrp.CFrame end
    return CFrame.lookAt(hrp.Position + unit * actual, npcRoot.Position)
end

local function getNPCsInRange(hrp)
    local r = {}
    for _, npc in CollectionService:GetTagged(Entities.Tag.NPC) do
        if npc:IsA("Model") and npc:IsDescendantOf(workspace) then
            local hum  = npc:FindFirstChildOfClass("Humanoid")
            local root = npc:FindFirstChild("HumanoidRootPart")
                      or npc:FindFirstChild("Torso")
            if hum and hum.Health > 0 and root then
                local d = (root.Position - hrp.Position).Magnitude
                if d <= CFG.RANGE then
                    table.insert(r, {npc=npc, root=root, hum=hum, dist=d})
                end
            end
        end
    end
    table.sort(r, function(a,b) return a.dist < b.dist end)
    return r
end

local function canFire(char)
    if ActionState.isDowned(char)     then return false end
    if ActionState.isChanneling(char) then return false end
    return true
end

local function tryDirDmg(npc, hum, now)
    local last = lastDirDmg[npc] or 0
    if now - last < CFG.DIRECT_RATE then return end
    lastDirDmg[npc] = now
    pcall(function() hum:TakeDamage(CFG.DIRECT_DMG) end)
end

local function execGrab(char, hrp, npc, npcRoot, st)
    if st.executing then return end
    local now = os.clock()
    if now - (st.lastExec or 0) < CFG.EXEC_CD then return end
    if char:GetAttribute("Grabbed") or char:GetAttribute("Grabbing") then return end
    st.executing = true
    st.lastExec  = now
    Remotes.PerformAction:FireServer("Grab", {
        phase  = "start",
        cframe = computeCFrame(char, hrp, npc, npcRoot),
    })
    task.delay(CFG.EXEC_HOLD, function()
        if LocalPlayer.Character == char then
            Remotes.PerformAction:FireServer("Grab", {phase="stop"})
        end
        st.executing = false
    end)
end

local function watchHP(char, hrp, npc, npcRoot)
    local st = npcState[npc]
    if not st or st.hpConn then return end
    local hum = npc:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    st.hpConn = hum.HealthChanged:Connect(function(hp)
        if hp <= 0 then
            if st.hpConn then st.hpConn:Disconnect() end
            npcState[npc] = nil ; lastDirDmg[npc] = nil
            return
        end
        if hp / hum.MaxHealth <= CFG.EXEC_THRESHOLD then
            local c = LocalPlayer.Character
            local h = c and c:FindFirstChild("HumanoidRootPart")
            if h and (npcRoot.Position - h.Position).Magnitude <= CFG.RANGE then
                execGrab(c, h, npc, npcRoot, st)
            end
        end
    end)
end

local function fireAll(char, hrp, targets, now)
    for i, e in targets do
        local st = npcState[e.npc]
        if not st or st.executing then continue end
        tryDirDmg(e.npc, e.hum, now)
        local pkt = {
            phase  = "start",
            cframe = computeCFrame(char, hrp, e.npc, e.root),
        }
        if i == 1 then
            Remotes.PerformAction:FireServer("LightAttack", pkt)
        else
            local d, n, r = (i-1)*CFG.BURST_DELAY, e.npc, e.root
            task.delay(d, function()
                if n.Parent and LocalPlayer.Character == char then
                    Remotes.PerformAction:FireServer("LightAttack", {
                        phase  = "start",
                        cframe = computeCFrame(char, hrp, n, r),
                    })
                end
            end)
        end
    end
end

local function ensureState(npc)
    if not npcState[npc] then
        npcState[npc] = {executing=false, lastExec=0, hpConn=nil}
    end
    return npcState[npc]
end

local function cleanup()
    for npc, st in npcState do
        if not npc.Parent then
            if st.hpConn then st.hpConn:Disconnect() end
            npcState[npc] = nil ; lastDirDmg[npc] = nil
        end
    end
end

local function setupChar(char)
    for _, st in npcState do
        if st.hpConn then st.hpConn:Disconnect() end
    end
    npcState = {} ; lastDirDmg = {}
    posState = {underground=false, surfaceY=nil, lastBehind=0}
    if attrConn then attrConn:Disconnect() end
    attrConn = char.AttributeChanged:Connect(function()
        if not char:GetAttribute("Grabbing") then
            for _, st in npcState do st.executing = false end
        end
    end)
end

local cleanTimer = 0
RunService.Heartbeat:Connect(function(dt)
    local char = LocalPlayer.Character
    if not char then return end
    local hrp  = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local hum  = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end

    forceFlush(char)

    if shouldGoUnderground(char) then
        goUnderground(hrp)
        maintainUnderground(hrp)
        return
    elseif posState.underground then
        returnToSurface(hrp)
    end

    cleanTimer += dt
    if cleanTimer >= 3 then cleanTimer = 0 ; cleanup() end

    if not canFire(char) then return end

    local now     = os.clock()
    local targets = getNPCsInRange(hrp)
    if #targets == 0 then return end

    if #targets > CFG.MAX_TARGETS then
        local t = {}
        for i = 1, CFG.MAX_TARGETS do t[i] = targets[i] end
        targets = t
    end

    for _, e in targets do
        local st = ensureState(e.npc)
        watchHP(char, hrp, e.npc, e.root)
        if e.hum.Health/e.hum.MaxHealth <= CFG.EXEC_THRESHOLD
        and not st.executing then
            execGrab(char, hrp, e.npc, e.root, st)
        end
    end

    if targets[1] then teleportBehind(hrp, targets[1].root) end
    fireAll(char, hrp, targets, now)
end)

LocalPlayer.CharacterAdded:Connect(setupChar)
LocalPlayer.CharacterRemoving:Connect(function()
    for _, st in npcState do
        if st.hpConn then st.hpConn:Disconnect() end
    end
    npcState = {} ; lastDirDmg = {}
    if attrConn then attrConn:Disconnect() ; attrConn = nil end
end)

if LocalPlayer.Character then setupChar(LocalPlayer.Character) end
