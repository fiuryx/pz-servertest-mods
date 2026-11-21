-- Clean Ashes - MP Fix (B42)
-- Clean Ashes overrides ISClearAshes:perform() on the client and removes the ashes object
-- locally (transmitRemoveItemFromSquare + getObjects():remove). In B42 the vanilla action
-- already removes the ashes in ISClearAshes:complete(), which runs on the server in
-- multiplayer (and locally in singleplayer), so the client-side removal is redundant and
-- can desync the square. This restores the vanilla perform(); Clean Ashes keeps its cursor,
-- tool tags and animations.
require "TimedActions/ISBaseTimedAction"
require "TimedActions/ISClearAshes"

local function patch()
    if not ISClearAshes then return end
    ISClearAshes.perform = function(self)
        -- needed to remove from queue / start next. The removal happens in complete().
        ISBaseTimedAction.perform(self)
    end
end

patch()
Events.OnGameStart.Add(patch)
