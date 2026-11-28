-- On the server, changing what a character holds (setPrimaryHandItem / setSecondaryHandItem) can throw an engine
-- error ("Cannot assign field callFrame") from inside a timed action's complete(). The action is then reported as
-- failed after it already moved the item, so the client keeps the cart on the floor while the server has it in the
-- inventory: the cart is duplicated. Here every hand change is protected and the action always finishes.
UnifiedCartsEquipFix = UnifiedCartsEquipFix or {}
local F = UnifiedCartsEquipFix

local function log(what, err)
    print("[UnifiedCartsEquipFix] " .. what .. ": " .. tostring(err))
end

-- set a hand and make sure it holds what we asked for
local function setHand(chr, primary, item)
    local ok, err = pcall(function()
        if primary then chr:setPrimaryHandItem(item) else chr:setSecondaryHandItem(item) end
    end)
    if ok then return end
    log(primary and "setPrimaryHandItem" or "setSecondaryHandItem", err)
    local now = primary and chr:getPrimaryHandItem() or chr:getSecondaryHandItem()
    if now ~= item then
        pcall(function()
            if primary then chr:setPrimaryHandItem(item) else chr:setSecondaryHandItem(item) end
        end)
    end
end
F.setHand = setHand

local function safe(what, fn)
    local ok, err = pcall(fn)
    if not ok then log(what, err) end
end

local function installCarts()
    if not ISUnifiedCartTake or not ISUnifiedCartDrop or not UnifiedCarts then return false end
    if ISUnifiedCartTake._EquipFix then return true end
    ISUnifiedCartTake._EquipFix = true

    local liftFromFloor = ISUnifiedCartTake.liftFromFloor
    local carried = ISUnifiedCartDrop.carried
    if not liftFromFloor or not carried then
        print("[UnifiedCartsEquipFix] Unified Carts changed, fix not applied")
        return true
    end

    -- Floor -> both hands (same steps as Unified Carts 0.84.15, hand changes protected)
    ISUnifiedCartTake.toHands = function(character, world, mode)
        local item = world and world:getItem()
        local square = world and world:getSquare()
        if not square or not UnifiedCarts.isCart(item) then return nil end
        if mode and not UnifiedCarts.setMovementMode(item, mode) then return nil end
        if UnifiedCarts.Hitch then UnifiedCarts.Hitch.revealItem(item) end

        local held = character:getPrimaryHandItem()
        if (held or character:getSecondaryHandItem()) and forceDropHeavyItems then
            safe("forceDropHeavyItems", function() forceDropHeavyItems(character) end)
            if UnifiedCarts.isCart(held) and held:getContainer() == nil then UnifiedCarts.updateModel(held) end
        end

        liftFromFloor(square, world, item)

        local inv = character:getInventory()
        inv:AddItem(item)
        sendAddItemToContainer(inv, item)
        setHand(character, true, item)
        setHand(character, false, item)
        safe("updateModel", function() UnifiedCarts.updateModel(item) end)
        safe("applyCartPose", function() UnifiedCarts.applyCartPose(character, item) end)
        if isServer() then safe("sendEquip", function() sendEquip(character) end) end
        if ISInventoryPage then ISInventoryPage.renderDirty = true end
        if UnifiedCarts.Mounts then UnifiedCarts.Mounts.refreshSoon(character) end
        return item
    end

    -- Hands/inventory -> floor
    ISUnifiedCartDrop.putDown = function(character, cart)
        if not character or not cart then return false end
        if not carried(character, cart) then return false end
        local square = character:getCurrentSquare()
        if not square then return false end

        local placed = square:AddWorldInventoryItem(cart, 0.5, 0.5, 0.0, false)
        if not placed then return false end
        local world = placed.getWorldItem and placed:getWorldItem() or placed
        if world and world.transmitCompleteItemToClients then world:transmitCompleteItemToClients() end

        if character:getPrimaryHandItem() == cart then setHand(character, true, nil) end
        if character:getSecondaryHandItem() == cart then setHand(character, false, nil) end
        safe("clearCartPose", function() UnifiedCarts.clearCartPose(character) end)
        safe("resetEquippedHandsModels", function() character:resetEquippedHandsModels() end)
        if isServer() then safe("sendEquip", function() sendEquip(character) end) end
        character:getInventory():Remove(cart)
        sendRemoveItemFromContainer(character:getInventory(), cart)
        safe("updateModel", function() UnifiedCarts.updateModel(cart) end)
        if UnifiedCarts.Mounts then UnifiedCarts.Mounts.refreshSoon(character) end
        if ISInventoryPage then ISInventoryPage.renderDirty = true end
        return true
    end
    print("[UnifiedCartsEquipFix] cart take/drop protected")
    return true
end

local function installUnequip()
    if not ISUnequipAction or ISUnequipAction._EquipFix then return end
    ISUnequipAction._EquipFix = true
    -- vanilla 42.22 complete(), hand changes protected
    function ISUnequipAction:complete()
        local chr, item = self.character, self.item
        chr:removeWornItem(item)
        if instanceof(item, "HandWeapon") and item:canBeActivated() then
            item:setActivated(false)
        end
        local both = item:isTwoHandWeapon() or item:isRequiresEquippedBothHands()
        if item == chr:getPrimaryHandItem() then
            if both and item == chr:getSecondaryHandItem() then setHand(chr, false, nil) end
            setHand(chr, true, nil)
        end
        if item == chr:getSecondaryHandItem() then
            if both and item == chr:getPrimaryHandItem() then setHand(chr, true, nil) end
            setHand(chr, false, nil)
        end
        safe("sendEquip", function() sendEquip(chr) end)
        safe("OnClothingUpdated", function() triggerEvent("OnClothingUpdated", chr) end)

        if self.reason ~= "drop" and self.reason ~= "place" and isForceDropHeavyItem(item) then
            chr:getInventory():Remove(item)
            sendRemoveItemFromContainer(chr:getInventory(), item)
            local dropX, dropY, dropZ = ISTransferAction.GetDropItemOffset(chr, chr:getCurrentSquare(), item)
            chr:getCurrentSquare():AddWorldInventoryItem(item, dropX, dropY, dropZ)
        end
        if isClient() then ISInventoryPage.renderDirty = true end
        return true
    end
    print("[UnifiedCartsEquipFix] unequip protected")
end

local function install()
    pcall(require, "TimedActions/ISUnequipAction")
    pcall(require, "TimedActions/ISUnifiedCartTake")
    pcall(require, "TimedActions/ISUnifiedCartDrop")
    installUnequip()
    installCarts()
end

install()
Events.OnGameBoot.Add(install)
if Events.OnServerStarted then Events.OnServerStarted.Add(install) end
