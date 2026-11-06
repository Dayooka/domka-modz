local Cfg    = require(script.Parent._Config)
local Shared = require(script.Parent._Shared)

local gatherMote = Shared.getRemoteByName("GatherMote")
local S = { ec = 0, nc = 0, status = "Idle" }

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

local function isDB(i)    return EARTH[i.Name] or NAMEK[i.Name] end
local function exists(b)  return b.part and b.part.Parent and b.inst and b.inst.Parent end

local function findAll()
    local res = {}; local seen = {}
    local function chk(i)
        if seen[i] or not i.Parent then return end
        seen[i] = true
        if isDB(i) then
            local p = Shared.getPart(i)
            if p then table.insert(res, { inst=i, part=p, namek=NAMEK[i.Name]~=nil }) end
        end
    end
    for _, a in ipairs(workspace:GetChildren()) do
        chk(a)
        for _, b in ipairs(a:GetChildren()) do
            chk(b)
            for _, c in ipairs(b:GetChildren()) do chk(c) end
        end
    end
    return res
end

local function tryPickup(ball)
    if gatherMote then
        pcall(function() gatherMote:FireServer(ball.inst) end)
        pcall(function() gatherMote:FireServer(ball.part) end)
    end
    for _, pp in ipairs(ball.inst:GetDescendants()) do
        if pp:IsA("ProximityPrompt") then pcall(fireproximityprompt, pp) end
    end
    local hrp = Shared.getHRP()
    if hrp and ball.part and ball.part.Parent then
        local oy = Cfg.get("DragonBall","TP_OFFSET_Y") or 3
        hrp.CFrame = ball.part.CFrame
        task.wait(0.04)
        hrp.CFrame = ball.part.CFrame + Vector3.new(0, oy, 0)
    end
end

task.spawn(function()
    task.wait(1.5)
    while true do
        if not Cfg.get("DragonBall","enabled") then
            S.status = "Kikapcsolva"
            task.wait(1)
        else
            local hrp = Shared.getHRP()
            if not hrp then
                task.wait(0.5)
            else
                local balls = findAll()
                S.ec = 0; S.nc = 0
                for _, b in ipairs(balls) do
                    if b.namek then
                        S.nc = S.nc + 1
                    else
                        S.ec = S.ec + 1
                    end
                end

                if #balls == 0 then
                    S.status = "Mind megvan!"
                    if Cfg.get("DragonBall","AUTO_SUMMON") then
                        Shared.invoke("RequestSummon")
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
                            local oy = Cfg.get("DragonBall","TP_OFFSET_Y") or 3
                            S.status = (ball.namek and "Namek: " or "Earth: ") .. ball.inst.Name
                            hrp.CFrame = ball.part.CFrame + Vector3.new(0, oy, 0)
                            task.wait(0.06)
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

local Module = {}
function Module.getStats()
    return { enabled=Cfg.get("DragonBall","enabled"), earth=S.ec, namek=S.nc, status=S.status }
end
print("[AutoDragonBall] OK")
return Module
