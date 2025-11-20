-- Sorin Core Hub - Movement & Fling tab
-- Walk fling + slide-based movement speed (CFrame-based, less obvious than pure WalkSpeed edits).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

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

    -- Global movement flags shared across helpers
    local noclipEnabled = false

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
        Description = "Walk-based fling. High detection risk in strong anti-cheats.",
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
    local smartSprintEnabled = false

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

            -- If smart sprint is enabled, only apply slide
            -- when LeftShift is held.
            if smartSprintEnabled and not UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                return
            end

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
        Description = "Speed boost; uses CFrame sliding.",
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

    Tab:CreateToggle({
        Name = "Smart Sprint (Shift)",
        Icon = "bolt",
        IconSource = "Material",
        Description = "Only applies slide speed boost while holding LeftShift.",
        CurrentValue = false,
        Callback = function(enabled)
            smartSprintEnabled = enabled
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
        Description = "Higher values = faster sliding.",
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
    local followBodyVelocity
    local followWanderOffset
    local followNextWanderTime = 0
    local followOrbit = false
    local followOrbitAngle = 0
    local followOrbitSpeed = 2.25
    local followEmoteFriendly = false
    local emoteLockEnabled = false
    local emoteLockConn
    local emoteLockTrack
    local emoteLockSpeed = 12

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

        local myChar = LocalPlayer and LocalPlayer.Character
        local myHum = getHumanoid(myChar)

        -- always restore seating ability when follow stops
        if myHum then
            pcall(function()
                myHum:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
            end)
        end

        if followFlying then
            if not noclipEnabled then
                setCharacterCollide(myChar, true)
                resetCharacterPhysics(myChar)
            end
            followFlying = false
        end

        if followBodyVelocity then
            pcall(function()
                followBodyVelocity:Destroy()
            end)
            followBodyVelocity = nil
        end
    end

    local function startFollow()
        if followEnabled then
            return
        end

        followEnabled = true

        if followConn then
            pcall(function()
                followConn:Disconnect()
            end)
            followConn = nil
        end

        local flySpeed = 60

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

            -- prevent being locked into seats while follow is active
            if myHum.Sit then
                myHum.Sit = false
            end
            pcall(function()
                myHum:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
            end)

            local delta = targetRoot.Position - myRoot.Position
            local horizontalDelta = Vector3.new(delta.X, 0, delta.Z)
            local distance = delta.Magnitude
            local verticalDelta = delta.Y
            local onGround = isOnGround(myHum)

            if followFlyEnabled and (not onGround or math.abs(verticalDelta) > 6) then
                -- fly mode (BodyVelocity-based)
                if not followFlying then
                    followFlying = true
                    if followBodyVelocity then
                        pcall(function()
                            followBodyVelocity:Destroy()
                        end)
                        followBodyVelocity = nil
                    end

                    followBodyVelocity = Instance.new("BodyVelocity")
                    followBodyVelocity.MaxForce = Vector3.new(1e5, 1e5, 1e5)
                    followBodyVelocity.Velocity = Vector3.new(0, 0, 0)
                    followBodyVelocity.Parent = myRoot
                end

                -- ensure noclip is enforced every frame while flying,
                -- in case another feature temporarily re-enabled collisions
                setCharacterCollide(myChar, false)

                if distance > 1 then
                    local dir = delta.Unit
                    -- keep a consistent flying velocity towards the target
                    followBodyVelocity.Velocity = dir * flySpeed

                    -- keep character facing roughly towards the horizontal direction of travel
                    local lookDir = horizontalDelta.Magnitude > 0 and horizontalDelta.Unit or Vector3.new(0, 0, -1)
                    myRoot.CFrame = CFrame.new(myRoot.Position, myRoot.Position + lookDir)
                end
            else
                -- ground follow
                if followFlying then
                    followFlying = false
                    if not noclipEnabled then
                        setCharacterCollide(myChar, true)
                        resetCharacterPhysics(myChar)
                    end

                    if followBodyVelocity then
                        pcall(function()
                            followBodyVelocity:Destroy()
                        end)
                        followBodyVelocity = nil
                    end
                end

                if onGround then
                    if followEmoteFriendly then
                        -- emote-friendly: avoid MoveTo to keep animations/emotes playing
                        local desired = 8
                        local slack = 3
                        local horizMag = horizontalDelta.Magnitude

                        if distance > desired + slack then
                            if horizMag > 0.05 then
                                myHum:Move(horizontalDelta.Unit, true)
                            else
                                -- if we have no clear dir, small MoveTo nudge
                                myHum:MoveTo(targetRoot.Position)
                            end
                        elseif distance < desired - slack and horizMag > 0.05 then
                            myHum:Move(-horizontalDelta.Unit, true)
                        else
                            myHum:Move(Vector3.new(), true)
                        end
                        return
                    end

                    if distance > 10 then
                        followWanderOffset = nil
                        myHum:MoveTo(targetRoot.Position)
                    else
                        -- pick a small orbit/wander radius with a minimum so we don't spin in place
                        local radius = math.clamp(distance, 5, 10)
                        if followOrbit then
                            if radius < 5 then
                                radius = 5
                            end
                            -- smooth continuous orbit
                            followOrbitAngle = (followOrbitAngle + (followOrbitSpeed * dt)) % (math.pi * 2)
                            local offset = Vector3.new(math.cos(followOrbitAngle), 0, math.sin(followOrbitAngle)) *
                            radius
                            local orbitPos = targetRoot.Position + offset
                            local dir = orbitPos - myRoot.Position
                            local dirMag = dir.Magnitude

                            if dirMag > 0.2 then
                                myHum:MoveTo(orbitPos)
                            else
                                myHum:Move(Vector3.new(), true)
                            end
                        else
                            -- random wander around the target
                            local now = tick()
                            if not followWanderOffset or now >= followNextWanderTime then
                                local angle = math.random() * math.pi * 2
                                followWanderOffset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius
                                followNextWanderTime = now + math.random(2, 4)
                            end

                            local wanderPos = targetRoot.Position + followWanderOffset
                            myHum:MoveTo(wanderPos)
                        end
                    end
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
        Name = "Orbit Player",
        Icon = "sync",
        IconSource = "Material",
        Description = "Circle around the follow target instead of standing still when close.",
        CurrentValue = false,
        Callback = function(enabled)
            followOrbit = enabled
        end,
    })

    Tab:CreateToggle({
        Name = "Emote-Friendly Follow",
        Icon = "accessibility_new",
        IconSource = "Material",
        Description = "Use Move instead of MoveTo on ground to keep emotes/animations running.",
        CurrentValue = false,
        Callback = function(enabled)
            followEmoteFriendly = enabled
        end,
    })

    Tab:CreateToggle({
        Name = "Enable Fly Follow",
        Icon = "flight",
        IconSource = "Material",
        Description =
        "When enabled, follow switches to a simple flying mode with noclip if the target is not reachable on foot.",
        CurrentValue = false,
        Callback = function(enabled)
            followFlyEnabled = enabled
            if not enabled and followFlying then
                local myChar = LocalPlayer and LocalPlayer.Character
                if not noclipEnabled then
                    setCharacterCollide(myChar, true)
                    resetCharacterPhysics(myChar)
                end
                followFlying = false
            end
        end,
    })

    --------------------------------------------------------------------
    -- Emote Lock (keep emote playing while moving with assisted motion)
    --------------------------------------------------------------------

    local function getAnimator(humanoid)
        if not humanoid then
            return nil
        end
        return humanoid:FindFirstChildOfClass("Animator")
            or humanoid:WaitForChild("Animator", 1)
    end

    local function stopEmoteLock()
        emoteLockEnabled = false
        if emoteLockConn then
            pcall(function()
                emoteLockConn:Disconnect()
            end)
            emoteLockConn = nil
        end
        if emoteLockTrack then
            pcall(function()
                emoteLockTrack:Stop(0.15)
                emoteLockTrack:Destroy()
            end)
            emoteLockTrack = nil
        end
    end

    local function startEmoteLock()
        stopEmoteLock()

        local character = LocalPlayer and LocalPlayer.Character
        local humanoid = getHumanoid(character)
        local root = getRootPart(character)
        if not (character and humanoid and root) then
            UI:Notify({
                Title = "Emote Lock",
                Content = "Character or humanoid not ready.",
                Type = "warning",
            })
            return
        end

        local animator = getAnimator(humanoid)
        if not animator then
            UI:Notify({
                Title = "Emote Lock",
                Content = "Animator not available.",
                Type = "warning",
            })
            return
        end

        -- Try to reuse currently playing track; if none, abort
        local track
        local playing = humanoid:GetPlayingAnimationTracks()
        track = playing[1]
        if track then
            track.Looped = true
        end

        if not track then
            UI:Notify({
                Title = "Emote Lock",
                Content = "No emote track found or loaded.",
                Type = "warning",
            })
            return
        end

        emoteLockTrack = track
        emoteLockTrack:Play(0.1, 1, 1)
        emoteLockEnabled = true

        emoteLockConn = RunService.RenderStepped:Connect(function(dt)
            if not emoteLockEnabled then
                return
            end

            local character = LocalPlayer and LocalPlayer.Character
            local humanoid = getHumanoid(character)
            local root = getRootPart(character)
            local camera = Workspace.CurrentCamera
            if not (humanoid and root and camera and emoteLockTrack and emoteLockTrack.IsPlaying) then
                stopEmoteLock()
                return
            end

            -- keep default movement idle so emote isn't overridden
            humanoid:Move(Vector3.new(), true)

            local moveDir = Vector3.new(0, 0, 0)
            local camCF = camera.CFrame
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                moveDir += camCF.LookVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                moveDir -= camCF.LookVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                moveDir -= camCF.RightVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                moveDir += camCF.RightVector
            end

            moveDir = Vector3.new(moveDir.X, 0, moveDir.Z)
            local mag = moveDir.Magnitude
            if mag > 0.01 then
                moveDir = moveDir.Unit
                local step = emoteLockSpeed * dt
                local targetPos = root.Position + (moveDir * step)
                root.CFrame = CFrame.new(targetPos, targetPos + camCF.LookVector)
            end
        end)
    end

    Tab:CreateSection("Emote Lock")

    local emoteSpeedSlider = Tab:CreateSlider({
        Name = "Emote Move Speed",
        Icon = "speed",
        IconSource = "Material",
        Min = 4,
        Max = 30,
        Step = 1,
        Default = emoteLockSpeed,
        Description = "Speed while moving with emote lock.",
        Callback = function(value)
            local num = tonumber(value)
            if num then
                emoteLockSpeed = math.clamp(num, 4, 30)
            end
        end,
    })
    emoteSpeedSlider:Set({ CurrentValue = emoteLockSpeed })

    Tab:CreateToggle({
        Name = "Enable Emote Lock",
        Icon = "emoji_emotions",
        IconSource = "Material",
        Description = "Keeps emote playing while you move (uses CFrame sliding).",
        CurrentValue = false,
        Callback = function(enabled)
            if enabled then
                startEmoteLock()
                if emoteLockEnabled then
                    UI:Notify({
                        Title = "Emote Lock",
                        Content = "Emote lock enabled.",
                        Type = "info",
                    })
                end
            else
                stopEmoteLock()
                UI:Notify({
                    Title = "Emote Lock",
                    Content = "Emote lock disabled.",
                    Type = "info",
                })
            end
        end,
    })

    -- stop emote lock if character respawns
    LocalPlayer.CharacterAdded:Connect(stopEmoteLock)

    Players.PlayerAdded:Connect(refreshFollowOptions)
    Players.PlayerRemoving:Connect(function(plr)
        if plr.Name == followTargetName then
            followTargetName = nil
        end
        refreshFollowOptions()
    end)

    --------------------------------------------------------------------
    -- Extra movement utilities (infinite jump, manual fly)
    --------------------------------------------------------------------

    Tab:CreateSection("Extra Movement")

    -- Standalone noclip
    local noclipConn

    -- No snap-to-ground: only reset physics state; avoids any vertical "pushing"

    local function resetCharacterPhysics(character)
        character = character or (LocalPlayer and LocalPlayer.Character)
        local humanoid = getHumanoid(character)
        local root = getRootPart(character)
        if humanoid then
            humanoid.Sit = false
            humanoid.PlatformStand = false
            humanoid.AutoRotate = true
            humanoid:ChangeState(Enum.HumanoidStateType.Running)
            humanoid:Move(Vector3.new(), true)
        end

        if root then
            root.Anchored = false
            root.Velocity = Vector3.new(0, 0, 0)
            root.RotVelocity = Vector3.new(0, 0, 0)
            root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        end
    end

    local function setNoclip(state)
        noclipEnabled = state

        if noclipConn then
            pcall(function()
                noclipConn:Disconnect()
            end)
            noclipConn = nil
        end

        local character = LocalPlayer and LocalPlayer.Character

        if not noclipEnabled then
            -- do not touch physics; just restore collisions if we're not needed elsewhere
            if character and not followFlying and not flyEnabled then
                setCharacterCollide(character, true)
                resetCharacterPhysics(character)
            end
            return
        end

        -- always unanchor when entering noclip to avoid staying stuck
        if character then
            local root = getRootPart(character)
            if root then
                root.Anchored = false
            end
        end

        -- use Stepped so collisions are disabled before physics each frame
        noclipConn = RunService.Stepped:Connect(function()
            local ch = LocalPlayer and LocalPlayer.Character
            if ch then
                for _, part in ipairs(ch:GetDescendants()) do
                    if part:IsA("BasePart") then
                        pcall(function()
                            part.CanCollide = false
                        end)
                    end
                end
            end
        end)
    end

    Tab:CreateToggle({
        Name = "Noclip",
        Icon = "grid_off",
        IconSource = "Material",
        Description = "Disables collisions for your character.",
        CurrentValue = false,
        Callback = function(enabled)
            setNoclip(enabled)
            UI:Notify({
                Title = "Noclip",
                Content = enabled and "Noclip enabled." or "Noclip disabled.",
                Type = "info",
            })
        end,
    })

    -- Infinite jump
    local infiniteJumpEnabled = false
    local infiniteJumpConn

    local function setInfiniteJump(state)
        infiniteJumpEnabled = state

        if infiniteJumpConn then
            pcall(function()
                infiniteJumpConn:Disconnect()
            end)
            infiniteJumpConn = nil
        end

        if not infiniteJumpEnabled then
            return
        end

        infiniteJumpConn = UserInputService.JumpRequest:Connect(function()
            local character = LocalPlayer and LocalPlayer.Character
            local humanoid = getHumanoid(character)
            if humanoid then
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                humanoid.Jump = true
            end
        end)
    end

    Tab:CreateToggle({
        Name = "Infinite Jump",
        Icon = "arrow_upward",
        IconSource = "Material",
        Description = "Allows you to jump again while mid-air.",
        CurrentValue = false,
        Callback = function(enabled)
            setInfiniteJump(enabled)
            UI:Notify({
                Title = "Infinite Jump",
                Content = enabled and "Infinite jump enabled." or "Infinite jump disabled.",
                Type = "info",
            })
        end,
    })

    -- Manual fly
    local flyEnabled = false
    local flyConn
    local flyBodyVelocity
    local flyBodyGyro
    local flySpeed = 50

    local function stopFly()
        flyEnabled = false

        if flyConn then
            pcall(function()
                flyConn:Disconnect()
            end)
            flyConn = nil
        end

        if flyBodyVelocity then
            pcall(function()
                flyBodyVelocity:Destroy()
            end)
            flyBodyVelocity = nil
        end

        if flyBodyGyro then
            pcall(function()
                flyBodyGyro:Destroy()
            end)
            flyBodyGyro = nil
        end

        local character = LocalPlayer and LocalPlayer.Character
        local humanoid = getHumanoid(character)
        if humanoid then
            humanoid.PlatformStand = false
        end
        if not noclipEnabled and not followFlying then
            setCharacterCollide(character, true)
            resetCharacterPhysics(character)
        end
    end

    local function startFly()
        if flyEnabled then
            return
        end

        local character = LocalPlayer and LocalPlayer.Character
        local humanoid = getHumanoid(character)
        local root = getRootPart(character)
        local camera = Workspace.CurrentCamera

        if not (humanoid and root and camera) then
            UI:Notify({
                Title = "Fly",
                Content = "Character, Humanoid or RootPart not available.",
                Type = "warning",
            })
            return
        end

        flyEnabled = true
        humanoid.PlatformStand = true
        setCharacterCollide(character, false)

        flyBodyVelocity = Instance.new("BodyVelocity")
        flyBodyVelocity.MaxForce = Vector3.new(1e5, 1e5, 1e5)
        flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
        flyBodyVelocity.Parent = root

        flyBodyGyro = Instance.new("BodyGyro")
        flyBodyGyro.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
        flyBodyGyro.CFrame = camera.CFrame
        flyBodyGyro.P = 1e4
        flyBodyGyro.Parent = root

        if flyConn then
            pcall(function()
                flyConn:Disconnect()
            end)
            flyConn = nil
        end

        flyConn = RunService.RenderStepped:Connect(function(dt)
            if not flyEnabled then
                return
            end

            local character = LocalPlayer and LocalPlayer.Character
            local root = getRootPart(character)
            local humanoid = getHumanoid(character)
            local camera = Workspace.CurrentCamera

            if not (root and humanoid and camera and flyBodyVelocity and flyBodyGyro) then
                stopFly()
                return
            end

            local moveDir = Vector3.new(0, 0, 0)
            local camCF = camera.CFrame

            if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                moveDir = moveDir + camCF.LookVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                moveDir = moveDir - camCF.LookVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                moveDir = moveDir - camCF.RightVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                moveDir = moveDir + camCF.RightVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                moveDir = moveDir + Vector3.new(0, 1, 0)
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.Q) then
                moveDir = moveDir + Vector3.new(0, -1, 0)
            end

            if moveDir.Magnitude > 0 then
                moveDir = moveDir.Unit
            end

            flyBodyVelocity.Velocity = moveDir * flySpeed
            flyBodyGyro.CFrame = CFrame.new(root.Position, root.Position + camCF.LookVector)
        end)
    end

    Tab:CreateToggle({
        Name = "Fly",
        Icon = "flight_takeoff",
        IconSource = "Material",
        Description = "Manual fly mode (WASD + Space / Ctrl).",
        CurrentValue = false,
        Callback = function(enabled)
            if enabled then
                startFly()
                if flyEnabled then
                    UI:Notify({
                        Title = "Fly",
                        Content = "Fly enabled (use WASD + Space/Ctrl).",
                        Type = "info",
                    })
                end
            else
                stopFly()
                UI:Notify({
                    Title = "Fly",
                    Content = "Fly disabled.",
                    Type = "info",
                })
            end
        end,
    })

    -- Fly speed slider
    local flySpeedSlider = Tab:CreateSlider({
        Name = "Fly Speed",
        Icon = "speed",
        IconSource = "Material",
        Min = 10,
        Max = 200,
        Step = 5,
        Default = flySpeed,
        Description = "Controls how fast manual fly moves.",
        Callback = function(value)
            local num = tonumber(value)
            if num then
                flySpeed = math.clamp(num, 10, 200)
            end
        end,
    })

    flySpeedSlider:Set({ CurrentValue = flySpeed })

    -- Anti-fall velocity clamp
    local antiFallEnabled = false
    local antiFallConn

    local function setAntiFall(state)
        antiFallEnabled = state

        if antiFallConn then
            pcall(function()
                antiFallConn:Disconnect()
            end)
            antiFallConn = nil
        end

        if not antiFallEnabled then
            return
        end

        antiFallConn = RunService.Heartbeat:Connect(function()
            local character = LocalPlayer and LocalPlayer.Character
            local humanoid = getHumanoid(character)
            local root = getRootPart(character)
            if not (character and humanoid and root) then
                return
            end

            -- skip while in custom fly modes to avoid fighting with them
            if flyEnabled or followFlying then
                return
            end

            -- only while actually in the air
            if humanoid.FloorMaterial ~= Enum.Material.Air then
                return
            end

            local vy = root.AssemblyLinearVelocity.Y
            if vy < -40 then    -- MinFallSpeed
                local cap = -65 -- CapDownSpeed
                local newVy = math.max(vy, cap)
                if newVy ~= vy then
                    local v = root.AssemblyLinearVelocity
                    local blendedY = vy + (newVy - vy) * 0.35 -- BlendFactor
                    root.AssemblyLinearVelocity = Vector3.new(v.X, blendedY, v.Z)
                end
            end
        end)
    end

    Tab:CreateToggle({
        Name = "Anti-Fall Velocity Clamp",
        Icon = "vertical_align_bottom",
        IconSource = "Material",
        Description = "Attempts to limit extreme falling speed by clamping vertical velocity near the ground.",
        CurrentValue = false,
        Callback = function(enabled)
            setAntiFall(enabled)
            UI:Notify({
                Title = "Anti-Fall",
                Content = enabled and "Anti-fall velocity clamp enabled." or "Anti-fall velocity clamp disabled.",
                Type = "info",
            })
        end,
    })
end
