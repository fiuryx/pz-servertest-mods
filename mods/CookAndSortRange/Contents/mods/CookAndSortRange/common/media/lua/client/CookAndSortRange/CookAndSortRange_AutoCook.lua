-- AutoCook: ingredients from containers within the radius, walking to take them and to put
-- the unused ones back.
require "CookAndSortRange/CookAndSortRange_Core"
local R = CookAndSortRange

-- installed on game start, once every mod's Lua is loaded
local function install()
if not AutoCook or not AutoCook.continue then pcall(require, "AutoCook") end
if not AutoCook or not AutoCook.continue then
    print("[CookAndSortRange] AutoCook not found, hooks not installed")
    return
end
if R.acInstalled then return end
R.acInstalled = true
R.origGetContainers = R.origGetContainers or ISInventoryPaneContextMenu.getContainers

-- containers used while AutoCook is choosing: reachable ones plus the ones within the radius
local function extendedContainers(player, getFn)
    local set, list = R.reachable(player, getFn)
    local out = ArrayList.new()
    if list then for i = 0, list:size() - 1 do out:add(list:get(i)) end end
    for _, c in ipairs(R.nearbyContainers(player, true)) do
        if not set[c.inv] then out:add(c.inv); set[c.inv] = true end
    end
    return out
end

local extending = false
local function withExtended(player, fn, ...)
    -- already inside (AutoCook calling itself): the extended list is in place
    if extending or not R.enabled("AutoCook") then return fn(...) end
    local orig = ISInventoryPaneContextMenu.getContainers
    ISInventoryPaneContextMenu.getContainers = function(character)
        if character == player then return extendedContainers(character, orig) end
        return orig(character)
    end
    extending = true
    local res = { pcall(fn, ...) }
    extending = false
    ISInventoryPaneContextMenu.getContainers = orig
    if not res[1] then print("[CookAndSortRange] " .. tostring(res[2])); return end
    return unpack(res, 2)
end

local origContinue = AutoCook.continue
function AutoCook:continue()
    return withExtended(self.playerObj, origContinue, self)
end

local origQueueAddItem = AutoCook.queueAddItem
function AutoCook:queueAddItem(usedItem)
    if R.enabled("AutoCook") then
        local inv = self.playerObj:getInventory()
        if usedItem and not inv:contains(usedItem) and usedItem:getContainer() then
            R.walkTo(self.playerObj, usedItem:getContainer())
        end
    end
    return origQueueAddItem(self, usedItem)
end

local origReturn = AutoCook.returnItemsToOriginalContainer
function AutoCook:returnItemsToOriginalContainer()
    if not R.enabled("AutoCook") then return origReturn(self) end
    -- group by container (nearest first) and walk to each one before putting its items back
    local groups, order = {}, {}
    for _, s in pairs(self.returnToContainer or {}) do
        local c = s.sourceContainer
        if c then
            if not groups[c] then groups[c] = {}; table.insert(order, c) end
            table.insert(groups[c], s)
        end
    end
    local p = self.playerObj
    table.sort(order, function(a, b)
        local pa, pb = a:getParent(), b:getParent()
        if not pa or not pb or not pa.getSquare or not pb.getSquare or not pa:getSquare() or not pb:getSquare() then return false end
        return p:DistToSquared(pa:getX(), pa:getY()) < p:DistToSquared(pb:getX(), pb:getY())
    end)
    local all = self.returnToContainer
    for _, c in ipairs(order) do
        R.walkTo(p, c)
        self.returnToContainer = groups[c]
        origReturn(self)
    end
    self.returnToContainer = all
end

-- The AutoCook menu option is built with the reachable containers only: when it says there is
-- nothing to cook with, count again with the containers within the radius and enable it.
local function fixMenu(playerNum, context)
    if not R.enabled("AutoCook") or not context or not context.options then return end
    local player = getSpecificPlayer(playerNum)
    if not player then return end
    local list
    for _, option in ipairs(context.options) do
        local ac = option.target
        if option.notAvailable and type(ac) == "table" and getmetatable(ac) and ac.recipe and ac.baseItem and option.onSelect == AutoCook.continue then
            list = list or extendedContainers(player)
            local okc, items = pcall(function() return ac.recipe:getItemsCanBeUse(player, ac.baseItem, list) end)
            local count = 0
            if okc and items then
                for i = 0, items:size() - 1 do
                    local it = items:get(i)
                    if not ac.acceptIngredient or ac:acceptIngredient(it, ac.baseItem, ac.recipe) then count = count + 1 end
                end
            end
            if count > 0 then
                option.notAvailable = false
                if option.toolTip then
                    local fromName = getText("ContextMenu_EvolvedRecipe_" .. ac.recipe:getUntranslatedName())
                    option.toolTip.description = getText("ContextMenu_AutoCook_Tooltip", count, fromName)
                end
            end
        end
    end
end
Events.OnFillInventoryObjectContextMenu.Add(function(playerNum, context, items)
    local okf, err = pcall(fixMenu, playerNum, context)
    if not okf then print("[CookAndSortRange] " .. tostring(err)) end
end)
print("[CookAndSortRange] AutoCook hooks installed")
end

Events.OnGameStart.Add(install)
