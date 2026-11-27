-- AutoCook & Manage Containers - Range (B42): shared helpers.
CookAndSortRange = CookAndSortRange or {}
local R = CookAndSortRange

local function sv()
    return SandboxVars and SandboxVars.CookAndSortRange or {}
end

function R.radius()
    local r = tonumber(sv().Radius) or 8
    if r < 1 then r = 1 elseif r > 20 then r = 20 end
    return math.floor(r)
end

function R.enabled(which)
    local v = sv()[which]
    return v ~= false
end

-- Makes sure the client has the contents of a container it has never opened.
function R.checkExplored(inv, player)
    if inv:isExplored() then return end
    if isClient() then
        inv:requestServerItemsForContainer()
    else
        ItemPicker.fillContainer(inv, player)
    end
    inv:setExplored(true)
end

-- World containers (furniture, appliances...) within the radius, on the player's floor,
-- nearest first. Returns a Lua list of { inv = ItemContainer, obj = IsoObject, dist = number }.
function R.nearbyContainers(player, explore)
    local out = {}
    local sq0 = player and player:getCurrentSquare()
    if not sq0 then return out end
    local cell = getCell()
    local px, py, pz = sq0:getX(), sq0:getY(), sq0:getZ()
    local r = R.radius()
    for x = px - r, px + r do
        for y = py - r, py + r do
            local sq = cell:getGridSquare(x, y, pz)
            if sq then
                local objs = sq:getObjects()
                for i = 0, objs:size() - 1 do
                    local obj = objs:get(i)
                    local n = obj:getContainerCount()
                    if n and n > 0 and not (instanceof(obj, "IsoThumpable") and obj:isLockedToCharacter(player)) then
                        for c = 0, n - 1 do
                            local inv = obj:getContainerByIndex(c)
                            if inv then
                                if explore then R.checkExplored(inv, player) end
                                local dx, dy = x - px, y - py
                                table.insert(out, { inv = inv, obj = obj, dist = math.sqrt(dx * dx + dy * dy) })
                            end
                        end
                    end
                end
            end
        end
    end
    table.sort(out, function(a, b) return a.dist < b.dist end)
    return out
end

-- Containers the player reaches without walking (inventory, bags, adjacent loot).
function R.reachable(player)
    local set = {}
    local list = ISInventoryPaneContextMenu.getContainers(player)
    if list then
        for i = 0, list:size() - 1 do set[list:get(i)] = true end
    end
    return set, list
end

-- Queues a walk to a world container when it is out of reach. Returns false if it can't be reached.
function R.walkTo(player, inv)
    if not inv or inv:isInCharacterInventory(player) then return true end
    local parent = inv:getParent()
    if not parent or not parent.getSquare or not parent:getSquare() then return true end
    return luautils.walkToContainer(inv, player:getPlayerNum())
end
