local actor = game.Players.LocalPlayer
if game.RunService:IsPC() then
    actor.PCMovementMode = Enum.DevPCMovementMode.KeyboardMouse 
    -- actor.TouchMovementMode = Enum.DevTouchMovementMode.Scriptable
else
    actor.TouchMovementMode = Enum.DevTouchMovementMode.Thumbstick
end
print("a2222222", actor, actor.TouchMovementMode, actor.PCMovementMode)
