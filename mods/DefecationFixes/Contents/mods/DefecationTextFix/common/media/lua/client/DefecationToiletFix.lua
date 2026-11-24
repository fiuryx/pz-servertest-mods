-- Defecation Fixes (B42) - part 4: "Defecate" on toilets
-- The Defecation mod puts "Defecate" for toilets only inside the toilet's own submenu, looking that
-- submenu up by name. In 42.22 the submenu is built in Java and the lookup can fail, so toilets
-- had no "Defecate" option (only the one on the ground, which needs toilet paper). This handler
-- runs after the mod's own: if a usable toilet was clicked and the option is missing, it adds it
-- (inside the toilet submenu when found, otherwise at the top level), using the mod's own actions
-- and the mod's own rules (need of at least 40 percent, toilet with water).

require "DefecationDropPantsAction"

local okDF, DF = pcall(require, "DefecationMain")
if not okDF or type(DF) ~= "table" then DF = nil end

local MOD_LABEL = "Defecate"   -- the text the Defecation mod uses for its toilet option

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

local function moveableName(obj)
    local ok, name = pcall(function()
        local props = obj:getSprite():getProperties()
        if not props:has("CustomName") then return nil end
        local n = props:get("CustomName")
        if props:has("GroupName") then n = props:get("GroupName") .. " " .. n end
        return Translator.getMoveableDisplayName(n)
    end)
    return ok and name or nil
end

local function isUsableToilet(obj)
    local ok, res = pcall(function()
        local tex = obj:getTextureName()
        if not tex or not luautils.stringStarts(tex, "fixtures_bathroom_01") then return false end
        if not obj:hasWater() or obj:getFluidAmount() < 10.0 then return false end
        local props = obj:getSprite():getProperties()
        if not props:has("CustomName") then return false end
        return string.find(string.lower(props:get("CustomName")), "toilet") ~= nil
    end)
    return ok and res
end

local function onToilet(playerObj, toilet)
    if not toilet:getSquare() or not luautils.walkAdj(playerObj, toilet:getSquare(), true) then return end
    ISTimedActionQueue.add(ISWalkToTimedAction:new(playerObj, toilet:getSquare()))
    ISTimedActionQueue.add(DefecationDropPantsAction:new(playerObj, toilet, nil))
end

local function onFill(playerNum, context, worldObjects, test)
    if test or not context or not DefecationDropPantsAction then return end
    local player = getSpecificPlayer(playerNum)
    if not player or player:getVehicle() then return end
    local need = player:getModData()["Defecate"]
    if type(need) ~= "number" or need < 0.4 then return end
    if menuHas(context, MOD_LABEL, 0) then return end   -- the Defecation mod already added it

    local sq = worldObjects[1] and worldObjects[1]:getSquare()
    if not sq then return end
    local toilet
    local objs = sq:getObjects()
    for i = 0, objs:size() - 1 do
        if isUsableToilet(objs:get(i)) then toilet = objs:get(i) break end
    end
    if not toilet then return end

    -- Inside the toilet submenu if we can find it; otherwise at the top level.
    local names = {}
    local mn = moveableName(toilet); if mn then names[mn] = true end
    pcall(function() names[toilet:getFluidUiName()] = true end)
    local parent, label = context, getText("ContextMenu_Defecate") .. " (" .. (mn or "WC") .. ")"
    for _, o in pairs(context.options or {}) do
        if type(o) == "table" and o.name and names[o.name] and o.subOption then
            local ok, sub = pcall(function() return context:getSubMenu(o.subOption) end)
            if ok and sub then parent, label = sub, getText("ContextMenu_Defecate") end
            break
        end
    end

    local opt = parent:addOption(label, player, onToilet, toilet)
    if DF and DF.playerDefecating then opt.notAvailable = true end
end

Events.OnFillWorldObjectContextMenu.Add(onFill)
