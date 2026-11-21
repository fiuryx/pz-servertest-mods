-- Barras de estado de objetos para el inventario de CleanUI (B42)
-- v1.2: barra de frescura de la comida perecedera.
-- v1.3: barras en la ropa activadas por defecto y opcion de posicion
--       (abajo, arriba, vertical a la izquierda o a la derecha del icono).
--       Casilla propia para el estado de armas y herramientas.
-- v1.4: ropa manchada por el mod Defecation: barra marron (solo si ese mod esta activo).
-- v1.5: las pilas cerradas ya no se recorren enteras en cada fotograma: el resultado se
--       guarda un segundo por fila y se miran como mucho 200 objetos por pila.
-- Mod propio para el servidor de FiuRy. Solo dibuja: no cambia objetos ni guarda nada.
-- Se engancha al final de renderdetails() de los dos modos de inventario de CleanUI
-- (y del vanilla si se usa sin CleanUI), sin sustituir a otros mods que ya lo envuelvan.

local MOD = "EstadoObjetosCleanUI"
local failedOnce = false

----------------------------------------------------------------------
-- Opciones (Opciones > Mods)
----------------------------------------------------------------------
local opts = nil
local function setupOptions()
    if opts or not (PZAPI and PZAPI.ModOptions) then return end
    local o = PZAPI.ModOptions:create(MOD, getText("UI_EOC_Title"))
    o:addTickBox("enabled", getText("UI_EOC_Enabled"), true, getText("UI_EOC_Enabled_tooltip"))
    o:addTickBox("weapons", getText("UI_EOC_Weapons"), true, getText("UI_EOC_Weapons_tooltip"))
    o:addTickBox("clothing", getText("UI_EOC_Clothing"), true, getText("UI_EOC_Clothing_tooltip"))
    o:addTickBox("soiled", getText("UI_EOC_Soiled"), true, getText("UI_EOC_Soiled_tooltip"))
    o:addTickBox("head", getText("UI_EOC_Head"), true, getText("UI_EOC_Head_tooltip"))
    o:addTickBox("contents", getText("UI_EOC_Contents"), true, getText("UI_EOC_Contents_tooltip"))
    o:addTickBox("fresh", getText("UI_EOC_Fresh"), true, getText("UI_EOC_Fresh_tooltip"))
    o:addTickBox("stacks", getText("UI_EOC_Stacks"), true, getText("UI_EOC_Stacks_tooltip"))
    o:addTickBox("hideFull", getText("UI_EOC_HideFull"), false, getText("UI_EOC_HideFull_tooltip"))
    local pos = o:addComboBox("position", getText("UI_EOC_Position"), getText("UI_EOC_Position_tooltip"))
    pos:addItem("UI_EOC_Pos_Bottom", true)
    pos:addItem("UI_EOC_Pos_Top", false)
    pos:addItem("UI_EOC_Pos_Left", false)
    pos:addItem("UI_EOC_Pos_Right", false)
    opts = o
end
setupOptions()

local function opt(id, default)
    if not opts then return default end
    local ok, v = pcall(function()
        local x = opts:getOption(id)
        return x and x:getValue()
    end)
    if ok and v ~= nil then return v == true end
    return default
end

-- Valor numerico (desplegables); devuelve default si no hay opciones o no es valido
local function optNum(id, default)
    if not opts then return default end
    local ok, v = pcall(function()
        local x = opts:getOption(id)
        return x and x:getValue()
    end)
    if ok and type(v) == "number" then return v end
    return default
end

-- Posicion de las barras
local POS_BOTTOM, POS_TOP, POS_LEFT, POS_RIGHT = 1, 2, 3, 4

----------------------------------------------------------------------
-- Datos del objeto
----------------------------------------------------------------------
local function call(obj, name)
    local f = obj[name]
    if type(f) ~= "function" then return nil end
    local ok, v = pcall(f, obj)
    if ok then return v end
    return nil
end

local function clamp(x) return math.max(0, math.min(1, x)) end

-- Contenido restante (0..1) o nil: consumibles con usos (mecheros, cerillas,
-- pilas, cinta, hilo...), recipientes de liquido y cargadores.
local function getContents(item)
    -- Cargadores (y cualquier objeto no-arma con municion)
    if not instanceof(item, "HandWeapon") then
        local maxA = call(item, "getMaxAmmo")
        if maxA and maxA > 0 then
            local cur = call(item, "getCurrentAmmoCount") or 0
            return clamp(cur / maxA)
        end
    end
    -- Consumibles con usos
    if instanceof(item, "DrainableComboItem") then
        local u = call(item, "getCurrentUsesFloat")
        if u == nil then u = call(item, "getUsedDelta") end
        if u ~= nil then return clamp(u) end
    end
    -- Recipientes de liquido (botellas, bidones, cantimploras...)
    local fc = call(item, "getFluidContainer")
    if fc then
        local cap = call(fc, "getCapacity")
        if cap and cap > 0 then
            return clamp((call(fc, "getAmount") or 0) / cap)
        end
    end
    return nil
end

-- Frescura de la comida perecedera: { ratio, tipo } o nil.
-- La barra mide el tiempo que le queda hasta pudrirse (OffAgeMax), con el color
-- de la fase en la que esta: fresca (verde), pasada (naranja), podrida (roja entera).
-- Si esta congelada, azul claro (casi no envejece). Usa los mismos datos que el
-- tooltip del juego (edad y dias hasta pasarse/pudrirse), que el servidor ya sincroniza.
local NOT_PERISHABLE = 1000000
local function getFreshness(item)
    if not instanceof(item, "Food") then return nil end
    local offMax = call(item, "getOffAgeMax")
    if not offMax or offMax <= 0 or offMax >= NOT_PERISHABLE then return nil end
    local off = call(item, "getOffAge") or offMax
    local age = call(item, "getAge") or 0
    if call(item, "isRotten") == true or age >= offMax then
        return { 0, "rot" }
    end
    local ratio = clamp(1 - age / offMax)
    if call(item, "isFrozen") == true then return { ratio, "frozen" } end
    if off > 0 and off < offMax and age >= off then return { ratio, "stale" } end
    return { ratio, "fresh" }
end

-- Compatibilidad con el mod Defecation: marca la ropa manchada guardando el
-- nombre original en modData.DOriginalName. Solo se usa si ese mod esta activo.
local defecationActive = nil
local function isDefecationActive()
    if defecationActive ~= nil then return defecationActive end
    local ok, res = pcall(function()
        local mods = getActivatedMods()
        return mods ~= nil and (mods:contains("Defecation") or mods:contains("\\Defecation"))
    end)
    defecationActive = ok and res == true
    return defecationActive
end
Events.OnGameStart.Add(function() defecationActive = nil end)

local function isSoiled(item)
    if not isDefecationActive() then return false end
    local md = call(item, "getModData")
    return md ~= nil and md["DOriginalName"] ~= nil
end

-- Devuelve la lista de barras a dibujar: { {ratio, tipo}, ... }
-- tipo: "cond" (estado), "head" (cabeza del arma), "fill" (contenido),
--       "fresh"/"stale"/"rot"/"frozen" (frescura de la comida)
local function getBars(item, cfg)
    local bars = {}
    local isWeapon = instanceof(item, "HandWeapon")
    local isClothing = instanceof(item, "Clothing")
    local soiled = isClothing and cfg.soiled and isSoiled(item)
    local showCond = (isWeapon and cfg.weapons) or (isClothing and (cfg.clothing or soiled))
    local wantHead = isWeapon and cfg.head
    if showCond or wantHead then
        local ratio = nil
        if showCond then
            local maxC = call(item, "getConditionMax")
            if maxC and maxC > 0 then
                ratio = clamp((call(item, "getCondition") or 0) / maxC)
            end
        end
        local head = nil
        if wantHead and call(item, "hasHeadCondition") == true then
            local hMax = call(item, "getHeadConditionMax")
            local h = call(item, "getHeadCondition")
            if hMax and hMax > 0 and h then head = clamp(h / hMax) end
        end
        if soiled or not (cfg.hideFull and (ratio == nil or ratio >= 1) and (head == nil or head >= 1)) then
            if ratio ~= nil then table.insert(bars, { ratio, soiled and "soiled" or "cond" }) end
            if head ~= nil then table.insert(bars, { head, "head" }) end
        end
    end
    if cfg.fresh then
        local f = getFreshness(item)
        if f then table.insert(bars, f) end
    end
    if cfg.contents and not isClothing then
        local fill = getContents(item)
        if fill ~= nil then table.insert(bars, { fill, "fill" }) end
    end
    return bars
end

local function colorFor(r, kind)
    if kind == "fresh" then return 0.20, 0.80, 0.20 end   -- verde: fresca
    if kind == "stale" then return 0.95, 0.55, 0.10 end   -- naranja: pasada
    if kind == "rot" then return 0.90, 0.15, 0.15 end     -- rojo: podrida
    if kind == "frozen" then return 0.55, 0.85, 1.00 end  -- azul claro: congelada
    if kind == "soiled" then return 0.45, 0.28, 0.10 end  -- marron: ropa manchada (Defecation)
    if kind == "fill" then
        if r >= 0.25 then return 0.25, 0.60, 1.00 end   -- azul: contenido
        return 0.90, 0.15, 0.15                          -- rojo: casi vacio
    end
    if r >= 0.75 then return 0.20, 0.80, 0.20 end   -- verde
    if r >= 0.50 then return 0.90, 0.85, 0.15 end   -- amarillo
    if r >= 0.25 then return 0.95, 0.55, 0.10 end   -- naranja
    return 0.90, 0.15, 0.15                          -- rojo
end

-- Barra horizontal (se llena de izquierda a derecha) o vertical (de abajo arriba)
local function drawBar(pane, x, y, w, h, r, kind, vertical)
    pane:drawRect(x, y, w, h, 0.75, 0.05, 0.05, 0.05)
    if kind == "rot" then r = 1 end   -- podrida: barra roja entera
    local cr, cg, cb = colorFor(r, kind)
    if vertical then
        local fh = math.floor((h - 2) * r + 0.5)
        if fh > 0 then
            pane:drawRect(x + 1, y + 1 + (h - 2 - fh), w - 2, fh, 1.0, cr, cg, cb)
        end
    else
        local fw = math.floor((w - 2) * r + 0.5)
        if fw > 0 then
            pane:drawRect(x + 1, y + 1, fw, h - 2, 1.0, cr, cg, cb)
        end
    end
end

----------------------------------------------------------------------
-- Pilas cerradas: objeto que peor esta (con cache)
----------------------------------------------------------------------
-- Recorrer una pila de cientos de objetos en cada fotograma baja los FPS, asi que
-- el resultado se guarda un segundo por fila (la fila es una tabla nueva cada vez
-- que el inventario se refresca) y se miran como mucho STACK_SCAN objetos.
local STACK_SCAN = 200
local STACK_TTL = 1000
local stackCache = setmetatable({}, { __mode = "k" })

local function nowMs()
    local ok, t = pcall(getTimestampMs)
    if ok and t then return t end
    return os.time() * 1000
end

local function worstOfStack(data, cfg, now)
    local c = stackCache[data]
    if c and now - c.t < STACK_TTL then return c.item, c.bars end
    local worst, item, bars = nil, nil, nil
    local last = math.min(#data.items, STACK_SCAN + 1)
    for i = 2, last do
        local it = data.items[i]
        local b = it and getBars(it, cfg)
        if b and #b > 0 then
            local r = b[1][1]
            for j = 2, #b do r = math.min(r, b[j][1]) end
            if worst == nil or r < worst then worst = r; item = it; bars = b end
        end
    end
    stackCache[data] = { t = now, item = item, bars = bars }
    return item, bars
end

----------------------------------------------------------------------
-- Dibujo de las filas visibles
----------------------------------------------------------------------
local function drawBars(pane, doDragged)
    if not opt("enabled", true) then return end
    if doDragged and (not pane.dragStarted or pane.dragging == nil) then return end
    local map = pane.items
    local rowH = pane.itemHgt
    if not map or not rowH or rowH <= 0 then return end

    local cfg = { weapons = opt("weapons", true), clothing = opt("clothing", true), soiled = opt("soiled", true), head = opt("head", true), hideFull = opt("hideFull", false), contents = opt("contents", true), stacks = opt("stacks", true), fresh = opt("fresh", true) }
    local scroll = pane:getYScroll()
    local first = math.max(0, math.floor(-scroll / rowH) - 1)
    local last = math.max(first, math.ceil((pane:getHeight() - scroll) / rowH) + 1)
    local iconSize = pane.cleanUIItemIconSize or math.min(rowH - 2, 32)
    local inset = (rowH - iconSize) / 2
    local barH = math.max(4, math.floor(iconSize / 7))
    local now = nowMs()
    local pos = optNum("position", POS_BOTTOM)
    if pos < POS_BOTTOM or pos > POS_RIGHT then pos = POS_BOTTOM end
    local dx, dy = 0, 0
    if doDragged then
        dx = pane:getMouseX() - pane.draggingX
        dy = pane:getMouseY() - pane.draggingY
        first = 0
        last = #map - 1
    end

    for row = first, math.min(last, #map - 1) do
        local selected = pane.selected and pane.selected[row + 1] ~= nil
        if (doDragged and selected) or (not doDragged and not (pane.dragStarted and pane.dragging and selected)) then
            local data = map[row + 1]
            if data and data.type ~= "separator" then
                local grouped = data.items ~= nil
                local item = nil
                local bars = nil
                if grouped then
                    if data.count == nil or data.count <= 2 then
                        item = data.items[1]
                    elseif cfg.stacks then
                        item, bars = worstOfStack(data, cfg, now)
                    end
                else
                    item = data
                end
                if item and item.getTex and item:getTex() then
                    bars = bars or getBars(item, cfg)
                    local n = #bars
                    if n > 0 then
                        local iconX = grouped and (pane.column2 - iconSize - inset) or 26
                        local iconY = row * rowH + pane.headerHgt + inset + dy
                        local x = iconX + dx
                        local y = iconY
                        local span = n * barH - (n - 1)   -- grosor total de las barras juntas
                        if doDragged then pane:suspendStencil() end
                        for i = 1, n do
                            local off = (i - 1) * (barH - 1)
                            if pos == POS_TOP then
                                drawBar(pane, x, y + off, iconSize, barH, bars[i][1], bars[i][2], false)
                            elseif pos == POS_LEFT then
                                drawBar(pane, x + off, y, barH, iconSize, bars[i][1], bars[i][2], true)
                            elseif pos == POS_RIGHT then
                                drawBar(pane, x + iconSize - span + off, y, barH, iconSize, bars[i][1], bars[i][2], true)
                            else
                                drawBar(pane, x, y + iconSize - span + off, iconSize, barH, bars[i][1], bars[i][2], false)
                            end
                        end
                        if doDragged then pane:resumeStencil() end
                    end
                end
            end
        end
    end
end

----------------------------------------------------------------------
-- Enganche a renderdetails()
----------------------------------------------------------------------
local function wrap(paneClass)
    if type(paneClass) ~= "table" then return end
    if rawget(paneClass, "_EOC_done") then return end   -- una sola vez por clase
    local original = paneClass.renderdetails
    if type(original) ~= "function" then return end
    paneClass.renderdetails = function(self, doDragged, ...)
        local r = original(self, doDragged, ...)
        local ok, err = pcall(drawBars, self, doDragged)
        if not ok and not failedOnce then
            failedOnce = true
            print("[" .. MOD .. "] error al dibujar: " .. tostring(err))
        end
        return r
    end
    rawset(paneClass, "_EOC_done", true)
end

local function installAll()
    setupOptions()
    wrap(rawget(_G, "CleanUI_Clean_ISInventoryPane"))
    wrap(rawget(_G, "CleanUI_Vanilla_ISInventoryPane"))
    wrap(rawget(_G, "ISInventoryPane"))
end

local ticks = 0
local function onTick()
    ticks = ticks + 1
    if ticks % 120 == 1 then installAll() end   -- cada ~2 s: cubre cambios de modo de CleanUI
end

Events.OnGameStart.Add(installAll)
Events.OnTick.Add(onTick)
