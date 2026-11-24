-- Animal Cages: loot. Small cages in pet shops, farms and farming stores; carriers in pet shops
-- and pet supply crates.
require "Items/ProceduralDistributions"

local function add(list, item, chance)
    local d = ProceduralDistributions and ProceduralDistributions.list and ProceduralDistributions.list[list]
    if d and d.items then
        table.insert(d.items, item)
        table.insert(d.items, chance)
    end
end

add("PetShopShelf",      "Base.AnimalCageSmall", 6)
add("PetShopShelf",      "Base.AnimalCarrier",   6)
add("CratePetSupplies",  "Base.AnimalCageSmall", 4)
add("CratePetSupplies",  "Base.AnimalCarrier",   4)
add("BarnTools",         "Base.AnimalCageSmall", 2)
add("CrateFarming",      "Base.AnimalCageSmall", 2)
add("FarmerTools",       "Base.AnimalCageSmall", 1)
add("GigamartFarming",   "Base.AnimalCageSmall", 2)
add("ToolStoreFarming",  "Base.AnimalCageSmall", 2)
