# catn hub

the hub (picks the right script for whatever game you're in):

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/NNoradrenaline/catn-hub/main/dist/catn_hub.lua"))()
```

or just one game, no hub:

anime battle arena
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/NNoradrenaline/catn-hub/main/dist/games/aba.lua"))()
```

monday morning misery
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/NNoradrenaline/catn-hub/main/dist/games/mmm.lua"))()
```

climb for animals eggs
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/NNoradrenaline/catn-hub/main/dist/games/cfae.lua"))()
```

funky friday
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/NNoradrenaline/catn-hub/main/dist/games/ff.lua"))()
```

right ctrl opens the hub, right shift opens a game's menu. found a bug? tell me in the discord

## use the ui in your own script

works in any game. halloween and christmas themes switch on by themselves

```lua
local UI = loadstring(game:HttpGet("https://raw.githubusercontent.com/NNoradrenaline/catn-hub/main/dist/ui.lua"))()

local window = UI:CreateWindow({Title = "My Script", Subtitle = "Some Game", ToggleKey = Enum.KeyCode.RightShift, ConfigFolder = "MyScript"})
local tab = window:CreateTab({Name = "Main", Icon = "zap"})
local section = tab:CreateSection("Farm")

section:AddToggle({Name = "Auto farm", Default = false, Flag = "auto_farm", Callback = function(on) end})
section:AddSlider({Name = "Range", Min = 5, Max = 60, Default = 20, Flag = "range", Callback = function(v) end})
section:AddDropdown({Name = "Target", Options = {"Nearest", "Weakest"}, Default = "Nearest", Callback = function(v) end})
section:AddButton({Name = "Run", ButtonText = "Go", Callback = function() end})

window:Notify({Title = "Loaded", Content = "have fun", Type = "Success"})
```

every control is in [dist/example.lua](dist/example.lua). icons are [lucide](https://lucide.dev/icons) names
