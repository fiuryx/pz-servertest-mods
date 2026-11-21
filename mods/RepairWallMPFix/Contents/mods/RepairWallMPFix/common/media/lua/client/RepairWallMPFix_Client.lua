-- Repair Wall - MP Fix (B42) - client side
-- Replaces the context menu and network flow of [K] Repair Wall:
--  * the server only sends counts (it used to send inventory items, which do not travel over the
--    network, so in MP the tools had to be in hand and metal repairs failed on the welding mask);
--  * tools and welding mask are looked up locally, moved to the main inventory and equipped/worn;
--  * the server takes the materials of the right player and computes the repair itself.
-- If [K] Show Wall Health is active, its "Check" sub-option gets a translated name and an icon, and
-- answers meant for other players no longer add options to your menu.

require "RepairWallMPFix_Shared"

local INFO_ICON = "media/ui/infoIcon.png"
local REPAIR_ICON = "media/ui/repairIcon.png"

local function itemIcon(fullType)
    local sm = getScriptManager()
    local script = sm and sm:FindItem(fullType)
    if script then
        local icon = script:getIcon()
        if icon and icon ~= "" then
            local tex = getTexture("Item_" .. icon)
            if tex then return tex end
        end
    end
    return nil
end

local function infoIcon()
    return getTexture("media/ui/BetterContextMenuIcons/Info.png") or getTexture(INFO_ICON)
end

----------------------------------------------------------------------
-- Repair Wall: context menu
----------------------------------------------------------------------
RWFix.req = 0
RWFix.menu = nil
RWFix.object = nil
RWFix.playerNum = 0

function RWFix.onFillMenu(playerNum, context, worldObjects, test)
    if test then return end
    local seen = {}
    for i = 1, #worldObjects do
        local obj = worldObjects[i]
        if not seen[obj] and RWFix.isRepairable(obj) then
            seen[obj] = true
            local health, maxHealth = obj:getHealth(), obj:getMaxHealth()
            if health > 0 and health < maxHealth then
                local args = RWFix.objectArgs(obj)
                if args and args.index >= 0 then
                    local sub = ISContextMenu:getNew(context)
                    local option = context:addOptionOnTop(getText("ContextMenu_Kamer_RepairWall_Repair"), worldObjects, nil)
                    option.iconTexture = getTexture(REPAIR_ICON)
                    context:addSubMenu(option, sub)

                    RWFix.req = RWFix.req + 1
                    RWFix.menu = sub
                    RWFix.object = obj
                    RWFix.playerNum = playerNum
                    args.req = RWFix.req

                    local player = getSpecificPlayer(playerNum)
                    if isClient() then
                        sendClientCommand(player, RWFix.MODULE, "Check", args)
                    elseif RWFix.serverCheck then
                        RWFix.serverCheck(player, args)
                    end
                    return
                end
            end
        end
    end
end

local function buildOption(args)
    if args.req ~= RWFix.req or not RWFix.menu or not RWFix.object then return end
    local obj = RWFix.object
    local player = getSpecificPlayer(RWFix.playerNum)
    if not player then return end

    local name = getText(args.nameKey)
    local option = RWFix.menu:addOption(getText("ContextMenu_Kamer_RepairWall_RepairOption", name),
        obj, RWFix.prepare, player, args.material)
    if args.material == "Metal" then
        option.iconTexture = itemIcon("Base.BlowTorch")
    else
        option.iconTexture = itemIcon("Base.Hammer")
    end

    local color = "<RGB:1,0,0>"
    if args.percent > 45 then
        color = "<RGB:0,1,0>"
    elseif args.percent > 25 then
        color = "<RGB:0.604,0.804,0.196>"
    end

    local tooltip = ISToolTip:new()
    tooltip:initialise()
    tooltip:setName(name)
    pcall(function() tooltip:setTexture(obj:getSprite():getName()) end)
    local desc = getText("ContextMenu_Kamer_RepairWall_ToolTip1", color, args.percent)
    for kind, n in pairs(args.needs) do
        local have = args.have[kind] or 0
        local itemName = getItemNameFromFullType("Base." .. kind) or kind
        local rgb = have >= n and "<RGB:0,1,0>" or "<RGB:1,0,0>"
        desc = string.format("%s <LINE> %s %s %d/%d", desc, rgb, itemName, have, n)
    end
    tooltip.description = desc
    option.toolTip = tooltip
    option.notAvailable = not args.ok
end

-- Finds a usable tool locally (main inventory or equipped bags).
local function findLocal(player, kind)
    local found = RWFix.collect(player)
    return found[kind] and found[kind][1] or nil
end

local function isWorn(player, item)
    local ok, worn = pcall(function() return player:isEquippedClothing(item) end)
    if ok then return worn end
    return item:isEquipped()
end

function RWFix.prepare(obj, player, material)
    if not obj or obj:getObjectIndex() == -1 then return end
    local sq = obj:getSquare()
    if not luautils.walkAdjWindowOrDoor(player, sq, obj) then return end

    local toolKind = material == "Metal" and "BlowTorch" or "Hammer"
    local held = player:getPrimaryHandItem()
    if not (held and held:getType() and string.find(held:getType(), toolKind)) then
        local tool = findLocal(player, toolKind)
        if not tool then return end
        ISInventoryPaneContextMenu.transferIfNeeded(player, tool)
        ISTimedActionQueue.add(ISEquipWeaponAction:new(player, tool, 50, true))
        held = tool
    end

    if material == "Metal" then
        local mask = findLocal(player, "WeldingMask")
        if not mask then return end
        if not isWorn(player, mask) then
            ISInventoryPaneContextMenu.transferIfNeeded(player, mask)
            ISTimedActionQueue.add(ISWearClothing:new(player, mask, 50))
        end
    end

    ISTimedActionQueue.add(KAMER_RepairWallsAction:new(material, player, obj, sq, held, { HasItems = true }))
end

-- New perform(): the server (or the local game in singleplayer) does the repair.
local function patchAction()
    if not KAMER_RepairWallsAction or KAMER_RepairWallsAction.rwfixPatched then return end
    KAMER_RepairWallsAction.rwfixPatched = true

    local oldIsValid = KAMER_RepairWallsAction.isValid
    function KAMER_RepairWallsAction:isValid()
        if not self.object or self.object:getObjectIndex() == -1 then return false end
        return oldIsValid(self)
    end

    function KAMER_RepairWallsAction:perform()
        if self.hammerSound and self.hammerSound ~= 0 and self.character:getEmitter():isPlaying(self.hammerSound) then
            self.character:getEmitter():stopSound(self.hammerSound)
        end
        local args = RWFix.objectArgs(self.object)
        if args then
            if isClient() then
                sendClientCommand(self.character, RWFix.MODULE, "Repair", args)
            elseif RWFix.serverRepair then
                RWFix.serverRepair(self.character, args)
            end
        end
        ISBaseTimedAction.perform(self)
    end
end

----------------------------------------------------------------------
-- Server answers
----------------------------------------------------------------------
function RWFix.onServerCommand(module, command, args)
    if module ~= RWFix.MODULE or not args then return end
    if command == "Menu" then
        buildOption(args)
    elseif command == "Health" then
        local obj = RWFix.findObject(args.x, args.y, args.z, args.index)
        if obj and RWFix.isRepairable(obj) then
            obj:setHealth(args.health)
        end
    elseif command == "Missing" then
        local player = getSpecificPlayer(0)
        if player then player:Say(getText("ContextMenu_RWFix_Missing")) end
    end
end

----------------------------------------------------------------------
-- Show Wall Health (optional): translated names, icon, only our own answers
----------------------------------------------------------------------
local swhPending = {}

local function swhKey(x, y, z, index)
    return tostring(x) .. "," .. tostring(y) .. "," .. tostring(z) .. "," .. tostring(index)
end

local function swhHandler(module, command, args)
    if module ~= "KAMER_WallHealth_Server" or command ~= "updateHealth" or not args then return end
    local player = getSpecificPlayer(args.playerIndex or 0)
    if not player then return end
    local obj = RWFix.findObject(args.x, args.y, args.z, args.index)
    if not RWFix.isRepairable(obj) then return end

    if isClient() then
        obj:setHealth(args.newHealth)
    else
        args.newHealth = obj:getHealth()
    end

    local key = swhKey(args.x, args.y, args.z, args.index)
    if not swhPending[key] then return end
    swhPending[key] = nil
    if args.newHealth == 0 then return end

    local menu = KAMER_WallHealth.trashcan and KAMER_WallHealth.trashcan.menu
    if not menu then return end

    local name = getText(RWFix.nameKey(obj))
    local option = menu:addOption(getText("ContextMenu_Kamer_ShowWallHealth_Check", name), obj,
        KAMER_WallHealth.onObjectInfo, obj, player)
    option.iconTexture = infoIcon()
    if player:DistToSquared(args.x + 0.5, args.y + 0.5) < 4 then
        local tooltip = ISToolTip:new()
        tooltip.description = getText("ContextMenu_Kamer_ShowWallHealth_Health", args.newHealth, obj:getMaxHealth())
        tooltip:setName(name)
        option.toolTip = tooltip
    end
end

local function patchShowWallHealth()
    if not KAMER_WallHealth or KAMER_WallHealth.rwfixPatched then return end
    if not KAMER_WallHealth.Check or not KAMER_WallHealth.HandleClientRequestsK then return end
    KAMER_WallHealth.rwfixPatched = true

    local origCheck = KAMER_WallHealth.Check
    Events.OnFillWorldObjectContextMenu.Remove(origCheck)
    KAMER_WallHealth.Check = function(playerNum, context, worldObjects, test)
        if test then return end
        local seen = {}
        for i = 1, #worldObjects do
            local obj = worldObjects[i]
            if not seen[obj] and RWFix.isRepairable(obj) then
                seen[obj] = true
                local a = RWFix.objectArgs(obj)
                if a then swhPending[swhKey(a.x, a.y, a.z, obj:getObjectIndex())] = true end
            end
        end
        return origCheck(playerNum, context, worldObjects, test)
    end
    Events.OnFillWorldObjectContextMenu.Add(KAMER_WallHealth.Check)

    Events.OnServerCommand.Remove(KAMER_WallHealth.HandleClientRequestsK)
    KAMER_WallHealth.HandleClientRequestsK = swhHandler
    Events.OnServerCommand.Add(swhHandler)
end

----------------------------------------------------------------------
-- Hook up (after every mod's lua is loaded)
----------------------------------------------------------------------
local function install()
    if RWFix.installed then return end
    if not KAMER_RepairWall or not KAMER_RepairWallsAction then return end
    RWFix.installed = true
    if KAMER_RepairWall.Repair then
        Events.OnFillWorldObjectContextMenu.Remove(KAMER_RepairWall.Repair)
    end
    if HandleServerRequestsK then
        Events.OnServerCommand.Remove(HandleServerRequestsK)
    end
    Events.OnFillWorldObjectContextMenu.Add(RWFix.onFillMenu)
    Events.OnServerCommand.Add(RWFix.onServerCommand)
    patchAction()
end

local function hookUp()
    install()
    patchShowWallHealth()
end

Events.OnGameBoot.Add(hookUp)
Events.OnGameStart.Add(hookUp)
