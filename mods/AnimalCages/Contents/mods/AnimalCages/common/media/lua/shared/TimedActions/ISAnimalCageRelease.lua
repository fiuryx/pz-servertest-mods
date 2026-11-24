require "TimedActions/ISBaseTimedAction"
require "AnimalCages"

-- Takes the animal out of a cage or carrier into the player's hands, like picking it up. From there
-- the game's own options apply (drop it, put it in a hutch, a trailer...).
ISAnimalCageRelease = ISBaseTimedAction:derive("ISAnimalCageRelease")

function ISAnimalCageRelease:isValid()
    return self.character:getInventory():contains(self.cage) and AnimalCages.getAnimalItem(self.cage) ~= nil
end

function ISAnimalCageRelease:start()
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Low")
end

function ISAnimalCageRelease:perform()
    ISBaseTimedAction.perform(self)
end

function ISAnimalCageRelease:complete()
    local item = AnimalCages.getAnimalItem(self.cage)
    if not item then return false end
    local cont = self.cage:getItemContainer()
    local inv = self.character:getInventory()
    cont:Remove(item)
    sendRemoveItemFromContainer(cont, item)
    inv:AddItem(item)
    sendAddItemToContainer(inv, item)

    local md = self.cage:getModData()
    local animal = item:getAnimal()
    if animal and md.AC_time then
        local hours = getGameTime():getWorldAgeHours() - md.AC_time
        if hours > 0 then
            pcall(function() animal:changeStress(math.min(AnimalCages.STRESS_MAX, hours * AnimalCages.STRESS_PER_HOUR)) end)
        end
    end
    if md.AC_name then self.cage:setName(md.AC_name) end
    md.AC_time = nil
    md.AC_name = nil
    self.cage:setCustomName(false)
    AnimalCages.syncItem(self.character, self.cage)

    forceDropHeavyItems(self.character)
    self.character:setPrimaryHandItem(nil)
    self.character:setSecondaryHandItem(nil)
    self.character:setPrimaryHandItem(item)
    self.character:setSecondaryHandItem(item)
    return true
end

function ISAnimalCageRelease:getDuration()
    if self.character:isTimedActionInstant() then return 1 end
    return 60
end

function ISAnimalCageRelease:new(character, cage)
    local o = ISBaseTimedAction.new(self, character)
    o.cage = cage
    o.maxTime = o:getDuration()
    return o
end
