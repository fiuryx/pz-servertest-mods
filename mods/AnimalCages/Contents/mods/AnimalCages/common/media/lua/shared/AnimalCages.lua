-- Animal Cages and Carriers (B42): shared rules.
-- A cage holds the game's own picked-up animal item (Base.Animal), so the animal keeps everything
-- (breed, genetics, age, health, name). The game only lets players drag live animals to the floor,
-- so the animal goes in and out through this mod's timed actions.

AnimalCages = AnimalCages or {}
local AC = AnimalCages

local SMALL = { "chick", "hen", "cockerel", "turkeypoult", "rat", "ratbaby", "ratfemale",
                "mouse", "mousefemale", "mousepups", "rabkitten" }
local CARRIER_EXTRA = { "rabdoe", "rabbuck", "raccoonkit", "raccoonsow", "raccoonboar",
                        "turkeyhen", "gobblers", "lamb", "piglet" }

local function set(...)
    local t = {}
    for _, list in ipairs({ ... }) do for _, v in ipairs(list) do t[v] = true end end
    return t
end

AC.ALLOWED = {
    ["Base.AnimalCageSmall"] = set(SMALL),
    ["Base.AnimalCarrier"]   = set(SMALL, CARRIER_EXTRA),
}
AC.MIN_BAG_CAPACITY = 18      -- the small cage fits only in large bags (duffel, hiking, ALICE...)
AC.STRESS_PER_HOUR = 4        -- stress added on release per hour spent inside
AC.STRESS_MAX = 40

function AC.isCage(item)
    return item ~= nil and AC.ALLOWED[item:getFullType()] ~= nil
end

function AC.isCarrier(item)
    return item ~= nil and item:getFullType() == "Base.AnimalCarrier"
end

function AC.getAnimalItem(cage)
    if not AC.isCage(cage) or not cage.getItemContainer then return nil end
    local cont = cage:getItemContainer()
    if not cont then return nil end
    local items = cont:getItems()
    for i = 0, items:size() - 1 do
        local it = items:get(i)
        if instanceof(it, "AnimalInventoryItem") then return it end
    end
    return nil
end

function AC.isEmpty(cage)
    return cage:getItemContainer() ~= nil and cage:getItemContainer():getItems():isEmpty()
end

function AC.accepts(cage, animal)
    if not AC.isCage(cage) or not animal then return false end
    local ok, t = pcall(function() return animal:getAnimalType() end)
    return ok and t ~= nil and AC.ALLOWED[cage:getFullType()][t] == true
end

function AC.findAnimalItem(inv, animalId)
    local items = inv:getItems()
    for i = 0, items:size() - 1 do
        local it = items:get(i)
        if instanceof(it, "AnimalInventoryItem") and it:getAnimal() and it:getAnimal():getAnimalID() == animalId then
            return it
        end
    end
    return nil
end

function AC.syncItem(character, item)
    pcall(function() if syncItemFields then syncItemFields(character, item) end end)
    pcall(function() if syncItemModData then syncItemModData(character, item) end end)
end
