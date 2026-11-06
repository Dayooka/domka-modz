-- ═══════════════════════════════════════════════════════════════
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
local LockOn            = require(ReplicatedStorage.Modules.LockOn)
local Remotes           = require(ReplicatedStorage.Modules.Remotes)

local LocalPlayer = Players.LocalPlayer

-- ┌──────────────────────────────────────────────────────────────┐
-- │  KONFIGURÁCIÓ                                                │
-- └──────────────────────────────────────────────────────────────┘
local CFG = {
    ENABLED           = true,   -- _G.KillAuraCFG.ENABLED = false → ki

    RANGE             = 24,
    CHASE_RANGE       = 50,
    MAX_TARGETS       = 10,
    BURST_DELAY       = 0.004,
    MULTIPLY          = 2,
    MULT_DELAY        = 0.006,

    -- "nearest" | "lowest_hp" | "mixed"
    TARGET_PRIORITY   = "nearest",

    ATTACK_PLAYERS    = false,

    -- Knockdown/execution
    -- Az NPC-t knockoltnak tekintjük ha:
    --   ActionState.isDowned(npc) → ToggleRagdoll = true
    --   VAGY hp <= EXEC_THRESHOLD
    EXEC_THRESHOLD    = 0.15,
    EXEC_HOLD         = 0.3,
    EXEC_CD           = 2.5,

    BEHIND_OFFSET     = 2.5,
    BEHIND_RATE       = 0.08,

    UNDERGROUND_DEPTH = 10,
    UNDERGROUND_ENABLED = true,

    FREEZE_ENABLED    = true,
}

_G.KillAuraCFG = CFG

-- ┌──────────────────────────────────────────────────────────────┐
-- │  MODULE POISONING                                            │
-- └──────────────────────────────────────────────────────────────┘
local function poisonModules()
    if ActionConfig.LightAttack then ActionConfig.LightAttack.blockedBy = {} end
    if ActionConfig.HeavyAttack then ActionConfig.HeavyAttack.blockedBy = {} end
    if ActionConfig.Grab        then ActionConfig.Grab.blockedBy        = {} end
    CombatPublic.meleeApproachStop = function() return 0.1 end
    CombatPublic.meleeLungeTravel  = function(dist) return dist - 0.1 end
    print("[POISON] OK")
end
poisonModules()

-- ┌──────────────────────────────────────────────────────────────┐
-- │  LOCKON                                                      │
-- └──────────────────────────────────────────────────────────────┘
local currentLock = nil
local function setLockOn(t)
    if currentLock == t then return end
    currentLock = t
    pcall(function() LockOn.setLockTarget(t) end)
    pcall(function() Remotes.SetLockOnTarget:FireServer(t) end)
end
local function clearLockOn()
    if not currentLock then return end
    currentLock = nil
    pcall(function() LockOn.setLockTarget(nil) end)
    pcall(function() Remotes.SetLockOnTarget:FireServer(nil) end)
end

-- ┌──────────────────────────────────────────────────────────────┐
-- │  __namecall HOOK                                             │
-- └──────────────────────────────────────────────────────────────┘
local SPOOF      = { AttackCooldown=true, Swinging=true, HeavyCooldown=true }
local hookedRE   = Remotes.PerformAction
local bypass     = false
local oldNC

oldNC = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local m    = getnamecallmethod()
    local char = LocalPlayer.Character

    if m == "GetAttribute" and char and self == char then
        if SPOOF[select(1,...)] then return nil end
    end
    if m == "SetAttribute" and char and self == char then
        if SPOOF[select(1,...)] then return end
    end
    if m == "FireServer" and self == hookedRE and not bypass then
        local action, params = select(1,...), select(2,...)
        if action == "LightAttack" and type(params) == "table" then
            local p = params
            for i = 1, CFG.MULTIPLY do
                task.delay(i * CFG.MULT_DELAY, function()
                    bypass = true
                    pcall(function() hookedRE:FireServer(action, p) end)
                    bypass = false
                end)
            end
        end
    end
    return oldNC(self, ...)
end))

-- ┌──────────────────────────────────────────────────────────────┐
-- │  firesignal FLUSH                                            │
-- └──────────────────────────────────────────────────────────────┘
local lastFlush = 0
local function forceFlush(char)
    if not firesignal then return end
    local now = os.clock()
    if now - lastFlush < 0.05 then return end
    lastFlush = now
    pcall(function() firesignal(char:GetAttributeChangedSignal("AttackCooldown")) end)
end

-- ┌──────────────────────────────────────────────────────────────┐
-- │  NPC FÁZIS (state machine)                                   │
-- │                                                              │
-- │  "attack"  → normál ütés loop                               │
-- │  "execute" → knockolt/low hp → STOP ütés, Grab              │
-- │  "dead"    → eltávolítva → cleanup                          │
-- └──────────────────────────────────────────────────────────────┘
local function getNPCPhase(npc, hum)
    if not npc.Parent then return "dead" end
    if hum.Health <= 0 then
        -- HP 0 de parent még létezik → lehet hogy kliens desync
        -- Csak akkor dead ha parent is nil (szerver eltávolította)
        -- Különben maradjon "execute" fázisban
        return "execute"
    end
    -- isDowned = ToggleRagdoll = true → knockolt
    if ActionState.isDowned(npc) then return "execute" end
    -- Alacsony hp → execute fázis
    local hpPct = hum.Health / math.max(hum.MaxHealth, 1)
    if hpPct <= CFG.EXEC_THRESHOLD then return "execute" end
    return "attack"
end

-- ┌──────────────────────────────────────────────────────────────┐
-- │  TARGET KERESÉS                                              │
-- └──────────────────────────────────────────────────────────────┘
local tracked = {}

local function getTargets(hrp)
    local r, seen = {}, {}

    local function tryAdd(model, isPlayer)
        if seen[model] then return end
        seen[model] = true
        if not model:IsA("Model") or not model:IsDescendantOf(workspace) then return end
        local hum  = model:FindFirstChildOfClass("Humanoid")
        local root = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso")
        if not (hum and root and model.Parent) then return end
        -- HP 0 ÉS parent nil → tényleg halott
        if hum.Health <= 0 and not model.Parent then return end

        local d       = (root.Position - hrp.Position).Magnitude
        local maxDist = tracked[model] and CFG.CHASE_RANGE or CFG.RANGE
        if d > maxDist then tracked[model] = nil ; return end

        tracked[model] = true
        table.insert(r, { npc=model, root=root, hum=hum, dist=d, isPlayer=isPlayer })
    end

    for _, n in CollectionService:GetTagged(Entities.Tag.NPC) do tryAdd(n, false) end
    local f = workspace:FindFirstChild("NPCs")
    if f then for _, n in f:GetChildren() do tryAdd(n, false) end end
    if CFG.ATTACK_PLAYERS then
        for _, pl in Players:GetPlayers() do
            if pl ~= LocalPlayer and pl.Character then tryAdd(pl.Character, true) end
        end
    end

    if CFG.TARGET_PRIORITY == "lowest_hp" then
        table.sort(r, function(a, b) return a.hum.Health < b.hum.Health end)
    elseif CFG.TARGET_PRIORITY == "mixed" then
        table.sort(r, function(a, b)
            local sA = (a.hum.Health / math.max(a.hum.MaxHealth,1)) * 20 + a.dist
            local sB = (b.hum.Health / math.max(b.hum.MaxHealth,1)) * 20 + b.dist
            return sA < sB
        end)
    else
        table.sort(r, function(a, b) return a.dist < b.dist end)
    end
    return r
end

-- ┌──────────────────────────────────────────────────────────────┐
-- │  FREEZE                                                      │
-- └──────────────────────────────────────────────────────────────┘
local frozen = {}

local function freezeNPC(npc)
    if not CFG.FREEZE_ENABLED or frozen[npc] then return end
    frozen[npc] = true
    local hum  = npc:FindFirstChildOfClass("Humanoid")
    local root = npc:FindFirstChild("HumanoidRootPart")
    if hum then pcall(function()
        hum.WalkSpeed = 0 ; hum.JumpPower = 0
        hum.JumpHeight = 0 ; hum.PlatformStand = true
    end) end
    if root then pcall(function()
        root.AssemblyLinearVelocity  = Vector3.new(0, math.min(root.AssemblyLinearVelocity.Y, 0), 0)
        root.AssemblyAngularVelocity = Vector3.zero
    end) end
end

local function unfreezeNPC(npc)
    if not frozen[npc] then return end
    frozen[npc] = nil
    local hum = npc:FindFirstChildOfClass("Humanoid")
    if hum then pcall(function()
        hum.WalkSpeed = 16 ; hum.JumpPower = 50
        hum.JumpHeight = 7.2 ; hum.PlatformStand = false
    end) end
end

RunService.Heartbeat:Connect(function()
    if not CFG.FREEZE_ENABLED then return end
    for npc in frozen do
        if not npc.Parent then frozen[npc] = nil ; continue end
        local hum  = npc:FindFirstChildOfClass("Humanoid")
        local root = npc:FindFirstChild("HumanoidRootPart")
        if not hum or not root then continue end
        pcall(function()
            hum.WalkSpeed = 0 ; hum.PlatformStand = true
            root.AssemblyLinearVelocity = Vector3.new(
                0, math.min(root.AssemblyLinearVelocity.Y, 0), 0)
        end)
    end
end)

-- ┌──────────────────────────────────────────────────────────────┐
-- │  VALIDÁCIÓ                                                   │
-- └──────────────────────────────────────────────────────────────┘
local function canFire(char)
    if ActionState.isDowned(char)     then return false end
    if ActionState.isChanneling(char) then return false end
    return true
end

local function shouldGoUnderground(char)
    if not CFG.UNDERGROUND_ENABLED then return false end
    if ActionState.isIncapacitated(char) then return true end
    if ActionState.thrownLocked(char)    then return true end
    if ActionState.inStepIFrames(char)   then return true end
    if ActionState.isPinned(char)        then return true end
    return false
end

-- ┌──────────────────────────────────────────────────────────────┐
-- │  POZÍCIÓ                                                     │
-- └──────────────────────────────────────────────────────────────┘
local posState = { underground=false, surfaceY=nil, lastBehind=0 }

local function goUnderground(hrp)
    if posState.underground then return end
    posState.underground = true
    posState.surfaceY    = hrp.Position.Y
    hrp.CFrame = hrp.CFrame + Vector3.new(0, -CFG.UNDERGROUND_DEPTH, 0)
end

local function maintainUnderground(hrp)
    if not posState.surfaceY then return end
    local want = posState.surfaceY - CFG.UNDERGROUND_DEPTH
    if math.abs(hrp.Position.Y - want) > 2 then
        hrp.CFrame = hrp.CFrame + Vector3.new(0, want - hrp.Position.Y, 0)
    end
end

local function returnToSurface(hrp)
    if not posState.underground then return end
    posState.underground = false
    if posState.surfaceY then
        hrp.CFrame = hrp.CFrame + Vector3.new(0, posState.surfaceY - hrp.Position.Y, 0)
        posState.surfaceY = nil
    end
end

local function teleportBehind(hrp, npcRoot)
    local now = os.clock()
    if now - posState.lastBehind < CFG.BEHIND_RATE then return end
    posState.lastBehind = now
    local behind = npcRoot.Position - npcRoot.CFrame.LookVector * CFG.BEHIND_OFFSET
    behind = Vector3.new(behind.X, npcRoot.Position.Y, behind.Z)
    local rc = RaycastParams.new()
    rc.FilterType = Enum.RaycastFilterType.Exclude
    rc.FilterDescendantsInstances = {LocalPlayer.Character}
    rc.IgnoreWater = true
    local d = behind - npcRoot.Position
    if d.Magnitude > 0.1 and workspace:Raycast(npcRoot.Position, d, rc) then return end
    hrp.CFrame = CFrame.lookAt(behind, npcRoot.Position)
end

-- ┌──────────────────────────────────────────────────────────────┐
-- │  CFRAME                                                      │
-- └──────────────────────────────────────────────────────────────┘
local function computeCF(char, hrp, npc, root)
    if char:GetAttribute("InClash") or char:GetAttribute("Pinned") then return hrp.CFrame end
    if npc:GetAttribute("InSafeZone") then return hrp.CFrame end
    if ActionState.isUntrackable and ActionState.isUntrackable(npc) then return hrp.CFrame end

    local delta = root.Position - hrp.Position
    local dist  = delta.Magnitude
    if dist < 0.01 then return hrp.CFrame end

    local myS  = CombatPublic.bodyScale and CombatPublic.bodyScale(char) or 1
    local tS   = CombatPublic.bodyScale and CombatPublic.bodyScale(npc)  or 1
    local stop = CombatPublic.meleeApproachStop(myS, tS)
    local maxD = CombatPublic.MELEE_APPROACH_MAX

    if dist <= stop or dist > maxD then
        local flat = Vector3.new(root.Position.X, hrp.Position.Y, root.Position.Z)
        return (flat - hrp.Position).Magnitude > 0.01
            and CFrame.lookAt(hrp.Position, flat) or hrp.CFrame
    end

    local rc = RaycastParams.new()
    rc.FilterType = Enum.RaycastFilterType.Exclude
    rc.FilterDescendantsInstances = {char, npc}
    rc.IgnoreWater = true
    local unit   = delta.Unit
    local travel = CombatPublic.meleeLungeTravel(dist, stop)
    local hit    = workspace:Raycast(hrp.Position, unit * travel, rc)
    local actual = hit and math.max(0,(hit.Position-hrp.Position).Magnitude-2) or travel
    if actual <= 0.1 then return hrp.CFrame end
    return CFrame.lookAt(hrp.Position + unit * actual, root.Position)
end

local function syncCombo(char)
    local ok, s = pcall(CombatStylePublic.of, char)
    if ok and s and s.lights then
        local _ = (char:GetAttribute("AttackSequence") or 0) % #s.lights + 1
    end
end

-- ┌──────────────────────────────────────────────────────────────┐
-- │  GRAB EXECUTION                                              │
-- └──────────────────────────────────────────────────────────────┘
local execState = {}
-- [npc] = { grabbing=bool, lastExec=number }

local function tryExec(char, hrp, npc, root)
    local st = execState[npc]
    if not st then
        execState[npc] = { grabbing=false, lastExec=0 }
        st = execState[npc]
    end
    if st.grabbing then return end
    local now = os.clock()
    if now - st.lastExec < CFG.EXEC_CD then return end
    if ActionState.isIncapacitated(char) then return end
    if char:GetAttribute("Grabbing") then return end
    if not npc.Parent then return end

    st.grabbing = true
    st.lastExec = now

    setLockOn(npc)

    -- Mögé teleport mielőtt grab-elünk
    local behind = root.Position - root.CFrame.LookVector * CFG.BEHIND_OFFSET
    behind = Vector3.new(behind.X, root.Position.Y, behind.Z)
    hrp.CFrame = CFrame.lookAt(behind, root.Position)

    task.wait(0.05)

    if not npc.Parent or not LocalPlayer.Character then
        st.grabbing = false ; return
    end

    Remotes.PerformAction:FireServer("Grab", {
        phase  = "start",
        cframe = CFrame.lookAt(hrp.Position, root.Position),
    })

    task.delay(CFG.EXEC_HOLD, function()
        if LocalPlayer.Character == char then
            Remotes.PerformAction:FireServer("Grab", { phase = "stop" })
        end
        st.grabbing = false
    end)
end

-- ┌──────────────────────────────────────────────────────────────┐
-- │  KARAKTER SETUP                                              │
-- └──────────────────────────────────────────────────────────────┘
local attrConn = nil

local function setupChar(char)
    for npc in frozen do unfreezeNPC(npc) end
    frozen     = {}
    tracked    = {}
    execState  = {}
    posState   = { underground=false, surfaceY=nil, lastBehind=0 }
    currentLock = nil

    if attrConn then attrConn:Disconnect() end
    attrConn = char.AttributeChanged:Connect(function()
        if not char:GetAttribute("Grabbing") then
            for _, st in execState do st.grabbing = false end
        end
    end)
end

-- ┌──────────────────────────────────────────────────────────────┐
-- │  FŐ LOOP                                                     │
-- └──────────────────────────────────────────────────────────────┘
local cleanTimer = 0

RunService.Heartbeat:Connect(function(dt)
    if not CFG.ENABLED then return end

    local char = LocalPlayer.Character
    if not char then return end
    local hrp  = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local hum  = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end

    forceFlush(char)

    -- Underground (csak ha mi vagyunk incapacitated)
    if shouldGoUnderground(char) then
        if not posState.underground then goUnderground(hrp) end
        maintainUnderground(hrp)
        return
    elseif posState.underground then
        returnToSurface(hrp)
    end

    -- Cleanup halott NPC state-ek
    cleanTimer += dt
    if cleanTimer >= 3 then
        cleanTimer = 0
        for npc in execState do
            if not npc.Parent then
                execState[npc] = nil
                tracked[npc]   = nil
                unfreezeNPC(npc)
                if currentLock == npc then clearLockOn() end
            end
        end
        for npc in frozen do
            if not npc.Parent then unfreezeNPC(npc) end
        end
    end

    if not canFire(char) then return end

    local targets = getTargets(hrp)
    if #targets == 0 then
        if currentLock then clearLockOn() end
        return
    end
    if #targets > CFG.MAX_TARGETS then
        local t = {} ; for i=1,CFG.MAX_TARGETS do t[i]=targets[i] end ; targets=t
    end

    -- Lock-on elsődleges célpontra
    setLockOn(targets[1].npc)

    -- Attack/execute listák szétválasztva
    local toAttack  = {}
    local toExecute = {}

    for _, e in targets do
        if not e.npc.Parent then continue end
        local phase = getNPCPhase(e.npc, e.hum)

        if phase == "dead" then
            -- Szerver eltávolította → cleanup
            execState[e.npc] = nil
            tracked[e.npc]   = nil
            unfreezeNPC(e.npc)
            if currentLock == e.npc then clearLockOn() end

        elseif phase == "execute" then
            -- Knockolt / low hp → execute listába
            table.insert(toExecute, e)
            freezeNPC(e.npc)

        else -- "attack"
            table.insert(toAttack, e)
            freezeNPC(e.npc)
        end
    end

    -- ── EXECUTE fázis ──────────────────────────────────────────
    -- Az execute-ot az attack ELŐTT kezeljük, hogy ne küldjünk
    -- LightAttack-et knockolt NPC-re
    for _, e in toExecute do
        tryExec(char, hrp, e.npc, e.root)
    end

    -- ── ATTACK fázis ───────────────────────────────────────────
    if #toAttack > 0 then
        -- Mögé teleport az elsőhöz
        teleportBehind(hrp, toAttack[1].root)

        for i, e in toAttack do
            local st = execState[e.npc]
            -- Ne támadj ha éppen grab folyamatban van erre az NPC-re
            if st and st.grabbing then continue end

            local pkt = {
                phase  = "start",
                cframe = computeCF(char, hrp, e.npc, e.root),
            }
            if i == 1 then
                Remotes.PerformAction:FireServer("LightAttack", pkt)
            else
                local d, n, r = (i-1)*CFG.BURST_DELAY, e.npc, e.root
                task.delay(d, function()
                    if n.Parent and LocalPlayer.Character == char then
                        Remotes.PerformAction:FireServer("LightAttack", {
                            phase  = "start",
                            cframe = computeCF(char, hrp, n, r),
                        })
                    end
                end)
            end
        end
        syncCombo(char)
    end
end)

LocalPlayer.CharacterAdded:Connect(setupChar)
LocalPlayer.CharacterRemoving:Connect(function()
    for npc in frozen do unfreezeNPC(npc) end
    frozen = {} ; tracked = {} ; execState = {}
    if attrConn then attrConn:Disconnect() ; attrConn = nil end
end)

if LocalPlayer.Character then setupChar(LocalPlayer.Character) end
print("[KillAura v9] Betöltve | _G.KillAuraCFG.ENABLED")
