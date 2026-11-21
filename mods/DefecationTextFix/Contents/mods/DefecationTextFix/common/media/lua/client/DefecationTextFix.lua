-- Defecation - Toilet Option Translation Fix (B42)
-- The Defecation mod adds the toilet option with the fixed English text
-- "Defecate" instead of using its own translation key. After the world
-- context menu is built, this renames that option to getText("ContextMenu_Defecate")
-- (the key the mod already ships in every language). Nothing else is touched.

DefecationTextFix = DefecationTextFix or {}
local FIX = DefecationTextFix
local RAW = "Defecate"
local KEY = "ContextMenu_Defecate"

local function renameIn(menu, label, depth)
    if not menu or type(menu.options) ~= "table" or depth > 4 then return end
    for _, option in ipairs(menu.options) do
        if option.name == RAW then
            option.name = label
        end
        if option.subOption and menu.getSubMenu then
            local ok, sub = pcall(menu.getSubMenu, menu, option.subOption)
            if ok and sub and sub ~= menu then renameIn(sub, label, depth + 1) end
        end
    end
end

function FIX.onFill(player, context, worldObjects, test)
    if test or not context then return end
    local label = getTextOrNull(KEY)
    if not label or label == RAW then return end
    local ok, err = pcall(renameIn, context, label, 0)
    if not ok and not FIX.logged then
        FIX.logged = true
        print("[DefecationTextFix] " .. tostring(err))
    end
end

-- Registered on game start so it runs after the Defecation mod's own handler.
Events.OnGameStart.Add(function()
    if FIX.added then return end
    FIX.added = true
    Events.OnFillWorldObjectContextMenu.Add(FIX.onFill)
end)
