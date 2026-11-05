-- ══════════════════════════════════════════════════════════════════════
local CFG = {
    CALL_DELAY      = 0.55,
    CHECK_INTERVAL  = 25,
    AUTO_REPLANT    = true,
    TP_TO_FARM      = true,
    TP_OFFSET_Y     = 4,
    DEBUG           = false,
}

local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")
local LP      = Players.LocalPlayer
local char    = LP.Character or LP.CharacterAdded:Wait()
local hum     = char:WaitForChild("Humanoid")
local hrp     = char:WaitForChild("HumanoidRootPart")

LP.CharacterAdded:Connect(function(c)
    char=c; hum=c:WaitForChild("Humanoid"); hrp=c:WaitForChild("HumanoidRootPart")
end)

local RemFolder = RS:WaitForChild("Remotes",10)
local function getRemote(name)
    return RemFolder and RemFolder:FindFirstChild(name)
end

local function invokeRF(name,...)
    local r=getRemote(name); if not r then return nil end
    local ok,res=pcall(function(...)
        return r:IsA("RemoteFunction") and r:InvokeServer(...)
            or (r:FireServer(...) or true)
    end,...)
    return ok and res or nil
end

local function findFarm()
    local farm = workspace:FindFirstChild("SenzuFarmLocal")
        or workspace:FindFirstChild("SenzuFarm")
        or workspace:FindFirstChild("KameHouse")
    return farm
end

local function findPlots(farm)
    if not farm then return {} end
    local plots={}
    for _,desc in ipairs(farm:GetDescendants()) do
        local low=desc.Name:lower()
        if desc:IsA("BasePart") or desc:IsA("Model") then
            if low:find("plot") or low:find("slot") or low:find("bed")
            or low:find("grown") or low:find("seedling") or low:find("seed")
            or low:find("adult") or low:find("midling") or low:find("seeding") then
                table.insert(plots,desc)
            end
        end
    end
    return plots
end

local function tpTo(obj)
    if not CFG.TP_TO_FARM or not hrp then return end
    local part = obj.PrimaryPart or (obj:IsA("BasePart") and obj)
        or obj:FindFirstChildWhichIsA("BasePart")
    if part then
        hrp.CFrame = part.CFrame + Vector3.new(0,CFG.TP_OFFSET_Y,0)
        task.wait(0.2)
    end
end

local function runCycle()
    if _G.KillAuraCFG and _G.KillAuraCFG.AUTO_SENZU_ENABLED == false then return end

    invokeRF("GetSenzuFarm")
    task.wait(CFG.CALL_DELAY)

    local farm  = findFarm()
    local plots = findPlots(farm)
    if farm then tpTo(farm) end

    invokeRF("RequestHarvest")
    task.wait(CFG.CALL_DELAY)

    for _,plot in ipairs(plots) do
        local part = plot:IsA("BasePart") and plot
            or (plot:IsA("Model") and (plot.PrimaryPart or plot:FindFirstChildWhichIsA("BasePart")))
        if part then
            if CFG.TP_TO_FARM and hrp then
                hrp.CFrame = part.CFrame + Vector3.new(0,CFG.TP_OFFSET_Y,0)
                task.wait(0.08)
            end
            invokeRF("RequestHarvestAt", part.Position)
            for _,pp in ipairs(plot:GetDescendants()) do
                if pp:IsA("ProximityPrompt") then pcall(fireproximityprompt,pp) end
            end
            task.wait(CFG.CALL_DELAY * 0.4)
        end
    end

    if not CFG.AUTO_REPLANT then return end

    invokeRF("RequestPlant")
    task.wait(CFG.CALL_DELAY)

    for _,plot in ipairs(plots) do
        local part = plot:IsA("BasePart") and plot
            or (plot:IsA("Model") and (plot.PrimaryPart or plot:FindFirstChildWhichIsA("BasePart")))
        if part then
            if CFG.TP_TO_FARM and hrp then
                hrp.CFrame = part.CFrame + Vector3.new(0,CFG.TP_OFFSET_Y,0)
                task.wait(0.08)
            end
            invokeRF("RequestPlantAt", part.Position)
            for _,pp in ipairs(plot:GetDescendants()) do
                if pp:IsA("ProximityPrompt") then pcall(fireproximityprompt,pp) end
            end
            task.wait(CFG.CALL_DELAY * 0.4)
        end
    end
end

task.spawn(function()
    task.wait(2)
    while true do
        if _G.KillAuraCFG and _G.KillAuraCFG.AUTO_SENZU_ENABLED == false then
            task.wait(2)
            continue
        end

        pcall(runCycle)
        for i = CFG.CHECK_INTERVAL, 1, -1 do
            if _G.KillAuraCFG and _G.KillAuraCFG.AUTO_SENZU_ENABLED == false then break end
            task.wait(1)
        end
    end
end)

print("[AutoSenzu] ✓ Betöltve és összekötve a Master GUI-val")
