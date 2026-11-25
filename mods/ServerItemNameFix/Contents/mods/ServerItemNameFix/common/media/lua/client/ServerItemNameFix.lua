-- Server Item Name Fix (B42)
-- On a dedicated server some item names are built by the server, which cannot look up item names
-- in the players' language. Cooked dishes then show the internal code of an ingredient instead of
-- its name, for example "Bowl of Base.RicePot" instead of "Bowl of Rice".
-- This client-side patch replaces those codes with the item's name in your language, for the items
-- in your inventory and in the containers you have open. Display only: nothing is sent to the server.

local function itemName(fullType)
    if not getScriptManager():FindItem(fullType) then return nil end
    local name = getItemNameFromFullType(fullType)
    if name and name ~= "" and name ~= fullType then return name end
    return nil
end

local function fixItem(item)
    local name = item:getName()
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
