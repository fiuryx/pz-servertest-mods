-- Server Item Name Fix (B42)
-- On a dedicated server some item names are built by the server, which cannot look up item names
-- in the players' language. Cooked dishes then show the internal code of an ingredient instead of
-- its name, for example "Bowl of Base.RicePot" instead of "Bowl of Rice".
-- This client-side patch replaces those codes with the item's name in your language, for the items
-- in your inventory and in the containers you have open. Display only: nothing is sent to the server.

local cache = {}
local function itemName(fullType)
    local c = cache[fullType]
    if c ~= nil then return c or nil end
    local name = nil
    pcall(function()
        local script = getScriptManager():FindItem(fullType)
        if script then name = script:getDisplayName() end
    end)
    if (not name or name == "" or name == fullType) and getItemNameFromFullType then
        pcall(function() name = getItemNameFromFullType(fullType) end)
    end
    if not name or name == "" or name == fullType then name = nil end
    cache[fullType] = name or false
    return name
end

local function fixItem(item)
    local name = item:getDisplayName()   -- the stored name, without "(bloody)" etc.
    if not name or not string.find(name, "%.") then return end
    local fixed = string.gsub(name, "([%a_][%w_]*%.[%a_][%w_]*)", function(code)
        return itemName(code)
    end)
    if fixed ~= name then item:setName(fixed) end
end

local function fixContainer(container, depth)
    if not container or depth > 3 then return end
    local items = container:getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        fixItem(item)
        if item:IsInventoryContainer() then fixContainer(item:getItemContainer(), depth + 1) end
    end
end

local function onRefresh(page, state)
    if state ~= "end" or not page or not page.backpacks then return end
    for _, button in ipairs(page.backpacks) do
        if button.inventory then fixContainer(button.inventory, 0) end
    end
end

Events.OnRefreshInventoryWindowContainers.Add(function(page, state) pcall(onRefresh, page, state) end)

-- Also every couple of seconds for your own inventory and the containers you have open,
-- because the server can rename an item (a dish you just cooked) after the window refreshed.
local ticks = 0
local function sweep()
    for i = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(i)
        if player then
            fixContainer(player:getInventory(), 0)
            local loot = getPlayerLoot and getPlayerLoot(i)
            if loot and loot.inventoryPane and loot.inventoryPane.inventory then
                fixContainer(loot.inventoryPane.inventory, 0)
            end
        end
    end
end
Events.OnTick.Add(function()
    ticks = ticks + 1
    if ticks < 120 then return end
    ticks = 0
    pcall(sweep)
end)
