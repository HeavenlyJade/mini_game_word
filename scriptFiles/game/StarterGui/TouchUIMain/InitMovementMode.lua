local actor = game.Players.LocalPlayer
if game.RunService:IsPC() then
    actor.TouchMovementMode = Enum.DevTouchMovementMode.Scriptable
else
    actor.TouchMovementMode = Enum.DevTouchMovementMode.Thumbstick
end
