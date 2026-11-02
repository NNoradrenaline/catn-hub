if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local plr = Players.LocalPlayer
while not plr do task.wait() plr = Players.LocalPlayer end

local genv = getgenv and getgenv() or _G
if genv.__BFNF_AUTOPLAY and genv.__BFNF_AUTOPLAY.Destroy then
    pcall(genv.__BFNF_AUTOPLAY.Destroy)
end

local BPUI = ... or loadstring(game:HttpGet("https://raw.githubusercontent.com/NNoradrenaline/catn-hub/main/dist/ui.lua"))()

local G = getrenv()._G
local main = plr:WaitForChild("PlayerGui"):WaitForChild("Main")
local matchFrame = main:WaitForChild("MatchFrame")
local judgments = matchFrame:FindFirstChild("JudgmentsFrame")

local fns = {}
local function findFns()
    fns = {}
    for _, f in ipairs(getgc()) do
        if type(f) == "function" and islclosure(f) then
            local okSrc, src = pcall(function() return debug.info(f, "s") end)
            if okSrc and type(src) == "string" and src:find("songPlay") then
                local name = debug.info(f, "n")
                if name == "KeyPress" then fns.press = f
                elseif name == "KeyLift" then fns.lift = f
                elseif name == "NoteInput" then fns.input = f
                elseif name == "CreateNote" then fns.create = f end
            end
        end
    end

    fns.sideSlot = nil
    if fns.create then
        for i = 1, 30 do
            local okUp, v = pcall(debug.getupvalue, fns.create, i)
            if not okUp then break end
            if type(v) == "boolean" then
                local okNext, nxt = pcall(debug.getupvalue, fns.create, i + 1)
                if okNext and (nxt == 1 or nxt == 2) then fns.sideSlot = i + 1 end
                break
            end
        end
    end
    return fns.press ~= nil and fns.lift ~= nil
end

local function getSide()
    if fns.sideSlot then
        local okUp, s = pcall(debug.getupvalue, fns.create, fns.sideSlot)
        if okUp and (s == 1 or s == 2) then return s end
    end
    return 1
end

local function noteVelocity()
    if not fns.input then return nil end
    local okUp, spd = pcall(debug.getupvalue, fns.input, 4)
    if okUp and type(spd) == "number" and spd > 0 then return spd * 5.5 end
    return nil
end

local DEFAULT_KEYS = {"A", "S", "W", "D"}
local function fakeInput(lane)
    local bind = G.Settings and G.Settings.Inputs and G.Settings.Inputs[lane]
    local okKey, kc = pcall(function() return Enum.KeyCode[tostring(bind)] end)
    if not okKey or not kc then kc = Enum.KeyCode[DEFAULT_KEYS[lane]] end
    return {UserInputType = Enum.UserInputType.Keyboard, KeyCode = kc, UserInputState = Enum.UserInputState.Begin}
end

local auto = {enabled = false, offsetMs = 0, humanize = false, missChance = 2, goodChance = 10, jitter = 10}
local alive = true
local conns = {}
local held = {false, false, false, false}
local tapEnd = {0, 0, 0, 0}
local maxHold = {0, 0, 0, 0}
local hit = setmetatable({}, {__mode = "k"})
local lastY = setmetatable({}, {__mode = "k"})

local plan = setmetatable({}, {__mode = "k"})
local avgDt = 1 / 60
local side = 1
local problem
local warned = 0
local songLog = {}

local function newTiming()
    return {hits = 0, total = 0, worst = 0, perfect = 0, sick = 0, good = 0, other = 0}
end
local timing = newTiming()
local playing = false

local function logHit(ms)
    ms = math.abs(ms)
    timing.hits = timing.hits + 1
    timing.total = timing.total + ms
    timing.worst = math.max(timing.worst, ms)
    if ms <= 16.5 then timing.perfect = timing.perfect + 1
    elseif ms <= 43.5 then timing.sick = timing.sick + 1
    elseif ms <= 76.5 then timing.good = timing.good + 1
    else timing.other = timing.other + 1 end
end

local function counter(frame, label)
    local f = judgments and judgments:FindFirstChild(frame)
    local l = f and f:FindFirstChild(label)
    return l and tonumber(l.Text) or 0
end

local function gameCounts()
    return {
        perfect = counter("Perfect", "PerfCounter"), sick = counter("Sick", "SCounter"),
        good = counter("Good", "GCounter"), okay = counter("Okay", "OkCounter"),
        bad = counter("Bad", "BCounter"), combo = counter("ComboCounter", "CCounter"),
    }
end

local function songEnded()
    if timing.hits < 10 then timing = newTiming() return end
    local c = gameCounts()
    local line = string.format("%d notes  perfect %d  sick %d  good %d  |  avg %.1fms, worst %.1fms",
        timing.hits, c.perfect, c.sick, c.good + c.okay + c.bad, timing.total / timing.hits, timing.worst)
    table.insert(songLog, 1, line)
    if #songLog > 8 then table.remove(songLog) end
    timing = newTiming()

    local catnBus = getgenv and getgenv().CatnBus
    if catnBus then pcall(catnBus.emit, "song_finished", {title = "Song finished", text = line, tags = "musical_note"}) end
end

local function call(fn, lane)
    local okCall, err = pcall(fn, fakeInput(lane), false)
    if not okCall and warned < 3 then
        warned = warned + 1
        warn("[bfnf] " .. tostring(err))
    end
end

local function down(lane)
    if held[lane] then call(fns.lift, lane) end
    call(fns.press, lane)
    held[lane] = true
end

local function up(lane)
    if not held[lane] then return end
    call(fns.lift, lane)
    held[lane] = false
end

local function releaseAll()
    for lane = 1, 4 do up(lane) end
end

local function holdingTail(arrow, dir)
    local hold = arrow:FindFirstChild("Hold")
    local box = hold and hold:FindFirstChild("Hitbox")
    if not box then return false end
    for _, tail in ipairs(box:GetChildren()) do
        if tail:IsA("GuiObject") and tail:GetAttribute("LNHold") ~= nil
            and math.abs(tail.Size.Y.Scale) + tail.Position.Y.Scale * dir > 0.4 then
            return true
        end
    end
    return false
end

local function planFor(note)
    if plan[note] ~= nil then return plan[note] end
    local late = -auto.offsetMs
    if auto.humanize then
        local roll = math.random() * 100
        if roll < auto.missChance then
            plan[note] = false
            return false
        elseif roll < auto.missChance + auto.goodChance then

            late = late + (math.random() < 0.5 and -1 or 1) * (50 + math.random() * 20)
        else
            late = late + (math.random() * 2 - 1) * auto.jitter
        end
    end
    plan[note] = late
    return late
end

local function playLane(keys, lane, dt, vel, dir, now)
    local arrow = keys:FindFirstChild("Arrow" .. lane)
    local notes = arrow and arrow:FindFirstChild("Notes")
    if not notes then return end

    local nextNote, nextY
    for _, n in ipairs(notes:GetChildren()) do
        if n:GetAttribute("Type") == "Note" and not hit[n] then
            local y = n.Position.Y.Scale * dir
            if y > -1.5 and (not nextY or y < nextY) then nextNote, nextY = n, y end
        end
    end

    if nextNote then
        local speed = vel or (lastY[nextNote] and (lastY[nextNote] - nextY) / math.max(dt, 1e-3)) or 0
        lastY[nextNote] = nextY
        local late = planFor(nextNote)
        if late == false then

            if nextY < 0 then hit[nextNote] = true end
        else

            local target = speed > 0 and -late / 1000 * speed or 0
            if nextY <= target or (speed > 0 and nextY - target <= speed * avgDt / 2) then
                if speed > 0 then logHit(nextY / speed * 1000) end
                hit[nextNote] = true
                down(lane)
                tapEnd[lane] = now + 0.045
                maxHold[lane] = now + 15
            end
        end
    end

    if held[lane] and now >= tapEnd[lane] and (not holdingTail(arrow, dir) or now > maxHold[lane]) then
        up(lane)
    end
end

local function step(dt)
    if not matchFrame.Visible then
        if playing then
            playing = false
            releaseAll()
            songEnded()
        end
        return
    end
    playing = true
    if not auto.enabled or problem then
        releaseAll()
        return
    end

    local s = getSide()
    if s ~= side then
        releaseAll()
        side = s
    end

    avgDt = avgDt + (math.clamp(dt, 1 / 240, 0.1) - avgDt) * 0.1
    local keys = matchFrame:FindFirstChild("KeySync" .. side)
    if not keys then return end
    local vel = noteVelocity()
    local dir = G.Settings and G.Settings.Direction or 1
    local now = os.clock()
    for lane = 1, 4 do
        playLane(keys, lane, dt, vel, dir, now)
    end
end

if not findFns() then
    problem = "couldn't find the game's key functions, the game may have updated"
end
table.insert(conns, RunService.RenderStepped:Connect(function(dt)
    local okStep, err = pcall(step, dt)
    if not okStep and warned < 3 then
        warned = warned + 1
        warn("[bfnf] " .. tostring(err))
    end
end))

local window = BPUI:CreateWindow({Version = "1.0.0",
    Title = "Basically FNF", Subtitle = "Autoplay",
    Icon = "music", Theme = "Void", Accent = Color3.fromRGB(236, 112, 160),
    ToggleKey = Enum.KeyCode.RightShift, ShowSettings = true, ConfigFolder = "BFNFAutoplay",
    Watermark = false, CloseBehavior = "Hide",
    OnDestroy = function()
        alive = false
        auto.enabled = false
        releaseAll()
        for _, c in ipairs(conns) do c:Disconnect() end
    end,
})

local state = {Auto = auto, Log = songLog}
state.Destroy = function() pcall(function() window:Destroy() end) end
state.Problem = function() return problem end
state.Side = getSide
state.Window = window
genv.__BFNF_AUTOPLAY = state

local tab = window:CreateTab({Name = "Autoplay", Icon = "music"})
local sec = tab:CreateSection("Autoplay")
local toggle = sec:AddToggle({Name = "Auto play", Default = false, Flag = "bfnf_enabled",
    Description = "Hits every note on your side, holds included, timed for Perfects. Finds your side by itself and keeps playing with Roblox in the background.",
    Callback = function(v)
        auto.enabled = v == true and alive
        if not auto.enabled then releaseAll() end
    end})
sec:AddKeybind({Name = "Key", Default = Enum.KeyCode.F1, Mode = "Press", Flag = "bfnf_key",
    Callback = function() toggle:Set(not auto.enabled) end})
sec:AddButton({Name = "Find the game's functions again", ButtonText = "Rescan",
    Description = "Only needed if the status says it couldn't find them.",
    Callback = function()
        if findFns() then
            problem = nil
            window:Notify({Title = "Basically FNF", Content = "Found them.", Type = "Success", Duration = 3})
        else
            window:Notify({Title = "Basically FNF", Content = "Still can't find them. Join a song and try again.", Type = "Warning", Duration = 4})
        end
    end})
local statusLbl = sec:AddLabel({Text = "starting", Style = "Sub"})
local countsLbl = sec:AddLabel({Text = "-", Style = "Sub"})
local timingLbl = sec:AddLabel({Text = "-", Style = "Sub"})

local ctl = {}

local timingSec = tab:CreateSection("Timing")
ctl.offset = timingSec:AddSlider({Name = "Offset", Min = -40, Max = 40, Default = 0, Increment = 1, Suffix = " ms", Flag = "bfnf_offset",
    Description = "Positive presses earlier. Leave it at 0 for Perfects.",
    Callback = function(v) auto.offsetMs = tonumber(v) or 0 end})

local human = tab:CreateSection("Humanize")
ctl.humanize = human:AddToggle({Name = "Humanize", Default = false, Flag = "bfnf_humanize",
    Description = "Mixes in misses, Goods and small timing errors so it doesn't play perfectly.",
    Callback = function(v) auto.humanize = v == true end})
ctl.miss = human:AddSlider({Name = "Miss chance", DependsOn = ctl.humanize, Min = 0, Max = 15, Default = 2, Increment = 1, Suffix = " %", Flag = "bfnf_miss",
    Callback = function(v) auto.missChance = tonumber(v) or 0 end})
ctl.good = human:AddSlider({Name = "Good chance", DependsOn = ctl.humanize, Min = 0, Max = 40, Default = 10, Increment = 1, Suffix = " %", Flag = "bfnf_good",
    Callback = function(v) auto.goodChance = tonumber(v) or 0 end})
ctl.jitter = human:AddSlider({Name = "Timing jitter", DependsOn = ctl.humanize, Min = 0, Max = 40, Default = 10, Increment = 1, Suffix = " ms", Flag = "bfnf_jitter",
    Description = "Random error on normal hits. Under 16.5 ms is still a Perfect, under 43.5 ms a Sick.",
    Callback = function(v) auto.jitter = tonumber(v) or 0 end})

local PRESETS = {
    {name = "Perfect", s = {offset = 0, humanize = false}},
    {name = "Looks human", s = {offset = 0, humanize = true, miss = 1, good = 8, jitter = 20}},
    {name = "Sloppy", s = {offset = 0, humanize = true, miss = 5, good = 25, jitter = 35}},
}
local presetNames = {}
for _, p in ipairs(PRESETS) do table.insert(presetNames, p.name) end

local presetSec = tab:CreateSection("Presets")
local chosenPreset = "Perfect"
presetSec:AddDropdown({Name = "Preset", Options = presetNames, Default = "Perfect",
    Callback = function(v) chosenPreset = v end})
presetSec:AddButton({Name = "Use this preset", ButtonText = "Apply", Callback = function()
    for _, p in ipairs(PRESETS) do
        if p.name == chosenPreset then
            local s = p.s
            ctl.offset:Set(s.offset)
            if s.miss then ctl.miss:Set(s.miss) end
            if s.good then ctl.good:Set(s.good) end
            if s.jitter then ctl.jitter:Set(s.jitter) end
            ctl.humanize:Set(s.humanize)
            window:Notify({Title = "Preset", Content = chosenPreset .. " applied.", Type = "Success", Duration = 3})
        end
    end
end})

local logSec = tab:CreateSection("Song log")
local logText = logSec:AddParagraph({Title = "Last songs", Content = "none yet"})

task.spawn(function()
    while alive do
        pcall(function()
            local txt
            if problem then
                txt = problem
            elseif not auto.enabled then
                txt = "off"
            elseif matchFrame.Visible then
                txt = "playing side " .. getSide()
            else
                txt = "waiting for a song"
            end
            statusLbl:Set(txt)
            if matchFrame.Visible then
                local c = gameCounts()
                countsLbl:Set(string.format("combo %d  |  perfect %d  sick %d  good %d  ok %d  bad %d",
                    c.combo, c.perfect, c.sick, c.good, c.okay, c.bad))
                if timing.hits > 0 then
                    timingLbl:Set(string.format("timing: avg %.1fms, worst %.1fms over %d notes",
                        timing.total / timing.hits, timing.worst, timing.hits))
                else
                    timingLbl:Set("timing: -")
                end
            else
                countsLbl:Set("-")
                timingLbl:Set("-")
            end
            logText:SetContent(#songLog > 0 and table.concat(songLog, "\n") or "none yet")
        end)
        task.wait(0.5)
    end
end)

window:SelectTab("Autoplay")
pcall(function()
    window:Notify({Title = "Basically FNF", Content = "loaded, F1 to toggle", Type = "Success", Duration = 4})
end)

return state
