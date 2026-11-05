--[[
╔══════════════════════════════════════════════════════════════════════╗
║          AUTO SENZU FARM  (forráskód alapján)                       ║
╠══════════════════════════════════════════════════════════════════════╣
║  Pontos remote nevek (16. szekció alapján):                         ║
║    GetSenzuFarm (RF), RequestPlant (RF), RequestHarvest (RF)        ║
║    RequestPlantAt (RF), RequestHarvestAt (RF)                       ║
║  Workspace: SenzuFarmLocal (kliensoldali farm vizuális)             ║
║  Assets.Senzu: Grown, Seedling, Seed                                ║
║    + növények: Carrot, Onion, Tomato, Mushroom,                     ║
║      RedCabbage, Potato, Senzu – mind Seeding/Midling/Adult         ║
╚══════════════════════════════════════════════════════════════════════╝
]]

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

local function dbg(...) if CFG.DEBUG then print("[Senzu]",...) end end

-- GUI
local sg=Instance.new("ScreenGui"); sg.Name="Senzu_HUD"; sg.ResetOnSpawn=false
sg.IgnoreGuiInset=true; sg.Parent=LP:WaitForChild("PlayerGui")
local fr=Instance.new("Frame",sg)
fr.Size=UDim2.new(0,195,0,70); fr.Position=UDim2.new(1,-207,0.5,136)
fr.BackgroundColor3=Color3.fromRGB(5,14,6); fr.BackgroundTransparency=0.15; fr.BorderSizePixel=0
Instance.new("UICorner",fr).CornerRadius=UDim.new(0,10)
local stk=Instance.new("UIStroke",fr); stk.Color=Color3.fromRGB(60,200,80); stk.Thickness=1.4
local titleL=Instance.new("TextLabel",fr)
titleL.Size=UDim2.new(1,0,0,22); titleL.Position=UDim2.new(0,0,0,4)
titleL.BackgroundTransparency=1; titleL.Text="🌱 SENZU FARM"
titleL.TextColor3=Color3.fromRGB(80,220,100); titleL.Font=Enum.Font.GothamBold; titleL.TextSize=12
local statusL=Instance.new("TextLabel",fr)
statusL.Name="Status"; statusL.Size=UDim2.new(1,-8,0,14); statusL.Position=UDim2.new(0,4,0,26)
statusL.BackgroundTransparency=1; statusL.TextColor3=Color3.fromRGB(160,255,160)
statusL.Font=Enum.Font.Gotham; statusL.TextSize=11; statusL.TextXAlignment=Enum.TextXAlignment.Left
statusL.Text="Indítás..."
local timerL=Instance.new("TextLabel",fr)
timerL.Name="Timer"; timerL.Size=UDim2.new(1,-8,0,12); timerL.Position=UDim2.new(0,4,0,46)
timerL.BackgroundTransparency=1; timerL.TextColor3=Color3.fromRGB(100,180,100)
timerL.Font=Enum.Font.Gotham; timerL.TextSize=10; timerL.TextXAlignment=Enum.TextXAlignment.Left
timerL.Text=""

local function setStatus(s)
    if statusL then statusL.Text=s end
    print("[Senzu]",s)
end

-- Senzu farm megkeresése (SenzuFarmLocal a Workspace-ben – 13. szekció)
local function findFarm()
    -- Pontos név: "SenzuFarmLocal" (Workspace szekció)
    local farm = workspace:FindFirstChild("SenzuFarmLocal")
        or workspace:FindFirstChild("SenzuFarm")
        or workspace:FindFirstChild("KameHouse") -- alternatív location
    if farm then dbg("Farm megtalálva:",farm:GetFullName()) end
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
    setStatus("🔍 Farm lekérése...")
    -- GetSenzuFarm (RemoteFunction)
    local farmData = invokeRF("GetSenzuFarm")
    task.wait(CFG.CALL_DELAY)

    local farm  = findFarm()
    local plots = findPlots(farm)
    dbg("Parcellák:",#plots)
    if farm then tpTo(farm) end

    -- ARATÁS
    setStatus("🌾 Aratás...")
    invokeRF("RequestHarvest")
    task.wait(CFG.CALL_DELAY)

    for i,plot in ipairs(plots) do
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

    if not CFG.AUTO_REPLANT then setStatus("✅ Aratás kész!"); return end

    -- ÜLTETÉS
    setStatus("🌱 Ültetés...")
    task.wait(CFG.CALL_DELAY)
    invokeRF("RequestPlant")
    task.wait(CFG.CALL_DELAY)

    for i,plot in ipairs(plots) do
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

    setStatus("✅ Ciklus kész! Következő: "..CFG.CHECK_INTERVAL.."s")
end

task.spawn(function()
    task.wait(2)
    while true do
        local ok,err=pcall(runCycle)
        if not ok then setStatus("❌ Hiba: "..tostring(err)) end
        for i=CFG.CHECK_INTERVAL,1,-1 do
            if timerL then timerL.Text="⏱ Következő: "..i.."s" end
            task.wait(1)
        end
    end
end)

print("[AutoSenzu] ✓ betöltve | GetSenzuFarm + RequestPlant/Harvest/At")
