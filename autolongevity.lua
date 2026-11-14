-- autolongevity.lua
-- Híd: AutoLongevity modul <-> _AIO_Config <-> GUI
-- Regisztrálja _G._AIO_Modules["AutoLongevity"]-t a stat frissítőhöz

local Players = game:GetService("Players")
local LP      = Players.LocalPlayer

local Cfg = _G._AIO_Config
if not Cfg then
    warn("[AutoLongevity] _Config nem talalhato!")
    return
end

-- ── AutoLongevity modul (Executor verzió - Biztonságos fallback) ──
local AutoLongevity = {}
AutoLongevity.enabled = false
AutoLongevity.healing = false

-- BindableEventek a jelzésekhez (ha még nincsenek a játékban)
AutoLongevity.HealingStarted = Instance.new("BindableEvent")
AutoLongevity.HealingEnded = Instance.new("BindableEvent")

function AutoLongevity.setEnabled(state)
    AutoLongevity.enabled = state
    print("[AutoLongevity] Állapot megváltozott:", state)
end

function AutoLongevity.healNow()
    print("[AutoLongevity] Kézi gyógyulás indítva...")
    AutoLongevity.healing = true
    AutoLongevity.HealingStarted:Fire("pod")
    -- Ide jöhet a tényleges gyógyulási logika vagy rutinhoz kötött hívás
end

function AutoLongevity.stopHealing()
    AutoLongevity.healing = false
    AutoLongevity.HealingEnded:Fire("stopped")
end

-- ── Stat számlálók ────────────────────────────────────────────────
local stats = {
    healed     = 0,
    method     = "-",
    status     = "Készenlét",
    lastReason = "-",
    hp         = "?",
    longevity  = "?",
}

-- HP és Longevity % frissítő helper
local function refreshVitals()
    local char = LP.Character
    if not char then
        stats.hp        = "?"
        stats.longevity = "?"
        return
    end

    -- Health
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum and hum.MaxHealth > 0 then
        stats.hp = string.format("%.0f", (hum.Health / hum.MaxHealth) * 100)
    end

    -- Longevity (Humanoid > Stats gyerek)
    local humStats = hum and hum:FindFirstChild("Stats")
    if humStats then
        local lon    = humStats:GetAttribute("Longevity")    or 0
        local maxLon = humStats:GetAttribute("MaxLongevity") or 100
        if maxLon > 0 then
            stats.longevity = string.format("%.0f", (lon / maxLon) * 100)
        end
    else
        -- Ha nincs Stats gyerek, próbáljuk a karakter attribútumaiból
        local lon    = char:GetAttribute("Longevity")    or 0
        local maxLon = char:GetAttribute("MaxLongevity") or 100
        if maxLon > 0 then
            stats.longevity = string.format("%.0f", (lon / maxLon) * 100)
        end
    end
end

-- ── Signal összekötés ─────────────────────────────────────────────
AutoLongevity.HealingStarted.Event:Connect(function(method)
    stats.method = method == "pod" and "Pod" or "Pihenés"
    stats.status = "Gyógyul: " .. stats.method
end)

AutoLongevity.HealingEnded.Event:Connect(function(reason)
    stats.lastReason = reason or "-"
    if reason == "full" then
        stats.healed = stats.healed + 1
        stats.status = "Teli! (" .. stats.healed .. "x)"
    elseif reason == "stopped" then
        stats.status = "Leállítva"
    elseif reason == "timeout" then
        stats.status = "Idő lejárt"
    else
        stats.status = "Készenlét"
    end
    stats.method = "-"
end)

-- ── Config szinkronizált kulcsok ──────────────────────────────────
local SYNC_KEYS = {
    "healthThreshold",
    "longevityThreshold",
    "usePods",
    "teleportToPod",
    "podOffset",
    "podHeight",
    "useRest",
    "checkInterval",
    "healTimeout",
    "exitOffset",
}

local function syncToModule()
    local enabled = Cfg.get("AutoLongevity", "enabled") == true
    AutoLongevity.setEnabled(enabled)
    stats.status = enabled and "Aktív" or "Kikapcsolva"

    for _, key in ipairs(SYNC_KEYS) do
        local val = Cfg.get("AutoLongevity", key)
        if val ~= nil then
            AutoLongevity[key] = val
        end
    end
end

-- Első szinkron betöltéskor
syncToModule()

-- Config változáskor → frissítés
Cfg.onChange(function(mod, key, val)
    if mod ~= "AutoLongevity" then return end
    if key == "enabled" then
        AutoLongevity.setEnabled(val == true)
        stats.status = val and "Aktív" or "Kikapcsolva"
    else
        AutoLongevity[key] = val
    end
end)

-- ── Vitals frissítő loop ──────────────────────────────────────────
task.spawn(function()
    while true do
        task.wait(0.5)
        pcall(refreshVitals)
    end
end)

-- ── _G._AIO_Modules regisztráció ─────────────────────────────────
_G._AIO_Modules = _G._AIO_Modules or {}

_G._AIO_Modules["AutoLongevity"] = {

    -- GUI stat paragraph frissítéséhez
    getStats = function()
        return {
            healed     = stats.healed,
            method     = stats.method,
            status     = stats.status,
            lastReason = stats.lastReason,
            hp         = stats.hp,
            longevity  = stats.longevity,
            isHealing  = AutoLongevity.healing or false,
        }
    end,

    -- Kézi gyógyulás indítása más scriptekből
    healNow = function()
        return AutoLongevity.healNow()
    end,

    -- Kézi leállítás
    stopHealing = function()
        AutoLongevity.stopHealing()
    end,
}

print("[AutoLongevity] OK")
