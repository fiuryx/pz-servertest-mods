-- After AutoCook has finished a dish, put it in the nearest free oven or microwave within the radius and turn it
-- on. The server watches the dish and turns the appliance off as soon as it is cooked (see CookAndSortRange_Server).
require "CookAndSortRange/CookAndSortRange_Core"
require "TimedActions/ISBaseTimedAction"
local R = CookAndSortRange

local function say(player, key)
    if HaloTextHelper and HaloTextHelper.addText then
        HaloTextHelper.addText(player, getText(key), "", HaloTextHelper.getColorWhite())
    else
        player:setHaloNote(getText(key), 255, 255, 255, 300)
    end
end

-- instant action queued after the transfer: asks the server to start the appliance
CSRStartCooking = ISBaseTimedAction:derive("CSRStartCooking")
function CSRStartCooking:isValid() return self.stove ~= nil and self.food ~= nil end
function CSRStartCooking:update() end
function CSRStartCooking:start() end
function CSRStartCooking:stop() ISBaseTimedAction.stop(self) end
function CSRStartCooking:perform()
    ISBaseTimedAction.perform(self)
    local c = self.food:getContainer()
    if c ~= self.inv then return end -- the transfer did not happen
    sendClientCommand(self.character, "CookAndSortRange", "startCook",
        { x = self.stove:getX(), y = self.stove:getY(), z = self.stove:getZ(), id = self.food:getID() })
    say(self.character, self.stove:isMicrowave() and "IGUI_CSR_CookingMicrowave" or "IGUI_CSR_CookingOven")
end
function CSRStartCooking:new(character, stove, inv, food)
    local o = ISBaseTimedAction.new(self, character)
    o.stove, o.inv, o.food = stove, inv, food
    o.stopOnWalk, o.stopOnRun = false, false
    o.maxTime = 1
    return o
end

local function needsCooking(food)
    return food and instanceof(food, "Food") and food:isCookable() and not food:isCooked() and not food:isBurnt()
end

-- nearest free, powered oven (preferred) or microwave (only without metal) with room for the dish
function R.findAppliance(player, food)
    local best
    for _, c in ipairs(R.nearbyContainers(player, false)) do
        local obj = c.obj
        if instanceof(obj, "IsoStove") and not obj:Activated() and c.inv:isPowered() then
            local micro = obj:isMicrowave()
            if not (micro and food:getMetalValue() > 0) and c.inv:hasRoomFor(player, food) then
                local score = c.dist + (micro and 4 or 0)
                if not best or score < best.score then best = { obj = obj, inv = c.inv, score = score } end
            end
        end
    end
    return best
end

function R.cookInAppliance(player, food)
    if not player or not needsCooking(food) then return end
    if not player:getInventory():contains(food) then return end
    local best = R.findAppliance(player, food)
    if not best then
        say(player, "IGUI_CSR_NoAppliance")
        return
    end
    R.walkTo(player, best.inv)
    ISTimedActionQueue.add(ISInventoryTransferAction:new(player, food, player:getInventory(), best.inv))
    ISTimedActionQueue.add(CSRStartCooking:new(player, best.obj, best.inv, food))
end
