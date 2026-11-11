--[[
    releaseskill.lua - ReleaseSkill KillAura
    Config:  _G._AIO_Config.get("ReleaseSkill", key)

    Doksi 14.2.A alapján:
    - SetLockOnTarget + ReleaseSkill combo
    - Erősebb mint PerformAction mert szerver skill-sebzést számol
    - LockOn.MAX_RANGE = 1000 stud de mi 24-et használunk (biztonságos)
]]

local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")
local CS      = game:GetService("CollectionService")

local Cfg    = _G._AIO_Config
local Shared = _G._AIO_Shared

local LP = Players.LocalPlayer

-- Remotes
local RemFolder = RS:WaitForChild("Remotes", 10)
local function getRemote(name)
    return RemFolder and RemFolder:FindFirstChild(name)
end

local releaseSkillRemote = getRemote("ReleaseSkill")
local setLockOnRemote    = getRemote("SetLockOnTarget")

local S = { kills=0, status="Idle", target="-", lastFire=0 }

-- ── NPC keresés (ugyanaz mint combat.lua-ban) ──────────────────
local function getTargets()
    local hrp   = Shared.getHRP()
    if not hrp then return {} end
    local range = Cfg.get("ReleaseSkill","LOCK_ON_RANGE") or 24
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

    -- Játékosok (ha engedélyezett)
    if Cfg.get("ReleaseSkill","ATTACK_PLAYERS") then
        for _, pl in ipairs(Players:GetPlayers()) do
            if pl ~= LP and pl.Character then
                local r = pl.Character:FindFirstChild("HumanoidRootPart")
                local h = pl.Character:FindFirstChildOfClass("Humanoid")
                if r and h and h.Health > 0 then
                    local d = (r.Position - Shared.getHRP().Position).Magnitude
                    if d <= range then
                        table.insert(res, { npc=pl.Character, root=r, hum=h, dist=d, isPlayer=true })
                    end
                end
            end
        end
    end

    table.sort(res, function(a,b) return a.dist < b.dist end)
    return res
end

-- ── ReleaseSkill küldés ────────────────────────────────────────
local function fireReleaseSkill(target)
    if not releaseSkillRemote then return end
    local char = Shared.getChar()
    local hrp  = Shared.getHRP()
    if not char or not hrp then return end
    if not target.npc.Parent then return end

    local skillType = Cfg.get("ReleaseSkill","SKILL_TYPE") or "Melee"

    -- 1. SetLockOnTarget – célzás beállítása
    if setLockOnRemote then
        pcall(function()
            setLockOnRemote:FireServer(target.npc)
        end)
    end

    -- 2. ReleaseSkill – skill küldése a célra
    -- Doksi: "R.SetLockOnTarget:FireServer(p.Character); R.ReleaseSkill:FireServer("Melee", p.Character)"
    pcall(function()
        releaseSkillRemote:FireServer(skillType, target.npc)
    end)

    S.target  = target.npc.Name
    S.lastFire = tick()
end

-- ── Fő loop ───────────────────────────────────────────────────
task.spawn(function()
    task.wait(2)
    while true do
        task.wait(0.1)
        if not Cfg.get("ReleaseSkill","enabled") then
            S.status = "Kikapcsolva"
        else
            if _G._AIO_DefenseActive then
                S.status = "Defense aktiv – varakozas"
            else
                local targets = getTargets()
                if #targets == 0 then
                    S.status = "Nincs cel"
                else
                    local burstDelay = Cfg.get("ReleaseSkill","BURST_DELAY") or 0.004
                    for i, e in ipairs(targets) do
                        if not Cfg.get("ReleaseSkill","enabled") then break end
                        local d = (i-1) * burstDelay
                        if d > 0 then
                            task.delay(d, function()
                                if Cfg.get("ReleaseSkill","enabled") and e.npc.Parent then
                                    fireReleaseSkill(e)
                                end
                            end)
                        else
                            fireReleaseSkill(e)
                        end
                    end
                    S.status = "Aktiv – " .. #targets .. " cel"
                end
            end
        end
    end
end)

_G._AIO_Modules = _G._AIO_Modules or {}
_G._AIO_Modules["ReleaseSkill"] = {
    getStats = function()
        return {
            enabled = Cfg.get("ReleaseSkill","enabled"),
            status  = S.status,
            target  = S.target,
        }
    end
}

print("[ReleaseSkill] OK")
