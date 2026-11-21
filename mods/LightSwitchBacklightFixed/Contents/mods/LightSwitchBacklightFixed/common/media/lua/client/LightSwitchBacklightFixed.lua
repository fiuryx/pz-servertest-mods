-- Light Switch Backlight - Fixed (B42)
-- Fixed version of "Light Switch Backlight" (original B41 idea and code by its authors,
-- B42 port and no-flicker version by their authors). Highlights light switches within
-- 2 tiles: green when the light is on, red when it is off, only when there is power.
-- Fixes:
--  * Uses the current player every check, so it keeps working after death/respawn.
--  * Remembers what it highlighted and clears every switch that is no longer close
--    (walking away, changing floor, power cut), so nothing stays highlighted.
--  * No flickering. Light check every few ticks instead of every tick.
-- Client-side only: it just draws outlines, nothing is sent to the server.

local RADIUS = 2          -- tiles scanned around the player
local MAX_DIST = 2        -- tiles at which a switch is highlighted
local INTERVAL = 6        -- ticks between checks
local COLOR_ON = { 0.5, 1.0, 0.5, 1.0 }
local COLOR_OFF = { 1.0, 0.5, 0.5, 1.0 }

local lit = {}            -- [IsoLightSwitch] = true, currently highlighted by us
local tick = 0

local function setOutline(obj, state, color)
    if obj == nil then return end
    pcall(function()
        obj:setOutlineHighlight(state)
        obj:setOutlineHlBlink(false)
        if state then
            obj:setOutlineThickness(0.03)
            if color then obj:setOutlineHighlightCol(color[1], color[2], color[3], color[4]) end
        end
    end)
end

local function clearAll()
    for obj in pairs(lit) do setOutline(obj, false) end
    lit = {}
end

local function hasPower(sq)
    local ok, v = pcall(function() return sq:haveElectricity() end)
    if ok and v then return true end
    local w = getWorld and getWorld()
    if w and w.isHydroPowerOn then
        local ok2, on = pcall(function() return w:isHydroPowerOn() end)
        if ok2 then return on == true end
    end
    local sv = SandboxVars
    return sv and sv.ElecShutModifier and sv.ElecShutModifier > -1
        and getGameTime():getNightsSurvived() < sv.ElecShutModifier or false
end

local function update()
    local player = getSpecificPlayer(0)
    if not player or player:isDead() then clearAll(); return end
    local psq = player:getCurrentSquare()
    local cell = getCell()
    if not psq or not cell then clearAll(); return end

    local px, py, pz = math.floor(player:getX()), math.floor(player:getY()), math.floor(player:getZ())
    local now = {}
    for y = py - RADIUS, py + RADIUS do
        for x = px - RADIUS, px + RADIUS do
            local sq = cell:getGridSquare(x, y, pz)
            if sq then
                local objs = sq:getObjects()
                for i = 0, objs:size() - 1 do
                    local obj = objs:get(i)
                    if instanceof(obj, "IsoLightSwitch") and not psq:isWallTo(sq)
                        and sq:DistToProper(player) < MAX_DIST and hasPower(sq) then
                        now[obj] = true
                        setOutline(obj, true, obj:isActivated() and COLOR_ON or COLOR_OFF)
                    end
                end
            end
        end
    end
    for obj in pairs(lit) do
        if not now[obj] then setOutline(obj, false) end
    end
    lit = now
end

local function onTick()
    tick = tick + 1
    if tick % INTERVAL ~= 0 then return end
    local ok, err = pcall(update)
    if not ok then
        clearAll()
        print("[LightSwitchBacklightFixed] " .. tostring(err))
    end
end

Events.OnTick.Add(onTick)
Events.OnPlayerDeath.Add(function(p)
    if p and p == getSpecificPlayer(0) then clearAll() end
end)
Events.OnCreatePlayer.Add(function() clearAll() end)
