-- ══════════════════════════════════════════════════════════════════════
-- AUTO LOOT FARM (Master GUI Integrált verzió)
-- ══════════════════════════════════════════════════════════════════════

local CFG = {
    TP_OFFSET_Y   = 3,
    TP_DELAY      = 0.22,
    SCAN_INTERVAL = 1.0,
    MAX_PER_SCAN  = 40,
    LOOT_FOLDERS  = { "LootDrops", "MapLoot", "WorldDrops", "IngredientPickups" },
    ITEM_KEYWORDS = {
        "drop","loot","pickup","item","zeni","coin","reward","orb",
        "shard","fragment","gem","crystal","bag",
        "senzu","carrot","onion","tomato","mushroom","redcabbage","potato",
        "abyssjaws","mudking","pondcarp","sunfinsnapper","spinepuffer",
        "dragoneel","frostjawcod","redfang","bluetitan","sailfintuna",
        "steak","riceball","kebab","bread","seed","fish",
        "weight","plate","dumbbell","zeni","money","coin","cash",
    },
    EXCLUDE = { "npc","player","humanoid","baseplate","terrain","camera",
                "script","gui","sound","light","fire","smoke","sparkles" },
    DEBUG = false,
}

local Players = game:GetService("Players")
local CS      = game:GetService("CollectionService")
local RS      = game:GetService("ReplicatedStorage")
local LP      = Players.LocalPlayer
local char    = LP.Character or LP.CharacterAdded:Wait()
local hum     = char:WaitForChild("Humanoid")
local hrp     = char:WaitForChild("HumanoidRootPart")

LP.CharacterAdded:Connect(function(c)
    char=c; hum=c:WaitForChild("Humanoid"); hrp=c:WaitForChild("HumanoidRootPart")
end)

local RemFolder = RS:WaitForChild("Remotes",10)
local gatherMote= RemFolder and RemFolder:FindFirstChild("GatherMote")
local function dbg(...) if CFG.DEBUG then print("[AutoLoot]",...) end end

local function isExcluded(name)
    local low=name:lower()
    for _,kw in ipairs(CFG.EXCLUDE) do if low:find(kw,1,true) then return true end end
    return false
end

local function isLoot(inst)
    if isExcluded(inst.Name) then return false end
    if inst:FindFirstChildOfClass("Humanoid") then return false end
    local low=inst.Name:lower()
    for _,kw in ipairs(CFG.ITEM_KEYWORDS) do
        if low:find(kw,1,true) then return true end
    end
    if inst:FindFirstChildWhichIsA("ProximityPrompt",true) then return true end
    if CS:HasTag(inst,"Pickup") or CS:HasTag(inst,"Loot") or CS:HasTag(inst,"Collectible") then
        return true
    end
    return false
end

local function getPart(inst)
    if inst:IsA("BasePart") then return inst end
    if inst:IsA("Model") then
        return inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart")
    end
end

local function scanLoot()
    if not hrp then return {} end
    local res={} local seen={}
    local function chk(inst)
        if seen[inst] or not inst.Parent then return end; seen[inst]=true
        if isLoot(inst) then
            local p=getPart(inst)
            if p then
                table.insert(res,{inst=inst, part=p, dist=(p.Position-hrp.Position).Magnitude})
            end
        end
    end
    for _,fn in ipairs(CFG.LOOT_FOLDERS) do
        local folder=workspace:FindFirstChild(fn)
        if folder then
            for _,inst in ipairs(folder:GetDescendants()) do chk(inst) end
        end
    end
    for _,a in ipairs(workspace:GetChildren()) do
        chk(a)
        if a:IsA("Folder") or a:IsA("Model") then
            for _,b in ipairs(a:GetChildren()) do chk(b) end
        end
    end
    table.sort(res,function(a,b) return a.dist<b.dist end)
    if #res>CFG.MAX_PER_SCAN then
        local t={} for i=1,CFG.MAX_PER_SCAN do t[i]=res[i] end; res=t
    end
    return res
end

local function tryPickup(item)
    if not hrp or not item.part or not item.part.Parent then return end
    hrp.CFrame = item.part.CFrame + Vector3.new(0,CFG.TP_OFFSET_Y,0)
    task.wait(0.05)
    if gatherMote then
        pcall(function() gatherMote:FireServer(item.inst) end)
        pcall(function() gatherMote:FireServer(item.part) end)
    end
    for _,pp in ipairs(item.inst:GetDescendants()) do
        if pp:IsA("ProximityPrompt") then pcall(fireproximityprompt,pp) end
    end
    hrp.CFrame = item.part.CFrame
    task.wait(0.03)
    hrp.CFrame = item.part.CFrame + Vector3.new(0,CFG.TP_OFFSET_Y,0)
end

task.spawn(function()
    task.wait(1.5)
    while true do
        -- Globális GUI kapcsoló ellenőrzése
        if _G.KillAuraCFG and _G.KillAuraCFG.AUTO_LOOT_ENABLED == false then
            task.wait(1)
            continue
        end

        if not char or not hrp then task.wait(0.5); continue end
        local loot=scanLoot()

        for _,item in ipairs(loot) do
            if _G.KillAuraCFG and _G.KillAuraCFG.AUTO_LOOT_ENABLED == false then break end
            if not item.inst.Parent or not item.part.Parent then continue end
            tryPickup(item)
            task.wait(CFG.TP_DELAY)
        end
        task.wait(CFG.SCAN_INTERVAL)
    end
end)

print("[AutoLoot] ✓ Betöltve és összekötve a Master GUI-val")
