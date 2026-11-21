-- Better Clothing Info - Material Translation Fix (B42)
-- Better Clothing Info shows the clothing material with the raw script value
-- (item:getFabricType(), e.g. "cotton"), which is never translated.
-- This wraps BCI's global DrawItem:New and, only for the material row,
-- replaces that value with a translated name (UI_BCIMF_Fabric_<type>).
-- Unknown materials fall back to the original value with a capital letter.

require "BCI/DrawItem"

BCIMaterialFix = BCIMaterialFix or {}
local FIX = BCIMaterialFix
local MATERIAL_LABEL = "IGUI_ItemCat_Material"

function FIX.translate(value)
    if type(value) ~= "string" or value == "" then return value end
    local key = "UI_BCIMF_Fabric_" .. value:lower():gsub("%s+", "")
    local txt = getTextOrNull(key)
    if txt then return txt end
    return value:sub(1, 1):upper() .. value:sub(2)
end

function FIX.install()
    local DI = rawget(_G, "DrawItem")
    if type(DI) ~= "table" or type(DI.New) ~= "function" then return end
    if DI.New == FIX.wrapped then return end
    local original = DI.New
    FIX.wrapped = function(self, value, arg2, label, ...)
        if label == MATERIAL_LABEL then
            local ok, v = pcall(FIX.translate, value)
            if ok then value = v end
        end
        return original(self, value, arg2, label, ...)
    end
    DI.New = FIX.wrapped
end

FIX.install()
Events.OnGameBoot.Add(FIX.install)
Events.OnGameStart.Add(FIX.install)
