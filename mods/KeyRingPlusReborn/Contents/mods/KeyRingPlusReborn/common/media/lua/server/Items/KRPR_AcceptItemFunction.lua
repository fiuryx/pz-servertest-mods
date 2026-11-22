-- Key Ring Plus - Reborn: what fits on the ProduktFrosch key ring.
-- Its own accept function, so vanilla key rings and vanilla items are not modified.
require "Items/AcceptItemFunction"
AcceptItemFunction = AcceptItemFunction or {}

local EXTRA = {
    ["Base.P38"] = true,
    ["Base.TinOpener"] = true,
    ["Base.BottleOpener"] = true,
    ["Base.BottleOpener_Keychain"] = true,
    ["Base.Corkscrew"] = true,
    ["Base.Handiknife"] = true,
    ["Base.Multitool"] = true,
    ["Base.PenLight"] = true,
    ["Base.MagnesiumFirestarter"] = true,
    ["Base.Lighter"] = true,
    ["Base.LighterDisposable"] = true,
    ["Base.Lighter_Battery"] = true,
    ["Base.Thread"] = true,
}

function AcceptItemFunction.KeyRingPlus(container, item)
    if not item then return false end
    if item:getCategory() == "Key" or item:hasTag(ItemTag.FITS_KEY_RING) then
        return true
    end
    return EXTRA[item:getFullType()] == true
end
