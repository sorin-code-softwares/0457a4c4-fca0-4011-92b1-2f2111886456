-- Sorin Core Hub - Interaction tab
-- Player-centric helpers like looking at nearby players and saving spots.

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

local function findNearestPlayer(maxDistance)
    maxDistance = maxDistance or 120

    local myChar = LocalPlayer and LocalPlayer.Character
    local myRoot = getRootPart(myChar)
    if not myRoot then
        return nil
    end

    local best, bestDist = nil, maxDistance
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

return function(Tab, UI, Window)
    --------------------------------------------------------------------
    -- Player focus helpers
    --------------------------------------------------------------------

    Tab:CreateSection("Player Focus")

    -- look-at helper (rotation only)
    local lookAtNearestEnabled = false
    local lookAtNearestConn

    local function setLookAtNearest(state)
        lookAtNearestEnabled = state

        if lookAtNearestConn then
            pcall(function()
                lookAtNearestConn:Disconnect()
            end)
            lookAtNearestConn = nil
        end

        if not lookAtNearestEnabled then
            return
        end

        lookAtNearestConn = RunService.RenderStepped:Connect(function()
            local myChar = LocalPlayer and LocalPlayer.Character
            local myRoot = getRootPart(myChar)
            if not myRoot then
                return
            end

            local target = findNearestPlayer(120)
            if not target then
                return
            end

            local targetRoot = target.Character and getRootPart(target.Character)
            if not targetRoot then
                return
            end

            local myPos = myRoot.Position
            local targetPos = targetRoot.Position

            -- only rotate horizontally so you don't tilt up/down
            local lookPos = Vector3.new(targetPos.X, myPos.Y, targetPos.Z)
            myRoot.CFrame = CFrame.new(myPos, lookPos)
        end)
    end

    Tab:CreateToggle({
        Name = "Look at Nearest Player",
        Icon = "visibility",
        IconSource = "Material",
        Description = "Continuously rotates your character to face the nearest player within range.",
        CurrentValue = false,
        Callback = function(enabled)
            setLookAtNearest(enabled)
            UI:Notify({
                Title = "Player Focus",
                Content = enabled and "Now looking at nearest player." or "Stopped auto-looking at players.",
                Type = "info",
            })
        end,
    })

    -- simple orbit around nearest player (CFrame based, IY-style)
    local orbitEnabled = false
    local orbitConnMove
    local orbitConnFace
    local orbitTarget
    local orbitSpeed = 120 -- degrees per second
    local orbitRadius = 6
    local orbitAngle = 0

    local function stopOrbit()
        orbitEnabled = false
        if orbitConnMove then
            pcall(function()
                orbitConnMove:Disconnect()
            end)
            orbitConnMove = nil
        end
        if orbitConnFace then
            pcall(function()
                orbitConnFace:Disconnect()
            end)
            orbitConnFace = nil
        end
        orbitTarget = nil
        orbitAngle = 0
    end

    local function startOrbitNearest()
        stopOrbit()

        local target = findNearestPlayer(120)
        local myChar = LocalPlayer and LocalPlayer.Character
        local myRoot = getRootPart(myChar)
        local myHum = getHumanoid(myChar)

        if not (target and target.Character and getRootPart(target.Character) and myRoot and myHum) then
            UI:Notify({
                Title = "Orbit Player",
                Content = "No valid target found for orbit.",
                Type = "warning",
            })
            return
        end

        orbitEnabled = true
        orbitTarget = target
        orbitAngle = 0

        orbitConnMove = RunService.Heartbeat:Connect(function(dt)
            if not orbitEnabled then
                return
            end

            local char = LocalPlayer and LocalPlayer.Character
            local root = getRootPart(char)
            local hum = getHumanoid(char)
            local tgtChar = orbitTarget and orbitTarget.Character
            local tgtRoot = tgtChar and getRootPart(tgtChar)

            if not (root and hum and tgtRoot) then
                stopOrbit()
                return
            end

            orbitAngle = orbitAngle + math.rad(orbitSpeed) * dt

            local center = tgtRoot.Position
            local offset = CFrame.new(orbitRadius, 0, 0)
            local rot = CFrame.Angles(0, orbitAngle, 0)

            root.CFrame = CFrame.new(center) * rot * offset
        end)

        orbitConnFace = RunService.RenderStepped:Connect(function()
            if not orbitEnabled then
                return
            end

            local char = LocalPlayer and LocalPlayer.Character
            local root = getRootPart(char)
            local tgtChar = orbitTarget and orbitTarget.Character
            local tgtRoot = tgtChar and getRootPart(tgtChar)

            if not (root and tgtRoot) then
                return
            end

            root.CFrame = CFrame.new(root.Position, tgtRoot.Position)
        end)

        UI:Notify({
            Title = "Orbit Player",
            Content = ("Started orbiting %s."):format(orbitTarget.Name),
            Type = "info",
        })
    end

    Tab:CreateToggle({
        Name = "Orbit Nearest Player",
        Icon = "sync",
        IconSource = "Material",
        Description = "CFrame-based orbit around the nearest player. Combine with Noclip for smoother paths.",
        CurrentValue = false,
        Callback = function(enabled)
            if enabled then
                startOrbitNearest()
                if not orbitEnabled then
                    -- startOrbitNearest failed (no target)
                    UI:Notify({
                        Title = "Orbit Player",
                        Content = "Orbit could not be started.",
                        Type = "warning",
                    })
                end
            else
                stopOrbit()
                UI:Notify({
                    Title = "Orbit Player",
                    Content = "Stopped orbiting player.",
                    Type = "info",
                })
            end
        end,
    })

    --------------------------------------------------------------------
    -- Saved spots (simple bookmarks)
    --------------------------------------------------------------------

    Tab:CreateSection("Saved Spots")

    local savedSpots = {}

    local function saveSpot(slot)
        local character = LocalPlayer and LocalPlayer.Character
        local root = getRootPart(character)
        if not root then
            UI:Notify({
                Title = "Saved Spot",
                Content = "No character/root found to save.",
                Type = "warning",
            })
            return
        end

        savedSpots[slot] = root.CFrame
        UI:Notify({
            Title = "Saved Spot",
            Content = ("Saved current position to slot %d."):format(slot),
            Type = "info",
        })
    end

    local function teleportToSpot(slot)
        local cf = savedSpots[slot]
        if not cf then
            UI:Notify({
                Title = "Saved Spot",
                Content = ("No saved position in slot %d yet."):format(slot),
                Type = "warning",
            })
            return
        end

        local character = LocalPlayer and LocalPlayer.Character
        local root = getRootPart(character)
        if not root then
            UI:Notify({
                Title = "Saved Spot",
                Content = "No character/root found for teleport.",
                Type = "warning",
            })
            return
        end

        root.CFrame = cf
    end

    for slot = 1, 2 do
        Tab:CreateButton({
            Name = ("Save Spot %d"):format(slot),
            Icon = "bookmark_add",
            IconSource = "Material",
            Description = ("Save your current position into slot %d."):format(slot),
            Callback = function()
                saveSpot(slot)
            end,
        })

        Tab:CreateButton({
            Name = ("Teleport to Spot %d"):format(slot),
            Icon = "bookmark",
            IconSource = "Material",
            Description = ("Teleport your character to the saved position in slot %d."):format(slot),
            Callback = function()
                teleportToSpot(slot)
            end,
        })
    end
end
