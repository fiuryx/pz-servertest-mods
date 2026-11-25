-- Item Status CleanUI - marca "Ya lo tengo" (sustituye a la de Has Been Read)
--
-- Cada jugador puede marcar libros, revistas, folletos, mapas, CD y VHS como "ya lo
-- tengo" (clic derecho, o solo al cogerlos con el marcado automatico). La marca va por
-- tipo de objeto (todos los "Mecanica Vol.2" a la vez) y sale como un icono sobre el
-- objeto en el inventario.
--
-- Cada jugador elige en las opciones que marcas ve:
--   1. Solo las mias      2. Todo el servidor      3. Mi faccion
-- En 2 y 3, marcar o desmarcar cambia esa lista para todos los que la comparten. Las
-- marcas propias se guardan siempre aparte (modData del personaje).
--
-- Migracion: la primera vez se copian las marcas de Has Been Read (y de nuestro
-- complemento Shared Marks) del personaje; las listas compartidas del servidor son las
-- mismas que usaba Shared Marks.

local MOD = "EstadoObjetosCleanUI"
local MODULE = "EOCMarks"
local MODE_OWN, MODE_SERVER, MODE_FACTION = 1, 2, 3

EOCMarks = EOCMarks or {}
local M = EOCMarks
M.shared = M.shared or { server = {}, faction = {} }
M.factionName = M.factionName
M.ready = M.ready or false

local function option(id)
    local ok, v = pcall(function()
        return PZAPI.ModOptions:getOptions(MOD):getOption(id):getValue()
    end)
    if ok then return v end
    return nil
end

function M.enabled()
    local v = option("enabled")
    if v == false then return false end
    return option("marks") ~= false
end

function M.mode()
    if not isClient() then return MODE_OWN end
    local v = option("marksShared")
    if type(v) ~= "number" then return MODE_OWN end
    return v
end

----------------------------------------------------------------------
-- Clave de cada objeto (la misma que usaba Has Been Read, para migrar)
----------------------------------------------------------------------
local function call(obj, name, ...)
    local f = obj and obj[name]
    if type(f) ~= "function" then return nil end
    local ok, v = pcall(f, obj, ...)
    if ok then return v end
    return nil
end

local function recipeResourceKey(item, ftype)
    local recipes = call(item, "getLearnedRecipes")
    if not recipes or recipes:isEmpty() then return ftype end
    local t, seen = {}, {}
    for i = 0, recipes:size() - 1 do
        local r = recipes:get(i)
        if not seen[r] then seen[r] = true; t[#t + 1] = r end
    end
    table.sort(t)
    return ftype .. "|" .. table.concat(t, "|")
end

local function isTargetLiterature(item)
    local skill = call(item, "getSkillTrained")
    if skill and SkillBook and SkillBook[skill] then return true end
    local learned = call(item, "getLearnedRecipes")
    if learned and not learned:isEmpty() then return true end
    local ft = item:getFullType()
    if ft == "Base.Flier" or ft == "Base.Brochure" then return true end
    if (call(item, "getNumberOfPages") or 0) > 0 then return true end
    local md = call(item, "getModData")
    return md ~= nil and (md.literatureTitle ~= nil or md.printMedia ~= nil)
end

-- Devuelve la clave de la marca, o nil si el objeto no se puede marcar.
function M.keyFor(item)
    if not item then return nil end
    if instanceof(item, "MapItem") then return call(item, "getMapID") end
    local media = call(item, "getMediaData")
    if media then
        local cat = call(media, "getCategory")
        if cat == "CDs" or cat == "Retail-VHS" or cat == "Home-VHS" then
            return "Base.RM-" .. tostring(media:getIndex())
        end
        return nil
    end
    if call(item, "getCategory") ~= "Literature" or not isTargetLiterature(item) then return nil end
    local ft = item:getFullType()
    local key = ft
    if ft == "Base.RecipeClipping" or ft == "Base.SewingPattern"
        or (string.find(ft, "Schematic", 1, true) and call(item, "getDisplayCategory") == "RecipeResource") then
        key = recipeResourceKey(item, ft)
    end
    local md = call(item, "getModData")
    if md then
        if md.literatureTitle then key = md.literatureTitle
        elseif md.printMedia and md.printMedia.id then key = md.printMedia.id end
    end
    return key
end

----------------------------------------------------------------------
-- Marcas propias (con migracion desde Has Been Read)
----------------------------------------------------------------------
local function own(player)
    local md = player:getModData()
    if not md.EOCMarks then
        local mine = {}
        local src = (md.HBRShared and md.HBRShared.own)
            or (md.P4HasBeenRead and md.P4HasBeenRead.markedMap)
        if type(src) == "table" then
            for k, v in pairs(src) do if v then mine[k] = true end end
        end
        md.EOCMarks = { own = mine }
        pcall(function() player:transmitModData() end)
    end
    md.EOCMarks.own = md.EOCMarks.own or {}
    return md.EOCMarks.own
end

local function sharedList(mode)
    if mode == MODE_SERVER then return M.shared.server end
    if mode == MODE_FACTION and M.factionName then return M.shared.faction end
    return nil
end

function M.isMarked(player, key)
    if not player or not key then return false end
    if own(player)[key] then return true end
    local list = sharedList(M.mode())
    return list ~= nil and list[key] == true
end

function M.setMarks(player, keys, value)
    if not player or #keys == 0 then return end
    local mine = own(player)
    for _, k in ipairs(keys) do mine[k] = value and true or nil end
    pcall(function() player:transmitModData() end)
    local mode = M.mode()
    if mode == MODE_SERVER or mode == MODE_FACTION then
        local list = sharedList(mode)
        if list then for _, k in ipairs(keys) do list[k] = value and true or nil end end
        sendClientCommand(MODULE, "set", { scope = (mode == MODE_SERVER) and "server" or "faction", keys = keys, value = value and true or false })
    end
end

----------------------------------------------------------------------
-- Menu contextual del inventario
----------------------------------------------------------------------
local function realItem(v)
    if instanceof(v, "InventoryItem") then return v end
    return v and v.items and v.items[1] or nil
end

local function onMark(keys, player) M.setMarks(player, keys, true) end
local function onUnmark(keys, player) M.setMarks(player, keys, false) end

local function onFillInventory(playerNum, context, items)
    if not M.enabled() then return end
    local player = getSpecificPlayer(playerNum)
    if not player then return end
    local keys, seen = {}, {}
    local anyMarked, anyUnmarked = false, false
    for _, v in ipairs(items) do
        local it = realItem(v)
        local key = M.keyFor(it)
        if key and not seen[key] then
            seen[key] = true
            keys[#keys + 1] = key
            if M.isMarked(player, key) then anyMarked = true else anyUnmarked = true end
        end
    end
    if #keys == 0 then return end
    if #keys == 1 then
        if anyMarked then
            context:addOption(getText("UI_EOC_Unmark"), keys, onUnmark, player)
        else
            context:addOption(getText("UI_EOC_Mark"), keys, onMark, player)
        end
    else
        if anyUnmarked then context:addOption(getText("UI_EOC_MarkAll"), keys, onMark, player) end
        if anyMarked then context:addOption(getText("UI_EOC_UnmarkAll"), keys, onUnmark, player) end
    end
end
Events.OnFillInventoryObjectContextMenu.Add(function(...) pcall(onFillInventory, ...) end)

----------------------------------------------------------------------
-- Marcado automatico al coger objetos (al terminar la transferencia)
----------------------------------------------------------------------
if ISInventoryTransferAction and not M.transferHooked then
    M.transferHooked = true
    local original = ISInventoryTransferAction.perform
    function ISInventoryTransferAction:perform(...)
        local candidates = nil
        local ok = pcall(function()
            if M.enabled() and option("autoMark") ~= false and self.character and self.destContainer
                and self.destContainer:isInCharacterInventory(self.character) then
                candidates = {}
                local queued = self.queueList and self.queueList[1]
                if queued and queued.items then
                    for i, it in ipairs(queued.items) do candidates[i] = it end
                elseif self.item then
                    candidates[1] = self.item
                end
            end
        end)
        local r = original(self, ...)
        if ok and candidates and #candidates > 0 then
            pcall(function()
                local keys, seen = {}, {}
                for _, it in ipairs(candidates) do
                    if isClient() or it:getContainer() == self.destContainer then
                        local key = M.keyFor(it)
                        if key and not seen[key] and not M.isMarked(self.character, key) then
                            seen[key] = true
                            keys[#keys + 1] = key
                        end
                    end
                end
                if #keys > 0 then M.setMarks(self.character, keys, true) end
            end)
        end
        return r
    end
end

----------------------------------------------------------------------
-- Listas compartidas (servidor)
----------------------------------------------------------------------
local asked = 0
local function onTick()
    if not isClient() then return end
    asked = asked + 1
    if asked >= 18000 or (not M.ready and asked >= 300) then
        asked = 0
        sendClientCommand(MODULE, "get", {})
    end
end

local function onServerCommand(module, command, args)
    if module ~= MODULE or type(args) ~= "table" then return end
    if command == "full" then
        M.shared.server = args.server or {}
        M.shared.faction = args.faction or {}
        M.factionName = args.factionName
        M.ready = true
    elseif command == "delta" then
        if args.scope == "faction" and args.factionName ~= M.factionName then return end
        local list = (args.scope == "server") and M.shared.server or M.shared.faction
        for _, k in pairs(args.keys or {}) do list[k] = args.value and true or nil end
    end
end

Events.OnTick.Add(onTick)
Events.OnServerCommand.Add(onServerCommand)
Events.OnGameStart.Add(function()
    if isClient() then sendClientCommand(MODULE, "get", {}) end
    local p = getSpecificPlayer(0)
    if p then pcall(own, p) end   -- migracion al entrar
end)

return M
