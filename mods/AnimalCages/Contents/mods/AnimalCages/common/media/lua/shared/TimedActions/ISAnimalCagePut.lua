require "TimedActions/ISBaseTimedAction"
require "AnimalCages"

-- Puts the animal the player is holding (picked-up animal item) into an empty cage or carrier.
ISAnimalCagePut = ISBaseTimedAction:derive("ISAnimalCagePut")

function ISAnimalCagePut:isValid()
    local inv = self.character:getInventory()
    if not inv:contains(self.cage) or not AnimalCages.isEmpty(self.cage) then return false end
    local item = AnimalCages.findAnimalItem(inv, self.animalId)
    return item ~= nil and AnimalCages.accepts(self.cage, item:getAnimal())
end

function ISAnimalCagePut:start()
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Low")
end

function ISAnimalCagePut:perform()
    ISBaseTimedAction.perform(self)
end

function ISAnimalCagePut:complete()
    local inv = self.character:getInventory()
    local item = AnimalCages.findAnimalItem(inv, self.animalId)
    if not item or not inv:contains(self.cage) or not AnimalCages.isEmpty(self.cage) then return false end
    if not AnimalCages.accepts(self.cage, item:getAnimal()) then return false end

    if self.character:getPrimaryHandItem() == item then self.character:setPrimaryHandItem(nil) end
    if self.character:getSecondaryHandItem() == item then self.character:setSecondaryHandItem(nil) end
    inv:Remove(item)
    sendRemoveItemFromContainer(inv, item)
    local cont = self.cage:getItemContainer()
    cont:AddItem(item)
    sendAddItemToContainer(cont, item)

    local md = self.cage:getModData()
    md.AC_time = getGameTime():getWorldAgeHours()
    md.AC_name = md.AC_name or self.cage:getName()
    self.cage:setName(getText("IGUI_AC_CageWith", md.AC_name, item:getAnimal():getFullName()))
    self.cage:setCustomName(true)
    AnimalCages.syncItem(self.character, self.cage)
    return true
end

function ISAnimalCagePut:getDuration()
    if self.character:isTimedActionInstant() then return 1 end
    return 60
end

function ISAnimalCagePut:new(character, cage, animalId)
    local o = ISBaseTimedAction.new(self, character)
    o.cage = cage
    o.animalId = animalId
    o.maxTime = o:getDuration()
    return o
end
