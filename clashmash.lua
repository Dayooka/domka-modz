--[[
    clashmash.lua - Auto MeleeClashMash + BeamClashMash
    Config:  _G._AIO_Config.get("MeleeClashMash", key)

    Doksi 14.2.C alapján:
    - Clash közben MeleeClashMash/BeamClashMash spam → mindig megnyeri
    - MASH_VALUE: emberi max ~15-20 CPS, mi 50-et küldünk
    - Trigger: MeleeClashVanish vagy InClash attribútum
]]

local Players    = game:GetService("Players")
local RS         = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Cfg    = _G._AIO_Config
local Shared = _G._AIO_Shared
local LP     = Players.LocalPlayer

local RemFolder = RS:WaitForChild("Remotes", 10)
local function getRemote(name)
    return RemFolder and RemFolder:FindFirstChild(name)
end

local meleeMashRemote = getRemote("MeleeClashMash")
local beamMashRemote  = getRemote("BeamClashMash")
local beamSurgeRemote = getRemote("BeamClashSurge")

local S = { status="Idle", mashCount=0, wins=0 }
local inClash   = false
local clashTask = nil

local function stopClash()
    inClash = false
    if clashTask then
        task.cancel(clashTask)
        clashTask = nil
    end
    S.status = "Idle"
end

local function startClash(clashType)
    if inClash then return end
    if not Cfg.get("MeleeClashMash","enabled") then return end

    inClash = true
    S.status = "CLASH – " .. (clashType or "Melee")

    clashTask = task.spawn(function()
        local mashValue = Cfg.get("MeleeClashMash","MASH_VALUE") or 50
        local mashDelay = Cfg.get("MeleeClashMash","MASH_DELAY") or 0.05

        while inClash and Cfg.get("MeleeClashMash","enabled") do
            local char = Shared.getChar()
            if not char then break end

            -- InClash attribútum ellenőrzés
            if not char:GetAttribute("InClash") then
                break
            end

            -- Mash küldés típus alapján
            if clashType == "Beam" then
                if beamMashRemote then
                    pcall(function() beamMashRemote:FireServer(mashValue) end)
                end
                if beamSurgeRemote then
                    pcall(function() beamSurgeRemote:FireServer() end)
                end
            else
                -- Melee clash
                if meleeMashRemote then
                    pcall(function() meleeMashRemote:FireServer(mashValue) end)
                end
            end

            S.mashCount = S.mashCount + 1
            task.wait(mashDelay)
        end

        inClash = false
        S.status = "Idle"
    end)
end

-- InClash attribútum figyelő
local function attachClashListener(char)
    char:GetAttributeChangedSignal("InClash"):Connect(function()
        if not Cfg.get("MeleeClashMash","enabled") then return end
        local val = char:GetAttribute("InClash")
        if val then
            startClash("Melee")
        else
            stopClash()
        end
    end)

    -- BeamClash is figyelünk
    char:GetAttributeChangedSignal("InBeamClash"):Connect(function()
        if not Cfg.get("MeleeClashMash","enabled") then return end
        local val = char:GetAttribute("InBeamClash")
        if val then
            startClash("Beam")
        else
            stopClash()
        end
    end)
end

-- MeleeClashVanish remote listener (clash lehetőség jelzés)
local mcvRemote = getRemote("MeleeClashVanish")
if mcvRemote then
    mcvRemote.OnClientEvent:Connect(function()
        if Cfg.get("MeleeClashMash","enabled") then
            startClash("Melee")
        end
    end)
end

local char = LP.Character or LP.CharacterAdded:Wait()
attachClashListener(char)

LP.CharacterAdded:Connect(function(c)
    char = c
    stopClash()
    attachClashListener(c)
end)

_G._AIO_Modules = _G._AIO_Modules or {}
_G._AIO_Modules["MeleeClashMash"] = {
    getStats = function()
        return {
            enabled   = Cfg.get("MeleeClashMash","enabled"),
            status    = S.status,
            mashCount = S.mashCount,
            inClash   = inClash,
        }
    end
}

print("[ClashMash] OK")
