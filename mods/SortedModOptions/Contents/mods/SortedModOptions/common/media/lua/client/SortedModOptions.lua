-- Sorted Mod Options (B42)
-- Sorts the "Mods" tab of the Options screen alphabetically by the name each
-- mod shows in the current game language. It only reorders the list the menu
-- reads (PZAPI.ModOptions.Data); option values and saving are untouched.

require "OptionScreens/MainOptions"

SortedModOptions = SortedModOptions or {}
local SMO = SortedModOptions

-- UTF-8 accented letters folded to plain ASCII for the sort key
local FOLD = {
    ["á"]="a", ["à"]="a", ["â"]="a", ["ä"]="a", ["ã"]="a", ["å"]="a",
    ["Á"]="a", ["À"]="a", ["Â"]="a", ["Ä"]="a", ["Ã"]="a", ["Å"]="a",
    ["é"]="e", ["è"]="e", ["ê"]="e", ["ë"]="e", ["É"]="e", ["È"]="e", ["Ê"]="e", ["Ë"]="e",
    ["í"]="i", ["ì"]="i", ["î"]="i", ["ï"]="i", ["Í"]="i", ["Ì"]="i", ["Î"]="i", ["Ï"]="i",
    ["ó"]="o", ["ò"]="o", ["ô"]="o", ["ö"]="o", ["õ"]="o", ["Ó"]="o", ["Ò"]="o", ["Ô"]="o", ["Ö"]="o", ["Õ"]="o",
    ["ú"]="u", ["ù"]="u", ["û"]="u", ["ü"]="u", ["Ú"]="u", ["Ù"]="u", ["Û"]="u", ["Ü"]="u",
    ["ñ"]="n~", ["Ñ"]="n~", ["ç"]="c", ["Ç"]="c",
}

local function displayName(options)
    local name = options and options.name
    if type(name) ~= "string" then return "" end
    local ok, txt = pcall(getText, name)
    if ok and type(txt) == "string" and txt ~= "" then return txt end
    return name
end

function SMO.sortKey(text)
    local s = tostring(text or "")
    -- drop leading tags such as "[B42]", "(B42)" or "{...}" and leading symbols
    local prev
    repeat
        prev = s
        s = s:gsub("^%s+", "")
        s = s:gsub("^%b[]", ""):gsub("^%b()", ""):gsub("^%b{}", "")
        s = s:gsub("^[^%w\128-\255]+", "")
    until s == prev
    for k, v in pairs(FOLD) do
        s = s:gsub(k, v)
    end
    return s:lower()
end

function SMO.sort()
    local data = PZAPI and PZAPI.ModOptions and PZAPI.ModOptions.Data
    if type(data) ~= "table" or #data < 2 then return end
    local entries = {}
    for i, options in ipairs(data) do
        entries[i] = { options = options, key = SMO.sortKey(displayName(options)), index = i }
    end
    table.sort(entries, function(a, b)
        if a.key ~= b.key then return a.key < b.key end
        return a.index < b.index
    end)
    for i, e in ipairs(entries) do
        data[i] = e.options
    end
end

function SMO.install()
    if not MainOptions or type(MainOptions.addModOptionsPanel) ~= "function" then return end
    if MainOptions.addModOptionsPanel == SMO.wrapped then return end
    local original = MainOptions.addModOptionsPanel
    SMO.wrapped = function(self, ...)
        local ok, err = pcall(SMO.sort)
        if not ok and not SMO.loggedError then
            SMO.loggedError = true
            print("[SortedModOptions] " .. tostring(err))
        end
        return original(self, ...)
    end
    MainOptions.addModOptionsPanel = SMO.wrapped
end

SMO.install()
Events.OnGameBoot.Add(SMO.install)
Events.OnMainMenuEnter.Add(SMO.install)
Events.OnGameStart.Add(SMO.install)
