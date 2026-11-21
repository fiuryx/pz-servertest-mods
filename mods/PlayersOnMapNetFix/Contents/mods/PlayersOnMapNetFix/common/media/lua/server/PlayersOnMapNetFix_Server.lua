-- Players On Map - Network Fix (B42), server side.
-- Players On Map sends the full player list to every client about 10 times per second.
-- Here it is sent once per second, and not at all while nobody is online. The dots of
-- nearby players are drawn from each client's own game, so they keep moving smoothly;
-- far players on the map update once per second.

if not isServer() then return end

local MODULE, COMMAND = "PlayersOnMap", "players"
local INTERVAL_MS = 1000
local last = 0

local original = sendServerCommand

local function now()
    local ok, t = pcall(getTimestampMs)
    if ok and t then return t end
    return os.time() * 1000
end

sendServerCommand = function(...)
    local a, b, c = ...
    -- Pass the arguments on exactly as received: the Java side picks the overload by
    -- argument count, so an extra nil breaks it.
    -- Two forms exist: (module, command, args) and (player, module, command, args).
    local module, command = a, b
    if type(a) ~= "string" then module, command = b, c end
    if module == MODULE and command == COMMAND then
        local players = getOnlinePlayers()
        if not players or players:size() == 0 then return end
        local t = now()
        if t - last < INTERVAL_MS then return end
        last = t
    end
    return original(...)
end
