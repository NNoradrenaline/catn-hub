if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local plr = Players.LocalPlayer
while not plr do task.wait() plr = Players.LocalPlayer end

local genv = getgenv and getgenv() or _G
if genv.__FF_AUTOPLAY and genv.__FF_AUTOPLAY.Destroy then
    pcall(genv.__FF_AUTOPLAY.Destroy)
end

local BPUI = ... or loadstring(game:HttpGet("https://raw.githubusercontent.com/NNoradrenaline/catn-hub/main/dist/ui.lua"))()

local WORKER = [==[
local id = ...
local ch = get_comm_channel(id)

local started, startErr = pcall(function()
local RunService = game:GetService("RunService")
local env = getgenv and getgenv() or _G
if env.__FF_WORKER then pcall(env.__FF_WORKER) end

local cfg = {enabled = false, offsetMs = 0, humanize = false, missChance = 2, goodChance = 10, okChance = 0, badChance = 0, jitter = 15,
    spamWorse = 1.5, aim = false, aimTarget = 96}
local fw
local conns = {}
local alive = true
local presses, status = 0, "off"
local plans = setmetatable({}, {__mode = "k"})
local planVer = 0

local held = {}
local lastField
local song

local pressedAt = setmetatable({}, {__mode = "k"})
local lastDt = 0
local missLog = {}

local function newSong(field)
    song = {field = field, acc = 0, judged = 0, misses = 0, combo = 0, best = 0, counts = {}, title = "-"}
    if not field then return end
    pcall(function()
        local data = fw.Songs.SongData[field.Game.Song]
        song.title = data and (data.Title or data.Name) or tostring(field.Game.Song)
    end)
end
newSong(nil)

local function framework()
    if not fw then
        fw = filtergc("table", {Keys = {"VSRG", "Configs"}}, true)
        if fw then

            pcall(function()
                table.insert(conns, fw.EventAction:Bind("ScoreCalculated"):Connect(function(field, note, score, value, ms, acc)
                    if field ~= song.field then return end
                    song.judged = song.judged + 1
                    song.acc = song.acc + (tonumber(acc) or 0)
                    local name = score and score.Name or "?"
                    song.counts[name] = (song.counts[name] or 0) + 1
                    if (tonumber(value) or 0) > 0 then
                        song.combo = song.combo + 1
                        if song.combo > song.best then song.best = song.combo end
                    else
                        song.misses = song.misses + 1
                        song.combo = 0
                        local p = note and plans[note]
                        local why
                        if p and p.skip then
                            why = "skipped on purpose"
                        elseif note and pressedAt[note] then
                            why = string.format("pressed, game judged %s ms", tostring(ms and math.floor(ms + 0.5)))
                        elseif lastDt > 0.05 then
                            why = string.format("never pressed, %d ms frame", math.floor(lastDt * 1000 + 0.5))
                        else
                            why = "never pressed"
                        end
                        local t = note and tonumber(note.Time)
                        table.insert(missLog, 1, string.format("%s  lane %s  %s", t and string.format("%d:%05.2f", math.floor(t / 60), t % 60) or "?",
                            tostring(note and note.LaneIndex or "?"), why))
                        if #missLog > 12 then table.remove(missLog) end
                    end
                end))
            end)
        end
    end
    return fw
end

local function currentAcc()
    return song.judged > 0 and song.acc / song.judged or 100
end

-- notes per second (all lanes, real time) around t: a human slips more on spam streams
local function notesPerSec(field, t, pb)
    local n = 0
    for _, lane in pairs(field and field.Lanes or {}) do
        if type(lane.Notes) == "table" then
            for _, o in pairs(lane.Notes) do
                if type(o.Time) == "number" and math.abs(o.Time - t) <= 0.5 * pb then n = n + 1 end
            end
        end
    end
    return n
end

-- 0 under 7 notes/s, rising to 1 at 15 notes/s, times the "Worse on spam" slider
local function spamLevel(nps, strength)
    return math.clamp((nps - 7) / 8, 0, 1) * (tonumber(strength) or 0)
end

local function planFor(note, field, pb)
    local p = plans[note]
    if p and p.ver == planVer then return p end
    p = {ver = planVer, ms = 0}
    local side = math.random() < 0.5 and -1 or 1
    if cfg.aim then
        local acc = currentAcc()
        if song.judged > 10 and acc > cfg.aimTarget + 1.5 and math.random() < 0.25 then
            p.skip = true
        elseif acc > cfg.aimTarget then
            p.ms = side * (60 + math.random() * 22)
        end
    elseif cfg.humanize then

        local hold = (tonumber(note.Length) or 0) > 0
        if hold then side = -1 end
        local spam = spamLevel(notesPerSec(field, note.Time, pb or 1), cfg.spamWorse)
        local k = 1 + spam * 1.5
        local miss, good = cfg.missChance * k + spam * 2, cfg.goodChance * k + spam * 6
        local ok, bad = cfg.okChance * k + spam * 4, cfg.badChance * k + spam * 1.5
        local roll = math.random() * 100
        if roll < miss then
            p.skip = true
        elseif roll < miss + good then
            p.ms = side * (hold and 85 + math.random() * 30 or 56 + math.random() * 26)
        elseif roll < miss + good + ok then

            p.ms = side * (hold and 160 + math.random() * 14 or 118 + math.random() * 14)
        elseif roll < miss + good + ok + bad then

            p.ms = side * (hold and 176 + math.random() * 8 or 160 + math.random() * 12)
        else
            p.ms = (math.random() * 2 - 1) * math.min(cfg.jitter * (1 + spam), 48)
        end
    end
    plans[note] = p
    return p
end

local function releaseAll(field)
    for i in pairs(held) do
        if field then pcall(field.HitLane, field, i, false, os.clock()) end
        held[i] = nil
    end
end

local function step(dt)
    lastDt = dt
    local f = framework()
    local gh = f and f.VSRG.GameHandler
    local field = gh and gh.Field
    local g = field and field.Game
    if not cfg.enabled then
        releaseAll(lastField)
        status = "off"
        return
    end
    if not f then status = "can't find the game's code yet" return end
    if not g or g.Ending or not field.Lanes then
        releaseAll(lastField)
        status = "waiting for a song"
        return
    end
    if field ~= lastField then
        releaseAll(lastField)
        lastField = field
        newSong(field)
        table.clear(missLog)
    end
    status = "playing"

    local cfgs = f.Configs.VSRG
    local ignored = cfgs.IgnoredNoteTypes or {}
    local pb = g.AdjustedPlayback or 1
    local clock = os.clock()

    local sample = g.TimePositionSample
    local now
    if sample and type(sample.Clock) == "number" then
        now = (sample.Position or 0) + math.clamp(clock - sample.Clock, -0.25, 0.25) * pb
    else
        now = g.TimePosition or 0
    end
    local hbo = 0
    pcall(function() hbo = (f.SettingsHandler:Get("HitboxOffset") or 0) / 1000 end)
    now = now + hbo

    local function stamp(songT)
        if not (sample and type(sample.Clock) == "number") then return clock end
        local d = (songT - hbo - (sample.Position or 0)) / pb
        return sample.Clock + math.clamp(d, -0.249, 0.249)
    end

    local lead = math.min(dt, 0.05) * pb
    local nudge = cfg.offsetMs / 1000 * pb

    for i, h in pairs(held) do
        if (h.song and now + lead >= h.song) or (h.clock and clock >= h.clock) then
            field:HitLane(i, false, h.song and stamp(h.song) or clock)
            held[i] = nil
        end
    end

    for i, lane in pairs(field.Lanes) do
        local notes = lane.Notes
        if type(notes) == "table" then
            local due
            for _, note in pairs(notes) do
                local t = note.Time
                local kind = note.NoteData and note.NoteData.Type

                if type(t) == "number" and not note.Hit and not note.Cleaned and not pressedAt[note]
                    and not (kind and table.find(ignored, kind)) then
                    local p = planFor(note, field, pb)

                    if not p.skip and now + lead >= t + p.ms / 1000 * pb - nudge and now - t < 0.195 * pb then
                        due = due or {}
                        table.insert(due, note)
                    end
                end
            end
            if due then
                table.sort(due, function(a, b) return a.Time < b.Time end)
                for _, note in ipairs(due) do

                    local at = note.Time + planFor(note, field, pb).ms / 1000 * pb - nudge
                    if held[i] then field:HitLane(i, false, stamp(at)) end
                    field:HitLane(i, true, stamp(at))
                    pressedAt[note] = clock
                    presses = presses + 1
                    local len = tonumber(note.Length) or 0
                    if len > 0 then
                        held[i] = {song = note.Time + len}
                    else
                        held[i] = {clock = clock + 0.03}
                    end
                end
            end
        end
    end
end

table.insert(conns, RunService.RenderStepped:Connect(function(dt)
    local s, err = pcall(step, dt)
    if not s then
        status = "error: " .. tostring(err)
        pcall(releaseAll, lastField)
    end
end))

table.insert(conns, ch.Event:Connect(function(kind, data)
    if kind == "cfg" and type(data) == "table" then
        for k, v in pairs(data) do cfg[k] = v end
        planVer = planVer + 1
    elseif kind == "stop" then
        if env.__FF_WORKER then env.__FF_WORKER() end
    end
end))

local function stop()
    alive = false
    pcall(releaseAll, lastField)
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    table.clear(conns)
    env.__FF_WORKER = nil
end
env.__FF_WORKER = stop

task.spawn(function()
    while alive do
        local counts = song.counts or {}
        -- the game's own running score for every player in this song (what its score bar shows)
        local myScore, scoreMap
        pcall(function()
            local g = fw and fw.VSRG.GameHandler.Field and fw.VSRG.GameHandler.Field.Game
            local sc = g and g.Scores and g.Scores.Scores
            if type(sc) == "table" then
                scoreMap = {}
                for name, e in pairs(sc) do
                    if type(e) == "table" then scoreMap[tostring(name)] = math.floor(tonumber(e.Goal or e.Score) or 0) end
                end
                myScore = scoreMap[game:GetService("Players").LocalPlayer.Name]
            end
        end)
        pcall(function()
            ch:Fire("stat", {
                status = status, presses = presses, title = song.title or "-", playing = status == "playing",
                acc = currentAcc(), judged = song.judged or 0, misses = song.misses or 0,
                combo = song.combo or 0, best = song.best or 0,
                sick = counts.Sick or 0, good = counts.Good or 0, ok = counts.Ok or 0, bad = counts.Bad or 0,
                found = fw ~= nil, missLog = table.concat(missLog, "\n"),
                score = myScore, scores = scoreMap,
            })
        end)
        task.wait(0.25)
    end
end)
end)
if not started then ch:Fire("stat", {status = "worker failed: " .. tostring(startErr), presses = 0}) end
]==]

local auto = {
    enabled = false, offsetMs = 0, humanize = false, missChance = 2, goodChance = 10, okChance = 0, badChance = 0, jitter = 15,
    spamWorse = 1.5, aim = false, aimTarget = 96,
}
local live = {status = "starting", presses = 0, title = "-", playing = false, acc = 100, judged = 0, misses = 0,
    combo = 0, best = 0, sick = 0, good = 0, ok = 0, bad = 0, at = 0, missLog = ""}
local songLog = {}
local alive = true
local conns = {}
local channel, channelId, actor
local workerError

local function sendCfg()
    if channel then pcall(function() channel:Fire("cfg", table.clone(auto)) end) end
end

local function logSong(s)
    if not s or (s.judged or 0) < 10 then return end
    table.insert(songLog, 1, string.format("%s  %.2f%%  %d misses  best combo %d", s.title or "?", s.acc or 0, s.misses or 0, s.best or 0))
    if #songLog > 8 then table.remove(songLog) end

    local catnBus = getgenv and getgenv().CatnBus
    if catnBus then pcall(catnBus.emit, "song_finished", {title = "Song finished", text = songLog[1], tags = "musical_note"}) end

end

local function startWorker()
    if type(run_on_actor) ~= "function" or type(create_comm_channel) ~= "function" then
        workerError = "this executor can't run code inside the game's actor"
        return false
    end
    actor = plr:FindFirstChild("PlayerScripts") and plr.PlayerScripts:FindFirstChild("ClientActor")
    if not actor then
        workerError = "waiting for the game to load"
        return false
    end
    if not channel then
        channelId, channel = create_comm_channel()
        table.insert(conns, channel.Event:Connect(function(kind, data)
            if kind ~= "stat" or type(data) ~= "table" then return end
            if live.playing and live.title ~= data.title then logSong(live) end
            if live.playing and not data.playing then logSong(live) end
            for k, v in pairs(data) do live[k] = v end
            -- keep the last score seen while a song was playing: the game clears it once the song ends
            if data.playing and data.score and data.score > 0 then
                live.lastScore, live.lastScores, live.lastScoreTitle = data.score, data.scores, data.title
            end
            live.at = os.clock()
        end))
    end
    local s, err = pcall(run_on_actor, actor, WORKER, channelId)
    if not s then
        workerError = "couldn't start inside the game: " .. tostring(err)
        return false
    end
    workerError = nil
    live.at = os.clock()
    task.delay(0.3, sendCfg)
    return true
end

local function stopWorker()
    if channel then pcall(function() channel:Fire("stop") end) end
end

local FF_VERSION = "1.8.8"
local window = BPUI:CreateWindow({Version = FF_VERSION,
    Title = "Funky Friday", Subtitle = "Autoplay",
    Icon = "music", Theme = "Void", Accent = Color3.fromRGB(143, 112, 236),
    ToggleKey = Enum.KeyCode.RightShift, ShowSettings = true, ConfigFolder = "FFAutoplay",
    Watermark = false, CloseBehavior = "Hide",
    OnDestroy = function()
        alive = false
        auto.enabled = false
        stopWorker()
        for _, c in ipairs(conns) do c:Disconnect() end
    end,
})

local state = {Auto = auto, Live = live, Log = songLog}
state.Destroy = function() pcall(function() window:Destroy() end) end
state.Restart = startWorker
state.Problem = function() return workerError end
state.Window = window
genv.__FF_AUTOPLAY = state

local function set(key, value)
    auto[key] = value
    sendCfg()
end
state.Set = set

local tab = window:CreateTab({Name = "Autoplay", Icon = "music"})
local main = tab:CreateSection("Autoplay")
local toggle = main:AddToggle({Name = "Auto play", Default = false, Flag = "ff_enabled",
    Description = "Hits every note on your side, holds included, and leaves death and poison notes alone. Keeps playing with Roblox in the background.",
    Callback = function(v) set("enabled", v == true and alive) end})
main:AddKeybind({Name = "Key", Default = Enum.KeyCode.F1, Mode = "Press", Flag = "ff_key",
    Callback = function() toggle:Set(not auto.enabled) end})
local statusLbl = main:AddLabel({Text = "starting", Style = "Sub"})
local songLbl = main:AddLabel({Text = "song: -", Style = "Sub"})
local statsLbl = main:AddLabel({Text = "-", Style = "Sub"})

local ctl = {}

local timing = tab:CreateSection("Timing")
ctl.offset = timing:AddSlider({Name = "Offset", Min = -40, Max = 40, Default = 0, Increment = 1, Suffix = " ms", Flag = "ff_offset",
    Description = "Positive presses earlier. Leave it at 0: it already uses the game's own clock and your hitbox offset setting.",
    Callback = function(v) set("offsetMs", tonumber(v) or 0) end})

local aimSec = tab:CreateSection("Accuracy target")
ctl.aim = aimSec:AddToggle({Name = "Aim for an accuracy", Default = false, Flag = "ff_aim",
    Description = "Plays perfect while under the target and takes Goods, and the odd miss, while over it. Replaces Humanize while on.",
    Callback = function(v) set("aim", v == true) end})
ctl.aimTarget = aimSec:AddSlider({Name = "Target", DependsOn = ctl.aim, Min = 80, Max = 100, Default = 96, Increment = 0.01, Suffix = " %", Flag = "ff_aim_target",
    Description = "Click the number to type one, like 99.50.",
    Callback = function(v) set("aimTarget", tonumber(v) or 96) end})

local human = tab:CreateSection("Humanize")
ctl.humanize = human:AddToggle({Name = "Humanize", Default = false, Flag = "ff_humanize",
    Description = "Mixes in misses, Goods, Oks, Bads and small timing errors so it doesn't play perfectly.",
    Callback = function(v) set("humanize", v == true) end})
ctl.miss = human:AddSlider({Name = "Miss chance", DependsOn = ctl.humanize, Min = 0, Max = 15, Default = 2, Increment = 0.01, Suffix = " %", Flag = "ff_miss",
    Description = "Click the number to type one, like 2.73.",
    Callback = function(v) set("missChance", tonumber(v) or 0) end})
ctl.good = human:AddSlider({Name = "Good chance", DependsOn = ctl.humanize, Min = 0, Max = 40, Default = 10, Increment = 0.01, Suffix = " %", Flag = "ff_good",
    Callback = function(v) set("goodChance", tonumber(v) or 0) end})
ctl.ok = human:AddSlider({Name = "Ok chance", DependsOn = ctl.humanize, Min = 0, Max = 20, Default = 0, Increment = 0.01, Suffix = " %", Flag = "ff_ok",
    Callback = function(v) set("okChance", tonumber(v) or 0) end})
ctl.bad = human:AddSlider({Name = "Bad chance", DependsOn = ctl.humanize, Min = 0, Max = 20, Default = 0, Increment = 0.01, Suffix = " %", Flag = "ff_bad",
    Callback = function(v) set("badChance", tonumber(v) or 0) end})
ctl.jitter = human:AddSlider({Name = "Timing jitter", DependsOn = ctl.humanize, Min = 0, Max = 45, Default = 15, Increment = 1, Suffix = " ms", Flag = "ff_jitter",
    Description = "Random error on normal hits. Anything under 50 ms still counts as Sick.",
    Callback = function(v) set("jitter", tonumber(v) or 0) end})
ctl.spam = human:AddSlider({Name = "Worse on spam", DependsOn = ctl.humanize, Min = 0, Max = 3, Default = 1.5, Increment = 0.1, Suffix = "x", Flag = "ff_spam",
    Description = "On fast note streams it misses and slips more, like a real player. 0 plays spam like the rest of the song.",
    Callback = function(v) set("spamWorse", tonumber(v) or 0) end})

local PRESET_FILE = "FFAutoplay/presets.json"
local BUILT_IN = {
    {name = "Perfect", s = {offset = 0, humanize = false, aim = false}},
    {name = "Looks human", s = {offset = 0, humanize = true, miss = 2, good = 10, ok = 0, bad = 0, jitter = 15, spam = 1.5, aim = false}},
    {name = "Sloppy", s = {offset = 0, humanize = true, miss = 6, good = 25, ok = 4, bad = 1.5, jitter = 35, spam = 2.5, aim = false}},
    {name = "Aim for 95%", s = {offset = 0, aim = true, aimTarget = 95}},
}
local userPresets = {}
pcall(function()
    if type(isfile) == "function" and isfile(PRESET_FILE) then
        local data = HttpService:JSONDecode(readfile(PRESET_FILE))
        if type(data) == "table" then userPresets = data end
    end
end)

local function savePresets()
    pcall(function()
        if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder("FFAutoplay") then makefolder("FFAutoplay") end
        writefile(PRESET_FILE, HttpService:JSONEncode(userPresets))
    end)
end

local function presetNames()
    local names = {}
    for _, p in ipairs(BUILT_IN) do table.insert(names, p.name) end
    local mine = {}
    for name in pairs(userPresets) do table.insert(mine, name) end
    table.sort(mine, function(a, b) return a:lower() < b:lower() end)
    for _, n in ipairs(mine) do table.insert(names, n) end
    return names
end

local function findPreset(name)
    for _, p in ipairs(BUILT_IN) do if p.name == name then return p.s, true end end
    return userPresets[name], false
end

local function currentSettings()
    return {offset = auto.offsetMs, humanize = auto.humanize, miss = auto.missChance, good = auto.goodChance, ok = auto.okChance, bad = auto.badChance,
        jitter = auto.jitter, spam = auto.spamWorse, aim = auto.aim, aimTarget = auto.aimTarget}
end

local function applySettings(s)
    if type(s) ~= "table" then return false end
    local function num(v, lo, hi) v = tonumber(v) return v and math.clamp(v, lo, hi) or nil end
    if num(s.offset, -40, 40) then ctl.offset:Set(num(s.offset, -40, 40)) end
    if num(s.miss, 0, 15) then ctl.miss:Set(num(s.miss, 0, 15)) end
    if num(s.good, 0, 40) then ctl.good:Set(num(s.good, 0, 40)) end
    if num(s.ok, 0, 20) then ctl.ok:Set(num(s.ok, 0, 20)) end
    if num(s.bad, 0, 20) then ctl.bad:Set(num(s.bad, 0, 20)) end
    if num(s.jitter, 0, 45) then ctl.jitter:Set(num(s.jitter, 0, 45)) end
    if num(s.spam, 0, 3) then ctl.spam:Set(num(s.spam, 0, 3)) end
    if num(s.aimTarget, 80, 100) then ctl.aimTarget:Set(num(s.aimTarget, 80, 100)) end
    if type(s.humanize) == "boolean" then ctl.humanize:Set(s.humanize) end
    if type(s.aim) == "boolean" then ctl.aim:Set(s.aim) end
    return true
end

local presetSec = tab:CreateSection("Presets")
local chosenPreset = "Perfect"
local presetDrop = presetSec:AddDropdown({Name = "Preset", Options = presetNames(), Default = "Perfect",
    Callback = function(v) chosenPreset = v end})
presetSec:AddButton({Name = "Use this preset", ButtonText = "Apply", Callback = function()
    if applySettings((findPreset(chosenPreset))) then
        window:Notify({Title = "Preset", Content = chosenPreset .. " applied.", Type = "Success", Duration = 3})
    end
end})
local presetName = ""
presetSec:AddInput({Name = "Save current as", Placeholder = "name", Flag = "ff_preset_name",
    Callback = function(v) presetName = tostring(v or "") end})
presetSec:AddButton({Name = "Save preset", ButtonText = "Save", Callback = function()
    local name = presetName:gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then window:Notify({Title = "Preset", Content = "Type a name first.", Type = "Warning", Duration = 3}) return end
    local _, builtIn = findPreset(name)
    if builtIn then window:Notify({Title = "Preset", Content = "That name is taken by a built-in preset.", Type = "Warning", Duration = 3}) return end
    userPresets[name] = currentSettings()
    savePresets()
    pcall(function() presetDrop:Refresh(presetNames()) end)
    window:Notify({Title = "Preset", Content = "Saved " .. name .. ".", Type = "Success", Duration = 3})
end})
presetSec:AddButton({Name = "Delete preset", ButtonText = "Delete", Callback = function()
    local _, builtIn = findPreset(chosenPreset)
    if builtIn or not userPresets[chosenPreset] then
        window:Notify({Title = "Preset", Content = "Built-in presets can't be deleted.", Type = "Warning", Duration = 3})
        return
    end
    userPresets[chosenPreset] = nil
    savePresets()
    pcall(function() presetDrop:Refresh(presetNames()) end)
    window:Notify({Title = "Preset", Content = "Deleted " .. chosenPreset .. ".", Type = "Info", Duration = 3})
end})

local logSec = tab:CreateSection("Song log")
local logText = logSec:AddParagraph({Title = "Last songs", Content = "none yet"})
local missText = logSec:AddParagraph({Title = "Misses this song", Content = "none"})

task.spawn(function()
    startWorker()
    while alive do
        if not workerError and os.clock() - live.at > 3 then startWorker() end
        if workerError then
            task.wait(2)
            if alive then startWorker() end
        end
        pcall(function()
            local txt
            if workerError then
                txt = workerError
            elseif os.clock() - live.at > 1.5 then
                txt = "reconnecting"
            else
                txt = live.status
            end
            statusLbl:Set(txt .. "  |  presses: " .. tostring(live.presses))
            if live.playing then
                songLbl:Set("song: " .. tostring(live.title))
                statsLbl:Set(string.format("%.2f%%  |  misses %d  |  combo %d  |  sick %d  good %d  ok %d  bad %d",
                    live.acc, live.misses, live.combo, live.sick, live.good, live.ok, live.bad))
            else
                songLbl:Set("song: -")
                statsLbl:Set("-")
            end
            logText:SetContent(#songLog > 0 and table.concat(songLog, "\n") or "none yet")
            missText:SetContent((live.missLog and live.missLog ~= "") and live.missLog or "none")
        end)
        task.wait(0.5)
    end
end)


-- ===================== Auto farm with other account =====================
-- Two accounts share a stage: the winner plays perfect, the loser aims a hair lower, so the winner takes every duet.
-- Both accounts run this script and type the same two usernames. Lengths of songs live in FFAutoFarm/song_lengths.json.
local PAIR_FOLDER = "FFAutoFarm"
local SONG_CACHE = PAIR_FOLDER .. "/song_lengths.json"
local MIN_SONG_LEN = 31 -- the game ignores songs under its own MinSongLength (30s, +1 for rounding)
-- measured lengths (seconds) used until you scan; "pack|song"
local SEED_SONGS = {
    {"DaveBambiVolumes", "DaveBambiVolumes_Master", 36},
    {"HolidayMod", "HolidayMod_Jawa", 36},
    {"VSDaveBambi", "VSDaveBambi_Master", 36},
    {"Hazyriver", "Hazyriver_Fading", 43},
    {"VSDaniel", "VSDaniel_Spamton", 43},
    {"VSGarcello", "VSGarcello_Fading", 43},
    {"VSJared", "VSJared_Mullin", 47},
    {"FireInTheHole", "FireInTheHole_FiringHoles", 48},
    {"VSDaniel", "VSDaniel_Sans", 49},
    {"HoloFunk", "HoloFunk_Leaveitalltome", 54},
    {"KreadianFunk", "KreadianFunk_Mystery", 55},
    {"VSUniqueGeese", "VSUniqueGeese_Geesetune", 56},
    {"HoloFunk", "HoloFunk_TutorialMio", 58},
    {"HoloFunk", "HoloFunk_TutorialNene", 58},
}

local pairCfg = {on = false, winner = "", loser = "", loserAcc = 99, loserLow = false, song = "wins", -- song: "wins" or "score"
    hopOn = false, hopMin = 30} -- timed hop: leave the server after hopMin minutes
local serverJoinedAt = os.clock() -- the script reloads in every new server, so this is when we got here
-- "Best for score": a long, dense chart. Pack / song / chart names as the selector lists them.
local SCORE_SONG = {pack = "VSBob", song = "VSBob_Run", chart = "Insane"}
state.PairCfg = pairCfg -- lets other scripts (or a test) read/set the duo-farm options
-- the loser either aims just under the winner, or (lowest score) presses nothing at all
local function loserPlay()
    if pairCfg.loserLow then
        if auto.enabled then set("enabled", false) end
    else
        if not auto.enabled then set("enabled", true) end
        if not auto.aim then set("aim", true) end
        if auto.aimTarget ~= pairCfg.loserAcc then set("aimTarget", pairCfg.loserAcc) end
    end
end

local function pjson(path)
    if type(isfile) == "function" and isfile(path) then
        local ok, data = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
        if ok and type(data) == "table" then return data end
    end
end
local function pwrite(path, tbl)
    if type(writefile) == "function" then pcall(function() writefile(path, HttpService:JSONEncode(tbl)) end) end
end
if type(makefolder) == "function" and type(isfolder) == "function" and not isfolder(PAIR_FOLDER) then
    pcall(makefolder, PAIR_FOLDER)
end

-- ---------- song selector helpers ----------
local function selFrame()
    local pg = plr:FindFirstChild("PlayerGui")
    local gg = pg and pg:FindFirstChild("GameGui")
    local w = gg and gg:FindFirstChild("Windows")
    local s = w and w:FindFirstChild("SongSelectorNew")
    return s, s and s:FindFirstChild("Frame")
end

local function clickBtn(b)
    local ok, conns2 = pcall(getconnections, b.MouseButton1Click)
    if ok then
        for _, c in ipairs(conns2) do pcall(function() c:Fire() end) end
    end
end

local function parseLen(t)
    local m, s = tostring(t):match("(%d+):(%d%d)")
    if m then return tonumber(m) * 60 + tonumber(s) end
    return nil
end

-- select a song button + a chart (a given one, else the first of Normal/Easy/Hard); returns the length in seconds (or nil)
local function measure(frame, songBtn, chart)
    local det = frame.Center.Details
    local dur = det.ChartDetails.Metrics.Duration
    clickBtn(songBtn)
    local t0 = os.clock()
    while os.clock() - t0 < 0.4 and parseLen(dur.Text) do task.wait(0.05) end -- let it reset to "?"
    local inner = det.ChartArea.Charts.Inner
    for _, n in ipairs(chart and {chart} or {"Normal", "Easy", "Hard"}) do
        local cb = inner:FindFirstChild(n)
        if cb and cb.Visible then clickBtn(cb) break end
        if chart then return nil end -- asked for a chart this song doesn't show
    end
    t0 = os.clock()
    while os.clock() - t0 < 4 do
        local l = parseLen(dur.Text)
        if l then return l end
        task.wait(0.05)
    end
    return nil
end

local function songButtons(list)
    local t = {}
    for _, b in ipairs(list:GetChildren()) do
        if b:IsA("TextButton") then t[#t + 1] = b end
    end
    return t
end

-- ---------- scanner: reads every song's length straight from the game's song data ----------
-- The selector shows a song's length once its audio has loaded, so we load every track in parallel
-- (no clicking through the UI) and compute it the way the selector does. Takes about two minutes.
local scanning = false
local SCAN_WORKER = [==[
local id = ...
local ch = get_comm_channel(id)
local ok, err = pcall(function()
    local fw = filtergc("table", {Keys = {"VSRG", "Configs"}}, true)
    local out = {}
    for key, s in pairs(fw.Songs.SongData) do
        if type(s) == "table" and s.Active ~= false and type(s.AudioByChart) == "table" then
            local pick
            for _, n in ipairs({"Normal", "Easy", "Hard"}) do if s.AudioByChart[n] then pick = n break end end
            if not pick then pick = next(s.AudioByChart) end
            local entries = {}
            for _, e in ipairs(s.AudioByChart[pick] or {}) do
                local ids = {}
                for _, l in ipairs(e.Layers or {}) do
                    if l.AssetId then ids[#ids + 1] = tostring(l.AssetId) end
                end
                entries[#entries + 1] = ids
            end
            out[#out + 1] = {key = s.FullName or key, pack = s.Category, speed = s.PlaybackSpeed or 1,
                end_ = tonumber(s.EndTime), entries = entries}
        end
    end
    ch:Fire("songs", out)
end)
if not ok then ch:Fire("songs", {error = tostring(err)}) end
]==]

-- returns the number of songs written, or nil + a reason
local function fastScan(report)
    if scanning then return nil, "already scanning" end
    if type(run_on_actor) ~= "function" or type(create_comm_channel) ~= "function" then
        return nil, "this executor can't run code inside the game's actor"
    end
    local actor = plr:FindFirstChild("PlayerScripts") and plr.PlayerScripts:FindFirstChild("ClientActor")
    if not actor then return nil, "the game hasn't loaded yet" end
    scanning = true
    local ok, n, why = pcall(function()
        local songs
        local cid, chan = create_comm_channel()
        local conn = chan.Event:Connect(function(kind, data) if kind == "songs" then songs = data end end)
        run_on_actor(actor, SCAN_WORKER, cid)
        local w = os.clock()
        while not songs and os.clock() - w < 15 do task.wait(0.1) end
        conn:Disconnect()
        if not songs or songs.error then return nil, "couldn't read the song data: " .. tostring(songs and songs.error) end

        local ids, seen = {}, {}
        for _, s in ipairs(songs) do
            for _, e in ipairs(s.entries) do
                for _, a in ipairs(e) do
                    if not seen[a] then seen[a] = true ids[#ids + 1] = a end
                end
            end
        end
        local lengths, pending, idx, done = {}, 0, 1, 0
        local CONC, TIMEOUT = 60, 8
        local folder = Instance.new("Folder")
        folder.Name = "FFScan"
        folder.Parent = game:GetService("SoundService")
        local function launch(a)
            pending += 1
            task.spawn(function()
                local snd = Instance.new("Sound")
                snd.Volume = 0
                snd.SoundId = "rbxassetid://" .. a
                snd.Parent = folder
                local t = os.clock()
                while not snd.IsLoaded and os.clock() - t < TIMEOUT do task.wait(0.05) end
                if snd.IsLoaded and snd.TimeLength > 0 then lengths[a] = snd.TimeLength end
                snd:Destroy()
                pending -= 1
                done += 1
            end)
        end
        local lastReport = 0
        while (idx <= #ids or pending > 0) and scanning do
            while pending < CONC and idx <= #ids do launch(ids[idx]) idx += 1 end
            if report and os.clock() - lastReport > 1 then lastReport = os.clock() report(done, #ids) end
            task.wait(0.05)
        end
        folder:Destroy()
        if not scanning then return nil, "stopped" end

        -- the selector's formula: per entry the longest layer, summed, divided by the song's playback speed
        local res = pjson(SONG_CACHE) or {}
        local count = 0
        for _, s in ipairs(songs) do
            local total, complete = 0, #s.entries > 0
            for _, e in ipairs(s.entries) do
                local m
                for _, a in ipairs(e) do if lengths[a] then m = math.max(m or 0, lengths[a]) end end
                if m then total += m else complete = false end
            end
            if s.end_ and s.end_ > 0 then total = math.min(total, s.end_) end
            if complete and total > 0 then
                res[tostring(s.pack or "?") .. "|" .. s.key] = math.floor(total / s.speed + 0.5)
                count += 1
            end
        end
        pwrite(SONG_CACHE, res)
        return count
    end)
    scanning = false
    if not ok then return nil, tostring(n) end
    return n, why
end

-- all known songs at least MIN_SONG_LEN long, shortest first
local function songCandidates()
    local list, seen = {}, {}
    local cache = pjson(SONG_CACHE) or {}
    for k, v in pairs(cache) do
        if type(v) == "number" and v >= MIN_SONG_LEN then list[#list + 1] = {k, v} seen[k] = true end
    end
    for _, e in ipairs(SEED_SONGS) do
        local k = e[1] .. "|" .. e[2]
        if not seen[k] and e[3] >= MIN_SONG_LEN then list[#list + 1] = {k, e[3]} end
    end
    table.sort(list, function(a, b) return a[2] < b[2] end)
    return list
end

-- selects the shortest eligible song + a chart; true when the chart's length matches what we expect
local function pickShortest()
    local sel, frame = selFrame()
    if not (sel and sel.Visible and frame) then return false, "selector hidden" end
    local list = songCandidates()
    if #list == 0 then return false, "no song lengths known" end
    for i = 1, math.min(#list, 8) do
        local key, len = list[i][1], list[i][2]
        local pack, song = key:match("^(.-)|(.*)$")
        local packBtn = frame.Center.Categories.Mods.ModPackList:FindFirstChild(pack)
        if packBtn then
            clickBtn(packBtn)
            local songBtn
            local t0 = os.clock()
            while os.clock() - t0 < 4 and not songBtn do
                task.wait(0.1)
                songBtn = frame.Center.Songs.SongListBacking.SongList:FindFirstChild(song)
            end
            if songBtn then
                local l = measure(frame, songBtn)
                if l and math.abs(l - len) <= 2 and l >= MIN_SONG_LEN then return true, key .. " " .. l .. "s" end
            end
        end
    end
    return false, "none of the known songs could be selected"
end

-- ---------- the full song list, for the custom song search ----------
local CUSTOM_FILE = PAIR_FOLDER .. "/custom_song.json" -- shared by both accounts: {pack, song, chart, title, packName}
local INDEX_WORKER = [==[
local id = ...
local ch = get_comm_channel(id)
local ok, err = pcall(function()
    local fw = filtergc("table", {Keys = {"VSRG", "Configs"}}, true)
    local out = {}
    for key, s in pairs(fw.Songs.SongData) do
        if type(s) == "table" and s.Active ~= false then
            local charts = {}
            for c in pairs(s.Charts or {}) do charts[#charts + 1] = tostring(c) end
            out[#out + 1] = {key = s.FullName or key, pack = s.Category, packName = s.Name, title = s.Title,
                author = s.Author, charts = charts}
        end
    end
    ch:Fire("index", out)
end)
if not ok then ch:Fire("index", {error = tostring(err)}) end
]==]

local function chartRank(n) return ({Easy = 1, Normal = 2, Hard = 3, Insane = 4})[n] or 5 end

local songIndex -- every song: {key, pack, packName, title, author, charts, hay}
local function loadSongIndex()
    if songIndex then return songIndex end
    if type(run_on_actor) ~= "function" or type(create_comm_channel) ~= "function" then
        return nil, "this executor can't read the game's song data"
    end
    local actor = plr:FindFirstChild("PlayerScripts") and plr.PlayerScripts:FindFirstChild("ClientActor")
    if not actor then return nil, "the game hasn't loaded yet" end
    local got
    local cid, chan = create_comm_channel()
    local conn = chan.Event:Connect(function(kind, data) if kind == "index" then got = data end end)
    run_on_actor(actor, INDEX_WORKER, cid)
    local w = os.clock()
    while not got and os.clock() - w < 15 do task.wait(0.1) end
    conn:Disconnect()
    if not got or got.error then return nil, "couldn't read the song data: " .. tostring(got and got.error) end
    local list = {}
    for _, s in ipairs(got) do
        local title = tostring(s.title or s.key):gsub("<[^>]->", "")
        local packName = tostring(s.packName or s.pack or ""):gsub("<[^>]->", "")
        local charts = s.charts
        table.sort(charts, function(a, b) return chartRank(a) < chartRank(b) end)
        list[#list + 1] = {key = s.key, pack = s.pack, packName = packName, title = title,
            author = tostring(s.author or ""), charts = charts,
            hay = (title .. " " .. packName .. " " .. tostring(s.key) .. " " .. tostring(s.author or "")):lower()}
    end
    table.sort(list, function(a, b) return a.title:lower() < b.title:lower() end)
    songIndex = list
    return list
end

-- every word of the query must appear in the title, pack, id or artist; titles that start with it come first
local function searchSongs(query, limit)
    local list = songIndex
    if not list then return {} end
    local q = tostring(query or ""):lower()
    local words = {}
    for w in q:gmatch("%S+") do words[#words + 1] = w end
    local out = {}
    for _, e in ipairs(list) do
        local ok = true
        for _, w in ipairs(words) do
            if not e.hay:find(w, 1, true) then ok = false break end
        end
        if ok then out[#out + 1] = e end
    end
    table.sort(out, function(a, b)
        local sa, sb = a.title:lower():sub(1, #q) == q, b.title:lower():sub(1, #q) == q
        if sa ~= sb then return sa end
        return a.title:lower() < b.title:lower()
    end)
    local trimmed = {}
    for i = 1, math.min(#out, limit or 40) do trimmed[i] = out[i] end
    return trimmed
end

local function customChoice()
    local c = pjson(CUSTOM_FILE)
    if c and c.pack and c.song then return c end
end

local function saveCustom(e, chart)
    pwrite(CUSTOM_FILE, {pack = e.pack, song = e.key, chart = chart, title = e.title, packName = e.packName})
end

-- selects one song + chart in the selector; true when that chart's length loaded
local function pickSpecific(pack, song, chart)
    local sel, frame = selFrame()
    if not (sel and sel.Visible and frame) then return false, "selector hidden" end
    local packBtn = frame.Center.Categories.Mods.ModPackList:FindFirstChild(pack)
    if not packBtn then return false, "pack missing: " .. tostring(pack) end
    clickBtn(packBtn)
    local songBtn
    local t0 = os.clock()
    while os.clock() - t0 < 4 and not songBtn do
        task.wait(0.1)
        songBtn = frame.Center.Songs.SongListBacking.SongList:FindFirstChild(song)
    end
    if not songBtn then return false, "song missing: " .. tostring(song) end
    local l = measure(frame, songBtn, chart)
    if not l then return false, "couldn't select the " .. tostring(chart or "default") .. " chart" end
    return true, tostring(song) .. " " .. tostring(chart or "") .. " " .. l .. "s"
end

-- the chart our vote has to be on, when the mode asks for a specific one
local function wantedChart()
    if pairCfg.song == "score" then return SCORE_SONG.chart end
    if pairCfg.song == "custom" then
        local c = customChoice()
        return c and c.chart
    end
end

local function pickChosen()
    if pairCfg.song == "score" then return pickSpecific(SCORE_SONG.pack, SCORE_SONG.song, SCORE_SONG.chart) end
    if pairCfg.song == "custom" then
        local c = customChoice()
        if c then return pickSpecific(c.pack, c.song, c.chart) end
        -- nothing chosen yet: keep farming with the shortest song rather than sitting idle
        local ok, info = pickShortest()
        return ok, "no custom song chosen yet, used the shortest: " .. tostring(info)
    end
    return pickShortest()
end

-- one of the values in our own selector row ("Chart", "Song", ...), e.g. the difficulty we voted for
local function myRowValue(sel, name)
    local sf = sel:FindFirstChild("Players") and sel.Players:FindFirstChild("ScrollingFrame")
    local row = sf and sf:FindFirstChild(tostring(plr.UserId))
    local v = row and row:FindFirstChild("Rows") and row.Rows:FindFirstChild(name)
    v = v and v:FindFirstChild("Value")
    return v and v.Text or nil
end

-- Is our vote in? true = our row in the selector still says "Choosing..." (not readied), false = readied,
-- nil = can't tell (row missing). Pressing play again would undo our vote, so only press when this is true.
local function stillChoosing(sel)
    local sf = sel:FindFirstChild("Players") and sel.Players:FindFirstChild("ScrollingFrame")
    local row = sf and sf:FindFirstChild(tostring(plr.UserId))
    if not row then return nil end
    for _, d in ipairs(row:GetDescendants()) do
        if d:IsA("TextLabel") and d.Text == "Choosing..." then return true end
    end
    return false
end

-- ---------- the farm itself ----------
local function runPairFarm(winnerName, loserName, alive, setStatus, onStuck)
    local TeleportService = game:GetService("TeleportService")
    local VirtualInputManager = game:GetService("VirtualInputManager")
    local keyCode = Enum.KeyCode.E
    local PLAYER_1, PLAYER_2 = winnerName, loserName
    local partnerName = (plr.Name == PLAYER_1) and PLAYER_2 or PLAYER_1
    local isLeader = (plr.Name == PLAYER_1)
    local isHopping = false
    local myConns = {}
    local hopStartedAt -- when the current hop began; the watchdog below gives up on a hop that goes nowhere
    local HOP_MAX_SECONDS = 150

    -- Protection: a loop that hits an error (a map object missing mid-teleport, a bad web reply...) is restarted
    -- after a short pause instead of dying silently and leaving the farm half-dead.
    local function supervise(name, body)
        task.spawn(function()
            local fails = 0
            while alive() do
                local ok, err = pcall(body)
                if ok then return end
                fails += 1
                warn("[DUO FARM] " .. name .. " hit an error and is restarting: " .. tostring(err))
                task.wait(math.min(2 * fails, 10))
            end
        end)
    end

    -- Roblox kicks an account after 20 idle minutes (error 278); songs are played without real input
    local VirtualUser = game:GetService("VirtualUser")
    table.insert(myConns, plr.Idled:Connect(function()
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end))

    local VISITED_FILE = PAIR_FOLDER .. "/visited_servers.json"
    local HOP_FILE = PAIR_FOLDER .. "/hop_target.json"
    local CLAIM_FILE = PAIR_FOLDER .. "/stage_claim.json"
    local VISITED_TTL, MAX_VISITED, HOP_ENTRY_MAX_AGE = 600, 50, 120
    local GRACE_LEADER, GRACE_FOLLOWER = 2, 5
    local STAGE_CHECK_START, STAGE_CHECK_INTERVAL, STAGE_MISSES_TO_HOP = 8, 1, 3
    -- after a hop the other account can take a while to load in: hold the pad instead of hopping away from it
    local CLAIM_MAX_AGE, TP_START_DELAY, ALT_WAIT, VERIFY_TIMEOUT = 60, 3, 60, 75
    local PARTNER_GONE_HOP, SPLIT_HOP, SETTLE = 45, 10, 3 -- seconds: partner missing / on another stage / together before voting
    local READY_RETRY = 5 -- seconds to wait for the ready-up to register before pressing again
    local LEADER_SIDE, FOLLOWER_SIDE = "Left", "Right" -- swap if the winner sits on the wrong side

    -- a freshly joined server can be slow or odd: wait with time limits, never forever
    if not plr.Character then
        local got = false
        local conn = plr.CharacterAdded:Connect(function() got = true end)
        local t0 = os.clock()
        while not got and not plr.Character and os.clock() - t0 < 30 do task.wait(0.25) end
        conn:Disconnect()
    end
    if plr.Character then plr.Character:WaitForChild("HumanoidRootPart", 15) end
    plr:WaitForChild("PlayerGui", 15)
    local mapFolder = workspace:WaitForChild("Map", 30)
    local stages = mapFolder and mapFolder:WaitForChild("Stages", 30)
    if not stages then
        -- A hop sometimes lands in a server that never loads the world (just the red skybox + the player list).
        -- Restarting here is pointless - the map will never appear - so rejoin a fresh server to escape it, and
        -- keep trying (spaced out, to respect the teleport limit) in case the first rejoin also fails.
        setStatus("the map didn't load, rejoining a fresh server")
        while alive() do
            pcall(function() TeleportService:Teleport(game.PlaceId, plr) end)
            task.wait(15) -- if the teleport took us away this thread dies with the DataModel; otherwise try again
        end
        return function() for _, c in ipairs(myConns) do pcall(function() c:Disconnect() end) end end
    end
    task.wait(2)
    if not alive() then return end

    -- instant proximity prompts
    local function makeInstant(obj)
        if obj:IsA("ProximityPrompt") then pcall(function() obj.HoldDuration = 0 end) end
    end
    for _, obj in ipairs(workspace:GetDescendants()) do makeInstant(obj) end
    table.insert(myConns, workspace.DescendantAdded:Connect(makeInstant))
    task.spawn(function()
        while alive() and task.wait(10) do
            for _, obj in ipairs(workspace:GetDescendants()) do makeInstant(obj) end
        end
    end)

    -- visited servers
    local function countKeys(t) local n = 0 for _ in pairs(t) do n += 1 end return n end
    local function loadVisited()
        local visited, data = {}, pjson(VISITED_FILE)
        if data then
            for id, t in pairs(data) do
                if type(t) == "number" and os.time() - t < VISITED_TTL then visited[id] = t end
            end
        end
        return visited
    end
    local function trimVisited(visited)
        if countKeys(visited) > MAX_VISITED then visited = {} end
        visited[game.JobId] = os.time()
        return visited
    end
    local visitedServers = trimVisited(loadVisited())
    pwrite(VISITED_FILE, visitedServers)

    local function safeHttpGet(url)
        local req = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
        if req then
            local ok, res = pcall(function() return req({Url = url, Method = "GET", Headers = {["User-Agent"] = "Roblox/WinInet"}}) end)
            if ok and res and res.StatusCode == 200 and res.Body then return res.Body end
        end
        local ok, body = pcall(function() return game:HttpGet(url) end)
        if ok and body and body ~= "" then return body end
        return nil
    end

    local teleportFailed = false
    table.insert(myConns, TeleportService.TeleportInitFailed:Connect(function(_, result, message)
        warn("[DUO FARM] Teleport failed: " .. tostring(result) .. " - " .. tostring(message))
        teleportFailed = true
    end))
    -- returns normally only when the teleport did NOT take us away (it failed, or nothing happened in time)
    local function teleportTo(target, waitTime)
        if type(target) ~= "string" or target == "" or target == game.JobId then return end -- never "hop" to where we are
        teleportFailed = false
        local ok, err = pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, target, plr) end)
        if not ok then
            warn("[DUO FARM] teleport call errored: " .. tostring(err))
            return
        end
        local waited = 0
        while waited < waitTime and not teleportFailed do
            task.wait(0.5)
            waited += 0.5
        end
    end

    -- stage helpers
    local function isStageFree(stage)
        if stage.Name:lower() == "boss" then return false end
        local ws = stage:FindFirstChild("Workspaces")
        if not ws then return false end
        for _, child in ipairs(ws:GetChildren()) do
            if child.Name ~= "Shared" then return false end
        end
        return true
    end
    local function hasAvailableStage()
        for _, stage in ipairs(stages:GetChildren()) do
            if isStageFree(stage) then return true, stage end
        end
        return false, nil
    end
    local function stageKey(stage)
        local teams = stage:FindFirstChild("Teams")
        local ref = teams and teams:FindFirstChild("Left")
        if not ref then return nil end
        local p = ref:GetPivot().Position
        return string.format("%.1f,%.1f,%.1f", p.X, p.Y, p.Z)
    end
    local function stageOfPlayer(name)
        for _, stage in ipairs(stages:GetChildren()) do
            local ws = stage:FindFirstChild("Workspaces")
            if ws and ws:FindFirstChild(name, true) then return stage end
        end
        return nil
    end
    local function bothOnSameStage()
        for _, stage in ipairs(stages:GetChildren()) do
            local ws = stage:FindFirstChild("Workspaces")
            if ws and ws:FindFirstChild(PLAYER_1, true) and ws:FindFirstChild(PLAYER_2, true) then return stage end
        end
        return nil
    end
    local function pickFreeStage()
        local list = {}
        for _, stage in ipairs(stages:GetChildren()) do
            if isStageFree(stage) then
                local teams = stage:FindFirstChild("Teams")
                if teams and teams:FindFirstChild("Left") and teams:FindFirstChild("Right") then table.insert(list, stage) end
            end
        end
        table.sort(list, function(a, b)
            local pa, pb = a.Teams.Left:GetPivot().Position, b.Teams.Left:GetPivot().Position
            if pa.X ~= pb.X then return pa.X < pb.X end
            if pa.Z ~= pb.Z then return pa.Z < pb.Z end
            return pa.Y < pb.Y
        end)
        return list[1]
    end
    local function isStageOpenForAlt(stage)
        if stage.Name:lower() == "boss" then return false end
        local ws = stage:FindFirstChild("Workspaces")
        if not ws then return false end
        for _, child in ipairs(ws:GetChildren()) do
            if child.Name ~= "Shared" and not child:FindFirstChild(partnerName, true) then return false end
        end
        return true
    end
    local function findStageForAlt()
        local leaderStage = stageOfPlayer(partnerName)
        if leaderStage then
            if isStageOpenForAlt(leaderStage) then return leaderStage end
            return nil
        end
        local claim = pjson(CLAIM_FILE)
        if claim and claim.by == partnerName and claim.job == game.JobId and claim.key
            and type(claim.time) == "number" and os.time() - claim.time < CLAIM_MAX_AGE then
            for _, stage in ipairs(stages:GetChildren()) do
                if stageKey(stage) == claim.key and isStageOpenForAlt(stage) then return stage end
            end
        end
        return nil
    end
    local function teleportToStage(stage, side)
        local teams = stage:FindFirstChild("Teams")
        local spot = teams and teams:FindFirstChild(side)
        local char = plr.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if spot and root then
            return pcall(function() root.CFrame = spot:GetPivot() + Vector3.new(0, 3, 0) end)
        end
        return false
    end

    -- Failsafe: anyone on our stage who isn't one of the two chosen accounts. A stage keeps one marker per seated
    -- player (a Configuration named after them), so a real player we didn't choose shows up here.
    local function strangersOnStage(stage)
        local out = {}
        local ws = stage and stage:FindFirstChild("Workspaces")
        if not ws then return out end
        for _, d in ipairs(ws:GetDescendants()) do
            local n = d.Name:lower()
            if d:IsA("Configuration") and n ~= PLAYER_1:lower() and n ~= PLAYER_2:lower() and Players:FindFirstChild(d.Name) then
                out[#out + 1] = d.Name
            end
        end
        return out
    end
    local function ourStage() return stageOfPlayer(plr.Name) or stageOfPlayer(partnerName) end
    local intruder -- name of a stranger currently on our stage, or nil: blocks ready-up while set

    -- hop coordination
    local followBusy, publishedHere, usedNonces = false, false, {}
    supervise("hop follower", function()
        local currentJobId = game.JobId
        while alive() do
            task.wait(0.3)
            local entry = pjson(HOP_FILE)
            if entry and entry.by == partnerName and entry.from == currentJobId and entry.id and entry.nonce
                and not usedNonces[entry.nonce] and type(entry.time) == "number"
                and os.time() - entry.time < HOP_ENTRY_MAX_AGE then
                if not (isLeader and publishedHere) then
                    usedNonces[entry.nonce] = true
                    isHopping = true
                    hopStartedAt = hopStartedAt or os.clock()
                    followBusy = true
                    setStatus("following your other account to a new server")
                    pcall(teleportTo, entry.id, 15)
                    followBusy = false -- always released, even if the teleport errored or failed
                end
            end
        end
    end)

    local function findServer()
        local placeId, currentJobId = game.PlaceId, game.JobId
        local fresh = loadVisited()
        for id, t in pairs(visitedServers) do
            if os.time() - t < VISITED_TTL then fresh[id] = t end
        end
        visitedServers = trimVisited(fresh)
        pwrite(VISITED_FILE, visitedServers)
        local endpoints = {
            "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&excludeFullGames=true&limit=100",
            "https://games.roproxy.com/v1/games/%d/servers/Public?sortOrder=Asc&excludeFullGames=true&limit=100",
        }
        local candidates = {}
        for _, template in ipairs(endpoints) do
            local baseUrl = string.format(template, placeId)
            local cursor
            for _ = 1, 5 do
                local url = baseUrl
                if cursor then url = url .. "&cursor=" .. HttpService:UrlEncode(cursor) end
                local body = safeHttpGet(url)
                if not body then break end
                local ok, data = pcall(function() return HttpService:JSONDecode(body) end)
                if not ok or type(data) ~= "table" or type(data.data) ~= "table" then break end
                for _, server in ipairs(data.data) do
                    -- two free slots so both accounts fit
                    if server.id and server.id ~= currentJobId and not visitedServers[server.id]
                        and type(server.playing) == "number" and type(server.maxPlayers) == "number"
                        and server.playing <= server.maxPlayers - 2 then
                        table.insert(candidates, server.id)
                    end
                end
                cursor = data.nextPageCursor
                if not cursor or #candidates >= 20 then break end
                task.wait(0.5)
            end
            if #candidates > 0 then break end
            task.wait(1)
        end
        if #candidates > 0 then return candidates[math.random(1, #candidates)] end
        return nil
    end

    -- Hop protections: every step is pcall'd, teleports are at least 8 seconds apart (Roblox rate-limits them),
    -- failures back off (4s, 8s ... up to 30s) instead of hammering the web API, and the watchdog below abandons
    -- a hop that goes nowhere so the farm can start over instead of sitting stuck.
    local function searchLoop()
        local currentJobId = game.JobId
        local fails, lastTeleport = 0, -math.huge
        while alive() do
            while followBusy and alive() do task.wait(0.3) end
            local okFind, target = pcall(findServer)
            if not okFind then
                warn("[DUO FARM] looking for a server failed: " .. tostring(target))
                target = nil
            end
            while followBusy and alive() do task.wait(0.3) end
            if not alive() then return end
            if target then
                local gap = os.clock() - lastTeleport
                if gap < 8 then task.wait(8 - gap) end
                pcall(function()
                    visitedServers[target] = os.time()
                    visitedServers[currentJobId] = os.time()
                    pwrite(VISITED_FILE, visitedServers)
                    publishedHere = true
                    pwrite(HOP_FILE, {id = target, from = currentJobId, time = os.time(),
                        nonce = HttpService:GenerateGUID(false), by = plr.Name})
                end)
                setStatus("hopping to a new server")
                lastTeleport = os.clock()
                pcall(teleportTo, target, 15)
                -- still here: the teleport didn't take us anywhere
                fails += 1
                setStatus("that hop didn't work (try " .. fails .. "), trying another server")
            else
                fails += 1
                setStatus("no server found yet (try " .. fails .. "), searching again")
            end
            task.wait(math.min(4 * fails, 30))
        end
    end

    local function serverHop()
        if isHopping then return end
        isHopping = true
        hopStartedAt = os.clock()
        setStatus("no good stage here, looking for another server")
        local ok, err = pcall(function()
            local grace = isLeader and GRACE_LEADER or GRACE_FOLLOWER
            local waited = 0
            while waited < grace and not followBusy do
                task.wait(0.25)
                waited += 0.25
            end
            searchLoop()
        end)
        if not ok and alive() then
            warn("[DUO FARM] the hop errored: " .. tostring(err))
            if onStuck then onStuck("hop errored") end
        end
    end

    -- Watchdog: a hop that hasn't moved us in HOP_MAX_SECONDS is abandoned and the farm restarts in this server
    -- heartbeat: each account says which server it is in, so its partner can tell "hopped elsewhere" from "offline"
    local function beatFile(name) return PAIR_FOLDER .. "/alive_" .. name .. ".json" end
    supervise("heartbeat", function()
        while alive() do
            pcall(pwrite, beatFile(plr.Name), {job = game.JobId, time = os.time()})
            task.wait(10)
        end
    end)
    -- the partner's server when its client is alive somewhere else, or nil
    local function partnerWhere()
        local b = pjson(beatFile(partnerName))
        if b and type(b.time) == "number" and os.time() - b.time < 60 and type(b.job) == "string"
            and b.job ~= "" and b.job ~= game.JobId then return b.job end
        return nil
    end

    supervise("hop watchdog", function()
        while alive() do
            task.wait(2)
            if isHopping and hopStartedAt and os.clock() - hopStartedAt > (state.HopMaxSeconds or HOP_MAX_SECONDS) then
                warn("[DUO FARM] the hop took too long, starting over in this server")
                setStatus("the hop didn't work, starting over here")
                if onStuck then onStuck("hop timed out") end
                return
            end
        end
    end)

    -- 1. spam E at the stage prompt while we're in the lobby
    supervise("stage prompt", function()
        while alive() and task.wait(0.1) do
            if isHopping then break end
            local s = selFrame()
            -- never while we're already on a stage: pressing E there gets us off the pad again
            if s and s.Visible == false and workspace:FindFirstChild(plr.Name) and not stageOfPlayer(plr.Name) then
                VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
                task.wait(0.1)
                VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
                task.wait(0.4)
            end
        end
    end)

    -- 2. one stage teleport per server: winner picks, the other follows the winner's real stage
    local stageTpDone = false
    local function verifyTogether()
        task.spawn(function()
            local deadline = os.clock() + VERIFY_TIMEOUT
            while os.clock() < deadline and alive() do
                if isHopping then return end
                if bothOnSameStage() then setStatus("both accounts are on the same stage") return end
                if not stageOfPlayer(partnerName) then setStatus("on the pad, holding it until the other account gets here") end
                task.wait(1)
            end
            if alive() then
                setStatus("accounts ended up on different stages, hopping")
                serverHop()
            end
        end)
    end
    supervise("stage teleport", function()
        task.wait(TP_START_DELAY)
        local startedAt = os.clock()
        while alive() and not stageTpDone and not isHopping do
            task.wait(0.5)
            if stageOfPlayer(plr.Name) then
                stageTpDone = true
                verifyTogether()
                break
            end
            if not workspace:FindFirstChild(plr.Name) then continue end
            local stage
            if isLeader then
                stage = pickFreeStage()
                if stage then
                    pwrite(CLAIM_FILE, {key = stageKey(stage), job = game.JobId, time = os.time(), by = plr.Name})
                end
            else
                stage = findStageForAlt()
                if not stage and os.clock() - startedAt >= ALT_WAIT then
                    serverHop()
                    break
                end
            end
            -- last-moment check: the stage must still be free (or only hold our partner) right before we step on
            if stage and ((isLeader and not isStageFree(stage)) or (not isLeader and not isStageOpenForAlt(stage))) then
                stage = nil
            end
            if stage then
                local side = isLeader and LEADER_SIDE or FOLLOWER_SIDE
                if teleportToStage(stage, side) then
                    stageTpDone = true
                    setStatus("on a stage, waiting for the song vote")
                    verifyTogether()
                end
            end
        end
    end)

    -- 3. no free stage while both of us are in the lobby -> hop
    supervise("free stage check", function()
        task.wait(STAGE_CHECK_START)
        local misses = 0
        while alive() and not isHopping do
            local bothInLobby = workspace:FindFirstChild(plr.Name) and workspace:FindFirstChild(partnerName)
            if bothInLobby then
                if hasAvailableStage() then
                    misses = 0
                else
                    misses += 1
                    if misses >= STAGE_MISSES_TO_HOP then serverHop() break end
                end
            else
                misses = 0
            end
            task.wait(STAGE_CHECK_INTERVAL)
        end
    end)

    -- 4. partner left, or a stranger joined our stage
    supervise("partner check", function()
        local goneSince, splitSince
        while alive() and task.wait(2) do
            if isHopping then break end
            -- partner gone for a while (a hop target can take a bit to load into): go where it is if its
            -- client is alive in another server, otherwise hold this server so the watchdog can bring it back here
            if Players:FindFirstChild(partnerName) then goneSince = nil else goneSince = goneSince or os.clock() end
            if goneSince and os.clock() - goneSince >= PARTNER_GONE_HOP then
                local where = partnerWhere()
                if where then
                    isHopping = true
                    hopStartedAt = hopStartedAt or os.clock()
                    setStatus("going to your other account's server")
                    pcall(teleportTo, where, 15)
                    isHopping = false
                    goneSince = os.clock() -- the teleport didn't take: try again later
                else
                    setStatus("your other account is offline, holding this server for it")
                end
            end
            -- both seated but on different stages -> this server is a bust. One alone on a stage is just waiting.
            local mine, theirs = stageOfPlayer(plr.Name), stageOfPlayer(partnerName)
            if mine and theirs and mine ~= theirs then splitSince = splitSince or os.clock() else splitSince = nil end
            if splitSince and os.clock() - splitSince >= SPLIT_HOP then
                setStatus("accounts are on different stages, hopping")
                serverHop()
                break
            end
        end
    end)

    -- 5. ready up: pick the shortest eligible song and press play ONCE, check that the vote registered,
    -- and only press again if it didn't. Never while the other account isn't on the stage yet.
    supervise("ready up", function()
        local lastPress = -math.huge
        local lastTried = -math.huge
        local togetherSince, fixes = nil, 0
        while alive() and not isHopping do
            task.wait(0.5)
            local sel, frame = selFrame()
            if not (sel and sel.Visible) then
                lastPress, lastTried, fixes = -math.huge, -math.huge, 0 -- song started / selector closed: fresh round next time
            else
                -- "Play Solo" on the button means the game still sees one player
                local bothHere = bothOnSameStage() ~= nil and frame.Bottom.Play.PlaySong.Label.Text ~= "Play Solo"
                if bothHere then togetherSince = togetherSince or os.clock() else togetherSince = nil end
                if intruder then
                    setStatus("not readying up, " .. intruder .. " is on our stage")
                elseif not bothHere then
                    setStatus("on the pad, waiting for the other account to join the stage")
                elseif os.clock() - togetherSince < SETTLE then
                    setStatus("both on the stage, settling before the vote")
                else
                    local choosing = stillChoosing(sel)
                    if choosing == false then
                        local voted, want = myRowValue(sel, "Chart"), wantedChart()
                        if want and voted and voted ~= want and os.clock() - lastPress > 3 and fixes < 2 then -- at most 2 fixes a round, never a ready/unready loop
                            fixes += 1
                            -- we readied up on the wrong difficulty: press play again to un-ready, the retry below re-picks
                            clickBtn(frame.Bottom.Play.PlaySong)
                            lastPress = os.clock()
                            lastTried = -math.huge
                            setStatus("voted " .. tostring(voted) .. " instead of " .. tostring(want) .. ", un-readying to fix it")
                        else
                            setStatus("readied up, waiting for the other account")
                        end
                    elseif os.clock() - lastTried > READY_RETRY and choosing == true then -- only when our row actually shows "Choosing..."; never press blind while the row flickers in/out as both accounts settle on a stage
                        if bothOnSameStage() and stillChoosing(sel) ~= false and not intruder
                            and #strangersOnStage(ourStage()) == 0 then -- checked again right before we vote
                            lastTried = os.clock()
                            local ok, good, info = pcall(pickChosen)
                            if ok and good then
                                local play = frame.Bottom.Play:FindFirstChild("PlaySong")
                                if play then
                                    clickBtn(play)
                                    lastPress = os.clock()
                                    state.PlayPresses = (state.PlayPresses or 0) + 1 -- how often we've pressed ready (for checking)
                                    setStatus("pressed ready with " .. tostring(info) .. ", checking it took")
                                end
                            else
                                setStatus("couldn't pick a song: " .. tostring(good) .. " " .. tostring(info))
                            end
                        end
                    end
                end
            end
        end
    end)

    -- 6. timed hop: leave after N minutes in this server, but between songs so a round isn't thrown away
    supervise("timed hop", function()
        local dueSince
        while alive() and not isHopping do
            task.wait(1)
            local limit = (tonumber(pairCfg.hopMin) or 0) * 60
            if pairCfg.hopOn and limit > 0 and os.clock() - serverJoinedAt >= limit then
                dueSince = dueSince or os.clock()
                local sel = selFrame()
                -- the selector is only open while no song is playing; don't wait more than 3 minutes for it
                if (sel and sel.Visible) or os.clock() - dueSince > 180 then
                    setStatus("timed hop: " .. tostring(pairCfg.hopMin) .. " min in this server, hopping")
                    serverHop()
                    return
                end
            else
                dueSince = nil
            end
        end
    end)

    -- 7. stranger failsafe: if anyone but our two accounts is on our stage, stop voting and leave the server together.
    -- Before a song it leaves right away; during one it lets the song finish (the selector reopens), at most 2 minutes.
    supervise("stranger failsafe", function()
        local firstSeen
        while alive() and not isHopping do
            task.wait(0.5)
            local stage = ourStage()
            local strangers = stage and strangersOnStage(stage) or {}
            if #strangers > 0 then
                firstSeen = firstSeen or os.clock()
                intruder = strangers[1]
                setStatus("stranger on our stage (" .. intruder .. "), leaving this server")
                local sel = selFrame()
                if (sel and sel.Visible) or os.clock() - firstSeen > 120 then
                    serverHop()
                    return
                end
            else
                firstSeen, intruder = nil, nil
            end
        end
    end)

    -- hand back a cleanup so turning the option off disconnects everything
    return function()
        for _, c in ipairs(myConns) do pcall(function() c:Disconnect() end) end
    end
end

-- ---------- the options ----------
local pairTab = window:CreateTab({Name = "Art's duo farm", Icon = "users"})
local pairSec = pairTab:CreateSection("Auto farm with other account")
local function trimName(v) return (tostring(v or ""):gsub("^%s+", ""):gsub("%s+$", "")) end
pairSec:AddInput({Name = "Winner username", Placeholder = "account that should win", Flag = "ff_pair_winner",
    Callback = function(v) pairCfg.winner = trimName(v) end})
pairSec:AddInput({Name = "Loser username", Placeholder = "account that should lose", Flag = "ff_pair_loser",
    Callback = function(v) pairCfg.loser = trimName(v) end})
pairSec:AddSlider({Name = "Loser accuracy", Min = 50, Max = 99.99, Default = 99, Increment = 0.01, Suffix = " %", Flag = "ff_pair_acc",
    Description = "The winner plays 100%. The loser aims for this one, so it always scores a little lower. Click the number to type one, like 99.99.",
    Callback = function(v) pairCfg.loserAcc = math.clamp(tonumber(v) or 99, 50, 99.99) end})
pairSec:AddToggle({Name = "Loser: lowest score", Default = false, Flag = "ff_pair_loser_low",
    Description = "The loser presses no notes at all, so it scores as low as the game allows. The accuracy above is ignored while this is on.",
    Callback = function(v) pairCfg.loserLow = v == true end})
pairSec:AddToggle({Name = "Hop server on a timer", Default = false, Flag = "ff_pair_hop_on",
    Description = "Both accounts move to a new server after the time below. It waits for the current song to finish.",
    Callback = function(v) pairCfg.hopOn = v == true end})
pairSec:AddSlider({Name = "Hop server every", Min = 1, Max = 120, Default = 30, Increment = 1, Suffix = " minute(s)", Flag = "ff_pair_hop_min",
    Callback = function(v) pairCfg.hopMin = tonumber(v) or 30 end})
-- the two main modes first, then a custom song picked in the search below
local SONG_WINS, SONG_SCORE, SONG_CUSTOM = "Best for wins (shortest song)", "Best for score (Bob run on Insane)", "Custom song (search below)"
pairSec:AddDropdown({Name = "Pick song", Options = {SONG_WINS, SONG_SCORE, SONG_CUSTOM}, Default = SONG_WINS, Flag = "ff_pair_song",
    Description = "Wins: the shortest song that still counts. Score: the long dense Bob chart. Custom: any song you search for.",
    Callback = function(v)
        v = tostring(v)
        pairCfg.song = v == SONG_SCORE and "score" or v == SONG_CUSTOM and "custom" or "wins"
    end})
state.PairToggle = pairSec:AddToggle({Name = "Auto farm with other account", Default = false, Flag = "ff_pair_on",
    Description = "Run this on both accounts with the same two usernames. They join one stage, vote the shortest song that counts, play it and hop servers when the stage isn't free.",
    Callback = function(v) pairCfg.on = v == true end})
local pairStatus = pairSec:AddLabel({Text = "off", Style = "Sub"})
local uptimeLbl = pairSec:AddLabel({Text = "not running", Style = "Sub"})

-- ---------- custom song: search every song in the game ----------
local customSec = pairTab:CreateSection("Custom song")
local customLbl = customSec:AddLabel({Text = "choose \"Custom song\" in Pick song, then search here", Style = "Sub"})
local resultMap, selectedEntry = {}, nil
local songDrop, chartDrop

local function mmss(s) return string.format("%d:%02d", s // 60, s % 60) end
local function songLabel(e, cache)
    local len = cache[tostring(e.pack) .. "|" .. e.key]
    local extra = ""
    if type(len) == "number" then
        extra = " (" .. mmss(len) .. (len < MIN_SONG_LEN and ", too short to count as a win" or "") .. ")"
    end
    return e.title .. " - " .. e.packName .. extra
end
local function showCustom()
    local c = customChoice()
    pcall(function()
        customLbl:Set(c and ("chosen: " .. tostring(c.title) .. " (" .. tostring(c.packName) .. ") on " .. tostring(c.chart or "its default chart"))
            or "no song chosen yet")
    end)
end
-- fills the Song list from a search; returns how many songs matched
local function runSearch(text)
    local list, why = loadSongIndex()
    if not list then
        window:Notify({Title = "Songs", Content = tostring(why), Type = "Error", Duration = 4})
        return 0
    end
    local cache = pjson(SONG_CACHE) or {}
    local labels = {}
    resultMap = {}
    for _, e in ipairs(searchSongs(text, 40)) do
        local lbl = songLabel(e, cache)
        local base, n = lbl, 1
        while resultMap[lbl] do n += 1 lbl = base .. " #" .. n end
        resultMap[lbl] = e
        labels[#labels + 1] = lbl
    end
    pcall(function() songDrop:Refresh(#labels > 0 and labels or {"no songs found"}) end)
    pcall(function() customLbl:Set(#labels .. " songs match (of " .. #list .. "), pick one in the Song list") end)
    return #labels
end
local function pickCustomEntry(e, chart)
    selectedEntry = e
    saveCustom(e, chart or e.charts[1])
    pcall(function() chartDrop:Refresh(e.charts) end)
    showCustom()
end
state.SearchSongs = function(q) loadSongIndex() return searchSongs(q, 40) end -- for checking
state.SetCustom = pickCustomEntry

customSec:AddInput({Name = "Search every song", Placeholder = "song, pack or artist, then Enter",
    Callback = function(text) task.spawn(runSearch, tostring(text or "")) end})
songDrop = customSec:AddDropdown({Name = "Song", Options = {"search above first"}, Default = "search above first",
    Callback = function(label)
        local e = resultMap[tostring(label)]
        if not e then return end
        -- Normal when the song has it, else the first chart it lists
        local chart = e.charts[1]
        for _, c in ipairs(e.charts) do if c == "Normal" then chart = c break end end
        pickCustomEntry(e, chart)
    end})
chartDrop = customSec:AddDropdown({Name = "Difficulty", Options = {"choose a song first"}, Default = "choose a song first",
    Callback = function(c)
        if not selectedEntry then return end
        for _, n in ipairs(selectedEntry.charts) do
            if n == tostring(c) then saveCustom(selectedEntry, n) showCustom() end
        end
    end})
showCustom()

local scanSec = pairTab:CreateSection("Song lengths")
local scanStatus = scanSec:AddLabel({Text = "uses the built-in list until you scan", Style = "Sub"})
local function runScan()
    task.spawn(function()
        scanStatus:Set("starting scan")
        local n, why = fastScan(function(d, t) scanStatus:Set("loading audio " .. d .. " / " .. t) end)
        scanStatus:Set(n and ("done, " .. n .. " songs measured") or ("scan failed: " .. tostring(why)))
    end)
end
state.RunScan = runScan -- same as the button, for other scripts and tests
scanSec:AddButton({Name = "Scan every song", ButtonText = "Start / stop", Callback = function()
    if scanning then
        scanning = false
        scanStatus:Set("stopping")
    else
        runScan()
    end
end})

-- ---------- Discord webhook: one message per win ----------
local hookSec = pairTab:CreateSection("Discord webhook")
local hookCfg = {url = "", on = false, everyWins = 1}
state.WebhookCfg = hookCfg
hookSec:AddInput({Name = "Webhook URL (optional)", Placeholder = "https://discord.com/api/webhooks/...", Flag = "ff_hook_url",
    Description = "Only needed if you're NOT using the bot below. If the bot is set up, wins post through it instead. Saved in plain text, so don't share the settings file.",
    Callback = function(v) hookCfg.url = trimName(v) end})
hookSec:AddToggle({Name = "Notify on wins", Default = false, Flag = "ff_hook_on",
    Description = "Posts wins to your channel, through the bot when it's set up, otherwise the webhook.",
    Callback = function(v) hookCfg.on = v == true end})
local EVERY = {["Every win"] = 1, ["Every 5 wins"] = 5, ["Every 10 wins"] = 10, ["Every 25 wins"] = 25, ["Every 50 wins"] = 50, ["Every 100 wins"] = 100}
hookSec:AddDropdown({Name = "How often", Options = {"Every win", "Every 5 wins", "Every 10 wins", "Every 25 wins", "Every 50 wins", "Every 100 wins"}, Default = "Every win", Flag = "ff_hook_every",
    Description = "Only send a win message this often, so the channel isn't spammed on fast farms.",
    Callback = function(v) hookCfg.everyWins = EVERY[tostring(v)] or 1 end})

-- Control the duo farm from Discord. A webhook can only send, so taking commands needs a bot token
-- (made in the Developer Portal). You enter it; it is saved in plain text in this script's settings, so
-- keep that file and the channel private. Run both accounts with the same token and channel.
local botCfg = {token = "", channel = "", on = false}
state.BotCfg = botCfg
hookSec:AddInput({Name = "Bot token (to take commands)", Placeholder = "token from the Developer Portal", Flag = "ff_bot_token",
    Description = "Lets you type start / stop / status in your channel to control the duo farm. Saved in plain text, so keep the settings file and the channel private.",
    Callback = function(v) botCfg.token = trimName(v) end})
hookSec:AddInput({Name = "Command channel ID", Placeholder = "right-click the channel > Copy Channel ID", Flag = "ff_bot_channel",
    Callback = function(v) botCfg.channel = trimName(v) end})
hookSec:AddToggle({Name = "Take commands from Discord", Default = false, Flag = "ff_bot_on",
    Description = "Polls the channel every few seconds for: start, stop, status.",
    Callback = function(v) botCfg.on = v == true end})

local function validHook(url)
    return type(url) == "string"
        and (url:match("^https://discord%.com/api/webhooks/%d+/[%w_%-]+$") or url:match("^https://discordapp%.com/api/webhooks/%d+/[%w_%-]+$")
            or url:match("^https://[%w%.]*discord%.com/api/webhooks/%d+/[%w_%-]+$")) ~= nil
end

-- the bot is set up (token + a numeric channel): then everything posts as the bot, no webhook needed
local function botReady()
    return botCfg.token ~= "" and type(botCfg.channel) == "string" and botCfg.channel:match("^%d+$") ~= nil
end

-- returns the HTTP status, or nil on failure. Posts as the bot when it is set up (dropping the
-- webhook-only username field), otherwise falls back to the webhook url.
local function postHook(url, payload)
    if hookCfg.dryRun then return 204 end -- test hook: skip the network
    local req = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
    if not req then return nil end
    local target, headers, body = url, {["Content-Type"] = "application/json"}, payload
    if botReady() then
        target = "https://discord.com/api/v10/channels/" .. botCfg.channel .. "/messages"
        headers["Authorization"] = "Bot " .. botCfg.token
        body = {content = payload.content, embeds = payload.embeds} -- a bot posts as itself; username/avatar are webhook-only
    end
    local ok, res = pcall(req, {Url = target, Method = "POST", Headers = headers, Body = HttpService:JSONEncode(body)})
    return ok and res and res.StatusCode or nil
end

-- Run stats survive server hops (the script reloads every time): when the farm started, wins and score since then.
-- A file with no heartbeat for 10 minutes belongs to an earlier run that stopped, so it's ignored.
local STATS_FILE = PAIR_FOLDER .. "/stats_" .. plr.Name .. ".json"
local runStats = {}
do
    local saved = pjson(STATS_FILE)
    if saved and saved.startedAt and os.time() - (saved.lastSeen or 0) < 600 then runStats = saved end
end
local function saveStats()
    runStats.lastSeen = os.time()
    pwrite(STATS_FILE, runStats)
end
state.GetRunStats = function() return runStats end -- for checking, same idea as state.PairCfg
local function fmtDur(sec)
    sec = math.max(0, math.floor(sec))
    local d, h, m, s = sec // 86400, sec % 86400 // 3600, sec % 3600 // 60, sec % 60
    if d > 0 then return string.format("%dd %dh %dm", d, h, m) end
    if h > 0 then return string.format("%dh %dm", h, m) end
    if m > 0 then return string.format("%dm %ds", m, s) end
    return string.format("%ds", s)
end

local sessionScore = tonumber(runStats.score) or 0 -- score earned on every win since the farm started

-- Lifetime totals: score and wins counted across every hop and every execute, never reset except by the Reset button.
-- lastWins / lastScore / lastSeen let a win that lands while we're hopping still be counted when the script reloads.
local LIFE_FILE = PAIR_FOLDER .. "/lifetime_" .. plr.Name .. ".json"
local lifetime = pjson(LIFE_FILE) or {}
lifetime.score = tonumber(lifetime.score) or 0
lifetime.wins = tonumber(lifetime.wins) or 0
lifetime.since = lifetime.since or os.time()
local function saveLifetime() pwrite(LIFE_FILE, lifetime) end

-- "This run" (sw): wins gained since THIS execution. Survives server hops (the script reloads every hop) through a
-- file heartbeat, but a fresh execute after a 10-minute gap starts from zero -- unlike lifetime.wins, which only
-- the Reset button clears. This is what the control panel labels "This run".
local EXEC_FILE = PAIR_FOLDER .. "/exec_" .. plr.Name .. ".json"
local execWins = 0
do
    local saved = pjson(EXEC_FILE)
    if saved and os.time() - (tonumber(saved.seen) or 0) < 600 then execWins = tonumber(saved.wins) or 0 end
end
local function saveExec() pwrite(EXEC_FILE, {wins = execWins, seen = os.time()}) end
saveExec() -- stamp this execute so a hop reload within 10 min keeps the count

local function commas(n)
    local s = tostring(math.floor((tonumber(n) or 0) + 0.5))
    local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return (out:gsub("^,", ""))
end

local function winPayload(title, wins, streak)
    local fields = {
        {name = "Account", value = plr.Name, inline = true},
        {name = "Wins", value = tostring(wins), inline = true},
        {name = "Win streak", value = tostring(streak), inline = true},
        {name = "Song", value = tostring(live.lastScoreTitle or live.title or "-"), inline = true},
        {name = "Accuracy", value = string.format("%.2f%%", tonumber(live.acc) or 0), inline = true},
    }
    -- the game's score for that song, ours and the other player's
    if tonumber(live.lastScore) then
        table.insert(fields, {name = "Score earned", value = commas(live.lastScore), inline = true})
        local best
        for name, v in pairs(live.lastScores or {}) do
            if name ~= plr.Name and (not best or v > best) then best = v end
        end
        if best then table.insert(fields, {name = "Opponent score", value = commas(best), inline = true}) end
        table.insert(fields, {name = "Session score", value = commas(sessionScore), inline = true})
    end
    table.insert(fields, {name = "Total score (all hops)", value = commas(lifetime.score), inline = true})
    table.insert(fields, {name = "Total wins tracked", value = tostring(lifetime.wins), inline = true})
    if runStats.startedAt then
        table.insert(fields, {name = "Running for", value = fmtDur(os.time() - runStats.startedAt), inline = true})
        table.insert(fields, {name = "Wins this run", value = tostring(runStats.wins or 0), inline = true})
    end
    return {username = "catn hub", embeds = {{
        title = title, color = 0x8F70EC, fields = fields,
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    }}}
end

hookSec:AddButton({Name = "Send a test message", ButtonText = "Test", Callback = function()
    if not (botReady() or validHook(hookCfg.url)) then
        window:Notify({Title = "Discord", Content = "Set up the bot (token + channel) below, or a webhook URL, first.", Type = "Warning", Duration = 4})
        return
    end
    task.spawn(function()
        local code = postHook(hookCfg.url, winPayload("Test message", "-", "-"))
        local good = code and code >= 200 and code < 300
        local via = botReady() and "bot" or "webhook"
        window:Notify({Title = "Discord", Content = good and ("Sent via the " .. via .. ", check your channel.") or ("Discord said " .. tostring(code or "nothing")),
            Type = good and "Success" or "Error", Duration = 4})
    end)
end})

hookSec:AddButton({Name = "Reset score and win totals", ButtonText = "Reset", Callback = function()
    lifetime = {score = 0, wins = 0, since = os.time(), lastWins = lifetime.lastWins, lastSeen = os.time()}
    sessionScore = 0
    if runStats.startedAt then runStats.score, runStats.wins = 0, 0 saveStats() end
    execWins = 0; saveExec()
    saveLifetime()
    window:Notify({Title = "Totals", Content = "Score and win totals are back to zero.", Type = "Success", Duration = 3})
end})

-- ---------- Global stats: report this account to a shared channel so the panel bot can show everyone ----------
-- Posting to a webhook needs no bot token, so every user reports here with zero setup. Each account keeps ONE
-- message it edits (id saved to disk), so the channel stays one line per account instead of filling up.
local STATS_WEBHOOK = "https://discord.com/api/webhooks/1572814663328997406/P0LgC-184HItuVh1XFzmD87VaU8kId-e58K4pudYeN2XmRG8Vsxk7bvKbd8GXi4RmCpp"
-- Firebase Realtime DB: one node per account (overwritten each cycle), so the bot reads everyone in one GET
-- with no burial and no shared rate limit. Primary store; the webhook above is the fallback when this is blank.
-- the exact win streak from the tag over our head (the leaderboard rounds big ones), or nil
local function streakTag()
    local ch = workspace:FindFirstChild(plr.Name)
    local head = ch and ch:FindFirstChild("Head")
    local streak = head and head:FindFirstChild("Streak", true)
    local lbl = streak and streak:FindFirstChildWhichIsA("TextLabel", true)
    local n = lbl and tonumber((lbl.Text:gsub(",", "")))
    return n
end

local STATS_DB = "https://catn-db-default-rtdb.firebaseio.com/"
do
    local req = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
    if req and (STATS_WEBHOOK ~= "" or STATS_DB ~= "") then
        local MSG_FILE = PAIR_FOLDER .. "/statmsg_" .. plr.Name .. ".json"
        local saved = pjson(MSG_FILE) or {}
        local msgId = saved.id
        local function num(t) -- "3.13k" / "105m" / "1,234" -> a number
            t = tostring(t or ""):gsub(",", ""):gsub("%s", "")
            local n, suf = t:match("^([%d%.]+)([KkMmBb]?)$")
            if not n then return nil end
            return (tonumber(n) or 0) * (({k = 1e3, m = 1e6, b = 1e9})[suf:lower()] or 1)
        end
        local function board(name) -- the real leaderboard value, or nil if the board isn't up yet
            local pg = plr:FindFirstChild("PlayerGui")
            local gg = pg and pg:FindFirstChild("GameGui")
            local lb = gg and gg:FindFirstChild("Screen") and gg.Screen:FindFirstChild("Leaderstats")
            local items = lb and lb:FindFirstChild("Inner") and lb.Inner:FindFirstChild("Items")
            local row = items and items:FindFirstChild("Inner") and items.Inner:FindFirstChild(plr.Name)
            local cats = row and row:FindFirstChild("Categories")
            local lbl = cats and cats:FindFirstChild(name)
            return lbl and num(lbl.Text) or nil
        end
        -- remember the last real values, so a tick where the board is mid-rebuild doesn't drop them to 0
        local realW, realP, realTS = tonumber(saved.w), tonumber(saved.p), tonumber(saved.ts)
        -- "" unless this client is genuinely still connected: a kicked/disconnected client keeps its old JobId
        local function liveJob()
            local ok, live = pcall(function()
                if not plr.Parent then return false end
                local nc = game:FindService("NetworkClient")
                if nc and not nc:FindFirstChild("ClientReplicator") then return false end
                local pg = game:GetService("CoreGui"):FindFirstChild("RobloxPromptGui")
                local ov = pg and pg:FindFirstChild("promptOverlay")
                return not (ov and ov:FindFirstChild("ErrorPrompt"))
            end)
            return (not ok or live) and game.JobId or ""
        end
        local function statData()
            realW = board("Wins") or realW or tonumber(lifetime.lastWins) or 0
            realP = board("Points") or realP or 0
            realTS = board("TotalScore") or realTS or 0
            return {
                n = plr.Name,
                v = FF_VERSION, -- script version, shown by the bot
                w = math.floor(realW), -- real leaderboard wins
                p = math.floor(realP), -- real points (the game's Points currency)
                ts = math.floor(realTS), -- real total score
                ws = streakTag() or board("WinStreak"), -- current win streak: exact from the head tag, else the board
                sw = execWins, -- wins the script farmed since it was executed (this run), surviving hops
                s = tonumber(lifetime.score) or 0, -- score the script farmed
                rw = runStats.startedAt and (runStats.wins or 0) or nil,
                rs = runStats.startedAt and sessionScore or nil,
                rt = runStats.startedAt or nil,
                pl = game.PlaceId, -- so the bot can hand out a "join this server" script
                j = liveJob(), -- verified: empty if kicked/disconnected
                t = os.time(),
            }
        end
        task.spawn(function()
            while alive do
                saveExec() -- heartbeat: keeps "this run" alive across a hop reload even in a dry spell
                local data = statData()
                if STATS_DB ~= "" then
                    -- merge FF's stats onto this account's node (the hub core writes the base presence); one bot GET, no rate wall
                    pcall(req, {Url = STATS_DB .. "accounts/" .. plr.Name .. ".json", Method = "PATCH",
                        Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode(data)})
                else
                    local payload = HttpService:JSONEncode({content = "STAT " .. HttpService:JSONEncode(data)})
                    local sent = false
                    if msgId then
                        local ok, res = pcall(req, {Url = STATS_WEBHOOK .. "/messages/" .. msgId, Method = "PATCH",
                            Headers = {["Content-Type"] = "application/json"}, Body = payload})
                        sent = ok and res and tonumber(res.StatusCode) ~= nil and res.StatusCode < 300
                    end
                    if not sent then -- no message yet, or it was deleted: post a fresh one and remember its id
                        local ok, res = pcall(req, {Url = STATS_WEBHOOK .. "?wait=true", Method = "POST",
                            Headers = {["Content-Type"] = "application/json"}, Body = payload})
                        if ok and res and res.Body then
                            local good, m = pcall(function() return HttpService:JSONDecode(res.Body) end)
                            if good and type(m) == "table" and m.id then msgId = m.id end
                        end
                    end
                end
                -- keep the last real values + the live server on disk, so the bot can join local accounts even offline
                pwrite(MSG_FILE, {id = msgId, w = realW, p = realP, ts = realTS, j = liveJob(), pl = game.PlaceId})
                task.wait(45) -- refresh often so the server id the bot hands out stays current across hops
            end
        end)
        -- Global lobby boards (Weekly Wins, Weekly Score, Winstreaks...) -> boards/ff, so the bot's leaderboard
        -- command shows the game's real positions. Every FF user can write it; whoever is due first refreshes it.
        if STATS_DB ~= "" then
            local function readBoards()
                local lb = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Leaderboards")
                local boards = {}
                for _, b in ipairs(lb and lb:GetChildren() or {}) do
                    local g = b:FindFirstChild("SurfaceGui", true)
                    local inner = g and g:FindFirstChild("SF") and g.SF:FindFirstChild("Inner")
                    local title = b.Name
                    for _, d in ipairs(g and g:GetDescendants() or {}) do
                        if d:IsA("TextLabel") and d.Name:find("BoardLabel$") then title = d.Text end
                    end
                    local rows = {}
                    for _, r in ipairs(inner and inner:GetChildren() or {}) do
                        local rank, val = r:FindFirstChild("Rank"), r:FindFirstChild("Value")
                        if r:IsA("Frame") and rank and val then
                            local name
                            for _, d in ipairs(r:GetDescendants()) do
                                if d:IsA("TextLabel") and d ~= rank and d ~= val and d.Text ~= "" then name = d.Text break end
                            end
                            if name and tonumber(rank.Text) then rows[#rows + 1] = {r = tonumber(rank.Text), n = name, v = val.Text} end
                        end
                    end
                    table.sort(rows, function(x, y) return x.r < y.r end)
                    if #rows > 0 then boards[b.Name] = {title = title, rows = rows} end
                end
                return boards
            end
            task.spawn(function()
                task.wait(15) -- let the boards fill in after joining
                while alive do
                    pcall(function()
                        local res = req({Url = STATS_DB .. "boards/ff/t.json", Method = "GET"})
                        local last = res and tonumber(res.Body)
                        if last and os.time() - last < 120 then return end -- someone refreshed it recently
                        local boards = readBoards()
                        if next(boards) then
                            req({Url = STATS_DB .. "boards/ff.json", Method = "PUT", Headers = {["Content-Type"] = "application/json"},
                                Body = HttpService:JSONEncode({t = os.time(), by = plr.Name, boards = boards})})
                        end
                    end)
                    task.wait(120 + math.random(0, 30))
                end
            end)
        end
    end
end

local function myBoardRow()
    local pg = plr:FindFirstChild("PlayerGui")
    local gg = pg and pg:FindFirstChild("GameGui")
    local ls = gg and gg:FindFirstChild("Screen") and gg.Screen:FindFirstChild("Leaderstats")
    local items = ls and ls:FindFirstChild("Inner") and ls.Inner:FindFirstChild("Items")
    local inner = items and items:FindFirstChild("Inner")
    local row = inner and inner:FindFirstChild(plr.Name)
    return row and row:FindFirstChild("Categories")
end

-- this account's current win streak. The tag over our head has the exact number; the leaderboard
-- rounds big ones ("1.17k"), so it's only the fallback. "?" while neither is up.
local function winStreak()
    local n = streakTag()
    if n then return tostring(n) end
    local cats = myBoardRow()
    local lbl = cats and cats:FindFirstChild("WinStreak")
    return lbl and lbl.Text ~= "" and lbl.Text or "?"
end

-- ---------- Discord bot: online + instant commands over the gateway, REST polling as a fallback ----------
local API = "https://discord.com/api/v10"
local botReq = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
if botReq then
    local req = botReq
    local gatewayUp = false
    local pollLastId, pollSeeded, warnedAuth = nil, false, false
    local function sendTo(channelId, text)
        pcall(req, {Url = API .. "/channels/" .. tostring(channelId) .. "/messages", Method = "POST",
            Headers = {["Content-Type"] = "application/json", ["Authorization"] = "Bot " .. botCfg.token},
            Body = HttpService:JSONEncode({content = text})})
    end
    -- Both accounts run the bot, so only one of them should answer (the winner, or either if none is set);
    -- both still ACT on a command, only the reply is deduped.
    local function primary() return tostring(pairCfg.winner or "") == "" or plr.Name:lower() == tostring(pairCfg.winner):lower() end
    local function send(text) if primary() then sendTo(botCfg.channel, text) end end
    local function role()
        local me = plr.Name:lower()
        if me == (pairCfg.winner or ""):lower() then return "winner" end
        if me == (pairCfg.loser or ""):lower() then return "loser" end
        return "neither winner nor loser"
    end
    -- Only farm commands live here now (they need a live game). Chat (hi/meow/help) is the standalone bot's job.
    local function apply(raw)
        local text = tostring(raw):lower():gsub("^%s+", ""):gsub("%s+$", "")
        text = text:gsub("^!%s*", ""):gsub("^catn%s+", "") -- optional "catn" / "!" prefix
        local cmd = text:match("^(%S+)") or ""
        if cmd == "start" or cmd == "on" then
            pairCfg.on = true
            pcall(function() state.PairToggle:Set(true) end)
            send(plr.Name .. ": duo farm ON (" .. role() .. ")")
        elseif cmd == "stop" or cmd == "off" then
            pairCfg.on = false
            pcall(function() state.PairToggle:Set(false) end)
            send(plr.Name .. ": duo farm OFF")
        elseif cmd == "status" then
            if not pairCfg.on then
                send(plr.Name .. ": duo farm is OFF")
            elseif runStats.startedAt then
                send(string.format("%s: ON as %s, running %s, wins %d, score %s, streak %s (v%s)", plr.Name, role(),
                    fmtDur(os.time() - runStats.startedAt), runStats.wins or 0, commas(sessionScore), winStreak(), FF_VERSION))
            else
                send(plr.Name .. ": ON as " .. role() .. ", starting up (v" .. FF_VERSION .. ")")
            end
        elseif cmd == "stats" then
            send(string.format("%s: lifetime wins %s, total score %s, win streak %s", plr.Name, commas(lifetime.wins or 0), commas(lifetime.score or 0), winStreak()))
        elseif cmd == "streak" or cmd == "winstreak" then
            send(plr.Name .. ": win streak " .. winStreak())
        elseif cmd == "rejoin" or cmd == "hop" or cmd == "reconnect" then
            send(plr.Name .. ": rejoining")
            pcall(function() game:GetService("TeleportService"):Teleport(game.PlaceId, plr) end)
        end
    end
    -- Gateway: a WebSocket to Discord so the bot shows ONLINE and commands arrive instantly (no poll delay).
    -- Each reconnect is a fresh login, so on a hopping farm it can hit Discord's daily gateway limit; the poll
    -- loop below is the fallback and takes over whenever the gateway is down.
    local wslib = (WebSocket or websocket)
    if wslib then
        task.spawn(function()
            local GW = "wss://gateway.discord.gg/?v=10&encoding=json"
            local INTENTS = 33280 -- GUILD_MESSAGES (512) + MESSAGE_CONTENT (32768)
            local fails = 0
            while alive do
                if not (botCfg.on and botCfg.token ~= "" and botCfg.channel:match("^%d+$")) then
                    gatewayUp = false
                    task.wait(2)
                else
                    local ok, sock = pcall(function() return wslib.connect(GW) end)
                    if not ok or not sock then
                        gatewayUp = false
                        fails = math.min(fails + 1, 12)
                        task.wait(10 + fails * 5) -- can't connect; the poll loop covers commands meanwhile
                    else
                        local seq, hbMs, closed = nil, nil, false
                        local msgConn = sock.OnMessage:Connect(function(raw)
                            local good, p = pcall(function() return HttpService:JSONDecode(raw) end)
                            if not good or type(p) ~= "table" then return end
                            if p.s ~= nil then seq = p.s end
                            local op = p.op
                            if op == 10 then
                                hbMs = p.d and tonumber(p.d.heartbeat_interval)
                                pcall(function() sock:Send(HttpService:JSONEncode({op = 2, d = {
                                    token = botCfg.token, intents = INTENTS,
                                    properties = {os = "windows", browser = "catn", device = "catn"},
                                    presence = {status = "online", afk = false, since = 0, activities = {}}}})) end)
                                task.spawn(function()
                                    while not closed do
                                        task.wait((hbMs or 41250) / 1000)
                                        if closed then break end
                                        pcall(function() sock:Send(HttpService:JSONEncode({op = 1, d = seq})) end)
                                    end
                                end)
                            elseif op == 1 then
                                pcall(function() sock:Send(HttpService:JSONEncode({op = 1, d = seq})) end)
                            elseif op == 7 or op == 9 then -- server asked us to reconnect / invalid session
                                closed = true
                                pcall(function() sock:Close() end)
                            elseif op == 0 then
                                if p.t == "READY" then gatewayUp = true; fails = 0 end
                                if p.t == "MESSAGE_CREATE" and type(p.d) == "table" and not (p.d.author and p.d.author.bot)
                                    and tostring(p.d.channel_id) == botCfg.channel then
                                    apply(p.d.content)
                                end
                            end
                        end)
                        local closeConn = sock.OnClose:Connect(function() closed = true end)
                        while not closed and alive and botCfg.on and botCfg.token ~= "" do task.wait(0.5) end
                        closed, gatewayUp = true, false
                        pcall(function() msgConn:Disconnect() end)
                        pcall(function() closeConn:Disconnect() end)
                        pcall(function() sock:Close() end)
                        task.wait(3) -- small gap before a fresh connect
                    end
                end
            end
        end)
    end

    -- Poll fallback: the only path with no WebSocket, and the safety net when the gateway is down. It idles while
    -- the gateway is up and re-seeds so it skips the backlog when it takes back over.
    task.spawn(function()
        while alive do
            task.wait(1.2)
            if botCfg.on and botCfg.token ~= "" and botCfg.channel:match("^%d+$") then
                if gatewayUp then
                    pollSeeded = false
                else
                    local url = API .. "/channels/" .. botCfg.channel .. "/messages?limit=" .. (pollLastId and ("10&after=" .. pollLastId) or "1")
                    local ok, res = pcall(req, {Url = url, Method = "GET", Headers = {["Authorization"] = "Bot " .. botCfg.token}})
                    local status = ok and res and res.StatusCode
                    if (status == 401 or status == 403) and not warnedAuth then
                        warnedAuth = true
                        pcall(function() window:Notify({Title = "Discord bot", Content = "Discord refused the token/permissions (" .. tostring(status) .. "). Check the token and that the bot can read and send in that channel.", Type = "Error", Duration = 6}) end)
                    elseif status == 200 and res.Body then
                        warnedAuth = false
                        local good, msgs = pcall(function() return HttpService:JSONDecode(res.Body) end)
                        if good and type(msgs) == "table" then
                            for i = #msgs, 1, -1 do
                                local m = msgs[i]
                                if type(m) == "table" and m.id then
                                    pollLastId = m.id
                                    if pollSeeded and not (m.author and m.author.bot) then
                                        apply(m.content)
                                    end
                                end
                            end
                            pollSeeded = true
                        end
                    elseif status == 429 then
                        task.wait(5) -- rate limited: ease off before the next poll
                    end
                end
            end
        end
    end)
end

-- reads "1,234", "12.5K", "3M" off the leaderboard
local function parseCount(t)
    t = tostring(t or ""):gsub(",", ""):gsub("%s", "")
    local num, suffix = t:match("^([%d%.]+)([KkMmBb]?)$")
    if not num then return nil end
    local mult = ({k = 1e3, m = 1e6, b = 1e9})[suffix:lower()] or 1
    return (tonumber(num) or 0) * mult
end

-- Wins only ever go up, so remember the highest value seen: a leaderboard rebuild that briefly shows 0 and then
-- the real number can't look like a win. Increases in the first SETTLE seconds after binding are ignored.
local WIN_SETTLE = 15
local winQueue = {}
local winBound, winConn, winLast, winBoundAt
local winBaseFromSave = false -- true when the baseline came from the file saved before the last hop / execute
-- wins and score are tracked on every win, with or without the webhook; the webhook message is only an extra
local notifiedAtWins = nil -- win count at our last notification, for the "how often" throttle
local function onWinsChanged(lbl)
    local cur = parseCount(lbl.Text)
    if not cur then return end
    if winLast and cur > winLast and (os.clock() - winBoundAt > WIN_SETTLE or winBaseFromSave) then
        local gained = math.floor(cur - winLast + 0.5)
        -- the song's score from this server, or the one saved just before we hopped (a win can land mid-hop)
        local earned = tonumber(live.lastScore) or tonumber(lifetime.lastScore) or 0
        sessionScore += earned
        lifetime.score += earned
        lifetime.wins += gained
        execWins += gained; saveExec()
        lifetime.lastScore = nil
        if runStats.startedAt then
            runStats.wins = (runStats.wins or 0) + gained
            runStats.score = sessionScore
            saveStats()
        end
        lifetime.lastWins = cur
        saveLifetime()
        if hookCfg.on then
            local every = math.max(1, tonumber(hookCfg.everyWins) or 1)
            notifiedAtWins = notifiedAtWins or (cur - gained) -- baseline: the win count before this change
            if cur - notifiedAtWins >= every then
                local gainedSince = cur - notifiedAtWins
                notifiedAtWins = cur
                local cats = myBoardRow()
                local streakLbl = cats and cats:FindFirstChild("WinStreak")
                local payload = winPayload("Win +" .. gainedSince, lbl.Text, streakLbl and streakLbl.Text or "?")
                if state.OnWin then pcall(state.OnWin, payload) end
                if botReady() or validHook(hookCfg.url) or hookCfg.dryRun then table.insert(winQueue, payload) end
            end
        end
    end
    if not winLast or cur > winLast then
        winLast = cur
        lifetime.lastWins = cur
        saveLifetime()
        winBaseFromSave = false
    end
end

task.spawn(function()
    while alive do
        local cats = myBoardRow()
        local lbl = cats and cats:FindFirstChild("Wins")
        if lbl ~= winBound then -- (re)bind, the game may rebuild the leaderboard rows
            if winConn then winConn:Disconnect() winConn = nil end
            winBound = lbl
            winBoundAt = os.clock()
            if lbl then
                -- first bind after a hop / execute: if we saved the win count less than 10 minutes ago, that is our
                -- baseline, so a win that landed while we were hopping gets counted instead of silently absorbed
                if not winLast and tonumber(lifetime.lastWins) and os.time() - (tonumber(lifetime.lastSeen) or 0) < 600 then
                    winLast, winBaseFromSave = lifetime.lastWins, true
                end
                local cur = parseCount(lbl.Text)
                if cur and winBaseFromSave and cur > winLast then
                    onWinsChanged(lbl) -- counts the gained wins with the saved score
                elseif cur and (not winLast or cur > winLast) then
                    winLast = cur
                end
                winConn = lbl:GetPropertyChangedSignal("Text"):Connect(function() onWinsChanged(lbl) end)
            end
        end
        -- keep the file fresh: the last in-song score and a heartbeat, so a hop can't lose a win's score
        if live.lastScore then lifetime.lastScore = live.lastScore end
        lifetime.lastSeen = os.time()
        if os.time() - (lifetime.savedAt or 0) >= 6 then
            lifetime.savedAt = os.time()
            saveLifetime()
        end
        -- send one queued message per tick so a burst can't trip Discord's rate limit
        if #winQueue > 0 then
            local code = postHook(hookCfg.url, table.remove(winQueue, 1))
            if code == 429 then task.wait(3) end
        end
        task.wait(2)
    end
    if winConn then winConn:Disconnect() end
end)

-- manager: starts/stops the farm and the accuracy split from the toggle
local pairRunning, pairToken, pairCleanup, pairSaved = false, 0, nil, nil
local pairRestartWhy -- set by the farm when a hop is stuck or errored: the manager restarts it (stats are kept)
local function pairSetStatus(t) pcall(function() pairStatus:Set(t) end) end

local function pairEnd()
    pairToken += 1
    pairRunning = false
    if pairCleanup then pairCleanup() pairCleanup = nil end
    if pairSaved then
        for k, v in pairs(pairSaved) do set(k, v) end
        pairSaved = nil
    end
    -- turned off on purpose: the next run starts counting from zero
    runStats = {}
    sessionScore = 0
    pcall(function() if isfile(STATS_FILE) then delfile(STATS_FILE) end end)
    pcall(function() uptimeLbl:Set("not running") end)
    pairSetStatus("off")
end

task.spawn(function()
    local warned = false
    while alive do
        local winner, loser = pairCfg.winner, pairCfg.loser
        local want = pairCfg.on and winner ~= "" and loser ~= ""
        local role
        if want then
            if plr.Name:lower() == winner:lower() then role = "winner"
            elseif plr.Name:lower() == loser:lower() then role = "loser" end
        end
        if want and not role then
            if not warned then
                warned = true
                pairSetStatus("this account (" .. plr.Name .. ") is neither the winner nor the loser")
            end
        elseif want and not pairRunning then
            warned = false
            pairRunning = true
            pairToken += 1
            local my = pairToken
            -- (kept across a restart, so "off" still puts back what the player had before the farm took over)
            pairSaved = pairSaved or {enabled = auto.enabled, aim = auto.aim, aimTarget = auto.aimTarget, humanize = auto.humanize}
            -- no song list yet (first run): measure every song in the background, the built-in list covers the wait
            local known = 0
            for k, v in pairs(pjson(SONG_CACHE) or {}) do if type(v) == "number" then known += 1 end end
            if known < 500 and not scanning then runScan() end
            if not runStats.startedAt then -- a fresh run (a hop reload keeps the saved one)
                runStats = {startedAt = os.time(), wins = 0, score = 0}
                sessionScore = 0
            end
            saveStats()
            set("humanize", false)
            if role == "winner" then
                set("enabled", true)
                set("aim", false) -- no target = perfect
            else
                loserPlay()
            end
            local w, l = (role == "winner") and plr.Name or winner, (role == "loser") and plr.Name or loser
            pairSetStatus("running as the " .. role)
            task.spawn(function()
                local okRun, cleanup = pcall(runPairFarm, w, l, function() return alive and pairRunning and pairToken == my end, pairSetStatus,
                    function(why) if pairToken == my then pairRestartWhy = why end end)
                if okRun then
                    if pairToken == my then pairCleanup = cleanup else if cleanup then cleanup() end end
                else
                    pairSetStatus("error: " .. tostring(cleanup))
                end
            end)
        elseif pairRunning and pairRestartWhy then
            -- the farm asked for a fresh start (stuck hop, error, map didn't load): stop this run, the next tick starts a new one
            local why = pairRestartWhy
            pairRestartWhy = nil
            warn("[DUO FARM] restarting the farm: " .. tostring(why))
            pairToken += 1
            pairRunning = false
            if pairCleanup then pcall(pairCleanup) pairCleanup = nil end
            pairSetStatus("restarting (" .. tostring(why) .. ")")
        elseif role and pairRunning then
            -- loser accuracy slider can change while running
            if role == "loser" then loserPlay() end
        elseif not want and pairRunning then
            pairEnd()
        end
        if pairRunning and runStats.startedAt then
            pcall(function()
                uptimeLbl:Set("running for " .. fmtDur(os.time() - runStats.startedAt) .. "  |  wins " .. tostring(runStats.wins or 0)
                    .. "  |  score " .. commas(sessionScore)
                    .. (pairCfg.hopOn and ("  |  hop in " .. fmtDur(math.max(0, (tonumber(pairCfg.hopMin) or 0) * 60 - (os.clock() - serverJoinedAt)))) or ""))
            end)
            if os.time() - (runStats.lastSeen or 0) >= 20 then saveStats() end -- heartbeat: tells a hop reload this run is alive
        end
        task.wait(1)
    end
end)

-- ---------- menu layout fix ----------
-- Switching the layout or arrangement (Panels / Rail / Dock, Columns / Grid ...) sometimes leaves the panels half-sized:
-- squished, with blurry text and a blank area. The library's own ApplyLayout rebuilds them properly, so run it a moment
-- after every layout, arrangement, panel-count or window-size change (and not on our own re-layout).
task.spawn(function()
    local v = window.v
    if type(v) ~= "table" or type(v.ApplyLayout) ~= "function" then return end
    local function sample()
        local size = v.Pages and v.Pages.AbsoluteSize
        return tostring(v.LayoutName) .. "|" .. tostring(v.Arrange) .. "|" .. tostring(v.OpenPanels and #v.OpenPanels)
            .. "|" .. (size and (math.floor(size.X) .. "x" .. math.floor(size.Y)) or "?")
    end
    local last, dirtyAt = sample(), nil
    while alive do
        task.wait(0.25)
        local now = sample()
        if now ~= last then
            last, dirtyAt = now, os.clock() -- still changing: wait until it settles
        elseif dirtyAt and os.clock() - dirtyAt > 0.9 then
            dirtyAt = nil
            pcall(function() v:ApplyLayout() end)
            task.wait(0.6)
            last = sample() -- our own re-layout changed the sizes, don't treat that as a new change
        end
    end
end)

window:SelectTab("Autoplay")
pcall(function()
    window:Notify({Title = "Funky Friday", Content = "loaded, F1 to toggle", Type = "Success", Duration = 4})
end)

return state
