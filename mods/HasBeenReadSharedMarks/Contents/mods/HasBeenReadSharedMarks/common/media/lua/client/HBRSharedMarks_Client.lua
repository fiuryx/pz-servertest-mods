-- Has Been Read - Shared Marks (B42), client side.
--
-- Has Been Read keeps each player's item marks ("I already have this book") in that player's own
-- data. This add-on lets each player choose, in the Has Been Read options, which marks they see:
--   1. Only mine        - like the original mod.
--   2. Whole server     - my marks plus the server-wide list.
--   3. My faction       - my marks plus my faction's list.
-- In modes 2 and 3, marking or unmarking a book (by hand or with auto-mark) also updates that list
-- for everyone sharing it. The player's own marks are always kept apart, so going back to
-- "Only mine" shows exactly the player's marks again.
--
-- How it works: Has Been Read draws from player modData P4HasBeenRead.markedMap. Every second we
-- compare that table with what we last wrote there; new keys are marks the player made, missing
-- keys are marks the player removed. Then we write back "own marks + shared list".

local MODULE = "HBRShared"
local MODE_OWN, MODE_SERVER, MODE_FACTION = 1, 2, 3

local S = {
    shared = { server = {}, faction = {} },   -- last lists received from the server
    factionName = nil,
    lastView = {},                            -- keys we wrote into markedMap last time
    lastMode = nil,
    ready = false,                            -- true once the server sent the lists
    ticks = 0,
    askTicks = 0,
}

-- Option inside the Has Been Read options page (own page as a fallback).
local option
local function addOption()
    local api = PZAPI and PZAPI.ModOptions
    if not api then return end
    local opts = api.getOptions and api:getOptions("P4HasBeenRead")
    if not opts then opts = api:create("HasBeenReadSharedMarks", "Has Been Read - Shared Marks") end
    option = opts:addComboBox("HBRSharedMode", getText("UI_HBRShared_Option_Name"), getText("UI_HBRShared_Option_Tooltip"))
    option:addItem(getText("UI_HBRShared_Option_Own"), true)
    option:addItem(getText("UI_HBRShared_Option_Server"), false)
    option:addItem(getText("UI_HBRShared_Option_Faction"), false)
end
pcall(addOption)

local function mode()
    local v = option and option:getValue() or MODE_OWN
    if not isClient() then return MODE_OWN end   -- single player: nothing to share
    return v or MODE_OWN
end

local function hbrData(player)
    local md = player:getModData()
    md.P4HasBeenRead = md.P4HasBeenRead or { doNotAutoMark = false }
    md.P4HasBeenRead.markedMap = md.P4HasBeenRead.markedMap or {}
    return md.P4HasBeenRead
end

local function ownMarks(player)
    local md = player:getModData()
    if not md.HBRShared then
        -- First run: the marks the player already had become their own marks.
        md.HBRShared = { own = {} }
        for k, v in pairs(hbrData(player).markedMap) do
            if v then md.HBRShared.own[k] = true end
        end
    end
    md.HBRShared.own = md.HBRShared.own or {}
    return md.HBRShared.own
end

local function sharedList(m)
    if m == MODE_SERVER then return S.shared.server end
    if m == MODE_FACTION and S.factionName then return S.shared.faction end
    return nil
end

local function send(m, keys, value)
    if #keys == 0 then return end
    local scope = (m == MODE_SERVER) and "server" or "faction"
    sendClientCommand(MODULE, "set", { scope = scope, keys = keys, value = value })
    -- update our copy now; the server echo makes it final
    local list = sharedList(m)
    if list then for _, k in ipairs(keys) do list[k] = value or nil end end
end

local function sync(player)
    local m = mode()
    if m ~= MODE_OWN and not S.ready then return end  -- wait for the lists
    local view = hbrData(player).markedMap
    local own = ownMarks(player)
    local changed = false

    -- 1) What did the player change since our last write?
    if S.lastMode == m then
        local added, removed = {}, {}
        for k, v in pairs(view) do
            if v and not S.lastView[k] then added[#added + 1] = k end
        end
        for k in pairs(S.lastView) do
            if not view[k] then removed[#removed + 1] = k end
        end
        for _, k in ipairs(added) do own[k] = true; changed = true end
        for _, k in ipairs(removed) do own[k] = nil; changed = true end
        if m ~= MODE_OWN then
            send(m, added, true)
            send(m, removed, false)
        end
    end

    -- 2) Write back: own marks + the shared list of the chosen mode.
    local wanted = {}
    for k in pairs(own) do wanted[k] = true end
    local list = sharedList(m)
    if list then for k, v in pairs(list) do if v then wanted[k] = true end end end
    for k in pairs(view) do if not wanted[k] then view[k] = nil end end
    for k in pairs(wanted) do if not view[k] then view[k] = true end end

    S.lastView = wanted
    S.lastMode = m
    if changed then player:transmitModData() end
end

local function onTick()
    local player = getSpecificPlayer(0)
    if not player or player:isDead() then return end
    S.ticks = S.ticks + 1
    S.askTicks = S.askTicks + 1
    if isClient() and (S.askTicks >= 18000 or (not S.ready and S.askTicks >= 300)) then
        -- refresh the lists every few minutes (faction changes) and retry until they arrive
        S.askTicks = 0
        sendClientCommand(MODULE, "get", {})
    end
    if S.ticks < 60 then return end
    S.ticks = 0
    sync(player)
end

local function onServerCommand(module, command, args)
    if module ~= MODULE or type(args) ~= "table" then return end
    if command == "full" then
        S.shared.server = args.server or {}
        S.shared.faction = args.faction or {}
        S.factionName = args.factionName
        S.ready = true
    elseif command == "delta" then
        local list = (args.scope == "server") and S.shared.server or S.shared.faction
        if args.scope == "faction" and args.factionName ~= S.factionName then return end
        for _, k in pairs(args.keys or {}) do list[k] = args.value and true or nil end
    end
end

local function onGameStart()
    if isClient() then sendClientCommand(MODULE, "get", {}) end
end

Events.OnTick.Add(function() pcall(onTick) end)
Events.OnServerCommand.Add(onServerCommand)
Events.OnGameStart.Add(onGameStart)
