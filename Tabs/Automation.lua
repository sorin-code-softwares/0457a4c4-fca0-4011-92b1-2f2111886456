-- Sorin Core Hub - Automation & Safety tab
-- General helpers like Anti-AFK, auto-respawn and simple edge safety.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer

local function getRootPart(character)
    character = character or (LocalPlayer and LocalPlayer.Character)
    if not character then
        return nil
    end
    return character:FindFirstChild("HumanoidRootPart")
        or character:FindFirstChild("Torso")
        or character:FindFirstChild("UpperTorso")
end

local function getHumanoid(character)
    character = character or (LocalPlayer and LocalPlayer.Character)
    return character and character:FindFirstChildOfClass("Humanoid")
end

local function isOnGround(humanoid)
    if not humanoid then
        return false
    end

    local state = humanoid:GetState()
    if state == Enum.HumanoidStateType.Running
        or state == Enum.HumanoidStateType.RunningNoPhysics then
        return true
    end

    return humanoid.FloorMaterial and humanoid.FloorMaterial ~= Enum.Material.Air
end

return function(Tab, UI, Window)
    --------------------------------------------------------------------
    -- AFK & Session helpers
    --------------------------------------------------------------------

    Tab:CreateSection("AFK & Session")

    -- Anti-AFK
    local antiAfkEnabled = false
    local antiAfkConn

    local function setAntiAfk(state)
        antiAfkEnabled = state

        if antiAfkConn then
            pcall(function()
                antiAfkConn:Disconnect()
            end)
            antiAfkConn = nil
        end

        if not antiAfkEnabled or not LocalPlayer then
            return
        end

        antiAfkConn = LocalPlayer.Idled:Connect(function()
            if not antiAfkEnabled then
                return
            end

            pcall(function()
                VirtualUser:CaptureController()
                local camera = Workspace.CurrentCamera
                local cf = camera and camera.CFrame or CFrame.new()
                VirtualUser:ClickButton2(Vector2.new(), cf)
            end)
        end)
    end

    Tab:CreateToggle({
        Name = "Anti-AFK",
        Icon = "schedule",
        IconSource = "Material",
        Description = "Simulates small input occasionally to prevent idle kick in many games.",
        CurrentValue = false,
        Callback = function(enabled)
            setAntiAfk(enabled)
            UI:Notify({
                Title = "Anti-AFK",
                Content = enabled and "Anti-AFK enabled." or "Anti-AFK disabled.",
                Type = "info",
            })
        end,
    })

    -- Auto-respawn
    local autoRespawnEnabled = false
    local autoRespawnCharConn
    local autoRespawnDiedConn

    local function disconnectAutoRespawn()
        if autoRespawnCharConn then
            pcall(function()
                autoRespawnCharConn:Disconnect()
            end)
            autoRespawnCharConn = nil
        end
        if autoRespawnDiedConn then
            pcall(function()
                autoRespawnDiedConn:Disconnect()
            end)
            autoRespawnDiedConn = nil
        end
    end

    local function bindHumanoidForRespawn(character)
        if not autoRespawnEnabled then
            return
        end

        if autoRespawnDiedConn then
            pcall(function()
                autoRespawnDiedConn:Disconnect()
            end)
            autoRespawnDiedConn = nil
        end

        local humanoid = getHumanoid(character)
        if not humanoid then
            return
        end

        autoRespawnDiedConn = humanoid.Died:Connect(function()
            if not autoRespawnEnabled then
                return
            end

            task.delay(1, function()
                if autoRespawnEnabled and LocalPlayer and LocalPlayer.Character == character then
                    pcall(function()
                        LocalPlayer:LoadCharacter()
                    end)
                end
            end)
        end)
    end

    local function setAutoRespawn(state)
        autoRespawnEnabled = state
        disconnectAutoRespawn()

        local lp = LocalPlayer
        if not autoRespawnEnabled or not lp then
            return
        end

        if lp.Character then
            bindHumanoidForRespawn(lp.Character)
        end

        autoRespawnCharConn = lp.CharacterAdded:Connect(function(char)
            bindHumanoidForRespawn(char)
        end)
    end

    Tab:CreateToggle({
        Name = "Auto Respawn",
        Icon = "replay",
        IconSource = "Material",
        Description = "Tries to automatically respawn your character shortly after death where possible.",
        CurrentValue = false,
        Callback = function(enabled)
            setAutoRespawn(enabled)
            UI:Notify({
                Title = "Auto Respawn",
                Content = enabled and "Auto respawn enabled." or "Auto respawn disabled.",
                Type = "info",
            })
        end,
    })

    --------------------------------------------------------------------
    -- Edge safety / simple anti-fall
    --------------------------------------------------------------------

    Tab:CreateSection("Edge Safety")

    local edgeSafetyEnabled = false
    local edgeSafetyConn

    local function setEdgeSafety(state)
        edgeSafetyEnabled = state

        if edgeSafetyConn then
            pcall(function()
                edgeSafetyConn:Disconnect()
            end)
            edgeSafetyConn = nil
        end

        if not edgeSafetyEnabled then
            return
        end

        edgeSafetyConn = RunService.Heartbeat:Connect(function()
            local character = LocalPlayer and LocalPlayer.Character
            local humanoid = getHumanoid(character)
            local root = getRootPart(character)
            if not (character and humanoid and root) then
                return
            end

            -- only while normally running on the ground
            if humanoid.PlatformStand or not isOnGround(humanoid) then
                return
            end

            local moveDir = humanoid.MoveDirection
            if moveDir.Magnitude <= 0.01 then
                return
            end
            moveDir = Vector3.new(moveDir.X, 0, moveDir.Z).Unit

            -- probe a bit in front of the player at two distances;
            -- if any of them has no ground underneath, kill horizontal speed.
            local rayParams = RaycastParams.new()
            rayParams.FilterType = Enum.RaycastFilterType.Exclude
            rayParams.FilterDescendantsInstances = { character }

            local origin = root.Position
            local distances = { 3, 6 }
            local unsafe = false

            for _, dist in ipairs(distances) do
                local ahead = origin + moveDir * dist
                local result = Workspace:Raycast(ahead + Vector3.new(0, 3, 0), Vector3.new(0, -20, 0), rayParams)
                if not result then
                    unsafe = true
                    break
                end
            end

            if unsafe then
                local v = root.AssemblyLinearVelocity
                if v.Y <= 0 then
                    root.AssemblyLinearVelocity = Vector3.new(0, v.Y, 0)
                end
            end
        end)
    end

    Tab:CreateToggle({
        Name = "Edge Safety",
        Icon = "safety_check",
        IconSource = "Material",
        Description = "Attempts to stop you right before running off a ledge by cancelling horizontal velocity.",
        CurrentValue = false,
        Callback = function(enabled)
            setEdgeSafety(enabled)
            UI:Notify({
                Title = "Edge Safety",
                Content = enabled and "Edge safety enabled." or "Edge safety disabled.",
                Type = "info",
            })
        end,
    })
end
