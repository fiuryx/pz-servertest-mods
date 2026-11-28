-- Server side of "cook in the oven/microwave": starts the appliance with a safety timer and turns it off as soon
-- as the dish is cooked (checked every in-game minute).
if isClient() then return end

local watches = {}

local function findStove(x, y, z)
    local sq = getCell():getGridSquare(x, y, z)
    if not sq then return nil end
    local objs = sq:getObjects()
    for i = 0, objs:size() - 1 do
        local o = objs:get(i)
        if instanceof(o, "IsoStove") then return o end
    end
    return nil
end

local function findItem(stove, id)
    local c = stove:getContainer()
    return c and c:getItemById(id) or nil
end

local function startCook(player, args)
    if type(args) ~= "table" or not args.id then return end
    local stove = findStove(args.x, args.y, args.z)
    if not stove or stove:Activated() then return end
    local c = stove:getContainer()
    if not c or not c:isPowered() then return end
    local food = findItem(stove, args.id)
    if not food or not instanceof(food, "Food") or food:isCooked() or food:isBurnt() then return end
    local micro = stove:isMicrowave()

    -- safety timer: enough to cook (the appliance has to heat up first) but below the burning time
    local done = food:getCookingTime() or 0
    local toCook = math.max(1, (food:getMinutesToCook() or 0) - done)
    local toBurn = (food:getMinutesToBurn() or 0) - done
    local minutes = math.ceil(toCook * 2 + 10)
    if toBurn > toCook + 1 then minutes = math.min(minutes, math.floor(toBurn) - 1) end
    minutes = math.max(minutes, math.ceil(toCook) + 1)
    minutes = math.min(minutes, micro and 60 or 120)

    stove:setTimer(minutes * 60)
    stove:setMaxTemperature(micro and 100 or 200)
    stove:Toggle()
    table.insert(watches, { x = args.x, y = args.y, z = args.z, id = args.id })
end

Events.OnClientCommand.Add(function(module, command, player, args)
    if module ~= "CookAndSortRange" or command ~= "startCook" then return end
    local ok, err = pcall(startCook, player, args)
    if not ok then print("[CookAndSortRange] " .. tostring(err)) end
end)

local function check()
    for i = #watches, 1, -1 do
        local w = watches[i]
        local finished = true
        local stove = findStove(w.x, w.y, w.z)
        if stove and stove:Activated() then
            local food = findItem(stove, w.id)
            if food and not food:isCooked() and not food:isBurnt() then
                finished = false
            else
                stove:Toggle() -- cooked, burnt or taken out: turn it off
            end
        end
        if finished then table.remove(watches, i) end
    end
end

Events.EveryOneMinute.Add(function()
    if #watches == 0 then return end
    local ok, err = pcall(check)
    if not ok then print("[CookAndSortRange] " .. tostring(err)) end
end)
