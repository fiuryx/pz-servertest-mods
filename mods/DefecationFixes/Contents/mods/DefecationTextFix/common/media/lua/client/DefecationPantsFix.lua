-- Defecation Fixes (B42) - part 3: take the trousers off and put them back on.
-- When defecating on purpose (toilet or ground), Defecation only plays a squat animation: the
-- clothes stay on. This patch takes off the clothing that covers the groin (trousers, shorts,
-- skirts, long johns, underwear) with the game's own unequip action before squatting, and puts it
-- back on afterwards in reverse order. If the squat is interrupted, the clothes are put back on too.
-- Not in vehicles (the character is seated). Accidents ("pooed himself") are not touched.

require "TimedActions/ISUnequipAction"
require "TimedActions/ISWearClothing"

local FIX = {}
local okDF, DF = pcall(require, "DefecationMain")
if not okDF or type(DF) ~= "table" then DF = nil end
-- Outer layers first: that is the order to take them off.
local LOCATIONS = { "PANTS_EXTRA", "PANTS", "PANTS_SKINNY", "SHORT_PANTS", "SHORTS_SHORT",
                    "LONG_SKIRT", "SKIRT", "LEGS1", "UNDERWEAR_BOTTOM" }
local pending = {}   -- player -> list of removed items, until they are worn again

local function bottoms(chr)
    local out, seen = {}, {}
    for _, name in ipairs(LOCATIONS) do
        local loc = ItemBodyLocation and ItemBodyLocation[name]
        if loc then
            local ok, item = pcall(function() return chr:getWornItem(loc) end)
            if ok and item and not seen[item] then
                seen[item] = true
                table.insert(out, item)
            end
        end
    end
    return out
end

local function wearBack(chr, items)
    for i = #items, 1, -1 do
        local it = items[i]
        if it and not chr:isEquippedClothing(it) and chr:getInventory():contains(it) then
            ISTimedActionQueue.add(ISWearClothing:new(chr, it))
        end
    end
end

local function install()
    if FIX.done or not DefecationDropPantsAction or not DefecationAction then return end
    FIX.done = true

    local origPerform = DefecationDropPantsAction.perform
    function DefecationDropPantsAction:perform()
        local chr = self.character
        if chr:getVehicle() or not DefecationAction then return origPerform(self) end
        local items = bottoms(chr)
        if #items == 0 then return origPerform(self) end

        chr:playSound("PutItemInBag")
        ISTimedActionQueue.getTimedActionQueue(chr):resetQueue()
        for _, it in ipairs(items) do
            ISTimedActionQueue.add(ISUnequipAction:new(chr, it, 50))
        end
        local act = DefecationAction:new(chr, true, true, false, self.toiletObject, self.toiletPaper)
        act.dfxItems = items
        ISTimedActionQueue.add(act)
        for i = #items, 1, -1 do
            ISTimedActionQueue.add(ISWearClothing:new(chr, items[i]))
        end
        pending[chr] = items
        ISBaseTimedAction.perform(self)
    end

    local origStop = DefecationAction.stop
    function DefecationAction:stop()
        origStop(self)
        if self.dfxItems then
            local items = self.dfxItems
            self.dfxItems = nil
            pending[self.character] = nil
            wearBack(self.character, items)
        end
    end

    local origDone = DefecationAction.perform
    function DefecationAction:perform()
        if self.dfxItems then pending[self.character] = nil end
        return origDone(self)
    end
end

-- Watchdog: Defecation marks the player as "defecating" when the squat starts and only clears it
-- when its own defecate action ends. If the queue is cleared in between (walking away, an
-- interrupted unequip...), the flag stayed on and every "Defecate" option (toilets included) stayed
-- greyed out until the game was restarted. Clear it, and put the clothes back on, when no
-- defecation action is left in the queue.
local ticks = 0
local function watchdog()
    ticks = ticks + 1
    if ticks < 30 then return end
    ticks = 0
    for i = 0, getNumActivePlayers() - 1 do
        local chr = getSpecificPlayer(i)
        if chr and not chr:isDead() then
            local busy = ISTimedActionQueue.hasActionType(chr, "DefecationAction")
                or ISTimedActionQueue.hasActionType(chr, "DefecationDropPantsAction")
            if not busy then
                if pending[chr] then
                    local items = pending[chr]
                    pending[chr] = nil
                    wearBack(chr, items)
                end
                if DF and DF.playerDefecating and i == 0 then DF.playerDefecating = false end
            end
        end
    end
end

Events.OnGameStart.Add(install)
Events.OnTick.Add(watchdog)
