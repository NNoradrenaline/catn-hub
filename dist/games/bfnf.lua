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

local function laneQueue(lane)
    if not fns.input then return nil end
    local okUp, q = pcall(debug.getupvalue, fns.input, 5)
    local sideQ = okUp and type(q) == "table" and q[getSide()]
    local entry = type(sideQ) == "table" and sideQ[lane]
    if type(entry) == "table" and type(entry.notes) == "table" and type(entry.index) == "number" then return entry end
    return nil
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

local auto = {enabled = false, offsetMs = 0, humanize = false, missChance = 2, goodChance = 10, jitter = 10,
    aim = false, aimTarget = 96}
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

local aimHit, aimState, newAim

local function logHit(ms)
    if aimHit then aimHit(ms) end
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
    if newAim then aimState = newAim() end
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

newAim = function()

    return {obj = nil, nextSearch = 0, A = 0, N = 0, N0 = nil, worths = {}, sums = {[0] = 0}, heads = nil, floor = nil,
        M = 0, M0 = nil, missedAt = {}, pressAt = {}, planned = setmetatable({}, {__mode = "k"})}
end
aimState = newAim()

local function worthAt(ms)
    local x = ms / 200
    return math.max(0, 1 - x * x)
end

local function addWorth(w)
    local a = aimState
    table.insert(a.worths, w)
    a.sums[#a.worths] = a.sums[#a.worths - 1] + w
    return #a.worths
end

local function setWorth(i, w)
    local a = aimState
    a.worths[i] = w
    for j = i, #a.worths do a.sums[j] = a.sums[j - 1] + a.worths[j] end
end

local pressingNote
aimHit = function(ms)
    if not auto.aim then return end
    local i = pressingNote and aimState.planned[pressingNote]
    if i then setWorth(i, worthAt(math.abs(ms))) else addWorth(worthAt(math.abs(ms))) end
end

local function findScore()
    local a = aimState
    if a.obj and a.obj.Parent and a.obj.Value == plr then return a.obj end
    if os.clock() < a.nextSearch then return nil end
    a.obj = nil
    local function look(root)
        for _, v in ipairs(root:GetDescendants()) do
            if v:IsA("ObjectValue") and v.Value == plr and v:GetAttribute("Notes") ~= nil and v:GetAttribute("Accuracy") ~= nil then
                return v
            end
        end
    end
    local personal = workspace:FindFirstChild("PersonalStages")
    a.obj = personal and look(personal) or nil
    if not a.obj then
        a.obj = look(workspace)
        a.nextSearch = os.clock() + 3
    end
    return a.obj
end

local function readScore()
    local obj = findScore()
    if not obj then return end
    local a = aimState
    a.A = tonumber(obj:GetAttribute("Accuracy")) or 0
    a.N = tonumber(obj:GetAttribute("Notes")) or 0
    a.M = tonumber(obj:GetAttribute("Miss")) or 0
    if not a.N0 then a.N0, a.M0 = a.N, a.M end
end

local function liveAccuracy()
    local a = aimState
    if a.N <= 0 then return nil end
    return math.floor(a.A / a.N * 10000) / 100
end

local function expectedScore()
    local a = aimState
    local now = os.clock()
    local judged = a.N - (a.N0 or a.N)
    a.unplanned = 0
    if a.M0 then
        local plannedSeen = 0
        for _, t in ipairs(a.missedAt) do
            if now - t > 0.6 then plannedSeen = plannedSeen + 1 end
        end
        a.unplanned = math.max(0, a.M - a.M0 - plannedSeen)
        judged = judged - a.unplanned
    end
    local counted = math.clamp(judged, 0, #a.worths)
    local waiting = #a.worths - counted
    return a.A + (a.sums[#a.worths] - a.sums[counted]), a.N + waiting
end

local function countChart()
    local heads, maxIndex, entries, chart = 0, 0, 0, {}
    for _, f in ipairs(getgc()) do
        if type(f) == "function" and islclosure(f) then
            local okL, line = pcall(debug.info, f, "l")
            if okL and line == 1372 then
                local okS, src = pcall(function() return debug.info(f, "s") end)
                if okS and type(src) == "string" and src:find("songPlay") then
                    local ups = {}
                    for i = 1, 24 do
                        local okU, v = pcall(debug.getupvalue, f, i)
                        if not okU then break end
                        ups[i] = v
                    end
                    for i, v in pairs(ups) do
                        if type(v) == "table" and type(v[1]) == "number" and v[2] ~= nil then
                            entries = entries + 1
                            if type(ups[i - 1]) == "number" then maxIndex = math.max(maxIndex, ups[i - 1]) end
                            if type(v[2]) == "number" then
                                heads = heads + 1

                                local rate, scaled = 1, ups[i + 5]
                                if type(scaled) == "number" and scaled > 0 and v[1] > 0 then
                                    local r = v[1] / scaled
                                    if r > 0.25 and r < 4 then rate = r end
                                end
                                table.insert(chart, {t = v[1] / rate, lane = v[2]})
                            end
                            break
                        end
                    end
                end
            end
        end
    end
    return heads, maxIndex, entries, chart
end

local FINAL_NOTES, CLOSE_NOTES = 60, 15

local function planned(r, goal)
    if r <= 0 then return 0 end
    local final = math.min(0.999, math.max(0.96, 2 * goal - 1))
    local close = math.min(0.9995, math.max(final, 0.995, 1 - (1 - goal) / 2))
    local n = math.min(r, CLOSE_NOTES)
    return n * close + math.max(0, math.min(r, FINAL_NOTES) - n) * final
end

local function songFloor(chart)
    local byLane = {}
    for _, n in ipairs(chart) do
        byLane[n.lane] = byLane[n.lane] or {}
        table.insert(byLane[n.lane], n)
    end
    for _, list in pairs(byLane) do
        table.sort(list, function(x, y) return x.t < y.t end)
        for i, n in ipairs(list) do
            local before = list[i - 1] and (n.t - list[i - 1].t) * 1000 or math.huge
            local after = list[i + 1] and (list[i + 1].t - n.t) * 1000 or math.huge
            if after > 140 + 125 then
                n.least = 0
            else
                n.least = worthAt(math.min(105, 0.45 * after, math.max(0, before - 20)))
            end
        end
    end
    table.sort(chart, function(x, y) return x.t < y.t end)
    local A = 1
    for i, n in ipairs(chart) do
        if i <= #chart - FINAL_NOTES then A = A + (n.least or 0.72) end
    end
    return (A + planned(math.min(#chart, FINAL_NOTES), 0.5)) / (#chart + 1)
end

local function aimGoal()
    local floor = aimState.floor
    local want = auto.aimTarget / 100
    if floor and want < floor + 0.002 then want = math.ceil((floor + 0.002) * 10000) / 10000 end

    return want + 0.00005
end

local function aimNeed()
    local a = aimState
    local A, N = expectedScore()
    local goal = aimGoal()
    local need
    if a.heads and a.heads > #a.worths + (a.unplanned or 0) then
        local headsLeft = a.heads - #a.worths - (a.unplanned or 0)
        local total = N + headsLeft
        if headsLeft > FINAL_NOTES then
            need = (goal * total - A - planned(FINAL_NOTES, goal)) / (headsLeft - FINAL_NOTES)
        else
            need = goal * total - A - planned(headsLeft - 1, goal)
        end
    else

        need = goal * (N + 1) - A
    end
    if need < 0.72 then return nil end
    return math.min(need, 1)
end

local function aimPlan(note, y, speed)
    local need = aimNeed()
    if speed <= 0 then
        if need then return 0 end
        addWorth(0)
        table.insert(aimState.missedAt, os.clock())
        return false
    end

    local lane = note.Parent
    local now = os.clock()
    local arrive = now + y / speed
    local earliest, latest = 105, 105
    local prev = aimState.pressAt[lane]
    if prev then earliest = math.min(earliest, (arrive - prev) * 1000 - 20) end
    local nextGap = math.huge
    for _, other in ipairs(lane:GetChildren()) do
        if other ~= note and other:GetAttribute("Type") == "Note" and not hit[other] then
            local gap = (other.Position.Y.Scale * (G.Settings and G.Settings.Direction or 1) - y) / speed * 1000
            if gap > 0 then nextGap = math.min(nextGap, gap) end
        end
    end
    latest = math.min(latest, nextGap * 0.45)

    if not need then
        if nextGap > 140 + 125 then
            addWorth(0)
            table.insert(aimState.missedAt, now)
            aimState.pressAt[lane] = arrive + 0.14
            return false
        end
        need = 0.72
    end
    local best, bestErr
    for k = 0, 30 do
        local ms = (y - speed * avgDt * k) / speed * 1000
        if ms < -latest then break end
        if ms <= earliest then
            local err = math.abs(worthAt(math.abs(ms)) - need)
            if not bestErr or err < bestErr then best, bestErr = ms, err end
        end
    end
    best = best or 0
    aimState.pressAt[lane] = arrive - best / 1000
    aimState.planned[note] = addWorth(worthAt(math.abs(best)))
    return -best
end

local function planFor(note, y, speed)
    if plan[note] ~= nil then return plan[note] end
    local late = -auto.offsetMs
    if auto.aim then

        if speed > 0 and y > speed * 0.15 then return nil end
        local off = aimPlan(note, y, speed)
        plan[note] = off
        return off
    elseif auto.humanize then
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
    local queue = laneQueue(lane)
    if queue then

        local n = queue.notes[queue.index]
        if n and n.Parent == notes and not hit[n] then nextNote, nextY = n, n.Position.Y.Scale * dir end
    else
        for _, n in ipairs(notes:GetChildren()) do
            if n:GetAttribute("Type") == "Note" and not hit[n] then
                local y = n.Position.Y.Scale * dir
                if y > -1.5 and (not nextY or y < nextY) then nextNote, nextY = n, y end
            end
        end
    end

    if nextNote then
        local speed = vel or (lastY[nextNote] and (lastY[nextNote] - nextY) / math.max(dt, 1e-3)) or 0
        lastY[nextNote] = nextY
        local late = planFor(nextNote, nextY, speed)
        if late == nil then

        elseif late == false then

            if nextY < 0 then hit[nextNote] = true end
        else

            local target = speed > 0 and -late / 1000 * speed or 0
            if nextY <= target or (speed > 0 and nextY - target <= speed * avgDt / 2) then
                pressingNote = nextNote
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
    if not playing and auto.aim then
        local a = aimState

        task.spawn(function()
            for _ = 1, 40 do
                if aimState ~= a or not matchFrame.Visible then return end
                local okC, heads, maxIndex, entries, chart = pcall(countChart)
                if okC and heads > 0 then
                    local okF, floor = pcall(songFloor, chart)
                    if okF then a.floor = floor end
                    a.heads = heads + math.max(0, maxIndex - entries)
                    return
                end
                task.wait(0.5)
            end
        end)
    end
    playing = true
    if auto.aim then
        pcall(readScore)
    end
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

local window = BPUI:CreateWindow({Version = "1.1.0",
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
state.Aim = function() return aimState end
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

local aimSec = tab:CreateSection("Accuracy target")
ctl.aim = aimSec:AddToggle({Name = "Aim for an accuracy", Default = false, Flag = "bfnf_aim",
    Description = "Finishes the song on exactly the accuracy you pick, by hitting each note just off enough. Under about 72% it misses some notes on purpose. Replaces Humanize while on.",
    Callback = function(v) auto.aim = v == true end})
ctl.aimTarget = aimSec:AddSlider({Name = "Target", DependsOn = ctl.aim, Min = 1, Max = 99.9, Default = 96, Increment = 0.01, Suffix = " %", Flag = "bfnf_aim_target",
    Description = "Click the number to type an exact value. Tops out at 99.9%: a press can only land on a frame, so even a perfect hit is a few ms off.",
    Callback = function(v) auto.aimTarget = tonumber(v) or 96 end})
local aimLbl = aimSec:AddLabel({Text = "-", Style = "Sub"})

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
    {name = "Perfect", s = {offset = 0, humanize = false, aim = false}},
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
            ctl.aim:Set(s.aim == true)
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
            if auto.aim and matchFrame.Visible then
                local acc = liveAccuracy()
                local goal = math.floor((aimGoal() - 0.00005) * 10000 + 0.5) / 100
                local floor = aimState.floor and math.ceil((aimState.floor + 0.002) * 10000) / 100
                local note = ""
                if floor and goal > auto.aimTarget + 0.001 then
                    note = string.format(" (lowest this song allows: %.2f%%)", floor)
                end
                aimLbl:Set(acc and string.format("now %.2f%%, aiming for %.2f%%%s", acc, goal, note)
                    or (aimState.obj and "waiting for the first note" or "looking for your score"))
            else
                aimLbl:Set("-")
            end
        end)
        task.wait(0.5)
    end
end)

window:SelectTab("Autoplay")
pcall(function()
    window:Notify({Title = "Basically FNF", Content = "loaded, F1 to toggle", Type = "Success", Duration = 4})
end)

return state
