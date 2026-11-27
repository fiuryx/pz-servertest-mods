-- Manage Containers: "put in assigned containers" uses the configured containers within the
-- radius, and the character walks to each one (nearest first) to put the items away.
require "CookAndSortRange/CookAndSortRange_Core"
local ok = pcall(require, "ManageContainers/ISInventoryPaneContextMenu")
if not ok or not ISInventoryPaneContextMenu.TransferItems or not ISConfigureContainerWindow then return end
local R = CookAndSortRange

local origValid = ISInventoryPaneContextMenu.ValidNearbyContainers
local origTransfer = ISInventoryPaneContextMenu.TransferItems

local function configured(player)
    local uuid = ISConfigureContainerWindow:getStoredUUID(player, "playerContainerID", true)
    local out = {}
    for _, c in ipairs(R.nearbyContainers(player, false)) do
        local obj = c.obj
        local idx = obj:getContainerIndex(c.inv) + 1
        local data = ISConfigureContainerWindow.getContainerData(obj, idx, uuid)
        if data and data["containersFilters"] and data["containersFilters"][idx] and data["exclusiveSelection"] and data["exclusiveSelection"][idx] then
            local cats = {}
            for _, f in ipairs(data["containersFilters"][idx]) do cats[f] = true end
            local sel = data["exclusiveSelection"][idx]
            table.insert(out, { inv = c.inv, itemCats = cats, include = sel.Include or {}, exclude = sel.Exclude or {},
                remainingSpace = c.inv:getEffectiveCapacity(player) - c.inv:getContentsWeight(), assignedItems = {}, dist = c.dist })
        end
    end
    return out
end

-- the inventory buttons ask this often: cache the answer for a second
local validCache = {}
ISInventoryPaneContextMenu.ValidNearbyContainers = function(playerObj)
    if not R.enabled("ManageContainers") or not playerObj then return origValid(playerObj) end
    local now = getTimestampMs()
    local key = playerObj:getPlayerNum()
    local c = validCache[key]
    if c and now - c.t < 1000 then return c.v end
    local okc, list = pcall(configured, playerObj)
    local v = (okc and #list > 0) or origValid(playerObj)
    validCache[key] = { t = now, v = v }
    return v
end

local function flatten(items)
    local out = {}
    for _, b in ipairs(items or {}) do
        if instanceof(b, "InventoryItem") then table.insert(out, b)
        elseif b and b.items then
            for _, it in ipairs(ISInventoryPane.getActualItems(b.items)) do table.insert(out, it) end
        end
    end
    return out
end

local function accepts(c, item)
    local cat = item:getDisplayCategory() or item:getCategory()
    local t = item:getFullType()
    return (c.itemCats[cat] ~= nil and c.exclude[t] == nil) or c.include[t] ~= nil
end

local function transfer(items, playerNum, unrestricted)
    local player = getSpecificPlayer(playerNum)
    local hotBar = getPlayerHotbar(playerNum)
    local conts = configured(player)
    if #conts == 0 then return origTransfer(items, playerNum, unrestricted) end
    -- most exclusive container first (fewest categories), like the original scoring
    for _, item in ipairs(flatten(items)) do
        local okItem = not item:isFavorite() and (unrestricted or (not item:isEquipped() and item:getType() ~= "KeyRing" and not (hotBar and hotBar:isInHotbar(item))))
        if okItem then
            local best, bestScore
            for _, c in ipairs(conts) do
                local w = item:getActualWeight()
                if c.remainingSpace > w and accepts(c, item) then
                    local n = 0
                    for _ in pairs(c.itemCats) do n = n + 1 end
                    local score = math.max(20 - n * 2, 0) * 1000 - (c.dist or 0)
                    if not best or score > bestScore then best, bestScore = c, score end
                end
            end
            if best then
                best.remainingSpace = best.remainingSpace - item:getActualWeight()
                table.insert(best.assignedItems, item)
            end
        end
    end
    -- containers are already nearest first: walk to each one and put its items in
    for _, c in ipairs(conts) do
        if #c.assignedItems > 0 then
            table.sort(c.assignedItems, function(a, b) return a:getActualWeight() < b:getActualWeight() end)
            if R.walkTo(player, c.inv) then
                for _, it in ipairs(c.assignedItems) do
                    ISTimedActionQueue.add(ISInventoryTransferAction:new(player, it, it:getContainer(), c.inv))
                end
            end
        end
    end
end

ISInventoryPaneContextMenu.TransferItems = function(items, playerNum, unrestricted)
    if not R.enabled("ManageContainers") then return origTransfer(items, playerNum, unrestricted) end
    local okt, err = pcall(transfer, items, playerNum, unrestricted)
    if not okt then
        print("[CookAndSortRange] " .. tostring(err))
        return origTransfer(items, playerNum, unrestricted)
    end
end
