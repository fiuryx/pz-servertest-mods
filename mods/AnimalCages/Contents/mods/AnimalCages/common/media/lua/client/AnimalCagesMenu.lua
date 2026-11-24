-- Animal Cages and Carriers (B42): context menus and transfer rules (client).
require "AnimalCages"
require "TimedActions/ISAnimalCagePut"
require "TimedActions/ISAnimalCageRelease"

local AC = AnimalCages

local function playerCages(player)
    local list = player:getInventory():getAllEvalRecurse(function(it) return AC.isCage(it) end, ArrayList.new())
    local out = {}
    for i = 0, list:size() - 1 do table.insert(out, list:get(i)) end
    return out
end

local function freeCagesFor(player, animal)
    local out = {}
    for _, cage in ipairs(playerCages(player)) do
        if AC.isEmpty(cage) and AC.accepts(cage, animal) then table.insert(out, cage) end
    end
    return out
end

-- Menu icon: the cage's own item icon (the game draws it next to the option).
local function setIcon(opt, item)
    if opt and item then pcall(function() opt.iconTexture = item:getTex() end) end
    return opt
end

local function tooBigTooltip(names)
    local tip = ISWorldObjectContextMenu.addToolTip()
    tip.description = getText("Tooltip_AC_NoCage") .. (names ~= "" and (" <LINE> " .. names) or "")
    return tip
end

-- From the hands -------------------------------------------------------------------------------

local function onPutFromHands(player, cage, animalItem)
    ISInventoryPaneContextMenu.transferIfNeeded(player, cage)
    ISTimedActionQueue.add(ISAnimalCagePut:new(player, cage, animalItem:getAnimal():getAnimalID()))
end

local function onRelease(player, cage)
    ISInventoryPaneContextMenu.transferIfNeeded(player, cage)
    ISTimedActionQueue.add(ISAnimalCageRelease:new(player, cage))
end

local function onInventoryMenu(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    if not player then return end
    for _, v in ipairs(items) do
        local item = v
        if type(v) == "table" and v.items then item = v.items[1] end
        if instanceof(item, "AnimalInventoryItem") and item:getAnimal() then
            local animal = item:getAnimal()
            local cages = freeCagesFor(player, animal)
            if #cages > 0 then
                for _, cage in ipairs(cages) do
                    setIcon(context:addOption(getText("ContextMenu_AC_PutIn", cage:getName()), player, onPutFromHands, cage, item), cage)
                end
            elseif #playerCages(player) > 0 then
                local opt = setIcon(context:addOption(getText("ContextMenu_AC_PutIn", getText("IGUI_AC_ACage")), nil, nil), playerCages(player)[1])
                opt.notAvailable = true
                opt.toolTip = tooBigTooltip("")
            end
            break
        elseif AC.isCage(item) then
            local inside = AC.getAnimalItem(item)
            if inside and inside:getAnimal() then
                setIcon(context:addOption(getText("ContextMenu_AC_Release", inside:getAnimal():getFullName()), player, onRelease, item), item)
            end
            break
        end
    end
end
Events.OnFillInventoryObjectContextMenu.Add(onInventoryMenu)

-- From the world: catch the animal and put it straight into a cage --------------------------------

local function onCatch(player, cage, animal)
    if not animal or not animal:getSquare() then return end
    ISInventoryPaneContextMenu.transferIfNeeded(player, cage)
    if luautils.walkAdj(player, animal:getSquare(), true) then
        ISTimedActionQueue.add(ISPickupAnimal:new(player, animal))
        ISTimedActionQueue.add(ISAnimalCagePut:new(player, cage, animal:getAnimalID()))
    end
end

local function onWorldMenu(playerNum, context, worldObjects, test)
    if test then return end
    local player = getSpecificPlayer(playerNum)
    if not player or player:getVehicle() then return end
    local cages = playerCages(player)
    if #cages == 0 then return end

    local seen, animals = {}, {}
    for _, obj in ipairs(worldObjects) do
        local sq = obj and obj.getSquare and obj:getSquare()
        if sq and not seen[sq] then
            seen[sq] = true
            local list = sq:getAnimals()
            for i = 0, list:size() - 1 do table.insert(animals, list:get(i)) end
        end
    end
    if #animals == 0 then return end

    for _, animal in ipairs(animals) do
        local ok = pcall(function()
            if animal:isDead() or not animal:isExistInTheWorld() then return end
            local free = freeCagesFor(player, animal)
            if #free > 0 then
                setIcon(context:addOption(getText("ContextMenu_AC_Catch", animal:getFullName(), free[1]:getName()), player, onCatch, free[1], animal), free[1])
            end
        end)
    end
end
Events.OnFillWorldObjectContextMenu.Add(onWorldMenu)

-- Transfer rules: the carrier never goes in a bag; the small cage only in large bags ---------------

local vanillaValid = ISInventoryTransferAction.isValid
function ISInventoryTransferAction:isValid()
    local item, dest = self.item, self.destContainer
    if item and dest and AC.isCage(item) then
        local bag = dest:getContainingItem()
        if bag and instanceof(bag, "InventoryContainer") then
            if AC.isCarrier(item) then return false end
            local cap = 0
            pcall(function() cap = bag:getCapacity() end)
            if cap < AC.MIN_BAG_CAPACITY then return false end
        end
    end
    return vanillaValid(self)
end
