-- autolongevity.lua
-- A modul kódja be van építve – nem kell ReplicatedStorage.Modules.AutoLongevity

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local Cfg = _G._AIO_Config
if not Cfg then warn("[AutoLongevity] _Config nem talalhato!") ; return end

-- ════════════════════════════════════════════════════════════════
--  BEÉPÍTETT AutoLongevity MODUL
-- ════════════════════════════════════════════════════════════════
local AutoLongevity = {}

AutoLongevity.enabled            = false
AutoLongevity.healthThreshold    = 0.6
AutoLongevity.longevityThreshold = 0.6
AutoLongevity.usePods            = true
AutoLongevity.teleportToPod      = true
AutoLongevity.podOffset          = 5
AutoLongevity.podHeight          = 3
AutoLongevity.useRest            = true
AutoLongevity.checkInterval      = 1
AutoLongevity.healTimeout        = 180
AutoLongevity.fullCheckDelay     = 0.5
AutoLongevity.exitOffset         = 12
AutoLongevity.healing            = false
AutoLongevity.method             = nil
AutoLongevity.currentPod         = nil

local stopRequested         = false
local DEFAULT_MAX_LONGEVITY = 100
local POD_TAG               = "HealingPod"
local PROMPT_NAME           = "HealingPodPrompt"
local ADMIN_POD_ATTR        = "AdminPod"
local LocalPlayer           = Players.LocalPlayer

local function newSignal(name)
    local ev = Instance.new("BindableEvent")
    ev.Name   = name
    ev.Parent = script
    return ev
end

AutoLongevity.HealingStarted = newSignal("LongevityHealingStarted")
AutoLongevity.HealingEnded   = newSignal("LongevityHealingEnded")
AutoLongevity.StateChanged   = newSignal("LongevityStateChanged")

local function getCharacter() return LocalPlayer and LocalPlayer.Character end
local function getRoot()
    local c = getCharacter(); return c and c:FindFirstChild("HumanoidRootPart")
end
local function getHumanoid()
    local c = getCharacter(); return c and c:FindFirstChildOfClass("Humanoid")
end
local function getLongevityInfo()
    local hum   = getHumanoid()
    local stats = hum and hum:FindFirstChild("Stats")
    if stats then
        return stats:GetAttribute("Longevity") or 0,
               stats:GetAttribute("MaxLongevity") or DEFAULT_MAX_LONGEVITY
    end
    local c = getCharacter()
    return (c and c:GetAttribute("Longevity") or 0),
           (c and c:GetAttribute("MaxLongevity") or DEFAULT_MAX_LONGEVITY)
end
local function getHealthInfo()
    local hum = getHumanoid()
    if not hum then return 0, 1 end
    return hum.Health, math.max(hum.MaxHealth, 1)
end
local function isFullyHealed()
    local hp, maxHp   = getHealthInfo()
    local lon, maxLon = getLongevityInfo()
    return hp >= maxHp - 0.5 and lon >= maxLon - 0.5
end
local function needsHealing()
    local hp, maxHp   = getHealthInfo()
    local lon, maxLon = getLongevityInfo()
    return hp  < maxHp  * AutoLongevity.healthThreshold
        or lon < maxLon * AutoLongevity.longevityThreshold
end
local function isBusy()
    local c = getCharacter(); if not c then return true end
    for _, attr in { "CombatTag","Attacking","KiBlasting","Charging","Blocking",
                     "Casting","InCustomization","InGym","InRing","Praying",
                     "Fishing","Flying","Stunned" } do
        if c:GetAttribute(attr) then return true end
    end
    return false
end
local function getPodPrompt(pod)
    local p = pod:FindFirstChild(PROMPT_NAME, true)
    return (p and p:IsA("ProximityPrompt") and p.Enabled) and p or nil
end
local function findNearestPod()
    local root = getRoot(); if not root then return nil, nil, nil end
    local bestPod, bestPrompt, bestDist
    for _, pod in CollectionService:GetTagged(POD_TAG) do
        if pod:IsA("Model") and pod:GetAttribute(ADMIN_POD_ATTR) ~= true and pod.Parent then
            local prompt = getPodPrompt(pod)
            if prompt then
                local dist = (root.Position - pod:GetPivot().Position).Magnitude
                if not bestDist or dist < bestDist then
                    bestPod, bestPrompt, bestDist = pod, prompt, dist
                end
            end
        end
    end
    return bestPod, bestPrompt, bestDist
end
local function teleportToPod(pod)
    local root = getRoot(); if not root then return false end
    local podPos = pod:GetPivot().Position
    local flat   = Vector3.new(root.Position.X - podPos.X, 0, root.Position.Z - podPos.Z)
    if flat.Magnitude < 0.01 then flat = Vector3.new(1, 0, 0) end
    root.CFrame = CFrame.lookAt(
        podPos + flat.Unit * AutoLongevity.podOffset + Vector3.new(0, AutoLongevity.podHeight, 0),
        podPos + Vector3.new(0, 2, 0)
    )
    return true
end
local function triggerPrompt(prompt)
    prompt:InputHoldBegin()
    task.wait(prompt.HoldDuration + 0.15)
    prompt:InputHoldEnd()
end
local function exitPod(pod)
    local root = getRoot()
    if root and pod then
        root.CFrame = CFrame.new(pod:GetPivot().Position + Vector3.new(AutoLongevity.exitOffset, AutoLongevity.podHeight, 0))
        task.delay(1, function()
            local char = getCharacter()
            if char and char:GetAttribute("InHealingPod") then
                local p = pod.Parent and getPodPrompt(pod)
                if p then pcall(triggerPrompt, p) end
            end
        end)
    end
end
local function fireRest(params)
    local R = require(game:GetService("ReplicatedStorage").Modules.Remotes)
    R.PerformAction:FireServer("Rest", params)
end
local function waitUntilFull()
    local deadline = os.clock() + AutoLongevity.healTimeout
    while os.clock() < deadline do
        task.wait(AutoLongevity.fullCheckDelay)
        if stopRequested      then return "stopped" end
        if isFullyHealed()    then return "full"    end
        if not getCharacter() then return "timeout" end
    end
    return "timeout"
end
local function healWithPod()
    local pod, prompt = findNearestPod()
    if not pod or not prompt then return false, "no pod available" end
    AutoLongevity.currentPod = pod
    if AutoLongevity.teleportToPod and not stopRequested then
        teleportToPod(pod); task.wait(0.2)
    end
    local char = getCharacter(); if not char then return false, "no character" end
    if not char:GetAttribute("InHealingPod") then
        local fp = getPodPrompt(pod)
        if not fp then return false, "prompt unavailable" end
        if not pcall(triggerPrompt, fp) then return false, "prompt trigger failed" end
    end
    local result = waitUntilFull()
    exitPod(pod); AutoLongevity.currentPod = nil
    return result == "full", result
end
local function healWithRest()
    local char = getCharacter(); if not char then return false, "no character" end
    if not char:GetAttribute("Resting") then pcall(fireRest, { phase = "start" }) end
    local result = waitUntilFull()
    pcall(fireRest, { phase = "stop" })
    return result == "full", result
end

function AutoLongevity.healNow()
    if AutoLongevity.healing then return false, "already healing" end
    if isFullyHealed()       then return true,  "already full"   end
    AutoLongevity.healing = true; stopRequested = false
    local ok, reason
    if AutoLongevity.usePods then
        AutoLongevity.method = "pod"
        AutoLongevity.HealingStarted:Fire("pod")
        ok, reason = healWithPod()
        if not ok and reason == "no pod available" and AutoLongevity.useRest then
            AutoLongevity.method = "rest"
            AutoLongevity.HealingStarted:Fire("rest")
            ok, reason = healWithRest()
        end
    elseif AutoLongevity.useRest then
        AutoLongevity.method = "rest"
        AutoLongevity.HealingStarted:Fire("rest")
        ok, reason = healWithRest()
    else
        ok, reason = false, "healing disabled"
    end
    AutoLongevity.healing = false; AutoLongevity.method = nil
    AutoLongevity.HealingEnded:Fire(reason)
    return ok, reason
end
function AutoLongevity.stopHealing()
    if not AutoLongevity.healing then return end
    stopRequested = true
    local char = getCharacter()
    if char then
        if char:GetAttribute("Resting")      then pcall(fireRest, { phase = "stop" }) end
        if char:GetAttribute("InHealingPod") and AutoLongevity.currentPod then
            exitPod(AutoLongevity.currentPod)
        end
    end
end
function AutoLongevity.setEnabled(value)
    AutoLongevity.enabled = value == true
    AutoLongevity.StateChanged:Fire(AutoLongevity.enabled)
end

-- Auto figyelő
task.spawn(function()
    while true do
        task.wait(AutoLongevity.checkInterval)
        if AutoLongevity.enabled and not AutoLongevity.healing then
            local char = getCharacter()
            if char and not isBusy() and needsHealing() then
                task.spawn(function() pcall(AutoLongevity.healNow) end)
            end
        end
    end
end)

-- ════════════════════════════════════════════════════════════════
--  HÍDRÉSZ
-- ════════════════════════════════════════════════════════════════
local bridgeStats = {
    healed = 0, method = "-", status = "Készenlét",
    lastReason = "-", hp = "?", longevity = "?",
}

AutoLongevity.HealingStarted.Event:Connect(function(method)
    bridgeStats.method = method == "pod" and "Pod" or "Pihenés"
    bridgeStats.status = "Gyógyul: " .. bridgeStats.method
end)
AutoLongevity.HealingEnded.Event:Connect(function(reason)
    bridgeStats.lastReason = reason or "-"
    if reason == "full" then
        bridgeStats.healed += 1
        bridgeStats.status = "Teli! (" .. bridgeStats.healed .. "x)"
    elseif reason == "stopped" then bridgeStats.status = "Leállítva"
    elseif reason == "timeout" then bridgeStats.status = "Idő lejárt"
    else                             bridgeStats.status = "Készenlét" end
    bridgeStats.method = "-"
end)

task.spawn(function()
    while true do
        task.wait(0.5)
        pcall(function()
            local char = LocalPlayer.Character; if not char then return end
            local hum  = char:FindFirstChildOfClass("Humanoid")
            if hum and hum.MaxHealth > 0 then
                bridgeStats.hp = string.format("%.0f", (hum.Health / hum.MaxHealth) * 100)
            end
            local lon, maxLon = getLongevityInfo()
            if maxLon > 0 then
                bridgeStats.longevity = string.format("%.0f", (lon / maxLon) * 100)
            end
        end)
    end
end)

local SYNC_KEYS = {
    "healthThreshold","longevityThreshold","usePods","teleportToPod",
    "podOffset","podHeight","useRest","checkInterval","healTimeout","exitOffset",
}
local function syncToModule()
    AutoLongevity.setEnabled(Cfg.get("AutoLongevity","enabled") == true)
    for _, key in ipairs(SYNC_KEYS) do
        local val = Cfg.get("AutoLongevity", key)
        if val ~= nil then AutoLongevity[key] = val end
    end
end
syncToModule()

Cfg.onChange(function(mod, key, val)
    if mod ~= "AutoLongevity" then return end
    if key == "enabled" then
        AutoLongevity.setEnabled(val == true)
        bridgeStats.status = val and "Aktív" or "Kikapcsolva"
    else
        AutoLongevity[key] = val
    end
end)

_G._AIO_Modules = _G._AIO_Modules or {}
_G._AIO_Modules["AutoLongevity"] = {
    getStats = function()
        return {
            healed     = bridgeStats.healed,
            method     = bridgeStats.method,
            status     = bridgeStats.status,
            lastReason = bridgeStats.lastReason,
            hp         = bridgeStats.hp,
            longevity  = bridgeStats.longevity,
            isHealing  = AutoLongevity.healing or false,
        }
    end,
    healNow     = function() return AutoLongevity.healNow() end,
    stopHealing = function() AutoLongevity.stopHealing() end,
}

print("[AutoLongevity] OK")
