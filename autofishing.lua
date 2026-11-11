--[[
    autofishing.lua - Auto Fishing
    Config:  _G._AIO_Config.get("Fishing", key)

    Doksi 14.4.B + 4.9 alapján:
    - Horgász szekvencia: FishingBait → FishingBite → FishingInput → FishingOutcome
    - Emberi-szerű timing + jitter az antidetect miatt
    - Pozíció kötelezés: a horgász helyen kell lenni
]]

local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")

local Cfg    = _G._AIO_Config
local Shared = _G._AIO_Shared
local LP     = Players.LocalPlayer

local RemFolder = RS:WaitForChild("Remotes", 10)
local function getRemote(name)
    return RemFolder and RemFolder:FindFirstChild(name)
end

-- Fishing remote-ok (doksi 4.9 alapján)
local R = {
    Bait    = getRemote("FishingBait")    or getRemote("FishingStarted"),
    Bite    = getRemote("FishingBite"),
    Input   = getRemote("FishingInput"),
    Outcome = getRemote("FishingOutcome"),
    Leap    = getRemote("FishingLeap"),
    Leave   = getRemote("FishingLeave"),
    Started = getRemote("FishingStarted"),
    Ended   = getRemote("FishingEnded"),
    Career  = getRemote("FishingCareer"),
}

local S = { status="Idle", caught=0, session=0 }
local sessionActive = false

-- Jitter helper (emberi-szerű timing)
local function jitterWait(base, jitter)
    local j = jitter or Cfg.get("Fishing","JITTER") or 0.15
    task.wait(base + (math.random() * j * 2 - j))
end

-- Fishing szekvencia (doksi: "Bait -> Bite -> Input -> Outcome")
local function runFishingSession()
    local delay = Cfg.get("Fishing","SEQUENCE_DELAY") or 0.3

    -- 1. Bait (dobás)
    S.status = "Bait..."
    if R.Bait then pcall(function() R.Bait:FireServer() end) end
    jitterWait(delay)

    -- 2. Bite (kapás várakozás – szerver jelzi, mi elfogadjuk)
    S.status = "Varakozas kaplasra..."
    -- Nem küldünk semmit – várunk a szerver OnClientEvent-re
    -- de van egy timeout
    jitterWait(delay * 3, 0.5)

    -- 3. Input (húzás timing)
    S.status = "Input..."
    if R.Input then pcall(function() R.Input:FireServer() end) end
    jitterWait(delay)

    -- 4. Outcome (eredmény)
    S.status = "Outcome..."
    if R.Outcome then pcall(function() R.Outcome:FireServer() end) end
    jitterWait(delay)

    S.caught   = S.caught + 1
    S.session  = S.session + 1
    S.status   = "Fogva: " .. S.caught
end

-- Bite event listener (ha a szerver jelzi a kapást)
if R.Bite then
    R.Bite.OnClientEvent:Connect(function()
        if not Cfg.get("Fishing","enabled") or not sessionActive then return end
        S.status = "KAPL! Input..."
        task.wait(0.1 + math.random() * 0.2)  -- emberi reakcióidő
        if R.Input then pcall(function() R.Input:FireServer() end) end
    end)
end

-- Fő loop
task.spawn(function()
    task.wait(2)
    while true do
        task.wait(2 + math.random())  -- emberi-szerű várakozás
        if not Cfg.get("Fishing","enabled") then
            S.status = "Kikapcsolva"
            sessionActive = false
        else
            sessionActive = true
            local ok, err = pcall(runFishingSession)
            if not ok then
                S.status = "Hiba: " .. tostring(err)
                task.wait(3)
            end
        end
    end
end)

_G._AIO_Modules = _G._AIO_Modules or {}
_G._AIO_Modules["Fishing"] = {
    getStats = function()
        return {
            enabled = Cfg.get("Fishing","enabled"),
            status  = S.status,
            caught  = S.caught,
        }
    end
}

print("[AutoFishing] OK")
