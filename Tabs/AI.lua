-- Sorin Core Hub - AI User tab (lightweight local responder + loose follow)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

local function listPlayers()
    local result = { "None" }
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            table.insert(result, plr.Name)
        end
    end
    table.sort(result)
    return result
end

return function(Tab, UI)
    Tab:CreateSection("Chat Responder")

    local aiRespondEnabled = false
    local aiFollowByChat = true
    local chatConns = {}
    local followDropdown

    local function sendChat(message)
        local chatEvents = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents", true)
        if not chatEvents then
            return
        end
        local say = chatEvents:FindFirstChild("SayMessageRequest", true)
        if not say then
            return
        end
        pcall(function()
            say:FireServer(message, "All")
        end)
    end

    local cannedReplies = {
        { "hello", "hi", "hey", reply = { "Hi there!", "Heya.", "Yo.", "Hello!" } },
        { "where", "u at", reply = { "Right here.", "On my way.", "Close by." } },
        { "follow", reply = { "I'll trail you.", "Got it, following.", "Okay, moving behind you." } },
        { "stop", "stay", reply = { "Alright, holding position.", "Stopping here.", "I'll wait." } },
    }

    local function pickReply(msg)
        local lower = msg:lower()
        for _, entry in ipairs(cannedReplies) do
            local replyList = entry.reply
            for i = 1, #entry - 1 do
                local needle = entry[i]
                if lower:find(needle, 1, true) then
                    return replyList[math.random(1, #replyList)], needle
                end
            end
        end
        return nil
    end

    -- Loose follow (AI tab keeps it gentler than Movement tab)
    local aiFollowEnabled = false
    local aiFollowNearest = false
    local aiFollowDistance = 11
    local aiFollowTargetName = nil
    local aiFollowConn

    local function refreshDropdown()
        if followDropdown then
            followDropdown:Set({
                Options = listPlayers(),
                CurrentValue = aiFollowTargetName or "None",
            })
        end
    end

    local function resolveTarget()
        if aiFollowNearest then
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

        if not aiFollowTargetName or aiFollowTargetName == "None" then
            return nil
        end
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr.Name == aiFollowTargetName then
                return plr
            end
        end
        return nil
    end

    local function stopAiFollow()
        aiFollowEnabled = false
        if aiFollowConn then
            pcall(function()
                aiFollowConn:Disconnect()
            end)
            aiFollowConn = nil
        end
    end

    local function startAiFollow()
        if aiFollowConn then
            pcall(function()
                aiFollowConn:Disconnect()
            end)
            aiFollowConn = nil
        end

        aiFollowEnabled = true

        aiFollowConn = RunService.Heartbeat:Connect(function()
            if not aiFollowEnabled then
                return
            end

            local target = resolveTarget()
            local targetChar = target and target.Character
            local targetRoot = targetChar and getRootPart(targetChar)
            local myChar = LocalPlayer and LocalPlayer.Character
            local myHum = getHumanoid(myChar)
            local myRoot = getRootPart(myChar)

            if not (targetRoot and myHum and myRoot) then
                return
            end

            local delta = targetRoot.Position - myRoot.Position
            local horiz = Vector3.new(delta.X, 0, delta.Z)
            local distance = horiz.Magnitude
            local desired = aiFollowDistance
            local slack = 3

            if distance > desired + slack then
                local dir = horiz.Unit
                local targetPos = targetRoot.Position - dir * slack
                myHum:MoveTo(targetPos)
            elseif distance < desired - slack then
                -- step back to keep some personal space
                local dir = horiz.Magnitude > 0 and horiz.Unit or Vector3.new(0, 0, -1)
                myHum:MoveTo(myRoot.Position - dir * 2)
            else
                myHum:Move(Vector3.new(), true)
            end
        end)
    end

    local function clearChatConns()
        for _, conn in ipairs(chatConns) do
            pcall(function()
                conn:Disconnect()
            end)
        end
        table.clear(chatConns)
    end

    local function attachChat(plr)
        local conn = plr.Chatted:Connect(function(msg)
            if not aiRespondEnabled then
                return
            end
            local reply, keyword = pickReply(msg)
            if reply then
                sendChat(reply)
            end

            if aiFollowByChat and plr ~= LocalPlayer then
                local lower = msg:lower()
                if lower:find("follow", 1, true) or lower:find("come", 1, true) then
                    aiFollowTargetName = plr.Name
                    aiFollowEnabled = true
                    startAiFollow()
                    refreshDropdown()
                elseif lower:find("stop", 1, true) or lower:find("stay", 1, true) then
                    stopAiFollow()
                end
            end
        end)
        table.insert(chatConns, conn)
    end

    Tab:CreateToggle({
        Name = "Enable Chatbot",
        Icon = "chat",
        IconSource = "Material",
        Description = "Simple local responder for nearby chat (no external AI).",
        CurrentValue = aiRespondEnabled,
        Callback = function(enabled)
            aiRespondEnabled = enabled
            if enabled then
                clearChatConns()
                for _, plr in ipairs(Players:GetPlayers()) do
                    attachChat(plr)
                end
            else
                clearChatConns()
            end
        end,
    })

    Tab:CreateToggle({
        Name = "Follow Commands from Chat",
        Icon = "record_voice_over",
        IconSource = "Material",
        Description = "When someone says \"follow\" or \"come\", switch the AI follow target to them.",
        CurrentValue = aiFollowByChat,
        Callback = function(enabled)
            aiFollowByChat = enabled
        end,
    })

    Tab:CreateSection("Loose Follow")

    followDropdown = Tab:CreateDropdown({
        Name = "AI Follow Target",
        Icon = "person_search",
        IconSource = "Material",
        Options = listPlayers(),
        Default = "None",
        Description = "Pick who the AI should loosely follow (or use nearest).",
        Callback = function(selected)
            aiFollowTargetName = selected == "None" and nil or selected
            if aiFollowEnabled then
                startAiFollow()
            end
        end,
    })

    Tab:CreateToggle({
        Name = "Follow Nearest",
        Icon = "radar",
        IconSource = "Material",
        Description = "Automatically pick the nearest player as target.",
        CurrentValue = aiFollowNearest,
        Callback = function(enabled)
            aiFollowNearest = enabled
        end,
    })

    local distanceSlider = Tab:CreateSlider({
        Name = "Preferred Distance",
        Icon = "social_distance",
        IconSource = "Material",
        Min = 6,
        Max = 18,
        Step = 1,
        Default = aiFollowDistance,
        Description = "How far to stay from the target while following.",
        Callback = function(value)
            local num = tonumber(value)
            if num then
                aiFollowDistance = math.clamp(num, 6, 18)
            end
        end,
    })

    distanceSlider:Set({ CurrentValue = aiFollowDistance })

    Tab:CreateToggle({
        Name = "Enable Loose Follow",
        Icon = "directions_walk",
        IconSource = "Material",
        Description = "Keeps you near the target with some breathing room (no noclip).",
        CurrentValue = aiFollowEnabled,
        Callback = function(enabled)
            if enabled then
                startAiFollow()
                if aiFollowEnabled then
                    UI:Notify({
                        Title = "AI Follow",
                        Content = "Loose follow enabled.",
                        Type = "info",
                    })
                end
            else
                stopAiFollow()
                UI:Notify({
                    Title = "AI Follow",
                    Content = "Loose follow disabled.",
                    Type = "info",
                })
            end
        end,
    })

    Players.PlayerAdded:Connect(function(plr)
        refreshDropdown()
        if aiRespondEnabled then
            attachChat(plr)
        end
    end)

    Players.PlayerRemoving:Connect(function(plr)
        if aiFollowTargetName == plr.Name then
            aiFollowTargetName = nil
            refreshDropdown()
        end
    end)
end
