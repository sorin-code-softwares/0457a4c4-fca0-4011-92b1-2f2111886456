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

