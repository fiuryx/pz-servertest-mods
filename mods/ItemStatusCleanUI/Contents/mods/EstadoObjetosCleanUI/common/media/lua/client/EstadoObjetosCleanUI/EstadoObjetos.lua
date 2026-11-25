-- Barras de estado de objetos para el inventario de CleanUI (B42)
-- v1.2: barra de frescura de la comida perecedera.
-- v1.3: barras en la ropa activadas por defecto y opcion de posicion
--       (abajo, arriba, vertical a la izquierda o a la derecha del icono).
--       Casilla propia para el estado de armas y herramientas.
-- v1.4: ropa manchada por el mod Defecation: barra marron (solo si ese mod esta activo).
-- v1.5: las pilas cerradas ya no se recorren enteras en cada fotograma: el resultado se
--       guarda un segundo por fila y se miran como mucho 200 objetos por pila.
-- v1.6: iconos de estado en la esquina del icono: sangre, suciedad, mojado y manchado
--       por el mod Defecation (sustituye a la barra marron de la v1.4). Cada uno con su opcion.
-- v1.7: al pasar el raton por una barra o un icono sale un recuadro con el estado y su
--       porcentaje (y los dias que le quedan a la comida). Opcion para quitarlo.
-- v1.8: barra de capacidad en los botones de la columna de contenedores (inventario,
--       mochilas, muebles, maleteros...). Verde con sitio, roja llena. Con su opcion.
-- v1.9: barra de lectura en los libros de habilidad (paginas leidas por el jugador).
--       Solo sale si se ha empezado a leer; verde cuando esta terminado.
-- Mod propio para el servidor de FiuRy. Solo dibuja: no cambia objetos ni guarda nada.
-- Se engancha al final de renderdetails() de los dos modos de inventario de CleanUI
-- (y del vanilla si se usa sin CleanUI), sin sustituir a otros mods que ya lo envuelvan.

require "ISUI/ISUIElement"

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
    o:addTickBox("head", getText("UI_EOC_Head"), true, getText("UI_EOC_Head_tooltip"))
    o:addTickBox("contents", getText("UI_EOC_Contents"), true, getText("UI_EOC_Contents_tooltip"))
    o:addTickBox("containers", getText("UI_EOC_Containers"), true, getText("UI_EOC_Containers_tooltip"))
    o:addTickBox("books", getText("UI_EOC_Books"), true, getText("UI_EOC_Books_tooltip"))
    o:addTickBox("fresh", getText("UI_EOC_Fresh"), true, getText("UI_EOC_Fresh_tooltip"))
    o:addTickBox("stacks", getText("UI_EOC_Stacks"), true, getText("UI_EOC_Stacks_tooltip"))
    o:addTickBox("hideFull", getText("UI_EOC_HideFull"), false, getText("UI_EOC_HideFull_tooltip"))
    o:addTickBox("blood", getText("UI_EOC_Blood"), true, getText("UI_EOC_Blood_tooltip"))
    o:addTickBox("dirt", getText("UI_EOC_Dirt"), true, getText("UI_EOC_Dirt_tooltip"))
    o:addTickBox("wet", getText("UI_EOC_Wet"), true, getText("UI_EOC_Wet_tooltip"))
    o:addTickBox("soiled", getText("UI_EOC_Soiled"), true, getText("UI_EOC_Soiled_tooltip"))
    o:addTickBox("tooltips", getText("UI_EOC_Tooltips"), false, getText("UI_EOC_Tooltips_tooltip"))
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
-- Libros con paginas (los de habilidad): paginas leidas por el jugador local.
-- El juego lo guarda en el personaje (getAlreadyReadPages(tipo)) y en el libro.
local function getReadProgress(item)
    if not instanceof(item, "Literature") then return nil end
    local pages = call(item, "getNumberOfPages")
    if not pages or pages <= 0 then return nil end
    local read = call(item, "getAlreadyReadPages") or 0
    local player = getSpecificPlayer(0)
    if player then
        local ok, p = pcall(function() return player:getAlreadyReadPages(item:getFullType()) end)
        if ok and p and p > read then read = p end
    end
    if read <= 0 then return nil end       -- sin empezar: no se muestra
    if read >= pages then return nil end   -- ya leido: tampoco (solo se ve mientras se lee)
    return { read / pages, "read", { read, pages } }
end

local function getBars(item, cfg)
    local bars = {}
    local isWeapon = instanceof(item, "HandWeapon")
    local isClothing = instanceof(item, "Clothing")
    local showCond = (isWeapon and cfg.weapons) or (isClothing and cfg.clothing)
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
        if not (cfg.hideFull and (ratio == nil or ratio >= 1) and (head == nil or head >= 1)) then
            if ratio ~= nil then table.insert(bars, { ratio, "cond" }) end
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
    if cfg.books then
        local rp = getReadProgress(item)
        if rp then table.insert(bars, rp) end
    end
    return bars
end

----------------------------------------------------------------------
-- Iconos de estado: sangre, suciedad, mojado, manchado (Defecation)
----------------------------------------------------------------------
-- Devuelve { blood = 0..1, dirt = 0..1, wet = 0..1, soiled = 1 } (solo los que tiene).
-- El valor es la intensidad: decide la opacidad del icono.
--  * Sangre: ropa (media 0-100, el juego la llama "ensangrentada" desde 25), armas y
--    herramientas (0-1) y bolsas que se llevan puestas. hasBlood() cubre los tres.
--  * Suciedad: ropa y bolsas (0-100, "sucia" desde 15).
--  * Mojado: ropa (0-100) y objetos que se mojan, como libros o papel (si/no).
local ICON_MIN_ALPHA = 0.45
local function getFlags(item, cfg)
    -- f._pct guarda el valor real (0-100) para el recuadro de informacion
    local f = nil
    local function set(kind, v, pct)
        f = f or { _pct = {} }
        f[kind] = clamp(v)
        f._pct[kind] = pct
    end
    if cfg.blood and call(item, "hasBlood") == true then
        if instanceof(item, "Clothing") then
            local b = call(item, "getBloodlevel") or 25
            set("blood", b / 25, b)
        else
            local b = call(item, "getBloodLevel") or 0.5
            set("blood", b / 0.5, b * 100)
        end
    end
    if cfg.dirt and call(item, "hasDirt") == true then
        local d = call(item, "getDirtiness") or 15
        set("dirt", d / 15, d)
    end
    if cfg.wet then
        local w = instanceof(item, "Clothing") and call(item, "getWetness") or nil
        if w and w > 0 then
            set("wet", w / 50, w)
        elseif call(item, "isWet") == true then
            set("wet", 1, nil)
        end
    end
    if cfg.soiled and instanceof(item, "Clothing") and isSoiled(item) then
        set("soiled", 1, nil)
    end
    return f
end

local function mergeFlags(a, b)
    if not b then return a end
    a = a or { _pct = {} }
    for k, v in pairs(b) do
        if k ~= "_pct" and (a[k] == nil or v > a[k]) then a[k] = v end
    end
    for k, v in pairs(b._pct) do
        if a._pct[k] == nil or v > a._pct[k] then a._pct[k] = v end
    end
    return a
end

local ICON_ORDER = { "blood", "dirt", "wet", "soiled" }
local ICON_FILES = {
    blood = "media/ui/EstadoObjetosCleanUI/eoc_blood.png",
    dirt = "media/ui/EstadoObjetosCleanUI/eoc_dirt.png",
    wet = "media/ui/EstadoObjetosCleanUI/eoc_wet.png",
    soiled = "media/ui/EstadoObjetosCleanUI/eoc_soiled.png",
}
local iconTex = {}
local function texFor(kind)
    local t = iconTex[kind]
    if t == nil then
        t = getTexture(ICON_FILES[kind]) or false
        iconTex[kind] = t
    end
    return t or nil
end

local function colorFor(r, kind)
    if kind == "read" then
        if r >= 1.0 then return 0.20, 0.80, 0.20 end    -- verde: terminado
        return 0.60, 0.45, 0.95                          -- morado: leyendo
    end
    if kind == "capacity" then
        if r >= 1.0 then return 0.90, 0.15, 0.15 end    -- rojo: lleno
        if r >= 0.85 then return 0.95, 0.55, 0.10 end   -- naranja
        if r >= 0.60 then return 0.90, 0.85, 0.15 end   -- amarillo
        return 0.20, 0.80, 0.20                          -- verde: con sitio
    end
    if kind == "fresh" then return 0.20, 0.80, 0.20 end   -- verde: fresca
    if kind == "stale" then return 0.95, 0.55, 0.10 end   -- naranja: pasada
    if kind == "rot" then return 0.90, 0.15, 0.15 end     -- rojo: podrida
    if kind == "frozen" then return 0.55, 0.85, 1.00 end  -- azul claro: congelada
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
    if c and now - c.t < STACK_TTL then return c.item, c.bars, c.flags end
    local worst, item, bars, flags = nil, nil, nil, nil
    local last = math.min(#data.items, STACK_SCAN + 1)
    for i = 2, last do
        local it = data.items[i]
        if it then flags = mergeFlags(flags, getFlags(it, cfg)) end
        local b = cfg.stacks and it and getBars(it, cfg)
        if b and #b > 0 then
            local r = b[1][1]
            for j = 2, #b do r = math.min(r, b[j][1]) end
            if worst == nil or r < worst then worst = r; item = it; bars = b end
        end
    end
    stackCache[data] = { t = now, item = item, bars = bars, flags = flags }
    return item, bars, flags
end

----------------------------------------------------------------------
-- Recuadro de informacion al pasar el raton por una barra o un icono
----------------------------------------------------------------------
-- Mientras se dibujan las filas se mira si el raton esta encima de alguna barra o
-- icono; si lo esta se guarda que hay debajo y un elemento de UI aparte (por encima
-- de todo, de tamano cero) dibuja el recuadro junto al raton.
local hover = nil       -- { info, t }
local probe = nil       -- { mx, my } posicion del raton en la fila, solo si hay que mirar

local function hit(x, y, w, h, info)
    if probe and probe.mx >= x and probe.mx < x + w and probe.my >= y and probe.my < y + h then
        hover = { info = info, t = nowMs() }
    end
end

local function pctText(v)
    return tostring(math.floor(v + 0.5)) .. "%"
end

local function daysText(d)
    local txt = string.format("%.1f", math.max(0, d))
    local sep = getTextOrNull("UI_EOC_Tip_DecimalSep")
    if sep and sep ~= "." then txt = txt:gsub("%.", sep) end
    return txt
end

local function numText(v)
    local txt = string.format("%.1f", v)
    local sep = getTextOrNull("UI_EOC_Tip_DecimalSep")
    if sep and sep ~= "." then txt = txt:gsub("%.", sep) end
    return txt
end

local KIND_TEXT = {
    cond = "UI_EOC_Tip_Condition", head = "UI_EOC_Tip_Head", fill = "UI_EOC_Tip_Contents",
    fresh = "UI_EOC_Tip_Fresh", stale = "UI_EOC_Tip_Stale", rot = "UI_EOC_Tip_Rotten",
    frozen = "UI_EOC_Tip_Frozen", blood = "UI_EOC_Tip_Blood", dirt = "UI_EOC_Tip_Dirt",
    wet = "UI_EOC_Tip_Wet", soiled = "UI_EOC_Tip_Soiled",
}

-- Lineas de texto del recuadro (se calculan solo cuando se va a dibujar)
local function tipLines(info)
    local lines = {}
    local item = info.item
    if info.stack and item then
        local ok, name = pcall(function() return item:getDisplayName() end)
        if ok and name then table.insert(lines, getText("UI_EOC_Tip_Stack", name)) end
    end
    local kind = info.kind
    if kind == "read" and info.extra then
        table.insert(lines, getText("UI_EOC_Tip_Read") .. ": " .. getText("UI_EOC_Tip_Pages", tostring(info.extra[1]), tostring(info.extra[2]))
            .. " (" .. pctText(info.ratio * 100) .. ")")
        return lines
    end
    if kind == "capacity" then
        if info.name then table.insert(lines, info.name) end
        table.insert(lines, getText("UI_EOC_Tip_Capacity") .. ": " .. numText(info.w) .. " / " .. numText(info.cap)
            .. " (" .. pctText(info.w / info.cap * 100) .. ")")
        return lines
    end
    local label = getText(KIND_TEXT[kind] or "UI_EOC_Tip_Condition")
    if kind == "cond" or kind == "head" or kind == "fill" then
        table.insert(lines, label .. ": " .. pctText(info.ratio * 100))
    elseif kind == "fresh" or kind == "stale" or kind == "rot" or kind == "frozen" then
        table.insert(lines, label)
        if kind ~= "rot" then
            table.insert(lines, getText("UI_EOC_Tip_ShelfLife") .. ": " .. pctText(info.ratio * 100))
            local age = item and call(item, "getAge")
            local off = item and call(item, "getOffAge")
            local offMax = item and call(item, "getOffAgeMax")
            if age and off and off > 0 and age < off and off < offMax then
                table.insert(lines, getText("UI_EOC_Tip_StaleIn", daysText(off - age)))
            end
            if age and offMax and age < offMax then
                table.insert(lines, getText("UI_EOC_Tip_RotsIn", daysText(offMax - age)))
            end
        end
    elseif kind == "soiled" then
        table.insert(lines, label)
        table.insert(lines, getText("UI_EOC_Tip_SoiledHint"))
    elseif kind == "wet" and info.pct == nil then
        table.insert(lines, getText("UI_EOC_Tip_WetYes"))
    else
        table.insert(lines, label .. ": " .. pctText(info.pct or 0))
    end
    return lines
end

local Tip = ISUIElement:derive("EstadoObjetosCleanUITip")
function Tip:new()
    local o = ISUIElement.new(self, 0, 0, 0, 0)
    o.anchorLeft = true
    o.anchorTop = true
    return o
end
function Tip:render()
    local h = hover
    if not h or nowMs() - h.t > 150 then return end
    local ok, lines = pcall(tipLines, h.info)
    if not ok or not lines or #lines == 0 then return end
    local font = UIFont.Small
    local tm = getTextManager()
    local lh = tm:getFontHeight(font)
    local w = 0
    for _, l in ipairs(lines) do w = math.max(w, tm:MeasureStringX(font, l)) end
    local pad = 4
    local bw, bh = w + pad * 2, #lines * lh + pad * 2
    -- arriba a la izquierda del raton, para no tapar el tooltip del objeto
    local mx, my = getMouseX(), getMouseY()
    local x = mx - bw - 12
    local y = my - bh - 8
    if x < 0 then x = mx + 16 end
    if y < 0 then y = my + 20 end
    -- coordenadas relativas a este elemento
    x = x - self:getAbsoluteX()
    y = y - self:getAbsoluteY()
    self:drawRect(x, y, bw, bh, 0.85, 0.05, 0.05, 0.05)
    self:drawRectBorder(x, y, bw, bh, 0.9, 0.5, 0.5, 0.5)
    for i, l in ipairs(lines) do
        self:drawText(l, x + pad, y + pad + (i - 1) * lh, 1, 1, 1, 1, font)
    end
end

local tipElement = nil
local function ensureTip()
    if tipElement then return end
    local t = Tip:new()
    t:initialise()
    t:addToUIManager()
    t:setAlwaysOnTop(true)
    tipElement = t
end

-- Iconos en fila en una esquina del icono del objeto, lejos de las barras:
-- arriba a la derecha; abajo a la derecha si las barras van arriba; arriba a la
-- izquierda si las barras van a la derecha.
local function drawFlags(pane, x, y, iconSize, pos, flags, item, stack)
    local s = math.max(8, math.floor(iconSize * 0.4))
    local n = 0
    for _, kind in ipairs(ICON_ORDER) do if flags[kind] then n = n + 1 end end
    if n == 0 then return end
    -- que quepan dentro del ancho del icono (se solapan un poco si hay muchos)
    local step = s - 1
    if n > 1 then step = math.min(step, math.floor((iconSize - s) / (n - 1))) end
    local fromLeft = (pos == POS_RIGHT)
    local cy = (pos == POS_TOP) and (y + iconSize - s) or y
    local i = 0
    for _, kind in ipairs(ICON_ORDER) do
        local v = flags[kind]
        if v then
            local tex = texFor(kind)
            if tex then
                local cx = fromLeft and (x + i * step) or (x + iconSize - s - i * step)
                local a = ICON_MIN_ALPHA + (1 - ICON_MIN_ALPHA) * clamp(v)
                pane:drawTextureScaled(tex, cx, cy, s, s, a, 1, 1, 1)
                if probe then
                    hit(cx, cy, s, s, { kind = kind, pct = flags._pct and flags._pct[kind], item = item, stack = stack })
                end
                i = i + 1
            end
        end
    end
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

    local cfg = { weapons = opt("weapons", true), clothing = opt("clothing", true), soiled = opt("soiled", true), head = opt("head", true), hideFull = opt("hideFull", false), contents = opt("contents", true), stacks = opt("stacks", true), fresh = opt("fresh", true), blood = opt("blood", true), dirt = opt("dirt", true), wet = opt("wet", true), books = opt("books", true) }
    local scroll = pane:getYScroll()
    local first = math.max(0, math.floor(-scroll / rowH) - 1)
    local last = math.max(first, math.ceil((pane:getHeight() - scroll) / rowH) + 1)
    local iconSize = pane.cleanUIItemIconSize or math.min(rowH - 2, 32)
    local inset = (rowH - iconSize) / 2
    local barH = math.max(4, math.floor(iconSize / 7))
    local now = nowMs()
    local pos = optNum("position", POS_BOTTOM)
    if pos < POS_BOTTOM or pos > POS_RIGHT then pos = POS_BOTTOM end
    probe = nil
    if not doDragged and opt("tooltips", false) and pane:isMouseOver() then
        probe = { mx = pane:getMouseX(), my = pane:getMouseY() - scroll }
        ensureTip()
    end
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
                local flags = nil
                local stacked = false
                if grouped then
                    if data.count == nil or data.count <= 2 then
                        item = data.items[1]
                    else
                        stacked = true
                        local sItem, sBars, sFlags = worstOfStack(data, cfg, now)
                        flags = sFlags
                        if cfg.stacks then item, bars = sItem, sBars end
                        if not item then item = data.items[1] end
                    end
                else
                    item = data
                end
                if item and item.getTex and item:getTex() then
                    if stacked then
                        bars = bars or {}
                    else
                        bars = getBars(item, cfg)
                        flags = getFlags(item, cfg)
                    end
                    local n = #bars
                    local iconX = grouped and (pane.column2 - iconSize - inset) or 26
                    local iconY = row * rowH + pane.headerHgt + inset + dy
                    if flags then
                        if doDragged then pane:suspendStencil() end
                        drawFlags(pane, iconX + dx, iconY, iconSize, pos, flags, item, stacked)
                        if doDragged then pane:resumeStencil() end
                    end
                    if n > 0 then
                        local x = iconX + dx
                        local y = iconY
                        local span = n * barH - (n - 1)   -- grosor total de las barras juntas
                        if doDragged then pane:suspendStencil() end
                        for i = 1, n do
                            local off = (i - 1) * (barH - 1)
                            local bx, by, bw, bh, vert
                            if pos == POS_TOP then
                                bx, by, bw, bh, vert = x, y + off, iconSize, barH, false
                            elseif pos == POS_LEFT then
                                bx, by, bw, bh, vert = x + off, y, barH, iconSize, true
                            elseif pos == POS_RIGHT then
                                bx, by, bw, bh, vert = x + iconSize - span + off, y, barH, iconSize, true
                            else
                                bx, by, bw, bh, vert = x, y + iconSize - span + off, iconSize, barH, false
                            end
                            drawBar(pane, bx, by, bw, bh, bars[i][1], bars[i][2], vert)
                            if probe then
                                hit(bx, by, bw, bh, { kind = bars[i][2], ratio = bars[i][1], extra = bars[i][3], item = item, stack = stacked })
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
-- Barra de capacidad en los botones de la columna de contenedores
----------------------------------------------------------------------
-- Cada boton de la columna (inventario, mochilas, muebles, maleteros...) guarda su
-- contenedor en button.inventory y su capacidad en button.capacity. El peso se lee
-- como mucho cada 300 ms por boton. El suelo no lleva barra.
local CAP_TTL = 300

local function drawContainerBar(button)
    if not opt("enabled", true) or not opt("containers", true) then return end
    local inv = button.inventory
    if not inv then return end
    local okType, ctype = pcall(function() return inv:getType() end)
    if okType and ctype == "floor" then return end
    local now = nowMs()
    if not button._EOC_t or now - button._EOC_t > CAP_TTL or button._EOC_inv ~= inv then
        button._EOC_t = now
        button._EOC_inv = inv
        local okW, w = pcall(function() return inv:getCapacityWeight() end)
        local cap = button.capacity
        if not cap or cap <= 0 then
            local okC, c = pcall(function() return inv:getEffectiveCapacity(getSpecificPlayer(0)) end)
            cap = okC and c or nil
        end
        button._EOC_w = okW and w or nil
        button._EOC_cap = cap
    end
    local w, cap = button._EOC_w, button._EOC_cap
    if not w or not cap or cap <= 0 then return end
    local ratio = w / cap

    local bs = math.min(button:getWidth(), button:getHeight())
    local barH = math.max(3, math.floor(bs / 9))
    local pos = optNum("position", POS_BOTTOM)
    local x, y, bw, bh, vert
    if pos == POS_TOP then
        x, y, bw, bh, vert = 2, 1, bs - 4, barH, false
    elseif pos == POS_LEFT then
        x, y, bw, bh, vert = 1, 2, barH, bs - 4, true
    elseif pos == POS_RIGHT then
        x, y, bw, bh, vert = bs - barH - 1, 2, barH, bs - 4, true
    else
        x, y, bw, bh, vert = 2, bs - barH - 1, bs - 4, barH, false
    end
    -- el relleno no pasa del borde; el color rojo indica que esta lleno o pasado
    local fill = math.min(1, ratio)
    drawBar(button, x, y, bw, bh, fill, "capacity", vert)

    if opt("tooltips", false) and button:isMouseOver() then
        local mx, my = button:getMouseX(), button:getMouseY()
        if mx >= x and mx < x + bw and my >= y and my < y + bh then
            ensureTip()
            hover = { info = { kind = "capacity", w = w, cap = cap, name = button.name }, t = now }
        end
    end
end

local function wrapButton(button)
    if not button or button._EOC_render then return end
    local original = button.render
    button._EOC_render = true
    button.render = function(self, ...)
        if original then original(self, ...) end
        local ok, err = pcall(drawContainerBar, self)
        if not ok and not failedOnce then
            failedOnce = true
            print("[" .. MOD .. "] error en barra de contenedor: " .. tostring(err))
        end
    end
end

local function wrapPage(pageClass)
    if type(pageClass) ~= "table" then return end
    if rawget(pageClass, "_EOC_btn_done") then return end
    local original = rawget(pageClass, "addContainerButton") or pageClass.addContainerButton
    if type(original) ~= "function" then return end
    pageClass.addContainerButton = function(self, ...)
        local button = original(self, ...)
        pcall(wrapButton, button)
        return button
    end
    rawset(pageClass, "_EOC_btn_done", true)
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
        probe = nil
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
    wrapPage(rawget(_G, "CleanUI_Vanilla_ISInventoryPage"))
    wrapPage(rawget(_G, "ISInventoryPage"))
end

local ticks = 0
local function onTick()
    ticks = ticks + 1
    if ticks % 120 == 1 then installAll() end   -- cada ~2 s: cubre cambios de modo de CleanUI
end

Events.OnGameStart.Add(installAll)
Events.OnTick.Add(onTick)
