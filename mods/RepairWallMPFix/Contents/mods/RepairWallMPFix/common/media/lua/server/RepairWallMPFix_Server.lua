-- Repair Wall - MP Fix (B42) - server side
-- The original mod kept the scanned inventory in ONE global table shared by every player, so with
-- several players the materials could be taken from the wrong person. Here every player has their
-- own pending repair, the items are looked up on the server and the repair amount is computed here.

require "RepairWallMPFix_Shared"

RWFix.pending = RWFix.pending or {}

local function keyOf(player)
    local ok, name = pcall(function() return player:getUsername() end)
    if ok and name then return name end
    return "local"
end

local function reply(player, command, args)
    if isServer() then
        sendServerCommand(player, RWFix.MODULE, command, args)
    elseif RWFix.onServerCommand then
        RWFix.onServerCommand(RWFix.MODULE, command, args)
    end
end

local function broadcastHealth(obj)
    local a = RWFix.objectArgs(obj)
    if not a then return end
    a.health = obj:getHealth()
    a.maxHealth = obj:getMaxHealth()
    if isServer() then
        sendServerCommand(RWFix.MODULE, "Health", a)
    end
end

function RWFix.serverCheck(player, args)
    local obj = RWFix.findObject(args.x, args.y, args.z, args.index)
    if not RWFix.isRepairable(obj) then return end
    local health, maxHealth = obj:getHealth(), obj:getMaxHealth()
    if health <= 0 or health >= maxHealth then return end

    local data = RWFix.needs(obj)
    local found = RWFix.collect(player)
    local have, okCount = RWFix.counts(found, data.needs)

    RWFix.pending[keyOf(player)] = {
        x = args.x, y = args.y, z = args.z, index = args.index,
        material = data.material,
    }

    reply(player, "Menu", {
        req = args.req,
        x = args.x, y = args.y, z = args.z, index = args.index,
        material = data.material,
        nameKey = RWFix.nameKey(obj),
        needs = data.needs,
        have = have,
        all = data.allItems,
        ok = okCount >= data.allItems,
        percent = RWFix.repairPercent(data.material, player),
    })
end

function RWFix.serverRepair(player, args)
    local key = keyOf(player)
    local p = RWFix.pending[key]
    RWFix.pending[key] = nil
    if not p or p.x ~= args.x or p.y ~= args.y or p.z ~= args.z then return end

    local obj = RWFix.findObject(args.x, args.y, args.z, args.index)
    if not RWFix.isRepairable(obj) then return end
    local health, maxHealth = obj:getHealth(), obj:getMaxHealth()
    if health <= 0 or health >= maxHealth then return end

    -- Check the materials again now, right before taking them.
    local data = RWFix.needs(obj)
    local found = RWFix.collect(player)
    local _, okCount = RWFix.counts(found, data.needs)
    if okCount < data.allItems then
        reply(player, "Missing", {})
        return
    end

    for kind, n in pairs(data.needs) do
        if not RWFix.TOOLS[kind] then
            for i = 1, n do
                local item = found[kind][i]
                local container = item and item:getContainer()
                if container then
                    container:Remove(item)
                    if isServer() then
                        sendRemoveItemFromContainer(container, item)
                    end
                end
            end
        end
    end

    local add = math.ceil(maxHealth * RWFix.repairPercent(data.material, player) / 100)
    obj:setHealth(math.min(maxHealth, health + add))
    broadcastHealth(obj)
end

local function onClientCommand(module, command, player, args)
    if module ~= RWFix.MODULE or not player or not args then return end
    if command == "Check" then
        RWFix.serverCheck(player, args)
    elseif command == "Repair" then
        RWFix.serverRepair(player, args)
    end
end

Events.OnClientCommand.Add(onClientCommand)
