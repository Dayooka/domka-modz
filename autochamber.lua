--[[
    autochamber.lua - Auto Gravity Chamber + Robot Training
    Config:  _G._AIO_Config.get("Chamber", key)

    Doksi 14.4 + 4.4 alapján:
    - RequestChamberAuto: automatikus kamra mód
    - RequestChamberGravity: gravitációs szint beállítás
    - ChamberAction: ismétlések küldése
    - RobotTrainingRequest: robot training XP farm
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

local R = {
    ChamberAuto    = getRemote("RequestChamberAuto"),
    ChamberGravity = getRemote("RequestChamberGravity"),
    ChamberAction  = getRemote("ChamberAction"),
    ChamberMenu    = getRemote("ChamberDrillMenu"),
    ChamberChoose  = getRemote("ChamberDrillChoose"),
    ChamberCue     = getRemote("ChamberDrillCue"),
    ChamberInput   = getRemote("ChamberDrillInput"),
    ChamberResult  = getRemote("ChamberDrillResult"),
    RobotRequest   = getRemote("RobotTrainingRequest"),
    RobotState     = getRemote("RobotTrainingState"),
    PlayerActive   = getRemote("PlayerActive"),
}

local S = { status="Idle", actions=0, xpSessions=0 }

local function jitterWait(base)
    task.wait(base + math.random() * 0.3)
end

local function runChamber()
    local delay = Cfg.get("Chamber","ACTION_DELAY") or 1.0

    -- PlayerActive jelzés (antidetect – jelezzük hogy "jelen vagyunk")
    if R.PlayerActive then
        pcall(function() R.PlayerActive:FireServer() end)
    end

    if Cfg.get("Chamber","USE_AUTO_MODE") then
        -- Auto mód: RequestChamberAuto – legegyszerűbb
        S.status = "Chamber Auto..."
        if R.ChamberAuto then
            pcall(function() R.ChamberAuto:FireServer() end)
        end
        jitterWait(delay)
    else
        -- Manuális mód: Gravity + Action küldés
        S.status = "Gravity beallitas..."
        if R.ChamberGravity then
            local level = Cfg.get("Chamber","GRAVITY_LEVEL") or 1
            pcall(function() R.ChamberGravity:FireServer(level) end)
        end
        jitterWait(delay * 0.5)

        S.status = "ChamberAction..."
        if R.ChamberAction then
            pcall(function() R.ChamberAction:FireServer() end)
        end
        jitterWait(delay)
    end

    S.actions     = S.actions + 1
    S.xpSessions  = S.xpSessions + 1
    S.status      = "Aktiv – " .. S.xpSessions .. " session"
end

local function runRobotTraining()
    S.status = "Robot Training..."
    if R.RobotRequest then
        pcall(function() R.RobotRequest:FireServer() end)
    end
    jitterWait(1.5)
    if R.RobotState then
        pcall(function() R.RobotState:FireServer() end)
    end
end

task.spawn(function()
    task.wait(2)
    while true do
        if not Cfg.get("Chamber","enabled") then
            S.status = "Kikapcsolva"
            task.wait(1)
        else
            local ok, err = pcall(runChamber)
            if not ok then
                S.status = "Hiba: " .. tostring(err)
                task.wait(3)
            end
            -- Emberi-szerű jitter a sessionök közt
            task.wait(0.5 + math.random() * 0.5)
        end
    end
end)

_G._AIO_Modules = _G._AIO_Modules or {}
_G._AIO_Modules["Chamber"] = {
    getStats = function()
        return {
            enabled     = Cfg.get("Chamber","enabled"),
            status      = S.status,
            actions     = S.actions,
            xpSessions  = S.xpSessions,
        }
    end
}

print("[AutoChamber] OK")
