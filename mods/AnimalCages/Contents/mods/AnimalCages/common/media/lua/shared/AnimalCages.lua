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

-- Time an animal survives inside (no food or water): the game does not update animals stored in a
-- container, so this is applied when it comes out. Hours of game time.
AC.LIMIT_HOURS = {
    rat = 48, ratbaby = 48, ratfemale = 48, mouse = 48, mousefemale = 48, mousepups = 48,
    chick = 48, turkeypoult = 48, rabkitten = 48,
    hen = 72, cockerel = 72, turkeyhen = 72, gobblers = 72, rabdoe = 72, rabbuck = 72,
    raccoonkit = 72, raccoonsow = 72, raccoonboar = 72,
    lamb = 96, piglet = 96,
}
AC.LIMIT_DEFAULT = 72
AC.WARN_THIRSTY = 0.4     -- share of the limit: name shows "thirsty"
AC.WARN_WEAK = 0.75       -- share of the limit: name shows "very weak"

function AC.limitFor(animal)
    local ok, t = pcall(function() return animal:getAnimalType() end)
    return (ok and t and AC.LIMIT_HOURS[t]) or AC.LIMIT_DEFAULT
end

-- Share (0..1+) of the survival limit already spent inside this cage.
function AC.timeShare(cage, animal)
    local md = cage:getModData()
    if not md.AC_time or not animal then return 0 end
    local hours = getGameTime():getWorldAgeHours() - md.AC_time
    if hours <= 0 then return 0 end
    return hours / AC.limitFor(animal)
end

-- Cage name with the animal and, when it matters, how it is doing.
function AC.cageName(cage, animal)
    local md = cage:getModData()
    local base = md.AC_name or (cage:getScriptItem() and cage:getScriptItem():getDisplayName()) or cage:getName()
    if not animal then return base end
    local share = AC.timeShare(cage, animal)
    if share >= AC.WARN_WEAK then
        return getText("IGUI_AC_CageWithStatus", base, animal:getFullName(), getText("IGUI_AC_Weak"))
    elseif share >= AC.WARN_THIRSTY then
        return getText("IGUI_AC_CageWithStatus", base, animal:getFullName(), getText("IGUI_AC_Thirsty"))
    end
    return getText("IGUI_AC_CageWith", base, animal:getFullName())
end

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
