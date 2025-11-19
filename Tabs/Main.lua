-- Sorin Core Hub - Main tab
-- Wird vom Loader via HttpGet + loadstring geladen.

return function(Tab, UI, Window)
    -- UI  == SorinCoreInterface

    Tab:CreateSection("Getting Started")

    Tab:CreateButton({
        Name = "Test Notification",
        Icon = "emoji_emotions",
        IconSource = "Material",
        Description = "Zeigt, dass Sorin Core UI und Notifications funktionieren.",
        Callback = function()
            UI:Notify({
                Title = "Sorin Core Hub",
                Content = "Sorin Core UI läuft!",
                Type = "success",
            })
        end,
    })

    Tab:CreateButton({
        Name = "Discord",
        Icon = "forum",
        IconSource = "Material",
        Description = "Kopiert den SorinSoftware Discord-Link in die Zwischenablage.",
        Callback = function()
            local invite = "https://discord.gg/XC5hpQQvMX" -- ggf. anpassen
            local copied = false

            if typeof(setclipboard) == "function" then
                copied = pcall(setclipboard, invite)
            end

            UI:Notify({
                Title = "Discord",
                Content = copied and "Invite-Link wurde in die Zwischenablage kopiert."
                           or ("Invite-Link: " .. invite),
                Type = "info",
            })
        end,
    })
end

