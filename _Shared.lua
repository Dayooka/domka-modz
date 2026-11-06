--[[
    _Shared  –  Segédfüggvények a modulok számára
]]

local Players         = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LP              = Players.LocalPlayer

local Remotes         = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Remotes"))
local ActionState     = require(ReplicatedStorage.Modules.ActionState)
local CombatPublic    = require(ReplicatedStorage.Modules.CombatPublic)
local Entities        = require(ReplicatedStorage.Modules.Entities)

local Module = {}

function Module.getLP() return LP end
function Module.getChar() return LP.Character end
function Module.getHRP()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end
function Module.getCombatPublic() return CombatPublic end
function Module.getEntities() return Entities end

function Module.getRemoteByName(name)
    local rf = ReplicatedStorage:FindFirstChild("Remotes")
    return rf and rf:FindFirstChild(name)
end

function Module.invoke(name, ...)
    local r = Module.getRemoteByName(name)
    if not r then return nil end
    local ok, res = pcall(function(...) return r:InvokeServer(...) end, ...)
    return ok and res or nil
end

function Module.perform(action, params)
    pcall(function() Remotes.PerformAction:FireServer(action, params) end)
end

function Module.canBlock()
    local char = LP.Character
    if not char then return false end
    return not ActionState.isDowned(char)
       and not ActionState.isChanneling(char)
       and not ActionState.isIncapacitated(char)
       and not ActionState.isRooted(char)
       and not ActionState.isIntangible(char)
end

function Module.canAttack()
    local char = LP.Character
    if not char then return false end
    return not ActionState.isDowned(char)
       and not ActionState.isChanneling(char)
       and not ActionState.isIncapacitated(char)
       and not ActionState.isRooted(char)
       and not ActionState.isIntangible(char)
end

function Module.canStep(lastStepAt, stepCooldown)
    local char = LP.Character
    if not char then return false end
    return Module.canBlock()
       and not ActionState.inStepIFrames(char)
       and (tick() - lastStepAt >= (stepCooldown or 0.52))
end

function Module.isAirborne()
    local char = LP.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    return char:GetAttribute("Flying") == true or (hum and hum.FloorMaterial == Enum.Material.Air)
end

function Module.getKiPct()
    local char = LP.Character
    if not char then return 1 end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hs = hum and hum:FindFirstChild("Stats")
    if hs then
        local k = hs:GetAttribute("Ki") or hs:GetAttribute("Energy")
        local m = hs:GetAttribute("MaxKi") or hs:GetAttribute("MaxEnergy")
        if k and m and m > 0 then return k / m end
    end
    return 1
end

function Module.getPart(inst)
    if inst:IsA("BasePart") then return inst end
    if inst:IsA("Model") then
        return inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart")
    end
    return nil
end

return Module
