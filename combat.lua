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
-- │  _G.KillAuraCFG = CFG → külső GUI scriptből elérhető        │
-- └──────────────────────────────────────────────────────────────┘
local CFG = {
    -- ── Fő kapcsoló ───────────────────────────────────────────
    ENABLED           = true,   -- GUI: _G.KillAuraCFG.ENABLED = false

    -- ── Aura ──────────────────────────────────────────────────
    RANGE             = 24,     -- normál hatótáv (studs)
    CHASE_RANGE       = 50,     -- knockback után követési táv
    MAX_TARGETS       = 10,
    BURST_DELAY       = 0.004,
    MULTIPLY          = 2,      -- packet szorzás
    MULT_DELAY        = 0.006,

    -- ── Célpont prioritás ─────────────────────────────────────
    -- "nearest"   → legközelebb lévő először
    -- "lowest_hp" → legkevesebb HP-val rendelkező először
    -- "mixed"     → HP + távolság kombinálva
    TARGET_PRIORITY   = "nearest",

    -- ── Player targeting ──────────────────────────────────────
    ATTACK_PLAYERS    = false,

    -- ── Execution (Grab) ──────────────────────────────────────
    EXEC_THRESHOLD    = 0.15,   -- HP% alatt grab (is_knocked_out is triggerel)
    EXEC_HOLD         = 0.3,    -- grab hold time (dok: Grab.minInterval = 0.3)
    EXEC_CD           = 2.0,    -- újra-grab cooldown

    -- ── Pozíció ───────────────────────────────────────────────
    BEHIND_OFFSET     = 2.5,    -- studs mögötte
    BEHIND_RATE       = 0.03,   -- mögé teleport frekvencia (s)
    BEHIND_ON_ATTACK  = true,   -- minden attack után azonnal mögé

    -- ── Underground ───────────────────────────────────────────
    UNDERGROUND_DEPTH = 10,     -- studs mélység (csökkentve: kevésbé bugos)
    UNDERGROUND_ENABLED = true, -- föld alá bújás engedélyezése

    -- ── Freeze ────────────────────────────────────────────────
    FREEZE_ENABLED    = true,   -- NPC-k mozgásának letiltása
}

-- GUI-ból elérhető globális referencia
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
    print("[POISON] Modulok módosítva")
end
poisonModules()

-- ┌──────────────────────────────────────────────────────────────┐
-- │  LOCKON                                                      │
-- └──────────────────────────────────────────────────────────────┘
local currentLockTarget = nil

local function setLockOn(target)
    if currentLockTarget == target then return end
    currentLockTarget = target
    pcall(function() LockOn.setLockTarget(target) end)
    pcall(function() Remotes.SetLockOnTarget:FireServer(target) end)
end

local function clearLockOn()
    if not currentLockTarget then return end
    currentLockTarget = nil
    pcall(function() LockOn.setLockTarget(nil) end)
    pcall(function() Remotes.SetLockOnTarget:FireServer(nil) end)
end

-- ┌──────────────────────────────────────────────────────────────┐
-- │  __namecall HOOK                                             │
-- └──────────────────────────────────────────────────────────────┘
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
        local action = select(1,...) ; local params = select(2,...)
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

-- ┌──────────────────────────────────────────────────────────────┐
-- │  firesignal FLUSH                                            │
-- └──────────────────────────────────────────────────────────────┘
local lastSigFlush = 0
local function forceFlush(char)
    if not firesignal then return end
    local now = os.clock()
    if now - lastSigFlush < 0.05 then return end
    lastSigFlush = now
    pcall(function() firesignal(char:GetAttributeChangedSignal("AttackCooldown")) end)
end

-- ┌──────────────────────────────────────────────────────────────┐
-- │  NPC / TARGET KERESÉS                                        │
-- └──────────────────────────────────────────────────────────────┘
local trackedTargets = {}

local function getTargetsInRange(hrp)
    local r    = {}
    local seen = {}

    local function tryAdd(model, isPlayer)
        if seen[model] then return end
        seen[model] = true
        if not model:IsA("Model") or not model:IsDescendantOf(workspace) then return end
        local hum  = model:FindFirstChildOfClass("Humanoid")
        local root = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso")
        -- FIX: csak akkor adjuk hozzá ha a szerver is éltnek tartja (parent != nil, HP > 0)
        if not (hum and hum.Health > 0 and root and model.Parent) then return end
        local d = (root.Position - hrp.Position).Magnitude
        local maxRange = trackedTargets[model] and CFG.CHASE_RANGE or CFG.RANGE
        if d <= maxRange then
            table.insert(r, { npc=model, root=root, hum=hum, dist=d, isPlayer=isPlayer })
            trackedTargets[model] = true
        else
            trackedTargets[model] = nil
        end
    end

    for _, npc in CollectionService:GetTagged(Entities.Tag.NPC) do
        tryAdd(npc, false)
    end
    local npcFolder = workspace:FindFirstChild("NPCs")
    if npcFolder then
        for _, npc in npcFolder:GetChildren() do tryAdd(npc, false) end
    end
    if CFG.ATTACK_PLAYERS then
        for _, pl in Players:GetPlayers() do
            if pl ~= LocalPlayer and pl.Character then
                tryAdd(pl.Character, true)
            end
        end
    end

    -- Célpont prioritás rendezés
    if CFG.TARGET_PRIORITY == "lowest_hp" then
        table.sort(r, function(a, b)
            return a.hum.Health < b.hum.Health
        end)
    elseif CFG.TARGET_PRIORITY == "mixed" then
        -- Kombó: normált HP (0-1) * 20 + távolság → kisebb = előbb
        table.sort(r, function(a, b)
            local sA = (a.hum.Health / math.max(a.hum.MaxHealth, 1)) * 20 + a.dist
            local sB = (b.hum.Health / math.max(b.hum.MaxHealth, 1)) * 20 + b.dist
            return sA < sB
        end)
    else -- "nearest" (default)
        table.sort(r, function(a, b) return a.dist < b.dist end)
    end

    return r
end

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
-- │  FREEZE                                                      │
-- └──────────────────────────────────────────────────────────────┘
local frozenTargets = {}

local function freezeTarget(model)
    if not CFG.FREEZE_ENABLED then return end
    frozenTargets[model] = true
    local hum = model:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    pcall(function()
        hum.WalkSpeed     = 0
        hum.JumpPower     = 0
        hum.JumpHeight    = 0
        hum.PlatformStand = true
    end)
    local root = model:FindFirstChild("HumanoidRootPart")
    if root then
        pcall(function()
            root.AssemblyLinearVelocity  = Vector3.new(0, math.min(root.AssemblyLinearVelocity.Y, 0), 0)
            root.AssemblyAngularVelocity = Vector3.zero
        end)
    end
end

local function unfreezeTarget(model)
    frozenTargets[model] = nil
    local hum = model:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    pcall(function()
        hum.WalkSpeed     = 16
        hum.JumpPower     = 50
        hum.JumpHeight    = 7.2
        hum.PlatformStand = false
    end)
end

-- Freeze maintenance Heartbeat
RunService.Heartbeat:Connect(function()
    if not CFG.FREEZE_ENABLED then return end
    for model in frozenTargets do
        if not model.Parent then
            frozenTargets[model] = nil ; continue
        end
        local hum  = model:FindFirstChildOfClass("Humanoid")
        local root = model:FindFirstChild("HumanoidRootPart")
        if not hum or not root then continue end
        pcall(function()
            hum.WalkSpeed     = 0
            hum.PlatformStand = true
            root.AssemblyLinearVelocity = Vector3.new(
                0, math.min(root.AssemblyLinearVelocity.Y, 0), 0
            )
        end)
    end
end)

-- ┌──────────────────────────────────────────────────────────────┐
-- │  POZÍCIÓ MANAGER                                             │
-- │                                                              │
-- │  FIX: Underground – egyszerű Y-only CFrame set,             │
-- │  NEM * rotation trick → nem bugos                           │
-- └──────────────────────────────────────────────────────────────┘
local posState = { underground=false, surfaceY=nil, lastBehind=0 }

local function goUnderground(hrp)
    if posState.underground then return end
    posState.underground = true
    posState.surfaceY    = hrp.Position.Y
    -- FIX: csak Y-t változtatjuk, XZ és rotation érintetlen
    hrp.CFrame = hrp.CFrame + Vector3.new(0, -CFG.UNDERGROUND_DEPTH, 0)
end

local function maintainUnderground(hrp)
    if not posState.underground or not posState.surfaceY then return end
    local targetY = posState.surfaceY - CFG.UNDERGROUND_DEPTH
    -- Csak akkor javítjuk ha elcsúszott
    if math.abs(hrp.Position.Y - targetY) > 1 then
        hrp.CFrame = hrp.CFrame + Vector3.new(0, targetY - hrp.Position.Y, 0)
    end
end

local function returnToSurface(hrp)
    if not posState.underground then return end
    posState.underground = false
    if posState.surfaceY then
        -- Visszateleportálás: Y visszaállítása
        hrp.CFrame = hrp.CFrame + Vector3.new(0, posState.surfaceY - hrp.Position.Y, 0)
        posState.surfaceY = nil
    end
end

local function teleportBehind(hrp, npcRoot, force)
    local now = os.clock()
    if not force and now - posState.lastBehind < CFG.BEHIND_RATE then return end
    posState.lastBehind = now
    -- NPC háta mögötti pozíció
    local behind = npcRoot.Position - npcRoot.CFrame.LookVector * CFG.BEHIND_OFFSET
    -- Ugyanazon Y magasság mint az NPC
    behind = Vector3.new(behind.X, npcRoot.Position.Y, behind.Z)
    -- Akadály ellenőrzés
    local rc = RaycastParams.new()
    rc.FilterType = Enum.RaycastFilterType.Exclude
    rc.FilterDescendantsInstances = {LocalPlayer.Character}
    rc.IgnoreWater = true
    local dir = behind - npcRoot.Position
    if dir.Magnitude > 0.1 and workspace:Raycast(npcRoot.Position, dir, rc) then return end
    -- CFrame.lookAt → felé nézünk az NPC pozíciójából
    hrp.CFrame = CFrame.lookAt(behind, npcRoot.Position)
end

local function chaseTarget(hrp, npcRoot)
    local delta = npcRoot.Position - hrp.Position
    if delta.Magnitude <= CFG.RANGE then return end
    local dest = npcRoot.Position - npcRoot.CFrame.LookVector * CFG.BEHIND_OFFSET
    dest = Vector3.new(dest.X, npcRoot.Position.Y, dest.Z)
    hrp.CFrame = CFrame.lookAt(dest, npcRoot.Position)
end

-- ┌──────────────────────────────────────────────────────────────┐
-- │  CFRAME SZÁMÍTÁS                                             │
-- └──────────────────────────────────────────────────────────────┘
local function computeAttackCFrame(char, hrp, npc, npcRoot)
    if char:GetAttribute("InClash") or char:GetAttribute("Pinned") then return hrp.CFrame end
    if npc:GetAttribute("InSafeZone") then return hrp.CFrame end
    if ActionState.isUntrackable and ActionState.isUntrackable(npc) then return hrp.CFrame end

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
            and CFrame.lookAt(hrp.Position, flat) or hrp.CFrame
    end

    local rc = RaycastParams.new()
    rc.FilterType = Enum.RaycastFilterType.Exclude
    rc.FilterDescendantsInstances = {char, npc}
    rc.IgnoreWater = true
    local unit   = delta.Unit
    local travel = CombatPublic.meleeLungeTravel(dist, stop)
    local hit    = workspace:Raycast(hrp.Position, unit * travel, rc)
    local actual = hit and math.max(0, (hit.Position - hrp.Position).Magnitude - 2) or travel
    if actual <= 0.1 then return hrp.CFrame end
    return CFrame.lookAt(hrp.Position + unit * actual, npcRoot.Position)
end

local function syncCombo(char)
    local ok, style = pcall(CombatStylePublic.of, char)
    if ok and style and style.lights then
        local _ = (char:GetAttribute("AttackSequence") or 0) % #style.lights + 1
    end
end

-- ┌──────────────────────────────────────────────────────────────┐
-- │  STATE KEZELÉS                                               │
-- └──────────────────────────────────────────────────────────────┘
local npcState = {}
-- [model] = {
--   executing  = bool,
--   lastExec   = number,
--   hpConn     = RBXScriptConnection,
--   kdConn     = RBXScriptConnection,  (knockdown)
--   kbConn     = RBXScriptConnection,  (knockback)
--   parentConn = RBXScriptConnection,  (parent removed = szerver ölte meg)
-- }

local function cleanupEntry(model)
    local st = npcState[model]
    if not st then return end
    if st.hpConn     then st.hpConn:Disconnect()     end
    if st.kdConn     then st.kdConn:Disconnect()     end
    if st.kbConn     then st.kbConn:Disconnect()     end
    if st.parentConn then st.parentConn:Disconnect() end
    unfreezeTarget(model)
    npcState[model]       = nil
    trackedTargets[model] = nil
    if currentLockTarget == model then clearLockOn() end
end

local function ensureState(model)
    if not npcState[model] then
        npcState[model] = {
            executing  = false,
            lastExec   = 0,
            hpConn     = nil,
            kdConn     = nil,
            kbConn     = nil,
            parentConn = nil,
        }
    end
    return npcState[model]
end

local function cleanup()
    for model in npcState do
        if not model.Parent then
            cleanupEntry(model)
        end
    end
end

-- ┌──────────────────────────────────────────────────────────────┐
-- │  EXECUTION (GRAB)                                            │
-- │                                                              │
-- │  FIX: execGrab külön flaggel blokkol hogy ne                │
-- │  triggerelődjön többször egyszerre                           │
-- └──────────────────────────────────────────────────────────────┘
Remotes.GrabCutscene.OnClientEvent:Connect(function()
    -- Grab cutscene érkezett → execution sikeresen feldolgozva
end)

local function execGrab(char, hrp, npc, npcRoot, st)
    if st.executing then return end
    local now = os.clock()
    if now - st.lastExec < CFG.EXEC_CD then return end
    -- Karakter validáció (mi vagyunk-e abban a helyzetben hogy grabbelni tudjunk)
    if ActionState.isIncapacitated(char) then return end
    if char:GetAttribute("Grabbing") then return end
    -- Az NPC legyen még életben (parent check → szerver oldali igazolás)
    if not npc.Parent then return end

    st.executing = true
    st.lastExec  = now

    setLockOn(npc)
    local grabCF = computeAttackCFrame(char, hrp, npc, npcRoot)

    Remotes.PerformAction:FireServer("Grab", { phase="start", cframe=grabCF })

    task.delay(CFG.EXEC_HOLD, function()
        if LocalPlayer.Character == char then
            Remotes.PerformAction:FireServer("Grab", { phase="stop" })
        end
        st.executing = false
    end)
end

-- ┌──────────────────────────────────────────────────────────────┐
-- │  LISTENER KÖTÉSEK                                            │
-- │                                                              │
-- │  FIX (direct dmg bug): HP listener most NEM távolítja el    │
-- │  az NPC-t ha Health == 0 kliens oldalon.                    │
-- │  Csak a parentConn (szerver eltávolítja a modelt) és         │
-- │  a main loop cleanup() kezeli a valódi halált.              │
-- └──────────────────────────────────────────────────────────────┘
local function bindListeners(char, hrp, npc, npcRoot, st)

    -- Parent listener: szerver eltávolítja az NPC-t → ez a valódi halál
    if not st.parentConn then
        st.parentConn = npc.AncestryChanged:Connect(function(_, parent)
            if parent == nil then
                cleanupEntry(npc)
            end
        end)
    end

    -- HP listener: csak figyelünk, NEM töröljük ha HP == 0 kliens oldalon
    -- (ez volt a direkt dmg bug oka)
    if not st.hpConn then
        local hum = npc:FindFirstChildOfClass("Humanoid")
        if hum then
            st.hpConn = hum.HealthChanged:Connect(function(hp)
                -- NPC nincs már a workspace-ben → szerver már megölte
                if not npc.Parent then return end
                -- Exec threshold ellenőrzés (ÉLŐ NPC-n)
                if hp > 0 and hp / hum.MaxHealth <= CFG.EXEC_THRESHOLD then
                    local c = LocalPlayer.Character
                    local h = c and c:FindFirstChild("HumanoidRootPart")
                    if h and (npcRoot.Position - h.Position).Magnitude <= CFG.CHASE_RANGE then
                        execGrab(c, h, npc, npcRoot, st)
                    end
                end
            end)
        end
    end

    -- FIX knockdown: ToggleRagdoll signal + main loop is ellenőrzi
    if not st.kdConn then
        st.kdConn = npc:GetAttributeChangedSignal("ToggleRagdoll"):Connect(function()
            if not npc:GetAttribute("ToggleRagdoll") then return end
            if not npc.Parent then return end
            local c = LocalPlayer.Character
            local h = c and c:FindFirstChild("HumanoidRootPart")
            if not h then return end
            if (npcRoot.Position - h.Position).Magnitude > CFG.CHASE_RANGE then return end
            -- Rövid delay: freeze után grab
            freezeTarget(npc)
            task.delay(0.15, function()
                if npc.Parent then
                    execGrab(c, h, npc, npcRoot, st)
                end
            end)
        end)
    end

    -- Knockback: elrepülés esetén refreeze + chase range
    if not st.kbConn then
        st.kbConn = npc:GetAttributeChangedSignal("HitByKnockBack"):Connect(function()
            if npc:GetAttribute("HitByKnockBack") then
                trackedTargets[npc] = true
                task.delay(0.05, function()
                    if npc.Parent then freezeTarget(npc) end
                end)
            end
        end)
    end
end

-- ┌──────────────────────────────────────────────────────────────┐
-- │  TÜZELÉS                                                     │
-- └──────────────────────────────────────────────────────────────┘
local function fireAll(char, hrp, targets)
    for i, e in targets do
        local st = npcState[e.npc]
        if not st or st.executing then continue end
        if not e.npc.Parent then continue end  -- szerver már eltávolította

        local pkt = {
            phase  = "start",
            cframe = computeAttackCFrame(char, hrp, e.npc, e.root),
        }

        if i == 1 then
            Remotes.PerformAction:FireServer("LightAttack", pkt)
            if CFG.BEHIND_ON_ATTACK then
                teleportBehind(hrp, e.root, true)
            end
        else
            local d, n, r = (i-1) * CFG.BURST_DELAY, e.npc, e.root
            task.delay(d, function()
                if n.Parent and LocalPlayer.Character == char then
                    Remotes.PerformAction:FireServer("LightAttack", {
                        phase  = "start",
                        cframe = computeAttackCFrame(char, hrp, n, r),
                    })
                end
            end)
        end
    end
    syncCombo(char)
end

-- ┌──────────────────────────────────────────────────────────────┐
-- │  KARAKTER SETUP                                              │
-- └──────────────────────────────────────────────────────────────┘
local attrConn = nil

local function setupChar(char)
    -- Mindent letakarítunk
    for model in npcState do cleanupEntry(model) end
    for model in frozenTargets do unfreezeTarget(model) end
    npcState       = {}
    trackedTargets = {}
    posState       = { underground=false, surfaceY=nil, lastBehind=0 }
    currentLockTarget = nil

    if attrConn then attrConn:Disconnect() end
    attrConn = char.AttributeChanged:Connect(function()
        if not char:GetAttribute("Grabbing") then
            for _, st in npcState do st.executing = false end
        end
    end)
end

-- ┌──────────────────────────────────────────────────────────────┐
-- │  FŐ LOOP                                                     │
-- └──────────────────────────────────────────────────────────────┘
local cleanTimer = 0

RunService.Heartbeat:Connect(function(dt)
    -- Fő kapcsoló
    if not CFG.ENABLED then return end

    local char = LocalPlayer.Character
    if not char then return end
    local hrp  = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local hum  = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end

    forceFlush(char)

    -- Underground kezelés
    if shouldGoUnderground(char) then
        if not posState.underground then goUnderground(hrp) end
        maintainUnderground(hrp)
        return
    elseif posState.underground then
        returnToSurface(hrp)
    end

    -- Cleanup (3 mp-enként)
    cleanTimer += dt
    if cleanTimer >= 3 then cleanTimer = 0 ; cleanup() end

    if not canFire(char) then return end

    local targets = getTargetsInRange(hrp)
    if #targets == 0 then
        if currentLockTarget then clearLockOn() end
        return
    end
    if #targets > CFG.MAX_TARGETS then
        local t = {} ; for i=1,CFG.MAX_TARGETS do t[i]=targets[i] end ; targets=t
    end

    -- Lock-on elsődleges célpont
    setLockOn(targets[1].npc)

    for _, e in targets do
        if not e.npc.Parent then continue end
        local st = ensureState(e.npc)

        -- Listener-ek kötése
        bindListeners(char, hrp, e.npc, e.root, st)

        -- Freeze
        if CFG.FREEZE_ENABLED then
            freezeTarget(e.npc)
        end

        -- Chase ha messzebb repült
        if e.dist > CFG.RANGE then
            chaseTarget(hrp, e.root)
        end

        -- FIX knockdown exec: main loop-ban is ellenőrizzük
        -- (ne csak a signal-re hagyatkozzunk)
        if not st.executing then
            local isDowned  = ActionState.isDowned(e.npc)   -- ToggleRagdoll
            local hpLow     = e.hum.Health / math.max(e.hum.MaxHealth, 1) <= CFG.EXEC_THRESHOLD
            if isDowned or hpLow then
                execGrab(char, hrp, e.npc, e.root, st)
            end
        end
    end

    -- Mögé teleport (rate-limited)
    teleportBehind(hrp, targets[1].root, false)

    -- Tüzelés
    fireAll(char, hrp, targets)
end)

-- ┌──────────────────────────────────────────────────────────────┐
-- │  KARAKTER EVENTS                                             │
-- └──────────────────────────────────────────────────────────────┘
LocalPlayer.CharacterAdded:Connect(setupChar)
LocalPlayer.CharacterRemoving:Connect(function()
    for model in npcState do cleanupEntry(model) end
    for model in frozenTargets do unfreezeTarget(model) end
    npcState = {} ; trackedTargets = {}
    if attrConn then attrConn:Disconnect() ; attrConn = nil end
end)

if LocalPlayer.Character then setupChar(LocalPlayer.Character) end
print("[KillAura v8] Betöltve | _G.KillAuraCFG.ENABLED = true")
