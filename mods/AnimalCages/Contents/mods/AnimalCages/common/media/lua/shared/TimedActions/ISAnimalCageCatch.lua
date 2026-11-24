require "TimedActions/ISBaseTimedAction"
require "TimedActions/Animals/ISPickupAnimal"

-- "Catch with a cage": the vanilla pick-up, made safe for the cage action queued after it.
--
-- In multiplayer the server finishes the pick-up first and removes the animal from the world.
-- The vanilla client action then sees "animal no longer in the world", stops, and that stop
-- clears the whole action queue, so the "put in cage" queued after it never ran: the animal
-- ended up in the hands, not in the cage.
-- Here, once the action has started, the client leaves the check to the server.
ISAnimalCageCatch = ISPickupAnimal:derive("ISAnimalCageCatch")

function ISAnimalCageCatch:isValid()
    if isClient() and self:isStarted() then return true end
    return ISPickupAnimal.isValid(self)
end

function ISAnimalCageCatch:new(character, animal, remove)
    local o = ISPickupAnimal.new(self, character, animal, remove)
    return o
end
