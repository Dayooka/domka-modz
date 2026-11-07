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
function Shared.getKiPct()
    local hum = Shared.getHum()
    local char = Shared.getChar()
    if not hum or not char then return 1 end
    local hs = hum:FindFirstChild("Stats")
    if hs then
        local k = hs:GetAttribute("Ki") or hs:GetAttribute("Energy")
        local m = hs:GetAttribute("MaxKi") or hs:GetAttribute("MaxEnergy")
        if k and m and m > 0 then return k / m end
    end
    local k = char:GetAttribute("Ki")
    local m = char:GetAttribute("MaxKi")
    if k and m and m > 0 then return k / m end
    return 1
end

-- ActionState feltételek
function Shared.canBlock()
    local AS = Shared.getActionState()
    local c  = Shared.getChar()
    if not AS or not c then return true end
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
    return Shared.canBlock() and not AS.inStepIFrames(c)
end
function Shared.canAttack()
    local AS = Shared.getActionState()
    local c  = Shared.getChar()
    if not AS or not c then return true end
    return not AS.isDowned(c)
       and not AS.isChanneling(c)
       and not AS.isIncapacitated(c)
       and not AS.isRooted(c)
       and not AS.isIntangible(c)
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
