-- Proximity Inventory - Remember Force Selected (B42)
-- Proximity Inventory (2847184718) keeps "Force Selected" only in memory, so it is lost when the
-- game restarts. This remembers it per local player in Zomboid/Lua/ProximityInventory_ForceSelected.txt
local ok, PI = pcall(require, "ProximityInventory/ProximityInventory")
if not ok or type(PI) ~= "table" or type(PI.isForceSelected) ~= "table" then return end

local FILE = "ProximityInventory_ForceSelected.txt"

-- Options > Mods: turn the automatic saving on or off
local opts = nil
if PZAPI and PZAPI.ModOptions then
    opts = PZAPI.ModOptions:create("ProxInvRememberForce", getText("UI_PIRF_Title"))
    opts:addTickBox("remember", getText("UI_PIRF_Remember"), true, getText("UI_PIRF_Remember_tooltip"))
end
local function enabled()
    if not opts then return true end
    local ok, v = pcall(function() return opts:getOption("remember"):getValue() end)
    if ok and v ~= nil then return v == true end
    return true
end
local saved = {}
local ready = false

local function load()
    local r = getFileReader(FILE, false)
    if not r then return end
    local line = r:readLine()
    while line do
        local n, v = line:match("^(%d+)=(%d)")
        if n then saved[tonumber(n)] = (v == "1") end
        line = r:readLine()
    end
    r:close()
end

local function save()
    local w = getFileWriter(FILE, true, false)
    if not w then return end
    for n = 0, 3 do
        if saved[n] ~= nil then w:write(n .. "=" .. (saved[n] and "1" or "0") .. "\r\n") end
    end
    w:close()
end

local function applyFor(n)
    if not enabled() then return end
    if saved[n] and not PI.isForceSelected[n] then
        PI.isForceSelected[n] = true
        if PI.manualContainerOverride then PI.manualContainerOverride[n] = nil end
        if ISInventoryPage and ISInventoryPage.dirtyUI then ISInventoryPage.dirtyUI() end
    end
end

pcall(load)

Events.OnCreatePlayer.Add(function(n) pcall(applyFor, n) end)
Events.OnGameStart.Add(function()
    for n = 0, 3 do pcall(applyFor, n) end
    ready = true
end)

-- Every half second: if the player changed the option (menu, Shift+click or key), save it.
local ticks = 0
Events.OnTick.Add(function()
    if not ready or not enabled() then return end
    ticks = ticks + 1
    if ticks % 30 ~= 0 then return end
    local changed = false
    for n = 0, 3 do
        if getSpecificPlayer(n) then
            local cur = PI.isForceSelected[n] == true
            if (saved[n] == true) ~= cur then saved[n] = cur; changed = true end
        end
    end
    if changed then pcall(save) end
end)
