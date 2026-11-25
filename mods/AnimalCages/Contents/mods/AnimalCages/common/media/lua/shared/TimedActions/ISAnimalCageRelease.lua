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
    AnimalCages.log("release complete", AnimalCages.describe(self.cage))
    if not item then return false end
    local cont = self.cage:getItemContainer()
    local inv = self.character:getInventory()
    cont:Remove(item)
    sendRemoveItemFromContainer(cont, item)
    inv:AddItem(item)
    sendAddItemToContainer(inv, item)

    local md = self.cage:getModData()
    local animal = item:getAnimal()
    local died = false
    if animal and md.AC_time then
        local hours = getGameTime():getWorldAgeHours() - md.AC_time
        local share = AnimalCages.timeShare(self.cage, animal)
        if share >= 1 then
            died = true
        elseif hours > 0 then
            -- Time inside without food or water, applied now (the game did not update it in the cage).
            pcall(function() animal:changeStress(math.min(AnimalCages.STRESS_MAX, hours * AnimalCages.STRESS_PER_HOUR)) end)
            pcall(function()
                local st = animal:getStats()
                st:set(CharacterStat.THIRST, math.min(1, st:get(CharacterStat.THIRST) + share))
                st:set(CharacterStat.HUNGER, math.min(1, st:get(CharacterStat.HUNGER) + share * 0.7))
            end)
        end
    end
    md.AC_time = nil
    md.AC_name = nil
    if self.cage:isCustomName() then
        local script = self.cage:getScriptItem()
        if script then self.cage:setName(script:getDisplayName()) end
        self.cage:setCustomName(false)
    end
    AnimalCages.syncItem(self.character, self.cage)

    forceDropHeavyItems(self.character)
    self.character:setPrimaryHandItem(nil)
    self.character:setSecondaryHandItem(nil)
    if died then
        -- Too long without water: it comes out dead, as a corpse (same steps as the game's own kill).
        local ok = pcall(function()
            animal:setX(self.character:getX())
            animal:setY(self.character:getY())
            animal:setZ(self.character:getZ())
            if self.character:getCurrentSquare() then animal:setCurrentSquare(self.character:getCurrentSquare()) end
            animal:setHealth(0)
            local body = IsoDeadBody.new(animal, true, false)
            local corpse = body:getItem()
            inv:Remove(item)
            sendRemoveItemFromContainer(inv, item)
            inv:AddItem(corpse)
            sendAddItemToContainer(inv, corpse)
            self.character:setPrimaryHandItem(corpse)
            self.character:setSecondaryHandItem(corpse)
        end)
        if ok then return true end
    end
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
