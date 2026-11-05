--[[
╔══════════════════════════════════════════════════════════════════════╗
║          AUTO NPC KILL FARM  (forráskód alapján)                    ║
╠══════════════════════════════════════════════════════════════════════╣
║  Pontos értékek:                                                     ║
║    Entities.Tag.NPC = "NPC" (CollectionService tag)                 ║
║    Entities.Folder.NPC = "NPCs" (Workspace.NPCs mappa)              ║
║    WorldNPCs: RedRibbon_HQYard, RedRibbon_OutpostYard, Civilians_*  ║
║    MELEE_APPROACH_MAX = 24 studs                                     ║
║    MELEE_FIST_REACH   = 3.8 studs                                   ║
║    CombatStylePublic: CHAIN_CAP=8, LIGHTS_PER_STRING=4              ║
║    Combo: LightAttack x4 → HeavyAttack (Rush: LLMD)                 ║
║    Grab: minInterval=0.3, phase=start→stop                          ║
║    ActionConfig: LightAttack blockedBy AttackCooldown               ║
╚══════════════════════════════════════════════════════════════════════╝
]]

local CFG = {
    -- Támadás timing (CombatStylePublic CHAIN_CAP=8 alapján)
    LIGHT_COUNT      = 4,      -- LIGHTS_PER_STRING = 4
    HEAVY_AFTER_LIGHT= true,   -- Rush combo: LLMD
    GRAB_ENABLED     = true,   -- Grab + execute
    GRAB_HOLD        = 0.32,   -- minInterval = 0.3 + kis buffer

    -- Cooldown-ok
    ATTACK_CD        = 0.18,   -- LightAttack cooldown becslés
    COMBO_DELAY      = 0.22,   -- lépések között

    -- Távolság (CombatPublic alapján)
    -- meleeApproachStop = MELEE_APPROACH_MAX - gap → ~20 studs stop
    ATTACK_RANGE     = 6,      -- ennyire kell megközelíteni
    TELEPORT_TO_NPC  = true,   -- teleportál az NPC mellé
    TP_OFFSET        = Vector3.new(0, 1, 2),

    -- NPC keresés
    -- WorldNPCs al-mappák (13. szekció alapján)
    WORLD_NPC_ZONES  = {
        "RedRibbon_HQYard", "RedRibbon_OutpostYard",
        "Civilians_CentralCity","Civilians_WestCity","Civilians_SouthCity",
        "Civilians_SatanCity","Civilians_EastCity","Civilians_NorthCity",
        "Civilians_LaccoVillage","Civilians_JingleVillage",
    },
    -- Root level NPC-k (boss-szintű, erősebbek = több XP)
    ROOT_NPCS        = {
        "Hercule","Piccolo","Krillin","Yamcha","Tien",
        "Red Ribbon Soldier","Vegeta",
    },
    PREFER_ROOT      = false,  -- true = erős NPC-ket preferálja

    -- Scan
    SCAN_RANGE       = 150,    -- studs – ennyire keres NPC-t
    LOOP_DELAY       = 0.5,

    DEBUG = false,
}

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local CS         = game:GetService("CollectionService")
local RS         = game:GetService("ReplicatedStorage")

local Remotes      = require(RS.Modules.Remotes)
local ActionState  = require(RS.Modules.ActionState)
local Entities     = require(RS.Modules.Entities)
local CombatPublic = require(RS.Modules.CombatPublic)

local LP   = Players.LocalPlayer
local char = LP.Character or LP.CharacterAdded:Wait()
local hum  = char:WaitForChild("Humanoid")
local hrp  = char:WaitForChild("HumanoidRootPart")

LP.CharacterAdded:Connect(function(c)
    char=c; hum=c:WaitForChild("Humanoid"); hrp=c:WaitForChild("HumanoidRootPart")
end)

local function dbg(...) if CFG.DEBUG then print("[NPCFarm]",...) end end

-- GUI
local sg=Instance.new("ScreenGui"); sg.Name="NPCFarm_HUD"; sg.ResetOnSpawn=false
sg.IgnoreGuiInset=true; sg.Parent=LP:WaitForChild("PlayerGui")
local fr=Instance.new("Frame",sg)
fr.Size=UDim2.new(0,200,0,90); fr.Position=UDim2.new(0,12,0,252)
fr.BackgroundColor3=Color3.fromRGB(14,4,4); fr.BackgroundTransparency=0.15; fr.BorderSizePixel=0
Instance.new("UICorner",fr).CornerRadius=UDim.new(0,10)
local stk=Instance.new("UIStroke",fr); stk.Color=Color3.fromRGB(255,60,60); stk.Thickness=1.4
local titleL=Instance.new("TextLabel",fr)
titleL.Size=UDim2.new(1,0,0,22); titleL.Position=UDim2.new(0,0,0,4)
titleL.BackgroundTransparency=1; titleL.Text="⚔ AUTO NPC FARM"
titleL.TextColor3=Color3.fromRGB(255,80,80); titleL.Font=Enum.Font.GothamBold; titleL.TextSize=12
local targetL=Instance.new("TextLabel",fr)
targetL.Name="Target"; targetL.Size=UDim2.new(1,-8,0,16); targetL.Position=UDim2.new(0,4,0,26)
targetL.BackgroundTransparency=1; targetL.TextColor3=Color3.fromRGB(255,160,160)
targetL.Font=Enum.Font.Gotham; targetL.TextSize=11; targetL.TextXAlignment=Enum.TextXAlignment.Left
targetL.Text="Célpont: -"
local statL=Instance.new("TextLabel",fr)
statL.Name="Stat"; statL.Size=UDim2.new(1,-8,0,14); statL.Position=UDim2.new(0,4,0,44)
statL.BackgroundTransparency=1; statL.TextColor3=Color3.fromRGB(200,160,160)
statL.Font=Enum.Font.Gotham; statL.TextSize=10; statL.TextXAlignment=Enum.TextXAlignment.Left
statL.Text="Kills: 0"
local comboL=Instance.new("TextLabel",fr)
comboL.Name="Combo"; comboL.Size=UDim2.new(1,-8,0,14); comboL.Position=UDim2.new(0,4,0,60)
comboL.BackgroundTransparency=1; comboL.TextColor3=Color3.fromRGB(255,200,100)
comboL.Font=Enum.Font.Gotham; comboL.TextSize=10; comboL.TextXAlignment=Enum.TextXAlignment.Left
comboL.Text="Combo: -"

local kills=0
local function updGui(target,combo)
    if targetL and target then targetL.Text="Célpont: "..target end
    if statL then statL.Text="Kills: "..kills end
    if comboL and combo then comboL.Text="Combo: "..combo end
end

-- ══════════════════════════════════════════
-- NPC KERESÉS (pontos Entities API alapján)
-- ══════════════════════════════════════════
local function getNPCs()
    if not hrp then return {} end
    local res={}
    -- Entities.Tag.NPC = "NPC"
    for _, npc in ipairs(CS:GetTagged(Entities.Tag.NPC)) do
        if npc:IsA("Model") and npc:IsDescendantOf(workspace) then
            local h=npc:FindFirstChildOfClass("Humanoid")
            local r=npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChild("Torso")
            if h and h.Health>0 and r then
                local d=(r.Position-hrp.Position).Magnitude
                if d<=CFG.SCAN_RANGE then
                    table.insert(res,{npc=npc, root=r, hum=h, dist=d})
                end
            end
        end
    end
    -- WorldNPCs al-mappák is (sok NPC itt van)
    local worldNPCs=workspace:FindFirstChild("WorldNPCs")
    if worldNPCs then
        for _,zone in ipairs(worldNPCs:GetChildren()) do
            for _,npc in ipairs(zone:GetChildren()) do
                if npc:IsA("Model") then
                    local h=npc:FindFirstChildOfClass("Humanoid")
                    local r=npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChild("Torso")
                    if h and h.Health>0 and r then
                        local d=(r.Position-hrp.Position).Magnitude
                        if d<=CFG.SCAN_RANGE then
                            table.insert(res,{npc=npc, root=r, hum=h, dist=d})
                        end
                    end
                end
            end
        end
    end
    table.sort(res,function(a,b) return a.dist<b.dist end)
    return res
end

-- ══════════════════════════════════════════
-- FELTÉTELEK
-- ══════════════════════════════════════════
local function canAttack()
    return not ActionState.isDowned(char)
       and not ActionState.isChanneling(char)
       and not ActionState.isIncapacitated(char)
       and not ActionState.isRooted(char)
       and not ActionState.isIntangible(char)
end

local function canGrab()
    return canAttack()
       and not char:GetAttribute("Carrying")
       and not char:GetAttribute("Gripping")
       and not char:GetAttribute("InClash")
       and not char:GetAttribute("KiBlasting")
end

-- ══════════════════════════════════════════
-- COMBO VÉGREHAJTÁS
-- ══════════════════════════════════════════
local lastAttack=0

local function sendLight(cframe)
    if tick()-lastAttack < CFG.ATTACK_CD then task.wait(CFG.ATTACK_CD) end
    lastAttack=tick()
    Remotes.PerformAction:FireServer("LightAttack",{phase="start", cframe=cframe})
end

local function sendHeavy(cframe)
    Remotes.PerformAction:FireServer("HeavyAttack",{phase="start", cframe=cframe})
    task.wait(0.22)
    Remotes.PerformAction:FireServer("HeavyAttack",{phase="stop"})
end

local function sendGrab(cframe)
    if not canGrab() then return end
    Remotes.PerformAction:FireServer("Grab",{phase="start", cframe=cframe})
    task.wait(CFG.GRAB_HOLD)
    Remotes.PerformAction:FireServer("Grab",{phase="stop"})
end

local function doCombo(target)
    local root=target.root
    if not root or not root.Parent then return end

    -- Teleport az NPC mellé (CombatPublic MELEE_FIST_REACH = 3.8)
    if CFG.TELEPORT_TO_NPC and hrp then
        local dir=(hrp.Position-root.Position).Unit
        hrp.CFrame = root.CFrame + dir*3.5 + CFG.TP_OFFSET
        task.wait(0.08)
    end

    local cf=hrp.CFrame

    -- RUSH combo: L L L L M (LIGHTS_PER_STRING=4, CHAIN_CAP=8)
    updGui(target.npc.Name, "LLLL")
    for i=1,CFG.LIGHT_COUNT do
        if not canAttack() then break end
        if not root.Parent then break end
        sendLight(cf)
        task.wait(CFG.COMBO_DELAY)
    end

    -- Heavy finisher
    if CFG.HEAVY_AFTER_LIGHT and canAttack() and root.Parent then
        updGui(nil, "LLLL+M")
        sendHeavy(cf)
        task.wait(CFG.COMBO_DELAY)
    end

    -- Grab (ha még él)
    if CFG.GRAB_ENABLED and target.hum.Health>0 and canGrab() and root.Parent then
        updGui(nil, "GRAB!")
        sendGrab(cf)
        task.wait(0.5)
    end
end

-- ══════════════════════════════════════════
-- FŐ LOOP
-- ══════════════════════════════════════════
local function farmLoop()
    while true do
        if not char or not hrp then task.wait(0.5); continue end

        local npcs=getNPCs()
        if #npcs==0 then
            updGui("nincs NPC","–")
            task.wait(1); continue
        end

        local target=npcs[1]
        updGui(target.npc.Name.." ["..math.floor(target.dist).."st]","–")

        -- Megölés loop amíg az NPC él
        local maxHits=20
        for _=1,maxHits do
            if not target.npc.Parent then break end
            if target.hum.Health<=0 then break end
            if not canAttack() then task.wait(0.1); continue end
            doCombo(target)
            task.wait(CFG.LOOP_DELAY)
        end

        -- Kill számláló
        if not target.npc.Parent or target.hum.Health<=0 then
            kills+=1
            updGui("Kill #"..kills,"–")
            dbg("Kill:",target.npc.Name)
        end

        task.wait(CFG.LOOP_DELAY)
    end
end

task.spawn(function()
    task.wait(2)
    local ok,err=pcall(farmLoop)
    if not ok then print("[NPCFarm] Hiba:",err) end
end)

print("[AutoNPCFarm] ✓ betöltve | LightAttack x"..CFG.LIGHT_COUNT.." + Heavy | Range:"..CFG.SCAN_RANGE)
