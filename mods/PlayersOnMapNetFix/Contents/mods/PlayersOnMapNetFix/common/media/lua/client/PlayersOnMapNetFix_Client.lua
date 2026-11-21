-- Players On Map - Network Fix (B42), client side.
-- Players On Map sends your position to the server about 10 times per second, all the time,
-- even with the map closed. The server already knows where every player is and uses its own
-- data whenever that message is older than half a second, so here it is sent at most once
-- every few seconds. The dots of nearby players are still drawn from your own game, so they
-- keep moving smoothly.

if not isClient() then return end

local MODULE, COMMAND = "PlayersOnMap", "player"
local INTERVAL_MS = 5000
local last = 0

local original = sendClientCommand

local function now()
    local ok, t = pcall(getTimestampMs)
    if ok and t then return t end
    return os.time() * 1000
end

sendClientCommand = function(...)
    local a, b, c = ...
    -- Pass the arguments on exactly as received: the Java side picks the overload by
    -- argument count, so an extra nil breaks it.
    -- Two forms exist: (module, command, args) and (player, module, command, args).
    local module, command = a, b
    if type(a) ~= "string" then module, command = b, c end
    if module == MODULE and command == COMMAND then
        local t = now()
        if t - last < INTERVAL_MS then return end
        last = t
    end
    return original(...)
end
