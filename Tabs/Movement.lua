-- Sorin Core Hub - Movement & Fling tab
-- Walk fling and velocity-based walkspeed (less obvious for anti-cheats).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

local function getRootPart(character)
    if not character then
        return nil
    end
    return character:FindFirstChild("HumanoidRootPart")
        or character:FindFirstChild("Torso")
        or character:FindFirstChild("UpperTorso")
end

return function(Tab, UI, Window)
    Tab:CreateSection("Walk Fling")

    --------------------------------------------------------------------
    -- Walk Fling (velocity desync)
    --------------------------------------------------------------------

    local walkFlingEnabled = false
    local walkFlingLoopRunning = false
    local walkFlingOriginalCollision = {}

    local function applyWalkFlingNoclip(character)
        if not character then
            return
        end
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                if walkFlingOriginalCollision[part] == nil then
                    walkFlingOriginalCollision[part] = part.CanCollide
                end
                part.CanCollide = false
            end
        end
    end

    local function restoreWalkFlingCollision()
        for part, canCollide in pairs(walkFlingOriginalCollision) do
            if typeof(part) == "Instance" and part:IsA("BasePart") then
                part.CanCollide = canCollide
            end
        end
        table.clear(walkFlingOriginalCollision)
    end

    local function neutralizeVelocity()
        local player = LocalPlayer
        local character = player and player.Character
        local root = getRootPart(character)
        if root then
            root.Velocity = Vector3.new(0, 0, 0)
            root.RotVelocity = Vector3.new(0, 0, 0)
        end
    end

    local function stopWalkFling()
        walkFlingEnabled = false
    end

    local function startWalkFling()
        walkFlingEnabled = true

        if walkFlingLoopRunning then
            return
        end
        walkFlingLoopRunning = true

        task.spawn(function()
            local moveOffset = 0.1

            while walkFlingEnabled do
                RunService.Heartbeat:Wait()
                if not walkFlingEnabled then
                    break
                end

                local player = LocalPlayer
                local character = player and player.Character
                local root = getRootPart(character)

                while walkFlingEnabled and not (character and character.Parent and root and root.Parent) do
                    RunService.Heartbeat:Wait()
                    character = player and player.Character
                    root = getRootPart(character)
                end

                if not walkFlingEnabled then
                    break
                end

                applyWalkFlingNoclip(character)

                local vel = root.Velocity
                root.Velocity = vel * 10000 + Vector3.new(0, 10000, 0)

                RunService.RenderStepped:Wait()
                if not walkFlingEnabled then
                    break
                end

                character = player and player.Character
                root = getRootPart(character)
                if character and character.Parent and root and root.Parent then
                    root.Velocity = vel
                end

                RunService.Stepped:Wait()
                if not walkFlingEnabled then
                    break
                end

                character = player and player.Character
                root = getRootPart(character)
                if character and character.Parent and root and root.Parent then
                    root.Velocity = vel + Vector3.new(0, moveOffset, 0)
                    moveOffset = -moveOffset
                end
            end

            restoreWalkFlingCollision()
            neutralizeVelocity()
            walkFlingLoopRunning = false
        end)
    end

    local walkFlingToggle = Tab:CreateToggle({
        Name = "Walk Fling",
        Icon = "directions_run",
        IconSource = "Material",
        Description = "Experimental walk-based fling using velocity desync. High detection risk in strong anti-cheats.",
        CurrentValue = false,
        Callback = function(enabled)
            if enabled then
                startWalkFling()
                UI:Notify({
                    Title = "Walk Fling",
                    Content = "Walk Fling enabled.",
                    Type = "warning",
                })
            else
                stopWalkFling()
                UI:Notify({
                    Title = "Walk Fling",
                    Content = "Walk Fling disabled.",
                    Type = "info",
                })
            end
        end,
    })

    --------------------------------------------------------------------
    -- Velocity-based Walkspeed
    --------------------------------------------------------------------

    Tab:CreateSection("Velocity Walkspeed")

    local velocityWalkEnabled = false
    local velocityLoopRunning = false
    local velocitySpeed = 30

    local function stopVelocityWalk()
        velocityWalkEnabled = false
    end

    local function startVelocityWalk()
        velocityWalkEnabled = true

        if velocityLoopRunning then
            return
        end
        velocityLoopRunning = true

        task.spawn(function()
            while velocityWalkEnabled do
                RunService.Heartbeat:Wait()
                if not velocityWalkEnabled then
                    break
                end

                local player = LocalPlayer
                local character = player and player.Character
                local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
                local root = getRootPart(character)

                if humanoid and root then
                    local moveDir = humanoid.MoveDirection
                    if moveDir.Magnitude > 0 then
                        local baseVel = root.Velocity
                        local extra = moveDir.Unit * velocitySpeed
                        local horizontalBase = Vector3.new(baseVel.X, 0, baseVel.Z)
                        local newHorizontal = horizontalBase + Vector3.new(extra.X, 0, extra.Z)
                        root.Velocity = Vector3.new(newHorizontal.X, baseVel.Y, newHorizontal.Z)
                    end
                end
            end

            velocityLoopRunning = false
        end)
    end

    local velocityToggle = Tab:CreateToggle({
        Name = "Enable Velocity Walkspeed",
        Icon = "run_circle",
        IconSource = "Material",
        Description = "Adds extra speed using Velocity instead of changing Humanoid.WalkSpeed.",
        CurrentValue = false,
        Callback = function(enabled)
            if enabled then
                startVelocityWalk()
                UI:Notify({
                    Title = "Velocity Walkspeed",
                    Content = "Velocity Walkspeed enabled.",
                    Type = "info",
                })
            else
                stopVelocityWalk()
                UI:Notify({
                    Title = "Velocity Walkspeed",
                    Content = "Velocity Walkspeed disabled.",
                    Type = "info",
                })
            end
        end,
    })

    local speedSlider = Tab:CreateSlider({
        Name = "Velocity Speed",
        Icon = "speed",
        IconSource = "Material",
        Min = 0,
        Max = 120,
        Step = 5,
        Default = velocitySpeed,
        Description = "Controls how strong the additional Velocity push is.",
        Callback = function(value)
            velocitySpeed = value
        end,
    })

    -- keep slider and internal state in sync if needed from outside
    speedSlider:Set({ CurrentValue = velocitySpeed })
end

