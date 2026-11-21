-- Debug Menu - MP Role Fix (B42)
-- Debug Menu (QNWDebugMenuB42) builds its "Mode switch" menu with QNW_DMMode.generateMenu().
-- When it thinks the game is singleplayer it gives the player a local role called
-- "SP_DebugMenu" with every capability, so the debug options work without admin rights.
-- On our dedicated server that check passes too, so every time an admin right-clicks the
-- world the role is replaced: "SP_DebugMenu" appears over the name and the real role
-- (Admin, with its colour and title) is lost on that game.
-- In multiplayer this puts the real role back after the menu is built and removes the
-- "override need" note that only makes sense in singleplayer. Singleplayer is untouched.

require "Mode/DebugMenuMode"

if not isClient() then return end

local FAKE_ROLE = "SP_DebugMenu"
local realRole = {}    -- [playerNum] = role the server gave us

local function roleName(role)
    if not role then return nil end
    local ok, name = pcall(function() return role:getName() end)
    if ok then return name end
    return nil
end

local function rememberRole(playerNum, player)
    local role = player and player:getRole()
    if role and roleName(role) ~= FAKE_ROLE then realRole[playerNum] = role end
end

local function restoreRole(playerNum, player)
    if not player then return end
    if roleName(player:getRole()) == FAKE_ROLE and realRole[playerNum] then
        player:setRole(realRole[playerNum])
    end
end

local function removeOverrideNote(context)
    if not context or not context.getOptionFromName then return end
    local switch = context:getOptionFromName(getText("IGUI_QNW_DebugMenu_ModeSwitch"))
    if not switch or not switch.subOption then return end
    local sub = context:getSubMenu(switch.subOption)
    if sub and sub.removeOptionByName then
        sub:removeOptionByName(getText("IGUI_QNW_DebugMenu_ModeSwitch_Override_Need"))
    end
end

local function patch()
    if not QNW_DMMode or QNW_DMMode.mpRoleFixed or type(QNW_DMMode.generateMenu) ~= "function" then return end
    local original = QNW_DMMode.generateMenu
    QNW_DMMode.generateMenu = function(playerNum, context, worldObjects, ...)
        local player = getSpecificPlayer(playerNum)
        pcall(rememberRole, playerNum, player)
        local r = original(playerNum, context, worldObjects, ...)
        pcall(restoreRole, playerNum, player)
        pcall(removeOverrideNote, context)
        return r
    end
    QNW_DMMode.mpRoleFixed = true
end

patch()
Events.OnGameStart.Add(patch)

-- Remember the role the server gives us, and undo the fake role if it was already set
-- before this patch loaded (for example after a reconnect).
Events.OnCreatePlayer.Add(function(playerNum, player)
    pcall(rememberRole, playerNum, player)
end)
Events.EveryOneMinute.Add(function()
    for n = 0, 3 do
        local p = getSpecificPlayer(n)
        if p then
            pcall(rememberRole, n, p)
            pcall(restoreRole, n, p)
        end
    end
end)
