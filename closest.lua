local players = game.Players
local LocalPlayer = game.Players.LocalPlayer
function GetClosestPlayer()
    local Character = game.Players.LocalPlayer.Character
    local Root = Character and Character:FindFirstChild("HumanoidRootPart")

    if not Root then
        return nil
    end

    local Closest
    local Distance = math.huge

    for _, Player in ipairs(Players:GetPlayers()) do
        if Player ~= LocalPlayer then
            local Char = Player.Character
            local HRP = Char and Char:FindFirstChild("HumanoidRootPart")

            if HRP then
                local Dist = (Root.Position - HRP.Position).Magnitude

                if Dist < Distance then
                    Distance = Dist
                    Closest = Player
                end
            end
        end
    end

    return Closest, Distance
end

return GetClosestPlayer
