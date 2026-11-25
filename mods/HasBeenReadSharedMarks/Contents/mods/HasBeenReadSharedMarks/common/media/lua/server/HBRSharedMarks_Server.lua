-- Has Been Read - Shared Marks (B42), server side.
-- Keeps a server-wide list and one list per faction in global mod data (saved with the world),
-- and sends changes to the players who share each list.

if isClient() then return end

local MODULE = "HBRShared"
local DATA_KEY = "HBRSharedMarks"

local function data()
    local d = ModData.getOrCreate(DATA_KEY)
    d.server = d.server or {}
    d.faction = d.faction or {}
    return d
end

local function factionName(player)
    local ok, name = pcall(function()
        local f = Faction.getPlayerFaction(player)
        return f and f:getName() or nil
    end)
    return ok and name or nil
end

local function onClientCommand(module, command, player, args)
    if module ~= MODULE or not player then return end
    local d = data()
    local fname = factionName(player)

    if command == "get" then
        sendServerCommand(player, MODULE, "full", {
            server = d.server,
            faction = fname and d.faction[fname] or {},
            factionName = fname,
        })
    elseif command == "set" and type(args) == "table" and type(args.keys) == "table" then
        local scope = args.scope == "server" and "server" or "faction"
        local list
        if scope == "server" then
            list = d.server
        elseif fname then
            d.faction[fname] = d.faction[fname] or {}
            list = d.faction[fname]
        end
        if not list then return end
        local keys, n = {}, 0
        for _, k in pairs(args.keys) do
            if type(k) == "string" and #k < 200 and n < 500 then
                list[k] = args.value and true or nil
                n = n + 1
                keys[n] = k
            end
        end
        if n == 0 then return end
        local players = getOnlinePlayers()
        for i = 0, players:size() - 1 do
            local p = players:get(i)
            if scope == "server" or factionName(p) == fname then
                sendServerCommand(p, MODULE, "delta", { scope = scope, factionName = fname, keys = keys, value = args.value and true or false })
            end
        end
    end
end

Events.OnClientCommand.Add(onClientCommand)
