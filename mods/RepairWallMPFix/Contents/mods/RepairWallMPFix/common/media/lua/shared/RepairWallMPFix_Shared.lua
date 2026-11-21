-- Repair Wall - MP Fix (B42)
-- Shared helpers used by the client and the server parts of the patch.

RWFix = RWFix or {}
RWFix.MODULE = "RepairWallMPFix"
RWFix.TOOLS = { Hammer = true, BlowTorch = true, WeldingMask = true }

function RWFix.isRepairable(obj)
    if not obj then return false end
    if not (instanceof(obj, "IsoThumpable") or instanceof(obj, "IsoDoor")) then return false end
    local md = obj:getModData()
    if md and md.wallType == "doorframe" then return false end
    return true
end

-- Translation key for the generic name of the object (the original mod used hardcoded English).
function RWFix.nameKey(obj)
    if instanceof(obj, "IsoThumpable") then return "ContextMenu_RWFix_WallObject" end
    if instanceof(obj, "IsoDoor") then return "ContextMenu_RWFix_Door" end
    return "ContextMenu_RWFix_Unknown"
end

function RWFix.findObject(x, y, z, index)
    local cell = getCell()
    if not cell then return nil end
    local sq = cell:getGridSquare(x, y, z)
    if not sq then return nil end
    local objects = sq:getObjects()
    if not index or index < 0 or index >= objects:size() then return nil end
    return objects:get(index)
end

function RWFix.objectArgs(obj)
    local sq = obj:getSquare()
    if not sq then return nil end
    return { x = sq:getX(), y = sq:getY(), z = sq:getZ(), index = sq:getObjects():indexOf(obj) }
end

-- Material and needed items, using the original mod's rules.
function RWFix.needs(obj)
    local data
    if KAMER_RepairWallsUtils and KAMER_RepairWallsUtils.ModData then
        local ok, res = pcall(KAMER_RepairWallsUtils.ModData, KAMER_RepairWallsUtils, obj)
        if ok and res then data = res end
    end
    if not data then
        data = { material = "Wood", needs = { Nails = 2, Plank = 1, Hammer = 1 }, allItems = 3 }
    end
    return data
end

-- Repair amount (percent of max health), from the player's own skills.
function RWFix.repairPercent(material, player)
    local lv = 0
    if material == "Metal" then
        lv = player:getPerkLevel(Perks.MetalWelding)
    else
        lv = player:getPerkLevel(Perks.Woodwork)
    end
    return (lv + 1) * 6
end

local function isUsableTool(kind, item)
    if kind == "Hammer" then
        local ok, broken = pcall(function() return item:isBroken() end)
        if ok and broken then return false end
        local okc, cond = pcall(function() return item:getCondition() end)
        if okc and cond and cond <= 0 then return false end
    elseif kind == "BlowTorch" then
        local ok, uses = pcall(function() return item:getCurrentUsesFloat() end)
        if ok and uses and uses <= 0 then return false end
    end
    return true
end

local function kindOf(item)
    local t = item:getType()
    if not t then return nil end
    if string.find(t, "Hammer") then return "Hammer" end
    if string.find(t, "WeldingMask") then return "WeldingMask" end
    if string.find(t, "BlowTorch") then return "BlowTorch" end
    return t
end

-- Items of the player: main inventory plus equipped bags (not favourites, not key rings),
-- the same places the original mod looked in. Returns { kind = { item, item, ... } }.
function RWFix.collect(player)
    local found = {}
    local function add(item)
        local kind = kindOf(item)
        if not kind then return end
        if RWFix.TOOLS[kind] and not isUsableTool(kind, item) then return end
        found[kind] = found[kind] or {}
        table.insert(found[kind], item)
    end
    local items = player:getInventory():getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        add(item)
        if instanceof(item, "InventoryContainer") and item:isEquipped() and not item:isFavorite() then
            local t = item:getType() or ""
            if not string.find(t, "KeyRing") then
                local inner = item:getInventory():getItems()
                for j = 0, inner:size() - 1 do
                    add(inner:get(j))
                end
            end
        end
    end
    return found
end

function RWFix.counts(found, needs)
    local have, okCount = {}, 0
    for kind, n in pairs(needs) do
        have[kind] = found[kind] and #found[kind] or 0
        if have[kind] >= n then okCount = okCount + 1 end
    end
    return have, okCount
end
