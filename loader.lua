-- ═══════════════════════════════════════════════════════════════
local repoBase = "https://raw.githubusercontent.com/Dayooka/domka-modz/refs/heads/main/"

local modulesToLoad = {
    "_Config.lua",
    "_Shared.lua",
    "combat.lua",         -- KillAura v9
    "01_AutoBlockParry.lua",
    "02_AutoVanish.lua",
    "03_AutoDragonBall.lua",
    "04_AutoLoot.lua",
    "05_AutoSenzu.lua",
    "06_AutoDaily.lua",
    "07_AutoNPCFarm.lua",
    "gui.lua",
}

print("[DOMKA MODZ] Modulok inicializálása...")

for _, fileName in ipairs(modulesToLoad) do
    local success, err = pcall(function()
        return loadstring(game:HttpGet(repoBase .. fileName))()
    end)
    if not success then
        warn("[DOMKA MODZ] Hiba a(z) " .. fileName .. " betöltésekor: ", err)
    else
        print("[DOMKA MODZ] Sikeresen betöltve: " + fileName)
    end
end

print("[DOMKA MODZ] Rendszer elindult. Minden farm alapból kikapcsolva!")
