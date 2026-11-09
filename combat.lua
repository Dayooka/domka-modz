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

-- ── Config bridge ──────────────────────────────────────────────
-- Ha _G._AIO_Config be van töltve, onnan olvassuk az értékeket
-- Ha nem, fallback a _G.KillAuraCFG-re (visszafelé kompatibilis)
local function CFG(key)
    local AIOCfg = _G._AIO_Config
    if AIOCfg then
        local v = AIOCfg.get("KillAura", key)
        if v ~= nil then return v end
    end
    -- Fallback: _G.KillAuraCFG
    if _G.KillAuraCFG and _G.KillAuraCFG[key] ~= nil then
        return _G.KillAuraCFG[key]
    end
    -- Hardcoded defaults
    local defaults = {
        enabled           = true,
        RANGE             = 24,
        CHASE_RANGE       = 50,
        MAX_TARGETS       = 10,
        BURST_DELAY       = 0.004,
        MULTIPLY          = 2,
        MULT_DELAY        = 0.006,
        TARGET_PRIORITY   = "nearest",
        ATTACK_PLAYERS    = false,
        EXEC_THRESHOLD    = 0.15,
        EXEC_HOLD         = 0.3,
        EXEC_CD           = 2.5,
        BEHIND_OFFSET     = 2.5,
        BEHIND_RATE       = 0.08,
        UNDERGROUND_DEPTH   = 10,
        UNDERGROUND_ENABLED = true,
        FREEZE_ENABLED    = true,
    }
    return defaults[key]
end

-- _G.KillAuraCFG megtartása visszafelé kompatibilitáshoz
_G.KillAuraCFG = setmetatable({}, {
    __index    = function(_, k) return CFG(k) end,
    __newindex = function(_, k, v)
        if _G._AIO_Config then
            _G._AIO_Config.set("KillAura", k, v)
        end
    end,
})

-- ── MODULE POISONING ───────────────────────────────────────────
--[[
    Csak az AttackCooldown, Swinging, HeavyCooldown elemeket
    vesszük ki a blockedBy listákból – a Blocking, Vanishing,
    SideStepping benne marad, különben a szerver visszautasítja
    a Block/Vanish küldést "tamadasban van" alapon.
]]
local REMOVE_FROM_BLOCKED = {
    AttackCooldown = true,
    Swinging       = true,
    HeavyCooldown  = true,
}

local function filterBlockedBy(action)
    if not ActionConfig[action] then return end
    local original = ActionConfig[action].blockedBy
    if type(original) ~= "table" then return end
    local filtered = {}
    for _, v in ipairs(original) do
        if not REMOVE_FROM_BLOCKED[v] then
            table.insert(filtered, v)
        end
    end
    ActionConfig[action].blockedBy = filtered
end

local function poisonModules()
    filterBlockedBy("LightAttack")
    filterBlockedBy("HeavyAttack")
    filterBlockedBy("Grab")
    -- Block, Vanish, SideStep NEM érintett – maradnak érintetlenül

    CombatPublic.meleeApproachStop = function() return 0.1 end
    CombatPublic.meleeLungeTravel  = function(dist) return dist - 0.1 end
    print("[POISON] OK")
end
poisonModules()

-- ── LOCKON ─────────────────────────────────────────────────────
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

-- ── __namecall HOOK ────────────────────────────────────────────
local SPOOF    = { AttackCooldown=true, Swinging=true, HeavyCooldown=true }
local hookedRE = Remotes.PerformAction
local bypass   = false
local oldNC

-- Ezek az actionök mindig átmennek a hookban – sosem blokkoljuk őket
local PASSTHROUGH = {
    Block    = true,
    Vanish   = true,
    SideStep = true,
    Grab     = true,   -- execut engedjük, csak sokszorozást tiltjuk
}

oldNC = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local m    = getnamecallmethod()
    local char = LocalPlayer.Character

    -- Attribute spoofing (AttackCooldown stb.)
    if m == "GetAttribute" and char and self == char then
        if SPOOF[select(1,...)] then return nil end
    end
    if m == "SetAttribute" and char and self == char then
        if SPOOF[select(1,...)] then return end
    end

    -- FireServer hook
    if m == "FireServer" and self == hookedRE then
        local action = select(1, ...)

        -- Block/Vanish/SideStep: MINDIG átengedjük, bypass-tól függetlenül
        if PASSTHROUGH[action] then
            return oldNC(self, ...)
        end

        -- LightAttack / HeavyAttack sokszorozás (csak ha nem bypass)
        if not bypass then
            local params = select(2, ...)
            if type(params) == "table" then
                local mult, multDel

                if action == "LightAttack" then
                    mult    = CFG("LIGHT_MULTIPLY") or 2
                    multDel = CFG("MULT_DELAY")     or 0.006
                elseif action == "HeavyAttack" then
                    mult    = CFG("HEAVY_MULTIPLY") or 1
                    multDel = CFG("MULT_DELAY")     or 0.006
                end

                if mult and mult > 1 then
                    local p = params
                    for i = 1, mult do
                        task.delay(i * multDel, function()
                            bypass = true
                            pcall(function() hookedRE:FireServer(action, p) end)
                            bypass = false
                        end)
                    end
                end
            end
        end
    end

    return oldNC(self, ...)
end))

-- ── firesignal FLUSH ───────────────────────────────────────────
local lastFlush = 0
local function forceFlush(char)
    if not firesignal then return end
    local now = os.clock()
    if now - lastFlush < 0.05 then return end
    lastFlush = now
    pcall(function() firesignal(char:GetAttributeChangedSignal("AttackCooldown")) end)
end

-- ── NPC FÁZIS ──────────────────────────────────────────────────
local function getNPCPhase(npc, hum)
    if not npc.Parent then return "dead" end
    if hum.Health <= 0 then return "execute" end
    if ActionState.isDowned(npc) then return "execute" end
    local hpPct = hum.Health / math.max(hum.MaxHealth, 1)
    if hpPct <= CFG("EXEC_THRESHOLD") then return "execute" end
    return "attack"
end

-- ── TARGET KERESÉS ─────────────────────────────────────────────
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
        if hum.Health <= 0 and not model.Parent then return end

        local d       = (root.Position - hrp.Position).Magnitude
        local maxDist = tracked[model] and CFG("CHASE_RANGE") or CFG("RANGE")
        if d > maxDist then tracked[model] = nil; return end

        tracked[model] = true
        table.insert(r, { npc=model, root=root, hum=hum, dist=d, isPlayer=isPlayer })
    end

    for _, n in CollectionService:GetTagged(Entities.Tag.NPC) do tryAdd(n, false) end
    local f = workspace:FindFirstChild("NPCs")
    if f then for _, n in f:GetChildren() do tryAdd(n, false) end end
    if CFG("ATTACK_PLAYERS") then
        for _, pl in Players:GetPlayers() do
            if pl ~= LocalPlayer and pl.Character then tryAdd(pl.Character, true) end
        end
    end

    local prio = CFG("TARGET_PRIORITY")
    if prio == "lowest_hp" then
        table.sort(r, function(a, b) return a.hum.Health < b.hum.Health end)
    elseif prio == "mixed" then
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

-- ── FREEZE ─────────────────────────────────────────────────────
local frozen = {}

local function freezeNPC(npc)
    if not CFG("FREEZE_ENABLED") or frozen[npc] then return end
    frozen[npc] = true
    local hum  = npc:FindFirstChildOfClass("Humanoid")
    local root = npc:FindFirstChild("HumanoidRootPart")
    if hum then pcall(function()
        hum.WalkSpeed = 0; hum.JumpPower = 0
        hum.JumpHeight = 0; hum.PlatformStand = true
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
        hum.WalkSpeed = 16; hum.JumpPower = 50
        hum.JumpHeight = 7.2; hum.PlatformStand = false
    end) end
end

RunService.Heartbeat:Connect(function()
    if not CFG("FREEZE_ENABLED") then return end
    for npc in frozen do
        if not npc.Parent then frozen[npc] = nil end
        local hum  = npc and npc:FindFirstChildOfClass("Humanoid")
        local root = npc and npc:FindFirstChild("HumanoidRootPart")
        if not hum or not root then end
        pcall(function()
            hum.WalkSpeed = 0; hum.PlatformStand = true
            root.AssemblyLinearVelocity = Vector3.new(
                0, math.min(root.AssemblyLinearVelocity.Y, 0), 0)
        end)
    end
end)

-- ── VALIDÁCIÓ ──────────────────────────────────────────────────
_G._AIO_DefenseActive = _G._AIO_DefenseActive or false

local function canFire(char)
    -- Alapvető ActionState ellenőrzések
    if ActionState.isDowned(char)        then return false end
    if ActionState.isChanneling(char)    then return false end
    if ActionState.isIncapacitated(char) then return false end

    -- _AIO_DefenseActive: autoblock/autovanish állítja
    if _G._AIO_DefenseActive then return false end

    -- Pontos attribútum nevek a forrásból (ActionState konstansok):
    -- SIDE_STEPPING_ATTR = "SideStepping"
    -- STEP_IFRAME_ATTR   = "StepIFrameUntil"
    -- PIN_ATTR           = "PinnedUntil"

    -- Blocking: szerver állítja ha block el lett fogadva
    if char:GetAttribute("Blocking") then return false end

    -- SideStepping: SIDE_STEPPING_ATTR
    if char:GetAttribute("SideStepping") then return false end

    -- StepIFrameUntil: inStepIFrames ellenőrzés
    if ActionState.inStepIFrames(char) then return false end

    -- InGym: ha edzőteremben van, nem támadható/mozoghat (HARD_CC tagja)
    if char:GetAttribute("InGym") then return false end

    return true
end

local function shouldGoUnderground(char)
    if not CFG("UNDERGROUND_ENABLED") then return false end
    if ActionState.isIncapacitated(char) then return true end
    if ActionState.thrownLocked(char)    then return true end
    if ActionState.inStepIFrames(char)   then return true end
    if ActionState.isPinned(char)        then return true end
    return false
end

-- ── POZÍCIÓ ────────────────────────────────────────────────────
local posState = { underground=false, surfaceY=nil, lastBehind=0 }

local function goUnderground(hrp)
    if posState.underground then return end
    posState.underground = true
    posState.surfaceY    = hrp.Position.Y
    hrp.CFrame = hrp.CFrame + Vector3.new(0, -CFG("UNDERGROUND_DEPTH"), 0)
end

local function maintainUnderground(hrp)
    if not posState.surfaceY then return end
    local want = posState.surfaceY - CFG("UNDERGROUND_DEPTH")
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
    if now - posState.lastBehind < CFG("BEHIND_RATE") then return end
    posState.lastBehind = now
    local offset = CFG("BEHIND_OFFSET")
    local behind = npcRoot.Position - npcRoot.CFrame.LookVector * offset
    behind = Vector3.new(behind.X, npcRoot.Position.Y, behind.Z)
    local rc = RaycastParams.new()
    rc.FilterType = Enum.RaycastFilterType.Exclude
    rc.FilterDescendantsInstances = {LocalPlayer.Character}
    rc.IgnoreWater = true
    local d = behind - npcRoot.Position
    if d.Magnitude > 0.1 and workspace:Raycast(npcRoot.Position, d, rc) then return end
    hrp.CFrame = CFrame.lookAt(behind, npcRoot.Position)
end

-- ── CFRAME ─────────────────────────────────────────────────────
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

-- ── GRAB EXECUTION ─────────────────────────────────────────────
local execState = {}

local function tryExec(char, hrp, npc, root)
    local st = execState[npc]
    if not st then
        execState[npc] = { grabbing=false, lastExec=0 }
        st = execState[npc]
    end
    if st.grabbing then return end
    local now = os.clock()
    if now - st.lastExec < CFG("EXEC_CD") then return end
    if ActionState.isIncapacitated(char) then return end
    if char:GetAttribute("Grabbing") then return end
    if not npc.Parent then return end

    st.grabbing = true
    st.lastExec = now
    setLockOn(npc)

    local offset = CFG("BEHIND_OFFSET")
    local behind = root.Position - root.CFrame.LookVector * offset
    behind = Vector3.new(behind.X, root.Position.Y, behind.Z)
    hrp.CFrame = CFrame.lookAt(behind, root.Position)
    task.wait(0.05)

    if not npc.Parent or not LocalPlayer.Character then
        st.grabbing = false; return
    end

    Remotes.PerformAction:FireServer("Grab", {
        phase  = "start",
        cframe = CFrame.lookAt(hrp.Position, root.Position),
    })

    task.delay(CFG("EXEC_HOLD"), function()
        if LocalPlayer.Character == char then
            Remotes.PerformAction:FireServer("Grab", { phase = "stop" })
        end
        st.grabbing = false
    end)
end

-- ── KARAKTER SETUP ─────────────────────────────────────────────
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

-- ── FŐ LOOP ────────────────────────────────────────────────────
local cleanTimer = 0

RunService.Heartbeat:Connect(function(dt)
    if not CFG("enabled") then return end

    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end

    forceFlush(char)

    if shouldGoUnderground(char) then
        if not posState.underground then goUnderground(hrp) end
        maintainUnderground(hrp)
        return
    elseif posState.underground then
        returnToSurface(hrp)
    end

    cleanTimer = cleanTimer + dt
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

    local maxT = CFG("MAX_TARGETS")
    if #targets > maxT then
        local t = {}
        for i = 1, maxT do t[i] = targets[i] end
        targets = t
    end

    setLockOn(targets[1].npc)

    local toAttack  = {}
    local toExecute = {}

    for _, e in targets do
        if not e.npc.Parent then end
        local phase = getNPCPhase(e.npc, e.hum)
        if phase == "dead" then
            execState[e.npc] = nil
            tracked[e.npc]   = nil
            unfreezeNPC(e.npc)
            if currentLock == e.npc then clearLockOn() end
        elseif phase == "execute" then
            table.insert(toExecute, e)
            freezeNPC(e.npc)
        else
            table.insert(toAttack, e)
            freezeNPC(e.npc)
        end
    end

    -- ── Execute fázis ─────────────────────────────────────────
    if CFG("EXEC_ENABLED") then
        for _, e in toExecute do
            tryExec(char, hrp, e.npc, e.root)
        end
    end

    -- ── Attack fázis ──────────────────────────────────────────
    if #toAttack == 0 then return end

    local mode       = CFG("ATTACK_MODE")     or "mixed"
    local burstDelay = CFG("BURST_DELAY")     or 0.004
    local atkDelay   = CFG("ATTACK_DELAY")    or 0.0
    local lightMult  = CFG("LIGHT_MULTIPLY")  or 2
    local multDelay  = CFG("MULT_DELAY")      or 0.006
    local heavyMult  = CFG("HEAVY_MULTIPLY")  or 1
    local heavyHold  = CFG("HEAVY_HOLD")      or 0.22
    local lightCount = CFG("LIGHT_COUNT")     or 4

    -- Teleport mögé az első célponthoz
    if CFG("TELEPORT_ENABLED") then
        teleportBehind(hrp, toAttack[1].root)
    end

    -- ── Segédfüggvények ──────────────────────────────────────
    local function sendLight(target, delayOffset)
        local n, r = target.npc, target.root
        local function doSend()
            if not n.Parent or LocalPlayer.Character ~= char then return end
            local pkt = {
                phase  = "start",
                cframe = computeCF(char, hrp, n, r),
            }
            -- Szerver-oldali sokszorozás (hook kezeli)
            Remotes.PerformAction:FireServer("LightAttack", pkt)
        end
        if delayOffset and delayOffset > 0 then
            task.delay(delayOffset, doSend)
        else
            doSend()
        end
    end

    local function sendHeavy(target, delayOffset)
        local n, r = target.npc, target.root
        local function doSend()
            if not n.Parent or LocalPlayer.Character ~= char then return end
            local pkt = {
                phase  = "start",
                cframe = computeCF(char, hrp, n, r),
            }
            Remotes.PerformAction:FireServer("HeavyAttack", pkt)
            task.delay(heavyHold, function()
                if LocalPlayer.Character == char then
                    Remotes.PerformAction:FireServer("HeavyAttack", { phase = "stop" })
                end
            end)
        end
        if delayOffset and delayOffset > 0 then
            task.delay(delayOffset, doSend)
        else
            doSend()
        end
    end

    -- ── Combo végrehajtás mód alapján ────────────────────────
    for i, e in toAttack do
        local st = execState[e.npc]
        if st and st.grabbing then
            -- Skip – grab folyamatban van erre az NPC-re
        else
            local baseDelay = (i - 1) * burstDelay + atkDelay

            if mode == "light" then
                -- Csak Light
                sendLight(e, baseDelay)

            elseif mode == "heavy" then
                -- Csak Heavy
                sendHeavy(e, baseDelay)

            elseif mode == "grab" then
                -- Csak Grab (execute)
                task.delay(baseDelay, function()
                    if e.npc.Parent and LocalPlayer.Character == char then
                        tryExec(char, hrp, e.npc, e.root)
                    end
                end)

            else
                -- mixed: LLLL + M combo (csak első célpontra)
                if i == 1 then
                    task.spawn(function()
                        -- Light sorozat
                        for j = 1, lightCount do
                            if not e.npc.Parent or LocalPlayer.Character ~= char then break end
                            if not canFire(char) then break end
                            sendLight(e, 0)
                            task.wait(0.08 + atkDelay)
                        end
                        -- Heavy finisher
                        if e.npc.Parent and LocalPlayer.Character == char and canFire(char) then
                            sendHeavy(e, 0)
                        end
                    end)
                else
                    -- Többi célpont: Light burst
                    sendLight(e, baseDelay)
                end
            end
        end
    end

    syncCombo(char)
end)

LocalPlayer.CharacterAdded:Connect(setupChar)
LocalPlayer.CharacterRemoving:Connect(function()
    for npc in frozen do unfreezeNPC(npc) end
    frozen = {}; tracked = {}; execState = {}
    if attrConn then attrConn:Disconnect(); attrConn = nil end
end)

if LocalPlayer.Character then setupChar(LocalPlayer.Character) end
print("[KillAura v9] Betöltve | _G.KillAuraCFG.ENABLED")
