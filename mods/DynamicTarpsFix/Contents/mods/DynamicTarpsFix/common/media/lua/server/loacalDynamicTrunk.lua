DynamicTarps = DynamicTarps or {}
DynamicTarps.ContainerAccess = DynamicTarps.ContainerAccess or {}
DynamicTarps.Init = DynamicTarps.Init or {}
DynamicTarps.Create = DynamicTarps.Create or {}

DynamicTarps.ModelList = {"Empty","Fill25","Fill50","Fill75","Full" }
DynamicTarps.KnownParts = DynamicTarps.KnownParts or {
    TruckBed = true,
    TruckBedOpen = true,
    TrailerTrunk = true,
    ATA2InteractiveTrunkRoofRack = true,
}

local function DisplayTarp(vehicle, part)
    if not vehicle or not part then return end
    local container = part:getItemContainer()
    if container then
        local maxCapacity = container:getCapacity()
        if maxCapacity < 75 then maxCapacity = 75 end
        local curCapacity = container:getContentsWeight()
        local activePos = 0
        if curCapacity > 0 then
            local fillRate = curCapacity / maxCapacity
            local modelsNumber = #DynamicTarps.ModelList
            activePos = math.floor(fillRate * modelsNumber + 1)
            if activePos > modelsNumber then activePos = modelsNumber end
        end
        for i, modelName in ipairs(DynamicTarps.ModelList) do
            part:setModelVisible(modelName, i == activePos)
        end
        vehicle:doDamageOverlay()
    end
end

local function DisplayAllTarps(vehicle)
    if not vehicle then return end
    for partId, _ in pairs(DynamicTarps.KnownParts) do
        local part = vehicle:getPartById(partId)
        if part then DisplayTarp(vehicle, part) end
    end
end

DynamicTarps.ContainerAccess.TruckBedOpen = function (vehicle, part, chr)
    local result = Vehicles.ContainerAccess.TruckBedOpen(vehicle, part, chr)
    DisplayTarp(vehicle, part)
    return result
end

function DynamicTarps.Init.OpenBed(vehicle, part)
    DisplayTarp(vehicle, part)
end

function DynamicTarps.Create.OpenBed(vehicle, part)
    Vehicles.Create.Default(vehicle, part)
    DisplayTarp(vehicle, part)
end


-- B42.18 / SVU3 Core: the old Dynamic Roof Rack patch called ATATuning2.*.RoofRack,
-- but SVU3 Core B42 only provides the generic Tuning functions.  These wrappers
-- keep the roof rack as a real vehicle container while still refreshing the tarp.
DynamicTarps.ContainerAccess.RoofRack = function(vehicle, part, chr)
    if not vehicle or not part then return false end
    if not part:getInventoryItem() then return false end
    if not part:getItemContainer() then return false end

    -- Keep access permissive: the vanilla inventory UI already controls range/visibility.
    DisplayTarp(vehicle, part)
    return true
end

function DynamicTarps.Init.RoofRack(vehicle, part)
    if ATATuning2 and ATATuning2.Init and ATATuning2.Init.Tuning then
        ATATuning2.Init.Tuning(vehicle, part)
    end
    DisplayTarp(vehicle, part)
end

function DynamicTarps.Create.RoofRack(vehicle, part)
    if ATATuning2 and ATATuning2.Create and ATATuning2.Create.Tuning then
        ATATuning2.Create.Tuning(vehicle, part)
    end
    DisplayTarp(vehicle, part)
end

-- SVU3 B42 roof racks do not always call the old TruckBedOpen access hook.
-- This keeps the visual tarp in sync after loading, entering/exiting inventory, or MP sync.
-- B42.20: IsoCell:getVehicles() still exposes size(), but its returned collection no longer
-- exposes get(index) to Lua in every context. Scan nearby grid squares instead.
-- Inventory refresh can fire very frequently, so throttle the scan to avoid unnecessary work.
local DTC_LastNearbyRefresh = 0

local function DTC_UpdateNearbyVehicles()
    local player = getPlayer and getPlayer()
    if not player then return end

    local now = getTimestampMs and getTimestampMs() or 0
    if now > 0 then
        if now - DTC_LastNearbyRefresh < 1000 then return end
        DTC_LastNearbyRefresh = now
    end

    local cell = getCell and getCell()
    if not cell then return end

    local px = math.floor(player:getX())
    local py = math.floor(player:getY())
    local pz = math.floor(player:getZ())
    local seen = {}

    local playerVehicle = player:getVehicle()
    if playerVehicle then
        seen[playerVehicle] = true
        DisplayAllTarps(playerVehicle)
    end

    for x = px - 20, px + 20 do
        for y = py - 20, py + 20 do
            local square = cell:getGridSquare(x, y, pz)
            if square then
                local objects = square:getMovingObjects()
                if objects then
                    for i = 0, objects:size() - 1 do
                        local obj = objects:get(i)
                        if obj and instanceof(obj, "BaseVehicle") and not seen[obj] then
                            seen[obj] = true
                            DisplayAllTarps(obj)
                        end
                    end
                end
            end
        end
    end
end

-- DynamicTarpsFix: en el servidor dedicado de B42.22 algunos eventos de jugador
-- (OnExitVehicle, OnRefreshInventoryWindowContainers) no existen y el original
-- revienta al registrarlos. Solo se registran si el evento existe.
local function DTC_SafeAdd(eventName, fn)
    local ev = Events[eventName]
    if ev and ev.Add then ev.Add(fn) end
end

DTC_SafeAdd("OnGameStart", function()
    DTC_SafeAdd("EveryTenMinutes", DTC_UpdateNearbyVehicles)
end)
DTC_SafeAdd("OnEnterVehicle", function(chr) if chr and chr:isLocalPlayer() then DTC_UpdateNearbyVehicles() end end)
DTC_SafeAdd("OnExitVehicle", function(chr) if chr and chr:isLocalPlayer() then DTC_UpdateNearbyVehicles() end end)
DTC_SafeAdd("OnRefreshInventoryWindowContainers", DTC_UpdateNearbyVehicles)
