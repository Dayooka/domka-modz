-- ══════════════════════════════════════════════════════════════════════
local CFG = {
    LIGHT_COUNT      = 4,
    HEAVY_AFTER_LIGHT= true,
    GRAB_ENABLED     = true,
    GRAB_HOLD        = 0.32,
    ATTACK_CD        = 0.18,
    COMBO_DELAY      = 0.22,
    ATTACK_RANGE     = 6,
    TELEPORT_TO_NPC  = true,
    TP_OFFSET        = Vector3.new(0, 1, 2),
    SCAN_RANGE       = 150,
    LOOP_DELAY       = 0.5,
    DEBUG            = false,
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

local function getNPCs()
    if not hrp then return {} end
    local res={}
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

    if CFG.TELEPORT_TO_NPC and hrp then
        local dir=(hrp.Position-root.Position).Unit
        hrp.CFrame = root.CFrame + dir*3.5 + CFG.TP_OFFSET
        task.wait(0.08)
    end

    local cf=hrp.CFrame

    for i=1,CFG.LIGHT_COUNT do
        if not canAttack() then break end
        if not root.Parent then break end
        sendLight(cf)
        task.wait(CFG.COMBO_DELAY)
    end

    if CFG.HEAVY_AFTER_LIGHT and canAttack() and root.Parent then
        sendHeavy(cf)
        task.wait(CFG.COMBO_DELAY)
    end

    if CFG.GRAB_ENABLED and target.hum.Health>0 and canGrab() and root.Parent then
        sendGrab(cf)
        task.wait(0.5)
    end
end

task.spawn(function()
    task.wait(2)
    while true do
        -- Globális GUI kapcsoló ellenőrzése
        if _G.KillAuraCFG and _G.KillAuraCFG.AUTO_NPC_FARM_ENABLED == false then
            task.wait(1)
            continue
        end

        if not char or not hrp then task.wait(0.5); continue end

        local npcs=getNPCs()
        if #npcs==0 then
            task.wait(1)
            continue
        end

        local target=npcs[1]
        for _=1,20 do
            if _G.KillAuraCFG and _G.KillAuraCFG.AUTO_NPC_FARM_ENABLED == false then break end
            if not target.npc.Parent then break end
            if target.hum.Health<=0 then break end
            if not canAttack() then task.wait(0.1); continue end
            doCombo(target)
            task.wait(CFG.LOOP_DELAY)
        end

        task.wait(CFG.LOOP_DELAY)
    end
end)

print("[AutoNPCFarm] ✓ Betöltve és összekötve a Master GUI-val")
