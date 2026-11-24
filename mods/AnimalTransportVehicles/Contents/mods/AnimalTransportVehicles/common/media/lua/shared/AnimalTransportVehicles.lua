-- Animal Transport in Vehicles (B42)
-- Gives existing vehicles (vanilla and modded) a small animal capacity in their trunk or truck bed,
-- using the game's own animal trailer system: the same "Put animal in" / "Check animals" / "Remove
-- animal" menus, the same per-animal sizes, and the animals stay real (hunger, age, genetics...).
-- Nothing is replaced: it only adds animalTrailerSize and an AnimalEntry area (copied from the
-- vehicle's TruckBed area) to vehicle scripts that have a trunk and no animal capacity yet.
-- Runs on both client and server with the same rules, so they always agree.

AnimalTransportVehicles = AnimalTransportVehicles or {}
local ATV = AnimalTransportVehicles

-- Capacity by vehicle kind (animal sizes: hen 30, lamb 60, piglet 70, sheep 100, calf 120, cow 400).
ATV.SIZE_CAR     = 60    -- cars and SUVs: birds, small animals, a lamb
ATV.SIZE_PICKUP  = 120   -- pickup trucks: a calf or a sheep, or several small animals
ATV.SIZE_VAN     = 200   -- vans, step vans, buses: about two sheep
ATV.SIZE_TRAILER = 150   -- cargo trailers that are not livestock trailers

local SKIP = { "burnt", "smashed", "wreck" }

local function lower(s) return string.lower(tostring(s or "")) end

local function sizeFor(name)
    local n = lower(name)
    for _, k in ipairs(SKIP) do if string.find(n, k, 1, true) then return 0 end end
    if string.find(n, "trailer", 1, true) then return ATV.SIZE_TRAILER end
    if string.find(n, "pickup", 1, true) or string.find(n, "truck", 1, true) then return ATV.SIZE_PICKUP end
    if string.find(n, "van", 1, true) or string.find(n, "bus", 1, true) then return ATV.SIZE_VAN end
    return ATV.SIZE_CAR
end

local function fmt(v) return string.format("%.4f", tonumber(v) or 0) end

function ATV.apply()
    local sm = getScriptManager and getScriptManager()
    if not sm then return 0 end
    local list = sm:getAllVehicleScripts()
    if not list then return 0 end
    local done = 0
    for i = 0, list:size() - 1 do
        local script = list:get(i)
        local ok, err = pcall(function()
            if script:getAnimalTrailerSize() > 0 then return end          -- livestock trailers, or already done
            if not (script:getPartById("TruckBed") or script:getPartById("TruckBedOpen")) then return end
            local area = script:getAreaById("TruckBed")
            if not area then return end
            local size = sizeFor(script:getFullName())
            if size <= 0 then return end
            -- Area values are already scaled by the vehicle's model scale (scripts are loaded), and
            -- Load() does not scale new areas, so the TruckBed numbers can be copied as they are.
            local text = "vehicle " .. script:getName() .. " { animalTrailerSize = " .. size .. ","
                .. " area AnimalEntry { xywh = " .. fmt(area:getX()) .. " " .. fmt(area:getY()) .. " "
                .. fmt(area:getW()) .. " " .. fmt(area:getH()) .. ", } }"
            script:Load(script:getName(), text)
            done = done + 1
        end)
        if not ok and not ATV.logged then
            ATV.logged = true
            print("[AnimalTransportVehicles] " .. tostring(err))
        end
    end
    if done > 0 then print("[AnimalTransportVehicles] animal capacity added to " .. done .. " vehicle scripts") end
    return done
end

-- Scripts are loaded before these events; apply() is idempotent (vehicles already done are skipped).
Events.OnGameBoot.Add(ATV.apply)
if Events.OnServerStarted then Events.OnServerStarted.Add(ATV.apply) end
Events.OnGameStart.Add(ATV.apply)
