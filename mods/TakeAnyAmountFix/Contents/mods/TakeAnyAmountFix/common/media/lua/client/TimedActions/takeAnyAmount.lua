-- Take Any Amount - Fix (B42): copy of takeAnyAmount.lua (Workshop 3389115640) with one fix:
-- avoids "attempted index: isInCharacterInventory of non-table" when an item has no container
-- (CleanUI / Proximity Inventory rows). Everything else is unchanged.

require "ISUI/ISToolTip"

local AMOUNT = 0
local MAX = 0

-------------------------------------------------
-- Textbox manager
-------------------------------------------------

function createAndOpenTextbox(items, player, mode)
    local callback
    if tonumber(mode) == 0 then
        callback = setAmountAndGrab
    elseif tonumber(mode) == 1 then
        callback = setAmountAndPut
    end

    local modal = ISTextBox:new(
        0, 0, 280, 180,
        getText("ContextMenu_TransferAmountInfo") .. " " .. tostring(MAX) .. ")",
        "",   -- start blank every time
        nil,
        callback,
        nil,
        nil,
        items,
        player
    )

    modal:initialise()
    modal:addToUIManager()

    -- Find the OK button
    local okButton = nil
    for _, child in ipairs(modal.children) do
        if child.internal == "OK" then
            okButton = child
            break
        end
    end

    -- Press Enter in the textbox = click OK button
    modal.entry.onCommandEntered = function()
        if okButton then
            okButton:triggerClick()
        else
            -- fallback
            local button = { internal = "OK", parent = modal }
            callback(nil, button, nil, items, player)
            modal:destroy()
        end
    end

    -- Auto-focus textbox so you can type immediately
    modal.entry:focus()

    if JoypadState.players[player + 1] then
        setJoypadFocus(player, modal)
    end
end

-------------------------------------------------
-- Grabbing items from containers
-------------------------------------------------

function setAmountAndGrab(target, button, obj, items, player)
    if button.internal == "OK" then
        local text = button.parent.entry:getText()
        local n = tonumber(text)
        if n then
            if n > MAX then n = MAX end
            if n < 0 then n = 0 end
            AMOUNT = n
            ISInventoryPaneContextMenu.onGrabAnyAmount(items, player)
        end
    end
end

ISInventoryPaneContextMenu.onGrabAnyAmount = function(items, player)
    local count = tonumber(AMOUNT)
    if not count or count <= 0 then return end

    local playerObj = getSpecificPlayer(player)
    local playerInv = getPlayerInventory(player).inventory
    local doWalk = true

    for _, k in ipairs(items) do
        if not instanceof(k, "InventoryItem") then
            -- k.items[1] is the display item; real items start at 2
            local total = #k.items - 1
            if total > 0 then
                local maxToTake = math.min(count, total)
                for i2 = 1, maxToTake do
                    local k2 = k.items[i2 + 1]
                    if k2 and k2:getContainer() ~= playerInv then
                        if doWalk then
                            if not luautils.walkToContainer(k2:getContainer(), player) then
                                return
                            end
                            doWalk = false
                        end
                        ISTimedActionQueue.add(ISInventoryTransferAction:new(
                            playerObj,
                            k2,
                            k2:getContainer(),
                            playerInv
                        ))
                    end
                end
            end
        elseif k:getContainer() ~= playerInv then
            if doWalk then
                if not luautils.walkToContainer(k:getContainer(), player) then
                    return
                end
                doWalk = false
            end
            ISTimedActionQueue.add(ISInventoryTransferAction:new(
                playerObj,
                k,
                k:getContainer(),
                playerInv
            ))
        end
    end
end

function ISInventoryPaneContextMenu.doGrabMenu(context, items, player)
    for _, k in pairs(items) do
        if not instanceof(k, "InventoryItem") then
            if isForceDropHeavyItem(k.items[1]) then
                -- corpse or generator
            elseif #k.items > 2 then
                MAX = #k.items - 1
                context:addOption(getText("ContextMenu_Grab_one"), items, ISInventoryPaneContextMenu.onGrabOneItems, player)
                context:addOption(getText("ContextMenu_Grab_half"), items, ISInventoryPaneContextMenu.onGrabHalfItems, player)
                context:addOption(getText("ContextMenu_GrabAmount"), items, createAndOpenTextbox, player, 0)
                context:addOption(getText("ContextMenu_Grab_all"), items, ISInventoryPaneContextMenu.onGrabItems, player)
            else
                context:addOption(getText("ContextMenu_Grab"), items, ISInventoryPaneContextMenu.onGrabItems, player)
            end
            break
        elseif isForceDropHeavyItem(k) then
            -- corpse or generator
        else
            context:addOption(getText("ContextMenu_Grab"), items, ISInventoryPaneContextMenu.onGrabItems, player)
            break
        end
    end
end

-------------------------------------------------
-- Putting items in containers
-------------------------------------------------

function setAmountAndPut(target, button, obj, items, player)
    if button.internal == "OK" then
        local text = button.parent.entry:getText()
        local n = tonumber(text)
        if n then
            if n > MAX then n = MAX end
            if n < 0 then n = 0 end
            AMOUNT = n
            ISInventoryPaneContextMenu.onPutItemsAmount(items, player)
        end
    end
end

ISInventoryPaneContextMenu.onPutItemsAmount = function(items, player)
    local playerObj = getSpecificPlayer(player)
    local playerLoot = getPlayerLoot(player).inventory
    items = ISInventoryPane.getActualItems(items)

    local doWalk = true
    local count = 0

    for _, k in ipairs(items) do
        if playerLoot:isItemAllowed(k) and not k:isFavorite() then
            if doWalk then
                if not luautils.walkToContainer(playerLoot, player) then
                    break
                end
                doWalk = false
            end
            if count == AMOUNT then
                break
            end
            ISTimedActionQueue.add(ISInventoryTransferAction:new(
                playerObj,
                k,
                k:getContainer(),
                playerLoot
            ))
            count = count + 1
        end
    end
end

-------------------------------------------------
-- Context menu: Put Amount
-------------------------------------------------

local function AddContextPutItems(player, context, items)
    local playerObj = getSpecificPlayer(player)
    local loot = getPlayerLoot(player)
    local moveItems = ISInventoryPane.getActualItems(items)

    local inPlayerInv = true

    -- Check only first item
    for _, k in ipairs(moveItems) do
        local kc = k:getContainer()
        if not kc or not kc:isInCharacterInventory(playerObj) then
            inPlayerInv = false
        end
        break
    end

    MAX = #moveItems

    if inPlayerInv and MAX > 1 then
        if ISInventoryPaneContextMenu.isAnyAllowed(loot.inventory, items)
            and not ISInventoryPaneContextMenu.isAllFav(items) then
            context:addOption(
                getText("ContextMenu_PutAmount") .. " (" .. loot.title .. ")",
                items,
                createAndOpenTextbox,
                player,
                1
            )
        end
    end
end

Events.OnFillInventoryObjectContextMenu.Add(AddContextPutItems)
