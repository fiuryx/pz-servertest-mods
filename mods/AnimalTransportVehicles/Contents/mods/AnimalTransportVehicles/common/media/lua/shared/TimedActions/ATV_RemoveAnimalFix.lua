-- Animal Transport in Vehicles: multiplayer fix for taking animals out of a vehicle.
--
-- Vanilla sends the animal to the server by its temporary online ID. For animals inside a
-- vehicle that ID can point to the wrong animal (or none) on the server. The server then
-- removes nothing (or another animal) but still tells the clients "removed", so the animal
-- keeps showing up in the vehicle afterwards.
-- Fix: also send the animal's permanent ID, look the animal up in this vehicle by that ID on
-- the server, and do nothing (no "removed" message) if it is not really there.
-- Applies to every vehicle, including vanilla livestock trailers.

require "TimedActions/ISBaseTimedAction"
require "TimedActions/Animals/ISRemoveAnimalFromTrailer"

local R = ISRemoveAnimalFromTrailer
if not R or R.ATV_fixed then return end
R.ATV_fixed = true

-- The extra "animalPid" parameter is sent to the server with the others (the game sends the
-- parameters of new() by name).
function R:new(character, vehicle, animal, grab, animalPid)
    local o = ISBaseTimedAction.new(self, character)
    o.vehicle = vehicle
    o.animal = animal
    o.grab = grab
    if animalPid == nil and animal and instanceof(animal, "IsoAnimal") then
        animalPid = animal:getAnimalID()
    end
    o.animalPid = animalPid
    o.maxTime = o:getDuration()
    return o
end

local function inVehicle(vehicle, animal)
    local list = vehicle and vehicle:getAnimals()
    if not list or not animal then return false end
    for i = 0, list:size() - 1 do
        if list:get(i) == animal then return true end
    end
    return false
end

local vanillaComplete = R.complete
function R:complete()
    if self.vehicle and self.animalPid ~= nil then
        local real = self.vehicle:getAnimalById(self.animalPid)
        if not real then
            print("[AnimalTransportVehicles] animal " .. tostring(self.animalPid) .. " is not in this vehicle any more; nothing removed")
            return false
        end
        if real ~= self.animal then
            print("[AnimalTransportVehicles] animal " .. tostring(self.animalPid) .. " resolved by its permanent ID")
            self.animal = real
        end
    elseif self.vehicle and self.animal and instanceof(self.animal, "IsoAnimal") and not inVehicle(self.vehicle, self.animal) then
        return false
    end
    return vanillaComplete(self)
end
