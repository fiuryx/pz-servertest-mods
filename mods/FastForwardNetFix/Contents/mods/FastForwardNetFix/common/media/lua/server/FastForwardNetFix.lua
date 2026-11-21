-- Fast Forward - Network Desync Fix (B42)
--
-- Problem: Fast Forward speeds up server timed actions by moving the server
-- clock with GameTime.setServerTimeShift(). Clients sync their clock to the
-- RAW server clock (TimeSync packet uses System.nanoTime), so any shift makes
-- every packet stamped with the server time (vehicles, players) look like it
-- comes from the future. The shift is also never undone. Result: passengers
-- and other players see vehicles in different places.
--
-- Fix: keep the server clock shift at 0 at all times, and instead change the
-- end time of each running timed action (NetTimedAction:setDuration) so it
-- still finishes faster while time is accelerated, and freezes while paused.

if not isServer() then return end

local FFNF = {}
FFNF.tracked = {}

-- 1. Neutralise the clock shift --------------------------------------------
local origSetShift = GameTime.setServerTimeShift
local overridden = false
if origSetShift then
    origSetShift(0)
    overridden = pcall(function()
        GameTime.setServerTimeShift = function(_) origSetShift(0) end
    end)
end
print("[FastForwardNetFix] clock shift blocked: " .. tostring(overridden))

local function nowMs()
    return GameTime.getServerTimeMills()
end

-- 2. Remember every timed action created on the server -----------------------
local base_new = ISBaseTimedAction.new
function ISBaseTimedAction:new(...)
    local o = base_new(self, ...)
    if o then FFNF.tracked[o] = true end
    return o
end

-- 3. Scale running actions with the game speed --------------------------------
-- For each action we keep a "virtual" elapsed time that advances at the game
-- multiplier. The action ends when the virtual time reaches its full duration:
--   endTime = startTime + realElapsed + (duration - virtual) / multiplier
local lastNow = nil

local function update()
    -- fallback: if the override did not take, undo any shift every tick
    if origSetShift and not overridden then origSetShift(0) end
    local now = nowMs()
    if not lastNow then lastNow = now; return end
    local dt = now - lastNow
    lastNow = now
    if dt <= 0 then return end

    local mult = getGameTime():getTrueMultiplier()
    if mult <= 0 then mult = 0.0001 end

    for action, _ in pairs(FFNF.tracked) do
        local net = action.netAction
        if net == nil then
            -- not a network action yet; drop it if it never becomes one
            action.ffnfAge = (action.ffnfAge or 0) + dt
            if action.ffnfAge > 10000 then FFNF.tracked[action] = nil end
        else
            local ok, p = pcall(net.getProgress, net)
            if not ok or p == nil or p >= 1 or p < 0 then
                FFNF.tracked[action] = nil
            else
                local st = action.ffnf
                if st == nil then
                    if mult == 1 then
                        -- nothing to do at normal speed
                    else
                        -- learn the duration from two progress samples
                        if action.ffnfP0 == nil then
                            action.ffnfP0 = p; action.ffnfT0 = now
                        elseif p > action.ffnfP0 then
                            local dur = (now - action.ffnfT0) / (p - action.ffnfP0)
                            local start = now - p * dur
                            action.ffnf = { start = start, dur = dur, virt = p * dur }
                        end
                    end
                else
                    st.virt = st.virt + dt * mult
                    local remaining = st.dur - st.virt
                    if remaining < 0 then remaining = 0 end
                    local newDur = (now - st.start) + remaining / mult
                    if newDur > 0 and newDur < 86400000 then
                        pcall(net.setDuration, net, newDur)
                    end
                end
            end
        end
    end
end

Events.OnTick.Add(update)
