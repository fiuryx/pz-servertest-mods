-- Simple Status - Extra Needs (B42)
-- Adds bars to Simple Status through its public API (SimpleStatus:addStat):
--   * Need to defecate   (Defecation)
--   * Alcohol withdrawal (Evolving Traits World)
--   * Sleep schedule     (Evolving Traits World, hidden by default)
--   * Hygiene need       (Lifestyle: Hobbies)
--   * Bladder need       (Lifestyle: Hobbies)
-- Each bar is only added when its mod is active.
-- Both only read values those mods already keep on the player; nothing is changed.

require "SimpleStatus"

local okUtils, utils = pcall(require, "ss.utils")
local color = okUtils and utils and utils.color or nil
local getPColor = okUtils and utils and utils.fn and utils.fn.getPColor or nil

local function clamp01(x) return math.max(0, math.min(1, x)) end

local function isActive(id)
    local ok, res = pcall(function()
        local mods = getActivatedMods()
        return mods ~= nil and (mods:contains(id) or mods:contains("\\" .. id))
    end)
    return ok and res == true
end

-- green -> yellow -> orange -> red as the bar fills (same scale Simple Status uses)
local function needColor(p)
    if not color or not getPColor then return nil end
    if p < 0.25 then return color.green
    elseif p < 0.5 then return getPColor(color.green, color.yellow, (p - 0.25) * 4)
    elseif p < 0.75 then return getPColor(color.yellow, color.orange, (p - 0.5) * 4)
    else return getPColor(color.orange, color.red, (p - 0.75) * 4) end
end

local function makeStat(percentFn)
    local stat = { type = "custom", shown = false }  -- hidden by default; enable from the Simple Status menu
    stat.valueFn = function(player) return percentFn(player) end
    stat.percentFn = function(player) return percentFn(player) end
    stat.textFn = function(player) return tostring(math.floor(percentFn(player) * 100 + 0.5)) .. " / 100" end
    stat.colorFn = function(player) return needColor(percentFn(player)) end
    return stat
end

local function register()
    if not SimpleStatus or type(SimpleStatus.addStat) ~= "function" then return end

    -- Defecation stores the need in player modData "Defecate", from 0 up to 0.6
    -- (0.4 = can use the toilet, about 0.57 = may soil yourself).
    if isActive("Defecation") then
        local stat = makeStat(function(player)
            local v = player:getModData()["Defecate"]
            if type(v) ~= "number" then return 0 end
            return clamp01(v / 0.6)
        end)
        stat.icon = "media/ui/ss-Excrementum_Feces.png"
        SimpleStatus:addStat("defecation_need", stat)
    end

    -- Evolving Traits World keeps the Alcoholic withdrawal severity (0-100) in
    -- player modData EvolvingTraitsWorld.AlcoholicSystem, synced by the server.
    if isActive("EvolvingTraitsWorld") then
        local stat = makeStat(function(player)
            local md = player:getModData()
            local etw = md and md.EvolvingTraitsWorld
            local sys = etw and etw.AlcoholicSystem
            local sev = sys and tonumber(sys.WithdrawalSeverity) or 0
            return clamp01(sev / 100)
        end)
        stat.icon = "media/ui/Moodles/AlcoholismWithdrawalMoodle.png"
        SimpleStatus:addStat("alcohol_withdrawal", stat)
    end

    if isActive("EvolvingTraitsWorld") then
        -- ETW sleep health moodle: value 12 - hours away from the preferred
        -- bedtime (0..12). The bar shows how far off schedule you are.
        local stat = makeStat(function(player)
            local md = player:getModData()
            local moodles = md and md.Moodles
            local m = moodles and moodles.SleepHealthMoodle
            local v = m and tonumber(m.Value)
            if not v then return 0 end
            return clamp01((12 - v) / 12)
        end)
        stat.icon = "media/ui/Moodles/SleepHealthMoodle.png"
        SimpleStatus:addStat("sleep_schedule", stat)
    end

    -- Lifestyle: Hobbies keeps its needs (0-100) directly in player modData.
    if isActive("LifestyleHobbies") then
        local hyg = makeStat(function(player)
            local v = player:getModData().hygieneNeed
            if type(v) ~= "number" then return 0 end
            return clamp01(v / 100)
        end)
        hyg.icon = "media/ui/moodles/HygieneBad.png"
        SimpleStatus:addStat("hygiene_need", hyg)

        local bl = makeStat(function(player)
            local v = player:getModData().bathroomNeed
            if type(v) ~= "number" then return 0 end
            return clamp01(v / 100)
        end)
        bl.icon = "media/ui/moodles/BladderNeed.png"
        SimpleStatus:addStat("bladder_need", bl)
    end
end

local ok, err = pcall(register)
if not ok then print("[SimpleStatusExtraNeeds] " .. tostring(err)) end
