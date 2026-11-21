-- Container Button Drag (B42)
-- Lets you drag a bag (or any item container) straight from its button in the
-- container column of the inventory / loot windows, and drop it like a normal
-- dragged item: on the item list of the other window, on another container
-- button, or on the ground (bags you carry).
--
-- It only reuses the game's own drag system (ISMouseDrag + the inventory panes'
-- drop handling), so transfers go through the normal timed actions and work in
-- multiplayer. Works with the vanilla UI and with CleanUI.

require "ISUI/ISUIElement"
require "ISUI/ISMouseDrag"
require "ISUI/ISInventoryPage"
require "ISUI/ISInventoryPane"

ContainerButtonDrag = ContainerButtonDrag or {}
local CBD = ContainerButtonDrag

local DRAG_THRESHOLD = 6
local ICON_SIZE = 32
local ICON_OFFSET = 14

CBD.pending = nil
CBD.active = nil

-------------------------------------------------------------------------------
-- Drag owner used as ISMouseDrag.draggingFocus. The panes call
-- draggingFocus:onMouseUp(0,0) once they have handled the drop.
-------------------------------------------------------------------------------
local Focus = {}
function Focus:onMouseUp(x, y)
    CBD.finish()
end
CBD.focus = Focus

local function isOurDrag()
    return CBD.active ~= nil and ISMouseDrag ~= nil and ISMouseDrag.draggingFocus == Focus
end

local function getBagItem(button)
    if not button or not button.inventory then return nil end
    local ok, item = pcall(function() return button.inventory:getContainingItem() end)
    if not ok or item == nil then return nil end
    if not instanceof(item, "InventoryItem") then return nil end
    return item
end

local function resetPaneDragCaches()
    for _, getter in ipairs({ getPlayerInventory, getPlayerLoot }) do
        local page = getter(0)
        if page and page.inventoryPane and page.inventoryPane.draggedItems then
            page.inventoryPane.draggedItems:reset()
        end
    end
end

function CBD.finish()
    CBD.active = nil
    CBD.pending = nil
    if ISMouseDrag and ISMouseDrag.draggingFocus == Focus then
        ISMouseDrag.dragging = nil
        ISMouseDrag.draggingFocus = nil
    end
    resetPaneDragCaches()
end

function CBD.start(p)
    CBD.pending = nil
    local item = p.item
    if not item or not p.button or not p.button.inventory then return end
    if getBagItem(p.button) ~= item then return end
    if getCore():isTutorial() then return end
    if not ISMouseDrag then ISMouseDrag = {} end
    ISMouseDrag.dragging = { item }
    ISMouseDrag.draggingFocus = Focus
    CBD.active = { button = p.button, item = item, releaseTicks = 0 }
    -- The press now belongs to the drag, not to a click on the button.
    p.button.pressed = false
    resetPaneDragCaches()
end

local function mouseOverAnyUI(mx, my)
    local uis = UIManager.getUI()
    for i = 0, uis:size() - 1 do
        local ui = uis:get(i)
        if ui:isPointOver(mx, my) then return true end
    end
    return false
end

-- Released over the world (no window under the mouse): drop the bag on the
-- ground, like dragging it from the item list does. Only for bags you carry.
local function dropOutside(a, mx, my)
    local item = a.item
    if not item or item:isFavorite() then return end
    local playerObj = getSpecificPlayer(0)
    if not playerObj or playerObj:getVehicle() then return end
    local container = item:getContainer()
    if not container or not container:isInCharacterInventory(playerObj) then return end
    if mouseOverAnyUI(mx, my) then return end
    if ISInventoryPaneContextMenu and ISInventoryPaneContextMenu.dropItem then
        ISInventoryPaneContextMenu.dropItem(item, 0)
    end
end

function CBD.update()
    local mx, my = getMouseX(), getMouseY()

    local p = CBD.pending
    if p then
        if not isMouseButtonDown(0) then
            CBD.pending = nil
        elseif math.abs(mx - p.x) > DRAG_THRESHOLD or math.abs(my - p.y) > DRAG_THRESHOLD then
            CBD.start(p)
        end
    end

    local a = CBD.active
    if a then
        if not isOurDrag() then
            -- Someone else consumed or replaced the drag.
            CBD.active = nil
        elseif not isMouseButtonDown(0) then
            -- Give the window under the mouse a couple of frames to take the drop.
            a.releaseTicks = a.releaseTicks + 1
            if a.releaseTicks >= 2 then
                dropOutside(a, mx, my)
                CBD.finish()
            end
        else
            a.releaseTicks = 0
        end
    end
end

-------------------------------------------------------------------------------
-- Zero-size UI element: never under the mouse (so it can't swallow clicks),
-- used for the per-frame update and to draw the dragged icon.
-------------------------------------------------------------------------------
local Tracker = ISUIElement:derive("ContainerButtonDragTracker")

function Tracker:new()
    local o = ISUIElement.new(self, 0, 0, 0, 0)
    o.anchorLeft = true
    o.anchorTop = true
    return o
end

local function safeUpdate()
    local ok, err = pcall(CBD.update)
    if not ok and not CBD.loggedError then
        CBD.loggedError = true
        print("[ContainerButtonDrag] " .. tostring(err))
    end
end

function Tracker:update()
    CBD.trackerStamp = getTimestampMs()
    safeUpdate()
    self:setX(getMouseX())
    self:setY(getMouseY())
end

function Tracker:render()
    local a = CBD.active
    if not a or not a.item or not isOurDrag() then return end
    local tex = a.item:getTex()
    if tex then
        self:drawRect(ICON_OFFSET - 2, ICON_OFFSET - 2, ICON_SIZE + 4, ICON_SIZE + 4, 0.45, 0, 0, 0)
        self:drawTextureScaledAspect(tex, ICON_OFFSET, ICON_OFFSET, ICON_SIZE, ICON_SIZE, 0.9, 1, 1, 1)
    end
end

function CBD.ensureTracker()
    if CBD.tracker then return end
    local t = Tracker:new()
    t:initialise()
    t:addToUIManager()
    t:setAlwaysOnTop(true)
    CBD.tracker = t
end

-------------------------------------------------------------------------------
-- Hooks on the container buttons. ISInventoryPage:addContainerButton assigns
-- ISInventoryPage.onBackpackMouseDown / onBackpackMouseUp to every button each
-- time the column is rebuilt, so wrapping the page functions is enough.
-------------------------------------------------------------------------------
local function makeMouseDown(orig)
    return function(page, button, x, y)
        local r = orig(page, button, x, y)
        CBD.pending = nil
        if page and page.player == 0 then
            local item = getBagItem(button)
            if item then
                CBD.pending = { page = page, button = button, item = item, x = getMouseX(), y = getMouseY() }
            end
        end
        return r
    end
end

local function makeMouseUp(orig)
    return function(button, x, y)
        if isOurDrag() then
            local a = CBD.active
            -- Dropped back on its own button (or into itself): just cancel.
            local own = a.item and instanceof(a.item, "InventoryContainer") and a.item:getInventory() or nil
            if button == a.button or (own ~= nil and button.inventory == own) then
                button.pressed = false
                CBD.finish()
                return
            end
        else
            CBD.pending = nil
        end
        return orig(button, x, y)
    end
end

function CBD.install()
    if not ISInventoryPage then return end
    local down = ISInventoryPage.onBackpackMouseDown
    if down and down ~= CBD.wrappedDown then
        CBD.wrappedDown = makeMouseDown(down)
        ISInventoryPage.onBackpackMouseDown = CBD.wrappedDown
    end
    local up = ISInventoryPage.onBackpackMouseUp
    if up and up ~= CBD.wrappedUp then
        CBD.wrappedUp = makeMouseUp(up)
        ISInventoryPage.onBackpackMouseUp = CBD.wrappedUp
    end
end

-- Fallback in case the tracker element is not being updated.
Events.OnTick.Add(function()
    if CBD.trackerStamp and getTimestampMs() - CBD.trackerStamp < 250 then return end
    if CBD.pending or CBD.active then safeUpdate() end
end)

Events.OnGameBoot.Add(CBD.install)
Events.OnGameStart.Add(function()
    CBD.install()
    CBD.ensureTracker()
end)
Events.OnCreatePlayer.Add(function()
    CBD.install()
    CBD.ensureTracker()
end)
