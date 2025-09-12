local function Bypass()
    if game:GetService("ReplicatedStorage"):FindFirstChild("xReplicatedStorage") and game:GetService("ReplicatedStorage").xReplicatedStorage.Eventos:FindFirstChild("UI") then
        game:GetService("ReplicatedStorage").xReplicatedStorage.Eventos.UI:Destroy()
    end
end

local function Fly()
    if not game:GetService("Players").LocalPlayer.Character or not game:GetService("Players").LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end
    Instance.new("BodyVelocity").MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    Instance.new("BodyVelocity").Velocity = Vector3.new(0, 0, 0)
    Instance.new("BodyVelocity").Parent = game:GetService("Players").LocalPlayer.Character.HumanoidRootPart
    game:GetService("RunService").RenderStepped:Connect(function()
        if not game:GetService("Players").LocalPlayer.Character or not game:GetService("Players").LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end
        Instance.new("BodyVelocity").Velocity = Vector3.new(0, 0, 0) +
            (game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.W) and game.Workspace.CurrentCamera.CFrame.LookVector * 50 or Vector3.new(0, 0, 0)) +
            (game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.S) and -game.Workspace.CurrentCamera.CFrame.LookVector * 50 or Vector3.new(0, 0, 0)) +
            (game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.D) and game.Workspace.CurrentCamera.CFrame.RightVector * 50 or Vector3.new(0, 0, 0)) +
            (game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.A) and -game.Workspace.CurrentCamera.CFrame.RightVector * 50 or Vector3.new(0, 0, 0)) +
            (game:GetService("UserInputService").TouchEnabled and
             (function()
                for _, input in pairs(game:GetService("UserInputService"):GetTouchInput()) do
                    return (game.Workspace.CurrentCamera.CFrame.LookVector * (input.Position.Y - game.Workspace.CurrentCamera.ViewportSize.Y / 2).Unit * 50) +
                           (game.Workspace.CurrentCamera.CFrame.RightVector * (input.Position.X - game.Workspace.CurrentCamera.ViewportSize.X / 2).Unit * 50)
                end
                return Vector3.new(0, 0, 0)
             end)() or Vector3.new(0, 0, 0))
    end)
end

local function NoClip()
    if not game:GetService("Players").LocalPlayer.Character then return end
    game:GetService("RunService").Stepped:Connect(function()
        if not game:GetService("Players").LocalPlayer.Character then return end
        for _, part in pairs(game:GetService("Players").LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end)
end

return {Bypass = Bypass, Fly = Fly, NoClip = NoClip}
