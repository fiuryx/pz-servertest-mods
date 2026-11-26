-- Server Item Name Fix (B42) - server part
-- A dedicated server loads its translations before the mods are active, so every
-- text the server builds from a mod key stays as the raw key: skill level-up notes
-- ("IGUI_perks_Dancing +1"), XP notes, item names made by the server, etc.
-- Once the server has started we reload the translations, which now include the
-- active mods, and Translator.loadFiles() also refreshes the perk names.
if not isServer() then return end

local TAG = "[ServerItemNameFix] "

local function findLanguage(code)
    local list = Translator.getAvailableLanguage()
    if not list then return nil end
    code = string.upper(code)
    for i = 0, list:size() - 1 do
        local lang = list:get(i)
        if lang and string.upper(tostring(lang:name())) == code then return lang end
    end
    return nil
end

local function reload()
    local wanted = SandboxVars.ServerItemNameFix and SandboxVars.ServerItemNameFix.Language
    if type(wanted) == "string" then wanted = wanted:gsub("%s", "") end
    if wanted and wanted ~= "" then
        local lang = findLanguage(wanted)
        if lang then
            Translator.setLanguage(lang)
        else
            print(TAG .. "unknown language code: " .. tostring(wanted))
        end
    end
    local ok, err = pcall(function() Translator.loadFiles() end)
    local lang = Translator.getLanguage()
    print(TAG .. "translations reloaded: " .. tostring(ok) .. (ok and "" or (" " .. tostring(err)))
        .. ", language " .. tostring(lang and lang:name())
        .. ", test " .. tostring(getText("IGUI_perks_Dancing")))
end

Events.OnServerStarted.Add(reload)
