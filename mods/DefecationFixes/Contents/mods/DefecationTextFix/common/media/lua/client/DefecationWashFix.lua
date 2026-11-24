-- Defecation Fixes (B42) - part 2: clean soiled clothes at water sources
-- The Defecation mod adds "Clean the feces" only inside the water source submenu, looking it up by name.
-- In 42.22 that submenu is built in Java and the lookup can fail (bath and shower mods, world items,
-- rain collectors...), so the option never shows. This handler runs after the mod's own: if the option
-- is not in the menu, it adds it (inside the water source submenu when found, otherwise at the top level).
-- It reuses the mod's own timed action (DefecationWashAction), so washing works exactly the same.

require "DefecationWashAction"

local MAX_DIST = 10
local NEED_WATER = 7
local NEED_CLEANER = 0.3

local function menuHas(menu, name, depth)
    if not menu or not menu.options or depth > 3 then return false end
    for _, o in pairs(menu.options) do
        if type(o) == "table" then
            if o.name == name then return true end
            if o.subOption and menu.getSubMenu then
                local ok, sub = pcall(function() return menu:getSubMenu(o.subOption) end)
                if ok and sub and menuHas(sub, name, depth + 1) then return true end
            end
        end
    end
    return false
end

local function findOption(menu, names)
    if not menu or not menu.options then return nil end
    for _, o in pairs(menu.options) do
        if type(o) == "table" and o.name and names[o.name] and o.subOption then return o end
    end
    return nil
end

local function moveableName(obj)
    local ok, name = pcall(function()
        local spr = obj:getSprite()
        if not spr then return nil end
        local props = spr:getProperties()
        if not props:has("CustomName") then return nil end
        local n = props:get("CustomName")
        if props:has("GroupName") then n = props:get("GroupName") .. " " .. n end
        return Translator.getMoveableDisplayName(n)
    end)
    return ok and name or nil
end

local function waterAmount(obj)
    local ok, amount = pcall(function()
        if obj:hasComponent(ComponentType.FluidContainer) then return obj:getFluidContainer():getAmount() end
        return obj:getFluidAmount()
    end)
    return (ok and amount) or 0
end

local function findWater(worldObjects)
    for i = 1, #worldObjects do
        local obj = worldObjects[i]
        local ok, has = pcall(function() return obj:hasWater() end)
        if ok and has then return obj end
    end
    return nil
end

local function onWash(playerObj, square, item, cleaner, water, fluidType)
    if not square or not luautils.walkAdj(playerObj, square, true) then return end
    if item:isWorn() then ISTimedActionQueue.add(ISUnequipAction:new(playerObj, item, 50)) end
    ISInventoryPaneContextMenu.transferIfNeeded(playerObj, item)
    ISInventoryPaneContextMenu.transferIfNeeded(playerObj, cleaner)
    ISTimedActionQueue.add(DefecationWashAction:new(playerObj, item, cleaner, water, fluidType))
end

local function onFill(playerNum, context, worldObjects, test)
    if test or not context or not DefecationWashAction then return end
    local label = getText("ContextMenu_DefecateSterilize")
    if menuHas(context, label, 0) then return end   -- the Defecation mod already added it

    local player = getSpecificPlayer(playerNum)
    if not player or player:getVehicle() then return end

    local items = player:getInventory():getAllEvalRecurse(function() return true end, ArrayList.new())
    local soiled, cleaner, cleanerAmount, fluidType, weak = {}, nil, 0, "", false
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        local fc = item:getFluidContainer()
        if fc and (fc:contains(Fluid.Bleach) or fc:contains(Fluid.CleaningLiquid)) then
            local t = fc:getPrimaryFluid():getFluidTypeString()
            if (t == "Bleach" or t == "CleaningLiquid") and fc:getAmount() > cleanerAmount then
                cleaner, cleanerAmount, fluidType, weak = item, fc:getAmount(), t, false
            elseif not cleaner then
                weak = true
            end
        end
        local md = item:hasModData() and item:getModData() or nil
        if md and md["DOriginalName"] ~= nil then table.insert(soiled, item) end
    end
    if #soiled == 0 then return end

    local water = findWater(worldObjects)
    if not water or not water:getSquare() then return end
    if water:getSquare():DistToProper(player:getSquare()) > MAX_DIST then return end

    -- Inside the water source submenu if we can find it; otherwise at the top level.
    local names = {}
    local mn = moveableName(water); if mn then names[mn] = true end
    pcall(function() names[water:getFluidUiName()] = true end)
    if instanceof(water, "IsoWorldInventoryObject") and water:getItem() then
        names[water:getItem():getDisplayName()] = true
        names[water:getItem():getName()] = true
    end
    names[getText("ContextMenu_NaturalWaterSource")] = true
    local parent = context
    local srcOpt = findOption(context, names)
    if srcOpt then
        local ok, sub = pcall(function() return context:getSubMenu(srcOpt.subOption) end)
        if ok and sub then parent = sub end
    end

    local washOpt = parent:addOption(label, worldObjects, nil)
    local sub = ISContextMenu:getNew(parent)
    parent:addSubMenu(washOpt, sub)

    local waterLeft = waterAmount(water)
    local cleanerName = getText("Fluid_Name_Bleach") .. " / " .. getText("Fluid_Name_CleaningLiquid")
    if fluidType == "Bleach" then cleanerName = getText("Fluid_Name_Bleach")
    elseif fluidType == "CleaningLiquid" then cleanerName = getText("Fluid_Name_CleaningLiquid") end
    local cleanerText = cleaner and tostring(math.min(math.floor(cleanerAmount * 1000), 300)) or "0"

    for _, item in ipairs(soiled) do
        local opt = sub:addOption(item:getName(), player, onWash, water:getSquare(), item, cleaner, water, fluidType)
        if not cleaner or cleanerAmount < NEED_CLEANER or waterLeft < NEED_WATER then opt.notAvailable = true end
        local tip = ISWorldObjectContextMenu.addToolTip()
        tip.description = cleanerName .. ": " .. cleanerText .. " / 300"
            .. " <LINE> " .. getText("ContextMenu_Water") .. ": " .. tostring(math.min(luautils.round(waterLeft, 2), NEED_WATER)) .. " / " .. NEED_WATER
            .. " <LINE> " .. getText("Tooltip_clothing_dirty") .. ": " .. math.ceil(item:getDirtiness()) .. " / 100"
        if weak and not cleaner then
            tip.description = tip.description .. " <LINE><RED> " .. getText("Fluid_Name_Bleach") .. " / "
                .. getText("Fluid_Name_CleaningLiquid") .. getText("Tooltip_DefecateNotPotentEnough")
        end
        opt.toolTip = tip
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFill)
