-- ══════════════════════════════════════════════════════════════════════
local CFG = {
    TP_OFFSET_Y   = 3,
    TP_DELAY      = 0.30,
    MAX_RETRIES   = 4,
    RETRY_DELAY   = 0.18,
    AUTO_SUMMON   = false,
    LOOP          = true,
    EARTH = { "DragonBall_01","DragonBall_02","DragonBall_03",
              "DragonBall_04","DragonBall_05","DragonBall_06","DragonBall_07" },
    NAMEK = { "NamekDragonBall_01","NamekDragonBall_02","NamekDragonBall_03",
              "NamekDragonBall_04","NamekDragonBall_05","NamekDragonBall_06",
              "NamekDragonBall_07" },
    DEBUG = false,
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

local Remotes = require(RS.Modules.Remotes)
local function dbg(...) if CFG.DEBUG then print("[AutoDB]",...) end end

local EARTH_SET={} local NAMEK_SET={}
for _,n in ipairs(CFG.EARTH) do EARTH_SET[n]=true end
for _,n in ipairs(CFG.NAMEK) do NAMEK_SET[n]=true end

local function isDB(inst)
    return EARTH_SET[inst.Name] or NAMEK_SET[inst.Name]
end

local function getPart(inst)
    if inst:IsA("BasePart") then return inst end
    if inst:IsA("Model") then
        return inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart")
    end
end

local function findAll()
    local res={} local seen={}
    local function chk(i)
        if seen[i] or not i.Parent then return end; seen[i]=true
        if isDB(i) then
            local p=getPart(i)
            if p then
                table.insert(res,{inst=i, part=p, namek=NAMEK_SET[i.Name]~=nil})
            end
        end
    end
    for _,a in ipairs(workspace:GetChildren()) do
        chk(a)
        for _,b in ipairs(a:GetChildren()) do
            chk(b)
            for _,c in ipairs(b:GetChildren()) do chk(c) end
        end
    end
    return res
end

local RemFolder = RS:WaitForChild("Remotes",10)
local gatherMote = RemFolder and RemFolder:FindFirstChild("GatherMote")

local function tryPickup(ball)
    if gatherMote then
        pcall(function() gatherMote:FireServer(ball.inst) end)
        pcall(function() gatherMote:FireServer(ball.part) end)
    end
    for _,pp in ipairs(ball.inst:GetDescendants()) do
        if pp:IsA("ProximityPrompt") then pcall(fireproximityprompt,pp) end
    end
    if hrp and ball.part and ball.part.Parent then
        hrp.CFrame = ball.part.CFrame
        task.wait(0.04)
        hrp.CFrame = ball.part.CFrame + Vector3.new(0,CFG.TP_OFFSET_Y,0)
    end
end

local function exists(b) return b.part and b.part.Parent and b.inst and b.inst.Parent end

task.spawn(function()
    task.wait(1.5)
    while true do
        -- Globális GUI kapcsoló ellenőrzése
        if _G.KillAuraCFG and _G.KillAuraCFG.AUTO_DB_ENABLED == false then
            task.wait(1)
            continue
        end

        if not char or not hrp then task.wait(0.5); continue end
        local balls=findAll()

        if #balls==0 then
            if CFG.AUTO_SUMMON then
                local sumR=RemFolder and RemFolder:FindFirstChild("RequestSummon")
                if sumR then pcall(function() sumR:FireServer() end) end
            end
            if CFG.LOOP then task.wait(5); continue else break end
        end

        for _,ball in ipairs(balls) do
            if _G.KillAuraCFG and _G.KillAuraCFG.AUTO_DB_ENABLED == false then break end
            if not exists(ball) then continue end

            hrp.CFrame = ball.part.CFrame + Vector3.new(0,CFG.TP_OFFSET_Y,0)
            task.wait(0.06)

            for i=1,CFG.MAX_RETRIES do
                tryPickup(ball)
                task.wait(CFG.RETRY_DELAY)
                if not exists(ball) then break end
            end
            task.wait(CFG.TP_DELAY)
        end
        task.wait(1)
    end
end)

print("[AutoDragonBall] ✓ Betöltve és összekötve a Master GUI-val")
