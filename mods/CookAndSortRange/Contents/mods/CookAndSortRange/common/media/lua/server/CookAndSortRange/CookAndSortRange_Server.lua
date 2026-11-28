-- Server side of "cook in the oven/microwave": turns the appliance on with its timer set so that it turns off by
-- itself when the dish is cooked and before it can burn (vanilla timer, same as setting it by hand).
if isClient() then return end

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

-- Minutes for the timer. The dish only cooks once the appliance is hot, so the timer goes halfway between
-- "cooked" and "burnt": the heating time and the heat left after switching off both fit in that margin.
local function timerMinutes(food, micro)
    local done = food:getCookingTime() or 0
    local toCook = math.max(1, (food:getMinutesToCook() or 0) - done)
    local toBurn = (food:getMinutesToBurn() or 0) - done
    local minutes
    if toBurn > toCook + 2 then
        minutes = toCook + (toBurn - toCook) / 2
    else
        minutes = toCook * 1.5 + 10
    end
    minutes = math.ceil(minutes)
    return math.max(1, math.min(minutes, micro and 60 or 120))
end

local function startCook(player, args)
    if type(args) ~= "table" or not args.id then return end
    local stove = findStove(args.x, args.y, args.z)
    if not stove or stove:Activated() then return end
    local c = stove:getContainer()
    if not c or not c:isPowered() then return end
    local food = c:getItemById(args.id)
    if not food or not instanceof(food, "Food") or food:isCooked() or food:isBurnt() then return end
    local micro = stove:isMicrowave()
    stove:setTimer(timerMinutes(food, micro) * 60)
    stove:setMaxTemperature(micro and 100 or 200)
    stove:Toggle()
end

Events.OnClientCommand.Add(function(module, command, player, args)
    if module ~= "CookAndSortRange" or command ~= "startCook" then return end
    local ok, err = pcall(startCook, player, args)
    if not ok then print("[CookAndSortRange] " .. tostring(err)) end
end)
