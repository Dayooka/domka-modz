-- ═══════════════════════════════════════════════════════════════
--  KillAuraController – FINAL v7
--  Új: player targeting, knockback chase, freeze, knockdown exec,
--      hit-back prevention
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
local CFG = getgenv().DomkaConfig or {
    -- Aura
    RANGE             = 24,
    CHASE_RANGE       = 50,
    MAX_TARGETS       = 10,
    BURST_DELAY       = 0.004,
    MULTIPLY          = 2,
    MULT_DELAY        = 0.006,

    -- Execution
    EXEC_THRESHOLD    = 0.15,
    EXEC_HOLD         = 0.3,
    EXEC_CD           = 2.0,

    -- Direct damage
    DIRECT_DMG        = 20,
    DIRECT_RATE       = 0.08,

    -- Pozíció
    BEHIND_OFFSET     = 2.5,   -- ← EZ HIÁNYZOTT
    BEHIND_RATE       = 0.03,
    UNDERGROUND_DEPTH = 12,

    -- Beállítások
    ATTACK_PLAYERS             = false,
    ATTACK_PLAYERS_THRESHOLD   = 0.3,
    FREEZE_ENABLED             = true,
    FREEZE_RATE                = 0,
    BEHIND_ON_ATTACK           = true,
    UNDERGROUND_AFTER_BURST    = false,
}

-- ┌──────────────────────────────────────────────────────────────┐
-- │  RÉTEG 0 – MODULE POISONING                                  │
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
-- │  TARGET KERESÉS                                              │
-- │  ÚJ: ATTACK_PLAYERS → játékosok is benne vannak             │
-- └──────────────────────────────────────────────────────────────┘

-- Kiterjesztett range (knockback chase): target-ek követése
local trackedTargets = {}  -- {model → true} – azok akik már benn voltak az aurában

local function getTargetsInRange(hrp)
    local r    = {}
    local seen = {}

    local function tryAdd(model, isPlayer)
        if seen[model] then return end
        seen[model] = true
        if not model:IsA("Model") or not model:IsDescendantOf(workspace) then return end
        local hum  = model:FindFirstChildOfClass("Humanoid")
        local root = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso")
        if not (hum and hum.Health > 0 and root) then return end

        local d = (root.Position - hrp.Position).Magnitude

        -- Normál range VAGY extended range ha már korábban tracked volt
        local maxRange = trackedTargets[model] and CFG.CHASE_RANGE or CFG.RANGE

        if d <= maxRange then
            table.insert(r, { npc=model, root=root, hum=hum, dist=d, isPlayer=isPlayer })
            trackedTargets[model] = true  -- innentől chase range-en belül tartjuk
        else
            trackedTargets[model] = nil   -- túl messze, elengedjük
        end
    end

    -- NPC-k (CollectionService)
    for _, npc in CollectionService:GetTagged(Entities.Tag.NPC) do tryAdd(npc, false) end

    -- NPC folder backup
    local npcFolder = workspace:FindFirstChild("NPCs")
    if npcFolder then
        for _, npc in npcFolder:GetChildren() do tryAdd(npc, false) end
    end

    -- Játékosok (ha engedélyezett)
    if CFG.ATTACK_PLAYERS then
        for _, player in Players:GetPlayers() do
            if player ~= LocalPlayer and player.Character then
                tryAdd(player.Character, true)
            end
        end
    end

    table.sort(r, function(a, b) return a.dist < b.dist end)
    return r
end

-- ┌──────────────────────────────────────────────────────────────┐
-- │  FREEZE RENDSZER                                             │
-- │  ÚJ: Folyamatosan nullázza az NPC mozgását kliens oldalon   │
-- │  Minden frame futó velocity suppressor                       │
-- └──────────────────────────────────────────────────────────────┘
local frozenTargets = {}  -- {model → true}

local function freezeTarget(model)
    if not CFG.FREEZE_ENABLED then return end
    frozenTargets[model] = true

    local hum  = model:FindFirstChildOfClass("Humanoid")
    local root = model:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return end

    -- Humanoid mozgás letiltása
    pcall(function()
        hum.WalkSpeed     = 0
        hum.JumpPower     = 0
        hum.JumpHeight    = 0
        hum.PlatformStand = true  -- Roblox: letiltja a fizikai mozgást
    end)

    -- Velocity nullázás
    pcall(function()
        root.AssemblyLinearVelocity  = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
        root.AssemblyAngularVelocity = Vector3.zero
    end)
end

local function unfreezeTarget(model)
    frozenTargets[model] = nil
    local hum = model:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    pcall(function()
        hum.WalkSpeed     = 16   -- Roblox default
        hum.JumpPower     = 50   -- default
        hum.JumpHeight    = 7.2  -- default
        hum.PlatformStand = false
    end)
end

-- Freeze maintenance loop (minden Heartbeat-en)
RunService.Heartbeat:Connect(function()
    for model in frozenTargets do
        if not model.Parent then
            frozenTargets[model] = nil
            continue
        end
        local hum  = model:FindFirstChildOfClass("Humanoid")
        local root = model:FindFirstChild("HumanoidRootPart")
        if not hum or not root then continue end
        pcall(function()
            hum.WalkSpeed     = 0
            hum.PlatformStand = true
            root.AssemblyLinearVelocity = Vector3.new(
                0, math.min(root.AssemblyLinearVelocity.Y, 0), 0
            )  -- Y negatív megengedett (esés), pozitív nem (knockback)
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
    if ActionState.isIncapacitated(char) then return true end
    if ActionState.thrownLocked(char)    then return true end
    if ActionState.inStepIFrames(char)   then return true end
    if ActionState.isPinned(char)        then return true end
    return false
end

-- ┌──────────────────────────────────────────────────────────────┐
-- │  POZÍCIÓ MANAGER                                             │
-- │  ÚJ: BEHIND_ON_ATTACK → minden attack után azonnal mögé     │
-- └──────────────────────────────────────────────────────────────┘
local posState    = { underground=false, surfaceY=nil, lastBehind=0 }

local function maintainUnderground(hrp)
    if not posState.underground or not posState.surfaceY then return end
    hrp.CFrame = CFrame.new(hrp.Position.X, posState.surfaceY - CFG.UNDERGROUND_DEPTH, hrp.Position.Z)
              * (hrp.CFrame - hrp.CFrame.Position)
end
local function goUnderground(hrp)
    if posState.underground then return end
    posState.underground = true ; posState.surfaceY = hrp.Position.Y
end
local function returnToSurface(hrp)
    if not posState.underground then return end
    posState.underground = false
    if posState.surfaceY then
        hrp.CFrame = CFrame.new(hrp.Position.X, posState.surfaceY, hrp.Position.Z)
                  * (hrp.CFrame - hrp.CFrame.Position)
        posState.surfaceY = nil
    end
end

-- Mögé teleport – most rate-limit nélkül hívható (BEHIND_ON_ATTACK)
local function teleportBehindTarget(hrp, npcRoot, force)
    local now = os.clock()
    if not force and now - posState.lastBehind < CFG.BEHIND_RATE then return end
    posState.lastBehind = now
    local behind = npcRoot.Position - npcRoot.CFrame.LookVector * CFG.BEHIND_OFFSET
    local rc = RaycastParams.new()
    rc.FilterType = Enum.RaycastFilterType.Exclude
    rc.FilterDescendantsInstances = {LocalPlayer.Character}
    rc.IgnoreWater = true
    if workspace:Raycast(npcRoot.Position, behind - npcRoot.Position, rc) then return end
    hrp.CFrame = CFrame.lookAt(behind, npcRoot.Position)
end

-- ÚJ: Chase mode – ha az ellenfél kilőttek messzebbre
local function chaseTarget(hrp, npcRoot)
    local delta = npcRoot.Position - hrp.Position
    local dist  = delta.Magnitude
    if dist <= CFG.RANGE then return end  -- nincs szükség chase-re
    -- Feléjük megyünk, de nem egészen odáig (mögéjük)
    local behind = npcRoot.Position - npcRoot.CFrame.LookVector * 2
    hrp.CFrame = CFrame.lookAt(behind, npcRoot.Position)
end

-- ┌──────────────────────────────────────────────────────────────┐
-- │  CFRAME SZÁMÍTÁS                                             │
-- └──────────────────────────────────────────────────────────────┘
local function computeCFrame(char, hrp, npc, npcRoot)
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
-- │  COMBAT                                                      │
-- └──────────────────────────────────────────────────────────────┘
local npcState   = {}
local lastDirDmg = {}
local attrConn   = nil

local function tryDirDmg(npc, hum, now)
    local last = lastDirDmg[npc] or 0
    if now - last < CFG.DIRECT_RATE then return end
    lastDirDmg[npc] = now
    pcall(function() hum:TakeDamage(CFG.DIRECT_DMG) end)
end

Remotes.GrabCutscene.OnClientEvent:Connect(function()
    -- Grab cutscene elindult → execution sikeresen fogadva
end)

local function execGrab(char, hrp, npc, npcRoot, st)
    if st.executing then return end
    local now = os.clock()
    if now - (st.lastExec or 0) < CFG.EXEC_CD then return end
    if ActionState.isIncapacitated(char) then return end
    if char:GetAttribute("Grabbing") then return end
    st.executing = true ; st.lastExec = now
    setLockOn(npc)
    Remotes.PerformAction:FireServer("Grab", {
        phase  = "start",
        cframe = computeCFrame(char, hrp, npc, npcRoot),
    })
    task.delay(CFG.EXEC_HOLD, function()
        if LocalPlayer.Character == char then
            Remotes.PerformAction:FireServer("Grab", { phase = "stop" })
        end
        st.executing = false
    end)
end

local function watchHP(char, hrp, npc, npcRoot, st)
    if st.hpConn then return end
    local hum = npc:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    st.hpConn = hum.HealthChanged:Connect(function(hp)
        if hp <= 0 then
            if st.hpConn then st.hpConn:Disconnect() end
            if st.kdConn then st.kdConn:Disconnect() end
            unfreezeTarget(npc)
            npcState[npc]       = nil
            lastDirDmg[npc]     = nil
            trackedTargets[npc] = nil
            if currentLockTarget == npc then clearLockOn() end
            return
        end
        local pct = hp / hum.MaxHealth
        if pct <= CFG.EXEC_THRESHOLD then
            local c = LocalPlayer.Character
            local h = c and c:FindFirstChild("HumanoidRootPart")
            if h and (npcRoot.Position - h.Position).Magnitude <= CFG.CHASE_RANGE then
                execGrab(c, h, npc, npcRoot, st)
            end
        end
    end)
end

-- ÚJ: Knockdown figyelő
-- Ha az NPC leknockolódik (ToggleRagdoll = true) → azonnali execution
local function watchKnockdown(char, hrp, npc, npcRoot, st)
    if st.kdConn then return end
    st.kdConn = npc:GetAttributeChangedSignal("ToggleRagdoll"):Connect(function()
        if not npc:GetAttribute("ToggleRagdoll") then return end
        -- NPC leknockolódott → azonnal execute
        local c = LocalPlayer.Character
        local h = c and c:FindFirstChild("HumanoidRootPart")
        if not h then return end
        local dist = (npcRoot.Position - h.Position).Magnitude
        if dist > CFG.CHASE_RANGE then return end
        -- Freeze rövid ideig hogy ne tudjon elrepülni a ragdoll
        freezeTarget(npc)
        task.delay(0.2, function()
            execGrab(c, h, npc, npcRoot, st)
        end)
    end)
end

-- ÚJ: HitByKnockBack figyelő – knockback esetén chase + refreeze
local function watchKnockback(npc, npcRoot, st)
    if st.kbConn then return end
    st.kbConn = npc:GetAttributeChangedSignal("HitByKnockBack"):Connect(function()
        if not npc:GetAttribute("HitByKnockBack") then return end
        -- Knockback érkezett → refreeze + tracker kiterjesztve
        trackedTargets[npc] = true  -- chase range-re váltás
        task.delay(0.05, function() freezeTarget(npc) end)
    end)
end

local function fireAll(char, hrp, targets, now)
    for i, e in targets do
        local st = npcState[e.npc]
        if not st or st.executing then continue end

        tryDirDmg(e.npc, e.hum, now)

        local pkt = { phase = "start", cframe = computeCFrame(char, hrp, e.npc, e.root) }

        if i == 1 then
            Remotes.PerformAction:FireServer("LightAttack", pkt)
            -- ÚJ: BEHIND_ON_ATTACK → azonnal mögé teleport minden első attack után
            if CFG.BEHIND_ON_ATTACK then
                teleportBehindTarget(hrp, e.root, true)
            end
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
    syncCombo(char)

    -- ÚJ: burst után rövid föld alá (extra hit-back protection)
    if CFG.UNDERGROUND_AFTER_BURST then
        goUnderground(hrp)
        task.delay(0.05, function()
            returnToSurface(hrp)
        end)
    end
end

local function ensureState(npc)
    if not npcState[npc] then
        npcState[npc] = { executing=false, lastExec=0, hpConn=nil, kdConn=nil, kbConn=nil }
    end
    return npcState[npc]
end

local function cleanup()
    for npc, st in npcState do
        if not npc.Parent then
            if st.hpConn then st.hpConn:Disconnect() end
            if st.kdConn then st.kdConn:Disconnect() end
            if st.kbConn then st.kbConn:Disconnect() end
            unfreezeTarget(npc)
            npcState[npc]       = nil
            lastDirDmg[npc]     = nil
            trackedTargets[npc] = nil
        end
    end
end

local function setupChar(char)
    for _, st in npcState do
        if st.hpConn then st.hpConn:Disconnect() end
        if st.kdConn then st.kdConn:Disconnect() end
        if st.kbConn then st.kbConn:Disconnect() end
    end
    for npc in frozenTargets do unfreezeTarget(npc) end
    npcState          = {}
    lastDirDmg        = {}
    trackedTargets    = {}
    posState          = { underground=false, surfaceY=nil, lastBehind=0 }
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
    local char = LocalPlayer.Character
    if not char then return end
    local hrp  = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local hum  = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end

    forceFlush(char)

    if shouldGoUnderground(char) then
        goUnderground(hrp) ; maintainUnderground(hrp) ; return
    elseif posState.underground then
        returnToSurface(hrp)
    end

    cleanTimer += dt
    if cleanTimer >= 3 then cleanTimer = 0 ; cleanup() end
    if not canFire(char) then return end

    local now     = os.clock()
    local targets = getTargetsInRange(hrp)

    if #targets == 0 then
        if currentLockTarget then clearLockOn() end
        return
    end
    if #targets > CFG.MAX_TARGETS then
        local t = {} ; for i=1,CFG.MAX_TARGETS do t[i]=targets[i] end ; targets=t
    end

    setLockOn(targets[1].npc)

    for _, e in targets do
        local st = ensureState(e.npc)

        -- Listener-ek csatlakoztatása
        watchHP(char, hrp, e.npc, e.root, st)
        watchKnockdown(char, hrp, e.npc, e.root, st)
        watchKnockback(e.npc, e.root, st)

        -- Freeze (stuckolás)
        if CFG.FREEZE_ENABLED then
            freezeTarget(e.npc)
        end

        -- Chase ha messzebb repült (knockback)
        if e.dist > CFG.RANGE then
            chaseTarget(hrp, e.root)
        end

        -- Exec check (HP threshold)
        if e.hum.Health / e.hum.MaxHealth <= CFG.EXEC_THRESHOLD and not st.executing then
            execGrab(char, hrp, e.npc, e.root, st)
        end
    end

    -- Mögé teleport (rate-limited rendes verzió)
    teleportBehindTarget(hrp, targets[1].root, false)

    -- Tüzelés
    fireAll(char, hrp, targets, now)
end)

LocalPlayer.CharacterAdded:Connect(setupChar)
LocalPlayer.CharacterRemoving:Connect(function()
    for npc, st in npcState do
        if st.hpConn then st.hpConn:Disconnect() end
        if st.kdConn then st.kdConn:Disconnect() end
        if st.kbConn then st.kbConn:Disconnect() end
        unfreezeTarget(npc)
    end
    npcState = {} ; lastDirDmg = {} ; trackedTargets = {}
    currentLockTarget = nil
    if attrConn then attrConn:Disconnect() ; attrConn = nil end
end)

if LocalPlayer.Character then setupChar(LocalPlayer.Character) end
print("[KillAura v7] Betöltve")
