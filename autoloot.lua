local Cfg    = (_G._AIO_Config)
local Shared = (_G._AIO_Shared)
local CS     = game:GetService("CollectionService")

local gatherMote = Shared.getRemoteByName("GatherMote")
local S = { found = 0, collected = 0, status = "Idle" }

local ITEM_KW = {
    "drop","loot","pickup","item","zeni","coin","reward","orb",
    "shard","fragment","gem","crystal","bag","senzu","carrot","onion",
    "tomato","mushroom","redcabbage","potato","steak","riceball","kebab",
    "bread","seed","fish","weight","plate","dumbbell",
    "abyssjaws","mudking","pondcarp","sunfinsnapper","spinepuffer",
    "dragoneel","frostjawcod","redfang","bluetitan","sailfintuna",
}
local EXCL_KW = {
    "npc","player","humanoid","baseplate","terrain","camera",
    "script","gui","sound","light","fire","smoke","sparkles",
}

local function isExcluded(name)
    local low = name:lower()
    for _, kw in ipairs(EXCL_KW) do
        if low:find(kw, 1, true) then return true end
    end
    return false
end

local function isLoot(inst)
    if isExcluded(inst.Name) then return false end
    if inst:FindFirstChildOfClass("Humanoid") then return false end
    local low = inst.Name:lower()
    for _, kw in ipairs(ITEM_KW) do
        if low:find(kw, 1, true) then return true end
    end
    if inst:FindFirstChildWhichIsA("ProximityPrompt", true) then return true end
    if CS:HasTag(inst,"Pickup") or CS:HasTag(inst,"Loot") or CS:HasTag(inst,"Collectible") then
        return true
    end
    return false
end

local function scanLoot()
    local hrp = Shared.getHRP()
    if not hrp then return {} end
    local res = {}; local seen = {}
    local folders = Cfg.get("Loot","LOOT_FOLDERS") or {}

    local function chk(inst)
        if seen[inst] or not inst.Parent then return end
        seen[inst] = true
        if isLoot(inst) then
            local p = Shared.getPart(inst)
            if p then
                table.insert(res, {
                    inst = inst, part = p,
                    dist = (p.Position - hrp.Position).Magnitude
                })
            end
        end
    end

    for _, fn in ipairs(folders) do
        local folder = workspace:FindFirstChild(fn)
        if folder then
            for _, i in ipairs(folder:GetDescendants()) do chk(i) end
        end
    end
    for _, a in ipairs(workspace:GetChildren()) do
        chk(a)
        if a:IsA("Folder") or a:IsA("Model") then
            for _, b in ipairs(a:GetChildren()) do chk(b) end
        end
    end

    table.sort(res, function(a, b) return a.dist < b.dist end)
    local max = Cfg.get("Loot","MAX_PER_SCAN") or 40
    if #res > max then
        local t = {}
        for i = 1, max do t[i] = res[i] end
        res = t
    end
    return res
end

local function tryPickup(item)
    local hrp = Shared.getHRP()
    if not hrp or not item.part or not item.part.Parent then return end
    local oy = Cfg.get("Loot","TP_OFFSET_Y") or 3
    hrp.CFrame = item.part.CFrame + Vector3.new(0, oy, 0)
    task.wait(0.05)
    if gatherMote then
        pcall(function() gatherMote:FireServer(item.inst) end)
        pcall(function() gatherMote:FireServer(item.part) end)
    end
    for _, pp in ipairs(item.inst:GetDescendants()) do
        if pp:IsA("ProximityPrompt") then pcall(fireproximityprompt, pp) end
    end
    hrp.CFrame = item.part.CFrame
    task.wait(0.03)
    hrp.CFrame = item.part.CFrame + Vector3.new(0, oy, 0)
end

-- ChildAdded listenrek azonnali rekciohoz
local folders = Cfg.get("Loot","LOOT_FOLDERS") or {}
for _, fn in ipairs(folders) do
    local folder = workspace:FindFirstChild(fn)
    if folder then
        folder.ChildAdded:Connect(function(newDrop)
            task.wait(0.25)
            if not Cfg.get("Loot","enabled") then return end
            if not isLoot(newDrop) then return end
            local p = Shared.getPart(newDrop)
            if not p then return end
            tryPickup({ inst=newDrop, part=p })
            task.wait(0.1)
            if not newDrop.Parent then
                S.collected = S.collected + 1
            end
        end)
    end
end

task.spawn(function()
    task.wait(1.5)
    while true do
        local interval = Cfg.get("Loot","SCAN_INTERVAL") or 1.0
        if not Cfg.get("Loot","enabled") then
            S.status = "Kikapcsolva"
            task.wait(1)
        else
            local loot = scanLoot()
            S.found = #loot
            S.status = S.found .. " drop"
            for _, item in ipairs(loot) do
                if not Cfg.get("Loot","enabled") then break end
                if item.inst.Parent and item.part.Parent then
                    tryPickup(item)
                    task.wait(0.08)
                    if not item.inst.Parent then
                        S.collected = S.collected + 1
                    end
                    task.wait(Cfg.get("Loot","TP_DELAY") or 0.22)
                end
            end
            task.wait(interval)
        end
    end
end)

local Module = {}
function Module.getStats()
    return {
        enabled   = Cfg.get("Loot","enabled"),
        found     = S.found,
        collected = S.collected,
        status    = S.status,
    }
end
print("[AutoLoot] OK")
_G._AIO_Modules = _G._AIO_Modules or {}
_G._AIO_Modules["Loot"] = Module
return Module
