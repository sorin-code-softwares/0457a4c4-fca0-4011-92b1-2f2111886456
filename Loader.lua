-- Sorin Core Hub - modular loader (v0.1)
-- Tabs werden wie im alten GamesHub über eigene Links geladen.

-- 1) Helper zum sicheren Laden von Remote-Modulen
local function safeRequire(url, name)
    local okHttp, body = pcall(function()
        return game:HttpGet(url)
    end)
    if not okHttp then
        warn(("[SorinCoreHub] HttpGet failed for %s: %s"):format(name or url, tostring(body)))
        return nil, "HttpGet failed: " .. tostring(body)
    end

    local fn, loadErr = loadstring(body)
    if not fn then
        warn(("[SorinCoreHub] loadstring failed for %s: %s"):format(name or url, tostring(loadErr)))
        return nil, "loadstring failed: " .. tostring(loadErr)
    end

    local okRun, mod = pcall(fn)
    if not okRun then
        warn(("[SorinCoreHub] executing %s failed: %s"):format(name or url, tostring(mod)))
        return nil, "module pcall failed: " .. tostring(mod)
    end

    return mod
end

-- 2) SorinCoreInterface + Icons anbinden
local SorinCoreInterface, errInterface = safeRequire(
    "https://raw.githubusercontent.com/sorinservice/script-libary/refs/heads/main/SorinCoreInterface.lua",
    "SorinCoreInterface"
)

if not SorinCoreInterface then
    warn("[SorinCoreHub] SorinCoreInterface konnte nicht geladen werden:", errInterface)
    return
end

local Icons, errIcons = safeRequire(
    "https://raw.githubusercontent.com/SorinSoftware-Services/AurexisInterfaceLibrary/main/src/icons.lua",
    "AurexisIcons"
)

if Icons then
    SorinCoreInterface.Icons = Icons
else
    warn("[SorinCoreHub] Icons table konnte nicht geladen werden:", errIcons)
end

-- 3) Fenster mit Loading-Screen erstellen
local Window = SorinCoreInterface:CreateWindow({
    Name = "Sorin Core Hub",
    Subtitle = "SorinSoftware Services",
    ToggleKey = Enum.KeyCode.K,

    LoadingEnabled = true,
    LoadingTitle = "Sorin Core Hub",
    LoadingSubtitle = "Loading core modules ...",
})

-- 4) Remote-Tab-Definitionen
-- Passe die URLs an dein neues Repo an (0457a4c4-fca0-4011-92b1-2f2111886456).
local TABS = {
    Main = "https://raw.githubusercontent.com/sorin-code-softwares/0457a4c4-fca0-4011-92b1-2f2111886456/main/Tabs/Main.lua",
    Movement = "https://raw.githubusercontent.com/sorin-code-softwares/0457a4c4-fca0-4011-92b1-2f2111886456/main/Tabs/Movement.lua",
    -- weitere Tabs später hier ergänzen
}

local TabDefs = {
    {
        id = "Main",
        name = "Main",
        icon = "home",
        iconSource = "Material",
        url = TABS.Main,
    },
    {
        id = "Movement",
        name = "Movement",
        icon = "directions_run",
        iconSource = "Material",
        url = TABS.Movement,
    },
}

local function attachRemoteTab(def)
    local tab = Window:CreateTab({
        Name = def.name or def.id,
        Icon = def.icon,
        IconSource = def.iconSource or def.ImageSource or "Material",
    })

    local mod, err = safeRequire(def.url, def.name or def.id)
    if not mod then
        tab:CreateButton({
            Name = "Tab load error",
            Description = tostring(err),
            Icon = "_error_outline",
            IconSource = "Material",
            Callback = function() end,
        })
        return
    end

    if type(mod) ~= "function" then
        tab:CreateButton({
            Name = "Tab init error",
            Description = "Module did not return a function.",
            Icon = "_error_outline",
            IconSource = "Material",
            Callback = function() end,
        })
        return
    end

    local ok, initErr = pcall(mod, tab, SorinCoreInterface, Window)
    if not ok then
        tab:CreateButton({
            Name = "Tab init error",
            Description = tostring(initErr),
            Icon = "_error",
            IconSource = "Material",
            Callback = function() end,
        })
    end
end

-- 5) Tabs laden
for _, def in ipairs(TabDefs) do
    attachRemoteTab(def)
end

-- 6) Loading-Screen schließen
Window:FinishLoading()
