-- catn hub v1.10.0

local Vanta = (function(...)
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")
local plr = Players.LocalPlayer
local unpack = table.unpack or unpack

local Vanta = {Version = "2.2"}
local U = {fast = false}

local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end

local THEMES = {
    Obsidian = {
        Accent = {rgb(232, 228, 220), rgb(14, 14, 14)},
        Background = rgb(10, 10, 10), Sidebar = rgb(13, 13, 13), Panel = rgb(21, 21, 21), Element = rgb(16, 16, 16),
        Hover = rgb(26, 26, 26), Stroke = rgb(36, 36, 36), Text = rgb(236, 234, 230), SubText = rgb(150, 148, 144),
        Muted = rgb(100, 98, 95),
    },
    Graphite = {
        Background = rgb(9, 9, 11), Sidebar = rgb(12, 12, 14), Panel = rgb(22, 22, 26), Element = rgb(17, 17, 20),
        Hover = rgb(26, 26, 30), Stroke = rgb(36, 36, 42), Text = rgb(237, 237, 240), SubText = rgb(150, 150, 160),
        Muted = rgb(98, 98, 108),
    },
    Slate = {
        Background = rgb(9, 11, 15), Sidebar = rgb(12, 14, 19), Panel = rgb(20, 24, 32), Element = rgb(16, 19, 26),
        Hover = rgb(24, 28, 38), Stroke = rgb(33, 39, 52), Text = rgb(232, 236, 244), SubText = rgb(140, 150, 170),
        Muted = rgb(92, 102, 122),
    },
    Warm = {
        Background = rgb(12, 11, 10), Sidebar = rgb(15, 14, 13), Panel = rgb(26, 24, 22), Element = rgb(21, 19, 18),
        Hover = rgb(30, 28, 26), Stroke = rgb(42, 39, 36), Text = rgb(240, 236, 230), SubText = rgb(158, 150, 140),
        Muted = rgb(108, 101, 93),
    },
    Paper = {
        Light = true,
        Background = rgb(250, 250, 250), Sidebar = rgb(244, 244, 245), Panel = rgb(255, 255, 255), Element = rgb(255, 255, 255),
        Hover = rgb(244, 244, 246), Stroke = rgb(228, 228, 231), Text = rgb(24, 24, 27), SubText = rgb(100, 100, 110),
        Muted = rgb(160, 160, 170),
    },
}

THEMES.Halloween = {
    Limited = {From = {10, 15}, To = {11, 3}, Ends = "Nov 3"},
    Accent = {rgb(255, 134, 40), rgb(30, 12, 0)},
    Background = rgb(17, 10, 23), Sidebar = rgb(20, 13, 27), Panel = rgb(31, 21, 41), Element = rgb(25, 17, 33),
    Hover = rgb(43, 30, 55), Stroke = rgb(60, 43, 74), Text = rgb(248, 240, 232), SubText = rgb(180, 162, 178),
    Muted = rgb(124, 106, 128),
}
THEMES.Christmas = {
    Limited = {From = {12, 1}, To = {1, 6}, Ends = "Jan 6"},
    Accent = {rgb(228, 56, 70), rgb(255, 255, 255)},
    Background = rgb(9, 17, 27), Sidebar = rgb(11, 21, 32), Panel = rgb(20, 33, 46), Element = rgb(15, 26, 37),
    Hover = rgb(28, 45, 60), Stroke = rgb(42, 63, 80), Text = rgb(242, 247, 252), SubText = rgb(162, 182, 198),
    Muted = rgb(106, 126, 142),
}
local THEME_ORDER = {"Obsidian", "Graphite", "Slate", "Warm", "Paper", "Halloween", "Christmas"}
local SEASON_ORDER = {"Halloween", "Christmas"}

local function themeActive(name)
    local t = THEMES[name]
    if not t then return false end
    if not t.Limited then return true end

    local okEnv, env = pcall(function() return getgenv and getgenv() or _G end)
    local preview = okEnv and type(env) == "table" and rawget(env, "VANTA_SEASON") or nil
    if type(preview) == "string" then return preview == name end
    local ok, d = pcall(os.date, "*t")
    if not ok or type(d) ~= "table" then return false end
    local today = d.month * 100 + d.day
    local a, b = t.Limited.From[1] * 100 + t.Limited.From[2], t.Limited.To[1] * 100 + t.Limited.To[2]
    if a <= b then return today >= a and today <= b end
    return today >= a or today <= b
end

local function seasonTheme()
    for _, n in ipairs(SEASON_ORDER) do
        if themeActive(n) then return n end
    end
    return nil
end

local function themeList()
    local list = {}
    for _, n in ipairs(THEME_ORDER) do
        if themeActive(n) then table.insert(list, n) end
    end
    return list
end

local ACCENTS = {
    Mono = {rgb(237, 237, 240), rgb(14, 14, 16), Light = {rgb(24, 24, 27), rgb(250, 250, 250)}},
    Blue = {rgb(59, 130, 246), rgb(255, 255, 255)},
    Emerald = {rgb(16, 185, 129), rgb(3, 20, 13)},
    Amber = {rgb(245, 158, 11), rgb(32, 18, 0)},
    Rose = {rgb(244, 63, 94), rgb(255, 255, 255)},
    Violet = {rgb(139, 92, 246), rgb(255, 255, 255)},
    Iris = {rgb(124, 108, 255), rgb(255, 255, 255)},
    Orange = {rgb(249, 115, 22), rgb(32, 14, 0)},
}
local ACCENT_ORDER = {"Mono", "Iris", "Blue", "Emerald", "Amber", "Rose", "Violet", "Orange"}

Vanta.Themes, Vanta.Accents = THEMES, ACCENTS
Vanta.ThemeActive, Vanta.ThemeList = themeActive, themeList

local STATUS = {Good = rgb(52, 199, 123), Warn = rgb(245, 166, 35), Bad = rgb(240, 82, 82)}

U.assets = {Glow = "rbxassetid://8992230677"}

local BUILDER = "rbxasset://fonts/families/BuilderSans.json"
local F = {
    Regular = Font.new(BUILDER, Enum.FontWeight.Regular),
    Medium = Font.new(BUILDER, Enum.FontWeight.Medium),
    SemiBold = Font.new(BUILDER, Enum.FontWeight.SemiBold),
    Mono = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Medium),
}
F.Bold = F.SemiBold
F.Display = F.SemiBold

local function new(class, props, children)
    local obj = Instance.new(class)
    local parent

    if obj:IsA("GuiObject") then obj.BorderSizePixel = 0 end
    for k, v in pairs(props or {}) do
        if k == "Parent" then parent = v else obj[k] = v end
    end
    for _, c in ipairs(children or {}) do c.Parent = obj end
    if parent then obj.Parent = parent end
    return obj
end

local function corner(r)
    return new("UICorner", {CornerRadius = UDim.new(0, r or 6)})
end

local function stroke(color, thickness, transparency)
    return new("UIStroke", {
        Color = color or rgb(36, 36, 42),
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })
end

local function pad(l, r, t, b)
    return new("UIPadding", {
        PaddingLeft = UDim.new(0, l or 0), PaddingRight = UDim.new(0, r or l or 0),
        PaddingTop = UDim.new(0, t or l or 0), PaddingBottom = UDim.new(0, b or t or l or 0),
    })
end

local function list(padding, dir, align, valign)
    return new("UIListLayout", {
        Padding = UDim.new(0, padding or 0),
        FillDirection = dir or Enum.FillDirection.Vertical,
        HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
        VerticalAlignment = valign or Enum.VerticalAlignment.Top,
        SortOrder = Enum.SortOrder.LayoutOrder,
    })
end

local function text(props)
    return new("TextLabel", {
        BackgroundTransparency = 1,
        FontFace = props.FontFace or F.Regular,
        TextColor3 = props.TextColor3 or rgb(237, 237, 240),
        TextSize = props.TextSize or 13,
        TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left,
        TextYAlignment = props.TextYAlignment or Enum.TextYAlignment.Center,
        Text = props.Text or "",
        RichText = props.RichText or false,
        TextWrapped = props.TextWrapped or false,
        TextTruncate = props.TextTruncate or Enum.TextTruncate.None,
        Size = props.Size or UDim2.new(1, 0, 0, 16),
        Position = props.Position or UDim2.new(),
        AnchorPoint = props.AnchorPoint or Vector2.new(),
        AutomaticSize = props.AutomaticSize or Enum.AutomaticSize.None,
        LayoutOrder = props.LayoutOrder or 0,
        ZIndex = props.ZIndex or 1,
        Parent = props.Parent,
    })
end

local function tween(obj, time, goal, style, dir)
    local t = TweenService:Create(obj, TweenInfo.new(U.fast and 0 or time, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), goal)
    t:Play()
    return t
end

U.motion = "Full"
local function full() return U.motion == "Full" end

local function spring(obj, time, goal)
    if not full() then return tween(obj, time * 0.7, goal) end
    return tween(obj, time, goal, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
end

local function guiParent()
    if type(gethui) == "function" then
        local ok, h = pcall(gethui)
        if ok and h then return h end
    end
    local ok = pcall(function() return CoreGui.Name end)
    if ok then return CoreGui end
    return plr:WaitForChild("PlayerGui")
end

local function screenGui(name, order)
    local g = new("ScreenGui", {
        Name = name,
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = order or 100,
        IgnoreGuiInset = true,
    })
    if type(syn) == "table" and type(syn.protect_gui) == "function" then pcall(syn.protect_gui, g) end
    g.Parent = guiParent()
    return g
end

local function keyName(key)
    if typeof(key) ~= "EnumItem" then return "None" end
    local names = {
        LeftControl = "LCtrl", RightControl = "RCtrl", LeftShift = "LShift", RightShift = "RShift",
        LeftAlt = "LAlt", RightAlt = "RAlt", Return = "Enter", MouseButton1 = "M1", MouseButton2 = "M2",
        MouseButton3 = "M3", Backquote = "`",
    }
    return names[key.Name] or key.Name
end

local function round(v, step)
    step = step or 1
    local r = math.floor(v / step + 0.5) * step
    local decimals = tostring(step):match("%.(%d+)")
    if decimals then r = tonumber(string.format("%." .. #decimals .. "f", r)) end
    return r
end

local function fmt(v)
    if math.floor(v) == v then return tostring(math.floor(v)) end
    return tostring(v)
end

local function toHex(c)
    return string.format("%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

local function fromHex(h)
    h = tostring(h or ""):gsub("#", "")
    if #h ~= 6 then return nil end
    local r, g, b = tonumber(h:sub(1, 2), 16), tonumber(h:sub(3, 4), 16), tonumber(h:sub(5, 6), 16)
    if not (r and g and b) then return nil end
    return Color3.fromRGB(r, g, b)
end

local function luma(c) return c.R * 0.299 + c.G * 0.587 + c.B * 0.114 end

local function safeCall(fn, ...)
    if type(fn) ~= "function" then return end
    local args = {...}
    task.spawn(function()
        local ok, err = pcall(fn, unpack(args))
        if not ok then warn("[vanta] callback error: " .. tostring(err)) end
    end)
end

local function draggable(handle, target, conns, onStart)
    local dragging, start, origin
    table.insert(conns, handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging, start, origin = true, input.Position, target.Position
            if onStart then onStart() end
            local c
            c = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    c:Disconnect()
                end
            end)
        end
    end))
    table.insert(conns, UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            local d = input.Position - start
            target.Position = UDim2.new(origin.X.Scale, origin.X.Offset + d.X, origin.Y.Scale, origin.Y.Offset + d.Y)
        end
    end))
end

local fs = {ok = type(writefile) == "function" and type(readfile) == "function"}
function fs.read(path)
    if not fs.ok then return nil end
    local ok, res = pcall(function()
        if type(isfile) == "function" and not isfile(path) then return nil end
        return readfile(path)
    end)
    return ok and res or nil
end
function fs.write(path, data)
    if not fs.ok then return end
    pcall(function()
        local built = ""
        for part in path:gmatch("([^/]+)/") do
            built = built == "" and part or (built .. "/" .. part)
            if type(makefolder) == "function" and (type(isfolder) ~= "function" or not isfolder(built)) then
                makefolder(built)
            end
        end
        writefile(path, data)
    end)
end

local fontTried = false
function U.loadFonts()
    if fontTried then return end
    fontTried = true
    if not fs.ok or type(getcustomasset) ~= "function" or type(isfile) ~= "function" then return end

    local done, fam = false, nil
    task.spawn(function()
        local ok, res = pcall(function()
            local base = "https://cdn.jsdelivr.net/gh/rsms/inter@v3.19/docs/font-files/Inter-"
            local faces = {}
            for _, w in ipairs({{"Regular", 400}, {"Medium", 500}, {"SemiBold", 600}}) do
                local file = "Vanta/Inter-" .. w[1] .. ".otf"
                if not isfile(file) then fs.write(file, game:HttpGet(base .. w[1] .. ".otf")) end
                table.insert(faces, {name = w[1], weight = w[2], style = "normal", assetId = getcustomasset(file)})
            end
            fs.write("Vanta/Inter.json", HttpService:JSONEncode({name = "Inter", faces = faces}))
            return getcustomasset("Vanta/Inter.json")
        end)
        if ok then fam = res end
        done = true
    end)
    local waited = 0
    while not done and waited < 4 do
        task.wait(0.05)
        waited = waited + 0.05
    end
    if type(fam) == "string" then
        F.Regular = Font.new(fam, Enum.FontWeight.Regular)
        F.Medium = Font.new(fam, Enum.FontWeight.Medium)
        F.SemiBold = Font.new(fam, Enum.FontWeight.SemiBold)
        F.Bold, F.Display = F.SemiBold, F.SemiBold
    end
end

Vanta.MissingIcons = {}
local ICONS = {

    ["bell"] = "rbxassetid://97392696311902",
    ["bot"] = "rbxassetid://80451686744860",
    ["bug"] = "rbxassetid://83626408925438",
    ["cat"] = "rbxassetid://124252153404931",
    ["chart-column"] = "rbxassetid://97915995538580",
    ["check"] = "rbxassetid://93898873302694",
    ["chevron-down"] = "rbxassetid://134243273101015",
    ["circle-check"] = "rbxassetid://85262178816537",
    ["circle-x"] = "rbxassetid://76821953846248",
    ["clock"] = "rbxassetid://121808839832144",
    ["coins"] = "rbxassetid://116510979641930",
    ["crosshair"] = "rbxassetid://134242818164054",
    ["droplet"] = "rbxassetid://100597455015098",
    ["egg"] = "rbxassetid://117851493400222",
    ["ellipsis"] = "rbxassetid://140019550645825",
    ["eye"] = "rbxassetid://100033680381365",
    ["eye-off"] = "rbxassetid://135928786788378",
    ["fish"] = "rbxassetid://124360663785796",
    ["flame"] = "rbxassetid://98218034436456",
    ["gamepad-2"] = "rbxassetid://92483947987410",
    ["ghost"] = "rbxassetid://113822048130017",
    ["gift"] = "rbxassetid://109855212076373",
    ["hash"] = "rbxassetid://82890331678520",
    ["hop"] = "rbxassetid://82778923997672",
    ["house"] = "rbxassetid://98755624629571",
    ["info"] = "rbxassetid://124560466474914",
    ["layers"] = "rbxassetid://81973586053257",
    ["layout-dashboard"] = "rbxassetid://139929981863901",
    ["layout-grid"] = "rbxassetid://81344910161871",
    ["list"] = "rbxassetid://113179976918783",
    ["map-pin"] = "rbxassetid://84279202219901",
    ["message-circle"] = "rbxassetid://127255077587058",
    ["minus"] = "rbxassetid://118026365011536",
    ["monitor"] = "rbxassetid://72664649203050",
    ["moon"] = "rbxassetid://83380517901735",
    ["mouse-pointer-2"] = "rbxassetid://117093892862228",
    ["music"] = "rbxassetid://113343203848535",
    ["panel-left"] = "rbxassetid://97419752870313",
    ["play"] = "rbxassetid://135609604299893",
    ["power"] = "rbxassetid://96479131758775",
    ["refresh-cw"] = "rbxassetid://138133190015277",
    ["search"] = "rbxassetid://121018724060431",
    ["server"] = "rbxassetid://92188766517878",
    ["settings"] = "rbxassetid://80758916183665",
    ["shield"] = "rbxassetid://110987169760162",
    ["shield-check"] = "rbxassetid://87354736164608",
    ["shield-off"] = "rbxassetid://133426959132690",
    ["shuffle"] = "rbxassetid://132382786975101",
    ["siren"] = "rbxassetid://134210267818039",
    ["sliders-horizontal"] = "rbxassetid://85538382643347",
    ["sun-moon"] = "rbxassetid://75752898854559",
    ["swords"] = "rbxassetid://81872698913435",
    ["table"] = "rbxassetid://109109148250737",
    ["tag"] = "rbxassetid://129104970103940",
    ["timer"] = "rbxassetid://85473888890506",
    ["trending-up"] = "rbxassetid://81819858538839",
    ["triangle-alert"] = "rbxassetid://125920361880643",
    ["trophy"] = "rbxassetid://131545003268773",
    ["users"] = "rbxassetid://115398113982385",
    ["wheat"] = "rbxassetid://85261952080359",
    ["wrench"] = "rbxassetid://112148279212860",
    ["x"] = "rbxassetid://110786993356448",
    ["zap"] = "rbxassetid://130551565616516",

}

local ART = {

    ["bat_down"] = {200, 120, "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"},
    ["bat_up"] = {200, 120, "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"},
    ["branch"] = {960, 340, "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"},
    ["fog"] = {512, 128, "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"},
    ["ghost"] = {200, 190, "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"},
    ["glow"] = {128, 128, "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"},
    ["leaf_maple"] = {100, 95, "iVBORw0KGgoAAAANSUhEUgAAAGQAAABfCAYAAAAeX2I6AAAQBElEQVR4nO2ce3Bb1Z3Hf+fce/V+2dbbrzwch2BIgvMgKU0ISxnaMC0tJQmlCTspMLTd3dmdzj5mp//kj50p7Ox2H13K0G7IhgJDHRLCbGk7DDtkOy0t1GkTSAgJiRPHj9iyZcvWw3rde/o7kq4syQ9CG8m6Gn3H8r26sq6l87m/5zkShbqqShTqqirVgVSZ6kCqTHUgVaY6kCpTHUiVqQ6kylQHUmWqA6ky1YFUmWoCyPEtvl++vr35GagBaR7I/27zf/+Oexx3mK1k66Eulxc0Lk0D6dnQ8vDajda9ViuF5atM6xwWugc0Lk0DsVjlxxudgpUxALdHBL2efLVn1y4BNCzNAjnY6V7nbtZ1iCIBUJAI/qzusqyhV3/5RdCwNAvE6RL2NDcbWlQYfOvzS5aWFvHJH65qWgMalSaB9HR1WRwO6U5Hg5CHwd0W/7X2VnPH8nbD99F16UCD0iSQqBLwGQzgUWEkkwxSSQX3IQPF5RJuif7+/7pBg9IkEEFOeyxW0aZaxsRYAoKBZAYGv9/UIDmdLt1O0KBE0KAURjwmE3GpbiprGdldDsnuwLdF4C7QoDRpIS6ffpvOIMzCgGwoUQM8xYM+n871/C0+zQV3bVqIzLwGA8nHDNUyIGcxDI9LAmuS4wk7aEyaBGIwCV6jjuQHvzD1Vd2YTqJORokFNCbNAXluZWOrSUfdeRgZAjBrKTk3JtEMIytoTJoDQkXWZndQVx5GibtS3ZiA78xkFDygMWkOiNEo3Iwpr7MQBiuBwXdFSsBmIp2gMWkOSINd/xmrjRbD4FIDeu4473ERQjWXRWoKyNEN/odXduo/Z5DIPJYBRdmWTmSYjSlrQWMqyxX04hpf+6tbvT/t2eLZ8/xajxlukERJ3mExUetCbqowlkiUWwgzP7thgwQaUlksJJ5KrN642fU5dBjb+z+InT9m9ByZGFdeeezS2EX4EyQKpEMnwdy6Q4VTElNsNsHsCkVteC8In1A9K1bYd/f1TfH9FzoabSlKVhv1wjZGmCEuw3P7z46NQBlUFiCCKFpNZiHixnZ423J9d3A01T1wKfbYz1a0nBjpjx4TZF3vI5dGA5/knLx7K47+SicVzH8Upb7zBPjOFqkrMhX6F3bgwKPkwAHlev7Pcx3ObpuZ7TIZI5uO2512nU4YVBSl1WKkbouBtEoChf6x9FcOrvY/+Oj54fNwg0WgTHr9Lv9Ptu9suk9XUMBFozIER1LR4b6ZS/EkvJuIycRkpr5QKP0jc8j66s6LFxOLnvNTnt9u/7RtI2GsCMboWCoDw90kFbkxWSHw9qnYu/e9E7j9417v4ZucnU1W+h2cBt7UaCWtZj3B0xC0diVb0yjZ60DB8340nD4bZ7Y7dp/MWtCNVNmC+shw8ivvngj9+tP3OLrUgTMgnLZ2nbm1Tbc2HJbXUjxmNEgwNBC78+KHsb951en97pd+M9Kz0DmVNFxOxpWNeh0sahmqG0tiS15Osysf91qPbnB/s8lEvrXCL60keOLswPPTKCCwYhiTERaNxOmTD5+58TC4ypYWPnp+PDzUF3noTG90SB242HQaomE5M2BWEwUz3iiRoaVFb95xt+32W9dbDr662fvUgicVSCCeUGD+ohDmBPgUzpNQgS7oGp/ucnmPd7t6VvmEpzr8QgkMBrEEQwtheRgMLWZ0gp258OA3X4Iyqax5+iPnJs/0fRj924HLiSh/VxabCENXZiAyJeddDlNYfnD9bsGyeYvl71/b6v35f22+qan0fKkk6ctMRJVaBldJHcLvJ9DdhGLsbOl5MPMy9axzf6urSXhjfYduV6OZWBiDIhjROIPgtAx6TLGV3Hn7A+lLoQTbd+A649Efo7IXTrt6R18+/37scHg6+25XrTHD6FAcpiblgoGF/OA6rBTu3Ga7d21j+I1XNviLFixMR+UzydTibqow4KfS6LbQzRWe4+V17gfahIGfd7UL/9rpp7eKhOVBqDAiMwxCEQW8DWIGBj8+HGQDsRnh8f3nxj6CMqoilezYlPTt0++EetWBWrHKhDN8CQhNptVRKBpMbJ1D9zpT95pO6dnX7/AePrja6efnUeSUjslsFoayAAwlZ30y/pJTmTrkcGdT8082eX602i88s75D2tZgIgUQclv8FY4pMI03t0PIwwhMsv7JMPzVl0+PvAVlVkXWML02Eoo/4LaOiAJ8BmfzzHwEGhokGBlKgIJjNju3AUXZkwPrCK9TWoeB+b77XfaRZBJm2v3SPrORFllCJJZ1YxYDLbKcWJzAwAQ8v2+Zbb3PTg6taZPutpuJmQ98KQwFf3EQ3FW57DkYeNqJGESDYfjOg6dH/wcqoIotKrvX2RQgqcQXWtv1fvUq5lOtY2gpaQy+2Jmdt64Q8LDPLTqNetg5E1PWt/pEv57nhgXwojE5c9+CqSorOC7L3M0pN6/2i4+2e2gzpVkrmA/GVFSBOL4OZwGMKAb1wUD6uw+eHvsnqJAq1nwzr9oURm8zXur/21oMMDMjw9hYctFU1tdELVu7jRuwgzu3KAQoqthZLu6bjQCbOqVupw0sfICVBWDweJHAUqbRNguDe7urAfnE7veD/wgVVMWA7D5yRB4akP/iVG/kg9Jg3OzXQwrT2UBm5QgsGLAlyhas0KEEhur/Be7FFMhnSnkYHA7eJsMKpPBKacBkguVg8MdHJpWhGdH8MFRYFW1Pf+3CaN9YkHzjg/djw/mBzmVYPq8OgzbA6GjyY7On+S2puICbHfhiGKpV8O3EdLbucFiEPAz1bzCZm6SxZMUX21V8vuD+twd+ERhjD7zzTuS9eJwVDazHlW0cXBtJQimwwuxpvjqEFaSti8FQY8g4r4XQ+9nMNHtMmbWeiagSnY6S//zquWv9UGEtyUrxl65OD90rWl8JTsRv0hmEFquR6FSrMGOmlEBQk1NprOYF+Lj2CD/O6wY+mCZ9LpUtcFvzwQggDOwcZ7oFpUF+dIrFpmPwd7tOBZ6FJdCSLd0/GgzHXhyIvvxnOn0YGLm5wU4dauprwjSYLw+dwDrFZhYWhcG3HAjfMerp/DCUWcsZDWH1jR1j7N4WwYhjUB8YS18Ixcg3dp8KvABLpCX/LMWPh6LvftZgviQJsMVuJQ3Zgc5e7TxtHQvmoCwAgw9mNK5kHjLqaFFAZyUwRrA7wP+G1zFKwfMnwywwMC6/FA0L+/Z+GDgJS6iytd8/qV7b2vLZFhf8YFWb2DrbLMSUFJuR/NbuluaFwQc7gFc9H/gmm7AgjGsTaSwcBew4F6e9IyEYCMbgiYd+P/IzqAJVzaeNXh6cvnifw3oqmZTvxuIsv5Caz58LeN0M45wHz4YKYSi5oM9dFufE2/vzBfThoAw201wYwxPyUCSl27vr5PCbUCWqqlUZoVAqOD7FrrKSmIFBP1NB9w0l58BQ8llWzjKUYhiD42mwYyall0oKwoyro+fD08lJqCItucvCxqFVlAzLHcbkX/qc0p0rWqVOiSjz9rZ4n2kYY8oyr1hQc/AUNp3ZNlqEWVi4HUAYjVYBdMJcGBx6ilEYD8kXsKF4YipJn7aLrG/32bEILKGWDMhrm31fxwmhHXo96XA5Rae3gbbzadPC4K0We1CQMcWwoh8a41CkfAzhNQXfb7AIeRhXA+mMVUkLwChMdfkkVDgGVyNxZRwTiY/SILyZloyv7D91JQQV1pIA+e+VDbe0+vVv3LZG75t/jZUavLP7he2OzABi3XgVY8pyr5gv8lim4s5mWTiRlGmfixSKBl5RSuoSNSNTZoGlsY2SSBOYCsu9CRD+et+ZwNtQQVU8hry4pmWVx6n7j3WrjabFYbB5YfD7Ihb0rS4BLg6nMoMJOUvhj18eSYEHJ5auC4ZSDIOfg+BL0gm860s3YnL8vZ4uV0VX0Fds5SJfXuNqoF/3edj2ZS2G1fxNLw6jZOBY8cBRHLlWlwSXrqXAnptsuoz7fjyGdjJ34IueP/dYvpDMAcISCNCFNk5H6Rdwt2xz6KUqu8t6/mbP7U12+LbXLX4KB6vJbMC5bpxnwEmn7FWtzParVP8ODGYbfaq/V3KlicIyrXF1MGXcuYJWwRcgtPFeGGFq+AEoGPDM3dzxzP8svJ+DwRjJbbOPc2uJJXC6JQ0/SKbJM+WevuUqK5Cj3Z49q1bqn2xuEpZJfCI1ZwnD2NGNxfkQ8ht/CYyPY3abOZr9W5Z7LPtDMgOVeyi7ze2HYzyoE6zAszOP/OpmBanvnICee3IGOmRfUz6PyLlJboHqAge+viuagEupNPspnvepP78QHIIyqWxAjmz0P4QTQ9/zOqlTwEYe9+kGzD/Nev4oy7ulwrQWFsiCSuuOovaIUuJy2CyMoucrJfMhJedUWEktU3JODi8l85UsBDvAwj/sPTf6YyiDyhZDZuLs9JVQ4vOXB4kFLz+zxUg8JrN4K767LW1esb3dI7hKYcRlAnzxHL9KFhrM6xk4tgiM4uwK+2WMZE6kPgcHnK9UCcqMTSppEHMhja/cVmSZ9WOqflySaC+USUuS9h7f5PthSxP9kt0MTSm+diqiXJqKsWkqQDCZUPjiaNDrRcVloytcNnDPgaHME4yvE8Z0jAZiM0pfUpF57MeMjU6l08yJLtWGo75yJgXHkknln/EFDAv4YqhAlDQlzAxm2H32SlkWWBdqSYAc2rHMQAenbwNJ9KZT6Sil5KpgEAceeW80yh/nHyHQyUGz257c5BDpwZZGpbUQRuFVrmZGhZazUKo7GaWDMYV+LZUQeyM6V+SJkydT/P89jamtLqm0SkBWiEb96b3vDQ3CEqlqur0L6a0d/pvwKn2j1YFQrhfGPDOFUzE6EJHpPbt7b/yK9Rupqv9uqcNXwuM7vebfzUShSyfS5mzBVxxD5oORb4ukKQTD0IvO54ndJ6/9DqpcmviyryODkf7Pt7QfjYYiYlKhDVj5ufIfE1kARhyD89QM+XA6Ih+mjubHv/zrixdAA6p6l1Wqw7e411ol+CLG2btNOsGr07FmfBfmDBSZReNpGJqZYaNMIG9Ox8mxx86NngENSXNAVKFlkBc2tK5MxxO3YUewh1D6bxhrjukMhmt7eq/2EZItNbUmzQJRdajDsQNH/i18I3ftvxg6ARqX9r+3l4IjsyVQ8bmLckjzQDDtXc+3+z8KnYIaUP2rxqtMmvx6pkJh7NiBm/+HGlHdQqpMtQBkHZpJTcQPLk0DObTewTMsBxbnNZFhcWk7hkSyGRZeVSegRqRpC1GyAR3AUjsuS9MWghkWt5D+/adCNeOytB3UCQZ0qB3r4NIskExAZ7CM1RgQ7bqsGgzoXJq1EDWg10KHt1CatRBC4H7cnIYakyYtJBc/1mNBeBxqTNq0kChkvraJkjqQqhBaBgfSXytzIIXSnMvK9a/uhxq0Di7tWUgsm12RGowfXJoDknNXU7WW7qrSIpAruPl3qFFpfhlQrak+hVtlqgOpMtWBVJnqQKpMdSBVpj8A5hCXYM6I7HMAAAAASUVORK5CYII="},
    ["leaf_oak"] = {100, 95, "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"},
    ["leaf_red"] = {100, 95, "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"},
    ["moon"] = {240, 240, "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"},
    ["pumpkin"] = {240, 216, "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"},
    ["spider"] = {100, 100, "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"},
    ["web"] = {300, 300, "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"},
    ["x_bulb"] = {44, 60, "iVBORw0KGgoAAAANSUhEUgAAACwAAAA8CAYAAAAdUliaAAAELklEQVR4nO2aO1LjQBCGx8Y8kzUnQJxgISRCDiEyxFThPQF7hD2C9wQQEFPcwFqKiCoK+wZ2RGonvG1vt2vGtNsjqUcjBa7yX9Wl12j6U6tH87DLasFUVgumivLQ2dlZOBqNLmE3EN7SLZfLv66vryOVUV4RdoRFBfqezPKKsHKD9blnqoXL4SVw0VoCF60lcNHyBR4od/WUh7yAoZutOwL04J6G8lBJZdDz83NYKpVaYAptUlHpu6rxeDzdokF3rL6+vtT7+/vUPj4+agcHB5FyVKYIA9ylgUWDqKm040qlMmNwLtOYwhkYovsHIAIKZKCM8WvGVldXJ7ArKytowf39/W/lKGdgcHzOIW1wtms00hr6QjnKCRii24iLrm1rMw06jfLd3V3DhcEJGBxepOVtEiwH1mXPXRjEwBBdjOweh9zc3FQbGxupoAlRDlutViDlEAODozp3vL6+PgFFx2trazMNL+4BJk5ZOVBdyuGSEuHMjRqUQ8RBkgefeyhed5LEUySo+JC/Vg6C54bD4cy5OKM5D3Yo5RBFGPMXNlUKQaObJcqsgValeSxNiYCC0X26lUBOHbMHg647UDkChxxWNxYrFH8IXiam/J4SyHmazwFSIET3aFWVQL7rEnMQaaBx90klBQ6F5aZDS76flw/nwQ8d69quJV1PqlNaXgQMlfWTHPABO3cuLNtVeQFDjrU5hOkgbADc4sDZvV2VFzB3YqY9toeQgvN6cCuRqNFhStjg0An2eNx5UmqYc1iWwsJb7EtYRMCYEtShMZhITkZsKJxkpqWHEYfV19sSFhEwjHfbb29vcwDoDM/z729SWpj7uKEPCYsoh7e3t/F19TgMTQFLxGIN08mYBu7VajVRSogbHVTatr1y2+ul53hKGGAWYVF0nYDByW1a5CSGuU4jrOFvpRzisQRUHOH0nEaKynZsy10DacB1/oqBxRHe3d3tgpNOUv6mXUNIYyTCHWn+OgGj4DPWpJ0Dz1/bMW1oMcBNFwYnYOgkbj8/PwdpXwJbxDms3h8cHR1duTA4AUNa9MFJE6DnXnvcZw2PsTw3DewUXWdgFDQ8BB6gU9No4nIXobA3tIBOoguNrXhgjDLmMoIYGASgOYzHFJKWI9Z0aWxGmaZIW1tbzZeXlwbA7Zg1MjopNeCmYVnSoZcluqhMK/Cop6enENKjRRb15oBpY6PRhuMaNLZIZVBmYNTj42MT13g5sK2TIMB/j4+PnReycwFGPTw8RLjUlAasof9BZEPlIe9pPvwMUH99fW0D8I5iwCYlNDTmrXiVMk7ePyzu7+/34VehOtjAfDmo6TToAHw9y1eByzsljGAxbw+iGMHuDxphHCvA+fDk5MQbFpUbMAqgq/C5iwD4px7sdOB0brCoXIGNbm5urnB7enraUDmrEOAitfz7QdFaOOD/1CsLt0xHxWUAAAAASUVORK5CYII="},
    ["x_cane"] = {128, 168, "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"},
    ["x_drift"] = {512, 128, "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"},
    ["x_flake1"] = {50, 50, "iVBORw0KGgoAAAANSUhEUgAAADIAAAAyCAYAAAAeP4ixAAAFiElEQVR4nN1azWskRRR/s+otsMOCeMia7VxFcHLUBOw96XFyFcEJXuLJzR+wpPMXJJ7E005gweMmNz2lA65Xd0F2L8JOFEEQdFb0JDr7flO/Sr/pVPV8pHsP+cGjq+vjfVS9el31Zq7JFcE1uSJ4VRrGaDRK8Gy1WgNpEC1pEDTiGV9XmzSmaddKIuXaUbshWAWlXaV2oK3NtkRqRhMrcqCUKZ0oLZn6JdZl7FMrmjDkEZ8dpX1Tv88626c2NLLZ1XX6+vgk0nyom74nNaPW8KsGfK6PNhTVMqrKxhyybVfLQy1/ITWhthVR5eA2P/C1r0puad1DLb/Huu+1bl3r7mm5x7o1ravFzWY2RBXojge0WkcVfaDUO3ztKx2K2+DAbXEr1OP7Y+XVuYw8i5kMKc32eBa1bp+Cdkw/hNxcCmO+UfowUH6slOrYoRl7zi8kTxYxhArBBcAAfox3/4XeYb2f6U07awFjyggZgdl/wFesXKq0y/dVJfTF/oOBW3asRyz89pTAPKMB7yudsa0rk+EztQMpJKXCU40o89C23LyfUfYz6tKVwjUnULUiR2Ti8YfSDQpraZ+c7Y/0dS3C40elZVb9qvR2aDa1L9wIs32q7emIIU/xu9LrpuspjJl5RdARDLW4JcVK3DCCPxXnPkAndByhsG1TtR0xIpHiQ5mTt4c3AjrApUKrGTeEAqAcZgYhtDz4S6Vb5r0bYfN3pGyRmvIb5G0xpA6j0IR5VB1R+qSPxG12i9fE+er/AWXmRconeG2Tt0WbOvRJQVQZMuDzudKxuGiFCIKo8rQ0/mOGzLmgY1KMLfF6ShmrlHlMHaxOF9CaJghRhEuKjQ0XSiV+t+hDuPdjKnr+QWRE8m6L70Yvwmcgbg8i4CAADL0usoghRijCX8g/fxE3k8umDkYcqNC9kCE8Z90p8UNEg2u9GZABfquxTe4xyzG+LZNCvZvhi7uidFOcGxyb/pkqDOM3zLgN1mWG3zGVvAle4CmFO8XkBzHPEaVdtbTsl4pzr1tSDYTT3oz8hgsfUS4LVQCukyldLzVh02aq2IHUjKbSQaMF2xbGPK51XWfydEq/VNxhM5FqDMR9qfMp/BApn8/iWlM3O48QOAsh4gAPcBO03w1mThCdQAmrsQ/uGlZ3pTjuoM8JeSWGT4e8T3jeyiF7lqzLrOF3IBf9HfhZ6RWZDL/YBwi/WST8ZuLCr+WH8Puf0kpABvgllwq/WFoySJQ2xd34zkyXlZIRhxSaxXiyLWFfj2WZNOKM7ZveCLrZ/IboQEQWzOCf4vweITUT9zV+UuqO2cR3pTdt5mjMkJmUNY61eEIZGWXeow45dQqiKmolfMK1uqQyI3yNMRn3F0ki8Mp8X9xd3vN6Swp3jOl0AVWu1RN3H/laLh7j/xW39H58LosjN7p8Rd4WQ+qwJfGzWdwQuggix7ty8YjwmUyeRI8ibJYiZYvclH8jb4s2dRhVuW3VVRfJgNRUx666wbTOnFddn0Y6nXLVzcUlO+ZKPqQsI/xhWf/i+6k51nvmISNOZDKioXwSueXlfHqe/sP7D2X7+0gqEfeKGdIXdwLdE7fBcik2GtyoE1BiDGNE6KKFupAxuRmfmvfEyN6jTv0A30sl6MYRTMt3JG7Et0ofBMpwpdul3NY5v9oSdBFjuhR0VNHHp3UARLW+TKZMe1IktoNppHnkWTSVxD5k1v07La+z7qHWbZR+cqgtiV3bMZ7uhttdm+csnAbWTZdxJp4GDmTGC9PM8qUBlH46KGP8k4PUjCZ+DM2kMOIn0+TLPfapFU38hug3OxLWO6Z+R4rEdkdqRhNXXYRj+D7CqVUYKdOU7X2pGU3/8yGVQIKuCTT9X5RBpFw7Gl0RYHQV/lTzMnFl/q/1AjU3kORN5YZOAAAAAElFTkSuQmCC"},
    ["x_flake2"] = {50, 50, "iVBORw0KGgoAAAANSUhEUgAAADIAAAAyCAYAAAAeP4ixAAAEd0lEQVR4nO1av2sUQRR+EQsLwYiVWHj+6EQ4C7XMaGFrQDsLN3+BCYgWikYkpRj/gmwKEUQxthK5vdI0SSBl4GKhnWgg/iiE833Zb7jJ3s7eXm5WwpEPHjc78+69eTtv3nszdwdkSHBAhgQHpWK02+0aPkdGRjakQoxIhaARLT6eqtKYql2r5mkHx9DskX1D9hqCGqKb2yh9V2oojeaMj3IMPEYCIvSK1JVggFFqKB12xg6zz5CnLgERPPzqm4714zYf15XO5rTnNRRHEhCV5JGMMVkENwLo27V0khH93Ph4ONH5nKFCI7jHINvL49XpEQgfnlNaUXqhyn84Y4l+jCk1td9IAZR3ST8u8nFJ+S/34E/yZHM+dyTdVxPufCx8KxIpjStNK7VUkOsmK/wcy4tMGdxz2veLGClrLKNDqLvFuYxzbl3wGRIrNdmGglgFLtOdEofPSDgYp53QzZY5F/vCmnzuQq4hWDou7YTSZ3ZjWRE+r3uUDwrjtG9Tlw3RmANcyuS5FVC42fVLMYU9Udpkd6T0l+2rEg5WFmSPs71J3XXOxYueUYurMy2pQW/Zbc8x53X5H8qAoIzzGdnQBQOmfavgoqch9NXnki71jRyWpwyZfWdqG24hI2cYuiD3eRnZPRMi6iLpbDYL+OxPpdNKh5z+WGnKvkEGhwbHrmh/wn7Iw8uJnO/+UfqqdEzpSEYfvOKoFKBMQrSbHRFjSumCCq0pndP2cUl92CKSNFw/9gnjWEt2GgEZx1XmGSUYeYF9zcwcvAhSovBIOys7I9qG0kulB3yeUbolO0+K75UmQxyBg9ZadKVY6WQPVrzhyLpaCAQt4zExuJ2kLvg7h+WXpHuoFtIIoKrroPYux3aNKlwLxWatB+uGpJk6kUAI4lrY7MwHoBq7sQ9mHLYZ6UQf8CBHvLMXeIOiTEJEsdhm0nvsJieewW04NezeLiu4VxYdUYvsc8sdlCItyh115NbZ16DuZemBMgkRya0rQSl9UzohOxMiDlOTJRMiwrV7PEBC/CJpQswm4E3mFy/KuJZReqG06vRB6BnHCCQuJMqoTF3E+i2SNPHZpHeIMt0Jr1K36SWzTNG4ojQpqRt8yGG5y/J6RfoEZRttPsoZfgOd0F1Gdpk9YvcB/PQau20Zv6ZKnsmAUBkoGtcysm9CZ3b/+FBoCI+ZMGBaOkv+Sjr556OEg5UF2fbiYpS6lzPH7S7kGmJvBCUtN2rshr9eUXrtsCYSDonTXqAuuy9rkh63G77VKbp8MGwjVCJ51Rl1bD9cYkHCIXHahuXO9q2JdMK1Ec/lQ9F1UCzpbcbsANdBn/TjEh8HvQ5CwIFhuZGx7xKFl2egwmiifHPS/fZi/c5EwXcw0VnyxdIHqroyzTPCotCY3SL47yMZI9adIduOyBMUoX8fgR9HfETEmXKGp6QThSLyBkPoFcGeQYRB2WGUtpyxLfY1ydN3JVCEoAcrhme3is2OI9oYqQD7vyHuNez/F6UkNjzt4Kj0vyjAUPyp5n9iaPbIPwfsBUvqIGQ0AAAAAElFTkSuQmCC"},
    ["x_frost"] = {200, 200, "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"},
    ["x_gifts"] = {264, 219, "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"},
    ["x_logo"] = {80, 80, "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"},
    ["x_ornament"] = {60, 60, "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"},
    ["x_pine"] = {720, 255, "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NBKgCbSGhoaGhoZGCCItI0Mr4C02MrQYbb7FBwapxXW9SdvoW7txkDIGcpyvgTRe/0829tb7TtMKd4z19aBBeK2mmpfYVNUzqk78Bg0KXNOhQkEGZO3aTphNuTktQjYvrq24Q04naWgkQBcRamhoaGhoaEQwuL6vj/+o3uIeflyIJ8JDnQk807HoX7uxj/900xRgkDWIJOvgtch1rgoPc9pvikJo6a10N5TIsZk2z3LK9unY/XQug5bkn8b7KoHmfS/xO4KVGwY96nVgvCS8jHEbaWgkQBNoDQ0NDQ0NjSlhcEPf2vyZHYvZt9tBzbQRxYJ0lIAOie1nLdvOdPc48YbnFXbJb81D3NDWRIUDI2UmvSIZ2teYBqE/dP/W3/BTPKjj7BX50fHhM/mT4ycGRp/KtGbeHmzEMIqG4/wv/x2kdHZVi1mkkWohz17nC70FtptWqps0NBKgdaA1NDQ0NDQ0XhJAI5NqtbLWJ9FOuUp2qUrNx86k3Ny2YLnK6MQHRnYeFJJ6dqH8KvZSQyR6zeDDfT1J2+64+Iy1juc9B9jjfWrfzfduVL/foWr+QO+mXtLQqAPtgdbQ0NDQ0NB4SQBe6I7OFStGaLyTqmY+kzV7J6hKmXzT/+GPv+Qvl21tXd93973/RdOCAWJ+Ye11tYv/W6V+P2loTAGaQGtoaGhoaGi8ZOB1AVwrvze4vu/LSy47F724O00y1ngNrqaHDPVSKfTOm0lD4zChUzg0NDQ0NDQ0/iDQ8cEzNjqO2y4cOdNo4kIaGocBLWOnoaGhoaGh8YcBw+yOfa6hMU1oD7SGhoaGhobGHww6ujrZ6zyR7+tZ30caGocJTaA1NDQ0NDQ0NDQ0pgGdwqGhoaGhoaGhoaExDWgCraGhoaGhoaGhoTENaAKtoaGhoaGhoaGhMQ1oAq2hoaGhoaGhoaExDWgCraGhoaGhoaGhoTENaAKtoaGhoaGhoaGhMQ1oAq2hoaGhoaGhoaExDWgCraGhoaGhoaGhoTENaAKtoaGhoaGhoaGhMQ1oAq2hoaGhoaGhoaExDWgCraGhoaGhoaGhoTENaAKtoaGhoaGhoaGhMQ1oAq2hoaGhoaGhoaExDWgCraGhoaGhoaGhoTENaAKtoaGhoaGhoaGhMQ1oAq2hoaGhoaGhoaExDWgCraGhoaGhoaGhoTENaAKtoaGhoaGhoaGhMQ1oAq2hoaGhoaGhoaExDWgCraGhoaGhoaGhoTENaAKtoaGhoaGhoaGhMQ1oAq2hoaGhoaGhoaExDWgCraGhoaGhoaGhoTENaAKtoaGhoaGhoaGhMQ1oAq2hoaGhoaGhoaExDWgCraGhoaGhoaGhoTENaAKtoaGhoaGhoaGhMQ1oAq2hoaGhoaGhoaExDWgCraGhoaGhoaGhoTENaAKtoaGhoaGhoaGhMQ1oAq2hoaGhoaGhoaExDWgCraGhoaGhoaGhoTENaAKtoaGhoaGhoaGhMQ1oAq2hoaGhoaGhoaExDWgCraGhoaGhoaGhoTENaAKtoaGhoaGhoaGhMQ1oAq2hoaGhoaGhoaExDWgCraGhoaGhoaGhoTENaAKtoaGhoaGhoaGhMQ1oAq2hoaGhoaGhoaExDWgCraGhoaGhoaGhoTENaAKtoaGhoaGhoaGhMQ1oAq2hoaGhoaGhoaExDWgCraGhoaGhoaGhoTENaAKtoaGhoaGhoaGhMQ1oAq2hoaGhoaGhoaExDWgCraGhoaGhoaGhoTEN/P9BJfouj4W4ZgAAAABJRU5ErkJggg=="},
    ["x_sleigh"] = {310, 100, "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"},
    ["x_snowman"] = {200, 264, "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"},
    ["x_wire"] = {220, 60, "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"},

}
local artIds = {}
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function b64decode(data)
    local map = {}
    for i = 1, 64 do map[B64:sub(i, i)] = i - 1 end
    local out, bits, n = {}, 0, 0
    for c in data:gmatch("[%w%+/]") do
        bits = bits * 64 + map[c]
        n = n + 6
        if n >= 8 then
            n = n - 8
            local byte = math.floor(bits / 2 ^ n)
            out[#out + 1] = string.char(byte)
            bits = bits - byte * 2 ^ n
        end
    end
    return table.concat(out)
end
local function decode64(data)
    local fns = {
        type(crypt) == "table" and (crypt.base64decode or crypt.base64_decode) or nil,
        rawget(getfenv(), "base64_decode"), rawget(getfenv(), "base64decode"),
    }
    for _, fn in ipairs(fns) do
        if type(fn) == "function" then
            local ok, res = pcall(fn, data)
            if ok and type(res) == "string" and #res > 0 then return res end
        end
    end
    return b64decode(data)
end

function U.art(name)
    if artIds[name] ~= nil then return artIds[name] or nil end
    artIds[name] = false
    local entry = ART[name]
    if not entry or not fs.ok or type(getcustomasset) ~= "function" then return nil end
    local ok, id = pcall(function()

        local path = "Vanta/art/" .. name .. "_" .. #entry[3] .. ".png"
        if not (type(isfile) == "function" and isfile(path)) then fs.write(path, decode64(entry[3])) end
        return getcustomasset(path)
    end)
    if ok and type(id) == "string" and id ~= "" then artIds[name] = id return id end
    return nil
end

function U.artSize(name)
    local e = ART[name]
    return e and Vector2.new(e[1], e[2]) or Vector2.new(1, 1)
end

local function flip(img, name)
    local sz = U.artSize(name)
    img.ImageRectOffset = Vector2.new(sz.X, 0)
    img.ImageRectSize = Vector2.new(-sz.X, sz.Y)
end

local ICON_ALIAS = {
    home = "house", close = "x", cross = "x", gear = "settings", cog = "settings", warning = "triangle-alert",
    alert = "triangle-alert", error = "circle-x", success = "circle-check", sword = "swords", chart = "chart-column",
    cursor = "mouse-pointer-2", combat = "swords", visuals = "eye", misc = "ellipsis", players = "users",
    teleport = "map-pin", farm = "wheat", auto = "bot",
}
function U.setIcon(img, name)
    if not name or name == "" then img.Image = "" return end
    name = tostring(name)
    if name:find("^rbxassetid://") then img.Image = name return end
    local id = ICONS[name] or ICONS[ICON_ALIAS[name] or ""]
    if not id then Vanta.MissingIcons[name] = true end
    img.Image = id or ""
end

local blurFx, blurRefs = nil, 0
function U.blur(on, size)
    if on then
        blurRefs = blurRefs + 1
        if not blurFx or not blurFx.Parent then
            blurFx = new("BlurEffect", {Name = "VantaBlur", Size = 0, Parent = Lighting})
        end
        tween(blurFx, 0.4, {Size = size or 12})
    else
        blurRefs = math.max(blurRefs - 1, 0)
        if blurFx and blurRefs == 0 then
            local b = blurFx
            tween(b, 0.3, {Size = 0}).Completed:Connect(function()
                if blurRefs == 0 and b.Parent then b:Destroy() if blurFx == b then blurFx = nil end end
            end)
        end
    end
end

local function buildTokens(themeName, accentName, customColor)
    local base = THEMES[themeName] or THEMES.Graphite
    local T = {}
    for k, v in pairs(base) do T[k] = v end
    T.Good, T.Warn, T.Bad = STATUS.Good, STATUS.Warn, STATUS.Bad
    local a = ACCENTS[accentName]
    if a then
        local pick = (base.Light and a.Light) or a

        if base.Accent and accentName == "Mono" then pick = base.Accent end
        T.Accent, T.OnAccent = pick[1], pick[2]
    else
        T.Accent = customColor or ACCENTS.Mono[1]
        T.OnAccent = luma(T.Accent) > 0.6 and rgb(14, 14, 16) or rgb(255, 255, 255)
    end

    if base.Limited and base.Accent then T.Accent, T.OnAccent = base.Accent[1], base.Accent[2] end
    T.Accent2 = T.Accent

    T.Edge = base.Light and rgb(0, 0, 0) or rgb(255, 255, 255)
    return T
end
U.defaultT = buildTokens("Graphite", "Mono")

local notifyGui, notifyHolder
local NOTIFY = {
    Info = {"info", "SubText"}, Success = {"circle-check", "Good"},
    Warning = {"triangle-alert", "Warn"}, Error = {"circle-x", "Bad"},
}

function U.notify(win, opts)
    opts = opts or {}
    local T = win and win.T or U.defaultT
    if not notifyGui or not notifyGui.Parent then
        notifyGui = screenGui("VantaNotify", 200)
        notifyHolder = new("Frame", {
            BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 1),
            Position = UDim2.new(1, -16, 1, -16), Size = UDim2.new(0, 300, 1, -32), Parent = notifyGui,
        }, {new("UIListLayout", {
            Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Bottom,
            HorizontalAlignment = Enum.HorizontalAlignment.Right, SortOrder = Enum.SortOrder.LayoutOrder,
        })})
    end
    local kind = NOTIFY[opts.Type or "Info"] or NOTIFY.Info
    local color = T[kind[2]] or T.SubText
    local duration = opts.Duration or 4

    local slot = new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = notifyHolder})
    local card = new("CanvasGroup", {
        BackgroundColor3 = T.Panel, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        Position = UDim2.new(0, 24, 0, 0), GroupTransparency = 1, Parent = slot,
    }, {corner(8), stroke(T.Stroke, 1, 0)})

    local inner = new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = card},
        {pad(12, 12, 11, 13)})
    local ic = new("ImageLabel", {
        BackgroundTransparency = 1, ImageColor3 = color, Position = UDim2.fromOffset(0, 1), Size = UDim2.fromOffset(16, 16), Parent = inner,
    })
    U.setIcon(ic, opts.Icon or kind[1])
    local body = new("Frame", {
        BackgroundTransparency = 1, Position = UDim2.fromOffset(26, 0), Size = UDim2.new(1, -46, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y, Parent = inner,
    }, {list(2)})
    text({Text = opts.Title or "Notice", FontFace = F.SemiBold, TextSize = 13, TextColor3 = T.Text, LayoutOrder = 1, Parent = body,
        Size = UDim2.new(1, 0, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd})
    if opts.Content and opts.Content ~= "" then
        text({Text = opts.Content, TextColor3 = T.SubText, TextSize = 12, TextWrapped = true, Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = body})
    end
    local bar = new("Frame", {
        BackgroundColor3 = color, BackgroundTransparency = 0.5, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 2), Parent = card,
    })
    local close = new("TextButton", {Text = "", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -6, 0, 6), Size = UDim2.fromOffset(22, 22), ZIndex = 3, Parent = card})
    local cx = new("ImageLabel", {BackgroundTransparency = 1, ImageColor3 = T.Muted, AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(12, 12), Parent = close})
    U.setIcon(cx, "x")

    local gone = false
    local function dismiss()
        if gone then return end
        gone = true
        tween(card, 0.25, {Position = UDim2.new(0, 24, 0, 0), GroupTransparency = 1})

        task.delay(0.22, function()
            if not slot.Parent then return end
            slot.AutomaticSize = Enum.AutomaticSize.None
            slot.Size = UDim2.new(1, 0, 0, slot.AbsoluteSize.Y)
            tween(slot, 0.22, {Size = UDim2.new(1, 0, 0, 0)})
            task.delay(0.25, function() slot:Destroy() end)
        end)
    end
    close.MouseButton1Click:Connect(dismiss)
    close.MouseEnter:Connect(function() tween(cx, 0.12, {ImageColor3 = T.Text}) end)
    close.MouseLeave:Connect(function() tween(cx, 0.15, {ImageColor3 = T.Muted}) end)

    tween(card, 0.2, {GroupTransparency = 0})
    spring(card, 0.45, {Position = UDim2.new(0, 0, 0, 0)})
    tween(bar, duration, {Size = UDim2.new(0, 0, 0, 2)}, Enum.EasingStyle.Linear)
    task.delay(duration, dismiss)

    local items = {}
    for _, c in ipairs(notifyHolder:GetChildren()) do
        if c:IsA("Frame") then table.insert(items, c) end
    end
    if #items > 5 then items[1]:Destroy() end
end

local Window = {}
Window.__index = Window
local Tab = {}
Tab.__index = Tab
local Section = {}
Section.__index = Section

local TOP_H, DOCK_H = 66, 58

local GLASS, GLASS_SOLID = 0.16, 0.05

function Vanta.Notify(selfOrVanta, opts)
    local win = (selfOrVanta ~= Vanta and getmetatable(selfOrVanta) == Window) and selfOrVanta or nil
    U.notify(win, opts)
end

function Window:Notify(opts) U.notify(self, opts) end

function Window:bind(obj, prop, token)
    obj[prop] = self.T[token]
    table.insert(self.Bound, {obj = obj, prop = prop, token = token})
    return obj
end

local function bstroke(win, parent, token, thickness, transparency)
    local s = stroke(win.T[token], thickness, transparency)
    s.Parent = parent
    win:bind(s, "Color", token)
    return s
end

function Window:_tip(target, message)
    if not self.TipBox then
        local box = new("Frame", {Name = "Tip", BackgroundColor3 = self.T.Panel, Visible = false, AutomaticSize = Enum.AutomaticSize.XY,
            Size = UDim2.fromOffset(0, 0), ZIndex = 400, Parent = self.Gui}, {corner(5), pad(9, 9, 6, 6)})
        self:bind(box, "BackgroundColor3", "Panel")
        bstroke(self, box, "Stroke", 1, 0)
        local label = text({Text = "", TextSize = 12, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.XY,
            Size = UDim2.fromOffset(0, 0), ZIndex = 401, Parent = box})
        new("UISizeConstraint", {MaxSize = Vector2.new(260, 400), Parent = label})
        self:bind(label, "TextColor3", "SubText")
        self.TipBox, self.TipLabel, self.TipOwner = box, label, nil
        table.insert(self.Conns, RunService.RenderStepped:Connect(function()
            if not box.Visible then return end
            if not self.Open or not self.TipOwner or not self.TipOwner.Parent then box.Visible = false return end
            local m = UserInputService:GetMouseLocation()
            box.Position = UDim2.fromOffset(m.X + 14, m.Y + 18)
        end))
    end
    local hovering = 0
    target.MouseEnter:Connect(function()
        hovering = hovering + 1
        local mine = hovering
        self.TipOwner = target
        task.delay(0.45, function()
            if hovering == mine and self.TipOwner == target and self.Open then
                self.TipLabel.Text = message
                self.TipBox.Visible = true
            end
        end)
    end)
    target.MouseLeave:Connect(function()
        hovering = hovering + 1
        if self.TipOwner == target then self.TipOwner = nil self.TipBox.Visible = false end
    end)
end

function Window:icon(parent, name, size, color, props)
    props = props or {}
    local img = new("ImageLabel", {
        BackgroundTransparency = 1, AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5),
        Position = props.Position or UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(size, size),
        ZIndex = props.ZIndex or 1, Parent = parent,
    })
    if type(color) == "string" then self:bind(img, "ImageColor3", color) else img.ImageColor3 = color or self.T.Text end
    U.setIcon(img, name)
    return img
end

function Window:_rebuildTokens()
    local fresh = buildTokens(self.ThemeName, self.AccentName, self.CustomAccent)
    for k in pairs(self.T) do self.T[k] = nil end
    for k, v in pairs(fresh) do self.T[k] = v end
end

function Window:_apply(animate)
    for i = #self.Bound, 1, -1 do
        local b = self.Bound[i]
        if not b.obj.Parent then
            table.remove(self.Bound, i)
        elseif animate then
            tween(b.obj, 0.25, {[b.prop] = self.T[b.token]})
        else
            b.obj[b.prop] = self.T[b.token]
        end
    end
    for _, fn in ipairs(self.Redraws) do pcall(fn) end
end

function Window:SetTheme(name)
    if not themeActive(name) then return end
    self.ThemeName = name
    self.ThemeChosen = true
    self:_rebuildTokens()
    self:_apply(true)
    self:_fxSync()
    self:_save()
end

local scene
local SEASONS = {}

local function sceneWanted()
    for _, w in ipairs(U.windows or {}) do
        if not w.Destroyed and w.Open and SEASONS[w.ThemeName] and w.SceneOn ~= false then return w.ThemeName end
    end
    return nil
end

SEASONS.Halloween = {
    logo = "pumpkin", corner = "web", cornerFlip = true, shade = Color3.fromRGB(14, 5, 22),
    build = function(ctx)
        local img, static, holder, rng = ctx.img, ctx.static, ctx.holder, ctx.rng
        local S = {leaves = {}, bats = {}, nextBat = 1.5, nextLeaf = 0}

        S.moon = static(img("moon", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -230, 0, 150), Size = UDim2.fromOffset(210, 210)}), 0.05)

        S.fog = {}
        for _, f in ipairs({{y = 40, h = 210, color = Color3.fromRGB(196, 176, 236), speed = 16, base = 0.55},
                            {y = 70, h = 160, color = Color3.fromRGB(150, 118, 206), speed = -10, base = 0.45}}) do
            local o = static(img("fog", {AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, f.y), Size = UDim2.new(1, 1500, 0, f.h),
                ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(740, f.h), ImageColor3 = f.color, ZIndex = 4}), f.base)
            table.insert(S.fog, {obj = o, y = f.y, speed = f.speed})
        end

        static(img("branch", {Position = UDim2.fromOffset(-30, -18), Size = UDim2.fromOffset(520, 184), ZIndex = 3}), 0)
        local br = static(img("branch", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 34, 0, 34), Size = UDim2.fromOffset(430, 152), ZIndex = 3}), 0)
        flip(br, "branch")
        static(img("web", {Size = UDim2.fromOffset(230, 230), ZIndex = 2}), 0.15)
        local wr = static(img("web", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(190, 190), ZIndex = 2}), 0.25)
        flip(wr, "web")

        S.thread = new("Frame", {BackgroundColor3 = Color3.fromRGB(235, 228, 245), BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0),
            Position = UDim2.new(1, -112, 0, 0), Size = UDim2.fromOffset(1, 90), ZIndex = 3, Parent = holder})
        S.spider = img("spider", {AnchorPoint = Vector2.new(0.5, 0.25), Position = UDim2.new(1, -112, 0, 90), Size = UDim2.fromOffset(34, 34), ZIndex = 3})

        S.pumpkins = {}
        for _, p in ipairs({{x = 0.065, size = 124, rot = -7}, {x = 0.94, size = 96, rot = 6}, {x = 0.115, size = 70, rot = 9}}) do
            local glow = img("glow", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(p.x, 0, 1, -p.size * 0.42 - 10),
                Size = UDim2.fromOffset(p.size * 2.6, p.size * 2.6), ImageColor3 = Color3.fromRGB(255, 136, 36), ZIndex = 5})
            static(img("pumpkin", {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(p.x, 0, 1, -10), Size = UDim2.fromOffset(p.size, p.size * 0.9),
                Rotation = p.rot, ZIndex = 6}), 0)
            table.insert(S.pumpkins, {glow = glow, seed = rng:NextNumber(0, 50)})
        end

        S.ghosts = {}
        for i, g in ipairs({{x = 0.075, y = 0.52, size = 78}, {x = 0.925, y = 0.6, size = 62}}) do
            local o = img("ghost", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(g.x, g.y), Size = UDim2.fromOffset(g.size, g.size * 0.95), ZIndex = 4})
            table.insert(S.ghosts, {obj = o, x = g.x, y = g.y, phase = i * 2.4})
        end

        local LEAVES = {"leaf_maple", "leaf_red", "leaf_oak", "leaf_maple"}

        return function(t, v, dt, vp, want)
            for _, f in ipairs(S.fog) do
                f.obj.Position = UDim2.new(0, -((t * f.speed) % 740 + 740) % 740, 1, f.y)
            end
            S.moon.Size = UDim2.fromOffset(210 + math.sin(t * 0.8) * 6, 210 + math.sin(t * 0.8) * 6)
            for _, p in ipairs(S.pumpkins) do
                local flicker = 0.55 + math.noise(t * 2.6, p.seed) * 0.5
                p.glow.ImageTransparency = 1 - math.clamp(flicker, 0.2, 0.9) * v
            end

            local len = 96 + math.sin(t * 0.55) * 52
            S.thread.Size = UDim2.fromOffset(1, len)
            S.thread.BackgroundTransparency = 1 - 0.55 * v
            S.spider.Position = UDim2.new(1, -112, 0, len)
            S.spider.Rotation = math.sin(t * 1.7) * 7
            S.spider.ImageTransparency = 1 - v

            for _, g in ipairs(S.ghosts) do
                local a = math.clamp(math.sin(t * 0.33 + g.phase) * 1.3, 0, 0.82)
                g.obj.ImageTransparency = 1 - a * v
                g.obj.Position = UDim2.new(g.x, math.sin(t * 0.7 + g.phase) * 10, g.y, math.sin(t * 1.3 + g.phase) * 12)
                g.obj.Rotation = math.sin(t * 0.9 + g.phase) * 5
            end

            S.nextBat = S.nextBat - dt
            if want and S.nextBat <= 0 and #S.bats < 4 then
                S.nextBat = rng:NextNumber(2.2, 5.5)
                local dir = rng:NextNumber() < 0.5 and 1 or -1
                local size = rng:NextNumber(42, 84)
                local b = {dir = dir, x = dir == 1 and -size or vp.X + size, y = rng:NextNumber(0.13, 0.45) * vp.Y, size = size,
                    speed = rng:NextNumber(120, 190) * (size / 70), phase = rng:NextNumber(0, 6), amp = rng:NextNumber(8, 22)}
                b.obj = img("bat_up", {AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(size, size * 0.6), ZIndex = 5})
                table.insert(S.bats, b)
            end
            for i = #S.bats, 1, -1 do
                local b = S.bats[i]
                b.x = b.x + b.dir * b.speed * dt
                local up = math.floor(t * 9 + b.phase) % 2 == 0
                b.obj.Image = U.art(up and "bat_up" or "bat_down") or ""
                b.obj.Position = UDim2.fromOffset(b.x, b.y + math.sin(t * 2.4 + b.phase) * b.amp)
                b.obj.Rotation = math.sin(t * 2.4 + b.phase) * 8
                b.obj.ImageTransparency = 1 - v
                if b.x < -b.size * 2 or b.x > vp.X + b.size * 2 then
                    b.obj:Destroy()
                    table.remove(S.bats, i)
                end
            end

            S.nextLeaf = S.nextLeaf - dt
            if want and S.nextLeaf <= 0 and #S.leaves < 16 then
                S.nextLeaf = rng:NextNumber(0.35, 0.9)
                local size = rng:NextNumber(15, 30)
                local l = {x0 = rng:NextNumber(0, vp.X), y = -size, size = size, vy = rng:NextNumber(38, 72), amp = rng:NextNumber(18, 50),
                    freq = rng:NextNumber(0.5, 1.1), phase = rng:NextNumber(0, 6), spin = rng:NextNumber(-80, 80), rot = rng:NextNumber(0, 360)}
                l.obj = img(LEAVES[rng:NextInteger(1, #LEAVES)], {AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(size, size * 0.95), ZIndex = 5})
                table.insert(S.leaves, l)
            end
            for i = #S.leaves, 1, -1 do
                local l = S.leaves[i]
                l.y = l.y + l.vy * dt
                l.rot = l.rot + l.spin * dt
                local sway = math.sin(t * l.freq + l.phase)
                l.obj.Position = UDim2.fromOffset(l.x0 + sway * l.amp, l.y)
                l.obj.Rotation = l.rot + sway * 25
                l.obj.ImageTransparency = 1 - 0.95 * v
                if l.y > vp.Y + 40 then
                    l.obj:Destroy()
                    table.remove(S.leaves, i)
                end
            end
        end
    end,
}

local WIRE_W, WIRE_TOP, WIRE_CTRL = 220, 6, 86
local LIGHT_COLORS = {
    Color3.fromRGB(255, 70, 80), Color3.fromRGB(255, 200, 70), Color3.fromRGB(70, 220, 120),
    Color3.fromRGB(80, 160, 255), Color3.fromRGB(255, 236, 200),
}

SEASONS.Christmas = {
    logo = "x_logo", corner = "x_frost", cornerFlip = false, shade = Color3.fromRGB(5, 14, 32),
    build = function(ctx)
        local img, static, holder, rng = ctx.img, ctx.static, ctx.holder, ctx.rng
        local S = {dots = {}, flakes = {}, trail = {}, nextDot = 0, nextFlake = 0, nextSleigh = 4}
        local cam = workspace.CurrentCamera
        local width = ((cam and cam.ViewportSize.X) or 1920) + WIRE_W

        S.moon = static(img("moon", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -250, 0, 200), Size = UDim2.fromOffset(190, 190),
            ImageColor3 = Color3.fromRGB(214, 228, 255)}), 0.1)

        static(img("x_wire", {Size = UDim2.new(0, width, 0, 60), Position = UDim2.fromOffset(0, -2), ScaleType = Enum.ScaleType.Tile,
            TileSize = UDim2.fromOffset(WIRE_W, 60), ZIndex = 5}), 0)
        S.bulbs = {}
        local n = 0
        for span = 0, math.ceil(width / WIRE_W) do
            for _, f in ipairs({0.2, 0.5, 0.8}) do
                n = n + 1
                local x = span * WIRE_W + f * WIRE_W
                local y = (1 - f) ^ 2 * WIRE_TOP + 2 * f * (1 - f) * WIRE_CTRL + f ^ 2 * WIRE_TOP - 2
                local slope = (2 * (1 - f) * (WIRE_CTRL - WIRE_TOP) + 2 * f * (WIRE_TOP - WIRE_CTRL)) / WIRE_W
                local color = LIGHT_COLORS[(n - 1) % #LIGHT_COLORS + 1]
                local glow = img("glow", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x, y + 14), Size = UDim2.fromOffset(46, 46),
                    ImageColor3 = color, ZIndex = 5})
                local bulb = img("x_bulb", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(13, 18),
                    Rotation = math.deg(math.atan(slope)) * 0.6, ImageColor3 = color, ZIndex = 6})
                table.insert(S.bulbs, {glow = glow, bulb = bulb, color = color, phase = rng:NextNumber(0, 6), rate = rng:NextNumber(1.2, 2.6)})
            end
        end

        static(img("x_pine", {Position = UDim2.fromOffset(-34, -26), Size = UDim2.fromOffset(540, 191), ZIndex = 7}), 0)
        local pr = static(img("x_pine", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 34, 0, -16), Size = UDim2.fromOffset(450, 159), ZIndex = 7}), 0)
        flip(pr, "x_pine")

        S.baubles = {}
        for _, b in ipairs({
            {sx = 0, x = 96, y = 62, len = 44, size = 30, color = Color3.fromRGB(226, 46, 62)},
            {sx = 0, x = 214, y = 74, len = 70, size = 26, color = Color3.fromRGB(255, 196, 70)},
            {sx = 0, x = 338, y = 70, len = 36, size = 22, color = Color3.fromRGB(80, 150, 255)},
            {sx = 1, x = -112, y = 56, len = 52, size = 28, color = Color3.fromRGB(255, 196, 70)},
            {sx = 1, x = -250, y = 66, len = 34, size = 24, color = Color3.fromRGB(226, 46, 62)},
        }) do
            local thread = new("Frame", {BackgroundColor3 = Color3.fromRGB(235, 225, 190), BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
                Size = UDim2.fromOffset(1, b.len), ZIndex = 8, Parent = holder})
            local orn = img("x_ornament", {AnchorPoint = Vector2.new(0.5, 0.2), Size = UDim2.fromOffset(b.size, b.size), ImageColor3 = b.color, ZIndex = 8})
            table.insert(S.baubles, {b = b, thread = thread, orn = orn, phase = rng:NextNumber(0, 6)})
        end

        static(img("x_drift", {AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 18), Size = UDim2.new(1, 0, 0, 130),
            ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(560, 130), ZIndex = 9}), 0)
        S.giftGlow = img("glow", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.075, 0, 1, -80), Size = UDim2.fromOffset(330, 330),
            ImageColor3 = Color3.fromRGB(255, 196, 110), ZIndex = 8})
        static(img("x_cane", {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.13, 0, 1, -36), Size = UDim2.fromOffset(60, 79), Rotation = 14, ZIndex = 9}), 0)
        static(img("x_gifts", {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.07, 0, 1, -30), Size = UDim2.fromOffset(160, 132), ZIndex = 10}), 0)
        static(img("x_snowman", {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.935, 0, 1, -34), Size = UDim2.fromOffset(118, 156), ZIndex = 10}), 0)

        return function(t, v, dt, vp, want)
            S.moon.Size = UDim2.fromOffset(190 + math.sin(t * 0.7) * 5, 190 + math.sin(t * 0.7) * 5)
            S.giftGlow.ImageTransparency = 1 - (0.32 + math.noise(t * 1.4, 3.1) * 0.12) * v

            for _, b in ipairs(S.bulbs) do
                local lit = 0.55 + 0.45 * math.sin(t * b.rate + b.phase)
                b.glow.ImageTransparency = 1 - (0.2 + lit * 0.55) * v
                b.bulb.ImageColor3 = b.color:Lerp(Color3.new(1, 1, 1), lit * 0.35)
                b.bulb.ImageTransparency = 1 - v
            end

            for _, o in ipairs(S.baubles) do
                local b = o.b
                local ax = b.sx == 1 and vp.X + b.x or b.x
                local a = math.sin(t * 1.3 + o.phase) * 0.14
                local ex, ey = ax + math.sin(a) * b.len, b.y + math.cos(a) * b.len
                o.thread.Position = UDim2.fromOffset((ax + ex) / 2, (b.y + ey) / 2)
                o.thread.Rotation = -math.deg(a)
                o.thread.BackgroundTransparency = 1 - 0.6 * v
                o.orn.Position = UDim2.fromOffset(ex, ey)
                o.orn.Rotation = -math.deg(a)
                o.orn.ImageTransparency = 1 - v
            end

            S.nextDot = S.nextDot - dt
            while want and S.nextDot <= 0 and #S.dots < 90 do
                S.nextDot = S.nextDot + 0.05
                local depth = rng:NextNumber(0.3, 1)
                local size = 2 + depth * 4
                local d = {x0 = rng:NextNumber(-40, vp.X + 40), y = -10, vy = 22 + depth * 48, amp = rng:NextNumber(8, 30), freq = rng:NextNumber(0.4, 1),
                    phase = rng:NextNumber(0, 6), alpha = 0.35 + depth * 0.55}
                d.obj = new("Frame", {BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
                    Size = UDim2.fromOffset(size, size), ZIndex = depth > 0.75 and 11 or 4, Parent = holder}, {corner(size)})
                table.insert(S.dots, d)
            end
            if S.nextDot < -1 then S.nextDot = 0 end
            for i = #S.dots, 1, -1 do
                local d = S.dots[i]
                d.y = d.y + d.vy * dt
                d.obj.Position = UDim2.fromOffset(d.x0 + math.sin(t * d.freq + d.phase) * d.amp, d.y)
                d.obj.BackgroundTransparency = 1 - d.alpha * v
                if d.y > vp.Y + 10 then d.obj:Destroy() table.remove(S.dots, i) end
            end
            S.nextFlake = S.nextFlake - dt
            if want and S.nextFlake <= 0 and #S.flakes < 10 then
                S.nextFlake = rng:NextNumber(0.8, 1.8)
                local size = rng:NextNumber(12, 24)
                local f = {x0 = rng:NextNumber(0, vp.X), y = -size, vy = rng:NextNumber(30, 55), amp = rng:NextNumber(15, 40), freq = rng:NextNumber(0.4, 0.9),
                    phase = rng:NextNumber(0, 6), spin = rng:NextNumber(-50, 50), rot = rng:NextNumber(0, 60)}
                f.obj = img(rng:NextNumber() < 0.5 and "x_flake1" or "x_flake2", {AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(size, size), ZIndex = 11})
                table.insert(S.flakes, f)
            end
            for i = #S.flakes, 1, -1 do
                local f = S.flakes[i]
                f.y = f.y + f.vy * dt
                f.rot = f.rot + f.spin * dt
                f.obj.Position = UDim2.fromOffset(f.x0 + math.sin(t * f.freq + f.phase) * f.amp, f.y)
                f.obj.Rotation = f.rot
                f.obj.ImageTransparency = 1 - 0.85 * v
                if f.y > vp.Y + 30 then f.obj:Destroy() table.remove(S.flakes, i) end
            end

            S.nextSleigh = S.nextSleigh - dt
            if want and S.nextSleigh <= 0 and not S.sleigh then
                S.nextSleigh = rng:NextNumber(14, 26)
                local y = rng:NextNumber(0.1, 0.24) * vp.Y
                S.sleigh = {x = -240, y0 = y, speed = rng:NextNumber(150, 200)}
                S.sleigh.obj = img("x_sleigh", {AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(230, 74), ZIndex = 3})
                S.sleigh.nextSpark = 0
            end
            local sl = S.sleigh
            if sl then
                sl.x = sl.x + sl.speed * dt
                local y = sl.y0 - (sl.x / vp.X) * 40 + math.sin(t * 2) * 6
                sl.obj.Position = UDim2.fromOffset(sl.x, y)
                sl.obj.Rotation = -4 + math.sin(t * 2) * 1.5
                sl.obj.ImageTransparency = 1 - 0.9 * v
                sl.nextSpark = sl.nextSpark - dt
                if sl.nextSpark <= 0 then
                    sl.nextSpark = 0.04
                    local sp = new("Frame", {BackgroundColor3 = Color3.fromRGB(255, 220, 130), BackgroundTransparency = 0.1, AnchorPoint = Vector2.new(0.5, 0.5),
                        Position = UDim2.fromOffset(sl.x - 100 + rng:NextNumber(-6, 6), y + 26 + rng:NextNumber(-5, 5)), Size = UDim2.fromOffset(3, 3),
                        ZIndex = 3, Parent = holder}, {corner(2)})
                    table.insert(S.trail, {obj = sp, life = 1.1, age = 0, vy = rng:NextNumber(8, 22)})
                end
                if sl.x > vp.X + 260 then sl.obj:Destroy() S.sleigh = nil end
            end
            for i = #S.trail, 1, -1 do
                local p = S.trail[i]
                p.age = p.age + dt
                local k = p.age / p.life
                p.obj.Position = p.obj.Position + UDim2.fromOffset(0, p.vy * dt)
                p.obj.BackgroundTransparency = 1 - (1 - k) * 0.9 * v
                if k >= 1 then p.obj:Destroy() table.remove(S.trail, i) end
            end
        end
    end,
}

local function buildScene(kind)
    local season = SEASONS[kind]
    local S = {kind = kind, want = false, vis = 0, t = 0, items = {}}
    local gui = screenGui("VantaScene", 140)
    S.gui = gui
    local holder = new("Frame", {BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = gui})

    local function img(name, props)
        local i = new("ImageLabel", {BackgroundTransparency = 1, Image = U.art(name) or "", ImageTransparency = 1, Parent = holder})
        for k, v in pairs(props or {}) do i[k] = v end
        return i
    end

    local function static(obj, base, prop)
        table.insert(S.items, {obj = obj, base = base or 0, prop = prop or "ImageTransparency"})
        return obj
    end

    local function shade(props, rot, base)
        local f = new("Frame", {BackgroundColor3 = season.shade, BackgroundTransparency = 1, Parent = holder})
        for k, v in pairs(props) do f[k] = v end
        new("UIGradient", {Rotation = rot, Transparency = NumberSequence.new(0, 1), Parent = f})
        static(f, base, "BackgroundTransparency")
    end
    shade({Size = UDim2.fromScale(1, 0.32)}, 90, 0.35)
    shade({AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0.4)}, -90, 0.25)
    shade({Size = UDim2.fromScale(0.2, 1)}, 0, 0.45)
    shade({AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromScale(0.2, 1)}, 180, 0.45)

    local update = season.build({img = img, static = static, holder = holder, rng = Random.new()})
    local cam = workspace.CurrentCamera

    S.conn = RunService.RenderStepped:Connect(function(dt)
        local target = S.want and 1 or 0
        if S.vis == 0 and target == 0 then
            if gui.Enabled then gui.Enabled = false end
            if #(U.windows or {}) == 0 or S.retired then
                S.conn:Disconnect()
                gui:Destroy()
                if scene == S then scene = nil end
            end
            return
        end
        gui.Enabled = true
        if target > S.vis then S.vis = math.min(S.vis + dt * 2.2, 1) else S.vis = math.max(S.vis - dt * 3, 0) end
        S.t = S.t + dt
        for _, it in ipairs(S.items) do it.obj[it.prop] = 1 - (1 - it.base) * S.vis end
        update(S.t, S.vis, dt, (cam and cam.ViewportSize) or Vector2.new(1280, 720), S.want)
    end)
    return S
end

function U.sceneSync()
    local want = sceneWanted()

    if scene and want and scene.kind ~= want then
        scene.want, scene.retired = false, true
        scene = nil
    end
    if want and not scene then
        local ok, res = pcall(buildScene, want)
        if ok then scene = res else warn("[vanta] scene: " .. tostring(res)) end
    end
    if scene then scene.want = want ~= nil end
end

function Window:_fxStop() end
function Window:_fxStart() end

function Window:_fxSync()
    local season = SEASONS[self.ThemeName]
    local logo = season and U.art(season.logo) or nil
    local function mark(art, icon)
        if not art then return end
        art.Image = logo or ""
        art.Visible = logo ~= nil
        if icon then icon.Visible = logo == nil end
    end
    mark(self.BrandArt, self.BrandMark)
    if self.Dock then mark(self.Dock.art, self.Dock.mark) end
    if self.CornerWeb then
        local corner = season and U.art(season.corner) or nil
        self.CornerWeb.Image = corner or ""
        self.CornerWeb.Visible = corner ~= nil
        if season and season.cornerFlip then
            flip(self.CornerWeb, season.corner)
        else
            self.CornerWeb.ImageRectOffset, self.CornerWeb.ImageRectSize = Vector2.zero, Vector2.zero
        end
    end
    U.sceneSync()
end

function Window:_dockBuild(opts)
    self.DockOn = opts.Dock ~= false
    if not U.hudBar or not U.hudBar.Parent then
        local hud = screenGui("VantaHud", 160)
        U.hudBar = new("Frame", {BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10),
            Size = UDim2.fromOffset(0, 32), AutomaticSize = Enum.AutomaticSize.X, Parent = hud},
            {list(8, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)})
    end
    local btn = new("TextButton", {Name = self.Title, Text = "", AutoButtonColor = false, BackgroundColor3 = self.T.Panel, BackgroundTransparency = 0.15,
        Size = UDim2.fromOffset(0, 32), AutomaticSize = Enum.AutomaticSize.X, Visible = self.DockOn, LayoutOrder = #U.windows, Parent = U.hudBar},
        {corner(16), pad(9, 14, 0, 0), list(8, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)})
    self:bind(btn, "BackgroundColor3", "Panel")
    local edge = bstroke(self, btn, "Edge", 1, 0.86)
    local markHolder = new("Frame", {BackgroundTransparency = 1, Size = UDim2.fromOffset(18, 18), LayoutOrder = 1, Parent = btn})
    local mark = self:icon(markHolder, opts.Icon or "layout-grid", 14, "Accent")
    local art = new("ImageLabel", {BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(22, 20), Visible = false, Parent = markHolder})
    local name = text({Text = self.Title, FontFace = F.SemiBold, TextSize = 12, Size = UDim2.fromOffset(0, 16), AutomaticSize = Enum.AutomaticSize.X,
        LayoutOrder = 2, Parent = btn})
    self:bind(name, "TextColor3", "Text")
    local dot = new("Frame", {Size = UDim2.fromOffset(6, 6), BackgroundColor3 = self.T.Muted, LayoutOrder = 3, Parent = btn}, {corner(3)})
    local timer = text({Text = "0m", FontFace = F.Medium, TextSize = 11, Size = UDim2.fromOffset(0, 16), AutomaticSize = Enum.AutomaticSize.X,
        LayoutOrder = 4, Parent = btn})
    self:bind(timer, "TextColor3", "SubText")
    self.Dock = {btn = btn, mark = mark, art = art, dot = dot, timer = timer, edge = edge, shown = self.DockOn, badge = false}

    local function paintDot()
        local TT = self.T
        tween(dot, 0.2, {BackgroundColor3 = self.Dock.badge and TT.Good or (self.Open and TT.Accent or TT.Muted)})
    end
    self.Dock.paint = paintDot
    table.insert(self.Redraws, paintDot)
    paintDot()

    btn.MouseEnter:Connect(function()
        tween(edge, 0.12, {Transparency = 0.6})
        tween(btn, 0.12, {BackgroundTransparency = 0.04})
    end)
    btn.MouseLeave:Connect(function()
        tween(edge, 0.15, {Transparency = 0.86})
        tween(btn, 0.15, {BackgroundTransparency = 0.15})
    end)
    btn.MouseButton1Click:Connect(function() self:SetOpen(not self.Open) end)

    local started = os.clock()
    task.spawn(function()
        while not self.Destroyed do
            local m = math.floor((os.clock() - started) / 60)
            timer.Text = m < 60 and (m .. "m") or string.format("%dh %dm", math.floor(m / 60), m % 60)
            task.wait(5)
        end
    end)
end

local TOP_CLEAR, EDGE = 64, 12

function Window:_screen()
    local cam = workspace.CurrentCamera
    local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
    local s = self:_scale()
    return vp, self.Root.Size.X.Offset * s, self.Root.Size.Y.Offset * s
end

function Window:_clampCentre(cx, cy)
    local vp, w, h = self:_screen()
    cx = math.clamp(cx, w / 2 + EDGE, math.max(w / 2 + EDGE, vp.X - w / 2 - EDGE))
    cy = math.clamp(cy, h / 2 + TOP_CLEAR, math.max(h / 2 + TOP_CLEAR, vp.Y - h / 2 - EDGE))
    return cx, cy
end

function Window:_moveCentre(cx, cy)
    local vp = self:_screen()
    cx, cy = self:_clampCentre(cx, cy)
    local was = self.Dragged
    self.Dragged = false
    self.Root.Position = UDim2.new(0.5, math.floor(cx - vp.X / 2 + 0.5), 0.5, math.floor(cy - vp.Y / 2 + 0.5))
    self.HomePos = self.Root.Position
    self.Dragged = was
end

function Window:_place()
    local vp, w, h = self:_screen()

    local saved = self.Saved.__spot
    if type(saved) == "table" and tonumber(saved.x) and tonumber(saved.y) then
        self.PosSaved = {x = tonumber(saved.x), y = tonumber(saved.y)}
        self:_moveCentre(vp.X / 2 + saved.x, vp.Y / 2 + saved.y)
        return
    end
    local others = {}
    for _, o in ipairs(U.windows or {}) do
        if o ~= self and not o.Destroyed and o.Open and o.Root and o.Root.Visible then
            table.insert(others, {c = o.Root.AbsolutePosition + o.Root.AbsoluteSize / 2, size = o.Root.AbsoluteSize})
        end
    end
    local function free(x, y)
        for _, r in ipairs(others) do
            if math.abs(x - r.c.X) < (w + r.size.X) / 2 + 8 and math.abs(y - r.c.Y) < (h + r.size.Y) / 2 + 8 then return false end
        end
        return true
    end
    local spots = {{vp.X / 2, vp.Y / 2}}
    for _, r in ipairs(others) do
        table.insert(spots, {r.c.X + (r.size.X + w) / 2 + 16, r.c.Y})
        table.insert(spots, {r.c.X - (r.size.X + w) / 2 - 16, r.c.Y})
        table.insert(spots, {r.c.X, r.c.Y + (r.size.Y + h) / 2 + 16})
    end
    for _, spot in ipairs(spots) do
        local x, y = self:_clampCentre(spot[1], spot[2])
        if free(x, y) then self:_moveCentre(x, y) return end
    end

    local last = others[#others]
    self:_moveCentre(last.c.X + 36, last.c.Y + 36)
end

function Window:_keepOnScreen()
    local c = self.Root.AbsolutePosition + self.Root.AbsoluteSize / 2
    self:_moveCentre(c.X, c.Y)
end

function Window:ResetPosition()
    self.PosSaved, self.Saved.__spot = nil, nil
    self:_place()
    self:_save()
end

function Window:SetBadge(on)
    local d = self.Dock
    if not d then return end
    d.badge = on == true
    d.paint()
end

function Window:_dockSync()
    local d = self.Dock
    if not d then return end
    d.btn.Visible = self.DockOn == true and not self.Destroyed
    d.paint()
end

function Window:SetAccent(a)
    if type(a) == "string" and ACCENTS[a] then
        self.AccentName, self.CustomAccent = a, nil
    elseif typeof(a) == "Color3" then
        self.AccentName, self.CustomAccent = nil, a
    else
        return
    end
    self:_rebuildTokens()
    self:_apply(true)
    self:_save()
end

function Window:SetKey(key)
    if typeof(key) == "EnumItem" and key.EnumType == Enum.KeyCode then
        self.Key = key
        self:_save()
    end
end

function Window:SetScale(v)
    self.UserScale = math.clamp(tonumber(v) or 1, 0.6, 1.5)
    if self.Open then tween(self.Scale, 0.25, {Scale = self:_scale()}) end
    self:_save()
end

function Window:_scale() return (self.BaseScale or 1) * (self.UserScale or 1) end

function Window:_flush()
    if not self.ConfigPath then return end
    local out = {}
    for k, v in pairs(self.Saved) do out[k] = v end
    for flag, f in pairs(self.Flags) do
        local ok, v = pcall(f.Save)
        if ok and v ~= nil then out[flag] = v end
    end
    out.__accent = self.AccentName
    if self.ThemeChosen then out.__theme = self.ThemeName end
    if self.DockPos then out.__dock = self.DockPos end
    if self.PosSaved then out.__spot = self.PosSaved end
    out.__key, out.__scale, out.__frost = self.Key and self.Key.Name, self.UserScale, self.BlurPref
    local ok, json = pcall(HttpService.JSONEncode, HttpService, out)
    if ok then fs.write(self.ConfigPath, json) end
end

function Window:_save()
    if not self.ConfigPath or self.Loading then return end
    self.SaveQueued = true
    if self.SaveRunning then return end
    self.SaveRunning = true
    task.delay(0.8, function()
        self.SaveRunning = false
        if not self.SaveQueued or self.Destroyed then return end
        self.SaveQueued = false
        self:_flush()
    end)
end

function Window:_flag(flag, get, set, save, load)
    if not flag then return nil end
    self.Flags[flag] = {Get = get, Set = set, Save = save or get}
    local saved = self.Saved[flag]
    if saved ~= nil then
        local ok, v = pcall(load or function(x) return x end, saved)
        if ok and v ~= nil then return v end
    end
    return nil
end

function Window:_index(tab, name, desc, row, sec)
    if not name or name == "" then return end
    table.insert(self.Index, {name = tostring(name), desc = tostring(desc or ""), tab = tab, row = row, sec = sec})
end

function Window:_flash(row)
    if not row.Parent then return end
    local prevColor = row.BackgroundColor3
    row.BackgroundColor3 = self.T.Accent
    tween(row, 0.1, {BackgroundTransparency = 0.82})
    task.delay(0.9, function()
        if not row.Parent then return end
        tween(row, 0.5, {BackgroundTransparency = 1}).Completed:Connect(function()
            if row.Parent then row.BackgroundColor3 = self.T.Hover end
        end)
    end)
end

function Vanta:Window(opts)
    opts = opts or {}

    plr = Players.LocalPlayer or plr
    while not plr do task.wait() plr = Players.LocalPlayer end
    U.loadFonts()
    local self = setmetatable({}, Window)
    self.Title = opts.Title or "Vanta"
    self.Subtitle = opts.Subtitle or ""
    self.Key = (typeof(opts.Key) == "EnumItem" and opts.Key.EnumType == Enum.KeyCode) and opts.Key or Enum.KeyCode.RightControl
    self.OnDestroy = opts.OnDestroy
    self.Tabs, self.Flags, self.Conns, self.Bound = {}, {}, {}, {}
    self.Redraws, self.Index, self.Binds, self.SideLabels = {}, {}, {}, {}
    self.Toggles = {}
    U.windows = U.windows or {}
    table.insert(U.windows, self)
    self.Open, self.Destroyed, self.OrderCount = true, false, 0
    self.UserScale, self.BlurPref = 1, opts.Blur ~= false
    self.SideCollapsed = false

    self.ThemeName = seasonTheme() or (themeActive(opts.Theme) and opts.Theme or "Obsidian")
    self.AccentName = ACCENTS[opts.Accent] and opts.Accent or "Mono"

    self.ConfigPath = opts.Config and (tostring(opts.Config) .. "/settings.json") or nil
    self.Saved = {}
    if self.ConfigPath then
        local raw = fs.read(self.ConfigPath)
        if raw then
            local ok, data = pcall(HttpService.JSONDecode, HttpService, raw)
            if ok and type(data) == "table" then self.Saved = data end
        end
        local s = self.Saved
        if type(s.__theme) == "string" and themeActive(s.__theme) then self.ThemeName = s.__theme end

        if seasonTheme() then self.ThemeName = seasonTheme() end

        self.ThemeChosen = type(s.__theme) == "string" and s.__theme == self.ThemeName
        if type(s.__accent) == "string" and ACCENTS[s.__accent] then self.AccentName = s.__accent end
        if type(s.__key) == "string" then
            local ok, k = pcall(function() return Enum.KeyCode[s.__key] end)
            if ok and k then self.Key = k end
        end
        if type(s.__scale) == "number" then self.UserScale = math.clamp(s.__scale, 0.6, 1.5) end
        if type(s.__frost) == "boolean" then self.BlurPref = s.__frost end
    end

    self.T = {}
    self:_rebuildTokens()
    local T = self.T

    local size = opts.Size or UDim2.fromOffset(720, 486)
    local gui = screenGui("Vanta_" .. HttpService:GenerateGUID(false):sub(1, 8), 150)
    self.Gui = gui

    local root = new("Frame", {
        Name = "Window", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5), Size = size, Parent = gui,
    })
    self.Root = root
    self.Scale = new("UIScale", {Scale = 1, Parent = root})

    local function fit()
        local cam = workspace.CurrentCamera
        if not cam then return end
        local vp = cam.ViewportSize
        local w, h = self.Root.Size.X.Offset, self.Root.Size.Y.Offset
        self.BaseScale = math.max(math.min(1, (vp.X - 24) / w, (vp.Y - 70) / h), 0.45)
        if self.Open and self.Booted then
            self.Scale.Scale = self:_scale()
            task.defer(function() if not self.Destroyed then self:_keepOnScreen() end end)
        end
    end
    if workspace.CurrentCamera then
        table.insert(self.Conns, workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit))
    end

    self.Shadow = new("ImageLabel", {
        Name = "Shadow", BackgroundTransparency = 1, Image = U.assets.Glow, ImageColor3 = Color3.new(0, 0, 0),
        ImageTransparency = 0.45, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 14),
        Size = UDim2.new(1, 120, 1, 120), ZIndex = 0, Parent = root,
    })

    local body = new("CanvasGroup", {
        Name = "Body", BackgroundColor3 = T.Background, BackgroundTransparency = self.BlurPref and GLASS or GLASS_SOLID, Size = UDim2.fromScale(1, 1),
        GroupTransparency = 1, Parent = root,
    }, {corner(18)})
    self:bind(body, "BackgroundColor3", "Background")
    self.Body = body
    self.Content = body

    local sheen = new("Frame", {Name = "Sheen", BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(1, 0.55), Parent = body})
    new("UIGradient", {Rotation = 90, Transparency = NumberSequence.new(0.95, 1), Parent = sheen})
    self.CornerWeb = new("ImageLabel", {Name = "Web", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0),
        Size = UDim2.fromOffset(120, 120), ImageTransparency = 0.8, Visible = false, Parent = body})
    flip(self.CornerWeb, "web")

    local border = new("Frame", {Name = "Border", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 30, Parent = root}, {corner(18)})
    bstroke(self, border, "Edge", 1, 0.86)
    self.Border = border
    self.PaintShimmer = function() end

    local grab = new("Frame", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 7), Size = UDim2.fromOffset(38, 4),
        BackgroundColor3 = T.Muted, BackgroundTransparency = 0.5, ZIndex = 5, Parent = body}, {corner(2)})
    self:bind(grab, "BackgroundColor3", "Muted")

    local header = new("Frame", {Name = "Header", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, 0, 0, 40),
        ZIndex = 5, Parent = body})
    self.Topbar = header
    local left = new("Frame", {BackgroundTransparency = 1, Position = UDim2.fromOffset(22, 0), Size = UDim2.new(1, -300, 1, 0), ZIndex = 5, Parent = header},
        {list(9, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)})
    local tile = new("Frame", {BackgroundTransparency = 1, Size = UDim2.fromOffset(26, 26), LayoutOrder = 1, ZIndex = 5, Parent = left})
    self.BrandTile = tile
    self.BrandMark = self:icon(tile, opts.Icon or "layout-grid", 20, "Accent", {ZIndex = 6})
    self.BrandArt = new("ImageLabel", {BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(30, 27), Visible = false, ZIndex = 6, Parent = tile})
    local titleLbl = text({Text = self.Title, FontFace = F.SemiBold, TextSize = 17, Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X,
        LayoutOrder = 2, ZIndex = 5, Parent = left})
    self:bind(titleLbl, "TextColor3", "Text")

    local version = self.Subtitle:match("^(v[%w%.%-]+)")
    local rest = self.Subtitle
    if version then rest = self.Subtitle:sub(#version + 1):gsub("^%s*·%s*", ""):gsub("^%s+", "") end
    if version then
        local tag = new("Frame", {BackgroundColor3 = T.Accent, BackgroundTransparency = 0.82, Size = UDim2.fromOffset(0, 18), AutomaticSize = Enum.AutomaticSize.X,
            LayoutOrder = 3, ZIndex = 5, Parent = left}, {corner(9), pad(7, 7, 0, 0)})
        self:bind(tag, "BackgroundColor3", "Accent")
        local tl = text({Text = string.upper(version), FontFace = F.SemiBold, TextSize = 9, Size = UDim2.fromOffset(0, 18),
            AutomaticSize = Enum.AutomaticSize.X, ZIndex = 6, Parent = tag})
        self:bind(tl, "TextColor3", "Accent")
    end
    if rest ~= "" then
        local sl = text({Text = rest, TextSize = 12, Size = UDim2.fromOffset(0, 18), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 4, ZIndex = 5, Parent = left})
        self:bind(sl, "TextColor3", "Muted")
    end

    local closeBtn = new("TextButton", {Text = "", AutoButtonColor = false, BackgroundColor3 = T.Hover, BackgroundTransparency = 0.5,
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -20, 0.5, 0), Size = UDim2.fromOffset(32, 32), ZIndex = 6, Parent = header}, {corner(16)})
    self:bind(closeBtn, "BackgroundColor3", "Hover")
    bstroke(self, closeBtn, "Edge", 1, 0.88)
    local closeIcon = self:icon(closeBtn, "x", 14, "SubText", {ZIndex = 7})
    closeBtn.MouseEnter:Connect(function()
        tween(closeBtn, 0.1, {BackgroundTransparency = 0.15})
        tween(closeIcon, 0.1, {ImageColor3 = self.T.Text})
    end)
    closeBtn.MouseLeave:Connect(function()
        tween(closeBtn, 0.15, {BackgroundTransparency = 0.5})
        tween(closeIcon, 0.15, {ImageColor3 = self.T.SubText})
    end)
    closeBtn.MouseButton1Click:Connect(function()
        self:SetOpen(false)
        local how = self.DockOn and ("Hidden. Click " .. self.Title .. " at the top or press " .. keyName(self.Key) .. " to bring it back.")
            or ("Hidden. Press " .. keyName(self.Key) .. " to bring it back.")
        Vanta.Notify(self, {Title = self.Title, Content = how, Icon = "eye-off"})
    end)

    local searchWrap = new("Frame", {BackgroundColor3 = T.Hover, BackgroundTransparency = 0.5, AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -62, 0.5, 0), Size = UDim2.fromOffset(200, 32), ZIndex = 6, Parent = header}, {corner(16)})
    self:bind(searchWrap, "BackgroundColor3", "Hover")
    self.SearchWrap = searchWrap
    self.SearchStroke = bstroke(self, searchWrap, "Edge", 1, 0.88)
    self.SearchIcon = self:icon(searchWrap, "search", 14, "Muted", {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 0), ZIndex = 7})
    self.SearchBox = new("TextBox", {
        Text = "", PlaceholderText = "Search", FontFace = F.Regular, TextSize = 12, TextColor3 = T.Text, PlaceholderColor3 = T.Muted,
        TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1, ClearTextOnFocus = false,
        Position = UDim2.fromOffset(34, 0), Size = UDim2.new(1, -44, 1, 0), ZIndex = 7, Parent = searchWrap,
    })
    self:bind(self.SearchBox, "TextColor3", "Text")
    self:bind(self.SearchBox, "PlaceholderColor3", "Muted")

    self.Pages = new("Frame", {Name = "Pages", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, TOP_H),
        Size = UDim2.new(1, 0, 1, -TOP_H - DOCK_H - 20), ClipsDescendants = true, Parent = body})

    local dock = new("Frame", {Name = "Dock", BackgroundColor3 = T.Panel, BackgroundTransparency = 0.3, AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.fromOffset(200, DOCK_H), ZIndex = 8, Parent = body}, {corner(18)})
    self:bind(dock, "BackgroundColor3", "Panel")
    bstroke(self, dock, "Edge", 1, 0.86)
    self.DockBar = dock
    local tabScroll = new("ScrollingFrame", {
        Name = "Tabs", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.X, ScrollBarThickness = 0, ScrollingDirection = Enum.ScrollingDirection.X, ZIndex = 8, Parent = dock,
    })
    self.TabScroll = tabScroll
    self.Pill = new("Frame", {BackgroundColor3 = T.Accent, BackgroundTransparency = 0.85, Position = UDim2.fromOffset(6, 6),
        Size = UDim2.fromOffset(60, DOCK_H - 12), Visible = false, ZIndex = 8, Parent = tabScroll}, {corner(13)})
    self:bind(self.Pill, "BackgroundColor3", "Accent")
    bstroke(self, self.Pill, "Accent", 1, 0.65)
    self.TabInner = new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, ZIndex = 9, Parent = tabScroll},
        {list(2, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center), pad(6, 6, 0, 0)})
    local function sizeDock()
        local sc = math.max(self.Scale.Scale, 0.01)
        local w = self.TabInner.AbsoluteSize.X / sc
        dock.Size = UDim2.fromOffset(math.min(w, root.Size.X.Offset - 48), DOCK_H)
        if self.Current and self.Booted then self:_movePill(self.Current, true) end
    end
    table.insert(self.Conns, self.TabInner:GetPropertyChangedSignal("AbsoluteSize"):Connect(sizeDock))
    table.insert(self.Conns, root:GetPropertyChangedSignal("Size"):Connect(sizeDock))

    self:_buildSearch()

    local grip = new("TextButton", {Text = "", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromScale(1, 1),
        Size = UDim2.fromOffset(18, 18), ZIndex = 40, Parent = root})
    for i = 0, 1 do
        local dot = new("Frame", {BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -4 - i * 4, 1, -4 + i * 0),
            Size = UDim2.fromOffset(2, 2), Parent = grip}, {corner(1)})
        self:bind(dot, "BackgroundColor3", "Muted")
    end
    local rz, rzStart, rzSize
    grip.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            rz, rzStart, rzSize = true, input.Position, root.AbsoluteSize / math.max(self.Scale.Scale, 0.01)
            local c
            c = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then rz = false c:Disconnect() end
            end)
        end
    end)
    table.insert(self.Conns, UserInputService.InputChanged:Connect(function(input)
        if not rz then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            local d = (input.Position - rzStart) / math.max(self.Scale.Scale, 0.01)
            root.Size = UDim2.fromOffset(math.clamp(rzSize.X + d.X, 620, 1100), math.clamp(rzSize.Y + d.Y, 420, 800))
        end
    end))

    local function dragged() self.Dragged = true end
    draggable(header, root, self.Conns, dragged)
    table.insert(self.Conns, root:GetPropertyChangedSignal("Position"):Connect(function()

        if self.Animating then return end
        self.HomePos = root.Position
        if not self.Dragged then return end
        self.PosSaved = {x = root.Position.X.Offset, y = root.Position.Y.Offset}
        self:_save()
    end))

    table.insert(self.Conns, UserInputService.InputBegan:Connect(function(input, processed)
        if self.Destroyed or self.Listening then return end
        if UserInputService:GetFocusedTextBox() then return end
        if input.KeyCode == self.Key and input.KeyCode ~= Enum.KeyCode.Unknown then
            self:SetOpen(not self.Open)
            return
        end
        if processed then return end
        for _, b in ipairs(self.Binds) do
            if b.key and (input.KeyCode == b.key or input.UserInputType == b.key) then task.spawn(b.fire) end
        end
    end))

    if UserInputService.TouchEnabled then
        local fab = new("TextButton", {Text = "", BackgroundColor3 = T.Panel, AutoButtonColor = false,
            Position = UDim2.new(0, 16, 0.5, -22), Size = UDim2.fromOffset(44, 44), Parent = gui}, {corner(22)})
        self:bind(fab, "BackgroundColor3", "Panel")
        bstroke(self, fab, "Stroke", 1, 0)
        self:icon(fab, opts.Icon or "layout-grid", 18, "Text")
        draggable(fab, fab, self.Conns)
        local downAt
        fab.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then downAt = fab.AbsolutePosition end
        end)
        fab.MouseButton1Up:Connect(function()
            if downAt and (fab.AbsolutePosition - downAt).Magnitude < 6 then self:SetOpen(not self.Open) end
        end)
    end

    table.insert(self.Redraws, function() self:_crumb() end)

    fit()
    self:_place()
    self.Scale.Scale = self:_scale() * 0.97
    self:_blur(self.BlurPref)
    self:_dockBuild(opts)
    self:_fxSync()

    if opts.Settings ~= false then
        task.defer(function() if not self.Destroyed then self:_settingsTab() end end)
    end
    task.defer(function() if not self.Destroyed then self:_boot(opts) end end)
    return self
end

function Window:_crumb() end

function Window:_hudPoint()
    local d = self.Dock
    if not d or not d.btn.Parent or not d.btn.Visible or not full() or U.fast then return nil end
    local p = d.btn.AbsolutePosition + d.btn.AbsoluteSize / 2
    if p.X <= 0 and p.Y <= 0 then return nil end
    local vp = self:_screen()
    return UDim2.new(0.5, p.X - vp.X / 2, 0.5, p.Y - vp.Y / 2)
end

function Window:_popIn()
    local home = self.HomePos or self.Root.Position
    self.HomePos = home
    local from = self:_hudPoint()
    tween(self.Body, 0.28, {GroupTransparency = 0})
    if from then
        self.Animating = true
        self.Root.Position = from
        self.Scale.Scale = self:_scale() * 0.1
        tween(self.Root, 0.55, {Position = home}, Enum.EasingStyle.Quint)
        tween(self.Scale, 0.55, {Scale = self:_scale()}, Enum.EasingStyle.Quint)
        task.delay(0.6, function()
            if self.Open and not self.Destroyed then
                self.Animating = false
                self.Root.Position = self.HomePos or home
            end
        end)
    else
        self.Scale.Scale = self:_scale() * (full() and 0.92 or 0.97)
        spring(self.Scale, 0.45, {Scale = self:_scale()})
    end
end

function Window:_cascade(tab)
    if not full() or U.fast then return end
    for i, sec in ipairs(tab.Sections or {}) do
        if i > 10 then break end
        local pop = sec.Pop
        if pop then
            pop.Scale = 0.96
            task.delay((i - 1) * 0.035, function()
                if pop.Parent then spring(pop, 0.4, {Scale = 1}) end
            end)
        end
    end
end

function Window:_boot(opts)
    self.Booted = true
    self:_popIn()
    local function ready()
        if self.Current then
            self:_movePill(self.Current, true)
            self:_cascade(self.Current)
        end
    end
    if opts.Loading ~= true and type(opts.Loading) ~= "table" then ready() return end
    local T = self.T
    local sp = new("CanvasGroup", {BackgroundColor3 = T.Background, Size = UDim2.fromScale(1, 1), ZIndex = 100, Parent = self.Body})
    self:bind(sp, "BackgroundColor3", "Background")
    local t1 = text({Text = self.Title, FontFace = F.SemiBold, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Center,
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.46), Size = UDim2.new(1, 0, 0, 20), Parent = sp})
    self:bind(t1, "TextColor3", "Text")
    local step = text({Text = "", TextSize = 11, TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.46, 24), Size = UDim2.new(1, 0, 0, 14), Parent = sp})
    self:bind(step, "TextColor3", "Muted")
    local track = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.46, 46), Size = UDim2.fromOffset(160, 2), Parent = sp}, {corner(1)})
    self:bind(track, "BackgroundColor3", "Stroke")
    local fill = new("Frame", {Size = UDim2.fromScale(0, 1), Parent = track}, {corner(1)})
    self:bind(fill, "BackgroundColor3", "Accent")
    task.spawn(function()
        local steps = (type(opts.Loading) == "table" and opts.Loading.Steps) or {"Starting", "Applying theme", "Ready"}
        for i, s in ipairs(steps) do
            step.Text = s
            tween(fill, 0.3, {Size = UDim2.fromScale(i / #steps, 1)})
            task.wait(0.28)
        end
        if self.Destroyed then return end
        tween(sp, 0.3, {GroupTransparency = 1})
        task.wait(0.3)
        sp:Destroy()
        ready()
    end)
end

function Window:_blur(on)
    if on and not self.BlurActive and self.Open then
        self.BlurActive = true
        U.blur(true, 12)
    elseif not on and self.BlurActive then
        self.BlurActive = false
        U.blur(false)
    end
end

function Window:SetBlur(v)
    self.BlurPref = v == true
    if self.Body then tween(self.Body, 0.3, {BackgroundTransparency = self.BlurPref and GLASS or GLASS_SOLID}) end
    self:_blur(self.BlurPref and self.Open)
    self:_save()
end

function Window:SetOpen(open)
    if self.Destroyed or self.Open == open then return end
    self.Open = open
    self:_dockSync()
    if open then

        if not self.PosSaved then self:_place() end
        self.Root.Visible = true
        self.Body.GroupTransparency = 1
        self:_popIn()
        tween(self.Shadow, 0.25, {ImageTransparency = 0.45})
        if self.Current then self:_cascade(self.Current) end
        self:_blur(self.BlurPref)
    else
        if self.ListenCancel then self.ListenCancel() end
        self.Listening = false
        local to = self:_hudPoint()
        if to then
            self.Animating = true
            tween(self.Root, 0.34, {Position = to}, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
            tween(self.Scale, 0.34, {Scale = self:_scale() * 0.1}, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
            tween(self.Body, 0.3, {GroupTransparency = 1})
        else
            tween(self.Scale, 0.2, {Scale = self:_scale() * (full() and 0.94 or 0.97)}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            tween(self.Body, 0.18, {GroupTransparency = 1})
        end
        tween(self.Shadow, 0.18, {ImageTransparency = 1})
        self:_blur(false)
        task.delay(to and 0.36 or 0.22, function()
            if not self.Open and not self.Destroyed then
                self.Root.Visible = false
                self.Animating = false
                if self.HomePos then self.Root.Position = self.HomePos end
            end
        end)
    end
    U.sceneSync()
end

function Window:Toggle() self:SetOpen(not self.Open) end

function Window:SetSidebar() end

function Window:Destroy()
    if self.Destroyed then return end
    self:_flush()
    self.Destroyed = true
    self:_fxStop()
    self:_dockSync()
    if self.DockSlot and U.dockSlots then U.dockSlots[self.DockSlot] = nil end
    for i = #(U.windows or {}), 1, -1 do
        if U.windows[i] == self then table.remove(U.windows, i) end
    end
    if U.refreshActive then pcall(U.refreshActive) end
    for _, c in ipairs(self.Conns) do pcall(function() c:Disconnect() end) end
    self:_blur(false)
    if self.OnDestroy then pcall(self.OnDestroy) end
    tween(self.Scale, 0.2, {Scale = self:_scale() * 0.97})
    tween(self.Body, 0.18, {GroupTransparency = 1})
    tween(self.Shadow, 0.18, {ImageTransparency = 1})
    task.delay(0.25, function() self.Gui:Destroy() end)
    if self.Dock and self.Dock.btn then
        self.Dock.btn:Destroy()
        if U.hudBar and #U.hudBar:GetChildren() <= 1 then U.hudBar.Parent:Destroy() U.hudBar = nil end
    end
    U.sceneSync()
end

function Window:_movePill(tab, instant)
    local btn = tab and tab.Btn
    if not btn or not btn.Parent then return end
    if not btn.Visible then self.Pill.Visible = false return end
    local scale = math.max(self.Scale.Scale, 0.01)
    local sc = self.TabScroll
    local x = (btn.AbsolutePosition.X - sc.AbsolutePosition.X) / scale + sc.CanvasPosition.X
    local y = (btn.AbsolutePosition.Y - sc.AbsolutePosition.Y) / scale
    self.Pill.Visible = true
    local goal = {Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(btn.AbsoluteSize.X / scale, btn.AbsoluteSize.Y / scale)}
    if instant then
        tween(self.Pill, 0, goal)
        return
    end
    spring(self.Pill, 0.38, goal)
end

function Window:Tab(opts)
    if type(opts) == "string" then opts = {Name = opts} end
    local tab = setmetatable({}, Tab)
    tab.Window = self
    tab.Name = opts.Name or "Tab"
    tab.Desc = opts.Desc or opts.Description or ""
    tab.IconName = opts.Icon or "layout-grid"
    tab.Group = opts.Group
    tab.Rows = {}
    self.OrderCount = self.OrderCount + 1
    tab.Order = self.OrderCount
    local T = self.T

    local w = math.clamp(#tab.Name * 6 + 18, 58, 92)
    local btn = new("TextButton", {Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromOffset(w, DOCK_H - 12),
        LayoutOrder = tab.Order, ZIndex = 10, Parent = self.TabInner})
    tab.IconImg = self:icon(btn, tab.IconName, 17, T.SubText, {Position = UDim2.new(0.5, 0, 0, 15), ZIndex = 11})
    tab.NameLbl = text({Text = tab.Name, FontFace = F.Medium, TextSize = 10, TextColor3 = T.SubText, TextXAlignment = Enum.TextXAlignment.Center,
        AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -5), Size = UDim2.new(1, -6, 0, 12),
        TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 11, Parent = btn})
    tab.Btn = btn
    local iconScale = new("UIScale", {Scale = 1, Parent = tab.IconImg})

    function tab:_paint(selected, hovered)
        local TT = self.Window.T
        local c = selected and TT.Accent or (hovered and TT.Text or TT.SubText)
        tween(self.NameLbl, 0.14, {TextColor3 = c})
        tween(self.IconImg, 0.14, {ImageColor3 = c})
    end
    table.insert(self.Redraws, function() tab:_paint(self.Current == tab) end)

    btn.MouseEnter:Connect(function()
        if self.Current ~= tab then tab:_paint(false, true) end
        if full() then spring(iconScale, 0.3, {Scale = 1.12}) end
    end)
    btn.MouseLeave:Connect(function()
        if self.Current ~= tab then tab:_paint(false, false) end
        tween(iconScale, 0.2, {Scale = 1})
    end)
    btn.MouseButton1Click:Connect(function() self:Select(tab) end)

    tab.Page = new("CanvasGroup", {Name = tab.Name, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, GroupTransparency = 1, Parent = self.Pages})
    tab.Scroll = new("ScrollingFrame", {
        BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 2, ScrollBarImageColor3 = T.Muted,
        ScrollingDirection = Enum.ScrollingDirection.Y, Parent = tab.Page,
    }, {list(0), pad(22, 22, 4, 18)})
    self:bind(tab.Scroll, "ScrollBarImageColor3", "Muted")

    local cols = new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = tab.Scroll},
        {list(16, Enum.FillDirection.Horizontal)})
    tab.Cols = {}
    for i = 1, 2 do
        tab.Cols[i] = new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(0.5, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
            LayoutOrder = i, Parent = cols}, {list(16)})
    end

    if tab.Group then table.insert(tab.Group.Tabs, tab) end
    table.insert(self.Tabs, tab)
    if not self.Current then self:Select(tab) end
    return tab
end

function Window:Group(opts)
    local group = {Window = self, Tabs = {}, Open = true}
    function group:SetOpen() end
    function group:Tab(o)
        if type(o) == "string" then o = {Name = o} end
        o.Group = group
        return group.Window:Tab(o)
    end
    return group
end

function Window:Select(tab)
    if type(tab) == "string" then
        for _, t in ipairs(self.Tabs) do if t.Name == tab then tab = t break end end
    end
    if type(tab) ~= "table" or tab == self.Current then return end
    if tab.Group and not tab.Group.Open then tab.Group:SetOpen(true) end
    local old = self.Current
    self.Current = tab
    if old then
        old:_paint(false, false)
        old.Page.Visible = false
    end
    tab:_paint(true, false)
    if self.Booted then self:_movePill(tab) end
    tab.Page.Visible = true
    tab.Page.GroupTransparency = 1
    tab.Page.Position = UDim2.fromOffset(0, 8)
    tween(tab.Page, 0.26, {GroupTransparency = 0, Position = UDim2.fromOffset(0, 0)})
    if self.Booted then self:_cascade(tab) end
    tab:_balance()
    tab.Shown = true
end

function Window:_buildSearch()
    local T = self.T
    local panel = new("Frame", {BackgroundColor3 = T.Panel, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -62, 0, 60),
        Size = UDim2.fromOffset(280, 0), AutomaticSize = Enum.AutomaticSize.Y, Visible = false, ZIndex = 60, Parent = self.Content},
        {corner(8), pad(4, 4, 4, 4), list(1)})
    self:bind(panel, "BackgroundColor3", "Panel")
    bstroke(self, panel, "Stroke", 1, 0)
    self.SearchPanel = panel

    local box, wrap = self.SearchBox, self.SearchWrap
    local function clear()
        for _, c in ipairs(panel:GetChildren()) do
            if c:IsA("TextButton") or c:IsA("TextLabel") then c:Destroy() end
        end
    end
    local function jump(entry)
        box.Text = ""
        box:ReleaseFocus()
        panel.Visible = false
        self:Select(entry.tab)
        if entry.sec and entry.sec.Collapsed then entry.sec:SetCollapsed(false) end
        task.delay(0.45, function()
            if not entry.row.Parent or self.Destroyed then return end
            local sc = entry.tab.Scroll
            local s = math.max(self.Scale.Scale, 0.01)
            local y = (entry.row.AbsolutePosition.Y - sc.AbsolutePosition.Y) / s + sc.CanvasPosition.Y - 24
            tween(sc, 0.35, {CanvasPosition = Vector2.new(0, math.max(y, 0))})
            self:_flash(entry.row)
        end)
    end
    local function refresh()
        local q = box.Text:lower()
        clear()
        if q == "" then panel.Visible = false return end
        local found = 0
        for _, e in ipairs(self.Index) do
            if e.row.Parent and (e.name:lower():find(q, 1, true) or e.desc:lower():find(q, 1, true) or e.tab.Name:lower():find(q, 1, true)) then
                found = found + 1
                if found > 7 then break end
                local b = new("TextButton", {Text = "", AutoButtonColor = false, BackgroundColor3 = self.T.Hover, BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 30), LayoutOrder = found, ZIndex = 61, Parent = panel}, {corner(5)})
                self:icon(b, e.tab.IconName, 14, "Muted", {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 9, 0.5, 0), ZIndex = 62})
                local n = text({Text = e.name, FontFace = F.Medium, TextSize = 12, Position = UDim2.fromOffset(32, 0),
                    Size = UDim2.new(1, -110, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 62, Parent = b})
                self:bind(n, "TextColor3", "Text")
                local t = text({Text = e.tab.Name, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0),
                    Position = UDim2.new(1, -9, 0, 0), Size = UDim2.fromOffset(70, 30), TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 62, Parent = b})
                self:bind(t, "TextColor3", "Muted")
                b.MouseEnter:Connect(function() tween(b, 0.08, {BackgroundTransparency = 0}) end)
                b.MouseLeave:Connect(function() tween(b, 0.12, {BackgroundTransparency = 1}) end)
                b.MouseButton1Click:Connect(function() jump(e) end)
            end
        end
        if found == 0 then
            local n = text({Text = "No results", TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 30), ZIndex = 61, Parent = panel})
            self:bind(n, "TextColor3", "Muted")
        end
        panel.Visible = true
    end
    box:GetPropertyChangedSignal("Text"):Connect(refresh)
    box.Focused:Connect(function()
        tween(wrap, 0.18, {BackgroundTransparency = 0.15})
        tween(self.SearchStroke, 0.15, {Transparency = 0.6})
        refresh()
    end)
    box.FocusLost:Connect(function()
        tween(wrap, 0.2, {BackgroundTransparency = 0.5})
        tween(self.SearchStroke, 0.15, {Transparency = 0.88})
        task.delay(0.15, function() panel.Visible = false end)
    end)
end

function Window:FocusSearch()
    if self.SearchBox then
        self.SearchBox.Visible = true
        self.SearchBox:CaptureFocus()
    end
end

function Window:Dialog(opts)
    opts = opts or {}
    local T = self.T
    local modal = new("CanvasGroup", {BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.5, Size = UDim2.fromScale(1, 1),
        GroupTransparency = 1, Active = true, ZIndex = 200, Parent = self.Body})
    local card = new("Frame", {BackgroundColor3 = T.Panel, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(320, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 201, Parent = modal},
        {corner(10), pad(18, 18, 16, 14), list(8)})
    self:bind(card, "BackgroundColor3", "Panel")
    bstroke(self, card, "Stroke", 1, 0)
    local cs = new("UIScale", {Scale = 0.96, Parent = card})
    local title = text({Text = opts.Title or "Are you sure?", FontFace = F.SemiBold, TextSize = 14, Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 1, ZIndex = 202, Parent = card})
    self:bind(title, "TextColor3", "Text")
    local msg = text({Text = opts.Content or "", TextSize = 13, TextWrapped = true, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = 2, ZIndex = 202, Parent = card})
    self:bind(msg, "TextColor3", "SubText")
    local btns = new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 3, ZIndex = 202, Parent = card},
        {list(8, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Bottom)})

    local closed = false
    local function close()
        if closed then return end
        closed = true
        tween(modal, 0.18, {GroupTransparency = 1})
        tween(cs, 0.18, {Scale = 0.97})
        task.delay(0.22, function() modal:Destroy() end)
    end
    for i, b in ipairs(opts.Buttons or {{Text = "Close"}}) do
        local primary, danger = b.Style == "Primary", b.Style == "Danger"
        local btn = new("TextButton", {Text = b.Text or "OK", FontFace = F.Medium, TextSize = 12, AutoButtonColor = false,
            BackgroundColor3 = danger and T.Bad or (primary and T.Accent or T.Hover),
            TextColor3 = danger and Color3.new(1, 1, 1) or (primary and T.OnAccent or T.Text),
            Size = UDim2.fromOffset(math.max(72, #(b.Text or "OK") * 8 + 28), 30), LayoutOrder = i, ZIndex = 203, Parent = btns}, {corner(6)})
        if not primary and not danger then
            self:bind(btn, "BackgroundColor3", "Hover")
            self:bind(btn, "TextColor3", "Text")
            bstroke(self, btn, "Stroke", 1, 0)
        elseif primary then
            self:bind(btn, "BackgroundColor3", "Accent")
            self:bind(btn, "TextColor3", "OnAccent")
        end
        btn.MouseEnter:Connect(function() tween(btn, 0.1, {BackgroundTransparency = 0.15}) end)
        btn.MouseLeave:Connect(function() tween(btn, 0.15, {BackgroundTransparency = 0}) end)
        btn.MouseButton1Click:Connect(function()
            close()
            safeCall(b.Callback)
        end)
    end
    tween(modal, 0.2, {GroupTransparency = 0})
    tween(cs, 0.25, {Scale = 1})
    return {Close = close}
end

local ROW_H = 40

local function sstroke(win, parent, token, thickness, transparency)
    local s = stroke(win.T[token], thickness, transparency)
    s.Parent = parent
    win:bind(s, "Color", token)
    return s
end

local function newRow(sec, height, noHover)
    local win = sec.Window
    sec.Items = sec.Items + 1
    local f = new("Frame", {
        BackgroundColor3 = win.T.Hover, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, height or ROW_H),
        LayoutOrder = sec.Items, ClipsDescendants = true, Parent = sec.Content,
    })
    win:bind(f, "BackgroundColor3", "Hover")
    local line = new("Frame", {BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 14, 1, 0),
        Size = UDim2.new(1, -28, 0, 1), BackgroundTransparency = 0.4, ZIndex = 3, Parent = f})
    win:bind(line, "BackgroundColor3", "Stroke")
    if not noHover then
        f.MouseEnter:Connect(function() tween(f, 0.1, {BackgroundTransparency = 0.45}) end)
        f.MouseLeave:Connect(function() tween(f, 0.15, {BackgroundTransparency = 1}) end)
    end
    table.insert(sec.Tab.Rows, f)
    sec.LastRow = f
    return f
end

local function newAutoRow(sec)
    local win = sec.Window
    sec.Items = sec.Items + 1
    local f = new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = sec.Items, Parent = sec.Content}, {list(0)})
    local body = new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = 1, Parent = f}, {pad(14, 14, 11, 11), list(3)})
    local line = new("Frame", {BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 1), LayoutOrder = 2, Parent = f})
    win:bind(line, "BackgroundColor3", "Stroke")
    table.insert(sec.Tab.Rows, f)
    sec.LastRow = f
    return f, body
end

local function labels(win, parent, name, desc, rightSpace, icon, top)
    local left = 14
    if icon then
        local iy = type(top) == "number" and top or 20
        win:icon(parent, icon, 15, "SubText", {AnchorPoint = Vector2.new(0, 0.5), Position = top and UDim2.new(0, 14, 0, iy) or UDim2.new(0, 14, 0.5, 0)})
        left = 40
    end
    local holder = new("Frame", {
        BackgroundTransparency = 1, Position = UDim2.new(0, left, 0, 0), Size = UDim2.new(1, -(rightSpace or 0) - left - 12, top and 0 or 1, top and 40 or 0), Parent = parent,
    }, {new("UIListLayout", {Padding = UDim.new(0, 1), VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder})})
    local title = text({Text = name or "", FontFace = F.Medium, TextSize = 13, Size = UDim2.new(1, 0, 0, 17),
        TextTruncate = Enum.TextTruncate.AtEnd, LayoutOrder = 1, Parent = holder})
    win:bind(title, "TextColor3", "Text")
    if desc and desc ~= "" then win:_tip(parent, desc) end
    return holder, title, nil
end

local function autoHeight(win, f, holder, minHeight)
    local function update()
        local s = math.max(win.Scale.Scale, 0.01)
        local h = 0
        for _, c in ipairs(holder:GetChildren()) do
            if c:IsA("GuiObject") then h = h + c.AbsoluteSize.Y / s + 1 end
        end
        f.Size = UDim2.new(1, 0, 0, math.max(minHeight, h + 20))
    end
    for _, c in ipairs(holder:GetChildren()) do
        if c:IsA("GuiObject") then c:GetPropertyChangedSignal("AbsoluteSize"):Connect(update) end
    end
    task.defer(update)
end

local function chip(win, parent, w, h)
    local c = new("Frame", {BackgroundColor3 = win.T.Hover, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.fromOffset(w, h or 26), Parent = parent}, {corner(6)})
    win:bind(c, "BackgroundColor3", "Hover")
    sstroke(win, c, "Stroke", 1, 0)
    return c
end

function Tab:Section(name, opts)
    opts = opts or {}
    local win = self.Window
    local sec = setmetatable({}, Section)
    sec.Window, sec.Tab, sec.Items, sec.Name = win, self, 0, name
    self.Count = (self.Count or 0) + 1
    sec.Frame = new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = self.Count, Parent = self.Cols[1]}, {list(8)})
    sec.Pop = new("UIScale", {Scale = 1, Parent = sec.Frame})
    self.Sections = self.Sections or {}
    table.insert(self.Sections, sec)
    if name and name ~= "" then
        local head = new("TextButton", {Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18),
            LayoutOrder = 0, Parent = sec.Frame})
        local lbl = text({Text = string.upper(name), FontFace = F.SemiBold, TextSize = 11, Position = UDim2.fromOffset(2, 0),
            Size = UDim2.new(1, -24, 1, 0), Parent = head})
        win:bind(lbl, "TextColor3", "Muted")
        sec.Chevron = win:icon(head, "chevron-down", 12, "Muted", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -4, 0.5, 0)})
        head.MouseEnter:Connect(function() tween(lbl, 0.1, {TextColor3 = win.T.SubText}) end)
        head.MouseLeave:Connect(function() tween(lbl, 0.15, {TextColor3 = win.T.Muted}) end)
        head.MouseButton1Click:Connect(function() sec:SetCollapsed(not sec.Collapsed) end)
    end
    sec.Layout = list(0)
    sec.Content = new("Frame", {BackgroundColor3 = win.T.Element, BackgroundTransparency = 0.25, Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y, ClipsDescendants = true, LayoutOrder = 1, Parent = sec.Frame}, {corner(12), sec.Layout})
    win:bind(sec.Content, "BackgroundColor3", "Element")
    sstroke(win, sec.Content, "Edge", 1, 0.92)
    if opts.Collapsed then task.defer(function() sec:SetCollapsed(true, true) end) end

    sec.Frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        if not self.Shown then self:_queueBalance() end
    end)
    self:_queueBalance()
    return sec
end

function Tab:_queueBalance()
    if self.BalanceQueued then return end
    self.BalanceQueued = true
    task.defer(function()
        self.BalanceQueued = false
        self:_balance()
    end)
end

function Tab:_balance()
    local cols, secs = self.Cols, self.Sections or {}
    if not cols then return end
    local one = #secs <= 1
    cols[1].Size = one and UDim2.new(1, 0, 0, 0) or UDim2.new(0.5, -8, 0, 0)
    cols[2].Visible = not one
    local s = math.max(self.Window.Scale.Scale, 0.01)
    local h = {0, 0}
    for i, sec in ipairs(secs) do
        local c = (one or h[1] <= h[2]) and 1 or 2
        if sec.Frame.Parent ~= cols[c] then sec.Frame.Parent = cols[c] end
        sec.Frame.LayoutOrder = i
        h[c] = h[c] + sec.Frame.AbsoluteSize.Y / s + 16
    end
end

function Section:SetCollapsed(v, instant)
    v = v == true
    if v == self.Collapsed then return end
    self.Collapsed = v
    local c = self.Content
    local s = math.max(self.Window.Scale.Scale, 0.01)
    local d = instant and 0 or 0.25
    if self.Chevron then tween(self.Chevron, d, {Rotation = v and -90 or 0}) end
    if v then
        self.LastHeight = c.AbsoluteSize.Y / s
        c.AutomaticSize = Enum.AutomaticSize.None
        c.Size = UDim2.new(1, 0, 0, self.LastHeight)
        tween(c, d, {Size = UDim2.new(1, 0, 0, 0)}).Completed:Connect(function()
            if self.Collapsed then c.Visible = false end
        end)
    else
        local h = self.Layout.AbsoluteContentSize.Y / s
        if h < 1 then h = self.LastHeight or 40 end
        c.Visible = true
        local t = tween(c, d, {Size = UDim2.new(1, 0, 0, h)})
        t.Completed:Connect(function()
            if not self.Collapsed then
                c.AutomaticSize = Enum.AutomaticSize.Y
                c.Size = UDim2.new(1, 0, 0, 0)
            end
        end)
    end
end

local function defaultSection(tab)
    if not tab.Default then tab.Default = tab:Section(nil) end
    return tab.Default
end

function Section:Button(opts)
    local win = self.Window
    local T = win.T
    local style = opts.Style
    local f = newRow(self, ROW_H)
    local click = new("TextButton", {Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 4, Parent = f})
    local label = opts.ButtonText or opts.Text or "Run"
    local w = math.max(54, #label * 7 + 24)
    local holder, title = labels(win, f, opts.Name, opts.Desc, w + 4, opts.Icon)
    autoHeight(win, f, holder, ROW_H)

    local b = new("Frame", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(w, 26), ZIndex = 2, Parent = f}, {corner(6)})
    local bl = text({Text = label, FontFace = F.Medium, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = b})
    local bs
    local function paint()
        local TT = win.T
        if style == "Primary" then
            b.BackgroundColor3, bl.TextColor3 = TT.Accent, TT.OnAccent
        elseif style == "Danger" then
            b.BackgroundColor3, bl.TextColor3 = TT.Bad, Color3.new(1, 1, 1)
        else
            b.BackgroundColor3, bl.TextColor3 = TT.Hover, TT.Text
        end
    end
    paint()
    table.insert(win.Redraws, paint)
    if style ~= "Primary" and style ~= "Danger" then bs = sstroke(win, b, "Stroke", 1, 0) end
    click.MouseEnter:Connect(function() tween(b, 0.1, {BackgroundTransparency = 0.12}) end)
    click.MouseLeave:Connect(function() tween(b, 0.15, {BackgroundTransparency = 0}) end)
    b.ClipsDescendants = true
    click.MouseButton1Down:Connect(function(x, y)
        tween(b, 0.06, {BackgroundTransparency = 0.3})
        if not full() or U.fast then return end
        local s = math.max(win.Scale.Scale, 0.01)
        local at = (Vector2.new(x, y) - b.AbsolutePosition) / s
        local grow = math.max(b.AbsoluteSize.X, b.AbsoluteSize.Y) / s * 2.4
        local ripple = new("Frame", {BackgroundColor3 = style == "Primary" and win.T.OnAccent or win.T.Text, BackgroundTransparency = 0.82,
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(at.X, at.Y), Size = UDim2.fromOffset(0, 0), ZIndex = 2, Parent = b},
            {corner(999)})
        tween(ripple, 0.5, {Size = UDim2.fromOffset(grow, grow), BackgroundTransparency = 1})
        task.delay(0.55, function() ripple:Destroy() end)
    end)
    click.MouseButton1Up:Connect(function() tween(b, 0.12, {BackgroundTransparency = 0.12}) end)
    click.MouseButton1Click:Connect(function() safeCall(opts.Callback) end)
    win:_index(self.Tab, opts.Name, opts.Desc, f, self)
    local obj = {}
    function obj:SetName(t) title.Text = t end
    function obj:SetText(t) bl.Text = t end
    return obj
end

function Section:Toggle(opts)
    local win = self.Window
    local value = opts.Default == true
    local locked = false
    local f = newRow(self, ROW_H)
    local btn = new("TextButton", {Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 4, Parent = f})
    local holder = labels(win, f, opts.Name, opts.Desc, 46, opts.Icon)
    autoHeight(win, f, holder, ROW_H)

    local box = new("Frame", {BackgroundColor3 = win.T.Hover, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.fromOffset(20, 20), ZIndex = 2, Parent = f}, {corner(6)})
    local boxStroke = sstroke(win, box, "Stroke", 1, 0)
    local check = win:icon(box, "check", 13, "OnAccent", {ZIndex = 3})
    local checkScale = new("UIScale", {Scale = 1, Parent = check})

    local function draw(instant)
        local TT = win.T
        local d = instant and 0 or 0.16
        tween(box, d, {BackgroundColor3 = value and TT.Accent or TT.Hover})
        tween(boxStroke, d, {Transparency = value and 1 or 0})
        tween(check, d, {ImageTransparency = value and 0 or 1})

        if not instant and value and full() then
            checkScale.Scale = 0.4
            spring(checkScale, 0.35, {Scale = 1})
        end
    end
    table.insert(win.Redraws, function() draw(true) end)

    local obj = {}
    local listeners = {}
    function obj:Set(v, silent)
        if locked and v == true then return end
        value = v == true
        draw()
        if not silent then safeCall(opts.Callback, value) end
        for _, fn in ipairs(listeners) do pcall(fn, value) end
        win:_save()
    end
    function obj:Get() return value end

    function obj:OnChanged(fn) table.insert(listeners, fn) end

    table.insert(win.Toggles, {name = opts.Name or "?", sec = self, get = function() return value end})
    function obj:Lock() locked = true f.BackgroundTransparency = 0.5 if value then obj:Set(false) end end
    function obj:Unlock() locked = false f.BackgroundTransparency = 1 end

    local saved = win:_flag(opts.Flag, function() return value end, function(v) obj:Set(v) end)
    if saved ~= nil then value = saved == true end
    draw(true)
    btn.MouseButton1Click:Connect(function()
        if locked then return end
        obj:Set(not value)
    end)
    f.MouseEnter:Connect(function() if not locked then tween(f, 0.1, {BackgroundTransparency = 0.45}) end end)
    f.MouseLeave:Connect(function() tween(f, 0.15, {BackgroundTransparency = locked and 0.5 or 1}) end)
    win:_index(self.Tab, opts.Name, opts.Desc, f, self)
    safeCall(opts.Callback, value)
    return obj
end

function Section:Slider(opts)
    local win = self.Window
    local T = win.T
    local min, max = opts.Min or 0, opts.Max or 100
    local step = opts.Step or opts.Increment or 1
    local suffix = opts.Suffix or ""
    local value = math.clamp(opts.Default or min, min, max)

    local hasDesc = false
    local f = newRow(self, hasDesc and 66 or 54)
    local holder = labels(win, f, opts.Name, opts.Desc, 80, opts.Icon)
    holder.Size = UDim2.new(1, -(opts.Icon and 40 or 14) - 92, 0, hasDesc and 46 or 32)

    local box = new("TextBox", {
        Text = "", FontFace = F.Mono, TextSize = 12, TextColor3 = T.SubText, BackgroundColor3 = T.Hover, BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Right, ClearTextOnFocus = false, AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -10, 0, 4), Size = UDim2.fromOffset(76, 24), Parent = f,
    }, {corner(5), pad(6, 6, 0, 0)})
    win:bind(box, "TextColor3", "SubText")
    win:bind(box, "BackgroundColor3", "Hover")

    local track = new("Frame", {BackgroundColor3 = T.Stroke, Position = UDim2.new(0, 14, 1, -17), Size = UDim2.new(1, -28, 0, 4), Parent = f}, {corner(2)})
    win:bind(track, "BackgroundColor3", "Stroke")
    local fill = new("Frame", {BackgroundColor3 = T.Accent, Size = UDim2.fromScale(0, 1), Parent = track}, {corner(2)})
    win:bind(fill, "BackgroundColor3", "Accent")
    local knob = new("Frame", {BackgroundColor3 = T.Text, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5),
        Size = UDim2.fromOffset(14, 14), ZIndex = 3, Parent = track}, {corner(7)})
    win:bind(knob, "BackgroundColor3", "Text")

    local halo = new("Frame", {BackgroundColor3 = T.Accent, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(12, 12), ZIndex = 2, Parent = track}, {corner(14)})
    win:bind(halo, "BackgroundColor3", "Accent")

    local obj = {}
    local function draw(instant)
        local r = (max > min) and (value - min) / (max - min) or 0
        local d = instant and 0 or 0.1
        tween(fill, d, {Size = UDim2.fromScale(r, 1)})
        tween(knob, d, {Position = UDim2.fromScale(r, 0.5)})
        tween(halo, d, {Position = UDim2.fromScale(r, 0.5)})
        box.Text = fmt(value) .. suffix
    end
    function obj:Set(v, silent)
        v = tonumber(v)
        if not v then draw() return end
        v = math.clamp(round(v - min, step) + min, min, max)
        local changed = v ~= value
        value = v
        draw()
        if changed and not silent then safeCall(opts.Callback, value) end
        if changed then win:_save() end
    end
    function obj:Get() return value end

    local saved = win:_flag(opts.Flag, function() return value end, function(v) obj:Set(v) end)
    if type(saved) == "number" then value = math.clamp(saved, min, max) end
    draw(true)

    local dragging = false
    local function fromX(x)
        local r = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
        obj:Set(min + (max - min) * r)
    end
    local hit = new("TextButton", {Text = "", BackgroundTransparency = 1, Position = UDim2.new(0, 0, 1, -32), Size = UDim2.new(1, 0, 0, 32), ZIndex = 4, Parent = f})
    hit.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            spring(knob, 0.25, {Size = UDim2.fromOffset(17, 17)})
            if full() then tween(halo, 0.25, {Size = UDim2.fromOffset(26, 26), BackgroundTransparency = 0.78}) end
            fromX(input.Position.X)
        end
    end)
    table.insert(win.Conns, UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            fromX(input.Position.X)
        end
    end))
    table.insert(win.Conns, UserInputService.InputEnded:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            dragging = false
            spring(knob, 0.3, {Size = UDim2.fromOffset(14, 14)})
            tween(halo, 0.3, {Size = UDim2.fromOffset(12, 12), BackgroundTransparency = 1})
        end
    end))
    box.Focused:Connect(function() tween(box, 0.1, {BackgroundTransparency = 0, TextColor3 = win.T.Text}) end)
    box.FocusLost:Connect(function()
        tween(box, 0.15, {BackgroundTransparency = 1, TextColor3 = win.T.SubText})
        local n = tonumber((box.Text:gsub("[^%d%.%-]", "")))
        obj:Set(n or value)
    end)
    f.MouseEnter:Connect(function() tween(f, 0.1, {BackgroundTransparency = 0.45}) end)
    f.MouseLeave:Connect(function() tween(f, 0.15, {BackgroundTransparency = 1}) end)
    win:_index(self.Tab, opts.Name, opts.Desc, f, self)
    safeCall(opts.Callback, value)
    return obj
end

function Section:Dropdown(opts)
    local win = self.Window
    local T = win.T
    local multi = opts.Multi == true
    local options = opts.Options or {}
    local value
    if multi then
        value = {}
        for _, v in ipairs(type(opts.Default) == "table" and opts.Default or {}) do value[v] = true end
    else
        value = opts.Default
    end
    local open = false

    local f = newRow(self, ROW_H, true)
    local head = new("TextButton", {Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, ROW_H), ZIndex = 4, Parent = f})
    local holder = labels(win, f, opts.Name, nil, 150, opts.Icon, true)

    local sel = new("Frame", {BackgroundColor3 = T.Hover, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 7), Size = UDim2.fromOffset(120, 26), ZIndex = 2, Parent = f}, {corner(6)})
    win:bind(sel, "BackgroundColor3", "Hover")
    sstroke(win, sel, "Stroke", 1, 0)
    local shown = text({Text = "", FontFace = F.Medium, TextSize = 12, Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -30, 1, 0),
        TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 3, Parent = sel})
    win:bind(shown, "TextColor3", "Text")
    local chev = win:icon(sel, "chevron-down", 12, "Muted", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), ZIndex = 3})

    local searchable = #options > 7
    local body = new("Frame", {BackgroundTransparency = 1, Position = UDim2.fromOffset(10, ROW_H + 2), Size = UDim2.new(1, -20, 0, 0), Parent = f})
    local search
    if searchable then
        search = new("TextBox", {
            Text = "", PlaceholderText = "Filter", FontFace = F.Regular, TextSize = 12, TextColor3 = T.Text, PlaceholderColor3 = T.Muted,
            TextXAlignment = Enum.TextXAlignment.Left, BackgroundColor3 = T.Hover, ClearTextOnFocus = false, Size = UDim2.new(1, 0, 0, 26), Parent = body,
        }, {corner(6), pad(10, 10, 0, 0)})
        win:bind(search, "TextColor3", "Text")
        win:bind(search, "PlaceholderColor3", "Muted")
        win:bind(search, "BackgroundColor3", "Hover")
        sstroke(win, search, "Stroke", 1, 0)
    end
    local listTop = searchable and 32 or 0
    local scroll = new("ScrollingFrame", {BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(0, listTop), Size = UDim2.new(1, 0, 0, 0),
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 2, ScrollBarImageColor3 = T.Muted, Parent = body}, {list(1)})
    win:bind(scroll, "ScrollBarImageColor3", "Muted")

    local obj = {}
    local buttons = {}

    local function display()
        local txt
        if multi then
            local picked = {}
            for _, o in ipairs(options) do if value[o] then table.insert(picked, tostring(o)) end end
            txt = #picked == 0 and "None" or (#picked <= 2 and table.concat(picked, ", ") or (#picked .. " selected"))
        else
            txt = value ~= nil and tostring(value) or "Select"
        end
        shown.Text = txt
        sel.Size = UDim2.fromOffset(math.clamp(shown.TextBounds.X + 38, 84, 200), 26)
    end

    local function paint()
        for o, b in pairs(buttons) do
            local on = multi and value[o] or (not multi and value == o)
            b.label.TextColor3 = on and win.T.Text or win.T.SubText
            b.tick.ImageTransparency = on and 0 or 1
        end
    end
    table.insert(win.Redraws, paint)

    local function visibleCount()
        local n = 0
        for _, b in pairs(buttons) do if b.btn.Visible then n = n + 1 end end
        return n
    end

    local function layout(instant)
        local listH = math.min(visibleCount() * 29, 174)
        scroll.Size = UDim2.new(1, 0, 0, listH)
        local h = open and (ROW_H + 2 + listTop + listH + 10) or ROW_H
        tween(f, instant and 0 or 0.22, {Size = UDim2.new(1, 0, 0, h)})
        tween(chev, instant and 0 or 0.2, {Rotation = open and 180 or 0})
    end

    local function fire()
        if multi then
            local picked = {}
            for _, o in ipairs(options) do if value[o] then table.insert(picked, o) end end
            safeCall(opts.Callback, picked)
        else
            safeCall(opts.Callback, value)
        end
    end

    local function build()
        for _, b in pairs(buttons) do b.btn:Destroy() end
        buttons = {}
        for i, o in ipairs(options) do
            local b = new("TextButton", {Text = "", AutoButtonColor = false, BackgroundColor3 = T.Hover, BackgroundTransparency = 1,
                Size = UDim2.new(1, -4, 0, 28), LayoutOrder = i, Parent = scroll}, {corner(5)})
            win:bind(b, "BackgroundColor3", "Hover")
            local lbl = text({Text = tostring(o), TextSize = 12, TextColor3 = T.SubText, Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -34, 1, 0),
                TextTruncate = Enum.TextTruncate.AtEnd, Parent = b})
            local tick = win:icon(b, "check", 13, "Accent", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0)})
            tick.ImageTransparency = 1
            b.MouseEnter:Connect(function() tween(b, 0.08, {BackgroundTransparency = 0.3}) end)
            b.MouseLeave:Connect(function() tween(b, 0.12, {BackgroundTransparency = 1}) end)
            b.MouseButton1Click:Connect(function()
                if multi then
                    value[o] = not value[o] or nil
                else
                    value = o
                    open = false
                    if search then search.Text = "" end
                    layout()
                end
                display()
                paint()
                fire()
                win:_save()
            end)
            buttons[o] = {btn = b, label = lbl, tick = tick}
        end
        paint()
    end

    local function filter()
        if not search then return end
        local q = search.Text:lower()
        for o, b in pairs(buttons) do
            b.btn.Visible = q == "" or tostring(o):lower():find(q, 1, true) ~= nil
        end
        if open then layout() end
    end
    if search then search:GetPropertyChangedSignal("Text"):Connect(filter) end

    head.MouseButton1Click:Connect(function()
        open = not open
        if not open and search then search.Text = "" end
        layout()
        if open and full() and not U.fast then
            local order = {}
            for _, b in pairs(buttons) do
                if b.btn.Visible then order[#order + 1] = b end
            end
            table.sort(order, function(a, b) return a.btn.LayoutOrder < b.btn.LayoutOrder end)
            for i, b in ipairs(order) do
                if i > 8 then break end
                b.label.TextTransparency = 1
                b.label.Position = UDim2.fromOffset(16, 0)
                task.delay(0.03 * i, function()
                    if not b.label.Parent then return end
                    tween(b.label, 0.25, {TextTransparency = 0, Position = UDim2.fromOffset(10, 0)})
                end)
            end
        end
    end)
    head.MouseEnter:Connect(function() if not open then tween(f, 0.1, {BackgroundTransparency = 0.45}) end end)
    head.MouseLeave:Connect(function() tween(f, 0.15, {BackgroundTransparency = 1}) end)

    function obj:Set(v, silent)
        if multi then
            value = {}
            for _, x in ipairs(type(v) == "table" and v or {v}) do value[x] = true end
        else
            value = v
        end
        display()
        paint()
        if not silent then fire() end
        win:_save()
    end
    function obj:Get()
        if not multi then return value end
        local picked = {}
        for _, o in ipairs(options) do if value[o] then table.insert(picked, o) end end
        return picked
    end
    function obj:Refresh(newOptions, keep)
        options = newOptions or {}
        if not keep then if multi then value = {} else value = nil end end
        build()
        display()
        filter()
        layout(true)
    end
    function obj:SetOpen(v) open = v == true layout() end

    local saved = win:_flag(opts.Flag, function() return obj:Get() end, function(v) obj:Set(v) end,
        function() local v = obj:Get() if v == nil then return false end return v end)
    if saved ~= nil then
        if multi and type(saved) == "table" then
            value = {}
            for _, x in ipairs(saved) do value[x] = true end
        elseif not multi then
            value = saved ~= false and saved or nil
        end
    end
    build()
    display()
    layout(true)
    win:_index(self.Tab, opts.Name, opts.Desc, f, self)
    if (multi and next(value)) or (not multi and value ~= nil) then fire() end
    return obj
end

function Section:Input(opts)
    local win = self.Window
    local T = win.T
    local f = newRow(self, ROW_H)
    local holder = labels(win, f, opts.Name, opts.Desc, 160, opts.Icon)
    autoHeight(win, f, holder, ROW_H)
    local wrap = chip(win, f, 150, 26)
    local box = new("TextBox", {
        Text = opts.Default or "", PlaceholderText = opts.Placeholder or "Type here", FontFace = F.Regular, TextSize = 12, TextColor3 = T.Text,
        PlaceholderColor3 = T.Muted, ClearTextOnFocus = false, TextTruncate = Enum.TextTruncate.AtEnd, TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = wrap,
    }, {pad(9, 9, 0, 0)})
    win:bind(box, "TextColor3", "Text")
    win:bind(box, "PlaceholderColor3", "Muted")
    local line = wrap:FindFirstChildOfClass("UIStroke")
    box.Focused:Connect(function() tween(line, 0.12, {Color = win.T.SubText}) end)

    local obj = {}
    local function clean(t)
        if opts.Numeric then return (t:gsub("[^%d%.%-]", "")) end
        return t
    end
    function obj:Set(t, silent)
        box.Text = clean(tostring(t or ""))
        if not silent then safeCall(opts.Callback, box.Text, true) end
        win:_save()
    end
    function obj:Get() return box.Text end
    box.FocusLost:Connect(function(enter)
        tween(line, 0.15, {Color = win.T.Stroke})
        box.Text = clean(box.Text)
        safeCall(opts.Callback, box.Text, enter)
        win:_save()
    end)
    f.MouseEnter:Connect(function() tween(f, 0.1, {BackgroundTransparency = 0.45}) end)
    f.MouseLeave:Connect(function() tween(f, 0.15, {BackgroundTransparency = 1}) end)
    local saved = win:_flag(opts.Flag, function() return box.Text end, function(v) obj:Set(v) end)
    if type(saved) == "string" then box.Text = saved end
    win:_index(self.Tab, opts.Name, opts.Desc, f, self)
    if box.Text ~= "" then safeCall(opts.Callback, box.Text, true) end
    return obj
end

function Section:Keybind(opts)
    local win = self.Window
    local T = win.T
    local key = opts.Default
    local f = newRow(self, ROW_H)
    local holder = labels(win, f, opts.Name, opts.Desc, 90, opts.Icon)
    autoHeight(win, f, holder, ROW_H)
    local btnChip = chip(win, f, 56, 24)
    local line = btnChip:FindFirstChildOfClass("UIStroke")
    local btn = new("TextButton", {Text = keyName(key), FontFace = F.Mono, TextSize = 11, AutoButtonColor = false, BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1), Parent = btnChip})
    win:bind(btn, "TextColor3", "SubText")
    local function resize()
        tween(btnChip, 0.12, {Size = UDim2.fromOffset(math.max(44, btn.TextBounds.X + 20), 24)})
    end
    btn:GetPropertyChangedSignal("Text"):Connect(resize)

    local bind = {key = key, sec = self}
    self.Bind = self.Bind or bind
    bind.fire = function() if opts.Callback then safeCall(opts.Callback, bind.key) end end
    table.insert(win.Binds, bind)

    local obj = {}
    function obj:Set(k)
        if k == nil or (typeof(k) == "EnumItem" and (k == Enum.KeyCode.Escape or k == Enum.KeyCode.Backspace)) then k = nil end
        if opts.KeyboardOnly and k ~= nil and k.EnumType ~= Enum.KeyCode then return end
        key, bind.key = k, k
        btn.Text = keyName(k)
        safeCall(opts.Changed, k)
        win:_save()
    end
    function obj:Get() return key end

    btn.MouseButton1Click:Connect(function()
        if win.Listening then return end
        win.Listening = true
        btn.Text = "press a key"
        tween(line, 0.1, {Color = win.T.Accent})
        local c
        local function stop()
            if c then c:Disconnect() c = nil end
            tween(line, 0.15, {Color = win.T.Stroke})
            btn.Text = keyName(key)
            win.ListenCancel = nil
            task.defer(function() win.Listening = false end)
        end
        win.ListenCancel = stop
        c = UserInputService.InputBegan:Connect(function(input)
            local k
            if input.UserInputType == Enum.UserInputType.Keyboard then
                k = input.KeyCode
            elseif not opts.KeyboardOnly and (input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.MouseButton3) then
                k = input.UserInputType
            else
                return
            end
            stop()
            obj:Set(k)
        end)
    end)
    f.MouseEnter:Connect(function() tween(f, 0.1, {BackgroundTransparency = 0.45}) end)
    f.MouseLeave:Connect(function() tween(f, 0.15, {BackgroundTransparency = 1}) end)

    local saved = win:_flag(opts.Flag, function() return key end, function(v) obj:Set(v) end,
        function() return key and key.Name or "None" end,
        function(name)
            if name == "None" then return false end
            local ok, k = pcall(function() return Enum.KeyCode[name] end)
            if ok and k then return k end
            if opts.KeyboardOnly then return nil end
            ok, k = pcall(function() return Enum.UserInputType[name] end)
            return ok and k or nil
        end)
    if saved == false then key = nil elseif saved then key = saved end
    bind.key = key
    btn.Text = keyName(key)
    win:_index(self.Tab, opts.Name, opts.Desc, f, self)
    return obj
end

function Section:ColorPicker(opts)
    local win = self.Window
    local T = win.T
    local color = opts.Default or opts.Color or Color3.new(1, 1, 1)
    local h, s, v = color:ToHSV()
    local open = false

    local f = newRow(self, ROW_H, true)
    local head = new("TextButton", {Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, ROW_H), ZIndex = 4, Parent = f})
    labels(win, f, opts.Name, nil, 60, opts.Icon, true)
    local swatch = new("Frame", {BackgroundColor3 = color, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 12), Size = UDim2.fromOffset(28, 16),
        ZIndex = 2, Parent = f}, {corner(4)})
    sstroke(win, swatch, "Stroke", 1, 0)

    local body = new("Frame", {BackgroundTransparency = 1, Position = UDim2.new(0, 14, 0, ROW_H + 4), Size = UDim2.new(1, -28, 0, 134), Parent = f})
    local sv = new("TextButton", {Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.fromHSV(h, 1, 1), Size = UDim2.new(1, -96, 0, 104), Parent = body}, {corner(6)})
    new("Frame", {BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(1, 1), Parent = sv}, {corner(6), new("UIGradient", {Transparency = NumberSequence.new(0, 1)})})
    new("Frame", {BackgroundColor3 = Color3.new(0, 0, 0), Size = UDim2.fromScale(1, 1), Parent = sv}, {corner(6), new("UIGradient", {Rotation = 90, Transparency = NumberSequence.new(1, 0)})})
    local svDot = new("Frame", {BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(10, 10), ZIndex = 3, Parent = sv},
        {corner(5), stroke(Color3.new(1, 1, 1), 2, 0)})

    local hueKeys = {}
    for i = 0, 6 do table.insert(hueKeys, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV((i / 6) % 1, 1, 1))) end
    local hue = new("TextButton", {Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(1, 1, 1), Position = UDim2.new(0, 0, 0, 114),
        Size = UDim2.new(1, -96, 0, 10), Parent = body}, {corner(5), new("UIGradient", {Color = ColorSequence.new(hueKeys)})})
    local hueDot = new("Frame", {BackgroundColor3 = Color3.new(1, 1, 1), AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(6, 14), ZIndex = 3, Parent = hue}, {corner(3)})
    sstroke(win, hueDot, "Stroke", 1, 0)

    local preview = new("Frame", {BackgroundColor3 = color, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(84, 70), Parent = body}, {corner(6)})
    sstroke(win, preview, "Stroke", 1, 0)
    local hex = new("TextBox", {Text = toHex(color), FontFace = F.Mono, TextSize = 12, ClearTextOnFocus = false, BackgroundColor3 = T.Hover,
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 78), Size = UDim2.fromOffset(84, 26), Parent = body}, {corner(6)})
    win:bind(hex, "TextColor3", "Text")
    win:bind(hex, "BackgroundColor3", "Hover")
    sstroke(win, hex, "Stroke", 1, 0)

    local obj = {}
    local function draw()
        color = Color3.fromHSV(h, s, v)
        sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
        svDot.Position = UDim2.fromScale(s, 1 - v)
        hueDot.Position = UDim2.fromScale(h, 0.5)
        swatch.BackgroundColor3 = color
        preview.BackgroundColor3 = color
        hex.Text = toHex(color)
    end
    function obj:Set(c, silent)
        if typeof(c) ~= "Color3" then return end
        h, s, v = c:ToHSV()
        draw()
        if not silent then safeCall(opts.Callback, color) end
        win:_save()
    end
    function obj:Get() return color end

    local drag
    local function update(pos)
        if drag == "sv" then
            s = math.clamp((pos.X - sv.AbsolutePosition.X) / math.max(sv.AbsoluteSize.X, 1), 0, 1)
            v = 1 - math.clamp((pos.Y - sv.AbsolutePosition.Y) / math.max(sv.AbsoluteSize.Y, 1), 0, 1)
        elseif drag == "hue" then
            h = math.clamp((pos.X - hue.AbsolutePosition.X) / math.max(hue.AbsoluteSize.X, 1), 0, 0.999)
        end
        draw()
        safeCall(opts.Callback, color)
        win:_save()
    end
    local function begin(which)
        return function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                drag = which
                update(input.Position)
            end
        end
    end
    sv.InputBegan:Connect(begin("sv"))
    hue.InputBegan:Connect(begin("hue"))
    table.insert(win.Conns, UserInputService.InputChanged:Connect(function(input)
        if drag and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then update(input.Position) end
    end))
    table.insert(win.Conns, UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then drag = nil end
    end))
    hex.FocusLost:Connect(function()
        local c = fromHex(hex.Text)
        if c then obj:Set(c) else hex.Text = toHex(color) end
    end)
    head.MouseButton1Click:Connect(function()
        open = not open
        tween(f, 0.22, {Size = UDim2.new(1, 0, 0, open and (ROW_H + 148) or ROW_H)})
    end)
    head.MouseEnter:Connect(function() if not open then tween(f, 0.1, {BackgroundTransparency = 0.45}) end end)
    head.MouseLeave:Connect(function() tween(f, 0.15, {BackgroundTransparency = 1}) end)

    local saved = win:_flag(opts.Flag, function() return color end, function(c) obj:Set(c) end, function() return toHex(color) end, fromHex)
    if saved then h, s, v = saved:ToHSV() end
    draw()
    win:_index(self.Tab, opts.Name, opts.Desc, f, self)
    safeCall(opts.Callback, color)
    return obj
end

function Section:Label(opts)
    if type(opts) == "string" then opts = {Text = opts} end
    local win = self.Window
    local f, body = newAutoRow(self)
    local lbl = text({Text = opts.Text or "", TextSize = 12, TextWrapped = true, RichText = true, Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y, Parent = body})
    win:bind(lbl, "TextColor3", "SubText")
    local obj = {}
    function obj:Set(t) lbl.Text = tostring(t) end
    function obj:Get() return lbl.Text end
    return obj
end

function Section:Paragraph(opts)
    local win = self.Window
    local f, body = newAutoRow(self)
    local title = text({Text = opts.Title or opts.Name or "", FontFace = F.Medium, TextSize = 13, Size = UDim2.new(1, 0, 0, 17), LayoutOrder = 1, Parent = body})
    win:bind(title, "TextColor3", "Text")
    local msg = text({Text = opts.Content or "", TextSize = 12, TextWrapped = true, RichText = true, Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = body})
    win:bind(msg, "TextColor3", "SubText")
    local obj = {}
    function obj:Set(t) msg.Text = tostring(t) end
    function obj:SetTitle(t) title.Text = tostring(t) end
    return obj
end

function Section:Progress(opts)
    local win = self.Window
    local f = newRow(self, 48, true)
    local holder = labels(win, f, opts.Name, nil, 90, opts.Icon, 15)
    holder.Size = UDim2.new(1, -(opts.Icon and 40 or 14) - 100, 0, 30)
    local pct = text({Text = "0%", FontFace = F.Mono, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -14, 0, 0), Size = UDim2.fromOffset(100, 30), Parent = f})
    win:bind(pct, "TextColor3", "SubText")
    local track = new("Frame", {BackgroundColor3 = win.T.Stroke, Position = UDim2.new(0, 14, 1, -15), Size = UDim2.new(1, -28, 0, 3), Parent = f}, {corner(2)})
    win:bind(track, "BackgroundColor3", "Stroke")
    local fill = new("Frame", {BackgroundColor3 = win.T.Accent, Size = UDim2.fromScale(0, 1), Parent = track}, {corner(2)})
    win:bind(fill, "BackgroundColor3", "Accent")
    local obj = {}
    function obj:Set(r, label)
        r = math.clamp(tonumber(r) or 0, 0, 1)
        tween(fill, 0.3, {Size = UDim2.fromScale(r, 1)})
        pct.Text = label or (math.floor(r * 100 + 0.5) .. "%")
    end
    obj:Set(opts.Default or 0)
    win:_index(self.Tab, opts.Name, opts.Desc, f, self)
    return obj
end

function Section:Stat(opts)
    local win = self.Window
    local f = newRow(self, ROW_H, true)
    labels(win, f, opts.Name, nil, 130, opts.Icon)
    local val = text({Text = tostring(opts.Value or "-"), FontFace = F.SemiBold, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Right,
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(150, 20), Parent = f})
    win:bind(val, "TextColor3", "Text")
    local obj = {}
    function obj:Set(t) val.Text = tostring(t) end
    win:_index(self.Tab, opts.Name, opts.Desc, f, self)
    return obj
end

function Section:Divider()
    local f = newRow(self, 8, true)
    f.BackgroundColor3 = self.Window.T.Background
    self.Window:bind(f, "BackgroundColor3", "Background")
    f.BackgroundTransparency = 0
end

local ELEMENTS = {"Button", "Toggle", "Slider", "Dropdown", "Input", "Keybind", "ColorPicker", "Label", "Paragraph", "Progress", "Stat", "Divider"}
for _, name in ipairs(ELEMENTS) do
    local make = Section[name]
    Section[name] = function(sec, opts)
        sec.LastRow = nil
        local obj = make(sec, opts)
        local dep = type(opts) == "table" and opts.DependsOn
        local row = sec.LastRow
        if row and type(dep) == "table" and type(dep.Get) == "function" and type(dep.OnChanged) == "function" then
            local want = opts.DependsValue
            if want == nil then want = true end
            local function sync() row.Visible = dep:Get() == want end
            sync()
            dep:OnChanged(sync)
        end
        return obj
    end
end

for _, name in ipairs(ELEMENTS) do
    Tab[name] = function(tab, opts) return Section[name](defaultSection(tab), opts) end
end

local active = {gui = nil, panel = nil, sig = nil, loop = false}

local function activeLines()
    local lines, theme = {}, nil
    for _, w in ipairs(U.windows or {}) do
        if not w.Destroyed and w.ShowActive then
            theme = theme or w.T
            for _, t in ipairs(w.Toggles) do
                if t.sec.Tab.Name ~= "Settings" and t.get() then
                    local bind = t.sec.Bind
                    table.insert(lines, {name = t.name, key = bind and bind.key and keyName(bind.key) or ""})
                end
            end
        end
    end
    return lines, theme
end

local function renderActive()
    local lines, T = activeLines()
    if not T then
        if active.gui then active.gui.Enabled = false end
        return
    end
    if not active.gui or not active.gui.Parent then
        active.gui = screenGui("VantaActive", 140)
        active.panel = new("Frame", {Position = UDim2.fromOffset(14, 64), Size = UDim2.fromOffset(190, 0), AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 0.06, Parent = active.gui}, {corner(8), pad(10, 10, 8, 8), list(3)})
        active.stroke = stroke(T.Stroke, 1, 0)
        active.stroke.Parent = active.panel
        active.conns = {}
        draggable(active.panel, active.panel, active.conns)
        active.sig = nil
    end
    active.gui.Enabled = true
    local sig = T.Panel and tostring(T.Panel) or ""
    for _, l in ipairs(lines) do sig = sig .. "|" .. l.name .. "=" .. l.key end
    if sig == active.sig then return end
    active.sig = sig
    for _, c in ipairs(active.panel:GetChildren()) do
        if c:IsA("TextLabel") or (c:IsA("Frame") and c.Name == "Line") then c:Destroy() end
    end
    active.panel.BackgroundColor3 = T.Panel
    active.stroke.Color = T.Stroke
    text({Text = "ON", FontFace = F.SemiBold, TextSize = 11, TextColor3 = T.Muted, Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 0, Parent = active.panel})
    if #lines == 0 then
        text({Text = "nothing is on", TextSize = 12, TextColor3 = T.Muted, Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 1, Parent = active.panel})
    end
    for i, l in ipairs(lines) do
        local row = new("Frame", {Name = "Line", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 16), LayoutOrder = i, Parent = active.panel})
        new("Frame", {BackgroundColor3 = T.Good, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.fromOffset(6, 6), Parent = row}, {corner(3)})
        text({Text = l.name, TextSize = 12, TextColor3 = T.Text, Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -60, 1, 0),
            TextTruncate = Enum.TextTruncate.AtEnd, Parent = row})
        text({Text = l.key, FontFace = F.Mono, TextSize = 11, TextColor3 = T.SubText, TextXAlignment = Enum.TextXAlignment.Right,
            AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0, 46, 1, 0), Parent = row})
    end
end

function U.refreshActive()
    pcall(renderActive)
    if active.loop then return end
    active.loop = true
    task.spawn(function()
        while true do
            task.wait(0.4)
            pcall(renderActive)
            local any = false
            for _, w in ipairs(U.windows or {}) do if not w.Destroyed and w.ShowActive then any = true end end
            if not any then
                if active.gui then active.gui.Enabled = false end
                active.loop = false
                return
            end
        end
    end)
end

function Window:_settingsTab()
    local tab = self:Tab({Name = "Settings", Icon = "settings", Desc = "Appearance and menu"})
    tab.Btn.LayoutOrder = 9999
    local look = tab:Section("Appearance")
    local themeDrop = look:Dropdown({Name = "Theme", Icon = "sun-moon", Options = themeList(), Default = self.ThemeName,
        Callback = function(n) if n and n ~= self.ThemeName then self:SetTheme(n) end end})
    local season = seasonTheme()
    if season then
        look:Label("Limited time: the " .. season .. " theme is here until " .. THEMES[season].Limited.Ends .. ".")
    end
    local accentDrop = look:Dropdown({Name = "Accent", Icon = "droplet", Options = ACCENT_ORDER, Default = self.AccentName,
        Callback = function(n) if n and n ~= self.AccentName then self:SetAccent(n) end end})

    table.insert(self.Redraws, function()
        themeDrop:Set(self.ThemeName, true)
        if self.AccentName then accentDrop:Set(self.AccentName, true) end
    end)
    look:Toggle({Name = "Background blur", Desc = "Softens the game behind the menu", Default = self.BlurPref,
        Callback = function(v) if v ~= self.BlurPref then self:SetBlur(v) end end})
    look:Slider({Name = "Interface scale", Min = 70, Max = 130, Step = 5, Default = math.floor(self.UserScale * 100 + 0.5), Suffix = "%",
        Callback = function(v) if math.abs(v / 100 - self.UserScale) > 0.001 then self:SetScale(v / 100) end end})
    look:Dropdown({Name = "Animations", Icon = "layers", Options = {"Full", "Reduced", "Off"}, Default = U.motion, Flag = "vanta_motion",
        Callback = function(v)
            if v ~= "Full" and v ~= "Reduced" and v ~= "Off" then return end
            U.motion, U.fast = v, v == "Off"
            for _, w in ipairs(U.windows or {}) do
                if w.PaintShimmer then pcall(w.PaintShimmer) end
            end
        end})
    local menu = tab:Section("Menu")
    menu:Toggle({Name = "Top bar", Desc = "The small bar at the top of the screen that opens and closes this window", Default = true, Flag = "vanta_dock",
        Callback = function(v) self.DockOn = v == true self:_dockSync() end})
    if season then
        local about = season == "Christmas" and "String lights, snow, baubles and presents around the window"
            or "Bats, falling leaves, pumpkins and cobwebs around the window"
        look:Toggle({Name = season .. " scene", Desc = about, Default = true, Flag = "vanta_scene",
            Callback = function(v) self.SceneOn = v == true U.sceneSync() end})
    end
    menu:Toggle({Name = "Show what's on", Desc = "A small on-screen list of every switch that's on, with its key", Default = false, Flag = "vanta_active_list",
        Callback = function(v) self.ShowActive = v == true U.refreshActive() end})
    menu:Button({Name = "Reset window position", Desc = "Forgets where you dragged it and picks a free spot again", ButtonText = "Reset",
        Callback = function() self:ResetPosition() end})
    menu:Keybind({Name = "Menu key", Desc = "Shows and hides this window", Default = self.Key, KeyboardOnly = true,
        Changed = function(k) if k then self:SetKey(k) end end})
    if self.ConfigPath then menu:Label("Settings are saved to workspace/" .. self.ConfigPath) end
    menu:Button({Name = "Unload script", Desc = "Turns everything off and closes this window", Style = "Danger", ButtonText = "Unload",
        Callback = function()
            self:Dialog({Title = "Unload this script?", Content = "Everything it started is turned off and the window closes.",
                Buttons = {{Text = "Cancel"}, {Text = "Unload", Style = "Danger", Callback = function() self:Destroy() end}}})
        end})
end

return Vanta

end)()

local BPUI = (function(...)
local Vanta = ...
local BPUI = {}
local lastWindow

local function convert(o)
    o = o or {}
    local out = {}
    for k, v in pairs(o) do out[k] = v end
    out.Desc = o.Desc or o.Description
    out.Step = o.Step or o.Increment
    return out
end

local function alias(obj)
    if type(obj) ~= "table" then return obj end
    obj.SetContent = obj.SetContent or obj.Set
    obj.SetValue = obj.SetValue or obj.Set
    obj.SetText = obj.SetText or obj.Set
    return obj
end

local Section = {}
Section.__index = Section

local function plain(o)
    local out = convert(o)
    out.Icon = nil
    return out
end

function Section:AddToggle(o) return alias(self.v:Toggle(plain(o))) end
function Section:AddSlider(o) return alias(self.v:Slider(plain(o))) end
function Section:AddDropdown(o) return alias(self.v:Dropdown(plain(o))) end
function Section:AddKeybind(o) return alias(self.v:Keybind(plain(o))) end
function Section:AddButton(o) return alias(self.v:Button(plain(o))) end
function Section:AddInput(o) return alias(self.v:Input(plain(o))) end
function Section:AddTextbox(o) return alias(self.v:Input(plain(o))) end
function Section:AddColorPicker(o) return alias(self.v:ColorPicker(plain(o))) end
function Section:AddProgress(o) return alias(self.v:Progress(plain(o))) end
function Section:AddDivider() return self.v:Divider() end
function Section:AddLabel(o)
    if type(o) == "string" then o = {Text = o} end
    return alias(self.v:Label(o or {}))
end
function Section:AddParagraph(o)
    o = o or {}
    return alias(self.v:Paragraph({Title = o.Title or o.Name, Content = o.Content or o.Text}))
end

local Tab = {}
Tab.__index = Tab

function Tab:CreateSection(o)
    local name = type(o) == "table" and (o.Name or o.Title) or o
    return setmetatable({v = self.v:Section(name)}, Section)
end

local Window = {}

local function wrapTab(win, vtab)
    local t = setmetatable({v = vtab, Window = win}, Tab)
    win._tabs[vtab] = t
    return t
end

Window.__index = function(win, key)
    if key == "_visible" then return win.v.Open end
    if key == "_activeTab" then return win._tabs[win.v.Current] end
    return Window[key]
end

function Window:CreateTab(o)
    if type(o) == "string" then o = {Name = o} end
    return wrapTab(self, self.v:Tab(convert(o)))
end

function Window:CreateGroup(o)
    if type(o) == "string" then o = {Name = o} end
    local win = self
    local group = self.v:Group({Name = o.Name, Open = o.Open})
    return {
        CreateTab = function(_, t)
            if type(t) == "string" then t = {Name = t} end
            return wrapTab(win, group:Tab(convert(t)))
        end,
        SetOpen = function(_, v) group:SetOpen(v) end,
    }
end

function Window:SelectTab(name) self.v:Select(name) end
function Window:Notify(o) self.v:Notify(o) end
function Window:Destroy() self.v:Destroy() end
function Window:Toggle() self.v:Toggle() end
function Window:SetOpen(v) self.v:SetOpen(v) end

BPUI.Windows = {}

function BPUI:CreateWindow(o)
    o = o or {}
    local gone

    local version = o.Version or "1.10.0"
    local v = Vanta:Window({
        Title = o.Title,

        Subtitle = o.Subtitle and ("v" .. version .. "  ·  " .. o.Subtitle) or ("v" .. version),
        Key = o.ToggleKey or o.Key,
        Config = o.ConfigFolder,
        OnDestroy = function()
            if o.OnDestroy then o.OnDestroy() end
            if BPUI.WindowGone then BPUI.WindowGone(gone) end
        end,
        Settings = o.ShowSettings ~= false,
        Size = o.Size,
        Icon = "cat",

        Theme = Vanta.ThemeActive(o.Theme) and o.Theme or nil,
    })
    local win = setmetatable({v = v, _tabs = {}}, Window)
    gone = v
    table.insert(BPUI.Windows, v)
    lastWindow = win
    return win
end

function BPUI:Notify(o)
    if lastWindow and not lastWindow.v.Destroyed then
        lastWindow.v:Notify(o)
    else
        Vanta:Notify(o)
    end
end

return BPUI

end)(Vanta)

local BASE = "https://raw.githubusercontent.com/NNoradrenaline/catn-hub/main/dist/"
local LOADER = 'loadstring(game:HttpGet("' .. BASE .. 'catn_hub.lua"))()'
local SOURCES = {}
local function GET_SOURCE(key)
    if not SOURCES[key] then SOURCES[key] = game:HttpGet(BASE .. "games/" .. key .. ".lua") end
    return SOURCES[key]
end

print("[catn hub] starting")
local hubOk, hubRes = xpcall(function()
if not game:IsLoaded() then game.Loaded:Wait() end
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")
local Lighting = game:GetService("Lighting")
local MarketplaceService = game:GetService("MarketplaceService")
local HttpService = game:GetService("HttpService")
local rs = game:GetService("ReplicatedStorage")
local plr = Players.LocalPlayer

local HUB_VERSION = "1.10.0"
local INVITE_CODE = "TwqtNreVMr"
local INVITE_URL = "https://discord.gg/" .. INVITE_CODE

local GAMES = {
    {
        Name = "Anime Battle Arena",
        Key = "aba",
        Icon = "swords",
        Version = "1.5.6",
        Detect = function() return game.GameId == 578392296 or game.PlaceId == 1458767429 end,
    },
    {
        Name = "Monday Morning Misery",
        Key = "mmm",
        Icon = "music",
        Version = "1.1.1",
        Detect = function()
            local m = rs:FindFirstChild("Modules")
            return m ~= nil and m:FindFirstChild("Songs") ~= nil and m:FindFirstChild("CommonEffects") ~= nil
        end,
    },
    {
        Name = "Climb For Animals Eggs",
        Key = "cfae",
        Icon = "egg",
        Version = "1.4.0",
        Detect = function() return game.GameId == 10765490774 or game.PlaceId == 85738654635245 end,
    },
    {
        Name = "Funky Friday",
        Key = "ff",
        Icon = "music",
        Version = "1.0.2",
        Detect = function() return game.GameId == 2404080894 or game.PlaceId == 6447798030 end,
    },
}

local genv = getgenv and getgenv() or _G
if genv.__CATN_HUB and not genv.__CATN_HUB.Destroyed then pcall(function() genv.__CATN_HUB:Destroy() end) end

local afkConn
local function antiAfk(on)
    if on and not afkConn then
        afkConn = plr.Idled:Connect(function()
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end)
        end)
    elseif not on and afkConn then
        afkConn:Disconnect()
        afkConn = nil
    end
end

local lowState
local function lowGraphics(on)
    if on and not lowState then
        local ok, level = pcall(function() return settings().Rendering.QualityLevel end)
        lowState = {quality = ok and level or nil, shadows = Lighting.GlobalShadows}
        pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
        Lighting.GlobalShadows = false
    elseif not on and lowState then
        if lowState.quality then pcall(function() settings().Rendering.QualityLevel = lowState.quality end) end
        Lighting.GlobalShadows = lowState.shadows
        lowState = nil
    end
end

local win = Vanta:Window({
    Title = "Catn Hub",
    Subtitle = "v" .. HUB_VERSION,
    Icon = "cat",
    Key = Enum.KeyCode.RightControl,
    Config = "CatnHub",
    OnDestroy = function()
        antiAfk(false)
        lowGraphics(false)
    end,
})
genv.__CATN_HUB = win

local gameName = "..."

local function copyText(text, what)
    if type(setclipboard) == "function" and pcall(setclipboard, text) then
        win:Notify({Title = "Copied", Content = what .. " is on your clipboard.", Type = "Success", Duration = 3})
    else
        win:Notify({Title = what, Content = "This executor can't copy to the clipboard: " .. text, Type = "Info", Duration = 10})
    end
end

local function getText(url)
    local send = request or http_request or (syn and syn.request) or (http and http.request)
    if send then
        local ok, res = pcall(send, {Url = url, Method = "GET"})
        if ok and type(res) == "table" and res.StatusCode == 200 and type(res.Body) == "string" then return res.Body end
    end
    local ok, res = pcall(function() return game:HttpGet(url) end)
    if ok and type(res) == "string" then return res end
end

local function getJson(url)
    local body = getText(url)
    if not body then return nil end
    local ok, data = pcall(HttpService.JSONDecode, HttpService, body)
    return ok and data or nil
end

local function run(entry)

    local okSource, source = pcall(GET_SOURCE, entry.Key)
    if not okSource or type(source) ~= "string" then
        win:Notify({Title = "Catn Hub", Content = "Couldn't get the " .. entry.Name .. " script: " .. tostring(source), Type = "Error", Duration = 8})
        return false
    end
    local fn, err = loadstring(source, "=Catn Hub (" .. entry.Name .. ")")
    if not fn then
        win:Notify({Title = "Catn Hub", Content = entry.Name .. " didn't compile: " .. tostring(err), Type = "Error", Duration = 8})
        return false
    end
    local ok, res = pcall(fn, BPUI)

    if setthreadidentity then pcall(setthreadidentity, 8) end
    if not ok then
        warn("[Catn Hub] " .. entry.Name .. ": " .. tostring(res))
        win:Notify({Title = "Catn Hub", Content = entry.Name .. " failed to start: " .. tostring(res), Type = "Error", Duration = 8})
        return false
    end
    return true
end

local loaded = false
local function load(entry)
    if loaded then
        win:Notify({Title = entry.Name, Content = "Already loaded.", Type = "Info"})
        return
    end
    loaded = true
    if run(entry) then
        win:SetBadge(true)
        win:SetOpen(false)
        win:Notify({Title = entry.Name, Content = "Loaded. Click the Catn icon or press Right Ctrl to open the hub again.", Type = "Success"})
    else
        loaded = false
    end
end

local function unloadAll()
    local n = 0
    for _, w in ipairs(BPUI.Windows) do
        if not w.Destroyed then
            pcall(function() w:Destroy() end)
            n = n + 1
        end
    end
    BPUI.Windows = {}
    loaded = false
    if not win.Destroyed then win:SetBadge(false) end
    return n
end

BPUI.WindowGone = function()
    if win.Destroyed then return end
    for _, w in ipairs(BPUI.Windows) do
        if not w.Destroyed then return end
    end
    loaded = false
    win:SetBadge(false)
end

local function panic()
    unloadAll()
    win:Destroy()
end

local function openDiscord()
    local opened = false
    local send = request or http_request or (syn and syn.request) or (http and http.request)
    if send then
        local ok, res = pcall(send, {
            Url = "http://127.0.0.1:6463/rpc?v=1",
            Method = "POST",
            Headers = {["Content-Type"] = "application/json", ["Origin"] = "https://discord.com"},
            Body = HttpService:JSONEncode({cmd = "INVITE_BROWSER", args = {code = INVITE_CODE}, nonce = HttpService:GenerateGUID(false)}),
        })
        opened = ok and type(res) == "table" and res.StatusCode == 200
    end
    if opened then
        win:Notify({Title = "Discord", Content = "Opening the invite in Discord.", Type = "Success"})
        return
    end
    local copied = type(setclipboard) == "function" and pcall(setclipboard, INVITE_URL)
    if copied then
        win:Notify({Title = "Discord", Content = "Couldn't reach the Discord app, so the invite link was copied. Paste it in your browser.", Type = "Info", Duration = 7})
    else
        win:Notify({Title = "Discord", Content = INVITE_URL, Type = "Info", Duration = 12})
    end
end

local function rejoin()
    local ok, err
    if #Players:GetPlayers() <= 1 then
        ok, err = pcall(TeleportService.Teleport, TeleportService, game.PlaceId, plr)
    else
        ok, err = pcall(TeleportService.TeleportToPlaceInstance, TeleportService, game.PlaceId, game.JobId, plr)
    end
    if not ok then
        win:Notify({Title = "Rejoin", Content = "Couldn't teleport: " .. tostring(err), Type = "Error", Duration = 8})
    end
end

local function serverHop()
    win:Notify({Title = "Server hop", Content = "Looking for another server.", Type = "Info", Duration = 3})
    task.spawn(function()
        local data = getJson("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100&excludeFullGames=true")
        local list = data and data.data
        if type(list) ~= "table" then
            win:Notify({Title = "Server hop", Content = "Couldn't get the server list. Try again in a moment.", Type = "Error"})
            return
        end
        local choices = {}
        for _, s in ipairs(list) do
            if s.id ~= game.JobId and type(s.playing) == "number" and type(s.maxPlayers) == "number" and s.playing < s.maxPlayers - 1 then
                table.insert(choices, s)
            end
        end
        if #choices == 0 then
            win:Notify({Title = "Server hop", Content = "No other open server found.", Type = "Warning"})
            return
        end
        local pick = choices[math.random(1, #choices)]
        win:Notify({Title = "Server hop", Content = "Joining a server with " .. tostring(pick.playing) .. " players.", Type = "Success", Duration = 4})
        local ok, err = pcall(TeleportService.TeleportToPlaceInstance, TeleportService, game.PlaceId, pick.id, plr)
        if not ok then
            win:Notify({Title = "Server hop", Content = "Couldn't teleport: " .. tostring(err), Type = "Error", Duration = 8})
        end
    end)
end

local function debugInfo()
    local exec = "unknown"
    if type(identifyexecutor) == "function" then
        local ok, name, ver = pcall(identifyexecutor)
        if ok and name then exec = tostring(name) .. (ver and (" " .. tostring(ver)) or "") end
    end
    local names = {}
    for _, w in ipairs(BPUI.Windows) do
        if not w.Destroyed then table.insert(names, tostring(w.Title)) end
    end
    local missing = {}
    for n in pairs(Vanta.MissingIcons) do table.insert(missing, n) end
    table.sort(missing)
    return table.concat({
        "Catn Hub " .. HUB_VERSION,
        "Game: " .. gameName .. " (place " .. tostring(game.PlaceId) .. ", game " .. tostring(game.GameId) .. ")",
        "Server: " .. tostring(game.JobId),
        "Executor: " .. exec,
        "Loaded: " .. (#names > 0 and table.concat(names, ", ") or "nothing"),
        "Theme: " .. win.ThemeName,
        "Missing icons: " .. (#missing > 0 and table.concat(missing, ", ") or "none"),
        "Time: " .. os.date("!%Y-%m-%d %H:%M UTC"),
    }, "\n")
end

local home = win:Tab({Name = "Game", Icon = "gamepad-2", Desc = "What you're playing and which script fits"})
local here = home:Section("This game")
local nameRow = here:Stat({Name = "Game", Icon = "gamepad-2", Value = "..."})
here:Stat({Name = "Place ID", Icon = "hash", Value = tostring(game.PlaceId)})
local statusRow = here:Stat({Name = "Status", Icon = "shield-check", Value = "Checking"})
local result = home:Section("Result"):Paragraph({Title = "Checking this game", Content = "One moment."})

local community = home:Section("Community")
community.Frame.LayoutOrder = 9000
community:Button({Name = "Discord", Icon = "message-circle", Desc = "Join the Catn Hub server", ButtonText = "Join", Callback = openDiscord})

local utils = win:Tab({Name = "Utilities", Icon = "wrench", Desc = "Tools that work in every game"})

local session = utils:Section("Session")
session:Toggle({Name = "Anti AFK", Icon = "timer", Desc = "Stops the game kicking you for being idle", Flag = "anti_afk", Callback = antiAfk})

local comeBack = {on = true, loader = type(LOADER) == "string" and LOADER or ""}
local canQueue = type(queue_on_teleport) == "function"
local comeBackToggle = session:Toggle({Name = "Come back after a teleport", Icon = "refresh-cw", Default = true, Flag = "come_back",
    Desc = "Runs the hub again in the new server, so a restart or rejoin doesn't stop your farm",
    Callback = function(v) comeBack.on = v == true end})
if not canQueue then comeBackToggle:Lock() end
session:Input({Name = "Your loader line", Placeholder = "loadstring(game:HttpGet(...))()", Default = comeBack.loader, Flag = "come_back_loader",
    Desc = "The line you run to start the hub", DependsOn = comeBackToggle,
    Callback = function(text) comeBack.loader = tostring(text or "") end})
table.insert(win.Conns, plr.OnTeleport:Connect(function(teleportState)
    if teleportState ~= Enum.TeleportState.Started or not comeBack.on or not canQueue then return end
    if comeBack.loader:gsub("%s", "") == "" then return end
    pcall(queue_on_teleport, comeBack.loader)
end))
session:Button({Name = "Rejoin", Icon = "refresh-cw", Desc = "Leaves and comes straight back to this server", ButtonText = "Rejoin", Callback = function()
    win:Dialog({Title = "Rejoin this server?", Content = "You'll leave the game and come straight back. Anything unsaved is lost.",
        Buttons = {{Text = "Cancel"}, {Text = "Rejoin", Style = "Primary", Callback = rejoin}}})
end})
session:Button({Name = "Server hop", Icon = "shuffle", Desc = "Moves you to a different public server", ButtonText = "Hop", Callback = function()
    win:Dialog({Title = "Hop to another server?", Content = "You'll leave this server and join a different one.",
        Buttons = {{Text = "Cancel"}, {Text = "Hop", Style = "Primary", Callback = serverHop}}})
end})

local perf = utils:Section("Performance")
perf:Toggle({Name = "Low graphics", Icon = "monitor", Desc = "Lowers the quality level and turns shadows off", Flag = "low_gfx", Callback = lowGraphics})

local control = utils:Section("Scripts")
control:Button({Name = "Unload all", Icon = "power", Desc = "Turns off every script the hub loaded", ButtonText = "Unload", Style = "Danger", Callback = function()
    local n = unloadAll()
    win:SetOpen(true)
    win:Notify({Title = "Unloaded", Content = n == 0 and "Nothing was loaded." or ("Turned off " .. n .. (n == 1 and " script." or " scripts.")), Type = "Info"})
end})
control:Keybind({Name = "Panic key", Icon = "siren", Desc = "Unloads every script and closes the hub, no questions asked", Default = Enum.KeyCode.End, Callback = panic})

local about = utils:Section("About")
about:Stat({Name = "Version", Icon = "tag", Value = HUB_VERSION})
about:Button({Name = "Place ID", Icon = "hash", ButtonText = "Copy", Callback = function() copyText(tostring(game.PlaceId), "Place ID") end})
about:Button({Name = "Server ID", Icon = "server", ButtonText = "Copy", Callback = function() copyText(tostring(game.JobId), "Server ID") end})
about:Button({Name = "Debug info", Icon = "bug", Desc = "Copies details to paste when you report a problem", ButtonText = "Copy", Callback = function()
    copyText(debugInfo(), "Debug info")
end})

win.CatnApi = {
    load = load, unloadAll = unloadAll, panic = panic, rejoin = rejoin, serverHop = serverHop, debugInfo = debugInfo, antiAfk = antiAfk,
}

task.spawn(function()
    local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, game.PlaceId)
    if win.Destroyed then return end
    gameName = ok and info and info.Name or "Unknown"
    nameRow:Set(gameName)
end)

local function detect()
    local found, verdicts = nil, {}
    for i, entry in ipairs(GAMES) do
        local ok, yes = pcall(entry.Detect)
        verdicts[i] = ok and yes == true
        if verdicts[i] and not found then found = entry end
    end
    return found, verdicts
end

task.spawn(function()
    local found, verdicts = detect()
    if not found and not rs:FindFirstChild("Modules") then

        rs:WaitForChild("Modules", 4)
        found, verdicts = detect()
    end
    if win.Destroyed then return end

    if found then
        statusRow:Set("Supported")
        result:SetTitle(found.Name .. " is supported")
        result:Set("The script for this game is ready. Press Load to open its menu.")
        local sec = home:Section("Script")
        sec:Button({
            Name = found.Name, Icon = found.Icon, Desc = "Opens the full menu for this game", ButtonText = "Load", Style = "Primary",
            Callback = function() load(found) end,
        })
        local auto = sec:Toggle({
            Name = "Load automatically", Icon = "zap", Desc = "Loads it as soon as you join this game", Flag = "autoload_" .. found.Key,
        })
        if auto:Get() then
            win:Notify({Title = found.Name, Content = "Loading automatically. You can turn that off in the Game tab.", Type = "Info", Duration = 4})
            task.delay(1.5, function()
                if not win.Destroyed then load(found) end
            end)
        else
            win:Notify({Title = "Supported", Content = found.Name .. " is ready to load.", Type = "Success"})
        end
    else
        statusRow:Set("Not supported")
        result:SetTitle("This game isn't supported")
        result:Set("We only have scripts for Anime Battle Arena and Monday Morning Misery. Join one of them and run the hub again. The Utilities tab still works here.")
        win:Notify({Title = "Not supported", Content = "No script for this game yet.", Type = "Warning"})
    end

    local list = home:Section("Our scripts")
    for i, entry in ipairs(GAMES) do
        list:Stat({Name = entry.Name, Icon = entry.Icon,
            Value = "v" .. entry.Version .. "  ·  " .. (verdicts[i] and "This game" or "Not this game")})
    end
end)

local preview = win:Group({Name = "Preview", Open = false})

local controls = preview:Tab({Name = "Controls", Icon = "sliders-horizontal", Desc = "Toggles, sliders and pickers"})
local main = controls:Section("Example")
local sample = main:Toggle({Name = "Toggle", Desc = "Switches with a short slide", Flag = "sample_toggle"})
main:Keybind({Name = "Keybind", Default = Enum.KeyCode.F1, Flag = "sample_key", Callback = function() sample:Set(not sample:Get()) end})
main:Slider({Name = "Slider", Min = 0, Max = 100, Step = 5, Default = 40, Suffix = "%", Flag = "sample_slider"})
main:Dropdown({Name = "Dropdown", Options = {"First", "Second", "Third"}, Default = "First", Flag = "sample_drop"})
main:Dropdown({Name = "Multi select", Multi = true, Options = {"Red", "Green", "Blue"}, Default = {"Green"}, Flag = "sample_multi"})
main:Input({Name = "Text box", Placeholder = "Type here", Flag = "sample_input"})
main:ColorPicker({Name = "Color", Default = Color3.fromRGB(120, 160, 255), Flag = "sample_color"})

local parts = preview:Tab({Name = "Components", Icon = "bell", Desc = "Notifications and dialogs"})
local fx = parts:Section("Actions")
fx:Button({Name = "Notifications", Desc = "One of each kind", ButtonText = "Send", Callback = function()
    win:Notify({Title = "Settings saved", Content = "Your changes will apply next run.", Type = "Info"})
    task.wait(0.12)
    win:Notify({Title = "Run finished", Content = "42 caught in 6m 12s.", Type = "Success"})
    task.wait(0.12)
    win:Notify({Title = "Low health", Content = "Pausing until you recover.", Type = "Warning"})
    task.wait(0.12)
    win:Notify({Title = "Request failed", Content = "Couldn't reach the server.", Type = "Error"})
end})
fx:Button({Name = "Dialog", ButtonText = "Open", Callback = function()
    win:Dialog({Title = "Reset all settings?", Content = "Every option goes back to its default. This can't be undone.",
        Buttons = {{Text = "Cancel"}, {Text = "Reset", Style = "Danger"}}})
end})

end, function(e) return tostring(e) .. "\n" .. debug.traceback() end)
if not hubOk then
    warn("[catn hub] failed to start: " .. tostring(hubRes))
end
return hubRes
