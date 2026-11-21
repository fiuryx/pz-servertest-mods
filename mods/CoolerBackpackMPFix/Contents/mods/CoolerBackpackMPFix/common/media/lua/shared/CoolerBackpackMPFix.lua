-- Cooler Backpack - MP Fix (B42)
-- Cooler Backpack adds its upgrades to zombies in OnZombieDead from a file in media/lua/server.
-- In B42 multiplayer that file also runs on the clients, so the player who kills the zombie
-- rolls the chance a second time on their own game: when it hits, the upgrade appears on the
-- corpse only for that player, the server does not know it, and it can never be taken.
-- The real drop is rolled by the server and reaches everyone with the corpse, so here the
-- client-side spawn of those three upgrades is skipped. Singleplayer and the server are untouched.

if not isClient() then return end

local DROPS = {
    ["CoolerBackpack.tcm_upgrade"] = true,
    ["CoolerBackpack.battery_capacity_upgrade"] = true,
    ["CoolerBackpack.oven_bag_upgrade"] = true,
}

local function patch()
    if not ItemSpawner or ItemSpawner.cbMPFixPatched then return end
    local original = ItemSpawner.spawnItem
    if not original then return end
    local ok = pcall(function()
        ItemSpawner.spawnItem = function(...)
            local fullType = ...
            if type(fullType) == "string" and DROPS[fullType] then
                return nil
            end
            -- Pass the arguments on exactly as received (Java picks the overload by count).
            return original(...)
        end
        ItemSpawner.cbMPFixPatched = true
    end)
    if not ok then
        print("[CoolerBackpackMPFix] could not patch ItemSpawner.spawnItem")
    end
end

patch()
Events.OnGameBoot.Add(patch)
