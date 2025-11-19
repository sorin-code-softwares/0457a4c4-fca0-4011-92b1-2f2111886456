-- Sorin Core Hub - Movement & Fling tab
-- Walk fling + slide-based movement speed (CFrame-based, less obvious than pure WalkSpeed edits).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

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
    -- Slide Speed (grounded, CFrame-based)
    --------------------------------------------------------------------

    Tab:CreateSection("Slide Speed")

    -- UI range 0..100 mapped to 10..90 studs/second extra speed.
    local SLIDER_MIN, SLIDER_MAX = 0, 100
    local slideStrength = 50

    local function strengthToSpeed(strength)
        local t = math.clamp(strength or 0, SLIDER_MIN, SLIDER_MAX) / SLIDER_MAX
        return 10 + t * 80
    end

    local slideEnabled = false
    local slideConn

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

            local extraSpeed = strengthToSpeed(slideStrength)
            local extra = extraSpeed * dt

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
        Name = "Slide Strength (0–100)",
        Icon = "speed",
        IconSource = "Material",
        Min = SLIDER_MIN,
        Max = SLIDER_MAX,
        Step = 1,
        Default = slideStrength,
        Description = "Controls how strong the slide speed is. Higher values = faster sliding while grounded.",
        Callback = function(value)
            local num = tonumber(value)
            if num then
                slideStrength = math.clamp(num, SLIDER_MIN, SLIDER_MAX)
            end
        end,
    })

    slideSlider:Set({ CurrentValue = slideStrength })

    --------------------------------------------------------------------
    -- Follow Player (MoveTo-based)
    --------------------------------------------------------------------

    Tab:CreateSection("Follow Player")

    local followEnabled = false
    local followConn
    local followTargetName = nil
    local followDropdown
    local followNearest = false
    local followFlyEnabled = false
    local followFlying = false

    local function setCharacterCollide(character, collide)
        if not character then
            return
        end
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                pcall(function()
                    part.CanCollide = collide
                end)
            end
        end
    end

    local function listFollowOptions()
        local result = { "None" }
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                table.insert(result, plr.Name)
            end
        end
        return result
    end

    local function findNearestPlayer()
        local myChar = LocalPlayer and LocalPlayer.Character
        local myRoot = getRootPart(myChar)
        if not myRoot then
            return nil
        end

        local best, bestDist = nil, math.huge
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                local ch = plr.Character
                local root = ch and getRootPart(ch)
                if root then
                    local d = (root.Position - myRoot.Position).Magnitude
                    if d < bestDist then
                        bestDist = d
                        best = plr
                    end
                end
            end
        end
        return best
    end

    local function resolveFollowTarget()
        if followNearest then
            return findNearestPlayer()
        end
        if not followTargetName or followTargetName == "None" then
            return nil
        end
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr.Name == followTargetName then
                return plr
            end
        end
        return nil
    end

    local function stopFollow()
        followEnabled = false
        if followConn then
            pcall(function()
                followConn:Disconnect()
            end)
            followConn = nil
        end

        if followFlying then
            local myChar = LocalPlayer and LocalPlayer.Character
            setCharacterCollide(myChar, true)
            followFlying = false
        end
    end

    local function startFollow()
        if followEnabled then
            return
        end

        if not followNearest and not resolveFollowTarget() then
            UI:Notify({
                Title = "Follow Player",
                Content = "Please select a valid target player first.",
                Type = "warning",
            })
            return
        end

        followEnabled = true

        if followConn then
            pcall(function()
                followConn:Disconnect()
            end)
            followConn = nil
        end

        local flySpeed = 40

        followConn = RunService.Heartbeat:Connect(function(dt)
            if not followEnabled then
                return
            end

            local targetPlayer = resolveFollowTarget()
            if not targetPlayer then
                return
            end

            local targetChar = targetPlayer.Character
            local targetRoot = targetChar and getRootPart(targetChar)

            local myChar = LocalPlayer and LocalPlayer.Character
            local myHum = getHumanoid(myChar)
            local myRoot = getRootPart(myChar)

            if not (targetRoot and myHum and myRoot) then
                return
            end

            local delta = targetRoot.Position - myRoot.Position
            local horizontalDelta = Vector3.new(delta.X, 0, delta.Z)
            local distance = delta.Magnitude
            local verticalDelta = delta.Y
            local onGround = isOnGround(myHum)

            if followFlyEnabled and (not onGround or math.abs(verticalDelta) > 6) then
                -- fly mode
                if not followFlying then
                    followFlying = true
                    setCharacterCollide(myChar, false)
                end

                if distance > 1 then
                    local dir = delta.Unit
                    local step = math.min(distance, flySpeed * dt)
                    local newPos = myRoot.Position + dir * step

                    local lookDir = horizontalDelta.Magnitude > 0 and horizontalDelta.Unit or Vector3.new(0, 0, -1)
                    myRoot.CFrame = CFrame.new(newPos, newPos + lookDir)
                end
            else
                -- ground follow
                if followFlying then
                    followFlying = false
                    setCharacterCollide(myChar, true)
                end

                if distance > 5 and onGround then
                    myHum:MoveTo(targetRoot.Position)
                end
            end
        end)
    end

    local function refreshFollowOptions()
        if not followDropdown then
            return
        end
        followDropdown:Set({
            Options = listFollowOptions(),
            CurrentValue = followTargetName or "None",
        })
    end

    followDropdown = Tab:CreateDropdown({
        Name = "Target Player",
        Icon = "person_search",
        IconSource = "Material",
        Options = listFollowOptions(),
        Default = "None",
        Description = "Choose which player your character should follow.",
        Callback = function(selected)
            followTargetName = selected == "None" and nil or selected
        end,
    })

    Tab:CreateToggle({
        Name = "Enable Follow",
        Icon = "person_pin_circle",
        IconSource = "Material",
        Description = "Automatically walks towards the selected player.",
        CurrentValue = false,
        Callback = function(enabled)
            if enabled then
                startFollow()
                if followEnabled then
                    UI:Notify({
                        Title = "Follow Player",
                        Content = "Follow enabled.",
                        Type = "info",
                    })
                end
            else
                stopFollow()
                UI:Notify({
                    Title = "Follow Player",
                    Content = "Follow disabled.",
                    Type = "info",
                })
            end
        end,
    })

    Tab:CreateToggle({
        Name = "Follow Nearest Player",
        Icon = "radar",
        IconSource = "Material",
        Description = "When enabled, follow always targets the nearest player instead of the selected one.",
        CurrentValue = false,
        Callback = function(enabled)
            followNearest = enabled
            if followEnabled and followNearest then
                UI:Notify({
                    Title = "Follow Player",
                    Content = "Now following the nearest player.",
                    Type = "info",
                })
            end
        end,
    })

    Tab:CreateToggle({
        Name = "Enable Fly Follow",
        Icon = "flight",
        IconSource = "Material",
        Description = "When enabled, follow switches to a simple flying mode with noclip if the target is not reachable on foot (e.g. above you or while you are falling).",
        CurrentValue = false,
        Callback = function(enabled)
            followFlyEnabled = enabled
            if not enabled and followFlying then
                local myChar = LocalPlayer and LocalPlayer.Character
                setCharacterCollide(myChar, true)
                followFlying = false
            end
        end,
    })

    Players.PlayerAdded:Connect(refreshFollowOptions)
    Players.PlayerRemoving:Connect(function(plr)
        if plr.Name == followTargetName then
            followTargetName = nil
        end
        refreshFollowOptions()
    end)
end
