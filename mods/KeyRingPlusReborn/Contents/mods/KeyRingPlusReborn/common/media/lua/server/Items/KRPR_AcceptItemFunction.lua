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
    ["Base.Paperclip"] = true,
    ["Base.FishingHook"] = true,
    ["Base.FishingHook_Forged"] = true,
    ["Base.FishingHook_Bone"] = true,
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
    local fullType = item:getFullType()
    if EXTRA[fullType] then return true end
    -- Authentic Z glow sticks (every colour, lit or not), but not the full pack
    if fullType:find("^AuthenticZClothing%.AuthenticGlowstick_") and fullType ~= "AuthenticZClothing.AuthenticGlowstick_Pack" then
        return true
    end
    return false
end
