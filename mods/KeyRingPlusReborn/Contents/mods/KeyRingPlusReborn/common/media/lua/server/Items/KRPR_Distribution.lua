-- Key Ring Plus - Reborn: world spawns (same places as the original mod).
require "Items/ProceduralDistributions"

local SPAWNS = {
    ShelfGeneric = 3, LivingRoomShelf = 2, WildWestBarShelf = 3,
    ComicStoreShelfGames = 4, ComicStoreShelfFantasy = 3, ComicStoreShelfSciFi = 4,
    ClassroomMisc = 2, ClassroomShelves = 2,
    BackstageDresser = 1, BedroomDresser = 3, BedroomDresserChild = 0.5, StripClubDressers = 2,
}

local list = ProceduralDistributions and ProceduralDistributions.list
if list then
    for name, chance in pairs(SPAWNS) do
        local d = list[name]
        if d and d.items then
            table.insert(d.items, "Base.KeyRing_ProduktFrosch")
            table.insert(d.items, chance)
        end
    end
end
