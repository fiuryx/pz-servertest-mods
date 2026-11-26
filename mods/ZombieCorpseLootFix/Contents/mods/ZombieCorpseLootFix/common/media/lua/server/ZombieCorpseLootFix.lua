-- Zombie Corpse Loot Fix (B42)
-- In multiplayer a client asks the server for the contents of a corpse the first time
-- it opens it, but only while that container is still "unexplored". When a mod adds an
-- item to a dying zombie and calls sendAddItemToContainer, the client receives just that
-- item and marks the container as explored, so it never asks for the rest: the corpse
-- shows only the added item (for example bullets from PZ More Tailoring army zombies)
-- and none of its clothes.
-- On the server we skip that packet for containers that belong to a zombie (its own
-- inventory or a bag it carries). The item stays on the server and reaches the client
-- with the rest of the corpse when it is opened.
if not isServer() then return end
if type(sendAddItemToContainer) ~= "function" then return end

local origSend = sendAddItemToContainer

local function belongsToZombie(container)
    local c = container
    for _ = 1, 6 do
        if not c then return false end
        local parent = c.getParent and c:getParent()
        if parent and instanceof(parent, "IsoZombie") then return true end
        local holder = c.getContainingItem and c:getContainingItem()
        if not holder then return false end
        c = holder.getContainer and holder:getContainer()
    end
    return false
end

sendAddItemToContainer = function(container, item, ...)
    local ok, zombieOwned = pcall(belongsToZombie, container)
    if ok and zombieOwned then return end
    return origSend(container, item, ...)
end
