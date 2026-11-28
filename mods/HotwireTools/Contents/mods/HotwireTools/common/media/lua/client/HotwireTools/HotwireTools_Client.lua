-- Radial menu: without tools the Hotwire slice is shown disabled with the reason.
require "HotwireTools/HotwireTools_Shared"
local H = HotwireTools

local function needText()
    return getText("IGUI_HotwireTools_Need")
end

local function sayNeed(playerObj)
    if HaloTextHelper and HaloTextHelper.addBadText then
        HaloTextHelper.addBadText(playerObj, needText())
    else
        playerObj:setHaloNote(needText(), 255, 80, 80, 300)
    end
end

local function install()
    if not ISVehicleMenu then pcall(require, "Vehicles/ISUI/ISVehicleMenu") end
    if not ISVehicleMenu or not ISVehicleMenu.showRadialMenu or not ISVehicleMenu.onHotwire or not ISRadialMenu then return end
    if ISVehicleMenu._HotwireToolsWrapped then return end
    ISVehicleMenu._HotwireToolsWrapped = true

    local origOnHotwire = ISVehicleMenu.onHotwire
    ISVehicleMenu.onHotwire = function(playerObj, ...)
        if playerObj and not H.hasTools(playerObj) then
            sayNeed(playerObj)
            return
        end
        return origOnHotwire(playerObj, ...)
    end

    local origShow = ISVehicleMenu.showRadialMenu
    ISVehicleMenu.showRadialMenu = function(playerObj, ...)
        if not playerObj or H.hasTools(playerObj) then return origShow(playerObj, ...) end
        local hotwireFn = ISVehicleMenu.onHotwire
        local origAdd = ISRadialMenu.addSlice
        ISRadialMenu.addSlice = function(self, text, texture, command, ...)
            if command ~= nil and (command == hotwireFn or command == origOnHotwire) then
                return origAdd(self, getText("ContextMenu_VehicleHotwire") .. "\n" .. needText(),
                    getTexture("media/ui/vehicles/vehicle_ignitionOFF.png"), nil, ...)
            end
            return origAdd(self, text, texture, command, ...)
        end
        local res = { pcall(origShow, playerObj, ...) }
        ISRadialMenu.addSlice = origAdd
        if not res[1] then error(res[2]) end
        return unpack(res, 2)
    end
    print("[HotwireTools] radial menu hooked")
end

Events.OnGameStart.Add(install)
