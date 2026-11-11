--[[
    antidetect.lua - StateProbeBypass + Attribútum Spoof
    Config:  _G._AIO_Config.get("StateProbeBypass", key)

    Doksi 5. fejezet + 14.5.A alapján:
    - StateProbeReport remote hookolása → mindig "tiszta" állapot küld
    - Attribútum manipuláció bypass (StepIFrameUntil, KnockbackAt stb.)
    - Ez az ELSŐ amit be kell kapcsolni mert minden mást láthatóvá tesz
]]

local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")

local Cfg = _G._AIO_Config
local LP  = Players.LocalPlayer

-- ── StateProbeReport hook ──────────────────────────────────────
-- Doksi: az exploiter hook-olja a StateProbeReport:FireServer-t
-- és tiszta, hamis adatot küld (mozgatók elrejtése)
local RemFolder = RS:WaitForChild("Remotes", 10)
local function getRemote(name)
    return RemFolder and RemFolder:FindFirstChild(name)
end

local probeBypassed = false

local function bypassStateProbe()
    if probeBypassed then return end

    local probeRemote = getRemote("StateProbeReport")
    if not probeRemote then
        warn("[AntiDetect] StateProbeReport remote nem talalhato")
        return
    end

    -- Tiszta állapot template (semmi gyanús nincs benne)
    local function getCleanReport()
        local char = LP.Character
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        local hum  = char and char:FindFirstChildOfClass("Humanoid")

        return {
            position    = hrp and hrp.Position or Vector3.zero,
            velocity    = Vector3.zero,          -- Nincs gyanús sebesség
            walkSpeed   = 16,                    -- Alap WalkSpeed
            jumpPower   = 50,
            health      = hum and hum.Health or 100,
            movers      = {},                    -- Üres: nincs mozgató
            joints      = {},                    -- Üres: nincs külső joint
            anchored    = false,
            platformStand = false,
            floorMaterial = Enum.Material.Plastic,
        }
    end

    -- Hook: StateProbeReport FireServer → mindig tiszta adatot küld
    -- (a __namecall hook már fel van állítva a combat.lua-ban,
    --  itt egy extra réteg: közvetlen remote wrapper)
    local origOnServerEvent = probeRemote.FireServer
    local hookConn

    -- Alternatív megközelítés: StateProbeRequest-re válaszolunk
    -- tiszta adattal (a szerver ezt kéri, mi ezt adjuk vissza)
    local requestRemote = getRemote("StateProbeRequest")
    if requestRemote then
        hookConn = requestRemote.OnClientEvent:Connect(function()
            if not Cfg.get("StateProbeBypass","enabled") then return end
            -- Tiszta report küldése a szerver kérésére
            pcall(function()
                probeRemote:FireServer(getCleanReport())
            end)
        end)
        probeBypassed = true
        print("[AntiDetect] StateProbeBypass aktiv (Request hook)")
    end

    -- Ha nincs Request remote, Heartbeat-en küldjük proaktívan
    if not hookConn then
        local lastProbe = 0
        game:GetService("RunService").Heartbeat:Connect(function()
            if not Cfg.get("StateProbeBypass","enabled") then return end
            local now = tick()
            if now - lastProbe < 2.0 then return end  -- 2s-enként
            lastProbe = now
            pcall(function()
                probeRemote:FireServer(getCleanReport())
            end)
        end)
        probeBypassed = true
        print("[AntiDetect] StateProbeBypass aktiv (Heartbeat)")
    end
end

-- ── Attribútum spoof védelem ───────────────────────────────────
-- Doksi 14.2.D: StepIFrameUntil, KnockbackAt hamisítás lehetséges
-- MI ezt a saját javunkra használjuk:
-- az autoblock/autovanish által küldött actionök hatékonyabbak
-- ha az iFrame attribútumok megfelelően vannak beállítva

local function setupAttributeEnhancement()
    local char = LP.Character
    if not char then return end

    -- VanishCounterUntil: Vanish counter ablak kiterjesztése
    -- (doksi: VANISH_CHAIN_MAX = 6 a CombatPublic-ban)
    -- Ezeket NE állítsuk végtelenre (gyanús!) – csak kis értékkel toljuk

    -- Megjegyzés: a szerver felülírja saját magától ezeket,
    -- de a kliensoldali ellenőrzések (pl. ActionState) ezeket olvassák
end

-- ── Indítás ───────────────────────────────────────────────────
task.spawn(function()
    task.wait(1)
    if Cfg.get("StateProbeBypass","enabled") then
        bypassStateProbe()
    end
end)

-- Config változás figyelés
Cfg.onChange(function(mod, key, val)
    if mod == "StateProbeBypass" and key == "enabled" then
        if val and not probeBypassed then
            bypassStateProbe()
        end
    end
end)

-- Karakter újratöltéskor újra beállítjuk
LP.CharacterAdded:Connect(function()
    task.wait(0.5)
    if Cfg.get("StateProbeBypass","enabled") then
        probeBypassed = false
        bypassStateProbe()
    end
end)

_G._AIO_Modules = _G._AIO_Modules or {}
_G._AIO_Modules["StateProbeBypass"] = {
    getStats = function()
        return {
            enabled  = Cfg.get("StateProbeBypass","enabled"),
            bypassed = probeBypassed,
            status   = probeBypassed and "Aktiv" or "Inaktiv",
        }
    end
}

print("[AntiDetect] OK")
