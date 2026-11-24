-- Animal Cages: nothing can be dragged into a cage or carrier by hand. The animal is put in by the
-- mod's own timed action (the game itself also refuses live animals in any container but the floor).
AcceptItemFunction = AcceptItemFunction or {}
function AcceptItemFunction.AnimalCage(container, item)
    return false
end
