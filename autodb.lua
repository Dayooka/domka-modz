--[[
    autodb.lua - Auto Dragon Ball Collector
    Config:  _G._AIO_Config.get("DragonBall", key)
    Statusz: _G._AIO_Modules["DragonBall"].getStats()

    FONTOS (forrás alapján):
    - Loot drop-ok szerver oldali kezeltek, NPC fején ProximityPrompt van
    - GatherMote remote NEM létezik
    - Felvétel: ProximityPrompt trigger + UseItem remote
    - Dragon Ball-ok: Assets.EarthDragonBalls / NamekDragonBalls
      nevek: DragonBall_01..07, NamekDragonBall_01..07
    - Workspace mappák: LootDrops, MapLoot, WorldDrops, IngredientPickups
]]

local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")

local Cfg    = _G._AIO_Config
local Shared = _G._AIO_Shared

local LP   = Players.LocalPlayer
local char = LP.Character or LP.CharacterAdded:Wait()
local hum  = char:WaitForChild("Humanoid")
local hrp  = char:WaitForChild("HumanoidRootPart")

LP.CharacterAdded:Connect(function(c)
    char = c
    hum  = c:WaitForChild("Humanoid")
    hrp  = c:WaitForChild("HumanoidRootPart")
end)

-- Remotes
local RemFolder = RS:WaitForChild("Remotes", 10)
local function getRemote(name)
    return RemFolder and RemFolder:FindFirstChild(name)
end

-- UseItem remote (inventory rendszer alapján)
local useItemRemote = getRemote("UseItem")

local S = { ec = 0, nc = 0, status = "Idle" }

-- Name set-ek
local EARTH, NAMEK = {}, {}
local function rebuildSets()
    EARTH = {}; NAMEK = {}
    for _, n in ipairs(Cfg.get("DragonBall","EARTH") or {}) do EARTH[n] = true end
    for _, n in ipairs(Cfg.get("DragonBall","NAMEK") or {}) do NAMEK[n] = true end
end
rebuildSets()
Cfg.onChange(function(mod, key)
    if mod == "DragonBall" and (key == "EARTH" or key == "NAMEK") then rebuildSets() end
end)

local function isDB(inst) return EARTH[inst.Name] or NAMEK[inst.Name] end
local function exists(b)  return b.part and b.part.Parent and b.inst and b.inst.Parent end

local function findAll()
    local res = {}; local seen = {}
    local function chk(inst)
        if seen[inst] or not inst.Parent then return end
        seen[inst] = true
        if isDB(inst) then
            local p = Shared.getPart(inst)
            if p then
                table.insert(res, {
                    inst  = inst,
                    part  = p,
                    namek = NAMEK[inst.Name] ~= nil,
                })
            end
        end
    end
    -- Teljes workspace scan (Dragon Ball-ok bárhol lehetnek)
    for _, a in ipairs(workspace:GetChildren()) do
        chk(a)
        for _, b in ipairs(a:GetChildren()) do
            chk(b)
            for _, c in ipairs(b:GetChildren()) do chk(c) end
        end
    end
    -- Ismert loot mappák explicit scan
    local lootFolders = { "LootDrops", "MapLoot", "WorldDrops", "IngredientPickups" }
    for _, fn in ipairs(lootFolders) do
        local folder = workspace:FindFirstChild(fn)
        if folder then
            for _, inst in ipairs(folder:GetDescendants()) do chk(inst) end
        end
    end
    return res
end

-- Felvétel: forrás alapján NPC fején ProximityPrompt + UseItem remote
local function tryPickup(ball)
    local hrpRef = Shared.getHRP()
    if not hrpRef then return end

    -- 1. Teleport a ball mellé
    local oy = Cfg.get("DragonBall","TP_OFFSET_Y") or 3
    hrpRef.CFrame = ball.part.CFrame + Vector3.new(0, oy, 0)
    task.wait(0.05)

    -- 2. Touch trigger (CFrame oda-vissza – fizikai érintkezés)
    hrpRef.CFrame = ball.part.CFrame
    task.wait(0.04)
    hrpRef.CFrame = ball.part.CFrame + Vector3.new(0, oy, 0)

    -- 3. ProximityPrompt trigger (legmegbízhatóbb módszer a forrás szerint)
    -- Az NPC-k fejénél lévő ProximityPrompt-ot keresi
    local function firePrompts(root)
        -- Az inst-en és szülőjén is keressük
        for _, pp in ipairs(root:GetDescendants()) do
            if pp:IsA("ProximityPrompt") then
                pcall(fireproximityprompt, pp)
            end
        end
        if root.Parent then
            for _, pp in ipairs(root.Parent:GetDescendants()) do
                if pp:IsA("ProximityPrompt") then
                    pcall(fireproximityprompt, pp)
                end
            end
        end
    end
    firePrompts(ball.inst)

    -- 4. UseItem remote (inventory rendszer – item közvetlen használat)
    if useItemRemote then
        pcall(function() useItemRemote:FireServer(ball.inst) end)
        pcall(function() useItemRemote:FireServer(ball.part) end)
    end

    -- 5. UseItemSlot (slot-alapú inventory)
    local useSlot = getRemote("UseItemSlot")
    if useSlot then
        pcall(function() useSlot:FireServer(ball.inst) end)
    end
end

task.spawn(function()
    task.wait(1.5)
    while true do
        if not Cfg.get("DragonBall","enabled") then
            S.status = "Kikapcsolva"
            task.wait(1)
        else
            local hrpRef = Shared.getHRP()
            if not hrpRef then
                task.wait(0.5)
            else
                local balls = findAll()
                S.ec = 0; S.nc = 0
                for _, b in ipairs(balls) do
                    if b.namek then S.nc = S.nc + 1 else S.ec = S.ec + 1 end
                end

                if #balls == 0 then
                    S.status = "Mind megvan! (Earth:7 Namek:7)"
                    if Cfg.get("DragonBall","AUTO_SUMMON") then
                        -- RequestSummon nem szerepel a remote listában!
                        -- A sárkány hívás UI-on keresztül történik
                        warn("[AutoDB] AUTO_SUMMON: a sárkány hívás UI-on keresztül elérhető")
                    end
                    if Cfg.get("DragonBall","LOOP") then
                        task.wait(5)
                    else
                        break
                    end
                else
                    for _, ball in ipairs(balls) do
                        if not Cfg.get("DragonBall","enabled") then break end
                        if exists(ball) then
                            local icon = ball.namek and "Namek" or "Earth"
                            S.status = icon .. ": " .. ball.inst.Name

                            local retries = Cfg.get("DragonBall","MAX_RETRIES") or 4
                            local retDel  = Cfg.get("DragonBall","RETRY_DELAY") or 0.18

                            for _ = 1, retries do
                                tryPickup(ball)
                                task.wait(retDel)
                                if not exists(ball) then break end
                            end

                            task.wait(Cfg.get("DragonBall","TP_DELAY") or 0.30)
                        end
                    end
                    task.wait(1)
                end
            end
        end
    end
end)

_G._AIO_Modules = _G._AIO_Modules or {}
_G._AIO_Modules["DragonBall"] = {
    getStats = function()
        return {
            enabled = Cfg.get("DragonBall","enabled"),
            earth   = S.ec,
            namek   = S.nc,
            status  = S.status,
        }
    end
}

print("[AutoDragonBall] OK")
