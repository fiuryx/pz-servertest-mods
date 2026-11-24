require "TimedActions/ISBaseTimedAction"
require "AnimalCages"

-- Puts the animal the player is holding (picked-up animal item) into an empty cage or carrier.
ISAnimalCagePut = ISBaseTimedAction:derive("ISAnimalCagePut")

-- The animal item to cage: the one with this animal ID, or else the animal held in the hands.
-- (Right after "Catch", the item created by the pickup can take a moment to reach the client.)
local function animalItem(self)
    local inv = self.character:getInventory()
    local item = AnimalCages.findAnimalItem(inv, self.animalId)
    if item then return item end
    local hand = self.character:getPrimaryHandItem()
    if instanceof(hand, "AnimalInventoryItem") and hand:getAnimal() and inv:contains(hand) then return hand end
    return nil
end

function ISAnimalCagePut:isValid()
    local inv = self.character:getInventory()
    if not inv:contains(self.cage) or not AnimalCages.isEmpty(self.cage) then return false end
    -- In multiplayer the server checks the animal when the action completes.
    if isClient() then return true end
    local item = animalItem(self)
    return item ~= nil and AnimalCages.accepts(self.cage, item:getAnimal())
end

function ISAnimalCagePut:waitToStart()
    -- Wait (up to ~5 s) for the picked-up animal to show up in the inventory.
    self.waited = (self.waited or 0) + 1
    return animalItem(self) == nil and self.waited < 300
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
    local item = animalItem(self)
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
    self.cage:setName(AnimalCages.cageName(self.cage, item:getAnimal()))
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
