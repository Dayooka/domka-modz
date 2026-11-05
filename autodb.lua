--[[
╔══════════════════════════════════════════════════════════════════════╗
║          AUTO DRAGON BALL COLLECTOR  (forráskód alapján)            ║
╠══════════════════════════════════════════════════════════════════════╣
║  Pontos nevek (Assets.EarthDragonBalls / NamekDragonBalls alapján): ║
║    DragonBall_01..07, NamekDragonBall_01..07 (nem "Namek")          ║
║  Felvétel: GatherMote RemoteEvent (nem RemoteFunction!)             ║
║    + ProximityPrompt (NPC fejénél ProximityPrompt van a doksi szerint)║
║  RequestSummon – sárkány hívás (Egyéb remote lista alapján)         ║
║  Workspace mappák: LootDrops, MapLoot, WorldDrops, IngredientPickups║
╚══════════════════════════════════════════════════════════════════════╝
]]

local CFG = {
    TP_OFFSET_Y   = 3,
    TP_DELAY      = 0.30,
    MAX_RETRIES   = 4,
    RETRY_DELAY   = 0.18,
    AUTO_SUMMON   = false,
    LOOP          = true,
    -- Pontos nevek a forrásból
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

-- Pontos name lookup
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

-- GUI
local sg=Instance.new("ScreenGui"); sg.Name="AutoDB_HUD"; sg.ResetOnSpawn=false
sg.IgnoreGuiInset=true; sg.Parent=LP:WaitForChild("PlayerGui")
local fr=Instance.new("Frame",sg)
fr.Size=UDim2.new(0,200,0,80); fr.Position=UDim2.new(1,-212,0.5,-40)
fr.BackgroundColor3=Color3.fromRGB(6,6,10); fr.BackgroundTransparency=0.15; fr.BorderSizePixel=0
Instance.new("UICorner",fr).CornerRadius=UDim.new(0,10)
local stk=Instance.new("UIStroke",fr); stk.Color=Color3.fromRGB(255,170,0); stk.Thickness=1.5
local titleL=Instance.new("TextLabel",fr)
titleL.Size=UDim2.new(1,0,0,22); titleL.Position=UDim2.new(0,0,0,4)
titleL.BackgroundTransparency=1; titleL.Text="🔮 AUTO DRAGON BALL"
titleL.TextColor3=Color3.fromRGB(255,195,30); titleL.Font=Enum.Font.GothamBold; titleL.TextSize=12
local statL=Instance.new("TextLabel",fr)
statL.Name="Stat"; statL.Size=UDim2.new(1,-8,0,16); statL.Position=UDim2.new(0,4,0,26)
statL.BackgroundTransparency=1; statL.TextColor3=Color3.fromRGB(160,220,255)
statL.Font=Enum.Font.Gotham; statL.TextSize=11; statL.TextXAlignment=Enum.TextXAlignment.Left
statL.Text="🌍0/7  💚0/7"
local statusL=Instance.new("TextLabel",fr)
statusL.Name="Status"; statusL.Size=UDim2.new(1,-8,0,14); statusL.Position=UDim2.new(0,4,0,46)
statusL.BackgroundTransparency=1; statusL.TextColor3=Color3.fromRGB(200,200,200)
statusL.Font=Enum.Font.Gotham; statusL.TextSize=10; statusL.TextXAlignment=Enum.TextXAlignment.Left
statusL.Text="Keresés..."

local ec,nc=0,0
local function updGui(status)
    if statL then statL.Text="🌍"..ec.."/7  💚"..nc.."/7" end
    if statusL and status then statusL.Text=status end
end

-- GatherMote – a forrás szerint ez RemoteEvent (nem Function!)
local RemFolder = RS:WaitForChild("Remotes",10)
local gatherMote = RemFolder and RemFolder:FindFirstChild("GatherMote")

local function tryPickup(ball)
    -- 1. GatherMote RemoteEvent
    if gatherMote then
        pcall(function() gatherMote:FireServer(ball.inst) end)
        pcall(function() gatherMote:FireServer(ball.part) end)
    end
    -- 2. ProximityPrompt
    for _,pp in ipairs(ball.inst:GetDescendants()) do
        if pp:IsA("ProximityPrompt") then pcall(fireproximityprompt,pp) end
    end
    -- 3. Touch
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
        if not char or not hrp then task.wait(0.5); continue end
        local balls=findAll()
        ec,nc=0,0
        for _,b in ipairs(balls) do if b.namek then nc+=1 else ec+=1 end end

        if #balls==0 then
            updGui("✅ Minden megvan!")
            if CFG.AUTO_SUMMON then
                local sumR=RemFolder and RemFolder:FindFirstChild("RequestSummon")
                if sumR then pcall(function() sumR:FireServer() end) end
            end
            if CFG.LOOP then task.wait(5); continue else break end
        end

        for _,ball in ipairs(balls) do
            if not exists(ball) then continue end
            local icon=ball.namek and "💚" or "🌍"
            updGui(icon.." TP → "..ball.inst.Name)

            -- Teleport
            hrp.CFrame = ball.part.CFrame + Vector3.new(0,CFG.TP_OFFSET_Y,0)
            task.wait(0.06)

            -- Pickup kísérletek
            for i=1,CFG.MAX_RETRIES do
                tryPickup(ball)
                task.wait(CFG.RETRY_DELAY)
                if not exists(ball) then
                    if ball.namek then nc-=1 else ec-=1 end
                    dbg("✓ Felvéve:",ball.inst.Name,"("..i..". próba)")
                    break
                end
            end
            task.wait(CFG.TP_DELAY)
            updGui(nil)
        end
        task.wait(1)
    end
end)

print("[AutoDragonBall] ✓ betöltve | Earth:",#CFG.EARTH,"Namek:",#CFG.NAMEK)
