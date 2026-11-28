-- Hotwiring needs a screwdriver and pliers (a multitool counts as both), on top of the vanilla
-- skill requirements. Burglars don't need tools. Checked in the timed action, so the server
-- validates it too.
HotwireTools = HotwireTools or {}
local H = HotwireTools

local DEFAULT_SCREWDRIVERS = "Base.Screwdriver;Base.Screwdriver_Old;Base.Screwdriver_Improvised;Base.Multitool"
local DEFAULT_PLIERS = "Base.Pliers;Base.Multitool"

local cache = {}
local function parse(str)
    local set = cache[str]
    if set then return set end
    set = {}
    for t in string.gmatch(str or "", "[^;,%s]+") do set[t] = true end
    cache[str] = set
    return set
end

local function opt(name, default)
    local sv = SandboxVars and SandboxVars.HotwireTools
    local v = sv and sv[name]
    if v == nil or v == "" then return default end
    return v
end

local function findTool(inv, set)
    return inv:getFirstEvalRecurse(function(item)
        return set[item:getFullType()] == true and not item:isBroken()
    end)
end

function H.isBurglar(chr)
    return chr:hasTrait(CharacterTrait.BURGLAR)
end

function H.hasTools(chr)
    if not chr then return false end
    if opt("BurglarNoTools", true) and H.isBurglar(chr) then return true end
    local inv = chr:getInventory()
    if not inv then return false end
    if not findTool(inv, parse(opt("Screwdrivers", DEFAULT_SCREWDRIVERS))) then return false end
    return findTool(inv, parse(opt("Pliers", DEFAULT_PLIERS))) ~= nil
end

local function install()
    if not ISHotwireVehicle then pcall(require, "Vehicles/TimedActions/ISHotwireVehicle") end
    if not ISHotwireVehicle or ISHotwireVehicle._HotwireToolsWrapped then return end
    ISHotwireVehicle._HotwireToolsWrapped = true
    local origIsValid = ISHotwireVehicle.isValid
    function ISHotwireVehicle:isValid()
        if not origIsValid(self) then return false end
        return H.hasTools(self.character)
    end
    print("[HotwireTools] hotwire action hooked")
end

install()
Events.OnGameBoot.Add(install)
