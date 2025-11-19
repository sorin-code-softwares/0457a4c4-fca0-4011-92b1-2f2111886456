-- Sorin Core Hub - Movement & Fling tab
-- Walk fling + slide-based movement speed (more subtle than pure WalkSpeed edits).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

local function getRootPart(character)
    if not character then
        return nil
    end
    return character:FindFirstChild("HumanoidRootPart")
        or character:FindFirstChild("Torso")
        or character:FindFirstChild("UpperTorso")
end

local function getHumanoid(character)
    character = character or LocalPlayer.Character
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
    -- Walk Fling (velocity desync)
    --------------------------------------------------------------------

    Tab:CreateSection("Walk Fling")

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
        local character = LocalPlayer and LocalPlayer.Character
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

                local character = LocalPlayer and LocalPlayer.Character
                local root = getRootPart(character)

                while walkFlingEnabled and not (character and character.Parent and root and root.Parent) do
                    RunService.Heartbeat:Wait()
                    character = LocalPlayer and LocalPlayer.Character
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

                character = LocalPlayer and LocalPlayer.Character
                root = getRootPart(character)
                if character and character.Parent and root and root.Parent then
                    root.Velocity = vel
                end

                RunService.Stepped:Wait()
                if not walkFlingEnabled then
                    break
                end

                character = LocalPlayer and LocalPlayer.Character
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

    Tab:CreateToggle({
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
    -- Slide Speed (grounded, MoveDirection-based, speed-capped)
    --------------------------------------------------------------------

    Tab:CreateSection("Slide Speed")

    local UI_MIN, UI_MAX = 0.1, 1.0        -- what the user sees
    local MUL_MIN, MUL_MAX = 0.8, 8.0      -- internal effective multiplier range

    local function remap(x, a1, a2, b1, b2)
        if a2 == a1 then
            return b1
        end
        return b1 + ((x - a1) * (b2 - b1) / (a2 - a1))
    end

    local slideEnabled = false
    local slideConn
    local slideUiFactor = 1.0

    local function getEffectiveMultiplier()
        local t = math.clamp(slideUiFactor, UI_MIN, UI_MAX)
        return math.clamp(remap(t, UI_MIN, UI_MAX, MUL_MIN, MUL_MAX), MUL_MIN, MUL_MAX)
    end

    local function stopSlide()
        slideEnabled = false
        if slideConn then
            pcall(function()
                slideConn:Disconnect()
            end)
            slideConn = nil
        end
    end

    local function startSlide()
        if slideEnabled then
            return
        end
        slideEnabled = true

        stopSlide()

        local rayParams = RaycastParams.new()
        rayParams.FilterType = Enum.RaycastFilterType.Exclude

        slideConn = RunService.RenderStepped:Connect(function(dt)
            if not slideEnabled then
                return
            end

            local character = LocalPlayer and LocalPlayer.Character
            local humanoid = getHumanoid(character)
            local root = getRootPart(character)
            if not (humanoid and root and character) then
                return
            end

            if humanoid.Sit or not isOnGround(humanoid) then
                return
            end

            local moveDir = humanoid.MoveDirection
            if moveDir.Magnitude <= 0.01 then
                return
            end
            moveDir = Vector3.new(moveDir.X, 0, moveDir.Z).Unit

            local base = (humanoid.WalkSpeed and humanoid.WalkSpeed > 0) and humanoid.WalkSpeed or 16
            local multiplier = getEffectiveMultiplier()
            local target = base * multiplier

            local vel = root.AssemblyLinearVelocity
            local curHorz = Vector3.new(vel.X, 0, vel.Z).Magnitude
            if curHorz >= target - 0.05 then
                return
            end

            local deficit = target - curHorz
            local maxExtra = math.clamp(target * 0.12 * dt, 0, 10.0 * dt)
            local extra = math.clamp(deficit * 0.6 * dt, 0, maxExtra)
            if extra <= 0 then
                return
            end

            rayParams.FilterDescendantsInstances = { character }
            local origin = root.Position
            local direction = moveDir * (extra + 0.2)
            local hit = Workspace:Raycast(origin, direction, rayParams)
            if hit and hit.Instance and hit.Instance.CanCollide ~= false then
                return
            end

            root.CFrame = root.CFrame + (moveDir * extra)
        end)
    end

    Tab:CreateToggle({
        Name = "Slide Speed (grounded)",
        Icon = "run_circle",
        IconSource = "Material",
        Description = "Ground-based speed boost; uses CFrame sliding instead of editing Humanoid.WalkSpeed.",
        CurrentValue = false,
        Callback = function(enabled)
            if enabled then
                startSlide()
                UI:Notify({
                    Title = "Slide Speed",
                    Content = "Slide Speed enabled.",
                    Type = "info",
                })
            else
                stopSlide()
                UI:Notify({
                    Title = "Slide Speed",
                    Content = "Slide Speed disabled.",
                    Type = "info",
                })
            end
        end,
    })

    local slideSlider = Tab:CreateSlider({
        Name = "Slide Multiplier (0.1–1.0)",
        Icon = "speed",
        IconSource = "Material",
        Min = UI_MIN,
        Max = UI_MAX,
        Step = 0.05,
        Default = slideUiFactor,
        Description = "Controls how strong the slide speed multiplier is. Low = subtle, high = aggressive.",
        Callback = function(value)
            local num = tonumber(value)
            if num then
                slideUiFactor = math.clamp(num, UI_MIN, UI_MAX)
            end
        end,
    })

    slideSlider:Set({ CurrentValue = slideUiFactor })
end
