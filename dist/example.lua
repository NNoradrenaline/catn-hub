-- every control in the catn ui, for copying into your own script. works in any game
local UI = loadstring(game:HttpGet("https://raw.githubusercontent.com/NNoradrenaline/catn-hub/main/dist/ui.lua"))()

local window = UI:CreateWindow({
    Title = "My Script",
    Subtitle = "Any game",
    Version = "1.0.0",
    ToggleKey = Enum.KeyCode.RightShift,
    ConfigFolder = "MyScript", -- toggles and sliders with a Flag are saved here and come back next time
})

local main = window:CreateTab({Name = "Main", Icon = "zap"})
local farm = main:CreateSection("Farm")

farm:AddToggle({Name = "Auto farm", Default = false, Flag = "auto_farm",
    Description = "Shows when you hover over the row",
    Callback = function(on) print("auto farm", on) end})

farm:AddSlider({Name = "Range", Min = 5, Max = 60, Default = 20, Increment = 1, Suffix = " studs", Flag = "range",
    Callback = function(value) print("range", value) end})

farm:AddDropdown({Name = "Target", Options = {"Nearest", "Weakest", "Random"}, Default = "Nearest", Flag = "target",
    Callback = function(choice) print("target", choice) end})

farm:AddKeybind({Name = "Toggle key", Default = Enum.KeyCode.F, Flag = "farm_key",
    Callback = function() print("key pressed") end})

local status = farm:AddLabel({Text = "idle", Style = "Sub"})
task.spawn(function()
    while task.wait(1) do status:Set("running for " .. math.floor(time()) .. "s") end
end)

local extra = main:CreateSection("Extras")
extra:AddButton({Name = "Say hi", ButtonText = "Run", Callback = function()
    window:Notify({Title = "Hi", Content = "Buttons, toggles and the rest all work like this.", Type = "Success", Duration = 4})
end})
extra:AddInput({Name = "Name", Placeholder = "type here", Flag = "name", Callback = function(text) print("typed", text) end})
extra:AddColorPicker({Name = "Colour", Default = Color3.fromRGB(255, 134, 40), Flag = "colour", Callback = function(c) print(c) end})
extra:AddParagraph({Title = "Notes", Content = "A paragraph for longer text. :SetContent() changes it later."})

-- a second tab shows up in the dock at the bottom. Settings (theme, blur, scale, menu key) is added for you
local other = window:CreateTab({Name = "Other", Icon = "settings-2"})
other:CreateSection("More"):AddToggle({Name = "Something else", Default = true, Callback = function() end})
