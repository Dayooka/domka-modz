local Cfg    = require(script.Parent._Config)
local Shared = require(script.Parent._Shared)

local S = { status = "Idle", nextIn = 0, cycles = 0 }

local function invoke(name, ...) return Shared.invoke(name, ...) end

local function findFarm()
    return workspace:FindFirstChild("SenzuFarmLocal")
        or workspace:FindFirstChild("SenzuFarm")
        or workspace:FindFirstChild("KameHouse")
end

local function findPlots(farm)
    if not farm then return {} end
    local plots = {}
    for _, desc in ipairs(farm:GetDescendants()) do
        local low = desc.Name:lower()
        if desc:IsA("BasePart") or desc:IsA("Model") then
            if low:find("plot") or low:find("slot") or low:find("bed")
            or low:find("grown") or low:find("seedling") or low:find("seed")
            or low:find("adult") or low:find("midling") or low:find("seeding") then
                table.insert(plots, desc)
            end
        end
    end
    return plots
end

local function tpTo(obj)
    if not Cfg.get("Senzu","TP_TO_FARM") then return end
    local hrp  = Shared.getHRP(); if not hrp then return end
    local part = Shared.getPart(obj) or (obj:IsA("BasePart") and obj)
    if part then
        hrp.CFrame = part.CFrame + Vector3.new(0, Cfg.get("Senzu","TP_OFFSET_Y") or 4, 0)
        task.wait(0.2)
    end
end

local function runCycle()
    local cd = Cfg.get("Senzu","CALL_DELAY") or 0.55
    S.status = "Farm lekérése..."
    invoke("GetSenzuFarm"); task.wait(cd)

    local farm  = findFarm()
    local plots = findPlots(farm)
    if farm then tpTo(farm) end

    -- ARATÁS
    S.status = "Aratás..."
    invoke("RequestHarvest"); task.wait(cd)
    for _, plot in ipairs(plots) do
        local part = Shared.getPart(plot) or (plot:IsA("BasePart") and plot)
        if part then
            if Cfg.get("Senzu","TP_TO_FARM") then
                local hrp = Shared.getHRP()
                if hrp then hrp.CFrame = part.CFrame + Vector3.new(0,4,0) end
                task.wait(0.08)
            end
            invoke("RequestHarvestAt", part.Position)
            for _, pp in ipairs(plot:GetDescendants()) do
                if pp:IsA("ProximityPrompt") then pcall(fireproximityprompt, pp) end
            end
            task.wait(cd * 0.4)
        end
    end

    if not Cfg.get("Senzu","AUTO_REPLANT") then S.status = "Aratás kész!"; return end

    -- ÜLTETÉS
    S.status = "Ültetés..."; task.wait(cd)
    invoke("RequestPlant"); task.wait(cd)
    for _, plot in ipairs(plots) do
        local part = Shared.getPart(plot) or (plot:IsA("BasePart") and plot)
        if part then
            if Cfg.get("Senzu","TP_TO_FARM") then
                local hrp = Shared.getHRP()
                if hrp then hrp.CFrame = part.CFrame + Vector3.new(0,4,0) end
                task.wait(0.08)
            end
            invoke("RequestPlantAt", part.Position)
            for _, pp in ipairs(plot:GetDescendants()) do
                if pp:IsA("ProximityPrompt") then pcall(fireproximityprompt, pp) end
            end
            task.wait(cd * 0.4)
        end
    end
    S.cycles += 1
    S.status = "Kész! Ciklus #" .. S.cycles
end

task.spawn(function()
    task.wait(2)
    while true do
        if not Cfg.get("Senzu","enabled") then
            S.status = "Kikapcsolva"; task.wait(1); continue
        end
        local ok, err = pcall(runCycle)
        if not ok then S.status = "Hiba: " .. tostring(err) end
        local interval = Cfg.get("Senzu","CHECK_INTERVAL") or 25
        S.nextIn = tick() + interval
        task.wait(interval)
    end
end)

local Module = {}
function Module.getStats()
    return {
        enabled  = Cfg.get("Senzu","enabled"),
        status   = S.status,
        cycles   = S.cycles,
        nextIn   = math.max(0, math.floor(S.nextIn - tick())),
    }
end
print("[AutoSenzu] ✓")
return Module
