local Players = game:GetService("Players")
local LP      = Players.LocalPlayer

-- Modulok lekerese _G-bol
local Cfg     = _G._AIO_Config
local Shared  = _G._AIO_Shared
local modules = _G._AIO_Modules or {}

if not Cfg then
    warn("[GUI] _Config nem talalhato! Futtasd elobb a _Config.lua-t")
    return
end

-- ── GUI EPITES ─────────────────────────────────────────────────────
local sg = Instance.new("ScreenGui")
sg.Name           = "AIO_GUI"
sg.ResetOnSpawn   = false
sg.IgnoreGuiInset = true
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sg.Parent         = LP:WaitForChild("PlayerGui")

-- Fo keret
local mainFrame = Instance.new("Frame", sg)
mainFrame.Size                  = UDim2.new(0, 280, 0, 420)
mainFrame.Position              = UDim2.new(0, 10, 0.5, -210)
mainFrame.BackgroundColor3      = Color3.fromRGB(8, 8, 14)
mainFrame.BackgroundTransparency= 0.08
mainFrame.BorderSizePixel       = 0
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 12)
local mainStroke = Instance.new("UIStroke", mainFrame)
mainStroke.Color     = Color3.fromRGB(80, 80, 160)
mainStroke.Thickness = 1.5

-- Cim sav
local titleBar = Instance.new("Frame", mainFrame)
titleBar.Size             = UDim2.new(1, 0, 0, 36)
titleBar.BackgroundColor3 = Color3.fromRGB(14, 10, 30)
titleBar.BorderSizePixel  = 0
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 12)

local titleLabel = Instance.new("TextLabel", titleBar)
titleLabel.Size                  = UDim2.new(1, -50, 1, 0)
titleLabel.Position              = UDim2.new(0, 10, 0, 0)
titleLabel.BackgroundTransparency= 1
titleLabel.Text                  = "DOMKA MODZ  -  AIO HUB"
titleLabel.TextColor3            = Color3.fromRGB(160, 120, 255)
titleLabel.Font                  = Enum.Font.GothamBold
titleLabel.TextSize              = 13
titleLabel.TextXAlignment        = Enum.TextXAlignment.Left

-- Osszes BE/KI gomb
local allBtn = Instance.new("TextButton", titleBar)
allBtn.Size                  = UDim2.new(0, 40, 0, 24)
allBtn.Position              = UDim2.new(1, -48, 0.5, -12)
allBtn.BackgroundColor3      = Color3.fromRGB(40, 180, 80)
allBtn.BorderSizePixel       = 0
allBtn.Text                  = "ALL"
allBtn.TextColor3            = Color3.new(1,1,1)
allBtn.Font                  = Enum.Font.GothamBold
allBtn.TextSize              = 11
Instance.new("UICorner", allBtn).CornerRadius = UDim.new(0, 6)

local allOn = true
allBtn.MouseButton1Click:Connect(function()
    allOn = not allOn
    Cfg.setAllEnabled(allOn)
    allBtn.BackgroundColor3 = allOn and Color3.fromRGB(40,180,80) or Color3.fromRGB(180,40,40)
    allBtn.Text = allOn and "ALL" or "OFF"
end)

-- Scroll
local scrollFrame = Instance.new("ScrollingFrame", mainFrame)
scrollFrame.Size                  = UDim2.new(1, -8, 1, -44)
scrollFrame.Position              = UDim2.new(0, 4, 0, 40)
scrollFrame.BackgroundTransparency= 1
scrollFrame.BorderSizePixel       = 0
scrollFrame.ScrollBarThickness    = 3
scrollFrame.ScrollBarImageColor3  = Color3.fromRGB(100, 80, 200)
scrollFrame.CanvasSize            = UDim2.new(0, 0, 0, 0)

local listLayout = Instance.new("UIListLayout", scrollFrame)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding   = UDim.new(0, 6)

local listPad = Instance.new("UIPadding", scrollFrame)
listPad.PaddingLeft   = UDim.new(0, 4)
listPad.PaddingRight  = UDim.new(0, 4)
listPad.PaddingTop    = UDim.new(0, 4)
listPad.PaddingBottom = UDim.new(0, 4)

-- Kartya definiciok
local CARD_DEFS = {
    -- ── KillAura ──────────────────────────────────────────────
    {
        cfgKey  = "KillAura",
        label   = "Kill Aura",
        color   = Color3.fromRGB(255, 50, 50),
        modKey  = nil,  -- combat nem ad vissza Module-t
        statFn  = function(_)
            local cfg = Cfg
            local range  = cfg.get("KillAura","RANGE")        or 24
            local mult   = cfg.get("KillAura","MULTIPLY")     or 2
            local freeze = cfg.get("KillAura","FREEZE_ENABLED") and "BE" or "KI"
            local prio   = cfg.get("KillAura","TARGET_PRIORITY") or "nearest"
            return "Range:"..range.."  x"..mult.."  Freeze:"..freeze.."  "..prio
        end,
        extras = {
            { label="Freeze",   cfgKey="KillAura", key="FREEZE_ENABLED" },
            { label="Players",  cfgKey="KillAura", key="ATTACK_PLAYERS" },
            { label="Underground", cfgKey="KillAura", key="UNDERGROUND_ENABLED" },
        },
        sliders = {
            { label="Range",    cfgKey="KillAura", key="RANGE",       min=5,  max=60,  step=1  },
            { label="x Mult",   cfgKey="KillAura", key="MULTIPLY",    min=1,  max=10,  step=1  },
            { label="Exec %",   cfgKey="KillAura", key="EXEC_THRESHOLD", min=0.05, max=0.5, step=0.05 },
            { label="MaxTargets", cfgKey="KillAura", key="MAX_TARGETS", min=1, max=20, step=1 },
        },
    },
    {
        cfgKey  = "BlockParry",
        label   = "Auto Block / Parry",
        color   = Color3.fromRGB(255, 200, 40),
        modKey  = "BlockParry",
        statFn  = function(stats)
            return "Block: " .. (stats.totalBlock or 0) .. "  Parry: " .. (stats.totalParry or 0)
        end,
        extras = {
            { label="Preemptiv", cfgKey="BlockParry", key="PREEMPTIVE" },
        },
    },
    {
        cfgKey  = "Vanish",
        label   = "Auto Vanish",
        color   = Color3.fromRGB(180, 60, 255),
        modKey  = "Vanish",
        statFn  = function(stats)
            return "V:" .. (stats.totalVanish or 0)
                .. " S:" .. (stats.totalStep or 0)
                .. " Ki:" .. (stats.ki or 0) .. "%"
                .. " Lanc:" .. (stats.chain or 0)
        end,
        extras = {
            { label="Post-Step", cfgKey="Vanish", key="POST_STEP" },
        },
    },
    {
        cfgKey  = "DragonBall",
        label   = "Auto Dragon Ball",
        color   = Color3.fromRGB(255, 170, 0),
        modKey  = "DragonBall",
        statFn  = function(stats)
            return "Earth:" .. (stats.earth or 0) .. "/7  Namek:" .. (stats.namek or 0) .. "/7"
        end,
        extras = {
            { label="Auto Summon", cfgKey="DragonBall", key="AUTO_SUMMON" },
        },
    },
    {
        cfgKey  = "Loot",
        label   = "Auto Loot Farm",
        color   = Color3.fromRGB(255, 160, 40),
        modKey  = "Loot",
        statFn  = function(stats)
            return "Talalt: " .. (stats.found or 0) .. "  Felvett: " .. (stats.collected or 0)
        end,
    },
    {
        cfgKey  = "Senzu",
        label   = "Auto Senzu Farm",
        color   = Color3.fromRGB(60, 220, 80),
        modKey  = "Senzu",
        statFn  = function(stats)
            return (stats.status or "-") .. "  " .. (stats.nextIn or 0) .. "s"
        end,
        extras = {
            { label="Auto Ultet", cfgKey="Senzu", key="AUTO_REPLANT" },
        },
    },
    {
        cfgKey  = "Daily",
        label   = "Auto Daily Farm",
        color   = Color3.fromRGB(80, 160, 255),
        modKey  = "Daily",
        statFn  = function(stats)
            return stats.status or "-"
        end,
        extras = {
            { label="Extras", cfgKey="Daily", key="CLAIM_EXTRAS" },
        },
    },
    {
        cfgKey  = "NPCFarm",
        label   = "Auto NPC Farm",
        color   = Color3.fromRGB(255, 60, 60),
        modKey  = "NPCFarm",
        statFn  = function(stats)
            return "Kills:" .. (stats.kills or 0) .. "  " .. (stats.target or "-")
        end,
        extras = {
            { label="Grab",   cfgKey="NPCFarm", key="GRAB_ENABLED" },
            { label="TP NPC", cfgKey="NPCFarm", key="TELEPORT_TO_NPC" },
        },
    },
}

local toggleBtns = {}
local statLabels = {}

local function buildCard(def, order)
    local card = Instance.new("Frame", scrollFrame)
    card.LayoutOrder           = order
    card.Size                  = UDim2.new(1, 0, 0, 0)
    card.AutomaticSize         = Enum.AutomaticSize.Y
    card.BackgroundColor3      = Color3.fromRGB(14, 12, 24)
    card.BackgroundTransparency= 0.3
    card.BorderSizePixel       = 0
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
    local cardStroke = Instance.new("UIStroke", card)
    cardStroke.Color        = def.color
    cardStroke.Thickness    = 1
    cardStroke.Transparency = 0.6

    local cardLayout = Instance.new("UIListLayout", card)
    cardLayout.SortOrder = Enum.SortOrder.LayoutOrder
    cardLayout.Padding   = UDim.new(0, 2)
    local cardPad = Instance.new("UIPadding", card)
    cardPad.PaddingLeft   = UDim.new(0, 8)
    cardPad.PaddingRight  = UDim.new(0, 8)
    cardPad.PaddingTop    = UDim.new(0, 6)
    cardPad.PaddingBottom = UDim.new(0, 6)

    -- Fejlec
    local header = Instance.new("Frame", card)
    header.Size                = UDim2.new(1, 0, 0, 24)
    header.BackgroundTransparency = 1
    header.LayoutOrder         = 1

    local lbl = Instance.new("TextLabel", header)
    lbl.Size                  = UDim2.new(1, -60, 1, 0)
    lbl.BackgroundTransparency= 1
    lbl.Text                  = def.label
    lbl.TextColor3            = def.color
    lbl.Font                  = Enum.Font.GothamBold
    lbl.TextSize              = 12
    lbl.TextXAlignment        = Enum.TextXAlignment.Left

    local enabled = Cfg.get(def.cfgKey, "enabled")
    local toggleBtn = Instance.new("TextButton", header)
    toggleBtn.Size            = UDim2.new(0, 50, 0, 20)
    toggleBtn.Position        = UDim2.new(1, -50, 0.5, -10)
    toggleBtn.BackgroundColor3= enabled and Color3.fromRGB(40,180,80) or Color3.fromRGB(160,40,40)
    toggleBtn.BorderSizePixel = 0
    toggleBtn.Text            = enabled and "BE" or "KI"
    toggleBtn.TextColor3      = Color3.new(1,1,1)
    toggleBtn.Font            = Enum.Font.GothamBold
    toggleBtn.TextSize        = 11
    Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 5)

    table.insert(toggleBtns, { cfgKey=def.cfgKey, key="enabled", btn=toggleBtn })

    toggleBtn.MouseButton1Click:Connect(function()
        local new = Cfg.toggle(def.cfgKey)
        toggleBtn.BackgroundColor3 = new and Color3.fromRGB(40,180,80) or Color3.fromRGB(160,40,40)
        toggleBtn.Text             = new and "BE" or "KI"
        cardStroke.Transparency    = new and 0.6 or 0.9
    end)

    -- Stat sor
    local statLbl = Instance.new("TextLabel", card)
    statLbl.Size                  = UDim2.new(1, 0, 0, 14)
    statLbl.BackgroundTransparency= 1
    statLbl.TextColor3            = Color3.fromRGB(160, 160, 180)
    statLbl.Font                  = Enum.Font.Gotham
    statLbl.TextSize              = 10
    statLbl.TextXAlignment        = Enum.TextXAlignment.Left
    statLbl.Text                  = "..."
    statLbl.LayoutOrder           = 2
    table.insert(statLabels, { modKey=def.modKey, lbl=statLbl, statFn=def.statFn })

    -- Slider-ek
    if def.sliders then
        for si, sl in ipairs(def.sliders) do
            local slRow = Instance.new("Frame", card)
            slRow.Size                 = UDim2.new(1, 0, 0, 20)
            slRow.BackgroundTransparency= 1
            slRow.LayoutOrder          = 3 + si

            -- Label
            local slLabel = Instance.new("TextLabel", slRow)
            slLabel.Size               = UDim2.new(0, 70, 1, 0)
            slLabel.BackgroundTransparency = 1
            slLabel.Text               = sl.label .. ":"
            slLabel.TextColor3         = Color3.fromRGB(180, 180, 180)
            slLabel.Font               = Enum.Font.Gotham
            slLabel.TextSize           = 9
            slLabel.TextXAlignment     = Enum.TextXAlignment.Left

            -- Érték label
            local curVal = Cfg.get(sl.cfgKey, sl.key) or sl.min
            local valLabel = Instance.new("TextLabel", slRow)
            valLabel.Size              = UDim2.new(0, 35, 1, 0)
            valLabel.Position          = UDim2.new(0, 72, 0, 0)
            valLabel.BackgroundTransparency = 1
            valLabel.Text              = tostring(curVal)
            valLabel.TextColor3        = Color3.fromRGB(255, 200, 60)
            valLabel.Font              = Enum.Font.GothamBold
            valLabel.TextSize          = 9

            -- Slider pálya
            local track = Instance.new("Frame", slRow)
            track.Size             = UDim2.new(1, -115, 0, 6)
            track.Position         = UDim2.new(0, 110, 0.5, -3)
            track.BackgroundColor3 = Color3.fromRGB(30, 25, 50)
            track.BorderSizePixel  = 0
            Instance.new("UICorner", track).CornerRadius = UDim.new(0, 3)

            local fill = Instance.new("Frame", track)
            fill.BackgroundColor3 = def.color
            fill.BorderSizePixel  = 0
            Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 3)

            local thumb = Instance.new("TextButton", track)
            thumb.Size             = UDim2.new(0, 10, 0, 14)
            thumb.BackgroundColor3 = Color3.fromRGB(220, 220, 255)
            thumb.BorderSizePixel  = 0
            thumb.Text             = ""
            Instance.new("UICorner", thumb).CornerRadius = UDim.new(0, 5)

            -- Pozíció frissítő
            local function updateSlider(val)
                val = math.clamp(val, sl.min, sl.max)
                -- step kerekítés
                local steps = math.round((val - sl.min) / sl.step)
                val = sl.min + steps * sl.step
                -- float kerekítés
                val = math.floor(val * 100 + 0.5) / 100
                local pct = (val - sl.min) / (sl.max - sl.min)
                fill.Size          = UDim2.new(pct, 0, 1, 0)
                thumb.Position     = UDim2.new(pct, -5, 0.5, -7)
                valLabel.Text      = tostring(val)
                Cfg.set(sl.cfgKey, sl.key, val)
            end

            -- Kezdeti pozíció
            local initPct = (curVal - sl.min) / (sl.max - sl.min)
            fill.Size      = UDim2.new(math.clamp(initPct,0,1), 0, 1, 0)
            thumb.Position = UDim2.new(math.clamp(initPct,0,1), -5, 0.5, -7)

            -- Drag logika
            local UIS2 = game:GetService("UserInputService")
            local draggingSlider = false
            thumb.InputBegan:Connect(function(inp)
                if inp.UserInputType == Enum.UserInputType.MouseButton1
                or inp.UserInputType == Enum.UserInputType.Touch then
                    draggingSlider = true
                end
            end)
            UIS2.InputChanged:Connect(function(inp)
                if draggingSlider and (inp.UserInputType == Enum.UserInputType.MouseMovement
                or inp.UserInputType == Enum.UserInputType.Touch) then
                    local trackAbs = track.AbsolutePosition
                    local trackSz  = track.AbsoluteSize
                    local pct2     = math.clamp((inp.Position.X - trackAbs.X) / trackSz.X, 0, 1)
                    local newVal   = sl.min + pct2 * (sl.max - sl.min)
                    updateSlider(newVal)
                end
            end)
            UIS2.InputEnded:Connect(function(inp)
                if inp.UserInputType == Enum.UserInputType.MouseButton1
                or inp.UserInputType == Enum.UserInputType.Touch then
                    draggingSlider = false
                end
            end)
            -- Track kattintás
            track.InputBegan:Connect(function(inp)
                if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                    local pct2 = math.clamp((inp.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
                    updateSlider(sl.min + pct2 * (sl.max - sl.min))
                end
            end)
        end
    end

    -- Extra toggle-ok
    if def.extras then
        local extraRow = Instance.new("Frame", card)
        extraRow.Size                 = UDim2.new(1, 0, 0, 0)
        extraRow.AutomaticSize        = Enum.AutomaticSize.Y
        extraRow.BackgroundTransparency= 1
        extraRow.LayoutOrder          = 3
        local exLayout = Instance.new("UIListLayout", extraRow)
        exLayout.FillDirection = Enum.FillDirection.Horizontal
        exLayout.SortOrder     = Enum.SortOrder.LayoutOrder
        exLayout.Padding       = UDim.new(0, 4)

        for i, ex in ipairs(def.extras) do
            local exVal = Cfg.get(ex.cfgKey, ex.key)
            local exBtn = Instance.new("TextButton", extraRow)
            exBtn.Size            = UDim2.new(0, 85, 0, 18)
            exBtn.BackgroundColor3= exVal and Color3.fromRGB(30,120,60) or Color3.fromRGB(80,30,30)
            exBtn.BorderSizePixel = 0
            exBtn.Text            = ex.label .. ": " .. (exVal and "BE" or "KI")
            exBtn.TextColor3      = Color3.fromRGB(200,200,200)
            exBtn.Font            = Enum.Font.Gotham
            exBtn.TextSize        = 9
            exBtn.LayoutOrder     = i
            Instance.new("UICorner", exBtn).CornerRadius = UDim.new(0, 4)

            local exBtnRef = exBtn
            local exRef    = ex
            exBtnRef.MouseButton1Click:Connect(function()
                local cur = Cfg.get(exRef.cfgKey, exRef.key)
                local new = not cur
                Cfg.set(exRef.cfgKey, exRef.key, new)
                exBtnRef.BackgroundColor3 = new and Color3.fromRGB(30,120,60) or Color3.fromRGB(80,30,30)
                exBtnRef.Text = exRef.label .. ": " .. (new and "BE" or "KI")
            end)
        end
    end
end

for i, def in ipairs(CARD_DEFS) do
    buildCard(def, i)
end

listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 8)
end)

-- Config valtozas -> toggle gomb frissites
Cfg.onChange(function(mod, key, val)
    for _, tb in ipairs(toggleBtns) do
        if tb.cfgKey == mod and tb.key == key then
            if key == "enabled" then
                tb.btn.BackgroundColor3 = val and Color3.fromRGB(40,180,80) or Color3.fromRGB(160,40,40)
                tb.btn.Text = val and "BE" or "KI"
            end
        end
    end
end)

-- Stat frissito loop
task.spawn(function()
    while true do
        task.wait(0.5)
        local mods = _G._AIO_Modules or {}
        for _, sl in ipairs(statLabels) do
            local mod = mods[sl.modKey]
            if mod and mod.getStats then
                local ok, stats = pcall(mod.getStats)
                if ok and stats and sl.statFn then
                    local ok2, text = pcall(sl.statFn, stats)
                    if ok2 and text then sl.lbl.Text = text end
                end
            end
        end
    end
end)

-- Huzható ablak
do
    local UIS = game:GetService("UserInputService")
    local dragging, dragStart, startPos
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging  = true
            dragStart = input.Position
            startPos  = mainFrame.Position
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

print("[GUI_Controller] OK - " .. #CARD_DEFS .. " kartya betoltve")
