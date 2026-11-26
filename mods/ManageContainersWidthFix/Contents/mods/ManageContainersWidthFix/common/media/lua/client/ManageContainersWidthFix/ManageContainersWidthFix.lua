-- Manage Containers - Wider Category List (B42)
-- The Manage Containers window has a fixed width of about 250 px, so long category
-- names (for example the ones added by Extended categories) are cut off. The whole
-- window is laid out from self.simpleViewWidth (the category list, the search box and
-- the advanced view to its right), so widening that value before the children are
-- created widens everything consistently.
require "ManageContainers/ConfigureContainer/ISConfigureContainerWindow"
if not ISConfigureContainerWindow or not ISConfigureContainerWindow.new then return end

local MOD = "ManageContainersWidthFix"
local MODES = { "auto", "original", 300, 400, 500, 600, 700 }

local opts
local function initOptions()
    if opts or not (PZAPI and PZAPI.ModOptions) then return end
    opts = PZAPI.ModOptions:create(MOD, getText("UI_MCWF_Title"))
    local w = opts:addComboBox("width", getText("UI_MCWF_Width"), getText("UI_MCWF_Width_tooltip"))
    w:addItem(getText("UI_MCWF_Auto"), true)
    w:addItem(getText("UI_MCWF_Original"), false)
    for i = 3, #MODES do w:addItem(tostring(MODES[i]) .. " px", false) end
end
initOptions()

local function getMode()
    local o = opts and opts:getOption("width")
    local v = o and o:getValue()
    return MODES[tonumber(v) or 1] or "auto"
end

-- Width of the longest translated category name, measured once per session.
local longest
local function longestCategoryWidth()
    if longest then return longest end
    local ok, cats = pcall(function() return ISConfigureContainerWindow:fetchCategories(getAllItems()) end)
    local tm = getTextManager()
    local maxw = 0
    if ok and cats then
        for i = 0, cats:size() - 1 do
            local cat = tostring(cats:get(i))
            local key = "IGUI_ItemCat_" .. cat
            local text = getText(key)
            if text == key then text = cat end
            local w = tm:MeasureStringX(UIFont.Small, text)
            if w > maxw then maxw = w end
        end
    end
    longest = maxw
    return longest
end
Events.OnGameStart.Add(function() longest = nil end)

local function wantedWidth(original)
    local mode = getMode()
    if mode == "original" then return original end
    local screenW = getCore():getScreenWidth()
    local maxW = math.floor(screenW * 0.45)
    local w
    if mode == "auto" then
        -- text starts at x=15 in the list, plus the scrollbar and a small margin
        w = 15 + longestCategoryWidth() + 20 + 24
    else
        w = mode * ISConfigureContainerWindow.UIScaleFactor()
    end
    return math.max(original, math.min(math.floor(w), maxW))
end

local origNew = ISConfigureContainerWindow.new
function ISConfigureContainerWindow:new(x, y, character, containers)
    local o = origNew(self, x, y, character, containers)
    local ok, w = pcall(wantedWidth, o.simpleViewWidth)
    if ok and w and w > o.simpleViewWidth then
        o.simpleViewWidth = w
        o:setWidth(w)
    end
    -- keep the window on screen
    local screenW = getCore():getScreenWidth()
    if o:getX() + o.simpleViewWidth > screenW then
        o:setX(math.max(0, screenW - o.simpleViewWidth - 10))
    end
    return o
end
