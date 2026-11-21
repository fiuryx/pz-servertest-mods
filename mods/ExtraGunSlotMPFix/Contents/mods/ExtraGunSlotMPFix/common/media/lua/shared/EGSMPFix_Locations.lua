-- Extra Gun Slot - Multiplayer Fix (B42)
-- Extra Gun Slot (BB_ExtraGunSlot) creates its "holsterbackb" attachment location
-- only in a client-side file, so a dedicated server does not know it and rejects
-- every GameCharacterAttachedItem packet that uses it ("no such location holsterbackb").
-- This file registers the same location from the shared folder so the server
-- also knows it. getOrCreateLocation does nothing if the location already exists.

local function EGSMPFix_RegisterLocation()
    if not AttachedLocations or not AttachedLocations.getGroup then return end
    local group = AttachedLocations.getGroup("Human")
    if group then
        group:getOrCreateLocation("holsterbackb"):setAttachmentName("holster_back_b")
    end
end

EGSMPFix_RegisterLocation()
