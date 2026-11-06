--[[
    07_AutoNPCFarm  -  ModuleScript
    Config:  _Config.get("NPCFarm", key)
    Statusz: require(this).getStats()
]]

local Cfg     = (_G._AIO_Config)
local Shared  = (_G._AIO_Shared)
local CS      = game:GetService("CollectionService")
local Players = game:GetService("Players")

local S = { kills = 0, status = "Idle", target = "-", combo = "-" }
local lastAttack = 0

local function getNPCs()
    local hrp   = Shared.getHRP()
    if not hrp then return {} end
    local range = Cfg.get("NPCFarm","SCAN_RANGE") or 150
    local Ent   = Shared.getEntities()
    local res   = {}

    if Ent then
        for _, npc in ipairs(CS:GetTagged(Ent.Tag.NPC)) do
            if npc:IsA("Model") and npc:IsDescendantOf(workspace) then
                local h = npc:FindFirstChildOfClass("Humanoid")
                local r = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChild("Torso")
                if h and h.Health > 0 and r then
                    local d = (r.Position - hrp.Position).Magnitude
                    if d <= range then
                        table.insert(res, { npc=npc, root=r, hum=h, dist=d })
                    end
                end
            end
        end
    end

    local worldNPCs = workspace:FindFirstChild("WorldNPCs")
    if worldNPCs then
        for _, zone in ipairs(worldNPCs:GetChildren()) do
            for _, npc in ipairs(zone:GetChildren()) do
                if npc:IsA("Model") then
                    local h = npc:FindFirstChildOfClass("Humanoid")
                    local r = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChild("Torso")
                    if h and h.Health > 0 and r then
                        local d = (r.Position - hrp.Position).Magnitude
                        if d <= range then
                            table.insert(res, { npc=npc, root=r, hum=h, dist=d })
                        end
                    end
                end
            end
        end
    end

    table.sort(res, function(a, b) return a.dist < b.dist end)
    return res
end

local function sendLight(cf)
    local cd = Cfg.get("NPCFarm","ATTACK_CD") or 0.18
    if tick() - lastAttack < cd then task.wait(cd) end
    lastAttack = tick()
    Shared.perform("LightAttack", { phase="start", cframe=cf })
end

local function sendHeavy(cf)
    Shared.perform("HeavyAttack", { phase="start", cframe=cf })
    task.wait(0.22)
    Shared.perform("HeavyAttack", { phase="stop" })
end

local function sendGrab(cf)
    if not Shared.canAttack() then return end
    local char = Shared.getChar()
    if not char then return end
    if char:GetAttribute("Carrying") or char:GetAttribute("Gripping")
    or char:GetAttribute("InClash")  or char:GetAttribute("KiBlasting") then return end
    local hold = Cfg.get("NPCFarm","GRAB_HOLD") or 0.32
    Shared.perform("Grab", { phase="start", cframe=cf })
    task.wait(hold)
    Shared.perform("Grab", { phase="stop" })
end

local function doCombo(target)
    local root = target.root
    if not root or not root.Parent then return end

    local hrp = Shared.getHRP()
    if Cfg.get("NPCFarm","TELEPORT_TO_NPC") and hrp then
        local offset = Cfg.get("NPCFarm","TP_OFFSET") or Vector3.new(0,1,2)
        local dir    = (hrp.Position - root.Position).Unit
        hrp.CFrame   = root.CFrame + dir * 3.5 + offset
        task.wait(0.08)
    end

    local cf         = hrp and hrp.CFrame or CFrame.new()
    local lights     = Cfg.get("NPCFarm","LIGHT_COUNT") or 4
    local comboDelay = Cfg.get("NPCFarm","COMBO_DELAY") or 0.22

    S.combo = "L x" .. lights
    for _ = 1, lights do
        if not Shared.canAttack() then break end
        if not root.Parent then break end
        sendLight(cf)
        task.wait(comboDelay)
    end

    if Cfg.get("NPCFarm","HEAVY_AFTER_LIGHT") and Shared.canAttack() and root.Parent then
        S.combo = "LLLL+M"
        sendHeavy(cf)
        task.wait(comboDelay)
    end

    if Cfg.get("NPCFarm","GRAB_ENABLED") and target.hum.Health > 0 and root.Parent then
        S.combo = "GRAB"
        sendGrab(cf)
        task.wait(0.5)
    end
end

task.spawn(function()
    task.wait(2)
    while true do
        local loopDelay = Cfg.get("NPCFarm","LOOP_DELAY") or 0.5
        if not Cfg.get("NPCFarm","enabled") then
            S.status = "Kikapcsolva"
            S.target = "-"
            S.combo  = "-"
            task.wait(1)
        else
            local npcs = getNPCs()
            if #npcs == 0 then
                S.status = "Nincs NPC"
                S.target = "-"
                task.wait(1)
            else
                local target = npcs[1]
                S.target = target.npc.Name .. " [" .. math.floor(target.dist) .. "st]"
                S.status = "Farmolas"

                for _ = 1, 20 do
                    if not Cfg.get("NPCFarm","enabled") then break end
                    if not target.npc.Parent or target.hum.Health <= 0 then break end
                    if Shared.canAttack() then
                        doCombo(target)
                    else
                        task.wait(0.1)
                    end
                    task.wait(loopDelay)
                end

                if not target.npc.Parent or target.hum.Health <= 0 then
                    S.kills  = S.kills + 1
                    S.status = "Kill #" .. S.kills
                end

                task.wait(loopDelay)
            end
        end
    end
end)

local Module = {}
function Module.getStats()
    return {
        enabled = Cfg.get("NPCFarm","enabled"),
        kills   = S.kills,
        target  = S.target,
        combo   = S.combo,
        status  = S.status,
    }
end
print("[AutoNPCFarm] OK")
_G._AIO_Modules = _G._AIO_Modules or {}
_G._AIO_Modules["NPCFarm"] = Module
return Module
