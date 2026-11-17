-- autoquest.lua
-- A modul kódja be van építve – nem kell ReplicatedStorage.Modules.AutoQuest

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")

local Cfg = _G._AIO_Config
if not Cfg then warn("[AutoQuest] _Config nem talalhato!") ; return end

-- ════════════════════════════════════════════════════════════════
--  BEÉPÍTETT AutoQuest MODUL
-- ════════════════════════════════════════════════════════════════
local AutoQuest = {}

AutoQuest.enabled       = false
AutoQuest.autoDialog    = true
AutoQuest.autoBoard     = false
AutoQuest.autoErrand    = false
AutoQuest.autoDaily     = false
AutoQuest.autoComplete  = true
AutoQuest.autoTeleport  = true
AutoQuest.autoDialogue  = true
AutoQuest.acceptDelay   = 0
AutoQuest.respectLevel  = true
AutoQuest.cooldown      = 2
AutoQuest.teleportOffset      = 12
AutoQuest.teleportHeight      = 4
AutoQuest.reteleportDistance  = 80
AutoQuest.checkInterval       = 1
AutoQuest.dialogueDelay       = 0.6
AutoQuest.filter              = nil

AutoQuest.activeQuests  = {}
AutoQuest.lastOffer     = nil
AutoQuest.questNames    = {}
AutoQuest.sideQuests    = {}
AutoQuest.hiddenQuests  = {}
AutoQuest.boardQuests   = {}
AutoQuest.errands       = {}
AutoQuest.errandMentors = {}

local lastAttempt = {}

local function rememberName(questId, title)
    if type(questId) == "string" and type(title) == "string" and title ~= "" then
        AutoQuest.questNames[questId] = title
    end
end

local function newSignal(name)
    local ev = Instance.new("BindableEvent")
    ev.Name   = name
    ev.Parent = script
    return ev
end
AutoQuest.Offer        = newSignal("AQOffer")
AutoQuest.Accepted     = newSignal("AQAccepted")
AutoQuest.Rejected     = newSignal("AQRejected")
AutoQuest.Queued       = newSignal("AQQueued")
AutoQuest.Progress     = newSignal("AQProgress")
AutoQuest.Ended        = newSignal("AQEnded")
AutoQuest.StateChanged = newSignal("AQStateChanged")

local CollectionService = game:GetService("CollectionService")
local LocalPlayer       = Players.LocalPlayer

local function getRoot()
    local c = LocalPlayer and LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function getRemotes()
    return require(game:GetService("ReplicatedStorage").Modules.Remotes)
end

function AutoQuest.accept(questId)
    if type(questId) ~= "string" then return false, "invalid questId" end
    local ok, result = pcall(function()
        return getRemotes().RequestAcceptQuest:InvokeServer(questId)
    end)
    if not ok then return false, "remote error" end
    if type(result) == "table" and result.ok then
        AutoQuest.activeQuests[questId] = AutoQuest.activeQuests[questId] or { questId = questId }
        return true, nil
    end
    return false, (type(result) == "table" and result.reason) or "rejected"
end

function AutoQuest.acceptErrand()
    local ok, result = pcall(function()
        return getRemotes().RequestAcceptErrand:InvokeServer()
    end)
    return ok and type(result) == "table" and result.ok == true,
           (type(result) == "table" and result.reason) or nil
end

function AutoQuest.claimDaily()
    local ok, result = pcall(function()
        return getRemotes().ClaimDailyGoal:InvokeServer()
    end)
    return ok and tonumber(result) ~= nil and tonumber(result) > 0
end

function AutoQuest.setEnabled(state)
    AutoQuest.enabled = state == true
    AutoQuest.StateChanged:Fire(AutoQuest.enabled)
end

function AutoQuest.setFilter(fn)
    if type(fn) == "function" or fn == nil then AutoQuest.filter = fn end
end

function AutoQuest.getActiveQuests()
    local copy = {}
    for id, info in pairs(AutoQuest.activeQuests) do copy[id] = info end
    return copy
end

function AutoQuest.getQuestName(questId)
    return AutoQuest.questNames[questId] or questId
end

function AutoQuest.onAccepted(fn) return AutoQuest.Accepted.Event:Connect(fn) end
function AutoQuest.onRejected(fn) return AutoQuest.Rejected.Event:Connect(fn) end
function AutoQuest.onEnded(fn)    return AutoQuest.Ended.Event:Connect(fn)    end

local function buildObjective(payload, questId)
    if type(payload) ~= "table" then return nil end
    local kind      = payload.objectiveKind
    local total     = tonumber(payload.total) or tonumber(payload.maxEnemies) or 0
    local remaining = tonumber(payload.remaining)
    local defeated  = remaining ~= nil and math.max(0, total - remaining) or nil
    local line = payload.objectiveLine
    if type(line) ~= "string" and type(payload.objectiveText) == "table" then
        line = payload.objectiveText.line
    end
    local hint = type(payload.objectiveText) == "table" and payload.objectiveText.hint or nil
    return {
        name        = payload.title or AutoQuest.getQuestName(questId),
        kind        = kind,
        enemy       = payload.enemyName,
        targetCount = total > 0 and total or nil,
        defeated    = defeated,
        line        = line,
        hint        = hint,
        where       = payload.arenaName,
        position    = type(payload.arenaPosition) == "Vector3" and payload.arenaPosition or nil,
        secondsLeft = tonumber(payload.secondsLeft),
    }
end

function AutoQuest.getObjective(questId)
    local info = AutoQuest.activeQuests[questId]
    if type(info) ~= "table" then return nil end
    return info.objective or { name = AutoQuest.getQuestName(questId) }
end

function AutoQuest.getActiveObjectives()
    local list = {}
    for id in pairs(AutoQuest.activeQuests) do
        local obj = AutoQuest.getObjective(id)
        if obj then obj.id = id ; table.insert(list, obj) end
    end
    return list
end

function AutoQuest.teleportTo(position)
    local root = getRoot()
    if not root or type(position) ~= "Vector3" then return false end
    local offsetDir = root.Position - position
    offsetDir = Vector3.new(offsetDir.X, 0, offsetDir.Z)
    if offsetDir.Magnitude < 0.5 then offsetDir = Vector3.new(1, 0, 0)
    else offsetDir = offsetDir.Unit end
    root.CFrame = CFrame.lookAt(
        position + offsetDir * AutoQuest.teleportOffset + Vector3.new(0, AutoQuest.teleportHeight, 0),
        position + Vector3.new(0, 2, 0)
    )
    return true
end

function AutoQuest.resolveTagTarget(tag)
    if type(tag) ~= "string" then return nil end
    local root = getRoot()
    local from = root and root.Position or Vector3.zero
    local best, bestDist = nil, math.huge
    for _, model in CollectionService:GetTagged(tag) do
        if model:IsA("Model") then
            local ok, pos = pcall(function() return model:GetPivot().Position end)
            if ok and type(pos) == "Vector3" then
                local dist = (pos - from).Magnitude
                if dist < bestDist then best, bestDist = pos, dist end
            end
        end
    end
    return best
end

function AutoQuest.findNpcByName(name)
    if type(name) ~= "string" or name == "" then return nil end
    local lower = string.lower(name)
    for _, container in { workspace:FindFirstChild("NPCs"), workspace } do
        if container then
            for _, model in container:GetChildren() do
                if model:IsA("Model") and string.lower(model.Name) == lower then
                    local ok, pos = pcall(function() return model:GetPivot().Position end)
                    if ok then return pos end
                end
            end
        end
    end
    return nil
end

function AutoQuest.getObjectiveTarget(questId)
    if type(questId) ~= "string" then return nil end
    local info = AutoQuest.activeQuests[questId]
    if type(info) == "table" and type(info.objective) == "table"
    and type(info.objective.position) == "Vector3" then
        return info.objective.position
    end
    for _, q in ipairs(AutoQuest.sideQuests) do
        if type(q) == "table" and q.id == questId and type(q.visit) == "table" then
            local pos = AutoQuest.resolveTagTarget(q.visit.tag)
            if pos then return pos end
        end
    end
    for _, q in ipairs(AutoQuest.hiddenQuests) do
        if type(q) == "table" and q.id == questId and type(q.visit) == "table" then
            local pos = AutoQuest.resolveTagTarget(q.visit.tag)
            if pos then return pos end
        end
    end
    local errandId = string.match(questId, "^errand:(.+)$")
    if errandId then
        local mentor = AutoQuest.errandMentors[errandId]
        if mentor then
            local pos = AutoQuest.findNpcByName(mentor)
            if pos then return pos end
        end
    end
    return nil
end

function AutoQuest.goToObjective(questId)
    local target = AutoQuest.getObjectiveTarget(questId)
    return target and AutoQuest.teleportTo(target) or false
end

function AutoQuest.refreshSideQuests()
    if not RunService:IsClient() then return {} end
    local ok, result = pcall(function() return getRemotes().GetSideQuests:InvokeServer() end)
    if ok and type(result) == "table" then AutoQuest.sideQuests = result end
    return AutoQuest.sideQuests
end

function AutoQuest.refreshHiddenQuests()
    if not RunService:IsClient() then return {} end
    local ok, result = pcall(function() return getRemotes().GetHiddenVisits:InvokeServer() end)
    if ok and type(result) == "table" then AutoQuest.hiddenQuests = result end
    return AutoQuest.hiddenQuests
end

local function cooldownPassed(questId)
    local now  = os.clock()
    local last = lastAttempt[questId]
    if last and now - last < AutoQuest.cooldown then return false end
    lastAttempt[questId] = now
    return true
end

local function tryAccept(questId, offer, source)
    if not AutoQuest.enabled             then return end
    if not cooldownPassed(questId)       then return end
    if AutoQuest.respectLevel and source == "dialog" then
        local minLevel    = tonumber(offer and offer.minLevel)   or 0
        local playerLevel = tonumber(offer and offer.playerLevel) or 0
        if minLevel > 0 and playerLevel < minLevel then
            AutoQuest.Rejected:Fire(questId, "level too low") ; return
        end
    end
    if AutoQuest.filter then
        local ok, allowed = pcall(AutoQuest.filter, offer, source)
        if not ok or allowed == false then return end
    end
    local ok, reason = AutoQuest.accept(questId)
    if ok then AutoQuest.Accepted:Fire(questId, source)
    else       AutoQuest.Rejected:Fire(questId, reason) end
end

-- Remote event összekötések
if RunService:IsClient() and LocalPlayer then
    local remotes = getRemotes()

    task.spawn(AutoQuest.refreshSideQuests)
    task.spawn(AutoQuest.refreshHiddenQuests)

    remotes.SideQuestsChanged.OnClientEvent:Connect(function(data)
        if type(data) == "table" then AutoQuest.sideQuests = data end
    end)
    remotes.HiddenVisitsChanged.OnClientEvent:Connect(function(data)
        if type(data) == "table" then AutoQuest.hiddenQuests = data end
    end)

    remotes.OpenQuestDialog.OnClientEvent:Connect(function(payload)
        if type(payload) ~= "table" or type(payload.questId) ~= "string" then return end
        rememberName(payload.questId, payload.title)
        local obj = buildObjective(payload, payload.questId)
        if obj then
            local entry = AutoQuest.activeQuests[payload.questId]
            if type(entry) == "table" then entry.objective = obj
            else AutoQuest.activeQuests[payload.questId] = { questId=payload.questId, objective=obj } end
        end
        AutoQuest.lastOffer = payload
        AutoQuest.Offer:Fire(payload, "dialog")
        if AutoQuest.autoDialog then
            task.delay(AutoQuest.acceptDelay, function() tryAccept(payload.questId, payload, "dialog") end)
        end
    end)

    remotes.OpenQuestBoard.OnClientEvent:Connect(function(payload)
        if type(payload) ~= "table" then return end
        if type(payload.quests) == "table" then
            AutoQuest.boardQuests = payload.quests
            for _, q in ipairs(payload.quests) do
                if type(q) == "table" then rememberName(q.questId, q.title) end
            end
        end
        if type(payload.errands) == "table" then
            AutoQuest.errands = payload.errands
            for _, errand in ipairs(payload.errands) do
                if type(errand) == "table" and type(errand.errandId) == "string" then
                    AutoQuest.errandMentors[errand.errandId] = errand.mentorName
                end
            end
        end
        if AutoQuest.autoErrand and AutoQuest.enabled and type(payload.errands) == "table" then
            for _, errand in ipairs(payload.errands) do
                if type(errand) == "table" and type(errand.errandId) == "string" then
                    task.delay(AutoQuest.acceptDelay, function()
                        local ok = AutoQuest.acceptErrand()
                        if ok then AutoQuest.Accepted:Fire(errand.errandId, "errand") end
                    end)
                    break
                end
            end
        end
        if AutoQuest.autoDaily and AutoQuest.enabled and payload.ready == true then
            task.delay(AutoQuest.acceptDelay, function()
                if AutoQuest.claimDaily() then AutoQuest.Accepted:Fire("daily", "daily") end
            end)
        end
        if AutoQuest.autoBoard and AutoQuest.enabled and type(payload.quests) == "table" then
            for _, quest in ipairs(payload.quests) do
                if type(quest) == "table" and type(quest.questId) == "string"
                and not quest.daily and not quest.objective and not quest.errandId then
                    task.delay(AutoQuest.acceptDelay, function() tryAccept(quest.questId, quest, "board") end)
                    break
                end
            end
        end
    end)

    remotes.OpenDialogue.OnClientEvent:Connect(function(payload)
        if not (AutoQuest.enabled and AutoQuest.autoComplete and AutoQuest.autoDialogue) then return end
        if type(payload) ~= "table" then return end
        task.delay(AutoQuest.dialogueDelay, function()
            if type(payload.actions) == "table" then
                for _, action in ipairs(payload.actions) do
                    if type(action) == "table" and type(action.id) == "string" then
                        pcall(function() remotes.DialogueAction:FireServer(action.id) end)
                        break
                    end
                end
            end
            task.delay(AutoQuest.dialogueDelay, function()
                pcall(function() remotes.DialogueClosed:FireServer(true) end)
            end)
        end)
    end)

    remotes.QuestQueued.OnClientEvent:Connect(function(payload)
        if type(payload) == "table" then
            local id = payload.questId or payload.id or payload.lesson
            if type(id) == "string" then AutoQuest.activeQuests[id] = payload end
            AutoQuest.Queued:Fire(payload)
        end
    end)

    remotes.QuestProgress.OnClientEvent:Connect(function(payload)
        if type(payload) == "table" then
            local id = payload.questId or payload.id or payload.lesson or payload.runId
            if type(id) == "string" then
                local obj   = buildObjective(payload, id)
                local entry = AutoQuest.activeQuests[id]
                if type(entry) == "table" then
                    if obj then entry.objective = obj end
                else
                    AutoQuest.activeQuests[id] = { questId=id, objective=obj }
                end
                rememberName(id, payload.title)
            end
            AutoQuest.Progress:Fire(payload)
        end
    end)

    remotes.QuestEnded.OnClientEvent:Connect(function(payload)
        if type(payload) == "table" then
            local id = payload.questId or payload.id or payload.lesson
            if type(id) == "string" then AutoQuest.activeQuests[id] = nil end
            AutoQuest.Ended:Fire(payload)
        end
    end)

    -- Auto teleport a célponthoz
    task.spawn(function()
        while true do
            task.wait(AutoQuest.checkInterval)
            if AutoQuest.enabled and AutoQuest.autoComplete and AutoQuest.autoTeleport then
                local root = getRoot()
                if root then
                    for id in pairs(AutoQuest.activeQuests) do
                        local target = AutoQuest.getObjectiveTarget(id)
                        if target and (root.Position - target).Magnitude > AutoQuest.reteleportDistance then
                            AutoQuest.teleportTo(target) ; break
                        end
                    end
                end
            end
        end
    end)
end

-- ════════════════════════════════════════════════════════════════
--  HÍDRÉSZ: Config szinkron + stat frissítő + modul regisztráció
-- ════════════════════════════════════════════════════════════════
local bridgeStats = {
    active    = 0,
    accepted  = 0,
    ended     = 0,
    lastQuest = "-",
    status    = "Készenlét",
}

AutoQuest.onAccepted(function(questId)
    bridgeStats.accepted  += 1
    bridgeStats.lastQuest  = tostring(questId)
    bridgeStats.status     = "Elfogadva: " .. tostring(questId)
end)
AutoQuest.onEnded(function(payload)
    bridgeStats.ended  += 1
    bridgeStats.status  = "Befejezve"
    local id = type(payload) == "table"
        and (payload.questId or payload.id or payload.lesson)
        or tostring(payload)
    if id then bridgeStats.lastQuest = tostring(id) end
end)

task.spawn(function()
    while true do
        task.wait(1)
        local count = 0
        for _ in pairs(AutoQuest.activeQuests) do count += 1 end
        bridgeStats.active = count
        if count > 0 then
            bridgeStats.status = string.format("Farmolás (%d aktív)", count)
        end
    end
end)

-- Quest szűrő – selectedQuestId alapján
AutoQuest.setFilter(function(offer, source)
    if not Cfg.get("AutoQuest", "enabled") then return false end
    local selectedId = Cfg.get("AutoQuest", "selectedQuestId") or ""
    if selectedId == "" then return true end
    local offerId    = offer and (offer.questId or offer.id or "") or ""
    local offerTitle = string.lower(offer and offer.title or "")
    local searchLow  = string.lower(selectedId)
    return string.lower(offerId) == searchLow
        or string.find(offerTitle, searchLow, 1, true) ~= nil
end)

local SYNC_KEYS = {
    "autoDialog","autoBoard","autoErrand","autoDaily",
    "autoComplete","autoTeleport","autoDialogue",
    "acceptDelay","cooldown","teleportOffset",
    "teleportHeight","checkInterval","dialogueDelay",
}
local function syncToModule()
    AutoQuest.setEnabled(Cfg.get("AutoQuest","enabled") == true)
    for _, key in ipairs(SYNC_KEYS) do
        local val = Cfg.get("AutoQuest", key)
        if val ~= nil then AutoQuest[key] = val end
    end
end
syncToModule()

Cfg.onChange(function(mod, key, val)
    if mod ~= "AutoQuest" then return end
    if key == "enabled" then
        AutoQuest.setEnabled(val == true)
        bridgeStats.status = val and "Aktív" or "Kikapcsolva"
    elseif key ~= "selectedQuestId" then
        AutoQuest[key] = val
    end
end)

_G._AIO_Modules = _G._AIO_Modules or {}
_G._AIO_Modules["AutoQuest"] = {
    getStats = function()
        return {
            active    = bridgeStats.active,
            accepted  = bridgeStats.accepted,
            ended     = bridgeStats.ended,
            lastQuest = bridgeStats.lastQuest,
            status    = bridgeStats.status,
        }
    end,
    getQuestList = function()
        local list, seen = {}, {}
        local function add(id, name, kind)
            if seen[id] then return end ; seen[id] = true
            table.insert(list, { id=id, name=name, kind=kind })
        end
        for _, q in ipairs(AutoQuest.sideQuests)   do if type(q)=="table" and q.id      then add(q.id,      AutoQuest.getQuestName(q.id),      "side")   end end
        for _, q in ipairs(AutoQuest.hiddenQuests)  do if type(q)=="table" and q.id      then add(q.id,      AutoQuest.getQuestName(q.id),      "hidden") end end
        for _, q in ipairs(AutoQuest.boardQuests)   do if type(q)=="table" and q.questId then add(q.questId, AutoQuest.getQuestName(q.questId), "board")  end end
        for id in pairs(AutoQuest.activeQuests) do add(id, AutoQuest.getQuestName(id), "active") end
        return list
    end,
    acceptQuest    = function(questId) return AutoQuest.accept(questId) end,
    getObjective   = function(questId) return AutoQuest.getObjective(questId) end,
    goToObjective  = function(questId) return AutoQuest.goToObjective(questId) end,
}

print("[AutoQuest] OK")
