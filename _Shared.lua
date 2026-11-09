--[[
    _Shared  –  ModuleScript
    Közös függvények minden script számára.
    Elhelyezés: StarterPlayerScripts > AIOScripts > _Shared
]]

local Players    = game:GetService("Players")
local RS         = game:GetService("ReplicatedStorage")

local Shared = {}

-- Modulok (lazy load – csak egyszer töltődik be)
local _remotes, _actionState, _combatPublic, _entities

function Shared.getRemotes()
    if not _remotes then _remotes = require(RS.Modules.Remotes) end
    return _remotes
end
function Shared.getActionState()
    if not _actionState then _actionState = require(RS.Modules.ActionState) end
    return _actionState
end
function Shared.getCombatPublic()
    if not _combatPublic then _combatPublic = require(RS.Modules.CombatPublic) end
    return _combatPublic
end
function Shared.getEntities()
    if not _entities then _entities = require(RS.Modules.Entities) end
    return _entities
end

-- RemoteFolder referencia
local _remF
function Shared.getRemoteFolder()
    if not _remF then _remF = RS:WaitForChild("Remotes", 10) end
    return _remF
end
function Shared.getRemoteByName(name)
    local f = Shared.getRemoteFolder()
    return f and f:FindFirstChild(name)
end

-- Karakter referenciák (mindig friss)
local LP = Players.LocalPlayer
function Shared.getChar()  return LP.Character end
function Shared.getHum()
    local c = LP.Character; return c and c:FindFirstChildOfClass("Humanoid")
end
function Shared.getHRP()
    local c = LP.Character; return c and c:FindFirstChild("HumanoidRootPart")
end
function Shared.getLP() return LP end

-- Ki százalék lekérése
-- Forrás alapján: Stats modul tárolja a Ki értékeket
-- Prioritás: 1. Stats modul 2. Humanoid.Stats gyerek 3. Karakter attr 4. default 1
function Shared.getKiPct()
    local hum  = Shared.getHum()
    local char = Shared.getChar()
    if not hum or not char then return 1 end

    -- 1. Stats ModuleScript (ha létezik)
    local ok, Stats = pcall(function()
        return require(RS.Modules:FindFirstChild("Stats"))
    end)
    if ok and Stats and Stats.getKi then
        local k, m = pcall(Stats.getKi, char)
        if k and m and type(m) == "number" and m > 0 then
            local ok2, cur = pcall(Stats.getKi, char)
            if ok2 and cur then return math.clamp(cur / m, 0, 1) end
        end
    end

    -- 2. Humanoid.Stats gyerek attribútumok
    local hs = hum:FindFirstChild("Stats")
    if hs then
        local k = hs:GetAttribute("Ki") or hs:GetAttribute("Energy")
        local m = hs:GetAttribute("MaxKi") or hs:GetAttribute("MaxEnergy")
        if k and m and m > 0 then return math.clamp(k / m, 0, 1) end
    end

    -- 3. Karakter direkten
    local k = char:GetAttribute("Ki")
    local m = char:GetAttribute("MaxKi")
    if k and m and m > 0 then return math.clamp(k / m, 0, 1) end

    -- 4. Default: feltételezzük hogy van Ki
    return 1
end

-- ── ActionState feltételek ─────────────────────────────────────────
-- Forrás alapján pontos HARD_CC attribútumok:
--   STUNNED_ATTR        = "Stunned"
--   RAGDOLL_ATTR        = "ToggleRagdoll"  (isDowned)
--   CHANNELING_ATTR     = "Channeling"
--   CAST_ATTR           = "Casting"
--   PIN_ATTR            = "PinnedUntil"    (isPinned)
--   STEP_IFRAME_ATTR    = "StepIFrameUntil" (inStepIFrames)
--   SIDE_STEPPING_ATTR  = "SideStepping"
--   IN_GYM_ATTR         = "InGym"          (HARD_CC tagja)

function Shared.canBlock()
    local AS = Shared.getActionState()
    local c  = Shared.getChar()
    if not AS or not c then return true end
    -- InGym: edzőteremben HARD_CC
    if c:GetAttribute("InGym") then return false end
    return not AS.isDowned(c)
       and not AS.isChanneling(c)
       and not AS.isIncapacitated(c)
       and not AS.isRooted(c)
       and not AS.isIntangible(c)
end

function Shared.canStep(lastStepAt, cooldown)
    local AS = Shared.getActionState()
    local c  = Shared.getChar()
    if not AS or not c then return true end
    if tick() - (lastStepAt or 0) < (cooldown or 0.52) then return false end
    if c:GetAttribute("InGym") then return false end
    -- StepIFrameUntil: inStepIFrames
    return Shared.canBlock() and not AS.inStepIFrames(c)
end

function Shared.canAttack()
    local AS = Shared.getActionState()
    local c  = Shared.getChar()
    if not AS or not c then return true end
    if c:GetAttribute("InGym") then return false end
    -- Defense aktív (autoblock/autovanish)
    if _G._AIO_DefenseActive then return false end
    return not AS.isDowned(c)
       and not AS.isChanneling(c)
       and not AS.isIncapacitated(c)
       and not AS.isRooted(c)
       and not AS.isIntangible(c)
end

-- isPinned: PinnedUntil attribútum alapján
function Shared.isPinned()
    local c = Shared.getChar()
    if not c then return false end
    local pinUntil = c:GetAttribute("PinnedUntil")
    if not pinUntil then return false end
    return workspace:GetServerTimeNow() < pinUntil
end

-- isInGym: InGym HARD_CC attribútum
function Shared.isInGym()
    local c = Shared.getChar()
    return c and c:GetAttribute("InGym") == true
end

-- Levegőben van-e
function Shared.isAirborne()
    local hum = Shared.getHum()
    local char = Shared.getChar()
    if not hum then return false end
    return (char and char:GetAttribute("Flying") == true)
        or hum.FloorMaterial == Enum.Material.Air
end

-- BasePart lekérése modellből
function Shared.getPart(inst)
    if not inst then return nil end
    if inst:IsA("BasePart") then return inst end
    if inst:IsA("Model") then
        return inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart")
    end
end

-- Teleport helper
function Shared.teleportTo(cframe)
    local hrp = Shared.getHRP()
    if hrp then hrp.CFrame = cframe end
end

-- Remote invoke helper (RF + RE egységesen)
function Shared.invoke(name, ...)
    local r = Shared.getRemoteByName(name)
    if not r then return nil end
    local ok, res = pcall(function(...)
        if r:IsA("RemoteFunction") then return r:InvokeServer(...)
        else r:FireServer(...); return true end
    end, ...)
    return ok and res or nil
end

-- PerformAction shortcut
function Shared.perform(action, data)
    local R = Shared.getRemotes()
    if R then pcall(function() R.PerformAction:FireServer(action, data or {}) end) end
end

_G._AIO_Shared = Shared
return Shared
