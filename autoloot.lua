--[[
╔══════════════════════════════════════════════════════════════════════╗
║          AUTO LOOT FARM  (forráskód alapján)                        ║
╠══════════════════════════════════════════════════════════════════════╣
║  Pontos Workspace mappák (13. szekció alapján):                     ║
║    LootDrops, MapLoot, WorldDrops, IngredientPickups                ║
║  Felvétel: GatherMote RemoteEvent                                   ║
║  Inventory: GetInventory (RF) + InventoryChanged (RE)               ║
║  Items: UseItem, UseItemSlot, SetItemSlot                           ║
║  Assets.ItemPreviews: BraveSword, RedFang, Steak, RiceBall,         ║
║    Kebab, Bread, magok, súlyok, halak (halnevek is tárolva)         ║
╚══════════════════════════════════════════════════════════════════════╝
]]

local CFG = {
    TP_OFFSET_Y   = 3,
    TP_DELAY      = 0.22,
    SCAN_INTERVAL = 1.0,
    MAX_PER_SCAN  = 40,
    -- Ismert loot mappák (Workspace 13. szekció alapján – pontos nevek)
    LOOT_FOLDERS  = { "LootDrops", "MapLoot", "WorldDrops", "IngredientPickups" },
    -- Assets.ItemPreviews és Assets.Senzu alapján ismert item nevek
    ITEM_KEYWORDS = {
        "drop","loot","pickup","item","zeni","coin","reward","orb",
        "shard","fragment","gem","crystal","bag",
        -- Assets.Senzu ételek
        "senzu","carrot","onion","tomato","mushroom","redcabbage","potato",
        -- Assets.Fishing halak
        "abyssjaws","mudking","pondcarp","sunfinsnapper","spinepuffer",
        "dragoneel","frostjawcod","redfang","bluetitan","sailfintuna",
        -- Assets.ItemPreviews
        "steak","riceball","kebab","bread","seed","fish",
        -- Súlyok (GymSetPlates alapján)
        "weight","plate","dumbbell",
        -- Zeni
        "zeni","money","coin","cash",
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

-- GUI
local sg=Instance.new("ScreenGui"); sg.Name="AutoLoot_HUD"; sg.ResetOnSpawn=false
sg.IgnoreGuiInset=true; sg.Parent=LP:WaitForChild("PlayerGui")
local fr=Instance.new("Frame",sg)
fr.Size=UDim2.new(0,195,0,70); fr.Position=UDim2.new(1,-207,0.5,54)
fr.BackgroundColor3=Color3.fromRGB(14,8,4); fr.BackgroundTransparency=0.15; fr.BorderSizePixel=0
Instance.new("UICorner",fr).CornerRadius=UDim.new(0,10)
local stk=Instance.new("UIStroke",fr); stk.Color=Color3.fromRGB(255,160,40); stk.Thickness=1.4
local titleL=Instance.new("TextLabel",fr)
titleL.Size=UDim2.new(1,0,0,22); titleL.Position=UDim2.new(0,0,0,4)
titleL.BackgroundTransparency=1; titleL.Text="💰 AUTO LOOT FARM"
titleL.TextColor3=Color3.fromRGB(255,180,60); titleL.Font=Enum.Font.GothamBold; titleL.TextSize=12
local statL=Instance.new("TextLabel",fr)
statL.Name="Stat"; statL.Size=UDim2.new(0.5,0,0,16); statL.Position=UDim2.new(0,4,0,26)
statL.BackgroundTransparency=1; statL.TextColor3=Color3.fromRGB(255,200,80)
statL.Font=Enum.Font.GothamSemibold; statL.TextSize=11; statL.TextXAlignment=Enum.TextXAlignment.Left
statL.Text="Talált: 0"
local sessL=Instance.new("TextLabel",fr)
sessL.Name="Sess"; sessL.Size=UDim2.new(0.5,0,0,16); sessL.Position=UDim2.new(0.5,0,0,26)
sessL.BackgroundTransparency=1; sessL.TextColor3=Color3.fromRGB(100,255,120)
sessL.Font=Enum.Font.GothamSemibold; sessL.TextSize=11; sessL.TextXAlignment=Enum.TextXAlignment.Left
sessL.Text="Felvett: 0"
local statusL=Instance.new("TextLabel",fr)
statusL.Name="Status"; statusL.Size=UDim2.new(1,-8,0,12); statusL.Position=UDim2.new(0,4,0,46)
statusL.BackgroundTransparency=1; statusL.TextColor3=Color3.fromRGB(180,160,120)
statusL.Font=Enum.Font.Gotham; statusL.TextSize=10; statusL.TextXAlignment=Enum.TextXAlignment.Left
statusL.Text="Indítás..."

local found,collected=0,0
local function updGui(s)
    if statL then statL.Text="Talált: "..found end
    if sessL then sessL.Text="Felvett: "..collected end
    if statusL and s then statusL.Text=s end
end

-- Loot detektálás
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
    -- ProximityPrompt jelzés
    if inst:FindFirstChildWhichIsA("ProximityPrompt",true) then return true end
    -- CollectionService "Pickup" tag
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
                table.insert(res,{inst=inst, part=p,
                    dist=(p.Position-hrp.Position).Magnitude})
            end
        end
    end
    -- Pontos Workspace mappák
    for _,fn in ipairs(CFG.LOOT_FOLDERS) do
        local folder=workspace:FindFirstChild(fn)
        if folder then
            for _,inst in ipairs(folder:GetDescendants()) do chk(inst) end
        end
    end
    -- Általános scan (top + 1 szint)
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
    -- GatherMote (pontos remote a forrásból)
    if gatherMote then
        pcall(function() gatherMote:FireServer(item.inst) end)
        pcall(function() gatherMote:FireServer(item.part) end)
    end
    -- ProximityPrompt
    for _,pp in ipairs(item.inst:GetDescendants()) do
        if pp:IsA("ProximityPrompt") then pcall(fireproximityprompt,pp) end
    end
    -- Touch trigger
    hrp.CFrame = item.part.CFrame
    task.wait(0.03)
    hrp.CFrame = item.part.CFrame + Vector3.new(0,CFG.TP_OFFSET_Y,0)
end

-- ChildAdded listenrek a loot mappákra (azonnali reakció)
for _,fn in ipairs(CFG.LOOT_FOLDERS) do
    local folder=workspace:FindFirstChild(fn)
    if folder then
        folder.ChildAdded:Connect(function(newDrop)
            task.wait(0.25)
            if not isLoot(newDrop) then return end
            local p=getPart(newDrop); if not p then return end
            dbg("Új drop:",newDrop.Name)
            tryPickup({inst=newDrop, part=p})
            task.wait(0.1)
            if not newDrop.Parent then collected+=1; updGui("⚡ "..newDrop.Name) end
        end)
    end
end

-- Fő scan loop
task.spawn(function()
    task.wait(1.5)
    while true do
        if not char or not hrp then task.wait(0.5); continue end
        local loot=scanLoot()
        found=#loot; updGui(#loot.." drop")

        for _,item in ipairs(loot) do
            if not item.inst.Parent or not item.part.Parent then continue end
            tryPickup(item)
            task.wait(0.08)
            if not item.inst.Parent then
                collected+=1
                dbg("✓ Felvéve:",item.inst.Name)
            end
            task.wait(CFG.TP_DELAY)
        end
        updGui(collected.." felvéve")
        task.wait(CFG.SCAN_INTERVAL)
    end
end)

print("[AutoLoot] ✓ betöltve | Mappák:",#CFG.LOOT_FOLDERS)
